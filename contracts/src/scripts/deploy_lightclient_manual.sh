source ../../../.env
mkdir -p envs
CURRENT_UNIX_TIME=`date +%s`

GNOSIS_NONCE=$(cast nonce --rpc-url $GNOSIS_RPC_URL $GNOSIS_PUBLIC_KEY)
GNOSIS_NONCE_PLUS_ONE=$(($GNOSIS_NONCE+1))

LIGHT_CLIENT_GNOSIS_ADDRESS=$(cast compute-address --nonce $GNOSIS_NONCE $GNOSIS_PUBLIC_KEY | awk '{print $3}')

GENESIS_VALIDATORS_ROOT=0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb
GENESIS_TIME=1616508000
SECONDS_PER_SLOT=12
FORK_VERSION=0x02001020
SYNC_COMMITTEE_PERIOD=494
SYNC_COMMITTEE_ROOT=0x5e66ab4fcfe56396c5bd5f17466766504cf53078ac9751a3cd7bac5ff22b68fb
SYNC_COMMITTEE_POSEIDON=0x194B83AD3B620BC4FAB97BAC4E71E4E98670013ED514EBC2D1F0CCDA431E74D3

# Deploy Deposit Bridge on Goerli
forge create src/lightclient/BeaconLightClient.sol:BeaconLightClient \
  --rpc-url $GOERLI_RPC_URL \
  --private-key $GOERLI_PRIVATE_KEY \
  --constructor-args \
  "$GENESIS_VALIDATORS_ROOT" \
  "$GENESIS_TIME" \
  "$SECONDS_PER_SLOT" \
  "$FORK_VERSION" \
  "$SYNC_COMMITTEE_PERIOD" \
  "$SYNC_COMMITTEE_ROOT" \
  "$SYNC_COMMITTEE_POSEIDON"

# Verify all the contracts
forge verify-contract \
    --chain-id ${GOERLI_CHAIN_ID} \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args \
    $(cast abi-encode "constructor(bytes32,uint256,uint256,bytes4,uint256,bytes32,bytes32)" \
    "$GENESIS_VALIDATORS_ROOT" \
    "$GENESIS_TIME" \
    "$SECONDS_PER_SLOT" \
    "$FORK_VERSION" \
    "$SYNC_COMMITTEE_PERIOD" \
    "$SYNC_COMMITTEE_ROOT" \
    "$SYNC_COMMITTEE_POSEIDON") \
    ${LIGHT_CLIENT_GNOSIS_ADDRESS} \
    src/lightclient/BeaconLightClient.sol:BeaconLightClient \
    ${ETHERSCAN_API_KEY}
