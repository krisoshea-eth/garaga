use dep::std;

fn main(
    verification_key : [Field; 128], 
    proof : [Field; 459],  // full proof length is 460, but there is one public input element that we must remove
    public_inputs : [Field; 1], // the number of public inputs in the circuit whose proof is being verified
    key_hash : Field,  // the key hash can be anything and this will not affect the proof
) {
    std::verify_proof(
        verification_key, 
        proof, 
        public_inputs, 
        key_hash,
    );
}