`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 11:39:10 PM
// Design Name: 
// Module Name: rns
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




module rns_to_binary_tb();

    // ---------------------------------
    // Parameters (match DUT)
    // ---------------------------------
    parameter n = 8;
    parameter L = 27;
    parameter N = 32;

    // ---------------------------------
    // DUT inputs
    // ---------------------------------
    reg  [n-1:0]   r1;
    reg  [n+1:0]   r2;   // 18 bits
    reg  [n-1:0]   r3;
    reg  [n:0]     r4;   // 17 bits

    // ---------------------------------
    // DUT output
    // ---------------------------------
    wire [n+L-1:0] X;

    // Expected output
    reg  [n+L-1:0] expected_X;

    // File handling
    integer file_in, file_out;
    integer scan_in, scan_out;
    integer csv_file;

    integer test_count  = 0;
    integer error_count = 0;

    // ---------------------------------
    // Instantiate DUT
    // ---------------------------------
    rns_to_binary #(
        .n(n),
        .N(N)
    ) dut (
        .x1(r1),
        .x2(r2),
        .x3(r3),
        .x4(r4),
        .X(X)
    );
    
    // ---------------------------------
    // Test Process
    // ---------------------------------
    initial begin
        // $display("ANMOL High");
        // Open the NEW binary files created by the Python script
        file_in  = $fopen("rns.txt", "r");
        file_out = $fopen("binary.txt", "r");

        csv_file = $fopen("rns_to_binary.csv", "w");
        $fwrite(csv_file, "x1, x2, x3, x4, Expected_X, Output_X, Verdict\n");

        if (file_in == 0) begin
            $display("ERROR: Cannot open rns.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Cannot open binary.txt");
            $finish;
        end

        
        $display("========================================");
        $display("   RNS to Binary Verification Started   ");
        $display("========================================");

        begin : test_loop
            while (!$feof(file_in) && !$feof(file_out)) begin
                
                // IMPORTANT: Changed %d to %b to read binary!
                scan_in  = $fscanf(file_in,  "%d %d %d %d", r1, r2, r3, r4);
                // $display("Debug: scan_in count = %d", scan_in); // Add this
                scan_out = $fscanf(file_out, "%d", expected_X);
                // $display("Debug: scan_out count = %d", scan_out); // Add this

            
                // Safely break if we hit the end of the file or a blank line
                if (scan_in != 4 || scan_out != 1) begin
                    disable test_loop; 
                end
                // $display("time: %0t", $time);
                #10;
                test_count = test_count + 1;
                $fwrite(csv_file, "%0d, %0d,%0d,%0d,%0d,%0d,", r1, r2, r3, r4, expected_X, X );


                if (X !== expected_X) begin
                    $display("Mismatch at test %0d", test_count);
                    // Printing in both Decimal (%0d) and Hex (%h) for easier debugging
                    $display("Residues: r1=%0d r2=%0d r3=%0d r4=%0d", r1, r2, r3, r4);
                    $display("Expected: %d (Deci)", expected_X);
                    $display("Got     : %d (Deci)", X);
                    $display("----------------------------------------");
                    $fwrite(csv_file, "ERROR\n");
                    error_count = error_count + 1;
                end
                else begin
                    $fwrite(csv_file, "PASS\n");
                end
            end
        end 

        $display("========================================");

        $display("========================================");
        $display("Total Tests  : %0d", test_count);
        $display("Total Errors : %0d", error_count);

        if (error_count == 0)
            $display("ALL TESTS PASSED ✅");
        else
            $display("SOME TESTS FAILED ❌");

        $display("========================================");

        $fclose(file_in);
        $fclose(file_out);

        $finish;
    end

endmodule
