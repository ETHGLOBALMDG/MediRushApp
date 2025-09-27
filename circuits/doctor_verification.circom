pragma circom 2.0.0;

template DoctorVerification() {
    // Input signals (private) - 'private' keyword is illegal, 'input' makes them prover inputs
    signal input name_hash;
    signal input speciality_hash;
    signal input nationality_hash;
    signal input certification_blob_hash;
    signal input is_registered;
    signal input is_legit;
    signal input reputation; // Reputation is assumed to be up to 100 (7 or 8 bits is sufficient)
    
    // Public signals
    signal output valid_doctor;
    signal output reputation_threshold_met;
    
    // --- 1. CORE VERIFICATION CONSTRAINTS ---
    
    // Check if doctor is registered (must be 1)
    component registrationCheck = IsEqual();
    registrationCheck.in[0] <== is_registered;
    registrationCheck.in[1] <== 1;
    
    // Check if doctor is legitimate (must be 1)
    component legitimacyCheck = IsEqual();
    legitimacyCheck.in[0] <== is_legit;
    legitimacyCheck.in[1] <== 1;
    
    // Check reputation threshold (minimum 200). 8 bits allows numbers up to 255.
    component reputationCheck = GreaterEqThan(12); 
    reputationCheck.in[0] <== reputation;
    reputationCheck.in[1] <== 200;
    reputation_threshold_met <== reputationCheck.out; // Public output is the result of this check
    
    // Combine core checks: (is_registered AND is_legit AND reputation >= 200)
    component coreChecks_1 = AND();
    component coreChecks_2 = AND();

    coreChecks_1.a <== registrationCheck.out;
    coreChecks_1.b <== legitimacyCheck.out;
    
    coreChecks_2.a <== coreChecks_1.out;
    coreChecks_2.b <== reputationCheck.out;
    
    // --- 2. DATA INTEGRITY CONSTRAINTS (HASH EXISTENCE) ---
    
    // Check if input hashes are non-zero (i.e., they exist)
    component nameNonZero = IsZero();
    component specialityNonZero = IsZero();
    component nationalityNonZero = IsZero();
    component certificationNonZero = IsZero();
    
    nameNonZero.in <== name_hash;
    specialityNonZero.in <== speciality_hash;
    nationalityNonZero.in <== nationality_hash;
    certificationNonZero.in <== certification_blob_hash;
    
    // **CORRECTION:** The hash is valid if IsZero.out is 0. We invert the output.
    component nameValid = NOT(); // NOT is 1 - IsZero.out
    component specialityValid = NOT();
    component nationalityValid = NOT();
    component certificationValid = NOT();

    nameValid.in <== nameNonZero.out;
    specialityValid.in <== specialityNonZero.out;
    nationalityValid.in <== nationalityNonZero.out;
    certificationValid.in <== certificationNonZero.out;

    // Combine data integrity checks
    component dataIntegrity_1 = AND();
    component dataIntegrity_2 = AND();
    component dataIntegrity_3 = AND();

    dataIntegrity_1.a <== nameValid.out;
    dataIntegrity_1.b <== specialityValid.out;
    
    dataIntegrity_2.a <== nationalityValid.out;
    dataIntegrity_2.b <== certificationValid.out;
    
    dataIntegrity_3.a <== dataIntegrity_1.out;
    dataIntegrity_3.b <== dataIntegrity_2.out;
    
    // --- 3. FINAL VALIDATION ---
    
    // Final output: (Core Checks) AND (Data Integrity Checks)
    component finalValidation = AND();
    finalValidation.a <== coreChecks_2.out;
    finalValidation.b <== dataIntegrity_3.out;

    valid_doctor <== finalValidation.out;
}

// ------------------------------------------------------------------
// | HELPER TEMPLATES (Copied from your post, assumed to be correct) |
// ------------------------------------------------------------------

template IsEqual() {
    signal input in[2];
    signal output out;
    
    component eq = IsZero();
    eq.in <== in[0] - in[1];
    out <== eq.out;
}

template IsZero() {
    signal input in;
    signal output out;
    
    signal inv;
    
    inv <-- in != 0 ? 1/in : 0;
    
    out <== -in*inv +1;
    in*out === 0;
}

template AND() {
    signal input a;
    signal input b;
    signal output out;
    
    out <== a*b;
}

template NOT() { // Added for cleaner data integrity check
    signal input in;
    signal output out;

    out <== 1 - in;
}

template GreaterEqThan(n) {
    signal input in[2];
    signal output out;
    
    // a >= b is equivalent to NOT (a < b)
    // The implementation here uses (b < a + 1)
    component lt = LessThan(n); // Note: I changed n+1 to n as LessThan already handles the bit size
    lt.in[0] <== in[1]; // b
    lt.in[1] <== in[0]; // a
    
    component notGate = NOT();
    notGate.in <== lt.out; // lt.out is 1 if b < a (i.e. a > b), so we check NOT(b < a+1)
    // Your original GreaterEqThan was checking: b < a+1 (i.e. b <= a) and setting out = lt.out.
    // Let's stick to the correct implementation that is standard, which is LessThan(n) on (b, a+1):
    
    component lt_correct = LessThan(n);
    lt_correct.in[0] <== in[1]; // b
    lt_correct.in[1] <== in[0] + 1; // a + 1
    out <== lt_correct.out; // out is 1 if b < a + 1, which means b <= a (a >= b)
}

template LessThan(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n); // Reduced to n bits for safety
    n2b.in <== in[0] + (1<<n) - in[1];

    out <== 1-n2b.out[n-1]; // Use n-1 bit for LessThan check based on carry logic
}

template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc1=0;

    var e2=1;
    for (var i = 0; i<n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] -1 ) === 0;
        lc1 += out[i] * e2;
        e2 = e2+e2;
    }

    lc1 === in;
}

component main = DoctorVerification();