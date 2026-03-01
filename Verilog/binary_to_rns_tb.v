`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 11:48:46 PM
// Design Name: 
// Module Name: binary_to_rns_tb
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


module binary_to_rns_tb();

    // ---------------------------------
    // Parameters (match DUT)
    // ---------------------------------
    parameter n = 8;
    parameter N = 32;

    // ---------------------------------
    // DUT inputs
    // ---------------------------------
    reg [N-1:0] X;

    // ---------------------------------
    // DUT output
    // ---------------------------------
    wire [n-1:0] r1;
     wire [n+1:0] r2;
    wire [n-1:0] r3;
    wire [n:0] r4;

    // Expected output
    reg  [n-1:0] expected_r1;
    reg [n+1:0] expected_r2;
    reg [n-1:0]  expected_r3;
    reg [n:0] expected_r4;

    // File handling
    integer file_in, file_out;
    integer scan_in, scan_out;
    integer csv_file;

    integer test_count  = 0;
    integer error_count = 0;

    // ---------------------------------
    // Instantiate DUT
    // ---------------------------------
    binary_to_rns #(
        .n(n),
        .N(N)
    ) dut (X, r1,r2, r3, r4);
    
    // ---------------------------------
    // Test Process
    // ---------------------------------
    initial begin
        // Open the NEW binary files created by the Python script
        file_in  = $fopen("binary.txt", "r");
        file_out = $fopen("rns.txt", "r");

        csv_file = $fopen("binary_to_rns.csv", "w");
        $fwrite(csv_file, "X, expected_r1, r1, expected_r2, r2,expected_r3, r3, expected_r4, r4,  Verdict\n");

        if (file_in == 0) begin
            $display("ERROR: Cannot open binary.txt");
            $finish;
        end

        if (file_out == 0) begin
            $display("ERROR: Cannot open rns.txt");
            $finish;
        end

        
        $display("========================================");
        $display("   Binary to RNS Verification Started   ");
        $display("========================================");

        begin : test_loop
            while (!$feof(file_in) && !$feof(file_out)) begin
                
                scan_in = $fscanf(file_in, "%d", X);
                // $display("Debug: scan_out count = %d", scan_out); // Add this
                // IMPORTANT: Changed %d to %b to read binary!
                scan_out  = $fscanf(file_out,  "%d %d %d %d", expected_r1, expected_r2, expected_r3, expected_r4);
                // $display("Debug: scan_in count = %d", scan_in); // Add this
                

            
                // Safely break if we hit the end of the file or a blank line
                if (scan_in != 1 || scan_out != 4) begin
                    disable test_loop; 
                end
                // $display("time: %0t", $time);
                #10;
                test_count = test_count + 1;
                $fwrite(csv_file, "%0d, %0d, %0d,%0d,%0d,%0d,%0d,%0d,%0d,",X, expected_r1, r1, expected_r2,r2, expected_r3, r3, expected_r4, r4);


                if ((r1 !== expected_r1) ||(r2 !== expected_r2) || (r3 !== expected_r3) || (r4 !== expected_r4)) begin
                    $display("Mismatch at test %0d", test_count);
                    // Printing in both Decimal (%0d) and Hex (%h) for easier debugging
                     $display("Residues: r1=%0d r3=%0d r4=%0d", r1, r2,r3, r4);
                    // $display("Expected: %d (Deci)", expected_X);
                    // $display("Got     : %d (Deci)", X);
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