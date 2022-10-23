#!/bin/bash
PHASE1=/home/ubuntu/powersOfTau28_hez_final_27.ptau
BUILD_DIR=../build
CIRCUIT_NAME=test_aggregate_bls_verify_512
TEST_DIR=../test
OUTPUT_DIR="$BUILD_DIR"/"$CIRCUIT_NAME"_cpp

run() {
    if [ ! -d "$BUILD_DIR" ]; then
        echo "No build directory found. Creating build directory..."
        mkdir -p "$BUILD_DIR"
    fi

    # echo "****COMPILING CIRCUIT****"
    # start=`date +%s`
    # circom "$TEST_DIR"/circuits/"$CIRCUIT_NAME".circom --O1 --r1cs --sym --c --output "$BUILD_DIR"
    # end=`date +%s`
    # echo "DONE ($((end-start))s)"

    # echo "****Running make to make witness generation binary****"
    # start=`date +%s`
    # make -C "$OUTPUT_DIR"
    # end=`date +%s`
    # echo "DONE ($((end-start))s)"

    echo "****Executing witness generation****"
    start=`date +%s`
    ./"$OUTPUT_DIR"/"$CIRCUIT_NAME" "$TEST_DIR"/input_aggregate_bls_verify_512.json witness.wtns
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****Converting witness to json****"
    start=`date +%s`
    npx snarkjs wej "$OUTPUT_DIR"/witness.wtns "$OUTPUT_DIR"/witness.json
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****GENERATING ZKEY 0****"
    start=`date +%s`
    npx --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc snarkjs zkey new "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p1.zkey
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****CONTRIBUTE TO PHASE 2 CEREMONY****"
    start=`date +%s`
    npx snarkjs zkey contribute "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p1.zkey "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p2.zkey -n="First phase2 contribution" -e="some random text for entropy"
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****VERIFYING FINAL ZKEY****"
    start=`date +%s`
    npx --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc npx snarkjs zkey verify "$BUILD_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p2.zkey
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****EXPORTING VKEY****"
    start=`date +%s`
    npx snarkjs zkey export verificationkey "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p2.zkey "$OUTPUT_DIR"/"$CIRCUIT_NAME"_vkey.json
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****GENERATING PROOF FOR SAMPLE INPUT****"
    start=`date +%s`
    ~/rapidsnark/build/prover "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p2.zkey "$OUTPUT_DIR"/witness.wtns "$OUTPUT_DIR"/"$CIRCUIT_NAME"_proof.json "$OUTPUT_DIR"/"$CIRCUIT_NAME"_public.json
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****VERIFYING PROOF FOR SAMPLE INPUT****"
    start=`date +%s`
    npx snarkjs groth16 verify "$OUTPUT_DIR"/"$CIRCUIT_NAME"_vkey.json "$OUTPUT_DIR"/"$CIRCUIT_NAME"_public.json "$OUTPUT_DIR"/"$CIRCUIT_NAME"_proof.json
    end=`date +%s`
    echo "DONE ($((end-start))s)"

    echo "****EXPORTING SOLIDITY SMART CONTRACT****"
    start=`date +%s`
    npx snarkjs zkey export solidityverifier "$OUTPUT_DIR"/"$CIRCUIT_NAME"_p2.zkey verifier.sol
    end=`date +%s`
    echo "DONE ($((end-start))s)"
}

mkdir -p logs
run 2>&1 | tee logs/"$CIRCUIT_NAME"_$(date '+%Y-%m-%d-%H-%M').log
