pragma circom 2.0.3;

include "../../circuits/simple_serialize.circom";

component main {public [in]} = SSZArray(128, 2);