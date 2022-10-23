import path from "path";
import { PointG1 } from "@noble/bls12-381";
const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;

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

describe("BLS12-381-AggregateAdd", function () {
  this.timeout(1000 * 1000);

  let circuit: any;
  before(async function () {
    circuit = await wasm_tester(
      path.join(__dirname, "circuits", "test_aggregate_bls_add_4.circom")
    );
  });

  var test_cases: Array<
    [
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      number[]
    ]
  > = [];

  for (var test = 1; test < 16; test++) {
    var bitArray = test
      .toString(2)
      .padStart(4, "0")
      .split("")
      .map((x) => parseInt(x));
    var pubkeys: Array<PointG1> = [];
    var sum = PointG1.ZERO;
    for (var idx = 0; idx < 4; idx++) {
      var pubkey: PointG1 = PointG1.fromPrivateKey(BigInt(private_keys[idx]));
      pubkeys.push(pubkey);
      if (bitArray[idx] == 1) {
        sum = sum.add(pubkey);
      }
    }
    test_cases.push([
      point_to_bigint(pubkeys[0]),
      point_to_bigint(pubkeys[1]),
      point_to_bigint(pubkeys[2]),
      point_to_bigint(pubkeys[3]),
      point_to_bigint(sum),
      bitArray,
    ]);
  }

  var test_bls12381_add_instance = function (
    test_case: [
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      [bigint, bigint],
      number[]
    ]
  ) {
    let [pub0x, pub0y] = test_case[0];
    let [pub1x, pub1y] = test_case[1];
    let [pub2x, pub2y] = test_case[2];
    let [pub3x, pub3y] = test_case[3];
    let [sumAllx, sumAlly] = test_case[4];
    let bitArray = test_case[5];

    var n: number = 55;
    var k: number = 7;
    var pub0x_array: bigint[] = bigint_to_array(n, k, pub0x);
    var pub0y_array: bigint[] = bigint_to_array(n, k, pub0y);
    var pub1x_array: bigint[] = bigint_to_array(n, k, pub1x);
    var pub1y_array: bigint[] = bigint_to_array(n, k, pub1y);

    it(JSON.stringify(bitArray), async function () {
      let witness = await circuit.calculateWitness({
        pubkeys: [
          [pub0x_array, pub0y_array],
          [pub1x_array, pub1y_array],
          [bigint_to_array(n, k, pub2x), bigint_to_array(n, k, pub2y)],
          [bigint_to_array(n, k, pub3x), bigint_to_array(n, k, pub3y)],
        ],
        pubkeybits: bitArray,
      });
      await circuit.assertOut(witness, {
        out: [bigint_to_array(n, k, sumAllx), bigint_to_array(n, k, sumAlly)],
      });
      await circuit.checkConstraints(witness);
    });
  };

  test_cases.forEach(test_bls12381_add_instance);
});
