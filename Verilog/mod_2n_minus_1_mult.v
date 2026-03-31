`timescale 1ns / 1ps

module mod_2n_minus_1_mult #(
    parameter n = 8 // Defines the modulus as 2^n - 1
)(
    input  wire [n-1:0] a,
    input  wire [n-1:0] b,
    output reg  [n-1:0] result
);

    // -------------------------------------------------------------------------
    // 1. Array to hold the partial products
    // -------------------------------------------------------------------------
    wire [n-1:0] pp [0:n-1];

    // -------------------------------------------------------------------------
    // 2. Circular Partial Product Generation (PPG)
    // -------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < n; i = i + 1) begin : GEN_PP
            // Circular left shift 'a' by 'i' positions.
            // (a << i) shifts left, (a >> (n - i)) brings the MSBs around to the LSBs.
            // The result is masked by the i-th bit of multiplier 'b'.
            assign pp[i] = b[i] ? ((a << i) | (a >> (n - i))) : {n{1'b0}};
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 3. End-Around Carry (EAC) Reduction & Final Addition
    // -------------------------------------------------------------------------
    integer j;
    reg [n:0] acc; // n+1 bits wide to catch the carry-out from the MSB
    
    always @(*) begin
        // Initialize the accumulator with the first partial product
        acc = {1'b0, pp[0]}; 
        
        // Accumulate remaining partial products, wrapping the carry each time
        for (j = 1; j < n; j = j + 1) begin
            // Add the n-bit sum, the next n-bit PP, and the 1-bit carry from the last addition
            acc = acc[n-1:0] + pp[j] + acc[n]; 
        end
        
        // Final wrap-around step: the very last loop addition might have generated a carry
        acc = acc[n-1:0] + acc[n];
        
        // ---------------------------------------------------------------------
        // 4. "Double-Zero" Correction
        // ---------------------------------------------------------------------
        // In mod 2^n-1, all 1s (2^n-1) is mathematically equivalent to 0.
        // We force it to all 0s to maintain a single representation of zero.
        if (acc[n-1:0] == {n{1'b1}}) begin
            result = {n{1'b0}};
        end else begin
            result = acc[n-1:0];
        end
    end

endmodule