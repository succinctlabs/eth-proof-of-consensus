forge build --extra-output-files abi --out abi
cp abi/Bridge.sol/Deposit.abi.json ../tesseract/lib/abi/Deposit.abi.json
cp abi/Bridge.sol/Withdraw.abi.json ../tesseract/lib/abi/Withdraw.abi.json
cp abi/BeaconLightClient.sol/BeaconLightClient.abi.json ../tesseract/lib/abi/BeaconLightClient.abi.json
cp abi/IERC20.sol/IERC20.abi.json ../tesseract/lib/abi/IERC20.abi.json
cp abi/Tokens.sol/GoerliUSD.abi.json ../tesseract/lib/abi/GoerliUSD.abi.json
cp abi/TrustlessAMB.sol/AMB.abi.json ../tesseract/lib/abi/AMB.abi.json