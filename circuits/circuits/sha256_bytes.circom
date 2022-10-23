pragma circom 2.0.3;

include "../sha256/sha256.circom";


/**
 * Wrapper around SHA256 to support bytes as input instead of bits
 * @param  n   The number of input bytes
 * @input  in  The input bytes
 * @output out The SHA256 output of the n input bytes, in bytes
 */
template Sha256Bytes(n) {
  signal input in[n];
  signal output out[32];

  component byte_to_bits[n];
  for (var i = 0; i < n; i++) {
    byte_to_bits[i] = Num2Bits(8);
    byte_to_bits[i].in <== in[i];
  }

  component sha256 = Sha256(n*8);
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < 8; j++) {
      sha256.in[i*8+j] <== byte_to_bits[i].out[7-j];
    }
  }

  component bits_to_bytes[32];
  for (var i = 0; i < 32; i++) {
    bits_to_bytes[i] = Bits2Num(8);
    for (var j = 0; j < 8; j++) {
      bits_to_bytes[i].in[7-j] <== sha256.out[i*8+j];
    }
    out[i] <== bits_to_bytes[i].out;
  }
}