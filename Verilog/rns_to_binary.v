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
    output [L+n-1:0] X; // original number


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
