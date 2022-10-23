// This generates input_512.json
import path from "path";
import fs from "fs";

import { PointG1, PointG2, aggregatePublicKeys } from "@noble/bls12-381";
import { toHexString, fromHexString } from "@chainsafe/ssz";
import bls from "@chainsafe/bls/blst-native";
import { ssz } from "@lodestar/types";

import {
  deserializeLightclientOptimisticUpdate,
  deserializeSyncCommittee,
} from "operator/common";
import { getSigningRoot } from "operator/lightClientHelpers";
import {
  utils,
  formatHex,
  bigint_to_array,
  msg_hash,
  sigHexAsSnarkInput,
  hexToIntArray,
} from "./bls_utils";
import { computeSigningRoot } from "@lodestar/light-client/lib/utils";

BigInt.prototype.toJSON = function () {
  return this.toString();
};

var n: number = 55;
var k: number = 7;

function point_to_bigint(point: PointG1): [bigint, bigint] {
  let [x, y] = point.toAffine();
  return [x.value, y.value];
}

async function generate_data(b: number = 512) {
  const dirname = path.resolve();
  const rawData = fs.readFileSync(
    path.join(dirname, "../operator/data/4278368/optimisticUpdate.json")
  );
  const optimisticUpdate = deserializeLightclientOptimisticUpdate(
    JSON.parse(rawData.toString())
  );
  const syncCommitteeSerialized = fs.readFileSync(
    path.join(dirname, "../operator/data/4278368/syncCommittee.json")
  );
  const syncCommitte = deserializeSyncCommittee(
    JSON.parse(syncCommitteeSerialized.toString())
  );

  let aggPubkey = PointG1.ZERO;
  const pubkeys = syncCommitte.pubkeys.map((pubkey, idx: number) => {
    const point = PointG1.fromHex(formatHex(toHexString(pubkey)));
    if (optimisticUpdate.syncAggregate.syncCommitteeBits.get(idx)) {
      aggPubkey = aggregatePublicKeys([aggPubkey, point]);
    }
    const bigints = point_to_bigint(point);
    return [
      bigint_to_array(n, k, bigints[0]),
      bigint_to_array(n, k, bigints[1]),
    ];
  });

  const signature = toHexString(
    optimisticUpdate.syncAggregate.syncCommitteeSignature
  );
  const signingRoot = getSigningRoot(optimisticUpdate.attestedHeader);
  const msg = await msg_hash(signingRoot, "array");

  // TODO use @noble bls library instead of chainsafe
  const verified = bls.verify(
    fromHexString(aggPubkey.toHex()),
    signingRoot,
    fromHexString(signature)
  );
  console.log(
    "Aggregate signature verified with computed aggregate public key"
  );
  console.log(verified);

  // signal input pubkeys[b][2][k];
  // signal input pubkeybits[b];
  // signal input signature[2][2][k];
  // signal input Hm[2][2][k];

  const aggPubKeyBigInts = point_to_bigint(aggPubkey);
  const msgAsInputHex = await msg_hash(signingRoot, "hex");
  const zkpairingInput = {
    pubkey: [
      "0x" + aggPubKeyBigInts[0].toString(16),
      "0x" + aggPubKeyBigInts[1].toString(16),
    ],
    signature: sigHexAsSnarkInput(signature, "hex"),
    msg: msgAsInputHex,
  };

  console.log("Input for zkpairing");
  console.log(zkpairingInput);

  const pubkeyAddrInput = {
    pubkeys: pubkeys,
    pubkeybits: optimisticUpdate.syncAggregate.syncCommitteeBits
      .toBoolArray()
      .map((x) => (x ? 1 : 0)),
  };
  const pubkeyAddrFilename = path.join(
    dirname,
    "test",
    `input_pubkey_addr_${b}.json`
  );
  console.log("Writing input to file", pubkeyAddrFilename);
  fs.writeFileSync(pubkeyAddrFilename, JSON.stringify(pubkeyAddrInput));

  const input = {
    pubkeys: pubkeys,
    pubkeybits: optimisticUpdate.syncAggregate.syncCommitteeBits
      .toBoolArray()
      .map((x) => (x ? 1 : 0)),
    signature: sigHexAsSnarkInput(signature, "array"),
    Hm: msg,
  };
  const verifyFilename = path.join(
    dirname,
    "test",
    `input_aggregate_bls_verify_${b}.json`
  );
  console.log("Writing input to file", verifyFilename);
  fs.writeFileSync(verifyFilename, JSON.stringify(input));

  const syncCommitteeSSZInput = {
    pubkeys: pubkeys,
    pubkeyHex: syncCommitte.pubkeys.map((pubkey) =>
      hexToIntArray(toHexString(pubkey))
    ),
    aggregatePubkeyHex: hexToIntArray(
      toHexString(syncCommitte.aggregatePubkey)
    ),
  };
  const syncCommitteeFilename = path.join(
    dirname,
    "test",
    `input_sync_committee_committments_${b}.json`
  );
  console.log("Writing input to file", syncCommitteeFilename);
  fs.writeFileSync(
    syncCommitteeFilename,
    JSON.stringify(syncCommitteeSSZInput)
  );

  // The assert valid signed header input is even more different
  // signal input pubkeyHex[b][48];
  // signal input aggregatePubkeyHex[48];
  // signal input pubkeys[b][2][k];
  // signal input pubkeybits[b];
  // signal input signature[2][2][k];
  // signal input signing_root[32]; // signing_root
  // NOTE we do not have Hm in here
  const validSignedHeaderInput = {
    signing_root: hexToIntArray(toHexString(signingRoot)),
    pubkeys: pubkeys,
    pubkeybits: optimisticUpdate.syncAggregate.syncCommitteeBits
      .toBoolArray()
      .map((x) => (x ? 1 : 0)),
    signature: sigHexAsSnarkInput(signature, "array"),
  };
  const validSignedHeaderFilename = path.join(
    dirname,
    "test",
    `input_valid_signed_header_${b}.json`
  );
  fs.writeFileSync(
    validSignedHeaderFilename,
    JSON.stringify(validSignedHeaderInput)
  );

  console.log("Expected output:");
  const syncCommitteeSSZ = ssz.altair.SyncCommittee.hashTreeRoot(syncCommitte);
  console.log("sync committee ssz", toHexString(syncCommitteeSSZ));
  console.log(
    "sync committee ssz as int array of bytes",
    hexToIntArray(toHexString(syncCommitteeSSZ))
  );
  console.log(
    "sum bits",
    validSignedHeaderInput.pubkeybits.reduce(
      (partialSum: number, a) => partialSum + a,
      0
    )
  );
}

generate_data();
