pragma circom 2.0.3;

include "../../circuits/aggregate_bls_verify.circom";

component main {public [msg]} = HashToField(10, 2);