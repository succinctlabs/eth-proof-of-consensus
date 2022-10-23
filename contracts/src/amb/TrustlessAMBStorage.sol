pragma solidity 0.8.14;

import "./interfaces/ITrustlessAMB.sol";
import "../lightclient/interfaces/IBeaconLightClient.sol";

abstract contract TrustlessAMBStorage is ITrustlessAMB {
    mapping(uint256 => bytes32) public messages;
    mapping(bytes32 => ExecutionStatus) public executionStatus;
    uint256 chainId;

    IBeaconLightClient public lightClient;
    address public otherSideAMB;

    uint256 public nonce;
    uint256 public maxGasPerTx;

    address public messageSender;
    bytes32 public messageId;
}
