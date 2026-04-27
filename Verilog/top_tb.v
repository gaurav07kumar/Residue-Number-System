`timescale 1ns / 1ps

module test_tb;

    // Parameters matching the DUT
    parameter n = 8;
    parameter N = 32;

    // Inputs to DUT
    reg [N-1:0] a;
    reg [N-1:0] b;
    reg oper;

    // Output from DUT
    wire [N+2:0] result;

    // Testbench file I/O variables
    integer file_in;
    integer file_out;
    integer scan_status;
    
    // Variables for checking correctness
    reg [63:0] expected_res; 
    reg [23:0] oper_str; // Holds "ADD" or "MUL" for clean CSV formatting

    // Instantiate the Unit Under Test (UUT)
    top_module #(n, N) uut (
        .a(a), 
        .b(b), 
        .oper(oper),
        .result(result)
    );

    initial begin
        // Open files
        file_in = $fopen("input.txt", "r");
        file_out = $fopen("output.csv", "w");

        if (file_in == 0) begin
            $display("Error: Failed to open input.txt. Make sure the Python script has been run.");
            $finish;
        end

        // Write the CSV header
        $fdisplay(file_out, "Time,Operation,Input_A,Input_B,Expected_Result,Actual_Result,Pass_Fail");

        // Process the file line by line
        while (!$feof(file_in)) begin
            // Read A, B, and the operation flag
            scan_status = $fscanf(file_in, "%b %b %b\n", a, b, oper);
            
            if (scan_status == 3) begin
                // Wait 10ns for the combinational logic to propagate
                #10; 
                
                // Determine the expected mathematical result
                if (oper == 1'b1) begin
                    expected_res = a * b;
                    oper_str = "MUL";
                end else begin
                    expected_res = a + b;
                    oper_str = "ADD";
                end
                
                // Compare DUT result with the lowest 32 bits of the expected calculation
                if (result == expected_res[N-1:0]) begin
                    $fdisplay(file_out, "%t,%s,%d,%d,%d,%d,PASS", $time, oper_str, a, b, expected_res[N-1:0], result);
                end else begin
                    $fdisplay(file_out, "%t,%s,%d,%d,%d,%d,FAIL", $time, oper_str, a, b, expected_res[N-1:0], result);
                    $display("Test failed at time %t: %s %d and %d expected %d but got %d", $time, oper_str, a, b, expected_res[N-1:0], result);
                end
            end
        end

        // Clean up and finish
        $fclose(file_in);
        $fclose(file_out);
        $display("Simulation complete. Check output.csv for results.");
        $finish;
    end
      
endmodule