
// LUT : 816 = 332 (two binary_to_rns) + 210 (rns_to_binary) + 56(p2) + extra for add/mul channels
// Delay: 62.469(total) = 37.832(logic) + 24.637(net)

// 
module top_module #(parameter n = 8, parameter N = 32) (a,b, oper, result);
    input [N-1:0] a, b;
    input  oper; // 0 for addition, 1 for multiplication
    output [N+2:0] result;

    wire [n-1:0] a1, a3;
    wire [n+1:0] a2;
    wire [n:0] a4;

    wire [n-1:0] b1, b3;
    wire [n+1:0] b2;
    wire [n:0] b4;

    binary_to_rns #(n, N) b2r_instance(a, a1, a2, a3, a4);
    binary_to_rns #(n, N) b2r_instance2(b, b1, b2, b3, b4);

    reg [n-1:0] add1;
    wire [n+1:0] add2;
    wire [n-1:0] add3;
    wire [n:0] add4;

    always @(*) begin
        add1 = a1+b1;
    end
    B6 #(n) add_channel2(a2, b2, add2);
    M2 #(n,0) add_channel3(a3, b3, add3);
    M2 #(n+1, 0) add_channel4(a4, b4, add4);

    wire [2*n-1:0] temp_mul1;
    wire [2*n+3:0] temp_mul2;
    wire [n-1:0] mul1;
    wire [n+1:0] mul2;
    wire [n-1:0] mul3;
    wire [n:0] mul4;
    

    assign temp_mul1 = a1 * b1;
    assign mul1 = temp_mul1[n-1:0];
    assign temp_mul2 = a2 * b2;
    p2 #(n, N) mul_channel2({{N-2*n-4{1'b0}},temp_mul2}, mul2);
    mod_2n_minus_1_mult #(n) mul_channel3(a3, b3, mul3);
    mod_2n_minus_1_mult #(n+1) mul_channel4(a4, b4, mul4);

    reg [n-1:0] residue1, residue3;
    reg [n+1:0] residue2;
    reg [n:0]   residue4;

    always @(*) begin
        if(oper)begin
            residue1 = mul1;
            residue2 = mul2;
            residue3 = mul3; 
            residue4 = mul4;
        end
        else begin
            residue1 = add1;
            residue2 = add2;
            residue3 = add3; 
            residue4 = add4;
        end
    end

    rns_to_binary #(n, N) r2b_instance(residue1, residue2, residue3, residue4, result);
    
endmodule

// Defines the modulus as 2^n - 1
// Montgomery reduction can be used for efficient modular multiplication.
module mod_2n_minus_1_mult #(parameter n = 8 ) (a,b,result);
    input  [n-1:0] a;
    input  [n-1:0] b;
    output reg[n-1:0] result;

    reg [2*n-1:0] product; // Intermediate product (up to 2n bits)
    reg [n-1:0] Sum; // Result after sum of upper and lower parts
    reg Cout; // Carry out from the addition of upper and lower parts
    reg all_ones; // Flag to check if all bits are 1
    reg overflow; // Flag to indicate if there was an overflow by range of mod.

    always @(*) begin
        // Step 1: Multiply a and b
        product = a * b;

        // Step 2: Reduce the product modulo (2^n - 1)
        {Cout, Sum} = product[n-1:0] + product[2*n-1:n]; // Add upper n bits to lower n bits
        all_ones = &Sum; // Check if all bits of Sum are 1
        overflow = Cout | all_ones; // Overflow occurs if there's a carry out or if Sum is all ones
        result = Sum + overflow;
    end
endmodule

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



// LUT : 210
// delay : 22.088(total) = 9.146(logic)+ 12.942(net)
module rns_to_binary #(parameter n = 8, parameter N = 32)( x1,x2,x3,x4,X);

    // The original is 'X'
    // Here n = 16, N = 32

    // we have used four New Moudlui set
    // Those are:
    // p1 = 2^(16) = 65536
    // p2 = 2^(17) + 2^(16) - 1 = 196607
    // p3 = 2^(16) - 1 = 65535
    // p4 = 2^(17) - 1 = 131071
    
    parameter L = 3*n + 3;

    input [n-1:0] x1; // X mod p1
    input [n+1:0] x2; // X mod p2
    input [n-1:0] x3; // X mod p3
    input [n:0] x4;   // X mod p4
    output [N+2:0] X; // original number


    wire [n+1:0] u1;
    wire [n-1:0] u2;
    wire [n:0] u3;
    wire [n:0] not_x1;
    INV1 #(n+1) inv1_instance({1'b0,x1}, not_x1);

    M1 M1_instance(x1, x2, u1);
    M2 #(n,0) M2_instance(x3, not_x1[n-1:0], u2);
    M2 #(n+1, 1) M3_instance(x4, not_x1, u3);


    // wire [n+1:0] not_u1;
    wire [n-1:0] not_g1, not_g2;
    INV1 #(n) inv2_instance1({{n-2{1'b0}},u1[n+1:n]}, not_g2);
    INV1 #(n) inv2_instance2(u1[n-1:0], not_g1);


    wire [n:0] not_h1, not_h2;
    INV1 #(n+1) inv2_instance3({{n{1'b0}},u1[n+1]}, not_h2);
    INV1 #(n+1) inv2_instance4(u1[n:0], not_h1);


    wire [n-1:0] y1, y2;
    csa_with_eac #(n) csaWithEAC_instance1(not_g1, not_g2, u2, y1, y2);
    wire [n:0] z1, z2;
    csa_with_eac #(n+1) csaWithEAC_instance2(not_h1, not_h2, u3, z1, z2);

    wire [n-1:0] v1;
    wire [n:0] v2; 
    M2 #(n,n-1) M4_instance(y1, y2, v1);
    M2 #(n+1,1) M5_instance(z1, z2, v2);

    wire [n:0] not_v2;
    INV1 #(n+1) inv3_instance(v2, not_v2);

    wire [n:0] w1;
    M2 #(n+1, 1) M6_instance({1'b0,v1}, not_v2, w1);

    wire [L-1:0] XH1, not_XH2, not_XH3, XH4, XH;
    assign XH1 = {w1,v1,u1};
    assign not_XH2 = {2'b11,~{w1, v1, v1}};
    assign not_XH3 = {{n{1'b1}},~{w1,{n+2{1'b0}}}};
    assign XH4 = {{n{1'b0}},{n{1'b0}},2'b00,w1};

    wire [L-1:0] s1,c1,s2,c2;
    csa #(L) M8_instance(XH1, not_XH2, not_XH3, s1, c1);
    csa #(L) M9_instance(s1, c1, XH4, s2, c2);

    cpa #(L) M10_instance(s2, c2, XH);
    assign X = {XH, x1};
endmodule

module INV1 #(parameter n = 8)(
    input [n-1:0] x1,
    output [n-1:0] not_x1
);
    // Simple 1's complement
    assign not_x1 = ~x1;
endmodule

module M1 #(parameter n=8)(
    // x1 is in range [0, 2^n - 1]
    // x2 is n
    input [n-1 : 0] x1,
    input [n+1 : 0] x2,
    output [n+1: 0] u1
);
    wire [n+1:0] w1; // |2* x2| mod P2
    B1 #(n) b1_instance(x2, w1);

    wire [n+1:0] w2; // |-x1| mod P2
    B2 #(n)  b2_instance(x1, w2);

    wire [n+1:0] w3; // |-2* x1| mod P2
    B3 #(n)  b3_instance(x1, w3);

    wire [n+1:0] w4, w5; // A, B output of B4 module i.e. n+2 bit CSA modulo P2
    B4 #(n)  b4_instance(w2, w3, x2, w4, w5);

    wire [n+1:0] w6, w7; // A, B output of B5 module i.e. n+2 bit CSA modulo P2
    B4 #(n)  b5_instance(w1, w4, w5, w6, w7);

    // final output sum module i.e. B6
    B6 #(n)  b6_instance(w6, w7, u1);

endmodule


module B1 #(parameter n=8) (
    input [n+1:0] x,
    output [n+1:0] y
);
    assign y[0] = x[n+1] | (x[n] & x[n-1]);
    assign y[n-1:1] = x[n-2:0];
    assign y[n] = x[n-1] ^ y[0];
    assign y[n+1] = x[n] ^ (x[n-1] & y[0]);
endmodule

module B2 #(parameter n=8) (
    input [n-1:0] x,
    output [n+1:0] y
);
    wire [n+1:0] w;
    assign w[n+1:0] = {1'b0,x[n-1:0],1'b0};
    assign y[n-1:0] = ~w[n-1:0];
    assign y[n] = w[n];
    assign y[n+1] = ~(w[n+1] | w[n]);
endmodule

module B3 #(parameter n=8) (
    input [n-1:0] x,
    output [n+1:0] y
);
    wire [n+1:0] w;
    assign w = {2'b00, x};
    assign y[n-1:0] = ~w[n-1:0];
    assign y[n] = w[n];
    assign y[n+1] = ~(w[n+1] | w[n]);
endmodule



module B4 #(parameter n=8)(
    input [n+1:0] Q, R, T,
    output [n+1:0] A, B
);
    wire [n+1:0] s;
    wire [n+2:0] c;

    assign s = Q ^ R ^ T;
    assign c[0] = 0;
    assign c[n+2:1] = (Q & R) | (R & T) | (T & Q);

    assign A[n-1:0] = s[n-1:0];
    assign A[n] = s[n] ^ (s[n+1] & s[n]);
    assign A[n+1] = s[n+1] ^ (s[n+1] & s[n]);

    assign B[0] = c[n+2] | (c[n+1] & c[n]) | (s[n+1] & s[n]);
    assign B[n-1:1] = c[n-1:1];
    assign B[n] = c[n] ^ (c[n+2] | (c[n+1] & c[n]));
    assign B[n+1] = c[n+1] ^ (c[n] & (c[n+2] | (c[n+1] & c[n])));

endmodule



module B6 #(parameter n = 16)(
    input [n+1:0] A, B,
    output wire [n+1:0] S
);
    reg [n+1:0] s;
    reg [n+2:0] carry;
    // wire w1, w2;

    integer i;
    always @(*) begin
        carry[0] = 1'b0;
        for(i=0 ; i<=n+1 ; i=i+1)begin
            s[i] = A[i] ^ B[i] ^ carry[i];
            carry[i+1] = (A[i] & B[i]) | (B[i] & carry[i]) | (A[i] & carry[i]);
        end
    end
    wire feedback, unique;
    assign unique = s[n+1] & (~s[n]) & (&s[n-1:0]);
    assign feedback = carry[n+2] | (s[n+1] & s[n]) | unique;

    wire [n+1:0] correction_value;
    // Create the correction value: 
    // If feedback is 1, set bit '0' and bit 'n' to 1. Otherwise 0.
    assign correction_value = feedback ? ((1'b1 << n) | 1'b1) : 0;
    // Final Sum: Add the correction to the raw sum
    assign S = s + correction_value;
endmodule




module M2 #(parameter k = 16, parameter m = 0)(x3, not_x1, u2);
    input [k-1:0] x3, not_x1;
    output reg [k-1:0] u2;
    // u2 = [(x3 - x1) * k2] mod P3

    // Modulo (2^k -1) multiplication of a residue x by 2^m is equivalent to express x in k-bit binary representation and then circularly left shift it by m-bits.

    // k2 = 1 = 2^(0); i.e. m = 0
    // so, u2 = [x3 + 1's complement of x1] mod P3
    // so, u2 = [x3 + not_x1] mod P3

    reg [k:0]   sum_stage1; // n+1 bits to capture the first carry
    reg [k-1:0] sum_stage2;
    always @(*) begin
        // --- Stage 1: Standard Addition ---
        // Computes x3 + ~x1. 
        // sum_stage1[k] is the Carry Out.
        // sum_stage1[k-1:0] is the intermediate Sum.
        sum_stage1 = x3 + not_x1;
        // --- Stage 2: End-Around Carry ---
        // Add the carry bit (sum_stage1[k]) back to the LSB.
        // Note: This second addition will NEVER generate a carry out.
        sum_stage2 = sum_stage1[k-1:0] + sum_stage1[k];
        if(&sum_stage2[k-1:0])begin
            u2 = 0;
        end
        else u2 = (sum_stage2 << m) | (sum_stage2 >> (k - m));
    end
endmodule





module csa #(parameter n = 16)(
    input [n-1:0] a,b,c,
    output [n-1:0] sum, carry
);
    wire [n:0] raw_carry;
    assign raw_carry[0] = 1'b1;
    assign sum = a ^ b ^ c;
    assign raw_carry[n:1] = (a&b) | (b&c) | (c&a);
    assign carry = raw_carry[n-1:0];
endmodule

module csa_with_eac #(parameter n = 8)(
    input [n-1:0] a,b, c,
    output [n-1:0] sum, carry
);
    wire [n-1:0] raw_carry;
    assign sum = a ^ b ^ c;
    assign raw_carry = (a&b) | (b&c) | (c&a);
    assign carry = {raw_carry[n-2:0], raw_carry[n-1]};
endmodule

module cpa #(parameter n=16)(
    input [n-1:0] a,b,
    output [n-1:0] sum
);
    assign sum = a+b;
endmodule
