pragma solidity 0.8.14;

import "../../lightclient/interfaces/IBeaconLightClient.sol";

interface ITrustlessAMB {
    enum ExecutionStatus {
        NOT_EXECUTED,       // b'00
        INVALID,            // b'01
        EXECUTION_FAILED,   // b'10
        EXECUTION_SUCCEEDED // b'11
    }
    event SentMessage(uint256 indexed nonce, bytes32 indexed msgHash, bytes message);
    event ExecutedMessage(uint256 indexed nonce, bytes32 indexed msgHash, bytes message, bool status);

    function lightClient() external view returns (IBeaconLightClient);

    // function messageId() external view returns (bytes32);

    // function messageSender() external view returns (address);

    function send(
        address receiver,
        uint16 chainId,
        uint256 gasLimit,
        bytes calldata data
    ) external returns (bytes32);

    function executeMessage(
        uint64 slot,
        bytes calldata message,
        bytes[] calldata accountProof,
        bytes[] calldata storageProof
    ) external returns (bool);

    // function messageCallStatus(bytes32 _messageId) external view returns (bool);
}