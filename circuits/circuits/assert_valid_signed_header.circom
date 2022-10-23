pragma circom 2.0.3;

include "./pubkey_poseidon.circom";
include "./aggregate_bls_verify.circom";


/**
 * Given the sync committee public keys and a bitmask to represent which validators signed,
 * verifies that there exists some valid BLS12-381 signature over the SSZ root of the Phase0BeaconBlockHeader
 * @param  b                     The size of the set of public keys
 * @param  n                     The number of bits to use per register
 * @param  k                     The number of registers
 * @input  pubkeys               The b BLS12-381 public keys in BigInt(n, k)
 * @input  pubkeybits            The b-length bitmask for which pubkeys to include
 * @input  signature             The BLS12-381 signature for the signing_root
 * @input  signing_root          The SSZ root of the block header
 * @output bitSum                \sum_{i=0}^{b-1} pubkeybits[i]
 * @output syncCommitteePoseidon Poseidon merkle root of pubkeys
 */
template AssertValidSignedHeader(b, n, k) {
    signal input pubkeys[b][2][k];
    signal input pubkeybits[b];
    signal input signature[2][2][k];
    signal input signing_root[32]; // signing_root

    signal output bitSum;
    signal output syncCommitteePoseidon;

    // Convert the signing_root to a field element using hash_to_field
    // This requires k = 7 and n = 55
    component hashToField = HashToField(32, 2);
    for (var i=0; i < 32; i++) {
        hashToField.msg[i] <== signing_root[i];
    }
    signal Hm[2][2][k];
    log(555555);
    for (var i=0; i < 2; i++) {
        for (var j=0; j < 2; j++) {
            for (var l=0; l < k; l++) {
                Hm[i][j][l] <== hashToField.result[i][j][l];
                log(Hm[i][j][l]);
            }
        }
    }

    // First verify the signature
    component aggregateVerify = AggregateVerify(b, n, k);
    for (var i=0; i < b; i++) {
        aggregateVerify.pubkeybits[i] <== pubkeybits[i];
        for (var j=0; j < k; j++) {
            aggregateVerify.pubkeys[i][0][j] <== pubkeys[i][0][j];
            aggregateVerify.pubkeys[i][1][j] <== pubkeys[i][1][j];
        }
    }
    for (var j=0; j < k; j++) {
        aggregateVerify.signature[0][0][j] <== signature[0][0][j];
        aggregateVerify.signature[0][1][j] <== signature[0][1][j];
        aggregateVerify.signature[1][0][j] <== signature[1][0][j];
        aggregateVerify.signature[1][1][j] <== signature[1][1][j];
        aggregateVerify.Hm[0][0][j] <== Hm[0][0][j];
        aggregateVerify.Hm[0][1][j] <== Hm[0][1][j];
        aggregateVerify.Hm[1][0][j] <== Hm[1][0][j];
        aggregateVerify.Hm[1][1][j] <== Hm[1][1][j];
    }


    // Then output the sum of the pubkeybits
    signal partialSum[b-1];
    for (var i=0; i < b-1; i++) {
        if (i == 0) {
            partialSum[i] <== pubkeybits[0] + pubkeybits[1];
        } else {
            partialSum[i] <== partialSum[i-1] + pubkeybits[i+1];
        }
    }

    log(999999);
    bitSum <== partialSum[b-2];
    log(bitSum);

    component poseidonSyncCommittee = PubkeyPoseidon(b, k);
    for (var i=0; i < b; i++) {
        for (var j=0; j < k; j++) {
            poseidonSyncCommittee.pubkeys[i][0][j] <== pubkeys[i][0][j];
            poseidonSyncCommittee.pubkeys[i][1][j] <== pubkeys[i][1][j];
        }
    }
    syncCommitteePoseidon <== poseidonSyncCommittee.out;
}