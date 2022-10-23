pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "../../lightclient/Structs.sol";

contract BeaconLightClientMock {
    uint256 public head;
    mapping(uint256 => BeaconBlockHeader) public headers;
    mapping(uint64 => bytes32) public executionStateRoots;

    function setHead(uint256 slot, BeaconBlockHeader memory header) external {
        head = slot;
        headers[slot] = header;
    }

    function stateRoot(uint256 slot) external view returns (bytes32) {
        return headers[slot].stateRoot;
    }

    function setExecutionRoot(uint64 slot, bytes32 executionRoot) external {
        executionStateRoots[slot] = executionRoot;
    }

    function executionStateRoot(uint64 slot) external view returns (bytes32) {
        return executionStateRoots[slot];
    }


}
