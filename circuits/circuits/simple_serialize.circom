pragma circom 2.0.3;

include "./sha256_bytes.circom";


/**
 * Helper function to implement SSZArray
 * @param  num_bytes The number of input bytes
 * @input  in        The input bytes
 * @output out       num_bytes/2 output bytes computed by the SHA256 of 64 byte words
 */
template SSZLayer(num_bytes) {
    signal input in[num_bytes];
    signal output out[num_bytes \ 2];

    var num_pairs = num_bytes \ 64;
    component hashers[num_bytes \ 64];
    for (var i = 0; i < num_pairs; i++) {
        hashers[i] = Sha256Bytes(64);
        for (var j = 0; j < 64; j++) {
            hashers[i].in[j] <== in[i*64+j];
        }
    }

    for (var i = 0; i < num_pairs; i++) {
        for (var j = 0; j < 32; j++) {
            out[i*32+j] <== hashers[i].out[j];
        }
    }
}


/**
 * Implements the Simple Serialization (SSZ) method used in Ethereum 2.0 for a list of 32 byte words
 * @param  num_bytes The number of input bytes
 * @param  log2b     ceil(log2(num_bytes))
 * @input  in        The input bytes
 * @output out       The 32 byte SSZ root of the input bytes
 */
template SSZArray(num_bytes, log2b) {
    assert(32 * (2 ** log2b) == num_bytes);
    signal input in[num_bytes];
    signal output out[32];

    component ssz_layers[log2b];
    for (var layer_idx = 0; layer_idx < log2b; layer_idx++) {
        var num_input_bytes = num_bytes \ (2 ** layer_idx);
        ssz_layers[layer_idx] = SSZLayer(num_input_bytes);
        for (var i = 0; i < num_input_bytes; i++) {
            if (layer_idx == 0) {
                ssz_layers[layer_idx].in[i] <== in[i];
            } else {
                ssz_layers[layer_idx].in[i] <== ssz_layers[layer_idx-1].out[i];
            }
        }
    }

    for (var i = 0; i < 32; i++) {
        out[i] <== ssz_layers[log2b-1].out[i];
    }
}


/**
 * Implements the Simple Serialization (SSZ) method used in Ethereum 2.0 for the Phase0SyncCommittee struct
 * @input  pubkeys          BLS12-381 public keys for the sync committee, in bytes
 * @input  aggregate_pubkey BLS12-381 public key for the sync committee, aggregated
 * @output out              The SSZ root of [pubkeys, aggregate_pubkey]
 */
template SSZPhase0SyncCommittee() {
  signal input pubkeys[512][48];
  signal input aggregate_pubkey[48];
  signal output out[32];

  component ssz_pubkeys = SSZArray(32768, 10);
  for (var i = 0; i < 512; i++) {
    for (var j = 0; j < 64; j++) {
      if (j < 48) {
        ssz_pubkeys.in[i*64 + j] <== pubkeys[i][j];
      } else {
        ssz_pubkeys.in[i*64 + j] <== 0;
      }
    }
  }

  component ssz_aggregate_pubkey = SSZArray(64, 1);
  for (var i = 0; i < 64; i++) {
    if (i < 48) {
      ssz_aggregate_pubkey.in[i] <== aggregate_pubkey[i];
    } else {
      ssz_aggregate_pubkey.in[i] <== 0;
    }
  }

  component hasher = Sha256Bytes(64);
  for (var i = 0; i < 64; i++) {
    if (i < 32) {
      hasher.in[i] <== ssz_pubkeys.out[i];
    } else {
      hasher.in[i] <== ssz_aggregate_pubkey.out[i-32];
    }
  }
  for (var i = 0; i < 32; i++) {
    out[i] <== hasher.out[i];
  }
}


/**
 * Implements the Simple Serialization (SSZ) method used in Ethereum 2.0 for the Phase0BeaconBlockHeader struct
 * @input  slot             The slot that the block header refers to
 * @input  proposer_index   The index of the validator that proposed the beacon block
 * @input  parent_root      The previous block header's SSZ root
 * @input  state_root       The SSZ root of the EVM state
 * @input  body_root        The SSZ root of the beacon block body
 * @output out              The SSZ root of the above data packed into the Phase0BeaconBlockHeader struct
 */
template SSZPhase0BeaconBlockHeader() {
  signal input slot[32];
  signal input proposer_index[32];
  signal input parent_root[32];
  signal input state_root[32];
  signal input body_root[32];
  signal output out[32];

  component ssz_beacon_block_header = SSZArray(256, 3);
  for (var i = 0; i < 256; i++) {
    if (i < 32) {
      ssz_beacon_block_header.in[i] <== slot[i];
    } else if (i < 64) {
      ssz_beacon_block_header.in[i] <== proposer_index[i-32];
    } else if (i < 96) {
      ssz_beacon_block_header.in[i] <== parent_root[i-64];
    } else if (i < 128) {
      ssz_beacon_block_header.in[i] <== state_root[i-96];
    } else if (i < 160) {
      ssz_beacon_block_header.in[i] <== body_root[i-128];
    } else {
      ssz_beacon_block_header.in[i] <== 0;
    }
  }

  for (var i = 0; i < 32; i++) {
    out[i] <== ssz_beacon_block_header.out[i];
  }
}