pragma circom 2.0.3;

include "../../node_modules/circomlib/circuits/poseidon.circom";


/**
 * Computes the Poseidon merkle root of a list of field elements
 * @param  num_eles The number of elements to compute the Poseidon merkle root over
 * @input  in       The input array of size num_eles field elements
 * @output out      The Poseidon merkle root of in
 */
template posiedon_generalized(num_eles) {
    signal input in[num_eles];
    // Can do bytes to field element
    // max individual posiedon is 16
    var total_poseidon = (num_eles) \ 15 + 1;
    component poseidon_aggregator[total_poseidon];
    for (var i=0; i < total_poseidon; i++) {
        var poseidonSize = 16;
        if (i == 0) poseidonSize = 15;
        poseidon_aggregator[i] = Poseidon(poseidonSize);
        for (var j = 0; j < 15; j++) {
            if (i*15 + j >= num_eles ) {
                poseidon_aggregator[i].inputs[j] <== 0;
            } else {
                poseidon_aggregator[i].inputs[j] <== in[i*15 + j];
            }
        }
        if (i > 0) {
            poseidon_aggregator[i].inputs[15] <== poseidon_aggregator[i- 1].out;
        }
    }
    signal output out;
    out <== poseidon_aggregator[total_poseidon-1].out;
}


/**
 * Converts 48 bytes to a BLS12-381 field element
 * @input  bytes     The input 48 bytes
 * @output field_ele The output BLS12-381 field element
 */
template bytes_48_to_field_ele() {
    // TODO: can also optimized by packing a 48 byte pubkeyhex into
    // 2 field elements to put into poseidon
    signal input bytes[48];
    signal output field_ele[2];

    signal field_ele_accum[2][24];

    for (var i=0; i < 2; i++) {
        for (var j=0; j < 24; j++) {
            if (j == 0) {
                field_ele_accum[i][j] <== 0;
            } else {
                field_ele_accum[i][j] <== field_ele_accum[i][j-1] + 2**(j*8) * bytes[i*24 + j];
            }
        }
    }

    field_ele[0] <== field_ele_accum[0][23];
    field_ele[1] <== field_ele_accum[1][23];
}


/**
 * Computes the Poseidon merkle root of a list of BLS12-381 public keys
 * @param  b       The size of the set of public keys
 * @param  k       The number of registers
 * @input  pubkeys The input array of size b with BLS12-381 public keys
 * @output out     The Poseidon merkle root of pubkeys
 */
template PubkeyPoseidon(b, k) {
    // TODO: this can be optimized further by packing the pubkey into a smaller number of field elements
    signal input pubkeys[b][2][k];
    signal output out;

    component posiedonHasher = posiedon_generalized(2*b*k);
    for (var i=0; i < b; i++) {
        for (var j=0; j < k; j++) {
            for (var l=0; l < 2; l++) {
                posiedonHasher.in[i*k*2 + j*2 + l] <== pubkeys[i][l][j];
            }
        }
    }
    out <== posiedonHasher.out;
}