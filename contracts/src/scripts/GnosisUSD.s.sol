// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../bridge/Tokens.sol";

contract Deploy is Script {
	function run() external {
		vm.startBroadcast();
		GnosisUSD g = new GnosisUSD(1000, msg.sender);
		vm.stopBroadcast();
	}
}
