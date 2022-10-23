import math
import json

import requests
import rlp

from utils import normalize_bytes, normalize_address, normalize_int, decode_hex, to_0x_string


BLOCK_HEADER_FIELDS = [
    "parentHash", "sha3Uncles", "miner", "stateRoot", "transactionsRoot",
    "receiptsRoot", "logsBloom", "difficulty", "number", "gasLimit",
    "gasUsed", "timestamp", "extraData", "mixHash", "nonce"
]


def request_block_header(rpc_endpoint, block_number):
    r = requests.post(rpc_endpoint, json={
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [block_number, True],
        "id": 1,
    })

    block_dict = get_json_rpc_result(r)
    block_number = normalize_int(block_dict["number"])
    block_header_fields = [normalize_bytes(block_dict[f]) for f in BLOCK_HEADER_FIELDS]

    return (block_number, block_header_fields)


def request_account_proof(rpc_endpoint, block_number, address, slots):
    hex_slots = [to_0x_string(s) for s in slots]

    r = requests.post(rpc_endpoint, json={
        "jsonrpc": "2.0",
        "method": "eth_getProof",
        "params": [address.lower(), hex_slots, to_0x_string(block_number)],
        "id": 1,
    })

    result = get_json_rpc_result(r)

    account_proof = decode_rpc_proof(result["accountProof"])
    storage_proofs = [
        decode_rpc_proof(slot_data["proof"]) for slot_data in result["storageProof"]
    ]

    return (account_proof, storage_proofs)


def decode_rpc_proof(proof_data):
    return [rlp.decode(decode_hex(node)) for node in proof_data]


def get_json_rpc_result(response):
    response.raise_for_status()
    json_dict = response.json()
    if "error" in json_dict:
        raise requests.RequestException(
            f"RPC error { json_dict['error']['code'] }: { json_dict['error']['message'] }",
            response=response
        )
    return json_dict["result"]
