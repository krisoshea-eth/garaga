reset() {
    rm -rf hello/
    nargo new hello
    cd hello
    nargo check
    cat << EOF > Prover.toml
x = "1"
y = "2"
EOF
    nargo execute witness
    cd ../
}

reset


BB_PATH="bb"


echo "nargo version : $(nargo --version)" # 1.0.0-beta.2
echo "bb version : $($BB_PATH --version)" # 0.74.0


run_noir_proof_basic() {
    cd hello
    local suffix="_basic"
    $BB_PATH prove -b target/hello.json -w target/witness.gz -o target/proof${suffix}.bin
    $BB_PATH write_vk -b target/hello.json -o target/vk${suffix}.bin
    if $BB_PATH verify -p target/proof${suffix}.bin -k target/vk${suffix}.bin; then
        echo "ok $suffix"
    else
        echo "Verification failed $suffix"
    fi
    $BB_PATH contract -k target/vk${suffix}.bin -o target/contract${suffix}.sol
    cd ../
}

run_noir_proof_ultra() {
    cd hello
    local suffix="_ultra"
    $BB_PATH prove_ultra_honk -b target/hello.json -w target/witness.gz -o target/proof${suffix}.bin
    $BB_PATH write_vk_ultra_honk -b target/hello.json -o target/vk${suffix}.bin
    if $BB_PATH verify_ultra_honk -p target/proof${suffix}.bin -k target/vk${suffix}.bin; then
        echo "ok $suffix"
    else
        echo "Verification failed $suffix"
    fi
    $BB_PATH contract_ultra_honk -k target/vk${suffix}.bin -o target/contract${suffix}.sol
    cd ../
}

run_noir_proof_ultra_keccak() {
    cd hello
    local suffix="_ultra_keccak"

    $BB_PATH prove_ultra_keccak_honk -b target/hello.json -w target/witness.gz -o target/proof${suffix}.bin
    $BB_PATH write_vk_ultra_keccak_honk -b target/hello.json -o target/vk${suffix}.bin
    $BB_PATH vk_as_fields_ultra_keccak_honk -b target/hello.json -k target/vk${suffix}.bin -o target/vk_fields${suffix}.bin

    if $BB_PATH verify_ultra_keccak_honk -p target/proof${suffix}.bin -k target/vk${suffix}.bin; then
        echo "ok $suffix"
    else
        echo "Verification failed $suffix"
    fi
    $BB_PATH contract_ultra_honk -k target/vk${suffix}.bin -o target/contract${suffix}.sol # contract_ultra_keccak_honk does not exist
    cd ../
}

run_noir_proof_ultra_starknet() {
    cd hello
    local suffix="_ultra_starknet"

    $BB_PATH prove_ultra_starknet_honk -b target/hello.json -w target/witness.gz -o target/proof${suffix}.bin
    $BB_PATH write_vk_ultra_starknet_honk -b target/hello.json -o target/vk${suffix}.bin
    $BB_PATH vk_as_fields_ultra_starknet_honk -b target/hello.json -k target/vk${suffix}.bin -o target/vk_fields${suffix}.bin

    if $BB_PATH verify_ultra_starknet_honk -p target/proof${suffix}.bin -k target/vk${suffix}.bin; then
        echo "ok $suffix"
    else
        echo "Verification failed $suffix"
    fi
    # $BB_PATH contract_ultra_honk -k target/vk${suffix}.bin -o target/contract${suffix}.sol # contract_ultra_keccak_honk does not exist
    cd ../
}

run_noir_proof_ultra_honk_basic_recursive_flow() {
    cd hello
    local hello_suffix="_recursive_hello_circuit"

    $BB_PATH prove_ultra_honk -b target/hello.json -w target/witness.gz -o target/proof${hello_suffix}.bin -h 1 --recursive
    $BB_PATH proof_as_fields_honk -p target/proof${hello_suffix}.bin -o target/proof_fields${hello_suffix} -h 1 --recursive
    $BB_PATH write_vk_ultra_honk -b target/hello.json -o target/vk${hello_suffix}.bin -h 1 --recursive
    $BB_PATH vk_as_fields_ultra_honk -k target/vk${hello_suffix}.bin -o target/vk_fields${hello_suffix} -h 1 --recursive
    if $BB_PATH verify_ultra_honk -p target/proof${hello_suffix}.bin -k target/vk${hello_suffix}.bin -v -h 1 --recursive; then
        echo "ok $hello_suffix"
    else
        echo "Verification failed $hello_suffix"
    fi

    local recursion_toml="../recursion/Prover.toml"
    local vk_fields="./target/vk_fields${hello_suffix}"
    local proof_fields="./target/proof_fields${hello_suffix}"

    # Ensure directory exists
    mkdir -p "$(dirname "$recursion_toml")"

    # Check if file exists
    if [[ ! -f "$vk_fields" ]]; then
        echo "Error: VK fields file not found at $vk_fields"
        return 1
    fi

    if [[ ! -f "$proof_fields" ]]; then
        echo "Error: VK fields file not found at $proof_fields"
        return 1
    fi

     # Read the verification key fields
    local vk_content=$(cat "$vk_fields")
    local proof_content=$(cat "$proof_fields")

    # Extract the array content (remove outer brackets)
    local array_content=${proof_content:1:${#proof_content}-2}

    # Split the array content by commas and preserve newlines
    IFS=$',\n' read -r -a array_elements <<< "$array_content"

    # Extract the 4th element (index 3)
    local public_input="${array_elements[3]}"

    # Remove any trailing/leading whitespace
    public_input=$(echo "$public_input" | xargs)

    # Remove the 4th element from the array
    unset "array_elements[3]"

    # Rebuild the array without the 4th element
    local modified_proof="["
    local first=true
    for element in "${array_elements[@]}"; do
        if $first; then
            modified_proof+="$element"
            first=false
        else
            modified_proof+=",$element"
        fi
    done
    modified_proof+="]"

    # Create the Prover.toml with just the verification key section
    cat > "$recursion_toml" << EOF
    "verification_key" = $(cat "$vk_fields")

    "proof"= $modified_proof
    "public_inputs"= ["$public_input"]

    "key_hash"= "0x1783e34f335b616604156e79a026d3f5c5a679b4262ec2858b58ab644d87498a"
EOF

    echo "Successfully copied verification key, proof and public inputs to $recursion_toml"

    cd ../recursion
    local recursion_suffix="_recursion_circuit"

    nargo compile

    nargo execute witness

    $BB_PATH prove_ultra_keccak_honk -b target/recursion.json -w target/witness.gz -o target/proof${recursion_suffix}.bin -h 1 --recursive

    $BB_PATH write_vk_ultra_keccak_honk -b ./target/recursion.json -o ./target/vk${recursion_suffix}.bin -h 1 --recursive

    if $BB_PATH verify_ultra_keccak_honk -p ./target/proof${recursion_suffix}.bin -k ./target/vk${recursion_suffix}.bin -v -h 1 --recursive; then
        echo "ok $recursion_suffix"
    else
        echo "Verification failed $recursion_suffix"
    fi

    garaga calldata --system ultra_keccak_honk --vk ./target/vk${recursion_suffix}.bin --proof ./target/proof${recursion_suffix}.bin --format array

    cd ../
}


echo $'\n basic'
# reset
run_noir_proof_basic

echo $'\n ultra honk'
# reset
run_noir_proof_ultra

echo $'\n ultra keccak honk'
# reset
run_noir_proof_ultra_keccak

# echo $'\n ultra starknet honk'
# reset
# run_noir_proof_ultra_starknet

echo $'\n ultra honk recursive flow'
# reset
run_noir_proof_ultra_honk_basic_recursive_flow


echo $'\n'
# Print sha256 hash of of .sol files :
for file in hello/target/*.sol; do
    echo $(md5sum $file)
done

# Print sha256 hash of of .bin files :
for file in hello/target/*.bin; do
    echo $(md5sum $file)
done
