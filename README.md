# Proof of Consensus for Ethereum

[![Twitter URL](https://img.shields.io/twitter/follow/succinctlabs?style=social)](https://twitter.com/succinctlabs)

## Overview

At Succinct Labs, we are aiming to build the foundation of a decentralized, permissionless, trust-minimized interoperability layer for Ethereum and other blockchains. In our first [blog post](https://blog.succinct.xyz/post/2022/09/20/proof-of-consensus/) we outlined a vision towards the end-game of interoperability that uses SNARKs to generate succinct proofs of consensus, which can power gas-efficient on-chain light clients. Our first proof of consensus implementation is for the Ethereum sync committee protocol, which we have a more detailed technical explanation of in our latest [blog post](...). As a demonstration, we implement a proof of concept bridge between Goerli (Ethereum test net) and Gnosis Chain.

This repository contains both the zkSNARK circuits as well as the smart contracts needed for our succinct light client implementation, as well as prototype message passing contracts and bridge contracts.

**It is important to note this code is unaudited and is NOT ready for production use.** We are working very closely with several auditors and the Gnosis Chain core team to turn this prototype into something production ready. Both our circuits and our smart contracts are a starting point for a production implementation. Thoughtful design around appropriate guardrails and failsafes will be critical when deploying a production system with this new technology.

## Circuits

Our circuits are used to generate a proof of verification of an aggregate BLS signature from at least 2/3s of the sync committee for a particular block header. There are 2 main relevant entry-points: `assert_valid_signed_header.circom`, which generates a proof for BLS signature verification and `sync_committee_committments.circom` which generates a proof mapping the `SSZ` committment for the sync committee validator public keys to a poseidon committment, which is crucial to reducing the number of constraints in the `assert_valid_signed_header` SNARK. More details can be found in our blog post linked above.

## Contracts

The smart contracts contain 3 subfolders that map to different parts of our implementation
* The `lightclient` folder contains the implementation of the succinct light client in Solidity, that can get updated with zkSNARKs generated from the sync committee attestations.
* The `AMB` folder contains an arbitrary message passing bridge, inspired by the Gnosis omnibridge [AMB](https://github.com/omni/tokenbridge-contracts) that uses the light client to pass arbitrary messages from one chain to another. The light client is used to retrieve the state root of Ethereum in the Gnosis smart contract, and this state root is used to verify that a particular message was "sent" on Ethereum. 
* The `bridge` folder contains a very simplistic implementation of a demo token bridge that allows a user to transfer "Succincts" (an ERC-20 we deployed on Goerli) from Goerli to Gnosis. Once the user deposits into the deposit bridge contract, the deposit bridge contract passes a message to the AMB. After the message is relayed to the AMB on the other side, the Gnosis AMB executes the message after verifying that the same message is indeed contained in the storage of the AMB on Goerli. This is done by the Gnosis AMB calling the light client smart contract and verifying a storage proof against the Goerli state root stored in the light client.

These contracts are **prototypes** that serve as a useful proof of concept to demonstrate how such a succinct light-client based bridge design might work. We are closely working with the Gnosis Chain team to develop a production-ready specification of a light-client and AMB with that can appropriately handle edge cases and has the appropriate guardrails for this very new zkSNARK technology.
