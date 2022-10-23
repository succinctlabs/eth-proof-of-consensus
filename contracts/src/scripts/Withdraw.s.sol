
// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.10;

// import "forge-std/Script.sol";
// import "../bridge/Bridge.sol";
// import "../bridge/Tokens.sol";
// import "../lightclient/SimpleSerialize.sol";
// import "../lightclient/LightClient.sol";
// import "../lightclient/Interfaces.sol";

// interface CheatCodes {
// 	function envAddress(string calldata) external returns (address);
// }

// contract Deploy is Script {
// 	function run() external {
// 		vm.startBroadcast();
// 		SimpleSerialize ssz = new SimpleSerialize();
// 		ValidHeaderVerifier validHeaderVerifier = new ValidHeaderVerifier();
// 		SyncCommitteeCommitmentVerifier syncCommitteeCommitmentVerifier = new SyncCommitteeCommitmentVerifier();
// 		ETH2LightClient lightClient = new ETH2LightClient(
// 			ISimpleSerialize(address(ssz)),
// 			IValidHeaderVerifier(address(validHeaderVerifier)),
// 			ISyncCommitteeCommittmentVerifier(address(syncCommitteeCommitmentVerifier)),
// 			"goerli"
// 		);
// 		Withdraw withdraw = new Withdraw(ILightClient(address(lightClient)));
// 		// Mint the GnosisUSD to the Withdraw contract
// 		address GNOSIS_USD = 0x5b8834AfE3EB059c5ACd7300d23831D4779fB682;
// 		address GOERLI_USD = 0x45cD94330AC3aeA42cc21Cf9315B745e27e768BD;
// 		withdraw.setMapping(GOERLI_USD, GNOSIS_USD);
// 		GnosisUSD(GNOSIS_USD).mint(address(withdraw), 100);
// 		vm.stopBroadcast();
// 	}
// }
