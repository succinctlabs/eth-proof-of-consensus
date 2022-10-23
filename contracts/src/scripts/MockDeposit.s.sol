// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../bridge/Bridge.sol";
import "../amb/TrustlessAMB.sol";


contract Deploy is Script {
	function run() external {
		vm.startBroadcast();
        address DUMMY_ADDRESS = 0x5b8834AfE3EB059c5ACd7300d23831D4779fB682;
        address WITHDRAW_ADDRESS = 0xEFc56627233b02eA95bAE7e19F648d7DcD5Bb132;
        address TOKEN_ADDRESS = 0x0b7108E278c2E77E4e4f5c93d9E5e9A11AC837FC;
        AMB amb = new AMB(DUMMY_ADDRESS, 1000000, DUMMY_ADDRESS);
        DepositMock deposit = new DepositMock(amb, WITHDRAW_ADDRESS, uint16(100));
        deposit.setMapping(TOKEN_ADDRESS, TOKEN_ADDRESS);
        deposit.deposit(address(this), 100, TOKEN_ADDRESS);
		vm.stopBroadcast();
	}
}
