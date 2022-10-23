import path from "path";
import fs from "fs";
import { expect, assert } from "chai";
const bls = require("@noble/bls12-381");
import { Fp, Fp2, PointG1 } from "@noble/bls12-381";
// import circom_tester from "circom_tester";
const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import { hexToIntArray } from "./bls_utils";

// @ts-ignore
BigInt.prototype.toJSON = function () {
  return this.toString();
};

function bigint_to_array(n: number, k: number, x: bigint) {
  let mod: bigint = 1n;
  for (var idx = 0; idx < n; idx++) {
    mod = mod * 2n;
  }

  let ret: bigint[] = [];
  var x_temp: bigint = x;
  for (var idx = 0; idx < k; idx++) {
    ret.push(x_temp % mod);
    x_temp = x_temp / mod;
  }
  return ret;
}

function point_to_bigint(point: PointG1): [bigint, bigint] {
  let [x, y] = point.toAffine();
  return [x.value, y.value];
}

const private_keys = [
  "0x06a680317cbb1cf70c700b672e48ed01fe5fd51427808a96e17611506e13aed9",
  "0x432bcfbda728fd60570db9505d0b899a9c7c8971ec0fd58252d8028ac0aa76ce",
  "0x6688391de4d32b5779ff669fb72f81b9aaff44e926ba19d5833c5a5c50dd40d2",
  "0x4c24c0c5360b7c44210697a5fba1f705456f37969e1354e30cbd0f290d2efd4a",
];

let n = 55;
let k = 7;

describe("BLS12-381-PubkeyBytesToBigInt", function () {
  this.timeout(1000 * 1000);

  // runs circom compilation
  let circuit: any;
  before(async function () {
    circuit = await wasm_tester(
      path.join(__dirname, "circuits", "test_pubkey_bytes_to_big_int.circom")
    );
  });

  it("Should test a pubkey", async function () {
    console.log("At top of test");
    const publicKeyHex =
      "0x891e60aff6ac35f971ce1536e6338f92c0f090415906e4097b35d1956b443d111da1d8839f35b598d92b233594d49762";
    const publicKey = PointG1.fromHex(publicKeyHex.slice(2));
    const [x, y] = point_to_bigint(publicKey);

    const pubkeyBytesInput = hexToIntArray(publicKeyHex);

    const witnessInput = {
      pubkeyX: bigint_to_array(n, k, x),
      pubkeyBytes: pubkeyBytesInput,
    };
    console.log(JSON.stringify(witnessInput));
    let witness = await circuit.calculateWitness(witnessInput);
    // This circuit does not have an out, it's just a check
    await circuit.checkConstraints(witness);
  });

  it("Should test a pubkey from input json", async function () {
    const rawData = fs.readFileSync(
      "./test/input_valid_signed_header_512.json"
    );
    const fullInput = JSON.parse(rawData.toString());

    const witnessInput = {
      pubkeyX: fullInput["pubkeys"][2][0],
      pubkeyBytes: fullInput["pubkeyHex"][2],
    };
    console.log(JSON.stringify(witnessInput));
    let witness = await circuit.calculateWitness(witnessInput);
    // This circuit does not have an out, it's just a check
    await circuit.checkConstraints(witness);
  });
});
