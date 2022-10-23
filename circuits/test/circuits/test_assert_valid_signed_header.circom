pragma circom 2.0.2;

include "../../circuits/assert_valid_signed_header.circom";

component main {public [signing_root]} = AssertValidSignedHeader(512, 55, 7);