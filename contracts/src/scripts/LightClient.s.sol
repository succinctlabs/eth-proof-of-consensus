// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "../lightclient/BeaconLightClient.sol";

contract Deploy is Script {
	function run() external {
		vm.startBroadcast();

    // To get these parameters, run npx tsx src/operator/initialize.ts

    bytes32 GENESIS_VALIDATORS_ROOT = 0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb;
    uint256 GENESIS_TIME = 1616508000;
    uint256 SECONDS_PER_SLOT = 12;
    bytes4 FORK_VERSION = 0x02001020;
    uint256 SYNC_COMMITTEE_PERIOD = 497;
    bytes32 SYNC_COMMITTEE_ROOT = 0x73baef55ba62659eb5c700b72d198ac222d18a4e7a2b0b23901c4923f8cc5e64;
    bytes32 SYNC_COMMITTEE_POSEIDON = 0x1976d6374aaffe72de1ea570e6c31e947b0db450dbe42baed5751132adb161e9;

    new BeaconLightClient(
        GENESIS_VALIDATORS_ROOT,
        GENESIS_TIME,
        SECONDS_PER_SLOT,
        FORK_VERSION,
        SYNC_COMMITTEE_PERIOD,
        SYNC_COMMITTEE_ROOT,
        SYNC_COMMITTEE_POSEIDON
    );

		vm.stopBroadcast();
	}
}
