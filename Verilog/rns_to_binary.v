`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 11:00:52 PM
// Design Name: 
// Module Name: rns_to_binary
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

// LUT : 209
// Delay : 20.714(total), 10.431(logic), 10.283(net)
module rns_to_binary #(parameter n = 8, parameter N = 27)( x1,x2,x3,x4,X);

    // The original is 'X'
    // Here n = 16, N = 51
    // we have used four New Moudlui set
    // Those are:
    // p1 = 2^(16) = 65536
    // p2 = 2^(17) + 2^(16) - 1 = 196607
    // p3 = 2^(16) - 1 = 65535
    // p4 = 2^(17) - 1 = 131071
    
    input [n-1:0] x1; // X mod p1
    input [n+1:0] x2; // X mod p2
    input [n-1:0] x3; // X mod p3
    input [n:0] x4;   // X mod p4
    output [N+n-1:0] X; // original number



    wire [n+1:0] u1;
    wire [n-1:0] u2;
    wire [n:0] u3;
    reg [n:0] not_x1;

    always @(*) begin
        not_x1 = ~{1'b0,x1};
    end

    M1 M1_instance(x1, x2, u1);
    M2 #(n,0) M2_instance(x3, not_x1[n-1:0], u2);
    M2 #(n+1, 1) M3_instance(x4, not_x1, u3);


    reg [n-1:0] not_g1, not_g2;
    reg [n:0] not_h1, not_h2;

    always @(*) begin
        not_g2 = ~{{n-2{1'b0}},u1[n+1:n]};
        not_g1 = ~u1[n-1:0];

        not_h2 = ~{{n{1'b0}},u1[n+1]};
        not_h1 = ~u1[n:0];
    end


    wire [n-1:0] y1, y2;
    csaWithEAC #(n) csaWithEAC_instance1(not_g1, not_g2, u2, y1, y2);
    wire [n:0] z1, z2;
    csaWithEAC #(n+1) csaWithEAC_instance2(not_h1, not_h2, u3, z1, z2);

    wire [n-1:0] v1;
    wire [n:0] v2; 
    M2 #(n,n-1) M4_instance(y1, y2, v1);
    M2 #(n+1,1) M5_instance(z1, z2, v2);

    reg [n:0] not_v2;
    always @(*) begin
        not_v2 = ~v2;
    end

    wire [n:0] w1;
    M2 #(n+1, 1) M6_instance({1'b0,v1}, not_v2, w1);

    wire [N-1:0] XH1, not_XH2, not_XH3, XH4;
    assign XH1 = {w1,v1,u1};
    assign not_XH2 = {2'b11,~{w1, v1, v1}};
    assign not_XH3 = {{n{1'b1}},~{w1,{n+2{1'b0}}}};
    assign XH4 = {{n{1'b0}},{n{1'b0}},2'b00,w1};

    wire [N-1:0] s1,c1,s2,c2;
    
    csa #(N) M8_instance(XH1, not_XH2, not_XH3, s1, c1);
    csa #(N) M9_instance(s1, c1, XH4, s2, c2);

    reg [N-1:0] XH;
    always @(*) begin
        XH = s2 + c2;
    end
    assign X = {XH, x1};

endmodule

module INV1 #(parameter n = 8)(
    input [n-1:0] x1,
    output reg [n-1:0] not_x1
);
    // Simple 1's complement
    always @(*) begin
        not_x1 = ~x1;
    end
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
    output reg [n+1:0] y
);
    always @(*) begin
        y[0] = x[n+1] | (x[n] & x[n-1]);
        y[n-1:1] = x[n-2:0];
        y[n] = x[n-1] ^ y[0];
        y[n+1] = x[n] ^ (x[n-1] & y[0]);
    end
endmodule

module B2 #(parameter n=8) (
    input [n-1:0] x,
    output reg[n+1:0] y
);
    reg [n+1:0] w;
    always @(*) begin
        w = {2'b0,x};
        y[n-1:0] = ~w[n-1:0];
        y[n] = w[n];
        y[n+1] = ~(w[n+1] | w[n]);
    end
endmodule

module B3 #(parameter n=8) (
    input [n-1:0] x,
    output reg[n+1:0] y
);
    reg [n+1:0] w;
    always @(*) begin
        w = {1'b0,x,1'b0};
        y[n-1:0] = ~w[n-1:0];
        y[n] = w[n];
        y[n+1] = ~(w[n+1] | w[n]);
    end
endmodule



module B4 #(parameter n=8)(
    input [n+1:0] Q, R, T,
    output reg[n+1:0] A, B
);
    reg [n+1:0] s;
    reg [n+2:0] c;
    
    always @(*) begin
        s = Q ^ R ^ T;
        c[0] = 0;
        c[n+2:1] = (Q & R) | (R & T) | (T & Q);

        A[n-1:0] = s[n-1:0];
        A[n] = s[n] ^ (s[n+1] & s[n]);
        A[n+1] = s[n+1] ^ (s[n+1] & s[n]);
        B[0] = c[n+2] | (c[n+1] & c[n]) | (s[n+1] & s[n]);
        B[n-1:1] = c[n-1:1];
        B[n] = c[n] ^ (c[n+2] | (c[n+1] & c[n]));
        B[n+1] = c[n+1] ^ (c[n] & (c[n+2] | (c[n+1] & c[n])));
    end
endmodule



module B6 #(parameter n = 8) (A, B, S);
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





module csa #(parameter n = 16)(a,b,c,sum,carry);
    input [n-1:0] a,b,c;
    output [n-1:0] sum, carry;

    wire [n:0] raw_carry;
    assign raw_carry[0] = 1'b1;
    assign sum = a ^ b ^ c;
    assign raw_carry[n:1] = (a&b) | (b&c) | (c&a);
    assign carry = raw_carry[n-1:0];
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

