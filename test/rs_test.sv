`include "sys_defs.svh"

module rs_test();
    logic              clock, reset;
    rs_input                rs_in;
    rs_output              rs_out;


    rs#(
        .RS_SIZE(`RS_SZ))        
    dut(.rs_input(rs_in),
        .clock(clock),
        .reset(reset),
        .rs_output(rs_out));


    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    initial begin
        
        clock = 0;
        reset = 1;
        $display("\nStart Testbench");
        rs_in.inst1 = 32'b0;
        rs_in.inst2 = 32'b0;
        rs_in.inst3 = 32'b0;
        rs_in.branch_misspredict_retired = 0;
        rs_in.alufunc1 = 0;
        rs_in.alufunc2 = 0;
        rs_in.alufunc3 = 0;
        rs_in.multfunc1 = 0;
        rs_in.multfunc2 = 0;
        rs_in.multfunc3 = 0;
        rs_in.uncond_branchfunc1 = 0;
        rs_in.uncond_branchfunc2 = 0;
        rs_in.uncond_branchfunc3 = 0;
        rs_in.branchfunc1 = 0;
        rs_in.branchfunc2 = 0;
        rs_in.branchfunc3 = 0;
        rs_in.dispatch1_valid = 1'b0;
        rs_in.dispatch2_valid = 1'b0;
        rs_in.dispatch3_valid = 1'b0;
        
        rs_in.mult1  = 0;
        rs_in.mult2  = 0;
        rs_in.mult3  = 0;
        rs_in.condbr1 = 0;
        rs_in.condbr2 = 0;
        rs_in.condbr3 = 0;
        rs_in.uncondbr1 = 0;
        rs_in.uncondbr2 = 0;
        rs_in.uncondbr3 = 0;
        rs_in.wrmem1 = 0;
        rs_in.wrmem2 = 0;
        rs_in.wrmem3 = 0;
        rs_in.rdmem1 = 0;
        rs_in.rdmem2 = 0;
        rs_in.rdmem3 = 0;
        rs_in.halt1 = 0;
        rs_in.halt2 = 0;
        rs_in.halt3 = 0;
        rs_in.dest_reg1 = '0;
        rs_in.dest_reg2 = '0;
        rs_in.dest_reg3 = '0;
        rs_in.archZeroReg1 = 0;
        rs_in.archZeroReg2 = 0;
        rs_in.archZeroReg3 = 0;
        rs_in.inst1_T1 = '0;
        rs_in.inst1_T1_ready = 1'b0;
        rs_in.inst1_T2 = '0;
        rs_in.inst1_T2_ready = 1'b0;
        rs_in.inst2_T1 = '0;
        rs_in.inst2_T1_ready = 1'b0;
        rs_in.inst2_T2 = '0;
        rs_in.inst2_T2_ready = 1'b0;
        rs_in.inst3_T1 = '0;
        rs_in.inst3_T1_ready = 1'b0;
        rs_in.inst3_T2 = '0;
        rs_in.inst3_T2_ready = 1'b0;

        rs_in.imm1 = '0;
        rs_in.imm1_valid = 1'b0;
        rs_in.imm2 = '0;
        rs_in.imm2_valid = 1'b0;
        rs_in.imm3 = '0;
        rs_in.imm3_valid = 1'b0;

        rs_in.cdb_tag1 = '0;
        rs_in.cdb_valid1 = 1'b0;
        rs_in.cdb_tag2 = '0;
        rs_in.cdb_valid2 = 1'b0;
        rs_in.cdb_tag3 = '0;
        rs_in.cdb_valid3 = 1'b0;

        rs_in.leftover_issues_from_execute = '0;
        rs_in.load_dependencies = '0;
        rs_in.sq_spot1 = 0;
        rs_in.sq_spot2 = 0;
        rs_in.sq_spot3 = 0;
        rs_in.sq_spot_ready_valid = 0;

        //
        @(negedge clock);#2
        $display("RESET");
        reset = 0;
        rs_in.dispatch1_valid = 1;
        rs_in.dest_reg1 = 1;
        rs_in.inst1_T1 = 2;
        rs_in.inst1_T2 = 3;#2
        
        
        
        //
        @(negedge clock);#2
        $display("Test 1");
        rs_in.dispatch1_valid = 0;#2
        
        
        //
        @(negedge clock);#2
        @(negedge clock);#2
        rs_in.cdb_tag1 = 2;
        rs_in.cdb_valid1 = 1;
        @(negedge clock);#2
        
        
        //$display("valid bus: %b", rs_out.issue_valid);
        @(negedge clock);#2
        rs_in.cdb_tag1 = 3;#2
        
        
        @(negedge clock); #2
        rs_in.cdb_valid1 = 0;#2
        
        
        @(negedge clock); #2
        //$display("Removed here");
        
        
        @(negedge clock); #2
        rs_in.dest_reg1 = 18;
        rs_in.inst1_T1_ready = 1;
        rs_in.inst1_T1 = 19;
        rs_in.inst1_T2_ready = 1;
        rs_in.inst1_T2 = 20;
        rs_in.leftover_issues_from_execute = 2;
        rs_in.dispatch1_valid = 1;#2
        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;#2
        
        
        @(negedge clock); #2
        rs_in.leftover_issues_from_execute = 0;#2
        
        
        @(negedge clock); #2
        $display("MULT Test");
        
        #2
        //Instruction 3
        rs_in.dest_reg1 = 1;
        rs_in.inst1_T1_ready = 1;
        rs_in.inst1_T1 = 2;
        rs_in.inst1_T2_ready = 1;
        rs_in.inst1_T2 = 3;
        rs_in.mult1 = 1;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 7;
        rs_in.inst2_T1_ready = 1;
        rs_in.inst2_T1 = 8;
        rs_in.inst2_T2_ready = 1;
        rs_in.inst2_T2 = 9;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 4;
        rs_in.inst3_T1_ready = 1;
        rs_in.inst3_T1 = 5;
        rs_in.inst3_T2_ready = 1;
        rs_in.inst3_T2 = 6;
        rs_in.dispatch3_valid = 1;#2

        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;
        rs_in.mult1 = 0;#2
        
        
        @(negedge clock); #2
        
        
        @(negedge clock); #2
        reset = 1;


        @(negedge clock); #2
        $display("============Testing Filling Up============");
        
        

        @(negedge clock)#2
        reset = 0;#2
        
        
        @(negedge clock)#2
        rs_in.dest_reg1 = 1;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 2;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 3;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 7;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 8;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 9;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 4;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 5;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 6;
        rs_in.dispatch3_valid = 1;#2
        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;#2
        
        

        @(negedge clock); #2

        rs_in.dest_reg1 = 10;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 11;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 12;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 16;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 17;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 18;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 13;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 14;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 15;
        rs_in.dispatch3_valid = 1;#2
        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;#2
        
        
        @(negedge clock); #2
        rs_in.dest_reg1 = 19;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 20;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 21;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 22;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 23;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 24;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 25;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 26;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 27;
        rs_in.dispatch3_valid = 1;#2
        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;#2
        
        
        @(negedge clock); #2
        rs_in.dest_reg1 = 28;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 29;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 30;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 31;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 31;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 31;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 31;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 31;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 31;
        rs_in.dispatch3_valid = 1;#2
        
        
        @(negedge clock); #2
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;#2
        
        
        $display("============Testing Adding to Issue============");
        @(negedge clock); #2
        rs_in.cdb_tag1 = 5;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 6;
        rs_in.cdb_valid2 = 1;
        rs_in.cdb_tag3 = 11;
        rs_in.cdb_valid3 = 1;
        @(negedge clock);
        
        
        @(negedge clock)
        rs_in.cdb_tag1 = 12;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 20;
        rs_in.cdb_valid2 = 1;
        rs_in.cdb_tag3 = 21;
        rs_in.cdb_valid3 = 1;
        rs_in.dest_reg1 = 31;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 31;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 31;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 31;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 31;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 31;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 31;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 31;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 31;
        rs_in.dispatch3_valid = 1;
        rs_in.leftover_issues_from_execute = 2;
        @(negedge clock);
        $display("============Testing Add to issue when full============");
        
        #2
        rs_in.cdb_tag1 = 31;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 8;
        rs_in.cdb_valid2 = 1;
        rs_in.cdb_tag3 = 9;
        rs_in.cdb_valid3 = 1;
        rs_in.dest_reg1 = 4;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 5;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 6;
        rs_in.dispatch1_valid = 1;
        //Instruction 2
        rs_in.dest_reg2 = 19;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 20;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 21;
        rs_in.dispatch2_valid = 1;
        //Instruction 3
        rs_in.dest_reg3 = 10;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 11;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 12;
        rs_in.dispatch3_valid = 1;
        rs_in.leftover_issues_from_execute = 14;
        @(negedge clock);
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;
        rs_in.cdb_valid1 = 0;
        rs_in.cdb_valid2 = 0;
        rs_in.cdb_valid3 = 0;
        rs_in.leftover_issues_from_execute = 0;#4
        
        
        @(negedge clock);
        $display("============Testing Issue Conflicts============");
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;
        rs_in.cdb_valid1 = 0;
        rs_in.cdb_valid2 = 0;
        rs_in.cdb_valid3 = 0;#4
        
        
        @(negedge clock);
        $display("============Testing Branch Misprediction============");
        rs_in.branch_misspredict_retired = 1;#2
        
        
        @(negedge clock);
        rs_in.branch_misspredict_retired = 0;#2
        
        
         @(negedge clock); 
        
         #2
        $display("============Testing Branch Added to Res============");
        rs_in.cdb_tag1 = 31;
        rs_in.cdb_valid1 = 0;
        rs_in.cdb_tag2 = 8;
        rs_in.cdb_valid2 = 0;
        rs_in.cdb_tag3 = 9;
        rs_in.cdb_valid3 = 0;
        rs_in.dest_reg1 = 4;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 5;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 6;
        rs_in.dispatch1_valid = 1;
        rs_in.condbr1 = 1;
        //Instruction 2
        rs_in.dest_reg2 = 19;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 20;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 21;
        rs_in.dispatch2_valid = 1;
        rs_in.uncondbr2 = 1;
        //Instruction 3
        rs_in.dest_reg3 = 10;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 11;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 12;
        rs_in.dispatch3_valid = 1;#14
        
        
        @(negedge clock);
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;
        rs_in.cdb_tag1 = 20;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 5;
        rs_in.cdb_valid2 = 1;
        rs_in.cdb_tag3 = 6;
        rs_in.cdb_valid3 = 1;#2
        
        
        @(negedge clock);
        rs_in.cdb_tag1 = 21;
        rs_in.leftover_issues_from_execute = 7'b1000000;#2
        
        
        @(negedge clock);
        rs_in.cdb_valid3 = 0;
        rs_in.cdb_valid2 = 0;
        rs_in.cdb_valid1 = 0;#2
        
        
        @(negedge clock);
        rs_in.dest_reg1 = 13;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 14;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 15;
        rs_in.dispatch1_valid = 1;
        rs_in.condbr1 = 1;
        //Instruction 2
        rs_in.dest_reg2 = 16;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 17;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 18;
        rs_in.dispatch2_valid = 1;
        rs_in.uncondbr2 = 1;
        rs_in.halt2 = 1;
        //Instruction 3
        rs_in.dest_reg3 = 28;
        rs_in.inst3_T1_ready = 0;
        rs_in.inst3_T1 = 29;
        rs_in.inst3_T2_ready = 0;
        rs_in.inst3_T2 = 30;
        rs_in.dispatch3_valid = 1;#2
        
        
        @(negedge clock);
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.dispatch3_valid = 0;
        rs_in.halt2 = 0;#2
        
        
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        rs_in.dispatch1_valid = 1;
        rs_in.condbr1 = 1;
        rs_in.archZeroReg1 = 0;
        rs_in.mult1 = 0;
        rs_in.branchfunc1 = 3'b001;
        @(negedge clock);
        rs_in.dispatch1_valid = 0;
        rs_in.condbr1 = 1;
        @(negedge clock);
        rs_in.cdb_tag1 = 15;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 14;
        rs_in.cdb_valid2 = 1;
        rs_in.cdb_tag3 = 0;
        rs_in.cdb_valid3 = 0;
        rs_in.leftover_issues_from_execute = '0;
        @(negedge clock);
        rs_in.cdb_tag1 = 20;
        rs_in.cdb_valid1 = 0;
        rs_in.cdb_tag2 = 5;
        rs_in.cdb_valid2 = 0;
        rs_in.cdb_tag3 = 6;
        rs_in.cdb_valid3 = 0;#2
        @(negedge clock);#2
        reset = 1;
        @(negedge clock);#2
        
        
        reset = 0;
        @(negedge clock);#2
        
        
        rs_in.condbr1 = 0;
        rs_in.condbr2 = 0;
        rs_in.condbr3 = 0;
        rs_in.dispatch1_valid = 1;
        rs_in.dest_reg1 = 4;
        rs_in.inst1_T1_ready = 0;
        rs_in.inst1_T1 = 5;
        rs_in.inst1_T2_ready = 0;
        rs_in.inst1_T2 = 6;
        rs_in.dispatch1_valid = 1;
        rs_in.wrmem1 = 1;
        rs_in.dispatch2_valid = 1;
        rs_in.dest_reg2 = 7;
        rs_in.inst2_T1_ready = 0;
        rs_in.inst2_T1 = 8;
        rs_in.inst2_T2_ready = 0;
        rs_in.inst2_T2 = 9;
        rs_in.dispatch2_valid = 1;
        rs_in.rdmem2 = 1;
        rs_in.uncondbr2 = 0;
        rs_in.condbr2 = 0;
        rs_in.load_dependencies = 10'b1111111100;
        rs_in.sq_spot1 = 0;
        rs_in.sq_spot2 = 1;
        rs_in.sq_spot3 = 2;
        @(negedge clock);#2
        rs_in.load_dependencies = '0;
        rs_in.sq_spot_ready_valid = 1;
        rs_in.sq_spot_ready = 1;
        rs_in.dispatch1_valid = 0;
        rs_in.dispatch2_valid = 0;
        rs_in.cdb_tag1 = 9;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 8;
        rs_in.cdb_valid2 = 1;
        @(negedge clock);#2
        rs_in.cdb_tag1 = 6;
        rs_in.cdb_valid1 = 1;
        rs_in.cdb_tag2 = 5;
        rs_in.cdb_valid2 = 1;
        @(negedge clock);#2
        rs_in.sq_spot_ready_valid = 1;
        rs_in.sq_spot_ready = 0;
        @(negedge clock);#2
        
        


        $finish;

     end



endmodule