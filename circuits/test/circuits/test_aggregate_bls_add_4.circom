pragma circom 2.0.2;

include "../../circuits/aggregate_bls_verify.circom";

component main {public [pubkeys, pubkeybits]} = AccumulatedECCAdd(4, 55, 7);