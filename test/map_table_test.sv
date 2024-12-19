// Description: This is the testbench for map table module

`include "sys_defs.svh"

`timescale 1us/1ns

module map_table_tb;

    logic clock;
    logic reset;
    map_table_input map_in;
    map_table_output map_out;
    logic insn1_valid, insn2_valid, insn3_valid;


    map_table dut (
        .map_input_packet(map_in),
        .clock(clock),
        .reset(reset),
        .map_output_packet(map_out)
    );



    // The global CLOCK_PERIOD is defined in the Makefile
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 0;
        insn1_valid = 0;
        insn2_valid = 0;
        insn3_valid = 0;
        map_in.imm1_valid = 0;
        map_in.imm2_valid = 0;
        map_in.imm3_valid = 0;
        map_in.has_dest1 = 1;
        map_in.has_dest2 = 1;
        map_in.has_dest3 = 1;
        map_in.dest_arch = '0;
        map_in.dest_preg_new = '0;
        map_in.dispatch_enable = '0;
        map_in.cdb_valid = '0;
        map_in.branch_misprediction = 0;


        @(posedge clock);
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Initialization test - check if variables have been successfully initialized
        // Time = 30, next posedge at Time = 45
        for (int i=0; i<32; i=i+1) begin
            if ((dut.maptable[i] != i)|| (dut.ready_bit[i] != 1)) begin
                $display("@Failed the initialization test");
                $finish;
            end
        end
        $display("@Passed the initialization test");

        @(negedge clock);
        

        // Check the current state of the map table
        $write("time: %3d    maptable_afterinitial: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.maptable[i]);
        end
        $display("");
        

        // Test Case 1 - Dispatch one single instruction
        // Time = 60, next posedge at Time = 75 
        map_in.dispatch_enable = 3'b001;
        map_in.operand_arch[1] = 5'd1;
        map_in.operand_arch[0] = 5'd2;
        map_in.dest_arch[0] = 5'd3;
        map_in.dest_preg_new[0] = 6'd33; // 1-32 have been matched with the 32 arch regs by default
        
        $display("Test 1");

        

        @(posedge clock);
        map_in.dispatch_enable = 3'b000;
        
        // Time = 75, next posedge at Time = 105
        if (map_out.operand_preg[0] == 6'd2 &&
            map_out.operand_preg[1] == 6'd1 &&
            map_out.operand_ready[0] == 1'b1 &&
            map_out.operand_ready[1] == 1'b1 &&
            map_out.dest_preg_old[0] == 6'd3) begin
            $display("\n@Passed the test case 1");
        end else begin
            $display("\nCheck the program");
        end
        

        @(negedge clock);

        // Check the current preg state of the map table
        $write("time: %3d    preg_state: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.maptable[i]);
        end
        $display("");

        // Check the ready state of the map table
        $write("time: %3d    ready_bit: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.ready_bit[i]);
        end
        $display("");        

     
        // Test Case 2 - Dispatch multiple instructions, let say 3 without any data dependencies
        // Time = 90, next posedge at Time = 105
        map_in.dispatch_enable = 3'b111;
        // The 3rd instruction
        map_in.operand_arch[5] = 5'd4;
        map_in.operand_arch[4] = 5'd5;
        map_in.dest_arch[2] = 5'd6;
        map_in.dest_preg_new[2] = 6'd34;

        // The 2nd instruction
        map_in.operand_arch[3] = 5'd7;
        map_in.operand_arch[2] = 5'd8;
        map_in.dest_arch[1] = 5'd9;
        map_in.dest_preg_new[1] = 6'd35;

        // The 1st instruction
        map_in.operand_arch[1] = 5'd10;
        map_in.operand_arch[0] = 5'd11;
        map_in.dest_arch[0] = 5'd12;
        map_in.dest_preg_new[0] = 6'd36;

        @(posedge clock);   // Wait for a full clock cycle

        // Time = 105, next_posedge at Time = 135
        // insn1 - 0, 1; insn2 - 2, 3; insn3 - 4, 5;
        if (map_out.operand_preg[4] == 6'd5 &&
            map_out.operand_preg[5] == 6'd4 &&
            map_out.operand_ready[4] == 1'b1 &&
            map_out.operand_ready[5] == 1'b1 &&
            map_out.dest_preg_old[2] == 6'd6) begin

            insn1_valid = 1;
            end

        if (map_out.operand_preg[2] == 6'd8 &&
            map_out.operand_preg[3] == 6'd7 &&
            map_out.operand_ready[2] == 1'b1 &&
            map_out.operand_ready[3] == 1'b1 &&
            map_out.dest_preg_old[1] == 6'd9) begin

            insn2_valid = 1;
            end
        
        if (map_out.operand_preg[0] == 6'd11 &&
            map_out.operand_preg[1] == 6'd10 &&
            map_out.operand_ready[0] == 1'b1 &&
            map_out.operand_ready[1] == 1'b1 &&
            map_out.dest_preg_old[0] == 6'd12) begin

            insn3_valid = 1;
            end
        

        if (insn1_valid && insn2_valid && insn3_valid) begin    
            $display("\n@Passed the test case 2");
        end else begin
            $display("\nCheck the program");
        end   

        @(negedge clock);   // Wait for the always block to print out the updated result   
        insn1_valid = 0;
        insn2_valid = 0;
        insn3_valid =0; 

        // Check the current preg state of the map table
        $write("time: %3d    preg_state: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.maptable[i]);
        end
        $display("");

        // Check the ready state of the map table
        $write("time: %3d    ready_bit: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.ready_bit[i]);
        end
        $display("");        


        // Test Case 3 - Test the common data bus - if it can set the insn ready bit in the map table
        // Time = 120, next posedge at Time = 135
        map_in.dispatch_enable = '0;
        map_in.cdb_valid[2] = 1;
        map_in.cdb_preg[2] = 6'd33;
        map_in.cdb_valid[1] = 1;
        map_in.cdb_preg[1] = 6'd34;
        map_in.cdb_valid[0] = 1;
        map_in.cdb_preg[0] = 6'd35;

        @(negedge clock);
        

        // Time = 150, next posedge at Time = 165
        // Check the current preg state of the map table
        $write("time: %3d    preg_state: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.maptable[i]);
        end
        $display("");

        // Check the ready state of the map table
        $write("time: %3d    ready_bit: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.ready_bit[i]);
        end
        $display("");         



        if (dut.ready_bit[dut.reverse_maptable[map_in.cdb_preg[2]]] == 1 &&
            dut.ready_bit[dut.reverse_maptable[map_in.cdb_preg[1]]] == 1 &&
            dut.ready_bit[dut.reverse_maptable[map_in.cdb_preg[0]]] == 1 
        ) begin
            $display("\n@Passed the test case 3");
        end else begin
            $display("\nCheck the program");
        end   


        // Test Case 4 - Dispatch multiple instructions - read from and write to pregs that are NOT ready
        // Time = 150, next posedge at Time = 165
        map_in.dispatch_enable = 3'b111;
        // The 1st instruction
        map_in.operand_arch[5] = 5'd0;
        map_in.operand_arch[4] = 5'd12;
        map_in.dest_arch[2] = 5'd3;
        map_in.dest_preg_new[2] = 6'd37;

        // The 2nd instruction
        map_in.operand_arch[3] = 5'd6;
        map_in.operand_arch[2] = 5'd9;
        map_in.dest_arch[1] = 5'd3;
        map_in.dest_preg_new[1] = 6'd38;

        // The 3rd instruction
        map_in.operand_arch[1] = 5'd10;
        map_in.operand_arch[0] = 5'd11;
        map_in.dest_arch[0] = 5'd6;
        map_in.dest_preg_new[0] = 6'd39;        

        @(posedge clock);

        //  Time = 165 
        if (map_out.operand_preg[4] == 6'd36 &&
            map_out.operand_preg[5] == 6'd0 &&
            map_out.operand_ready[4] == 1'b0 &&
            map_out.operand_ready[5] == 1'b1 &&
            map_out.dest_preg_old[2] == 6'd33) begin

            insn1_valid = 1;
            end

        if (map_out.operand_preg[2] == 6'd35 &&
            map_out.operand_preg[3] == 6'd39 &&
            map_out.operand_ready[2] == 1'b1 &&
            map_out.operand_ready[3] == 1'b1 &&
            map_out.dest_preg_old[1] == 6'd37) begin

            insn2_valid = 1;
            end
        
        if (
            map_out.operand_preg[1] == 6'd10 &&
            map_out.operand_ready[1] == 1'b1 &&
            map_out.dest_preg_old[0] == 6'd34) begin

            insn3_valid = 1;
            end

        if (insn1_valid && insn2_valid && insn3_valid) begin    
            $display("\n@Passed the test case 4");
        end else begin
            $display("\nCheck the program");
        end   

        @(negedge clock);   // Wait for the always block to print out the updated result 
        insn1_valid = 0;
        insn2_valid = 0;
        insn3_valid =0;
        // Time = 180
        // Check the current preg state of the map table
        $write("time: %3d    preg_state: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.maptable[i]);
        end
        $display("");

        // Check the ready state of the map table
        $write("time: %3d    ready_bit: ", $time);
        for (int i=0; i<32; i=i+1) begin
            $write("%d ", dut.ready_bit[i]);
        end
        $display(""); 


        $finish;

    end


    always @(posedge clock) begin
        $display("Third Insn:\nTime: %3d  |  operand_preg4: %d   operand_preg5: %d    operand_ready4: %d    operand_ready5: %d    dest_preg_old2: %d    inst3_valid: %d\n", 
        $time, map_out.operand_preg[4], map_out.operand_preg[5], map_out.operand_ready[4], map_out.operand_ready[5],
        map_out.dest_preg_old[2], map_out.valid_inst[2]);

        $display("Second Insn:\nTime: %3d  |  operand_preg2: %d   operand_preg3: %d    operand_ready2: %d    operand_ready3: %d    dest_preg_old1: %d    inst2_valid: %d\n", 
        $time, map_out.operand_preg[2], map_out.operand_preg[3], map_out.operand_ready[2], map_out.operand_ready[3],
        map_out.dest_preg_old[1], map_out.valid_inst[1]);

        $display("First Insn:\nTime: %3d  |  operand_preg0: %d   operand_preg1: %d    operand_ready0: %d    operand_ready1: %d    dest_preg_old0: %d    inst1_valid: %d\n", 
        $time, map_out.operand_preg[0], map_out.operand_preg[1], map_out.operand_ready[0], map_out.operand_ready[1],
        map_out.dest_preg_old[0], map_out.valid_inst[0]);
    end

endmodule