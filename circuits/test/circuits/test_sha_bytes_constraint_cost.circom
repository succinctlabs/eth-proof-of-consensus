pragma circom 2.0.2;

include "../../../node_modules/circomlib/circuits/sha256/sha256.circom";

// This is just to test the constraint cost of a raw SHA
// circom test/test_sha_bytes_constraint_cost.circom --r1cs --O2

template ShaBytes(num_bytes) {
    signal input in[num_bytes*8];
    component sha = Sha256(num_bytes*8);
    for (var i=0; i < num_bytes * 8; i++) {
        sha.in[i] <== in[i];
    }
    signal output out[256];
    for (var i=0; i < 256; i++) {
        out[i] <== sha.out[i];
    }
}

component main {public [in]} = ShaBytes(64);