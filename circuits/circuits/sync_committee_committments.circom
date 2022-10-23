pragma circom 2.0.3;

include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/binsum.circom";
include "./simple_serialize.circom";
include "./pubkey_poseidon.circom";


/**
 * Asserts that the byte representation of a BLS12-381 public key's x-coordinate matches the BigInt representation
 * @param  n           The number of bits to use per register
 * @param  k           The number of registers
 * @param  num_bytes   The number of input bytes
 * @input  pubkeyX     The BLS12-381 public key's x-coordinate in BigInt form
 * @output pubkeyBytes THe BLS12-381 public key's x-coordinate in byte form
 */
template AssertPubkeyBytesMatchesPubkeyXBigIntNoCheck(n, k, num_bytes) {
    // This is code from noble bls we are copying
    // const compressedValue = bytesToNumberBE(bytes);
    // const bflag = mod(compressedValue, POW_2_383) / POW_2_382;
    //   if (bflag === 1n) {
    //     return this.ZERO;
    //   }
    //   const x = new Fp(mod(compressedValue, POW_2_381));
    // Note: this does NOT check that pubkeyX, pubkeyY is on the curve

    signal input pubkeyX[k];
    signal input pubkeyBytes[num_bytes];

    component convertBytesToBits[num_bytes];
    for (var i=0; i < num_bytes; i++) {
        convertBytesToBits[i] = Num2Bits(8);
        convertBytesToBits[i].in <== pubkeyBytes[i];
    }

    signal pubkeyBitsConcat[num_bytes * 8];

    for (var i=num_bytes-1; i >= 0; i--) {
        for (var j=0; j < 8; j++) {
            pubkeyBitsConcat[(num_bytes-1 - i)*8 + j] <== convertBytesToBits[i].out[j]; // returns as little endian
        }
    }

    component convertBitsToBigInt[k];
    // Now stride through the concat bits with the (n,k) stride
    for (var i=0; i < k; i++) { // k = 7
        convertBitsToBigInt[i] = Bits2Num(n);
        for (var j=0; j < n; j++) { // n = 55
            // Edge case here where i*n + j > num_bytes * 8
            // We also want to zero out all bits >= 381 because we take it mod 2^381
            if (i*n + j >= num_bytes * 8 || i*n + j >= 381) {
                convertBitsToBigInt[i].in[j] <== 0;
            } else {
                convertBitsToBigInt[i].in[j] <== pubkeyBitsConcat[i*n + j];
            }
        }
    }

    for (var i=0; i < k; i++) {
        pubkeyX[i] === convertBitsToBigInt[i].out;
    }
}


/**
 * Computes the SSZ root and Poseidon root of the sync committee
 * @param  b                     The size of the set of public keys
 * @param  n                     The number of bits to use per register
 * @param  k                     The number of registers
 * @input  pubkeyHex             The sync committee's BLS12-381 public keys in hex form
 * @input  aggregatePubkeyHex    The sync committee's aggregated BLS12-381 public key in hex form
 * @input  pubkeys               The sync committee's BLS12-381 public keys in BigInt form
 * @output syncCommitteeSSZ      THe SSZ root of the sync committee
 * @output syncCommitteePoseidon THe Poseidon root of the sync committee
 */
template SyncCommitteeCommittments(b, n, k) {
    signal input pubkeyHex[b][48];
    signal input aggregatePubkeyHex[48];
    signal input pubkeys[b][2][k];

    signal output syncCommitteeSSZ[32];
    signal output syncCommitteePoseidon;

    // First check that the pubkeyshex match up with the pubkeys in bigint form
    component pubkeyMatch[b];
    for (var i=0; i < b; i++) {
        pubkeyMatch[i] = AssertPubkeyBytesMatchesPubkeyXBigIntNoCheck(n, k, 48);
        for (var j=0; j < k; j++) {
            pubkeyMatch[i].pubkeyX[j] <== pubkeys[i][0][j];
        }
        for (var j=0; j < 48; j++) {
            pubkeyMatch[i].pubkeyBytes[j] <== pubkeyHex[i][j];
        }
    }

    // Now compute the SSZ
    component sszSyncCommittee = SSZPhase0SyncCommittee();
    for (var i=0; i < b; i++) {
        for (var j=0; j < 48; j++) {
            sszSyncCommittee.pubkeys[i][j] <== pubkeyHex[i][j];
        }
    }
    for (var j=0; j < 48; j++) {
        sszSyncCommittee.aggregate_pubkey[j] <== aggregatePubkeyHex[j];
    }

    for (var j=0; j < 32; j++) {
        syncCommitteeSSZ[j] <== sszSyncCommittee.out[j];
        log(syncCommitteeSSZ[j]);
    }

    // Now compute the poseidon hash of the pubkeys
    component poseidonSyncCommittee = PubkeyPoseidon(b, k);
    for (var i=0; i < b; i++) {
        for (var j=0; j < k; j++) {
            poseidonSyncCommittee.pubkeys[i][0][j] <== pubkeys[i][0][j];
            poseidonSyncCommittee.pubkeys[i][1][j] <== pubkeys[i][1][j];
        }
    }

    syncCommitteePoseidon <== poseidonSyncCommittee.out;
}