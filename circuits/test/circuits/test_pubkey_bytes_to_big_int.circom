pragma circom 2.0.2;

include "../../circuits/sync_committee_committments.circom";

component main {public [pubkeyX, pubkeyBytes]} = AssertPubkeyBytesMatchesPubkeyXBigIntNoCheck(55, 7, 48);