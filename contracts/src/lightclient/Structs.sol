pragma solidity 0.8.14;

struct BLSAggregatedSignature {
    uint64 participation;
    Groth16Proof proof;
}

struct Groth16Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

struct BeaconBlockHeader {
    uint64 slot;
    uint64 proposerIndex;
    bytes32 parentRoot;
    bytes32 stateRoot;
    bytes32 bodyRoot;
}

struct LightClientUpdate {
    BeaconBlockHeader attestedHeader;
    BeaconBlockHeader finalizedHeader;
    bytes32[] finalityBranch;
    bytes32 nextSyncCommitteeRoot;
    bytes32[] nextSyncCommitteeBranch;
    bytes32 executionStateRoot;
    bytes32[] executionStateRootBranch;
    BLSAggregatedSignature signature;
}