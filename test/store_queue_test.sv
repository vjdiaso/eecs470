`include "sys_defs.svh"

module sq_test();
    logic clock, reset;
    store_queue_input store_in;
    store_queue_output store_out;

store_queue#()
    dut(.store_in(store_in),
    .clock(clock),
    .reset(reset),
    .store_out(store_out)
);

always begin
    #(`CLOCK_PERIOD/2) clock = ~clock;
end


task print_store_queue();
    
    $display("\nStore Queue inputs: D1: %b, D2: %b, D3: %b, Dest1: %d, Dest2: %d, Dest3: %d, IMM1: %d, IMM2: %d, IMM3: %d, WR1: %b, WR2: %b, WR3: %b, Ret1: %b, Ret2: %b, Ret3: %b, Phys1: %d, Phys2: %d, Phys3: %d, BMR1: %b, BMR2: %b, BMR3: %b, LAddr: %h, LSize: %d, LValid: %b, SQSpot: %d, Reg1_DATA: %d, Reg2_DATA: %d, SQSpotValid: %b, cache_miss1: %b, cache_miss2: %b, cache_miss3: %b",
        store_in.dispatch1_valid,
        store_in.dispatch2_valid,
        store_in.dispatch3_valid,
        store_in.dest_tag1,
        store_in.dest_tag2,
        store_in.dest_tag3,
        store_in.imm1,
        store_in.imm2,
        store_in.imm3,
        store_in.wrmem1,
        store_in.wrmem2,
        store_in.wrmem3,
        store_in.valid_retire_1,
        store_in.valid_retire_2,
        store_in.valid_retire_3,
        store_in.physReg1,
        store_in.physReg2,
        store_in.physReg3,
        store_in.branch_misspredict_retired1,
        store_in.branch_misspredict_retired2,
        store_in.branch_misspredict_retired3,
        store_in.load_addr,
        store_in.load_size,
        store_in.load_valid,
        store_in.sq_spot,
        store_in.reg1_data,
        store_in.reg2_data,
        store_in.sq_spot_valid,
        store_in.cache_miss1,
        store_in.cache_miss2,
        store_in.cache_miss3
    );
    
    $display("\n =============================================================================   Store Queue Contents ================================================================================");
    $display("| h/t | Entry |        inst        |  free  |  store_size  |   dest_tag   |     T2_data      |     offset      |        PC        |     wr_addr      |   ready   | store_range_sz |");
    $display("|-----|-------|--------------------|--------|--------------|--------------|------------------|-----------------|------------------|------------------|-----------|----------------|");
    for (int i = 0; i < `LSQ_SZ; i++) begin

        if(i == store_out.head_debug && i != store_out.tail_debug) begin
            $write("|  h  ");
        end else if (i == store_out.tail_debug && i != store_out.head_debug)begin
            $write("|  t  ");
        end else if (i == store_out.head_debug && i == store_out.tail_debug) begin
            $write("| h/t ");
        end else begin
            $write("|     ");
        end

        $display("|   %2d  |      %h      |   %b    |      %s    |      %d      |     %h     |    %d   |     %h     |     %h     |     %b     |       %b       |",
            i,
            store_out.store_queue[i].inst,
            store_out.store_queue[i].free,
            store_out.store_queue[i].store_size == BYTE ? "BYTE" : (store_out.store_queue[i].store_size == HALF ? "HALF": (store_out.store_queue[i].store_size == WORD ? "WORD": "NULL")),
            store_out.store_queue[i].dest_tag,
            store_out.store_queue[i].t2_data,
            store_out.store_queue[i].offset,
            store_out.store_queue[i].PC,
            store_out.store_queue[i].wr_addr,
            store_out.store_queue[i].ready,
            store_out.store_queue[i].store_range_sz
        );
    end
    $display(" =========================================================================  End Store Queue Contents =============================================================================");

    $display("\nSQ Logic Outputs: OpenSpots: %d, PrevStoreQueueReadyBits: %b\nLoad Forwarding: load_valid: %b, load_data_fwd: %h, load_data_fwd_bytes_valid: %b\nRetirement Outputs: WrAddr1: %h, Data1: %h, ValidData1: %b, StoreSize1: %d\nWrAddr2: %h, Data2: %h, ValidData2: %b, StoreSize2: %d\nWrAddr3: %h, Data3: %h, ValidData3: %b, StoreSize3: %d\nInputs: SQ_SpotReady: %d, SQ_SpotReadyValid: %b, Tail1: %d, Tail2: %d, Tail3: %d\nRetirement Input: StoreSetToRetireValid: %b, StoreSetToRetire: %d",
        store_out.openSpots,
        store_out.prev_store_queue_ready_bits,
        store_out.load_valid,
        store_out.load_data_fwd,
        store_out.load_data_fwd_bytes_valid,
        store_out.wr_addr1,
        store_out.data1,
        store_out.valid_data1,
        store_out.store_size1,
        store_out.wr_addr2,
        store_out.data2,
        store_out.valid_data2,
        store_out.store_size2,
        store_out.wr_addr3,
        store_out.data3,
        store_out.valid_data3,
        store_out.store_size3,
        store_out.sq_spot_ready,
        store_out.sq_spot_ready_valid,
        store_out.tail1,
        store_out.tail2,
        store_out.tail3,
        store_out.store_set_to_retire_valid,
        store_out.store_set_to_retire
    );

endtask

initial begin
    clock = 0;
    reset = 1;
    $display("\nStart Testbench");

    store_in.inst1 = 32'b0;
    store_in.inst2 = 32'b0;
    store_in.inst3 = 32'b0;

    store_in.dispatch1_valid = 1'b0;
    store_in.dispatch2_valid = 1'b0;
    store_in.dispatch3_valid = 1'b0;

    store_in.dest_tag1 = '0;
    store_in.dest_tag2 = '0;
    store_in.dest_tag3 = '0;

    store_in.imm1 = '0;
    store_in.imm2 = '0;
    store_in.imm3 = '0;

    store_in.wrmem1 = 1'b0;
    store_in.wrmem2 = 1'b0;
    store_in.wrmem3 = 1'b0;

    store_in.valid_retire_1 = 1'b0;
    store_in.valid_retire_2 = 1'b0;
    store_in.valid_retire_3 = 1'b0;
    store_in.physReg1 = '0;
    store_in.physReg2 = '0;
    store_in.physReg3 = '0;

    store_in.branch_mispredict = 1'b0;
    store_in.branch_misspredict_retired1 = 1'b0;
    store_in.branch_misspredict_retired2 = 1'b0;
    store_in.branch_misspredict_retired3 = 1'b0;

    store_in.reg1_data = '0;
    store_in.reg2_data = '0;

    store_in.PC1 = '0;
    store_in.PC2 = '0;
    store_in.PC3 = '0;

    store_in.load_addr = '0;
    store_in.load_size = '0;
    store_in.load_valid = 1'b0;

    store_in.sq_spot = '0;
    store_in.sq_spot_valid = 1'b0;

    store_in.cache_miss1 = 0;
    store_in.cache_miss2 = 0;
    store_in.cache_miss3 = 0;

    @(negedge clock);#2
    $display("RESET");
    print_store_queue();
    reset = 0;

    store_in.inst1 = 1;//32'h00a12023;
    store_in.inst2 = 2;
    store_in.inst3 = 3;

    store_in.dispatch1_valid = 1;
    store_in.dispatch2_valid = 1;
    store_in.dispatch3_valid = 1;

    store_in.dest_tag1 = 1;
    store_in.dest_tag2 = 2;
    store_in.dest_tag3 = 3;

    store_in.imm1 = 1;
    store_in.imm2 = 2;
    store_in.imm3 = 3;

    store_in.wrmem1 = 1;
    store_in.wrmem2 = 1;
    store_in.wrmem3 = 1;


    @(negedge clock);#2
    $display("CYCLE 1");
    print_store_queue();

    store_in.inst1 = 4;
    store_in.inst2 = 5;
    store_in.inst3 = 6;

    store_in.dispatch1_valid = 1;
    store_in.dispatch2_valid = 1;
    store_in.dispatch3_valid = 1;

    store_in.dest_tag1 = 4;
    store_in.dest_tag2 = 5;
    store_in.dest_tag3 = 6;

    store_in.imm1 = 4;
    store_in.imm2 = 5;
    store_in.imm3 = 6;

    store_in.wrmem1 = 1;
    store_in.wrmem2 = 1;
    store_in.wrmem3 = 1;

    @(negedge clock);#2
    $display("CYCLE 2");
    print_store_queue();

    store_in.inst1 = 7;
    store_in.inst2 = 8;
    store_in.inst3 = 9;

    store_in.dispatch1_valid = 1;
    store_in.dispatch2_valid = 1;
    store_in.dispatch3_valid = 1;

    store_in.dest_tag1 = 7;
    store_in.dest_tag2 = 8;
    store_in.dest_tag3 = 9;

    store_in.imm1 = 7;
    store_in.imm2 = 8;
    store_in.imm3 = 9;

    store_in.wrmem1 = 1;
    store_in.wrmem2 = 1;
    store_in.wrmem3 = 1;

    @(negedge clock);#2
    $display("CYCLE 3");
    print_store_queue();

    store_in.inst1 = 10;
    store_in.inst2 = 11;
    store_in.inst3 = 12;

    store_in.dispatch1_valid = 1;
    store_in.dispatch2_valid = 1;
    store_in.dispatch3_valid = 1;

    store_in.dest_tag1 = 10;
    store_in.dest_tag2 = 11;
    store_in.dest_tag3 = 12;

    store_in.imm1 = 10;
    store_in.imm2 = 11;
    store_in.imm3 = 12;

    store_in.wrmem1 = 1;
    store_in.wrmem2 = 1;
    store_in.wrmem3 = 1;

    @(negedge clock);#2
    $display("CYCLE 3");
    print_store_queue();

    store_in.wrmem1 = 0;
    store_in.wrmem2 = 0;
    store_in.wrmem3 = 0;

    store_in.reg1_data = 10;
    store_in.reg2_data = 10;
    store_in.sq_spot = 4;
    store_in.sq_spot_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 4");
    print_store_queue();
    store_in.reg1_data = 0;
    store_in.reg2_data = 10;
    store_in.sq_spot = 0;
    store_in.sq_spot_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 5");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 1;
    store_in.load_size = BYTE;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 6: case 1");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 1;
    store_in.load_size = HALF;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 7: case 8");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 0;
    store_in.load_size = HALF;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 8: case 9");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 1;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 9: case 16");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 0;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 10: case 17");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 2;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    store_in.dispatch1_valid = 0;
    store_in.valid_retire_1 = 1;
    store_in.physReg1 = 1;

    @(negedge clock);#2
    $display("CYCLE 11: testing retire");
    print_store_queue();

    store_in.dispatch1_valid = 1;
    store_in.wrmem1 = 1;
    store_in.imm1 = 2;

    @(negedge clock);#2
    $display("CYCLE 12: putting store at address 3 in");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 0;
    store_in.reg2_data = 13;
    store_in.reg1_data = 2;
  
    @(negedge clock);#2
    $display("CYCLE 13");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 0;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 14: case 17/18");
    print_store_queue();


    store_in.sq_spot_valid = 0;
    store_in.load_addr = 4;
    store_in.load_size = HALF;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 15: case 8/9");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 1;
    store_in.reg2_data = 10;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 16: retire");
    print_store_queue();

    store_in.valid_retire_1 = 1; // comes from ROB
    store_in.physReg1 = 2;

    store_in.dest_tag1 = 11;
    store_in.dispatch1_valid = 1;
    store_in.wrmem1 = 1;
    store_in.imm1 = 2;
    store_in.inst1 = 32'h00b12023;

    @(negedge clock);#2
    $display("CYCLE 17: retire and add at the same time");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 1;
    store_in.reg2_data = 32'h0000000f;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 18");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 7;
    store_in.load_size = BYTE;
    store_in.load_valid = 1;

    @(negedge clock);#2
    $display("CYCLE 19: 4/5/6/7");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 6;
    store_in.load_size = HALF;
    store_in.load_valid = 1;

    @(negedge clock);#5
    $display("CYCLE 20: 12/13/14/15");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 4;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    @(negedge clock);#5
    $display("CYCLE 21: 24/25/26/27");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 2;
    store_in.reg2_data = 14;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 22");
    print_store_queue();

    store_in.valid_retire_1 = 1;
    store_in.physReg1 = 3;
    store_in.dest_tag1 = 12;
    store_in.dispatch1_valid = 1;
    store_in.wrmem1 = 1;
    store_in.imm1 = 2;
    store_in.inst1 = 32'h00619523;

    @(negedge clock);#2
    $display("CYCLE 23");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 2;
    store_in.reg2_data = 16'h1234;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 24");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 4;
    store_in.load_size = HALF;
    store_in.load_valid = 1;

    @(negedge clock);#5
    $display("CYCLE 25: half to half");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 5;
    store_in.load_size = BYTE;
    store_in.load_valid = 1;

    @(negedge clock);#5
    $display("CYCLE 26: case 2/3");
    print_store_queue();

    store_in.sq_spot_valid = 0;
    store_in.load_addr = 4;
    store_in.load_size = WORD;
    store_in.load_valid = 1;

    @(negedge clock);#5
    $display("CYCLE 27: case 20/21/22/23");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 3;
    store_in.reg2_data = 14;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 22: mark spot 3 ready");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 5;
    store_in.reg2_data = 14;
    store_in.reg1_data = 2;

    @(negedge clock);#2
    $display("CYCLE 23: mark spot 5 ready");
    print_store_queue();

    store_in.valid_retire_1 = 1;
    store_in.physReg1 = 4;
    store_in.valid_retire_2 = 1;
    store_in.physReg2 = 5;
    store_in.valid_retire_3 = 1;
    store_in.physReg3 = 6;

    store_in.dest_tag1 = 13;
    store_in.dispatch1_valid = 1;
    store_in.wrmem1 = 1;
    store_in.imm1 = 2;
    store_in.inst1 = 32'h00619523;

    store_in.dest_tag2 = 14;
    store_in.dispatch2_valid = 1;
    store_in.wrmem2 = 1;
    store_in.imm2 = 2;
    store_in.inst2 = 32'h00619523;

    store_in.dest_tag3 = 15;
    store_in.dispatch3_valid = 1;
    store_in.wrmem3 = 1;
    store_in.imm3 = 2;
    store_in.inst3 = 32'h00619523;

    @(negedge clock);#2
    $display("CYCLE 24: 3 way retire and 3 way dispatch");
    print_store_queue();
    store_in.valid_retire_1 = 0;
    store_in.valid_retire_2 = 0;
    store_in.valid_retire_3 = 0;

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 6;
    store_in.reg2_data = 10;
    store_in.reg1_data = 2;
    store_in.cache_miss1 = 1;
    store_in.dispatch1_valid = 0;
    store_in.dispatch2_valid = 0;
    store_in.dispatch3_valid = 0;

    @(negedge clock);#2
    $display("CYCLE 25: try to retire on cache miss");
    print_store_queue();

    store_in.valid_retire_1 = 1; // comes from ROB
    store_in.physReg1 = 7;

    @(negedge clock);#2
    $display("CYCLE 26: try to retire on cache miss");
    print_store_queue();

    store_in.cache_miss1 = 0;
    store_in.valid_retire_1 = 1; // comes from ROB
    store_in.physReg1 = 7;
    store_in.sq_spot_valid = 0;

    @(negedge clock);#2
    $display("CYCLE 27: cache hit");
    print_store_queue();
    reset = 1;
    store_in.cache_miss1 = 1;
    store_in.valid_retire_1 = 0;
    @(negedge clock);
    print_store_queue();
    reset = 0;
    @(negedge clock);#2
    $display("CYCLE 28: retire and add at the same time");
    print_store_queue();
    store_in.dest_tag1 = 13;
    store_in.dispatch1_valid = 1;
    store_in.wrmem1 = 1;
    store_in.imm1 = 2;
    store_in.inst1 = 32'h00b12023;
    @(negedge clock);#2
    $display("CYCLE 29: retire and add at the same time");
    print_store_queue();

    store_in.sq_spot_valid = 1;
    store_in.sq_spot = 0;
    store_in.reg2_data = 32'h0000000f;
    store_in.reg1_data = 2;
    store_in.dispatch1_valid = 0;

    @(negedge clock);#2
    $display("CYCLE 29: retire and add at the same time");
    print_store_queue();
    store_in.load_addr = 4;
    store_in.load_size = WORD;
    store_in.load_valid = 1;
    
    







  





    
    





    // @(negedge clock);#2
    // $display("CYCLE 2");
    // print_store_queue();



    
    $finish;


end



endmodule