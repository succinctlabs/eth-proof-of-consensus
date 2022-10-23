import path from "path";
const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import { msg_hash } from "./bls_utils";

describe("HashToField", function () {
  this.timeout(1000 * 1000);

  let circuit: any;
  before(async function () {
    circuit = await wasm_tester(
      path.join(__dirname, "circuits", "test_hash_to_field.circom")
    );
  });

  it("Uint8Array(johnguibas)", async function () {
    const witnessInput = {
      msg: [106, 111, 104, 110, 103, 117, 105, 98, 97, 115],
    };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOut = await msg_hash(new Uint8Array(witnessInput.msg));
    await circuit.assertOut(witness, { result: expectedOut });
    await circuit.checkConstraints(witness);
  });

  it("Uint8Array(abcdefghij)", async function () {
    const witnessInput = {
      msg: [97, 98, 99, 100, 101, 102, 103, 104, 105, 106],
    };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOut = await msg_hash(new Uint8Array(witnessInput.msg));
    await circuit.assertOut(witness, { result: expectedOut });
    await circuit.checkConstraints(witness);
  });
});
