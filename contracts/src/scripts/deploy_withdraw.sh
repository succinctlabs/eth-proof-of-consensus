CURRENT_UNIX_TIME=`date +%s`
mkdir -p logs
source ../../../.env

forge script Withdraw.s.sol:Deploy \
  --rpc-url ${GNOSIS_RPC_URL} \
  --chain-id ${GNOSIS_CHAIN_ID} \
  --private-key ${GNOSIS_PRIVATE_KEY} \
  --broadcast \
  --verify \
  --etherscan-api-key ${BLOCKSCOUT_API_KEY} \
  -vvvv \
  | tee logs/withdraw_${CURRENT_UNIX_TIME}.log