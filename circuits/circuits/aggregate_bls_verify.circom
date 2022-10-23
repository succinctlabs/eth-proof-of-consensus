pragma circom 2.0.3;

include "../circom-pairing/circuits/bls_signature.circom";
include "../circom-pairing/circuits/curve.circom";
include "../circom-pairing/circuits/bls12_381_func.circom";
include "./sha256_bytes.circom";


/**
 * Computes an aggregate BLS12-381 public key over a set of public keys and a bitmask
 * @param  b          The size of the set of public keys
 * @param  n          The number of bits to use per register
 * @param  k          The number of registers
 * @input  pubkeys    The b BLS12-381 public keys in BigInt(n, k)
 * @input  pubkeybits The b-length bitmask for which pubkeys to include
 * @output out        \sum_{i=0}^{b-1} pubkeys[i] * pubkeybits[i] (over the BLS12-381 curve)
 */
template AccumulatedECCAdd(b, n, k) {
    var p[50] = get_BLS12_381_prime(55, 7);

    signal input pubkeys[b][2][k];
    signal input pubkeybits[b];

    signal output out[2][k];

    component has_prev_nonzero[b];
    has_prev_nonzero[0] = OR();
    has_prev_nonzero[0].a <== 0;
    has_prev_nonzero[0].b <== pubkeybits[0];
    for (var i = 1; i < b; i++) {
        has_prev_nonzero[i] = OR();
        has_prev_nonzero[i].a <== has_prev_nonzero[i - 1].out;
        has_prev_nonzero[i].b <== pubkeybits[i];
    }

    signal partial[b][2][k];
    for (var idx = 0; idx < k; idx++) {
        for (var l = 0; l < 2; l++) {
            partial[0][l][idx] <== pubkeys[0][l][idx];
        }
    }

    component adders[b - 1];
    signal intermed1[b - 1][2][k];
    signal intermed2[b - 1][2][k];
    for (var i = 1; i < b; i++) {
        adders[i - 1] = EllipticCurveAddUnequal(n, k, p);
        for (var idx = 0; idx < k; idx++) {
            for (var l = 0; l < 2; l++) {
                adders[i - 1].a[l][idx] <== partial[i - 1][l][idx];
                adders[i - 1].b[l][idx] <== pubkeys[i][l][idx];
            }
        }

        // partial[i] = has_prev_nonzero[i - 1] * ((1 - iszero[i]) * adders[i - 1].out + iszero[i] * partial[i - 1][0][idx])
        //              + (1 - has_prev_nonzero[i - 1]) * (1 - iszero[i]) * multiplexers[i]
        for (var idx = 0; idx < k; idx++) {
            for (var l = 0; l < 2; l++) {
                intermed1[i - 1][l][idx] <== (1-pubkeybits[i]) * (partial[i - 1][l][idx] - adders[i - 1].out[l][idx]) + adders[i - 1].out[l][idx];
                intermed2[i - 1][l][idx] <== pubkeys[i][l][idx] - (1-pubkeybits[i]) * pubkeys[i][l][idx];
                partial[i][l][idx] <== has_prev_nonzero[i - 1].out * (intermed1[i - 1][l][idx] - intermed2[i - 1][l][idx]) + intermed2[i - 1][l][idx];
            }
        }
    }

    for (var idx = 0; idx < k; idx++) {
        for (var l = 0; l < 2; l++) {
            out[l][idx] <== partial[b - 1][l][idx];
        }
    }
}


/**
 * Verifies a BLS12-381 signature over a message hash and an aggregated pubkey
 * @param  b          The size of the set of public keys
 * @param  n          The number of bits to use per register
 * @param  k          The number of registers
 * @input  pubkeys    The b BLS12-381 public keys in BigInt(n, k)
 * @input  pubkeybits The b-length bitmask for which pubkeys to include
 * @input  signature  The BLS12-381 signature over the message hash
 * @input  Hm         The message hash (in field)
 */
template AggregateVerify(b, n, k){
    signal input pubkeys[b][2][k];
    signal input pubkeybits[b];
    signal input signature[2][2][k];
    signal input Hm[2][2][k];

    component aggregateKey = AccumulatedECCAdd(b,n,k);
    for (var batch_idx = 0; batch_idx < b; batch_idx++) {
        aggregateKey.pubkeybits[batch_idx] <== pubkeybits[batch_idx];
        for (var reg_idx = 0; reg_idx < k; reg_idx++) {
            for (var x_or_y = 0; x_or_y < 2; x_or_y++) {
                aggregateKey.pubkeys[batch_idx][x_or_y][reg_idx] <== pubkeys[batch_idx][x_or_y][reg_idx];
            }
        }
    }

    component verifySignature = CoreVerifyPubkeyG1(n, k);
    for (var reg_idx = 0; reg_idx < k; reg_idx++) {
        for (var x_or_y = 0; x_or_y < 2; x_or_y++) {
            verifySignature.pubkey[x_or_y][reg_idx] <== aggregateKey.out[x_or_y][reg_idx];
            log(aggregateKey.out[x_or_y][reg_idx]);
            verifySignature.signature[0][x_or_y][reg_idx] <== signature[0][x_or_y][reg_idx];
            verifySignature.signature[1][x_or_y][reg_idx] <== signature[1][x_or_y][reg_idx];
            verifySignature.hash[0][x_or_y][reg_idx] <== Hm[0][x_or_y][reg_idx];
            verifySignature.hash[1][x_or_y][reg_idx] <== Hm[1][x_or_y][reg_idx];
        }
    }
}


/**
 * Computes vectorized XOR over two input arrays of bits
 * @param  n   The number of bits to XOR
 * @input  a   A n-length array of bits
 * @input  b   A n-length array of bits
 * @output out A n-length array of bits containing [a[0] \xor a[0], ..., a[n-1] \xor a[n-1]]
 */
template ArrayXOR(n) {
  signal input a[n];
  signal input b[n];
  signal output out[n];

  // component xors[n];

  for (var i = 0; i < n; i++) {
    // xors[i] = XOR();
    // xors[i].a <== a[i];
    // xors[i].b <== b[i];
    out[i] <-- a[i] ^ b[i];
  }
}


/**
 * Integer to Octet Stream
 * @param  l   The number of output bytes (at most ceil(254/8) due to the field size)
 * @input  in  A number
 * @output out The number converted to its l-length byte array representation in little endian
 */
template I2OSP(l) {
  signal input in; // number
  signal output out[l]; // bytes

  var value = in;
  for (var i = l - 1; i >= 0; i--) {
    out[i] <-- value & 255;
    value = value \ 256;
  }

  signal acc[l];
  for (var i = 0; i < l; i++) {
    if (i == 0) {
      acc[i] <== out[i];
    } else {
      acc[i] <== 256 * acc[i-1] + out[i];
    }
  }

  acc[l-1] === in;
}


/**
 * Given an arbitrary message, extends it pseudoradnomly to some target length
 * Target Implementation: https://github.com/paulmillr/noble-bls12-381/blob/main/index.ts#L236
 * @param  msg_len      Length of the input message in bytes
 * @param  dst_len      Length of the domain seperation tag in bytes
 * @param  expanded_len Length of the output message
 * @input  msg          Input message in bytes
 * @input  dst          Domain seperation tag in bytes
 * @output out          The input message expanded pseudodorandomly
 */
template ExpandMessageXMD(msg_len, dst_len, expanded_len) {
  signal input msg[msg_len];
  signal input dst[dst_len];
  signal output out[expanded_len];

  var b_in_bytes = 32;
  var r_in_bytes = 64;
  var ell = (expanded_len + b_in_bytes - 1) \ b_in_bytes;
  assert(ell < 255); // invalid xmd length

  component i2osp_dst = I2OSP(1);
  i2osp_dst.in <== dst_len;

  signal dst_prime[dst_len + 1];
  for (var i = 0; i < dst_len; i++) {
    dst_prime[i] <== dst[i];
  }
  dst_prime[dst_len] <== i2osp_dst.out[0];

  component i2osp_z_pad = I2OSP(r_in_bytes);
  i2osp_z_pad.in <== 0;

  component i2osp_l_i_b_str = I2OSP(2);
  i2osp_l_i_b_str.in <== expanded_len;

  // b_0 = sha256(Z_pad || msg || l_i_b_str || i2osp(0, 1) || DST_prime)
  var s256_0_input_byte_len = r_in_bytes + msg_len + 2 + 1 + dst_len + 1;
  component s256_0 = Sha256Bytes(s256_0_input_byte_len);
  for (var i = 0; i < s256_0_input_byte_len; i++) {
    if (i < r_in_bytes) {
      s256_0.in[i] <== i2osp_z_pad.out[i];
    } else if (i < r_in_bytes + msg_len) {
      s256_0.in[i] <== msg[i-r_in_bytes];
    } else if (i < r_in_bytes + msg_len + 2) {
      s256_0.in[i] <== i2osp_l_i_b_str.out[i-r_in_bytes-msg_len];
    } else if (i < r_in_bytes + msg_len + 2 + 1) {
      s256_0.in[i] <== 0;
    } else {
      s256_0.in[i] <== dst_prime[i-r_in_bytes-msg_len-2-1];
    }
  }

  // b[0] = sha256(s256_0.out || i2osp(1, 1) || dst_prime)
  component s256s[ell];
  var s256s_0_input_byte_len = 32 + 1 + dst_len + 1;
  s256s[0] = Sha256Bytes(s256s_0_input_byte_len);
  for (var i = 0; i < s256s_0_input_byte_len; i++) {
    if (i < 32) {
      s256s[0].in[i] <== s256_0.out[i];
    } else if (i < 32 + 1) {
      s256s[0].in[i] <== 1;
    } else {
      s256s[0].in[i] <== dst_prime[i - 32 - 1];
    }
  }

  // sha256(b[0] XOR b[i-1] || i2osp(i+1, 1) || dst_prime)
  component array_xor[ell-1];
  component i2osp_index[ell-1];
  for (var i = 1; i < ell; i++) {
    array_xor[i-1] = ArrayXOR(32);
    for (var j = 0; j < 32; j++) {
      array_xor[i-1].a[j] <== s256_0.out[j];
      array_xor[i-1].b[j] <== s256s[i-1].out[j];
    }

    i2osp_index[i-1] = I2OSP(1);
    i2osp_index[i-1].in <== i + 1;

    var s256s_input_byte_len = 32 + 1 + dst_len + 1;
    s256s[i] = Sha256Bytes(s256s_input_byte_len);
    for (var j = 0; j < s256s_input_byte_len; j++) {
      if (j < 32) {
        s256s[i].in[j] <== array_xor[i-1].out[j];
      } else if (j < 32 + 1) {
        s256s[i].in[j] <== i2osp_index[i-1].out[j-32];
      } else {
        s256s[i].in[j] <== dst_prime[j-32-1];
      }
    }
  }

  for (var i = 0; i < expanded_len; i++) {
    out[i] <== s256s[i \ 32].out[i % 32];
  }
}


/**
 * Implements a hash function from bytes to the field for BLS12-381
 * Target Implementation: https://github.com/paulmillr/noble-bls12-381/blob/main/index.ts#L268
 * @param  msg_len Length of the input message in bytes
 * @param  count   Number of output hashes to construct (can be tuned via ExpandMessageXMD)
 * @output result  The resulting hashes
 */
template HashToField(msg_len, count) {
  signal input msg[msg_len];

  var dst[43];
  dst[0] = 66;
  dst[1] = 76;
  dst[2] = 83;
  dst[3] = 95;
  dst[4] = 83;
  dst[5] = 73;
  dst[6] = 71;
  dst[7] = 95;
  dst[8] = 66;
  dst[9] = 76;
  dst[10] = 83;
  dst[11] = 49;
  dst[12] = 50;
  dst[13] = 51;
  dst[14] = 56;
  dst[15] = 49;
  dst[16] = 71;
  dst[17] = 50;
  dst[18] = 95;
  dst[19] = 88;
  dst[20] = 77;
  dst[21] = 68;
  dst[22] = 58;
  dst[23] = 83;
  dst[24] = 72;
  dst[25] = 65;
  dst[26] = 45;
  dst[27] = 50;
  dst[28] = 53;
  dst[29] = 54;
  dst[30] = 95;
  dst[31] = 83;
  dst[32] = 83;
  dst[33] = 87;
  dst[34] = 85;
  dst[35] = 95;
  dst[36] = 82;
  dst[37] = 79;
  dst[38] = 95;
  dst[39] = 80;
  dst[40] = 79;
  dst[41] = 80;
  dst[42] = 95;

  var p[7];
  p[0] = 35747322042231467;
  p[1] = 36025922209447795;
  p[2] = 1084959616957103;
  p[3] = 7925923977987733;
  p[4] = 16551456537884751;
  p[5] = 23443114579904617;
  p[6] = 1829881462546425;

  var dst_len = 43;
  var log2p = 381;
  var m = 2;
  var l = 64;
  var len_in_bytes = 256;

  component expand_message_xmd = ExpandMessageXMD(msg_len, dst_len, len_in_bytes);
  for (var i = 0; i < msg_len; i++) {
    expand_message_xmd.msg[i] <== msg[i];
  }
  for (var i = 0; i < dst_len; i++) {
    expand_message_xmd.dst[i] <== dst[i];
  }

  //signal bytes_be[count][m][l];
  signal bytes_le[count][m][l];
  for (var i = 0; i < count; i++) {
    for (var j = 0; j < m; j++) {
      for (var k = 0; k < l; k++) {
        // bytes_be[i][j][k] <== expand_message_xmd.out[i*m*l + j*l + k];
        bytes_le[i][j][k] <== expand_message_xmd.out[i*m*l + j*l + l - 1 - k];
      }
    }
  }

  var bits_per_register = 55;
  var num_registers = (8 * l + bits_per_register - 1) \ bits_per_register;

  var bytes_to_registers[count][m][num_registers];
  component byte_to_bits[count][m][num_registers];
  component bits_to_num[count][m][num_registers][2];

  for (var i = 0; i < count; i++) {
    for (var j = 0; j < m; j++) {
      for (var idx = 0; idx < num_registers; idx++)
        bytes_to_registers[i][j][idx] = 0;
      var cur_bits = 0;
      var idx = 0;
      for (var k = 0; k < l; k++){
        if (cur_bits + 8 <= bits_per_register) {
          bytes_to_registers[i][j][idx] += bytes_le[i][j][k] * (1 << cur_bits);
          cur_bits += 8;
          if (cur_bits == bits_per_register) {
            cur_bits = 0;
            idx++;
          }
        } else {
          var bits_1 = bits_per_register - cur_bits;
          var bits_2 = 8 - bits_1;
          byte_to_bits[i][j][idx] = Num2Bits(8);
          byte_to_bits[i][j][idx].in <== bytes_le[i][j][k];

          bits_to_num[i][j][idx][0] = Bits2Num(bits_1);
          for (var bit = 0; bit < bits_1; bit++)
            bits_to_num[i][j][idx][0].in[bit] <== byte_to_bits[i][j][idx].out[bit];

          bits_to_num[i][j][idx][1] = Bits2Num(bits_2);
          for (var bit = 0; bit < bits_2; bit++)
            bits_to_num[i][j][idx][1].in[bit] <== byte_to_bits[i][j][idx].out[bits_1 + bit];

          bytes_to_registers[i][j][idx] += bits_to_num[i][j][idx][0].out * (1 << cur_bits);
          bytes_to_registers[i][j][idx + 1] = bits_to_num[i][j][idx][1].out;
          idx++;
          cur_bits = bits_2;
        }
      }
    }
  }
  signal bytes_to_bigint[count][m][num_registers];
  for (var i = 0; i < count; i++) {
    for (var j = 0; j < m; j++) {
      for (var idx = 0; idx < num_registers; idx++) {
        bytes_to_bigint[i][j][idx] <== bytes_to_registers[i][j][idx];
      }
    }
  }

  component red[count][m];
  component modders[count][m];
  var log_extra = log_ceil(num_registers - 6);

  for (var i = 0; i < count; i++) {
    for (var j = 0; j < m; j++) {
      red[i][j] = PrimeReduce(bits_per_register, 7, num_registers - 7, p, log_extra + 2*bits_per_register);
      for (var k = 0; k < num_registers; k++)
        red[i][j].in[k] <== bytes_to_bigint[i][j][k];

      modders[i][j] = SignedFpCarryModP(bits_per_register, 7, log_extra + 2*bits_per_register, p);
      for (var k = 0; k < 7; k++) {
        modders[i][j].in[k] <== red[i][j].out[k];
      }
    }
  }

  signal output result[count][m][7];
  for (var i = 0; i < count; i++) {
    for (var j = 0; j < m; j++) {
      for (var k = 0; k < 7; k++) {
        result[i][j][k] <== modders[i][j].out[k];
      }
    }
  }
}