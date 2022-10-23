pragma solidity 0.8.14;

import "curve-merkle-oracle/StateProofVerifier.sol";
import {RLPReader} from "Solidity-RLP/RLPReader.sol";

library HeaderProof {
    using RLPReader for RLPReader.RLPItem;
	using RLPReader for bytes;

    function verifyStorage(
		bytes32 slotHash,
		bytes32 storageRoot,
		bytes[] memory _stateProof
	) internal view returns (uint256) {
		RLPReader.RLPItem[] memory stateProof = new RLPReader.RLPItem[](_stateProof.length);
		for (uint256 i = 0; i < _stateProof.length; i++) {
			stateProof[i] = RLPReader.toRlpItem(_stateProof[i]);
		}
		// Verify existence of some nullifier
		StateProofVerifier.SlotValue memory slotValue = StateProofVerifier.extractSlotValueFromProof(
			slotHash,
			storageRoot,
			stateProof
		);
		// Check that the validated storage slot is present
		require(slotValue.exists, "Slot value does not exist");
        return slotValue.value;
	}

	function verifyAccount(
		bytes[] memory proof,
		address contractAddress,
		bytes32 stateRoot
	) internal view returns (bytes32) {
		RLPReader.RLPItem[] memory accountProof = new RLPReader.RLPItem[](proof.length);
		for (uint256 i = 0; i < proof.length; i++) {
			accountProof[i] = RLPReader.toRlpItem(proof[i]);
		}
		bytes32 addressHash = keccak256(abi.encodePacked(contractAddress));
		StateProofVerifier.Account memory account = StateProofVerifier.extractAccountFromProof(
			addressHash,
			stateRoot,
			accountProof
		);
		require(account.exists, "Account does not exist");
		return account.storageRoot;
	}

}