// FIFO module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "sys_defs.svh"


module rob_test();

    logic              clock, reset;
    rob_input                rob_in;
    rob_output              rob_out;

    // variable to count values written to FIFO
    int cnt;

    // INSTANCE is from the sys_defs.svh file
    // it renames the module if SYNTH is defined in
    // order to rename the module to FIFO_svsim
    rob#(
        .ROB_SZ(4))
    dut (
        .rob_packet      (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (rob_out)
    );

    task print_rs_entry();
        
        $display("\n |          %d           |          %d          |          %d          |          %b          |          %b          |          %b          |          %b          |          %d          |          %b          |          %d          |          %d          |  ",
        rob_out.rob.destReg,
        rob_out.rob.oldReg,
        rob_out.rob.archReg,
        rob_out.rob.free,
        rob_out.rob.retire,
        rob_out.rob.taken,
        rob_out.rob.mispredict,
        rob_out.rob.branch_target,
        rob_out.rob.halt,
        rob_out.rob.inst,
        rob_out.rob.PC
        );
        
           
    endtask
    task print_rob();
        
        $display("\nROB inputs: D1: %b, D2: %b, D3: %b, Halt1: %b, Halt2: %b, Halt3: %b, PhysReg1: %d, PhysReg2: %d, PhysReg3: %d, ArchReg1: %d, ArchReg2: %d, ArchReg3: %d, OldPhysReg1: %d, OldPhysReg2: %d, OldPhysReg3: %d, CDB1: %d, CDB1V: %b, CDB2: %d, CDB2V: %b, CDB3: %d, CDB3V: %b, BranchTag: %d, BranchTaken: %b, BranchValid: %b, BranchTarget: %h, Inst1: %h, Inst2: %h, Inst3: %h, PC1: %h, PC2: %h, PC3: %h",
        rob_in.dispatch1_valid,
        rob_in.dispatch2_valid,
        rob_in.dispatch3_valid,
        rob_in.halt1,
        rob_in.halt2,
        rob_in.halt3,
        rob_in.physical_reg1,
        rob_in.physical_reg2,
        rob_in.physical_reg3,
        rob_in.archReg1,
        rob_in.archReg2,
        rob_in.archReg3,
        rob_in.physical_old_reg1,
        rob_in.physical_old_reg2,
        rob_in.physical_old_reg3,
        rob_in.cdb_tag1,
        rob_in.cdb_valid1,
        rob_in.cdb_tag2,
        rob_in.cdb_valid2,
        rob_in.cdb_tag3,
        rob_in.cdb_valid3,
        rob_in.branch_unit_tag,
        rob_in.branch_unit_taken,
        rob_in.branch_valid,
        rob_in.branch_target,
        rob_in.inst1,
        rob_in.inst2,
        rob_in.inst3,
        rob_in.PC1,
        rob_in.PC2,
        rob_in.PC3
        );

        $display("\n ---------------- Reorder Buffer Contents ----------------");
        $display("\n |       destReg        |         oldReg       |        archReg       |         free         |         retire       |         taken        |       mispredict     |    branch_target    |        halt         |        inst         |         PC          |");

        for(int i = 0; i < `RS_SZ; i++) begin
            print_rs_entry(rob_out.rob[i]);
        end
        
        $display("\nROB outputs: OpenSpots: %d, ArchIndex1: %d, ArchTag1: %d, ArchIndex2: %d, ArchTag2: %d, ArchIndex3: %d, ArchTag3: %d, ValidDisp1: %b, ValidDisp2: %b, ValidDisp3: %b, ValidRetire1: %b, ValidRetire2: %b, ValidRetire3: %b, RetiringTold1: %d, RetiringTold2: %d, RetiringTold3: %d, Halt1: %b, Halt2: %b, Halt3: %b, FreeTag1Taken: %b, FreeTag2Taken: %b, FreeTag3Taken: %b, BranchMissRet1: %b, BranchMissRet2: %b, BranchMissRet3: %b, MisspredictFreeList: %h, BranchTarget: %h, Inst1: %h, Inst2: %h, Inst3: %h, PC1: %h, PC2: %h, PC3: %h",
            rob_out.openSpots,
            rob_out.archIndex1,
            rob_out.archTag1,
            rob_out.archIndex2,
            rob_out.archTag2,
            rob_out.archIndex3,
            rob_out.archTag3,
            rob_out.valid_dispatch1,
            rob_out.valid_dispatch2,
            rob_out.valid_dispatch3,
            rob_out.valid_retire_1,
            rob_out.valid_retire_2,
            rob_out.valid_retire_3,
            rob_out.retiring_Told_1,
            rob_out.retiring_Told_2,
            rob_out.retiring_Told_3,
            rob_out.halt1,
            rob_out.halt2,
            rob_out.halt3,
            rob_out.freeTag1_taken,
            rob_out.freeTag2_taken,
            rob_out.freeTag3_taken,
            rob_out.branch_misspredict_retired1,
            rob_out.branch_misspredict_retired2,
            rob_out.branch_misspredict_retired3,
            rob_out.misspredict_freelist,
            rob_out.branch_target,
            rob_out.inst1,
            rob_out.inst2,
            rob_out.inst3,
            rob_out.PC1,
            rob_out.PC2,
            rob_out.PC3
        );

    endtask

    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    // Generate random numbers for our write data on each cycle
   

    initial begin
        
        clock = 1;
        reset = 1;
        $display("\nStart Testbench");
        @(negedge clock);
        print_rob();
        rob_in.op1 = 1;
        rob_in.op2 = 1;
        rob_in.op3 = 1;
        rob_in.physical_reg1 = 1; 
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;

        
        @(negedge clock);
        print_rob();
        reset = 0;

        // ---------- Test 1 ---------- //
        $display("\nTest 1: insert one remove one");
        rob_in.dispatch1_valid = 1;
        rob_in.physical_old_reg1 = 2;
        rob_in.physical_reg1 = 1;
        rob_in.cdb_tag1 = 0;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        @(negedge clock);
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_tag1 = 1;

        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        $display("\nTest 2: Push 3 at once");
        print_rob();
        reset = 0;
        @(negedge clock);
        rob_in.physical_reg1 = 1;
        rob_in.physical_reg2 = 2;
        rob_in.physical_reg3 = 3;
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        rob_in.cdb_tag1 = 1;
        rob_in.cdb_tag2 = 2;
        rob_in.cdb_tag3 = 3;
        rob_in.branch_valid = 0;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        @(negedge clock);
        $display("\nTest 3: Fill it up");
        rob_in.physical_reg1 = 4;
        rob_in.dispatch1_valid = 1;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        @(negedge clock);
        $display("\nTest 4: Overflow");
        rob_in.physical_reg1 = 5;
        rob_in.dispatch1_valid = 1;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        @(negedge clock);
        $display("\nTest 5: Mark 2 below head as ready to retire");
        rob_in.cdb_tag2 = 2;
        rob_in.cdb_tag3 = 3;
        rob_in.cdb_valid2 = 1;
        rob_in.cdb_valid3 = 1;
        @(negedge clock);
        print_rob();
        $display("\nTest 5: Mark head as ready to retire");
        rob_in.cdb_tag1 = 1;
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        @(negedge clock);
        $display("\nTest 6: Empty");
        rob_in.cdb_tag1 = 4;
        rob_in.cdb_valid1 = 1;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        @(negedge clock);
        rob_in.cdb_tag1 = 4;
        rob_in.cdb_valid1 = 1;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        @(negedge clock);
        $display("Test 7: fill it up");
        rob_in.physical_reg1 = 1;
        rob_in.physical_reg2 = 2;
        rob_in.physical_reg3 = 3;
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        rob_in.cdb_tag1 = 1;
        rob_in.cdb_tag2 = 2;
        rob_in.cdb_tag3 = 3;
        rob_in.branch_valid = 0;
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        @(negedge clock);
        $display("\nTest 8: Branch");
        rob_in.branch_valid = 1;
        rob_in.branch_unit_tag = 2;
        rob_in.branch_unit_taken = 1;
        rob_in.branch_target = 24;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_valid2 = 1;
        rob_in.cdb_valid3 = 1;
        rob_in.physical_reg1 = 5;
        rob_in.physical_reg2 = 6;
        rob_in.physical_reg3 = 7;
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        rob_in.cdb_tag1 = 1;
        rob_in.cdb_tag2 = 2;
        rob_in.cdb_tag3 = 3;
        rob_in.branch_valid = 0;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        @(negedge clock);
        @(negedge clock);
        $display("Test 9: Retire and dispatch same cycle");
        rob_in.physical_reg1 = 5;
        rob_in.physical_reg2 = 6;
        rob_in.physical_reg3 = 7;
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        rob_in.halt2 = 1;
        rob_in.cdb_tag1 = 5;
        rob_in.cdb_tag2 = 6;
        rob_in.cdb_tag3 = 7;
        rob_in.branch_valid = 0;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        rob_in.halt2 = 0;
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_valid2 = 1;
        rob_in.cdb_valid3 = 1;
        @(negedge clock);
        print_rob();
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        rob_in.physical_reg1 = 1;
        rob_in.physical_reg2 = 2;
        rob_in.physical_reg3 = 3;
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        rob_in.branch_valid = 0;
        @(negedge clock);
        print_rob();
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        @(negedge clock);
        @(negedge clock);



        // // ---------- Test 2 ---------- //
        // $display("\nTest 2: Write and read with one cycle wait");
        // $display("Write 1 value");
        // wr_en = 1;
        // @(negedge clock);
        // wr_en = 0;

        // $display("Wait one cycle");
        // @(negedge clock);

        // rd_en = 1;
        // $display("Read 1 value");
        // @(negedge clock);
        // rd_en = 0;

        // // ---------- Test 3 ---------- //
        // $display("\nTest 3: Write and read with no wait");
        // $display("Write 1 value");
        // wr_en = 1;
        // @(negedge clock);
        // wr_en = 0;

        // rd_en = 1;
        // $display("Read 1 value");
        // @(negedge clock);
        // rd_en = 0;

        // // ---------- Test 4 ---------- //
        // $display("\nTest 4: Read and write when empty");
        // wr_en = 1;
        // rd_en = 1;
        // @(negedge clock);
        // rd_en = 0;

        // // ---------- Test 5 ---------- //
        // $display("\nTest 5: Write 4 values");
        // repeat (4) @(negedge clock);
        // wr_en = 0;

        // // ---------- Test 6 ---------- //
        // $display("\nTest 6: Read 3 values");
        // rd_en = 1;
        // repeat (3) @(negedge clock);
        // rd_en = 0;

        // // ---------- Test 7 ---------- //
        // $display("\nTest 7: Write until full");
        // cnt = 1;
        // wr_en = 1;
        // while (!full) begin
        //     cnt++;
        //     @(negedge clock);
        // end

        // // ---------- Test 8 ---------- //
        // $display("\nTest 8: Invalid write");
        // @(negedge clock);

        // // ---------- Test 9 ---------- //
        // $display("\nTest 9: Simultaneous read and write when full");
        // rd_en = 1;
        // @(negedge clock);
        // wr_en = 0;
        // rd_en = 0;
        // @(negedge clock);

        // // ---------- Test 10 ---------- //
        // $display("\nTest 10: Read and write when one less than full");
        // rd_en = 1;
        // $display("Read when full");
        // @(negedge clock);
        // $display("Read and write");
        // wr_en = 1;
        // @(negedge clock);
        // wr_en = 0;
        // rd_en = 0;
        // @(negedge clock);

        // // ---------- Test 11 ---------- //
        // $display("\nTest 11: Read all values");
        // rd_en = 1;
        // while (cnt > 0) begin
        //     cnt--;
        //     @(negedge clock);
        // end

        // // ---------- Test 12 ---------- //
        // $display("\nTest 12: Invalid read");
        // @(negedge clock);
        // rd_en = 0;

        // // ---------- Test 13 ---------- //
        // $display("\nTest 13: Four simultaneous reads and writes");
        // rd_en = 1;
        // wr_en = 1;
        // repeat (4) @(negedge clock);
        // wr_en = 0;

        // // ---------- Test 14 ---------- //
        // $display("\nTest 14: Read last item");
        // @(negedge clock);
        // rd_en = 0;

        // @(negedge clock);
        // @(negedge clock);

        $display("\n\033[32m@@@ Passed\033[0m\n");

        $finish;
    end

endmodule