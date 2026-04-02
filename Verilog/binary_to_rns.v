// Author: Gaurav Kumar
// Description: This module converts a binary number into its Residue Number System (RNS) representation using the moduli set {p1, p2, p3, p4}. The input is a binary number of width N, and the outputs are the residues corresponding to each modulus in the set. The design utilizes various submodules for performing modular reduction and addition operations required for the conversion process.

// p1 = 2^n
// p2 = 2^(n+1) + 2^n - 1
// p3 = 2^n - 1
// p4 = 2^(n+1) - 1

// The module is parameterized to allow for different bit widths for the input and output residues, making it flexible for various applications. The implementation includes efficient algorithms for modular reduction, such as divide-by-3 and carry propagate adders with end-around carry, to ensure accurate and fast conversion from binary to RNS representation.
// The design is structured to facilitate testing and verification, with clear separation of functionality into submodules, allowing for easier debugging and validation of each component in the conversion process.

module binary_to_rns #(parameter n = 8, parameter N = 32) (X, m1,m2, m3, m4);
    input [N-1:0] X;
    output [n-1:0] m1;
     output [n+1:0] m2;
    output [n-1:0] m3;
    output [n:0] m4;

    p1 #(n, N) p1_instance(X, m1);
    p2 #(n, N) p2_instance(X, m2);
    p3 #(n, N) p3_instance(X, m3);
    p4 #(n+1, N) p4_instance(X, m4);

endmodule

module p1 #(parameter  n = 8, parameter N = 32) (X, m1); // X mod p1 = m1 where p1 = 2^n
    input [N-1:0] X;  // original number
    output [n-1:0] m1;  // residue output

    assign m1 = X[n-1:0]; // Modulo p1 = 2^n is simply the n least significant bits of X
endmodule

// Try p2 with help of montegomery form.
module p2 #(parameter n = 8, parameter N = 32) (X, m2); // X mod p2 = m2 where p2 = 2^(n+1) + 2^n - 1
    input [N-1:0] X; 
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
    mod_p2_adder #(n) p20({2'b00,q3}, out3, temp1);
    mod_p2_adder #(n) p21(out2, out1, temp2);
    
    mod_p2_adder #(n) p22(temp1, temp2, m2);

endmodule 
module head #(parameter n = 8, parameter N = 32) (X, q, out); 
    // out = (((X[N-1:n] % 3) << n) + X[n-1:0]) mod p2
    // q = X[N-1:n] / 3
    input [N-1:0] X;
    output [N-n-1:0] q;
    output [n+1:0] out;
    
    wire [1:0] rem;
    divide_by3 #(N-n) div0(X[N-1 : n], rem[1:0], q);          
    mod_p2_adder #(n) p0({rem,{n{1'b0}}}, {2'b00,X[n-1:0]}, out);
endmodule


module divide_by3 #(parameter N = 8) (X,R,Q); // Divide the N-bit number X by 3, producing a 2-bit remainder R and an (N-1)-bit quotient Q. 
// The division is performed using a chain of N stages, where each stage processes one bit of the input number X (starting from the most significant bit) and updates the partial remainder and quotient accordingly.
    input  [N-1:0] X;
    output [1:0]   R;
    output [N-1:0] Q;
    // -------------------------------------------------------------------------
    // Remainder chain: rem[i] holds the 2-bit partial remainder after
    // processing the (N-i)-th bit.
    // rem[0]  is seeded with 0 (nothing processed yet, MSB side).
    // rem[N]  is the final remainder after all bits are consumed.
    // -------------------------------------------------------------------------
    wire [1:0] rem [0:N];          // partial remainder chain
    assign rem[0] = 2'b00;         // initial remainder = 0
    assign R      = rem[N];        // final remainder

    // -------------------------------------------------------------------------
    // Generate one bit1_divide3 stage per input bit (MSB → LSB order)
    // -------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage
            bit1_divide3 u (rem[i], X[N-1-i], rem[i+1], Q[N-1-i]);
        end
    endgenerate
endmodule

// =============================================================================
// Module      : bit1_divide3
// Description : Single-bit stage of the divide-by-3 circuit.
//
//   Truth table for (rin, inputBit) → (q, rout):
//
//   rin  inputBit │  q   rout    Explanation
//   ─────────────┼─────────────────────────────────────────────────────
//   00     0     │  0   00      P=0, 0<3  → Q=0, R=0
//   00     1     │  0   01      P=1, 1<3  → Q=0, R=1
//   01     0     │  0   10      P=2, 2<3  → Q=0, R=2
//   01     1     │  1   00      P=3, 3≥3  → Q=1, R=0
//   10     0     │  1   01      P=4, 4≥3  → Q=1, R=1
//   10     1     │  1   10      P=5, 5≥3  → Q=1, R=2
//   11     x     │  x   xx      (invalid – never occurs)
//
// =============================================================================

module bit1_divide3 ( rin, inputBit, rout, q ); // 1-bit stage of divide-by-3 circuit -> delay of 4 gates
    input  [1:0] rin;       // incoming partial remainder (0, 1, or 2)
    input        inputBit;  // current input bit (MSB-first)
    output  [1:0] rout;  // outgoing partial remainder
    output        q;     // quotient bit for this position

    assign q =  rin[1] | (rin[0] & inputBit); // 2 Gate Delays
    assign rout[1] = (~inputBit & rin[0]) | ( inputBit & rin[1]); // 3 Gate Delays
    assign rout[0] = (~inputBit & rin[1]) | ( inputBit & ~rin[1] & ~rin[0]); // 4 Gate Delays
endmodule

// The unique condition is designed to handle the specific case of adding two numbers that result in 47 (101111_2 in 6 bits). 
// A+B <= 47 -> sum = A+B 
// A+B > 47 -> sum = (A+B+1+2^n) mod 2^(n+2)
// Assuming n = 4
// 47 is congruent to 0 mod 47
// 47 is conguent to 47 mod 47
module mod_p2_adder #(parameter n = 8)(A, B, S); // (A+B) mod p2 where p2 = 2^(n+1) + 2^n - 1, Architecture given in paper.
    input [n+1:0] A, B;
    output [n+1:0] S;

    wire [n+1:0] sum_stage1;
    wire cout_stage1;
    wire feedback0, feedback;

    csa_even #(n+2) csa_stage1(A,B,1'b0, sum_stage1, cout_stage1); // First stage: Standard addition using Carry Select Adder
    and g1(feedback0, sum_stage1[n+1], sum_stage1[n]);
    or g2(feedback, cout_stage1, feedback0); 

    wire cout_stage2;
    csa_even #(n+2) csa_stage2(sum_stage1, {1'b0,feedback,{n{1'b0}}}, feedback, S, cout_stage2); // S = sum_stage1 + feedback, where feedback is either 0 or 2^n + 1, using Carry Select Adder

endmodule



module p3 #(parameter  n = 8, parameter N = 32) (X, m3);
    input [N-1:0] X;  // original number
    output [n-1:0] m3;  // residue output

    wire [n-1:0] r1, r2, r3, r4;
    
    csaWithEAC #(n) csaWithEAC_instance1(X[N-1:3*n], X[3*n-1:2*n], X[2*n-1:n], r1, r2);
    csaWithEAC #(n) csaWithEAC_instance2(r1, r2, X[n-1:0], r3, r4);
    cpaWithEAC_even #(n) cpa_instance1(r3, r4, m3); // Using cpaWithEAC_even since n=8 is even
endmodule

module p4 #(parameter  n = 9, parameter N = 32) (X, m4); // X mod p4 = m4 where p4 = 2^(n+1) - 1 
    input [N-1:0] X;  // original number
    output [n-1:0] m4;  // residue output

    wire [n-1:0] r1, r2, r3, r4;
    wire [4*n-N-1: 0] zero_padding = 0;
    
    csaWithEAC #(n) csaWithEAC_instance1({zero_padding,X[N-1:3*n]}, X[3*n-1:2*n], X[2*n-1:n], r1, r2);
    csaWithEAC #(n) csaWithEAC_instance2(r1, r2, X[n-1:0], r3, r4);
    cpaWithEAC_odd #(n) cpa_instance1(r3, r4, m4); // Using cpaWithEAC_odd since n=9 is odd
endmodule

module csaWithEAC #(parameter n = 8)(a,b,c,sum, carry); // n-bit Carry Save Adder with End-Around Carry
    input [n-1:0] a,b, c;
    output [n-1:0] sum, carry;

    wire [n-1:0] raw_carry;
    wire [n-1:0] s1, c1, c2, c3;

    // sum = a ^ b ^ cin
    // carry = (a . b) + (b . cin) + (a . cin)
    nbit_xor #(n) g1(s1, a, b); // n-bit XOR gate
    nbit_xor #(n) g2(sum, s1, c); // n-bit XOR gate
    nbit_and #(n) g3(c1, a, b); // n-bit AND gate
    nbit_and #(n) g4(c2, b, c); // n-bit AND gate
    nbit_and #(n) g5(c3, a, c); // n-bit AND gate
    nbit_3input_or #(n) g6(raw_carry, c1, c2, c3);  // 3-input n-bit OR gate
    // assign sum = a ^ b ^ c;
    // assign raw_carry = (a&b) | (b&c) | (c&a);
    assign carry = {raw_carry[n-2:0], raw_carry[n-1]};
endmodule


module cpaWithEAC_even #(parameter n = 8)(a, b, sum); // n-bit Carry Propagate Adder with End-Around Carry, where n is even
    input [n-1:0] a, b;
    output [n-1:0] sum;

    wire [n-1:0]   sum_stage1; 
    wire cout_stage1;
    wire all_ones, overflow;
    wire cout_stage2;

    csa_even #(n) csa_instance(a, b, 1'b0, sum_stage1, cout_stage1); // First stage: Standard addition using Carry Select Adder
    // --- Stage 2: End-Around Carry ---
    // Add the carry bit (sum_stage1[n]) back to the LSB.
    // Note: This second addition will NEVER generate a carry out.
    assign all_ones = &sum_stage1[n-1:0]; // Check if the sum is all ones (i.e., 2^n - 1)
    or g1(overflow, cout_stage1, all_ones); // Capture the carry out of the MSB or if the sum is all ones
    csa_even #(n) csa_stage2({n{1'b0}}, sum_stage1, overflow, sum, cout_stage2); // Add the carry back to the LSB using Carry Select Adder
endmodule

module csa_even #(parameter N = 8) (a,b, cin, sum, cout); // N-bit Carry Select Adder using 2 N/2-bit rca as building blocks; where N is even
    input [N-1:0] a,b;
    input cin;
    output [N-1:0] sum;
    output cout;
    parameter n = N/2; // Split the N bits into two halves of n bits each

    wire [n-1:0] Sum_stage2_0, Sum_stage2_1; // Two possible sums for the second stage (carry-in = 0 or 1)
    wire cout_stage2_0, cout_stage2_1; // Corresponding carry-outs for the second stage
    
    wire cout_stage1;
    rca #(n) rca_stage1(a[n-1:0], b[n-1:0], cin, sum[n-1:0], cout_stage1); // Stage 1: Add the least significant n bits with cin
    rca #(n) rca_stage2_0(a[2*n-1:n], b[2*n-1:n], 1'b0, Sum_stage2_0, cout_stage2_0); // Stage 2: Precompute the sum for the next n bits assuming carry-in = 0
    rca #(n) rca_stage2_1(a[2*n-1:n], b[2*n-1:n], 1'b1, Sum_stage2_1, cout_stage2_1); // Stage 2: Precompute the sum for the next n bits assuming carry-in = 1

    nbit_2x1_mux #(n) mux_stage2_sum(Sum_stage2_0, Sum_stage2_1, cout_stage1, sum[2*n-1:n]); // Select the correct sum for the next n bits based on the carry-out from stage 1
    mux mux_stage2_cout(cout_stage2_0, cout_stage2_1, cout_stage1, cout); // Select the correct carry-out for the final output based on the carry-out from stage 1
endmodule

module cpaWithEAC_odd #(parameter n = 9)(a, b, sum); // n-bit Carry Propagate Adder with End-Around Carry, where n is odd
    input [n-1:0] a, b;
    output [n-1:0] sum;

    wire [n-1:0]   sum_stage1; 
    wire cout_stage1;
    wire all_ones, overflow;
    wire cout_stage2;

    csa_odd #(n) csa_instance(a, b, 1'b0, sum_stage1, cout_stage1); // First stage: Standard addition using Carry Select Adder
    // --- Stage 2: End-Around Carry ---
    // Add the carry bit (sum_stage1[n]) back to the LSB.
    // Note: This second addition will NEVER generate a carry out.
    assign all_ones = &sum_stage1[n-1:0]; // Check if the sum is all ones (i.e., 2^n - 1)
    or g1(overflow, cout_stage1, all_ones); // Capture the carry out of the MSB or if the sum is all ones
    csa_odd #(n) csa_stage2({n{1'b0}}, sum_stage1, overflow, sum, cout_stage2); // Add the carry back to the LSB using Carry Select Adder
endmodule

module csa_odd #(parameter N = 9) (a,b, cin, sum, cout); // N-bit Carry Select Adder using N/2-bit and (N/2+1)-bit rca as building blocks; where N is odd
    input [N-1:0] a,b;
    input cin;
    output [N-1:0] sum;
    output cout;
    parameter n = N/2; // Split the N bits into two halves of n bits each

    // Stage 1: Add the least significant n bits with cin
    // Stage 2: Precompute the sum for the next n+1 bits assuming carry-in = 0 and 1
    wire [n:0] Sum_stage2_0, Sum_stage2_1; // Two possible sums for the second stage (carry-in = 0 or 1)
    wire cout_stage2_0, cout_stage2_1; // Corresponding carry-outs for the second stage
    
    wire cout_stage1;
    rca #(n) rca_stage1(a[n-1:0], b[n-1:0], cin, sum[n-1:0], cout_stage1); // Stage 1: Add the least significant n bits with cin
    rca #(n+1) rca_stage2_0(a[2*n: n], b[2*n:n], 1'b0, Sum_stage2_0, cout_stage2_0); // Stage 2: Precompute the sum for the next n+1 bits assuming carry-in = 0
    rca #(n+1) rca_stage2_1(a[2*n: n], b[2*n:n], 1'b1, Sum_stage2_1, cout_stage2_1); // Stage 2: Precompute the sum for the next n+1 bits assuming carry-in = 1

    nbit_2x1_mux #(n+1) mux_stage2_sum(Sum_stage2_0, Sum_stage2_1, cout_stage1, sum[2*n: n]); // Select the correct sum for the next n+1 bits based on the carry-out from stage 1
    mux mux_stage2_cout(cout_stage2_0, cout_stage2_1, cout_stage1, cout); // Select the correct carry-out for the final output based on the carry-out from stage 1
endmodule

module rca #(parameter n = 8) (a,b, cin, sum, carry); // n-bit Ripple Carry Adder built from full adders 
    input [n-1:0] a,b;
    input cin;
    output [n-1:0] sum;
    output carry;

    wire [n-1:0] carry_chain; // Internal wires to connect carries between full adders

    genvar i;
    generate
        for(i=0; i<n; i=i+1) begin : full_adder_stage
            if(i==0) begin
                full_adder fa(a[i], b[i], cin, sum[i], carry_chain[i]);
            end else begin
                full_adder fa(a[i], b[i], carry_chain[i-1], sum[i], carry_chain[i]);
            end
        end
    endgenerate
    assign carry = carry_chain[n-1]; // Final carry-out from the last full adder
endmodule     

module half_adder(a,b, sum, carry);
    input a,b;
    output sum, carry;

    // carry = a . b
    // sum = a ^ b
    and g1(carry, a, b);
    xor g2(sum, a, b);
endmodule

module full_adder(a,b, cin, sum, carry); // 1-bit full adder with carry-in
    input a,b, cin;
    output sum, carry;
    wire s1, c1, c2, c3;

    // sum = a ^ b ^ cin
    // carry = (a . b) + (b . cin) + (a . cin)
    xor g1(s1, a, b);
    xor g2(sum, s1, cin);
    and g3(c1, a, b);
    and g4(c2, b, cin);
    and g5(c3, a, cin);
    or g6(carry, c1, c2, c3);  // 3-input OR gate
endmodule


module mux(i0,i1,sel,out); // 2-to-1 Multiplexer
    input i0, i1, sel;
    output out;

    // out = (~sel & i0) | (sel & i1 );
    wire not_sel;
    not g1(not_sel, sel);
    wire and0, and1;
    and g2(and0, i0, not_sel);
    and g3(and1, i1, sel);
    or g4(out, and0, and1);
endmodule

module nbit_2x1_mux #(parameter n = 8) (i0, i1, sel, out); // n-bit 2-to-1 Multiplexer
    input [n-1:0] i0, i1;
    input sel;
    output [n-1:0] out;

    // out = (~sel & i0) | (sel & i1 );
    wire not_sel;
    not g1(not_sel, sel);
    wire [n-1:0] and0, and1;
    nbit_and #(n) g2(and0, i0, {n{not_sel}});
    nbit_and #(n) g3(and1, i1, {n{sel}});
    nbit_or #(n) g4(out, and0, and1);
endmodule


// module nbit_not #(parameter n = 8) (out,a); // n-bit NOT gate
//     input [n-1:0] a;
//     output [n-1:0] out;
//     assign out = ~a;
// endmodule

module nbit_and #(parameter n = 8) (out,a,b); // n-bit AND gate
    input [n-1:0] a,b;
    output  [n-1:0] out;
    assign out = a & b;
endmodule

module nbit_or #(parameter n = 8) (out,a,b); // n-bit OR gate
    input [n-1:0] a,b;
    output  [n-1:0] out;
    assign out = a | b;
endmodule

module nbit_3input_or #(parameter n = 8) (out,a,b,c); // n-bit 3-input OR gate
    input [n-1:0] a,b,c;
    output [n-1:0] out;
    assign out = a | b | c;
endmodule

module nbit_xor #(parameter n = 8) (out,a,b); // n-bit XOR gate
    input [n-1:0] a,b;
    output [n-1:0] out;
    assign out = a ^ b;
endmodule
