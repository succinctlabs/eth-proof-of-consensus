# Trustless price oracle for ETH/stETH Curve pool

A trustless oracle for the ETH/stETH Curve pool using Merkle Patricia proofs of Ethereum state.

The oracle assumes that the pool's `fee` and `A` (amplification coefficient) values don't
change between the time of proof generation and submission.


## Audits

Commits [`1033b3e`] and [`ae093b3`] (the currently deployed version) were audited by MixBytes.
Contracts in both commits were assumed as secure to use according to the auditors' security
criteria. See [the full report] for details.

[`1033b3e`]: https://github.com/lidofinance/curve-merkle-oracle/tree/1033b3e84142317ffd8f366b52e489d5eb49c73f
[`ae093b3`]: https://github.com/lidofinance/curve-merkle-oracle/tree/ae093b308999a564ed3f23d52c6c5dce946dbfa7
[the full report]: https://github.com/lidofinance/audits/blob/main/MixBytes%20stETH%20price%20oracle%20Security%20Audit%20Report%2005-2021.pdf


## Mechanics

The oracle works by generating and verifying Merkle Patricia proofs of the following Ethereum state:

* Curve stETH/ETH pool contract account and the following slots from its storage trie:
  * `admin_balances[0]`
  * `admin_balances[1]`

* stETH contract account and the following slots from its storage trie:
  * `shares[0xDC24316b9AE028F1497c275EB9192a3Ea0f67022]`
  * `keccak256("lido.StETH.totalShares")`
  * `keccak256("lido.Lido.beaconBalance")`
  * `keccak256("lido.Lido.bufferedEther")`
  * `keccak256("lido.Lido.depositedValidators")`
  * `keccak256("lido.Lido.beaconValidators")`


## Contracts

The repo contains two main contracts:

* [`StableSwapStateOracle.sol`] is the main oracle contract. It receives and verifies the report
  from the offchain code, and persists the verified state along with its timestamp.

* [`StableSwapPriceHelper.vy`] is a helper contract used by `StableSwapStateOracle.sol` and written
  in Vyper. It contains the code for calculating exchange price based on the values of pool's storage
  slots. The code is copied from the [actual pool contract] with minimal modifications.

[`StableSwapStateOracle.sol`]: ./contracts/StableSwapStateOracle.sol
[`StableSwapPriceHelper.vy`]: ./contracts/StableSwapPriceHelper.vy
[actual pool contract]: https://github.com/curvefi/curve-contract/blob/3fa3b6c/contracts/pools/steth/StableSwapSTETH.vy


## Deploying and using the contracts

First, deploy `StableSwapPriceHelper`. Then, deploy `StableSwapStateOracle`, pointing it
to `StableSwapPriceHelper` using the constructor param:

```python
# assuming eth-brownie console

helper = StableSwapPriceHelper.deploy({ 'from': deployer })

price_update_threshold = 300 # 3%
price_update_threshold_admin = deployer

oracle = StableSwapStateOracle.deploy(
  helper,
  price_update_threshold_admin,
  price_update_threshold,
  { 'from': deployer }
)
```

To send proofs to the state oracle, call the `submitState` function:

```python
header_rlp_bytes = '0x...'
proofs_rlp_bytes = '0x...'

tx = oracle.submitState(header_rlp_bytes, proofs_rlp_bytes, { 'from': reporter })
```

The function is permissionless and, upon successful verification, will generate two events,
`SlotValuesUpdated` and `PriceUpdated`, and update the oracle with the verified pool balances
and stETH price. You can access them by calling `getState` and `getPrice`:

```python
(timestamp, etherBalance, stethBalance, stethPrice) = oracle.getState()
stethPrice = oracle.getPrice()
print("stETH/ETH price:", stethPrice / 10**18)
```


## Sending oracle transaction

Use the following script to generate and submit a proof to the oracle contract:

```
python offchain/generate_steth_price_proof.py \
  --rpc <HTTP RPC endpoint of a geth full node> \
  --keyfile <path to a JSON file containing an encrypted private key> \
  --gas-price <tx gas price in wei> \
  --contract <state oracle contract address> \
  --block <block number>
```

Some flags are optional:

* Skip the `--keyfile` flag to print the proof without sending a tx.
* Skip the `--gas-price` flag to use gas price determined by the node.
* Skip the `--block` flag to generate a proof correnspoding to the block `latest - 15`.
