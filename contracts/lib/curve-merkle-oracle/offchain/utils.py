# Partially taken from: https://github.com/ethereum/pyethereum/blob/b704a5c/ethereum/utils.py

import math

from eth_utils import decode_hex, to_canonical_address, to_bytes, to_int, to_hex


def normalize_bytes(x):
    return to_bytes(hexstr=x) if isinstance(x, str) else to_bytes(x)


def normalize_address(x):
    return to_canonical_address(x)


def normalize_int(x):
    if isinstance(x, str) and not x.startswith("0x"):
        x = int(x)
    return to_int(hexstr=x) if isinstance(x, str) else to_int(x)


def to_0x_string(x):
    if isinstance(x, str) and not x.startswith("0x"):
        x = int(x)
    return to_hex(x)
