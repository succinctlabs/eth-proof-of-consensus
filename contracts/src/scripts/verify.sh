source ../../../.env

# forge verify-contract \
#     --chain-id ${GOERLI_CHAIN_ID} \
#     --num-of-optimizations 200 \
#     --watch \
#     --constructor-args \
#     $(cast abi-encode "constructor(address,uint256,address)" 0x5b8834AfE3EB059c5ACd7300d23831D4779fB682 1000000 0x5b8834AfE3EB059c5ACd7300d23831D4779fB682) \
#     0x3a8DF2427e335b721824C2D8e627D5816D798048 \
#     src/amb/TrustlessAMB.sol:TrustlessAMB \
#     ${ETHERSCAN_API_KEY}


forge verify-contract \
    --chain-id ${GNOSIS_CHAIN_ID} \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args \
    $(cast abi-encode "constructor(bytes32,uint256,uint256,bytes4,uint256,bytes32,bytes32)" \
        0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb \
        1616508000 \
        12 \
        0x02001020 \
        497 \
        0x73baef55ba62659eb5c700b72d198ac222d18a4e7a2b0b23901c4923f8cc5e64 \
        0x1976d6374aaffe72de1ea570e6c31e947b0db450dbe42baed5751132adb161e9 \
    ) \
    0xa3ae36abaD813241b75b3Bb0e9E7a37aeFD70807 \
    src/lightclient/BeaconLightClient.sol:BeaconLightClient \
    ${ETHERSCAN_API_KEY}