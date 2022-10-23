pragma solidity 0.8.14;

import "./libraries/HeaderProof.sol";
import "./TrustlessAMBStorage.sol";
import "./interfaces/ITrustlessAMB.sol";

contract AMB is TrustlessAMBStorage {
	using RLPReader for RLPReader.RLPItem;
	using RLPReader for bytes;

    bytes32 internal constant EMPTY_MESSAGE_ID = bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    address internal constant EMPTY_ADDRESS = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);

    constructor(address _lightClient, uint256 newMaxGasPerTx, address newOtherSideAMB) {
        lightClient = IBeaconLightClient(_lightClient);
        maxGasPerTx = newMaxGasPerTx;
        otherSideAMB = newOtherSideAMB;

        messageId = EMPTY_MESSAGE_ID;
        messageSender = EMPTY_ADDRESS;
		chainId = block.chainid;
    }

    function send(address receiver, uint16 chainId, uint256 gasLimit, bytes calldata data) external returns (bytes32) {
        require(gasLimit <= maxGasPerTx, "Exceeded gas limit");
        bytes memory message = abi.encode(nonce, msg.sender, receiver, chainId, gasLimit, data);
        bytes32 messageRoot = keccak256(message);
        messages[nonce] = messageRoot;
        emit SentMessage(nonce++, messageRoot, message);
        return messageRoot;
    }

    struct Vars {
        // We need this struct because otherwise we get a stack too deep error
        uint256 nonce;
        address sender;
        address receiver;
        uint16 chainId;
        uint256 gasLimit;
        bytes data;
    }

    function executeMessage(uint64 slot, bytes calldata message, bytes[] calldata accountProof, bytes[] calldata storageProof) external returns (bool) {
        Vars memory vars;
        bytes32 messageRoot = keccak256(message);
        (
            vars.nonce,
            vars.sender,
            vars.receiver,
            vars.chainId,
            vars.gasLimit,
            vars.data
        ) = abi.decode(message, (uint256, address, address, uint16, uint256, bytes));
        require(executionStatus[messageRoot] == ExecutionStatus.NOT_EXECUTED, "TrustlessAMB: message already executed");
        require(vars.chainId == chainId, "TrustlessAMB: wrong chainId");

        {
            bytes32 executionStateRoot = lightClient.executionStateRoot(slot);
            require(executionStateRoot != bytes32(0), "TrustlessAMB: execution state root not found");

            // Verify the accountProof and get storageRoot
            bytes32 storageRoot = HeaderProof.verifyAccount(accountProof, otherSideAMB, executionStateRoot);

            // Verify the storageProof
            bytes32 slotKey = keccak256(abi.encode(keccak256(abi.encode(vars.nonce, 0))));
            uint256 slotValue = HeaderProof.verifyStorage(slotKey, storageRoot, storageProof);
            require(bytes32(slotValue) == messageRoot, "TrustlessAMB: invalid message hash");
        }

        bool status;
        {
            require(messageId == EMPTY_MESSAGE_ID, "TrustlessAMB: different message execution in progress");
            messageId = messageRoot;
            messageSender = vars.sender;
            // ensure enough gas for the call + 3 SSTORE + event
            require((gasleft() * 63) / 64 > vars.gasLimit + 40000, "TrustlessAMB: insufficient gas");
            bytes memory recieveCall = abi.encodeWithSignature("receiveSuccinct(address,bytes)", messageSender, vars.data);
            (status,) = vars.receiver.call{gas: vars.gasLimit}(recieveCall);
            messageId = EMPTY_MESSAGE_ID;
            messageSender = EMPTY_ADDRESS;
        }

        {
            executionStatus[messageRoot] = status ? ExecutionStatus.EXECUTION_SUCCEEDED : ExecutionStatus.EXECUTION_FAILED;
            emit ExecutedMessage(vars.nonce, messageRoot, message, status);
        }
    }

}