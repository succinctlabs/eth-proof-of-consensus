import path from "path";
import { expect } from "chai";
const circom_tester = require("circom_tester");
const wasm_tester = circom_tester.wasm;
import { i2osp, htfDefaults } from "./bls_utils";

describe("i2osp-1", function () {
  this.timeout(1000 * 1000);

  let circuit: any;
  before(async function () {
    circuit = await wasm_tester(
      path.join(__dirname, "circuits", "test_i2osp_1.circom")
    );
  });


  // witness[0] is whether it succeed or not (boolean)
  // witness[1] ... witness[n] is your output bytes

  it("i2osp(DST.length, 1)", async function () {
    const witnessInput = { in: htfDefaults.DST.length };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOutput = i2osp(witnessInput.in, 1);
    expect(witness[1]).to.equal(BigInt(expectedOutput[0]));
    await circuit.checkConstraints(witness);
  });

  it("i2osp(0, 1)", async function () {
    const witnessInput = { in: 0 };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOutput = i2osp(witnessInput.in, 1);
    expect(witness[1]).to.equal(BigInt(expectedOutput[0]));
    await circuit.checkConstraints(witness);
  });

  it("i2osp(1, 1)", async function () {
    const witnessInput = { in: 1 };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOutput = i2osp(witnessInput.in, 1);
    expect(witness[1]).to.equal(BigInt(expectedOutput[0]));
    await circuit.checkConstraints(witness);
  });
});

describe("i2osp-2", function () {
  this.timeout(1000 * 1000);
  let circuit: any;
  before(async function () {
    circuit = await wasm_tester(
      path.join(__dirname, "circuits", "test_i2osp_2.circom")
    );
  });

  it("i2osp(8, 2)", async function () {
    const witnessInput = { in: 8 };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOutput = i2osp(witnessInput.in, 2);
    expect(witness[1]).to.equal(BigInt(expectedOutput[0]));
    expect(witness[2]).to.equal(BigInt(expectedOutput[1]));
    await circuit.checkConstraints(witness);
  });

  it("i2osp(89, 2)", async function () {
    const witnessInput = { in: 89 };
    let witness = await circuit.calculateWitness(witnessInput);
    let expectedOutput = i2osp(witnessInput.in, 2);
    expect(witness[1]).to.equal(BigInt(expectedOutput[0]));
    expect(witness[2]).to.equal(BigInt(expectedOutput[1]));
    await circuit.checkConstraints(witness);
  });
});
