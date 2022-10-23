# We use this for deploying the deposit contract mock for generating proof for testing
CURRENT_UNIX_TIME=`date +%s`
mkdir -p logs
source ../../../.env

forge script MockDeposit.s.sol:Deploy \
  --rpc-url ${GOERLI_RPC_URL} \
  --chain-id ${GOERLI_CHAIN_ID} \
  --private-key ${GOERLI_PRIVATE_KEY} \
  --verify \
  --broadcast \
  --etherscan-api-key ${ETHERSCAN_API_KEY} \
  -vvvv \
  | tee logs/deposit_${CURRENT_UNIX_TIME}.log