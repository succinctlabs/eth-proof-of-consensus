CURRENT_UNIX_TIME=`date +%s`
mkdir -p logs
source ../../../.env

forge script Deposit.s.sol:Deploy \
  --rpc-url ${GOERLI_RPC_URL} \
  --chain-id ${GOERLI_CHAIN_ID} \
  --private-key ${GOERLI_PRIVATE_KEY} \
  --broadcast \
  --verify \
  --etherscan-api-key ${ETHERSCAN_API_KEY} \
  -vvvv \
  | tee logs/deposit_${CURRENT_UNIX_TIME}.log