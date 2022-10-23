pragma circom 2.0.3;

template TemplateAssertValidSignedHeader(b, n, k) {
    signal input pubkeyHex[b][48];
    signal input aggregatePubkeyHex[48];
    signal input pubkeys[b][2][k];
    signal input pubkeybits[b];
    signal input signature[2][2][k];
    signal input signing_root[32]; // signing_root

    signal output bitSum;
    signal output syncCommitteeSSZ[32];

    for (var i=0; i < 32; i++) {
        syncCommitteeSSZ[i] <== i;
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

    bitSum <== partialSum[b-2];
    
}

component main {public [signing_root]} = TemplateAssertValidSignedHeader(512, 55, 7);