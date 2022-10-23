pragma solidity 0.8.14;

import "../BeaconLightClient.sol";

interface IBeaconLightClient {
    function head() external view returns (uint64);

    function headers(uint64 slot) external view returns (BeaconBlockHeader memory);

    function optimisticHead() external view returns (BeaconBlockHeader memory);

    function stateRoot(uint64 slot) external view returns (bytes32);

    function executionStateRoot(uint64 slot) external view returns (bytes32);
}