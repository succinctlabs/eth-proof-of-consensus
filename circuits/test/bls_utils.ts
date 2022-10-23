/*
  noble-bls12-381 - MIT License (c) 2019 Paul Miller (paulmillr.com)
  This file is used to generate test cases for circuits that use functions related to the BLS12-381 curve.
  The original source file is from: https://github.com/paulmillr/noble-bls12-381/blob/main/index.ts.
*/

// bls12-381 is a construction of two curves:
// 1. Fp: (x, y)
// 2. Fp₂: ((x₁, x₂+i), (y₁, y₂+i)) - (complex numbers)
//
// Bilinear Pairing (ate pairing) is used to combine both elements into a paired one:
//   Fp₁₂ = e(Fp, Fp2)
//   where Fp₁₂ = 12-degree polynomial
// Pairing is used to verify signatures.
//
// We are using Fp for private keys (shorter) and Fp2 for signatures (longer).
// Some projects may prefer to swap this relation, it is not supported for now.

import nodeCrypto from "crypto";
import { PointG1, PointG2 } from "@noble/bls12-381";

// To verify curve parameters, see pairing-friendly-curves spec:
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-pairing-friendly-curves-09
// Basic math is done over finite fields over p.
// More complicated math is done over polynominal extension fields.
// To simplify calculations in Fp12, we construct extension tower:
// Fp₁₂ = Fp₆² => Fp₂³
// Fp(u) / (u² - β) where β = -1
// Fp₂(v) / (v³ - ξ) where ξ = u + 1
// Fp₆(w) / (w² - γ) where γ = v
export const CURVE = {
  // G1 is the order-q subgroup of E1(Fp) : y² = x³ + 4, #E1(Fp) = h1q, where
  // characteristic; z + (z⁴ - z² + 1)(z - 1)²/3
  P: 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaabn,
  // order; z⁴ − z² + 1
  r: 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001n,
  // cofactor; (z - 1)²/3
  h: 0x396c8c005555e1568c00aaab0000aaabn,
  // generator's coordinates
  // x = 3685416753713387016781088315183077757961620795782546409894578378688607592378376318836054947676345821548104185464507
  // y = 1339506544944476473020471379941921221584933875938349620426543736416511423956333506472724655353366534992391756441569
  Gx: 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bbn,
  Gy: 0x08b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1n,
  b: 4n,

  // G2 is the order-q subgroup of E2(Fp²) : y² = x³+4(1+√−1),
  // where Fp2 is Fp[√−1]/(x2+1). #E2(Fp2 ) = h2q, where
  // G² - 1
  // h2q
  P2:
    0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaabn *
      0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaabn -
    1n,
  // cofactor
  h2: 0x5d543a95414e7f1091d50792876a202cd91de4547085abaa68a205b2e5a7ddfa628f1cb4d9e82ef21537e293a6691ae1616ec6e786f0c70cf1c38e31c7238e5n,
  G2x: [
    0x024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8n,
    0x13e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7en,
  ],
  // y =
  // 927553665492332455747201965776037880757740193453592970025027978793976877002675564980949289727957565575433344219582,
  // 1985150602287291935568054521177171638300868978215655730859378665066344726373823718423869104263333984641494340347905
  G2y: [
    0x0ce5d527727d6e118cc9cdc6da2e351aadfd9baa8cbdd3a76d429a695160d12c923ac9cc3baca289e193548608b82801n,
    0x0606c4a02ea734cc32acd2b02bc28b99cb3e287e85a763af267492ab572e99ab3f370d275cec1da1aaa9075ff05f79ben,
  ],
  b2: [4n, 4n],
  // The BLS parameter x for BLS12-381
  x: 0xd201000000010000n,
  h2Eff:
    0xbc69f08f2ee75b3584c6a0ea91b352888e2a8e9145ad7689986ff031508ffe1329c2f178731db956d82bf015d1212b02ec0ec69d7477c1ae954cbc06689f6a359894c0adebbf6b4e8020005aaa95551n,
};

export function mod(a: bigint, b: bigint) {
  const res = a % b;
  return res >= 0n ? res : b + res;
}

const SHA256_DIGEST_SIZE = 32;

// Default hash_to_field options are for hash to G2.
//
// Parameter definitions are in section 5.3 of the spec unless otherwise noted.
// Parameter values come from section 8.8.2 of the spec.
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-8.8.2
//
// Base field F is GF(p^m)
// p = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
// m = 2 (or 1 for G1 see section 8.8.1)
// k = 128
export const htfDefaults = {
  // DST: a domain separation tag
  // defined in section 2.2.5
  DST: "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_", // to comply with https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#bls-signatures
  // p: the characteristic of F
  //    where F is a finite field of characteristic p and order q = p^m
  p: CURVE.P,
  // m: the extension degree of F, m >= 1
  //     where F is a finite field of characteristic p and order q = p^m
  m: 2,
  // k: the target security level for the suite in bits
  // defined in section 5.1
  k: 128,
  // option to use a message that has already been processed by
  // expand_message_xmd
  expand: true,
};

// Global symbol available in browsers only. Ensure we do not depend on @types/dom
declare const self: Record<string, any> | undefined;
const crypto: { node?: any; web?: any } = {
  node: nodeCrypto,
  web: typeof self === "object" && "crypto" in self ? self.crypto : undefined,
};

export const utils = {
  hashToField: hash_to_field,
  bytesToHex,
  sha256: async (message: Uint8Array): Promise<Uint8Array> => {
    if (crypto.web) {
      const buffer = await crypto.web.subtle.digest("SHA-256", message.buffer);
      return new Uint8Array(buffer);
    } else if (crypto.node) {
      return Uint8Array.from(
        crypto.node.createHash("sha256").update(message).digest()
      );
    } else {
      throw new Error("The environment doesn't have sha256 function");
    }
  },
  mod,
};

const hexes = Array.from({ length: 256 }, (v, i) =>
  i.toString(16).padStart(2, "0")
);
export function bytesToHex(uint8a: Uint8Array): string {
  // pre-caching chars could speed this up 6x.
  let hex = "";
  for (let i = 0; i < uint8a.length; i++) {
    hex += hexes[uint8a[i]];
  }
  return hex;
}

export function formatHex(str: string): string {
  if (str.startsWith("0x")) {
    str = str.slice(2);
  }
  return str;
}

export function hexToBytes(hex: string): Uint8Array {
  if (typeof hex !== "string") {
    throw new TypeError("hexToBytes: expected string, got " + typeof hex);
  }
  hex = formatHex(hex);
  if (hex.length % 2)
    throw new Error("hexToBytes: received invalid unpadded hex");
  const array = new Uint8Array(hex.length / 2);
  for (let i = 0; i < array.length; i++) {
    const j = i * 2;
    const hexByte = hex.slice(j, j + 2);
    if (hexByte.length !== 2) throw new Error("Invalid byte sequence");
    const byte = Number.parseInt(hexByte, 16);
    if (Number.isNaN(byte) || byte < 0)
      throw new Error("Invalid byte sequence");
    array[i] = byte;
  }
  return array;
}

export function hexToIntArray(hex: string): BigInt[] {
  if (typeof hex !== "string") {
    throw new TypeError("hexToBytes: expected string, got " + typeof hex);
  }
  hex = formatHex(hex);
  if (hex.length % 2)
    throw new Error("hexToBytes: received invalid unpadded hex");
  const array = [];
  for (let i = 0; i < hex.length / 2; i++) {
    const j = i * 2;
    const hexByte = hex.slice(j, j + 2);
    if (hexByte.length !== 2) throw new Error("Invalid byte sequence");
    const byte = Number.parseInt(hexByte, 16);
    if (Number.isNaN(byte) || byte < 0) {
      console.log(hexByte, byte);
      throw new Error("Invalid byte sequence");
    }
    array.push(BigInt(byte));
  }
  return array;
}

function ensureBytes(hex: string | Uint8Array): Uint8Array {
  // Uint8Array.from() instead of hash.slice() because node.js Buffer
  // is instance of Uint8Array, and its slice() creates **mutable** copy
  return hex instanceof Uint8Array ? Uint8Array.from(hex) : hexToBytes(hex);
}

export function concatBytes(...arrays: Uint8Array[]): Uint8Array {
  if (arrays.length === 1) return arrays[0];
  const length = arrays.reduce((a, arr) => a + arr.length, 0);
  const result = new Uint8Array(length);
  for (let i = 0, pad = 0; i < arrays.length; i++) {
    const arr = arrays[i];
    result.set(arr, pad);
    pad += arr.length;
  }
  return result;
}

// UTF8 to ui8a
function stringToBytes(str: string) {
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) {
    bytes[i] = str.charCodeAt(i);
  }
  return bytes;
}

// Octet Stream to Integer
function os2ip(bytes: Uint8Array): bigint {
  let result = 0n;
  for (let i = 0; i < bytes.length; i++) {
    result = result * 256n;
    result += BigInt(bytes[i]);
  }
  return result;
}

// Integer to Octet Stream
export function i2osp(value: number, length: number): Uint8Array {
  if (value < 0 || value >= 1 << (8 * length)) {
    throw new Error(`bad I2OSP call: value=${value} length=${length}`);
  }
  const res = Array.from({ length }).fill(0) as number[];
  for (let i = length - 1; i >= 0; i--) {
    res[i] = value & 0xff;
    value >>>= 8;
  }
  return new Uint8Array(res);
}

function strxor(a: Uint8Array, b: Uint8Array): Uint8Array {
  const arr = new Uint8Array(a.length);
  for (let i = 0; i < a.length; i++) {
    arr[i] = a[i] ^ b[i];
  }
  return arr;
}

// Produces a uniformly random byte string using a cryptographic hash function H that outputs b bits
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-5.4.1
async function expand_message_xmd(
  msg: Uint8Array,
  DST: Uint8Array,
  lenInBytes: number
): Promise<Uint8Array> {
  // console.log("expand_message_xmd", msg, DST, lenInBytes);
  const H = utils.sha256;
  const b_in_bytes = SHA256_DIGEST_SIZE;
  const r_in_bytes = b_in_bytes * 2;

  const ell = Math.ceil(lenInBytes / b_in_bytes);
  if (ell > 255) throw new Error("Invalid xmd length");
  const DST_prime = concatBytes(DST, i2osp(DST.length, 1));
  const Z_pad = i2osp(0, r_in_bytes);
  const l_i_b_str = i2osp(lenInBytes, 2);
  const b = new Array<Uint8Array>(ell);
  const b_0 = await H(
    concatBytes(Z_pad, msg, l_i_b_str, i2osp(0, 1), DST_prime)
  );
  b[0] = await H(concatBytes(b_0, i2osp(1, 1), DST_prime));
  for (let i = 1; i <= ell; i++) {
    const args = [strxor(b_0, b[i - 1]), i2osp(i + 1, 1), DST_prime];
    b[i] = await H(concatBytes(...args));
  }
  const pseudo_random_bytes = concatBytes(...b);
  return pseudo_random_bytes.slice(0, lenInBytes);
}

// hashes arbitrary-length byte strings to a list of one or more elements of a finite field F
// https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-hash-to-curve-11#section-5.3
// Inputs:
// msg - a byte string containing the message to hash.
// count - the number of elements of F to output.
// Outputs:
// [u_0, ..., u_(count - 1)], a list of field elements.
async function hash_to_field(
  msg: Uint8Array,
  count: number,
  options = {}
): Promise<bigint[][]> {
  // if options is provided but incomplete, fill any missing fields with the
  // value in hftDefaults (ie hash to G2).
  const htfOptions = { ...htfDefaults, ...options };
  const log2p = htfOptions.p.toString(2).length;
  const L = Math.ceil((log2p + htfOptions.k) / 8); // section 5.1 of ietf draft link above
  const len_in_bytes = count * htfOptions.m * L;
  const DST = stringToBytes(htfOptions.DST);

  let pseudo_random_bytes = msg;
  if (htfOptions.expand) {
    pseudo_random_bytes = await expand_message_xmd(msg, DST, len_in_bytes);
    // console.log("result", pseudo_random_bytes.toString());
  }
  const u = new Array(count);
  for (let i = 0; i < count; i++) {
    const e = new Array(htfOptions.m);
    for (let j = 0; j < htfOptions.m; j++) {
      const elm_offset = L * (j + i * htfOptions.m);
      const tv = pseudo_random_bytes.slice(elm_offset, elm_offset + L);
      e[j] = mod(os2ip(tv), htfOptions.p);
    }
    u[i] = e;
  }

  return u;
}

export function point_to_bigint(point: PointG1): [bigint, bigint] {
  let [x, y] = point.toAffine();
  return [x.value, y.value];
}

export function bigint_to_array(n: number, k: number, x: bigint) {
  let mod: bigint = 1n;
  for (let idx = 0; idx < n; idx++) {
    mod = mod * 2n;
  }

  let ret: string[] = [];
  var x_temp: bigint = x;
  for (let idx = 0; idx < k; idx++) {
    ret.push((x_temp % mod).toString());
    x_temp = x_temp / mod;
  }
  return ret;
}

export async function msg_hash(
  message: string | Uint8Array,
  returnType: "array" | "hex" = "array"
) {
  let msg;
  if (typeof message === "string") {
    msg = stringToBytes(message);
  } else {
    msg = message;
  }
  msg = msg as unknown as Uint8Array;

  let u = await hash_to_field(msg, 2);

  if (returnType === "hex") {
    return [
      ["0x" + u[0][0].toString(16), "0x" + u[0][1].toString(16)],
      ["0x" + u[1][0].toString(16), "0x" + u[1][1].toString(16)],
    ];
  } else {
    return [
      [bigint_to_array(55, 7, u[0][0]), bigint_to_array(55, 7, u[0][1])],
      [bigint_to_array(55, 7, u[1][0]), bigint_to_array(55, 7, u[1][1])],
    ];
  }
}

export function sigHexAsSnarkInput(
  signatureHex: string,
  returnType: "array" | "hex" = "array"
) {
  const sig = PointG2.fromSignature(formatHex(signatureHex));
  sig.assertValidity();
  if (returnType === "hex") {
    return [
      [
        "0x" + sig.toAffine()[0].c[0].value.toString(16),
        "0x" + sig.toAffine()[0].c[1].value.toString(16),
      ],
      [
        "0x" + sig.toAffine()[1].c[0].value.toString(16),
        "0x" + sig.toAffine()[1].c[1].value.toString(16),
      ],
    ];
  } else {
    return [
      [
        bigint_to_array(55, 7, sig.toAffine()[0].c[0].value),
        bigint_to_array(55, 7, sig.toAffine()[0].c[1].value),
      ],
      [
        bigint_to_array(55, 7, sig.toAffine()[1].c[0].value),
        bigint_to_array(55, 7, sig.toAffine()[1].c[1].value),
      ],
    ];
  }
}

export async function msg_uint_8_to_array(message: Uint8Array) {
  let u = await hash_to_field(message, 2);
  return [
    [bigint_to_array(55, 7, u[0][0]), bigint_to_array(55, 7, u[0][1])],
    [bigint_to_array(55, 7, u[1][0]), bigint_to_array(55, 7, u[1][1])],
  ];
}

// msg_uint_8_to_array(stringToBytes("abcdefghij"));
