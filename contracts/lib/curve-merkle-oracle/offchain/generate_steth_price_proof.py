import math
import argparse
import json
import sys
import os
from pprint import pprint
from getpass import getpass

from web3 import Web3
from web3.logs import DISCARD
import requests
import rlp

from state_proof import request_block_header, request_account_proof


ORACLE_CONTRACT_ADDRESS = '0x602C71e4DAC47a042Ee7f46E0aee17F94A3bA0B6'


def main():
    parser = argparse.ArgumentParser(
        description="Patricia Merkle Trie Proof Generating Tool",
        formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument("-b", "--block-number",
        help="Block number, defaults to `latest - 15`")

    parser.add_argument("-r", "--rpc",
        default="http://localhost:8545",
        help="URL of a full node RPC endpoint, e.g. http://localhost:8545")

    parser.add_argument("-k", "--keyfile",
        help="Send transaction and sign it using the keyfile at the provided path")

    parser.add_argument("-g", "--gas-price",
        help="Use the specified gas price")

    parser.add_argument("--contract",
        default=ORACLE_CONTRACT_ADDRESS,
        help="Oracle contract address")

    args = parser.parse_args()
    w3 = Web3(Web3.HTTPProvider(args.rpc))

    block_number = args.block_number if args.block_number is not None else w3.eth.block_number - 15
    oracle_contract = get_oracle_contract(args.contract, w3)
    params = oracle_contract.functions.getProofParams().call()

    (block_number, block_header, pool_acct_proof, steth_acct_proof,
        pool_storage_proofs, steth_storage_proofs) = generate_proof_data(
            rpc_endpoint=args.rpc,
            block_number=block_number,
            pool_address=params[0],
            steth_address=params[1],
            pool_slots=params[2:4],
            steth_slots=params[4:10],
        )

    header_blob = rlp.encode(block_header)

    proofs_blob = rlp.encode(
        [pool_acct_proof, steth_acct_proof] +
        pool_storage_proofs +
        steth_storage_proofs
    )

    print(f"\nBlock number: {block_number}\n")
    print("Header RLP bytes:\n")
    print(f"0x{header_blob.hex()}\n")
    print("Proofs list RLP bytes:\n")
    print(f"0x{proofs_blob.hex()}\n")

    if args.keyfile is None:
        return

    print(f"Will send transaction calling `submitState` on {oracle_contract.address}")

    private_key = load_private_key(args.keyfile, w3)
    account = w3.eth.account.privateKeyToAccount(private_key)
    nonce = w3.eth.get_transaction_count(account.address)
    gas_price = int(args.gas_price) if args.gas_price is not None else w3.eth.gas_price

    tx = oracle_contract.functions.submitState(header_blob, proofs_blob).buildTransaction({
        'gasPrice': gas_price,
        'gas': 3000000,
        'nonce': nonce,
    })

    signed = w3.eth.account.sign_transaction(tx, private_key)

    print(f"Sending transaction from {account.address}, gas price {gas_price}...")

    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

    print(f"Transaction sent: {tx_hash.hex()}\nWaiting for inclusion...\n")

    receipt = w3.eth.waitForTransactionReceipt(tx_hash)
    pprint(dict(receipt))

    if int(receipt['status']) != 1:
        print("\nTransaction failed")
    else:
        print_event("SlotValuesUpdated", receipt, oracle_contract)
        print_event("PriceUpdated", receipt, oracle_contract)


def get_oracle_contract(address, w3):
    dir = os.path.dirname(__file__)
    interface_path = os.path.join(dir, '../interfaces/StableSwapStateOracle.json')
    with open(interface_path) as abi_file:
        abi = json.load(abi_file)
        return w3.eth.contract(address=address, abi=abi)


def load_private_key(path, w3):
    with open(path) as keyfile:
        encrypted_key = keyfile.read()
        password = getpass()
        return w3.eth.account.decrypt(encrypted_key, password)


def print_event(name, receipt, contract):
    # https://github.com/ethereum/web3.py/issues/1738
    logs = contract.events[name]().processReceipt(receipt, DISCARD)
    if len(logs) != 0:
        print(f"\n{name} event:")
        for key, value in logs[0]['args'].items():
            print(f"  {key}: {value}")
    else:
        print(f"\nNo {name} event generated")


def generate_proof_data(
    rpc_endpoint,
    block_number,
    pool_address,
    steth_address,
    pool_slots,
    steth_slots,
):
    block_number = \
        block_number if block_number == "latest" or block_number == "earliest" \
        else hex(int(block_number))

    (block_number, block_header) = request_block_header(
        rpc_endpoint=rpc_endpoint,
        block_number=block_number,
    )

    (pool_acct_proof, pool_storage_proofs) = request_account_proof(
        rpc_endpoint=rpc_endpoint,
        block_number=block_number,
        address=pool_address,
        slots=pool_slots,
    )

    (steth_acct_proof, steth_storage_proofs) = request_account_proof(
        rpc_endpoint=rpc_endpoint,
        block_number=block_number,
        address=steth_address,
        slots=steth_slots,
    )

    return (
        block_number,
        block_header,
        pool_acct_proof,
        steth_acct_proof,
        pool_storage_proofs,
        steth_storage_proofs,
    )


if __name__ == "__main__":
    main()
    exit(0)
