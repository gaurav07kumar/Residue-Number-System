`timescale 1ns / 1ps

module main_test();
    parameter n = 16;
    parameter N = 51;


    // 2. Signals
    // Width is [n+1:0] (10 bits for n=8)
    reg [n-1:0] x1, x3;
    reg [n+1:0] x2;
    reg [n:0] x4;
    wire [N+n-1:0] X;

    // 3. Instantiate the Unit Under Test (UUT)
    main #(.n(n), .N(N)) uut (x1, x2, x3, x4, X);
    initial begin
        $dumpfile("wave.vcd");   // file GTKWave reads
        $dumpvars(0, main_test);        // dump all signals
    end
    
    // 4. Test Logic
    initial begin
    //     // Setup output formatting
    //     $display("---------------------------------------------------------------");
    //     $display("Testbench for Modulo Adder (n=%0d)", n);
    //     $display("Expected Modulus = 2^(%0d)  - 1 = %0d", n, (1<<(n))  - 1);
    //     $display("---------------------------------------------------------------");
    //     $display("Time |   x3   |   ~x1   |   x3+(~x1)  |  expected  |   y   ");
    //     $display("-----|-------|--------|-----------------|----------------");

        // --- Case 1: 
        x1=65000; x2=196007; x3=65001; x4=130071;
        #50;
    //     check_result(x1, x3,x2,x4,u1,u2,u3);

        


        $display("---------------------------------------------------------------");
        $finish;
    end

    // // Simple task to print and verify results
    // task check_result;
    //     input [n-1:0] x1, x3;
    //     input [n+1:0] x2;
    //     input [n:0] x4;
    //     input [n+1:0] u1;
    //     input [n-1:0] u2;
    //     input [n:0] u3;
        
    //     integer p2, p3, p4;
    //     integer u1E, u2E, u3E;

    //     begin
    //         p2 = (1<<(n+1)) + (1<<n) - 1;
    //         p4 = (1<<(n+1)) -1; 
    //         p3 = (1<<(n)) -1; 
            
    //         u1E = (3*(x2-x1)) % p2;
    //         u2E = (x3-x1) % p3;
    //         u3E = (2*(x4-x1)) % p4;
            
    //         $display("%4t", $time);
    //         $display("| %15d | %15d | %15d" ,u1E , u2E, u3E);
    //         $display("| %15d | %15d | %15d ",u1, u2, u3);
    //     end
    // endtask

endmodule