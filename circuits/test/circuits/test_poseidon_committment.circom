pragma circom 2.0.3;

include "../../circuits/pubkey_poseidon.circom";


component main {public [pubkeys]} = PubkeyPoseidon(512, 7);