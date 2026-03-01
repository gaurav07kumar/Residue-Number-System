`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 11:44:16 PM
// Design Name: 
// Module Name: binary_to_rns
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module binary_to_rns #(parameter n = 8, parameter N = 32) (X, m1,m2, m3, m4);
    input [N-1:0] X;
    output [n-1:0] m1;
     output [n+1:0] m2;
    output [n-1:0] m3;
    output [n:0] m4;

    p1 #(n, N) p1_instance(X, m1);
     p2 #(n, N) p2_instance(X, m2);
    p3 #(n, N) p3_instance(X, m3);
    p3 #(n+1, N) p4_instance(X, m4);



endmodule
module p1 #(parameter  n = 8, parameter N = 32) (X, m1);
    input [N-1:0] X;  // original number
    output [n-1:0] m1;  // residue output

    reg [n-1:0] m1;
    always @(*) begin
        m1 = X[n-1:0];
    end
endmodule

module p2 #(parameter n = 8, parameter N = 32) (X, m2);
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
    p2adder #(n) p20(q3, out3, temp1);
    p2adder #(n) p21(out2, out1, temp2);
    
    p2adder #(n) p22(temp1, temp2, m2);

endmodule 
module head #(parameter n = 8, parameter N = 32) (X, q, out);
    input [N-1:0] X;
    output [N-n-1:0] q;
    output [n+1:0] out;
    
    wire [n+1:0] rem;
    assign rem[n+1:2] = {n{1'b0}};
    divide3 #(N-n) div0(X[N-1 : n], rem, q);          
    p2adder #(n) p0(rem<<n, {2'b00,X[n-1:0]}, out);
endmodule


module divide3 #(parameter n = 8) (in, rem, q);
    input  [n-1:0] in;
    output  [1:0] rem;
    output  [n-1:0] q;
    wire [1:0] tempRem [n:0];   // remainder chain
    assign tempRem[n] = 2'b00;
    assign rem = tempRem[0];
    

    genvar i;
    generate
        for(i = 0; i < n; i = i + 1) begin : stage
            bit1_divide3 instance0 (tempRem[n-i], in[n-1-i], tempRem[n-1-i], q[n-1-i]);
        end
    endgenerate
    
endmodule

module bit1_divide3(rin, inputBit, rout, q);
    input [1:0] rin;
    input inputBit;
    output reg [1:0] rout;
    output reg q;
    always @(*) begin
        q = rin[1] | (inputBit & rin[0]);
        rout[1] = ((~inputBit) & rin[0])|(inputBit & rin[1]);
        rout[0] = ((~inputBit) & rin[1]) | (inputBit & (~rin[1]) & (~rin[0]));
    end
endmodule


module p2adder #(parameter n = 16)(
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



module p3 #(parameter  n = 8, parameter N = 32) (X, m3);
    input [N-1:0] X;  // original number
    output [n-1:0] m3;  // residue output

    wire [n-1:0] r1, r2, r3, r4;
    reg [4*n-N-1: 0] zero_padding = 0;
    
    csaWithEAC #(n) csaWithEAC_instance1({zero_padding,X[N-1:3*n]}, X[3*n-1:2*n], X[2*n-1:n], r1, r2);
    csaWithEAC #(n) csaWithEAC_instance2(r1, r2, X[n-1:0], r3, r4);
    cpa0 #(n) cpa_instance1(r3, r4, m3);
endmodule

module csaWithEAC #(parameter n = 8)(
    input [n-1:0] a,b, c,
    output [n-1:0] sum, carry
);
    wire [n-1:0] raw_carry;
    assign sum = a ^ b ^ c;
    assign raw_carry = (a&b) | (b&c) | (c&a);
    assign carry = {raw_carry[n-2:0], raw_carry[n-1]};
endmodule

module cpa0 #(parameter n = 8)(a, b, sum);
    input [n-1:0] a, b;
    output reg [n-1:0] sum;

    reg [n:0]   sum_stage1; // n+1 bits to capture the first carry
    reg [n-1:0] sum_stage2;
    reg all_ones;
    always @(*) begin
        // --- Stage 1: Standard Addition ---
        sum_stage1 = a + b;
        // --- Stage 2: End-Around Carry ---
        // Add the carry bit (sum_stage1[k]) back to the LSB.
        // Note: This second addition will NEVER generate a carry out.
        sum_stage2 = sum_stage1[n-1:0] + sum_stage1[n];
        all_ones = &sum_stage2;
        sum = all_ones ? {n{1'b0}} : sum_stage2;
    end
endmodule

