reset() {
    if [[ -d "hello" ]]; then
        echo "Deleting hello directory..."
        rm -rI hello/
    else
        echo "Directory 'hello' does not exist."
    fi
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

run_noir_proof_ultra_honk_recursive_flow() {
    cd hello
    local suffix="_ultra_honk_recursive_flow"

    $BB_PATH prove_ultra_honk -b target/hello.json -w target/witness.gz -o target/proof -h 1 --recursive 
    $BB_PATH proof_as_fields_honk -p target/proof -o target/proof_fields -h 1 --recursive
    $BB_PATH write_vk_ultra_honk -h 1 -b target/hello.json -o target/vk --recursive
    $BB_PATH vk_as_fields_ultra_honk -k target/vk -o target/vk_fields -h 1
    $BB_PATH verify_ultra_honk -p target/proof -v target/vk.bin -h 1 --recursive

    local recursion_toml="../recursion/Prover.toml"
    local vk_fields="./target/vk_fields"
    local proof_fields="./target/proof_fields"
    
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

    nargo compile

    nargo execute witness

    $BB_PATH prove_ultra_keccak_honk -b target/recursion.json -w target/witness.gz -o target/proof -h 1 --recursive

    $BB_PATH write_vk_ultra_keccak_honk -b ./target/recursion.json -o ./target/vk -h 1 --recursive

    $BB_PATH verify_ultra_keccak_honk -p ./target/proof -k ./target/vk -v -h 1 --recursive

    # Below is the garaga command that fails
    garaga calldata --system ultra_keccak_honk --vk ./target/vk --proof ./target/proof --format array
}

echo $'\n ultra honk recursive flow'
# reset
run_noir_proof_ultra_honk_recursive_flow
