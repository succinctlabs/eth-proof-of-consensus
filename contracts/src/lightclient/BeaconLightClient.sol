pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "./Structs.sol";
import "./BLSAggregatedSignatureVerifier.sol";
import "./PoseidonCommitmentVerifier.sol";
import "./libraries/SimpleSerialize.sol";
import "openzeppelin-contracts/access/Ownable.sol";

uint256 constant OPTIMISTIC_UPDATE_TIMEOUT = 86400;
uint256 constant SLOTS_PER_EPOCH = 32;
uint256 constant SLOTS_PER_SYNC_COMMITTEE_PERIOD = 8192;
uint256 constant MIN_SYNC_COMMITTEE_PARTICIPANTS = 10;
uint256 constant SYNC_COMMITTEE_SIZE = 512;
uint256 constant FINALIZED_ROOT_INDEX = 105;
uint256 constant NEXT_SYNC_COMMITTEE_INDEX = 55;
uint256 constant EXECUTION_STATE_ROOT_INDEX = 402;

contract BeaconLightClient is PoseidonCommitmentVerifier, BLSAggregatedSignatureVerifier, Ownable {
    bytes32 public immutable GENESIS_VALIDATORS_ROOT;
    uint256 public immutable GENESIS_TIME;
    uint256 public immutable SECONDS_PER_SLOT;

    bool public active;
    bytes4 public defaultForkVersion;
    uint64 public head;
    mapping(uint64 => BeaconBlockHeader) public headers;
    mapping(uint64 => bytes32) public executionStateRoots;

    BeaconBlockHeader public optimisticHeader;
    bytes32 public optimisticNextSyncCommitteeRoot;
    bytes32 public optimisticNextSyncCommitteePoseidon;
    bytes32 public optimisticExecutionStateRoot;
    uint64 public optimisticParticipation;
    uint64 public optimisticTimeout;

    mapping(uint256 => bytes32) public syncCommitteeRootByPeriod;
    mapping(bytes32 => bytes32) public sszToPoseidon;

    event HeadUpdate(uint256 indexed slot, bytes32 indexed root);
    event OptimisticHeadUpdate(uint256 indexed slot, bytes32 indexed root, uint256 indexed participation);
    event SyncCommitteeUpdate(uint256 indexed period, bytes32 indexed root);

    constructor(
        bytes32 genesisValidatorsRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        bytes4 forkVersion,
        uint256 startSyncCommitteePeriod,
        bytes32 startSyncCommitteeRoot,
        bytes32 startSyncCommitteePoseidon
    ) {
        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
        GENESIS_TIME = genesisTime;
        SECONDS_PER_SLOT = secondsPerSlot;
        defaultForkVersion = forkVersion;
        syncCommitteeRootByPeriod[startSyncCommitteePeriod] = startSyncCommitteeRoot;
        sszToPoseidon[startSyncCommitteeRoot] = startSyncCommitteePoseidon;
        active = true;
    }

    modifier isActive {
        require(active, "Light client must be active");
        _;
    }

    /*
    * @dev Returns the beacon chain state root for a given slot.
    */
    function stateRoot(uint64 slot) external view returns (bytes32) {
        return headers[slot].stateRoot;
    }

    /*
    * @dev Returns the execution state root for a given slot.
    */
    function executionStateRoot(uint64 slot) external view returns (bytes32) {
        return executionStateRoots[slot];
    }

    /*
    * @dev Updates the head given a finalized light client update. The primary conditions for this are:
    *   1) At least 2n/3+1 signatures from the current sync committee where n = 512
    *   2) A valid merkle proof for the finalized header inside the currently attested header
    */
    function step(LightClientUpdate memory update) external isActive {
        (BeaconBlockHeader memory activeHeader, bool isFinalized,) = processLightClientUpdate(update);
        require(activeHeader.slot > head, "Update slot must be greater than the current head");
        require(activeHeader.slot <= getCurrentSlot(), "Update slot is too far in the future");
        if (isFinalized) {
            setHead(activeHeader);
            setExecutionStateRoot(activeHeader.slot, update.executionStateRoot);
        }
    }

    /*
    * @dev Set the sync committee validator set root for the next sync commitee period. This root is signed by the current
    * sync committee. To make the proving cost of zkBLSVerify(..) cheaper, we map the ssz merkle root of the validators to a
    * poseidon merkle root (a zk-friendly hash function). In the case there is no finalization, we will keep track of the
    * best optimistic update. It can be finalized via forceUpdate(...).
    */
    function updateSyncCommittee(LightClientUpdate memory update, bytes32 nextSyncCommitteePoseidon, Groth16Proof memory commitmentMappingProof) external isActive {
        (BeaconBlockHeader memory activeHeader, bool isFinalized, uint64 participation) = processLightClientUpdate(update);
        uint64 currentPeriod = getSyncCommitteePeriodFromSlot(activeHeader.slot);
        require(syncCommitteeRootByPeriod[currentPeriod + 1] == 0, "Next sync committee was already initialized");

        bool isValidSyncCommitteeProof = SimpleSerialize.isValidMerkleBranch(
            update.nextSyncCommitteeRoot,
            NEXT_SYNC_COMMITTEE_INDEX,
            update.nextSyncCommitteeBranch,
            update.finalizedHeader.stateRoot
        );
        require(isValidSyncCommitteeProof, "Next sync committee proof is invalid");

        zkMapSSZToPoseidon(update.nextSyncCommitteeRoot, nextSyncCommitteePoseidon, commitmentMappingProof);

        if (isFinalized) {
            setSyncCommitteeRoot(currentPeriod + 1, update.nextSyncCommitteeRoot);
        } else {
            if (activeHeader.slot >= optimisticHeader.slot) {
                require(participation > optimisticParticipation, "Not the best optimistic update");
            }
            setOptimisticHead(activeHeader, update.nextSyncCommitteeRoot, update.executionStateRoot, participation);
        }
    }

    /*
    * @dev Finalizes the optimistic update and sets the next sync committee if no finalized updates have been received
    * for a period.
    */
    function forceUpdate() external isActive {
        require(optimisticHeader.slot > head, "Optimistic head must update the head forward");
        require(getCurrentSlot() > optimisticHeader.slot + SLOTS_PER_SYNC_COMMITTEE_PERIOD, "Optimistic should only finalized if sync period ends");
        require(optimisticTimeout < block.timestamp, "Waiting for UPDATE_TIMEOUT");
        setHead(optimisticHeader);
        setSyncCommitteeRoot(getSyncCommitteePeriodFromSlot(optimisticHeader.slot) + 1, optimisticNextSyncCommitteeRoot);
    }

    /*
    * @dev Implements shared logic for processing light client updates. In particular, it checks:
    *   1) If it claims to have finalization, sets the activeHeader to be the finalized one--else it uses the attestedHeader
    *   2) Validates the merkle proof that proves inclusion of finalizedHeader in attestedHeader
    *   3) Validates the merkle proof that proves inclusion of executionStateRoot in attestedHeader
    *   4) Verifies that the light client update has update.signature.participation signatures from the current sync committee with a zkSNARK
    *   5) If it's finalized, checks for 2n/3+1 signatures. If it's not, checks for at least MIN_SYNC_COMMITTEE_PARTICIPANTS and that it is the best update
    */
    function processLightClientUpdate(LightClientUpdate memory update) internal view returns (BeaconBlockHeader memory, bool, uint64) {
        bool hasFinalityProof = update.finalityBranch.length > 0;
        bool hasExecutionStateRootProof = update.executionStateRootBranch.length > 0;
        BeaconBlockHeader memory activeHeader = hasFinalityProof ? update.finalizedHeader : update.attestedHeader;
        if (hasFinalityProof) {
            bool isValidFinalityProof = SimpleSerialize.isValidMerkleBranch(
                SimpleSerialize.sszBeaconBlockHeader(update.finalizedHeader),
                FINALIZED_ROOT_INDEX,
                update.finalityBranch,
                update.attestedHeader.stateRoot
            );
            require(isValidFinalityProof, "Finality checkpoint proof is invalid");
        }

        if (hasExecutionStateRootProof) {
            require(hasFinalityProof, "To pass in executionStateRoot, must have finalized header");
            bool isValidExecutionStateRootProof = SimpleSerialize.isValidMerkleBranch(
                update.executionStateRoot,
                EXECUTION_STATE_ROOT_INDEX,
                update.executionStateRootBranch,
                update.finalizedHeader.bodyRoot
            );
            require(isValidExecutionStateRootProof, "Execution state root proof is invalid");
        }

        uint64 currentPeriod = getSyncCommitteePeriodFromSlot(activeHeader.slot);
        bytes32 signingRoot = SimpleSerialize.computeSigningRoot(update.attestedHeader, defaultForkVersion, GENESIS_VALIDATORS_ROOT);
        require(syncCommitteeRootByPeriod[currentPeriod] != 0, "Sync committee was never updated for this period");
        require(zkBLSVerify(signingRoot, syncCommitteeRootByPeriod[currentPeriod], update.signature.participation, update.signature.proof), "Signature is invalid");

        if (hasFinalityProof) {
            require(3 * update.signature.participation > 2 * SYNC_COMMITTEE_SIZE, "Not enough members of the sync committee signed");
        } else {
            require(update.signature.participation > MIN_SYNC_COMMITTEE_PARTICIPANTS, "Not enough members of the sync committee signed");
        }

        return (activeHeader, hasFinalityProof, update.signature.participation);
    }

    /*
    * @dev Maps a simple serialize merkle root to a poseidon merkle root with a zkSNARK. The proof asserts that:
    *   SimpleSerialize(syncCommittee) == Poseidon(syncCommittee).
    */
    function zkMapSSZToPoseidon(bytes32 sszCommitment, bytes32 poseidonCommitment, Groth16Proof memory proof) internal {
        uint256[33] memory inputs; // inputs is syncCommitteeSSZ[0..32] + [syncCommitteePoseidon]
        uint256 sszCommitmentNumeric = uint256(sszCommitment);
        for (uint256 i = 0; i < 32; i++) {
            inputs[32 - 1 - i] = sszCommitmentNumeric % 2**8;
            sszCommitmentNumeric = sszCommitmentNumeric / 2**8;
        }
        inputs[32] = uint256(poseidonCommitment);
        require(verifyCommitmentMappingProof(proof.a, proof.b, proof.c, inputs), "Proof is invalid");
        sszToPoseidon[sszCommitment] = poseidonCommitment;
    }

    /*
    * @dev Does an aggregated BLS signature verification with a zkSNARK. The proof asserts that:
    *   Poseidon(validatorPublicKeys) == sszToPoseidon[syncCommitteeRoot]
    *   aggregatedPublicKey = InnerProduct(validatorPublicKeys, bitmap)
    *   BLSVerify(aggregatedPublicKey, signature) == true
    */
    function zkBLSVerify(bytes32 signingRoot, bytes32 syncCommitteeRoot, uint256 claimedParticipation, Groth16Proof memory proof) internal view returns (bool) {
        require(sszToPoseidon[syncCommitteeRoot] != 0, "Must map SSZ commitment to Posedion commitment");
        uint256[34] memory inputs;
        inputs[0] = claimedParticipation;
        inputs[1] = uint256(sszToPoseidon[syncCommitteeRoot]);
        uint256 signingRootNumeric = uint256(signingRoot);
        for (uint256 i = 0; i < 32; i++) {
            inputs[(32 - 1 - i) + 2] = signingRootNumeric % 2 ** 8;
            signingRootNumeric = signingRootNumeric / 2**8;
        }
        return verifySignatureProof(proof.a, proof.b, proof.c, inputs);
    }

    function setHead(BeaconBlockHeader memory header) internal {
        head = header.slot;
        headers[head] = header;
        emit HeadUpdate(header.slot, SimpleSerialize.sszBeaconBlockHeader(header));
    }

    function setExecutionStateRoot(uint64 slot, bytes32 _executionStateRoot) internal {
        executionStateRoots[slot] = _executionStateRoot;
    }

    function setOptimisticHead(BeaconBlockHeader memory header, bytes32 nextSyncCommitteeRoot, bytes32 _executionStateRoot, uint64 participation) internal {
        optimisticHeader = header;
        optimisticNextSyncCommitteeRoot = nextSyncCommitteeRoot;
        optimisticExecutionStateRoot = _executionStateRoot;
        optimisticParticipation = uint64(participation);
        optimisticTimeout = uint64(block.timestamp + OPTIMISTIC_UPDATE_TIMEOUT);
        emit OptimisticHeadUpdate(header.slot, SimpleSerialize.sszBeaconBlockHeader(header), participation);
    }

    function setSyncCommitteeRoot(uint64 period, bytes32 root) internal {
        syncCommitteeRootByPeriod[period] = root;
        emit SyncCommitteeUpdate(period, root);
    }

    function getCurrentSlot() internal view returns (uint64) {
        return uint64((block.timestamp - GENESIS_TIME) / SECONDS_PER_SLOT);
    }

    function getSyncCommitteePeriodFromSlot(uint64 slot) internal pure returns (uint64) {
        return uint64(slot / SLOTS_PER_SYNC_COMMITTEE_PERIOD);
    }

    function setDefaultForkVersion(bytes4 forkVersion) public onlyOwner {
        defaultForkVersion = forkVersion;
    }

    function setActive(bool newActive) public onlyOwner {
        active = newActive;
    }
}
