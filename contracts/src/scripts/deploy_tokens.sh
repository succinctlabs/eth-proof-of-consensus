CURRENT_UNIX_TIME=`date +%s`
mkdir -p logs
source ../../../.env

forge script GoerliUSD.s.sol:Deploy \
  --rpc-url ${GOERLI_RPC_URL} \
  --chain-id ${GOERLI_CHAIN_ID} \
  --private-key ${GOERLI_PRIVATE_KEY} \
  --broadcast \
  --verify \
  --etherscan-api-key ${ETHERSCAN_API_KEY} \
  -vvvv \
  | tee logs/ropsten_usd_${CURRENT_UNIX_TIME}.log

forge script GnosisUSD.s.sol:Deploy \
  --rpc-url ${GNOSIS_RPC_URL} \
  --chain-id ${GNOSIS_CHAIN_ID} \
  --private-key ${GNOSIS_PRIVATE_KEY} \
  --broadcast \
  --verify \
  --etherscan-api-key ${BLOCKSCOUT_API_KEY} \
  -vvvv \
  | tee logs/gnosis_usd_${CURRENT_UNIX_TIME}.log