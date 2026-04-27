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

// LUT : 116
// Delay : 21.943(total), 16.091(logic), 5.852(net)
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
// LUT : 0
// Delay : 4.305(total) = 3.506(logic) + 0.809(net)
// WHY THERE IS LOGIC DELAY WHEN THIS IS JUST A WIRE ASSIGNMENT? Because we are using an always @(*) block to implement the combinational logic, which introduces a small amount of logic delay due to the way the Verilog simulator schedules events and evaluates the always block. If we were to implement this as a continuous assignment (e.g., assign m1 = X[n-1:0];), it would be purely combinational with no logic delay, and the output would update immediately with changes in the input. However, using an always block allows for more complex logic if needed in the future, at the cost of introducing a small delay.
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
// LUT : 56
// Delay : 21.943(total) = 16.091(logic) + 5.852(net)
module p2 #(
    parameter n = 8,
    parameter N = 32
)(
    input  wire [N-1:0] X,
    output wire [n+1:0] P
);

    // --------------------------------------------------------
    // Design-Time Constants
    // --------------------------------------------------------
    // M = 3*(2^8) - 1 = 767
    localparam [n+1:0] M = 3 * (1 << n) - 1;
    
    // k = N + 2 = 34. This shift amount guarantees our fractional error 
    // is small enough that the estimated quotient is off by at most 1.
    localparam k = N + 2;
    
    // MU = floor(2^34 / 767) = 22398786.
    // We use a 64-bit literal (64'h1) to prevent the Verilog compiler 
    // from overflowing its internal 32-bit integers during calculation.
    localparam [31:0] MU = (64'h1 << k) / M;

    // --------------------------------------------------------
    // Step 1: Estimate the Quotient (q = X * MU >> k)
    // --------------------------------------------------------
    // X is 32 bits, MU requires 25 bits. The product requires 57 bits.
    wire [63:0] X_MU = X * MU; 
    
    // Right-shift by k (34 bits) simply by selecting the upper bits.
    // The quotient for 32-bit X / 767 requires at most 23 bits.
    wire [22:0] q = X_MU[56:k];

    // --------------------------------------------------------
    // Step 2: Calculate the Remainder (r = X - q * M)
    // --------------------------------------------------------
    // Even though X and q*M are large, we know mathematically that 
    // their difference (the remainder) will be close to M (under 1534). 
    // We can safely truncate the subtraction to 11 bits to save routing.
    wire [10:0] q_M_trunc = (q * M); 
    wire [10:0] r = X[10:0] - q_M_trunc;

    // --------------------------------------------------------
    // Step 3: Final Conditional Correction
    // --------------------------------------------------------
    // If our estimated quotient was underestimated by 1, r will be >= M.
    // Subtract M once to get the final exact modulo.
    assign P = (r >= M) ? (r - M) : r;

endmodule


// ===========================================================================
// p3 : X mod p3   where p3 = 2^n - 1
// Fully behavioral: CSA-with-EAC and CPA-with-EAC stages are inlined.
// ===========================================================================
// LUT : 30
// Delay : 8.901(total) = 4.745(logic) + 4.156(net)
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