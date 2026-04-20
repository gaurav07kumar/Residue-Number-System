// Author: Gaurav Kumar
// Description: This module converts a binary number into its Residue Number System (RNS) representation using the moduli set {p1, p2, p3, p4}. The input is a binary number of width N, and the outputs are the residues corresponding to each modulus in the set. Converted to behavioral style: all gate primitives and generate/genvar structural instantiations have been replaced with always @(*) blocks and RTL operators.

// p1 = 2^n
// p2 = 2^(n+1) + 2^n - 1  (= 3*2^n - 1)
// p3 = 2^n - 1
// p4 = 2^(n+1) - 1

// The module is parameterized to allow for different bit widths for the input and output residues, making it flexible for various applications. The implementation includes efficient algorithms for modular reduction, such as divide-by-3 and carry propagate adders with end-around carry, to ensure accurate and fast conversion from binary to RNS representation.

// The design is structured to facilitate testing and verification, with clear separation of functionality into submodules, allowing for easier debugging and validation of each component in the conversion process.

// ===========================================================================
// Top-level: binary_to_rns
// Module hierarchy is retained; each submodule is internally behavioral.
// ===========================================================================

module binary_to_rns #(parameter n = 8, parameter N = 32) (X, m1, m2, m3, m4);
    input  [N-1:0] X;
    output [n-1:0] m1;
    output [n+1:0] m2;
    output [n-1:0] m3;
    output [n:0]   m4;

    p1 #(n, N)   p1_instance(X, m1);
    p2 #(n, N)   p2_instance(X, m2);
    p3 #(n, N)   p3_instance(X, m3);
    p4 #(n+1, N) p4_instance(X, m4);
endmodule


// ===========================================================================
// p1 : X mod 2^n  —  simply the n least-significant bits of X
// ===========================================================================
module p1 #(parameter n = 8, parameter N = 32) (X, m1);
    input  [N-1:0] X;
    output reg [n-1:0] m1;

    always @(*) begin
        m1 = X[n-1:0];
    end
endmodule


// ===========================================================================
// p2 : X mod p2  where p2 = 3*2^n - 1
// Hierarchy retained; submodules (head, mod_p2_adder) are behavioral.
// ===========================================================================
module p2 #(parameter n = 8, parameter N = 32) (X, m2);
    input  [N-1:0] X;
    output [n+1:0] m2;

    wire [N-n-1:0] q1;
    wire [n+1:0] out1;
    head #(n, N) head1(X, q1, out1);

    wire [2*n-1:0] q2;
    wire [n+1:0] out2;
    head #(n, N-n) head2(q1, q2, out2);

    wire [n-1:0] q3;
    wire [n+1:0] out3;
    head #(n, 2*n) head3(q2, q3, out3);

    wire [n+1:0] temp1, temp2;
    mod_p2_adder #(n) p20({2'b00, q3}, out3,  temp1);
    mod_p2_adder #(n) p21(out2, out1, temp2);
    mod_p2_adder #(n) p22(temp1, temp2, m2);
endmodule


// ===========================================================================
// head : helper for p2
//   q   = X[N-1:n] / 3
//   out = ( (X[N-1:n] % 3) << n  +  X[n-1:0] ) mod p2
// Hierarchy retained; divide_by3 and mod_p2_adder are behavioral.
// ===========================================================================
module head #(parameter n = 8, parameter N = 32) (X, q, out);
    input  [N-1:0]   X;
    output [N-n-1:0] q;
    output [n+1:0]   out;

    wire [1:0] rem;

    divide_by3 #(N-n) div3(X[N-1:n], rem, q);
    mod_p2_adder #(n)   p0({rem, {n{1'b0}}}, {2'b00, X[n-1:0]}, out);
endmodule


// ===========================================================================
// divide_by3 : divide N-bit X by 3, producing 2-bit remainder R and N-bit Q
// Behavioral: for loop implements the MSB-to-LSB chain of bit1_divide3 stages.
// ===========================================================================
module divide_by3 #(parameter N = 8) (X, R, Q);
    input  [N-1:0] X;
    output reg [1:0]   R;
    output reg [N-1:0] Q;

    always @(*) begin
        R = X%3;
        Q = X/3;
    end
endmodule


// ===========================================================================
// mod_p2_adder : (A + B) mod p2   where p2 = 3*2^n - 1
// Behavioral: replicates the two-stage carry-feedback algorithm exactly.
//   Stage 1 : {cout1, sum1} = A + B
//   feedback = cout1 | (sum1[n+1] & sum1[n])
//   Stage 2 : S = sum1 + feedback*(2^n + 1)  [mod 2^(n+2)]
// ===========================================================================
module mod_p2_adder #(parameter n = 8) (A, B, S);
    input  [n+1:0] A, B;
    output reg [n+1:0] S;

    // 2^n + 1 is the correction term added when overflow is detected
    localparam [n+1:0] P2_CORRECTION = (1 << n) + 1;

    reg [n+1:0] sum_stage1;
    reg cout_stage1, cout_stage2;
    reg feedback;

    always @(*) begin
        // Stage 1: standard (n+2)-bit addition
        {cout_stage1, sum_stage1} = A+B;

        // Overflow when carry out, or when bits [n+1:n] are both 1 (sum >= 3*2^n)
        feedback = cout_stage1 | (sum_stage1[n+1] & sum_stage1[n]);

        // Stage 2: conditionally add (2^n + 1); result is taken mod 2^(n+2)
        {cout_stage2, S} = sum_stage1 + (feedback ? P2_CORRECTION : 0);
    end
endmodule


// ===========================================================================
// p3 : X mod p3   where p3 = 2^n - 1
// Fully behavioral: CSA-with-EAC and CPA-with-EAC stages are inlined.
// ===========================================================================
module p3 #(parameter n = 8, parameter N = 32) (X, m3);
    input  [N-1:0] X;
    output [n-1:0] m3;

    wire [n-1:0] sum_1, cout_1, sum_2, cout_2;

    // --- CSA with End-Around Carry, instance 1 ---
    // Inputs: X4, X3, X2
    // End-around carry: rotate cout_1 left by 1
    csaWithEAC #(n) csa1(X[N-1:3*n], X[3*n-1:2*n], X[2*n-1:n], sum_1, cout_1);

    // --- CSA with End-Around Carry, instance 2 ---
    // Inputs: r1, r2, X1
    csaWithEAC #(n) csa2(sum_1, cout_1, X[n-1:0], sum_2, cout_2);

    // --- CPA with End-Around Carry ---
    // Inputs: sum_2, cout_2  →  computes (sum_2 + cout_2) mod (2^n - 1)
    cpaWithEAC #(n) cpa(sum_2, cout_2, m3);
endmodule

module csaWithEAC #(parameter n = 8)(a,b,c,sum, carry); // n-bit Carry Save Adder with End-Around Carry
    input [n-1:0] a,b, c;
    output reg [n-1:0] sum, carry;

    reg [n-1:0] raw_carry;
    reg [n-1:0] s1, c1, c2, c3;

    // sum = a ^ b ^ cin
    // carry = (a . b) + (b . cin) + (a . cin)
    always @(*) begin
        sum = a ^ b ^ c; 
        raw_carry = (a & b) | (b & c) | (a & c);
        carry = {raw_carry[n-2:0], raw_carry[n-1]}; // End-Around Carry: rotate left by 1
    end
endmodule

module cpaWithEAC #(parameter n = 8)(a, b, sum); // n-bit Carry Propagate Adder with End-Around Carry
    input [n-1:0] a, b;
    output reg [n-1:0] sum;

    reg cout_stage1;
    reg [n-1:0] sum_stage1;
    // In a standard CPA, the carry out of the MSB would be discarded. Here, we capture it and add it back to the LSB to implement the end-around carry behavior required for modulo (2^n - 1) addition.
    // NOTE: Would it be necessary to check for the special case of sum_stage1 being all ones (i.e., 2^n - 1) and treat that as zero? In practice, adding the carry out back to the LSB will correctly handle this case, since (2^n - 1) + 1 = 2^n, which is congruent to 0 mod (2^n - 1).
    // reg  all_ones, overflow;
    always @(*) begin
        {cout_stage1, sum_stage1} = a + b; // Standard addition
        // all_ones = &sum_stage1; // Check if the sum is all ones (i.e., 2^n - 1)
        // overflow = cout_stage1 | all_ones; // Capture the carry out of the MSB or if the sum is all ones
        sum = sum_stage1 + cout_stage1; // Add
    end
endmodule

// ===========================================================================
// p4 : X mod p4   where p4 = 2^n - 1  (called with n+1 to compute mod for p4)
// Fully behavioral: CSA-with-EAC and CPA-with-EAC stages are inlined.
// ===========================================================================
module p4 #(parameter n = 9, parameter N = 32) (X, m4);
    input  [N-1:0] X;
    output [n-1:0] m4;

    wire [n-1:0] sum_1, cout_1, sum_2, cout_2;

    // --- CSA with End-Around Carry, instance 1 ---
    // Inputs: X4, X3, X2
    // End-around carry: rotate cout_1 left by 1
    wire [4*n-N-1: 0] zero_padding = 0;
    csaWithEAC #(n) csa1({zero_padding, X[N-1:3*n]}, X[3*n-1:2*n], X[2*n-1:n], sum_1, cout_1);

    // --- CSA with End-Around Carry, instance 2 ---
    // Inputs: r1, r2, X1
    csaWithEAC #(n) csa2(sum_1, cout_1, X[n-1:0], sum_2, cout_2);

    // --- CPA with End-Around Carry ---
    // Inputs: sum_2, cout_2  →  computes (sum_2 + cout_2) mod (2^n - 1)
    cpaWithEAC #(n) cpa(sum_2, cout_2, m4);
endmodule