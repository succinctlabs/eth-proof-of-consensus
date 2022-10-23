pragma circom 2.0.3;

include "../../circuits/aggregate_bls_verify.circom";

component main {public [msg, dst]} = ExpandMessageXMD(10, 43, 256);