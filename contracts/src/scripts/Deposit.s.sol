// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.10;

// import "forge-std/Script.sol";
// import "../bridge/Bridge.sol";

// contract Deploy is Script {
// 	function run() external {
// 		vm.startBroadcast();
// 		Deposit deposit = new Deposit();
// 		address GNOSIS_USD = 0x5b8834AfE3EB059c5ACd7300d23831D4779fB682;
// 		address GOERLI_USD = 0x45cD94330AC3aeA42cc21Cf9315B745e27e768BD;
// 		deposit.setMapping(GOERLI_USD, GNOSIS_USD);
// 		vm.stopBroadcast();
// 	}
// }
