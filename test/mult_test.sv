`include "sys_defs.svh"

module testbench;

    logic clock, start, reset, done, failed;
    DATA r1, r2, correct_r;
    MULT_FUNC f;
    logic [`PHYS_REG_BITS-1:0] dest_tag_in, dest_tag_out;
    logic cdb_taken;
    logic full;
    DATA result;

    string fmt;

    mult dut(
        .clock(clock),
        .reset(reset),
        .start(start),
        .rs1(r1),
        .rs2(r2),
        .func(f),
        .dest_tag_in(dest_tag_in),
        .cdb_taken(cdb_taken),
        .dest_tag_out(dest_tag_out),
        .result(result),
        .done(done),
        .full(full)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    task wait_until_done;
        forever begin : wait_loop
            @(posedge done);
            @(negedge clock);
            if (done) begin
                disable wait_until_done;
            end
        end
    endtask


    task print_pipeline_reg();
        $display("\n      Info        |      Stage 1     |       Stage 2     |       Stage 3     |       Stage 4     |");
        $display("\nInputs");
        $display("\n      Prevsum   |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].prev_sum,dut.mstage[1].prev_sum,dut.mstage[2].prev_sum,dut.mstage[3].prev_sum);
        $display("\n      mplier    |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].mplier, dut.mstage[1].mplier, dut.mstage[2].mplier, dut.mstage[3].mplier);
        $display("\n      mcand     |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].mcand, dut.mstage[1].mcand, dut.mstage[2].mcand, dut.mstage[3].mcand);
        $display("\n      func      |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].func, dut.mstage[1].func, dut.mstage[2].func, dut.mstage[3].func);
        $display("\nOutputs");
        $display("\n      pro_sum   |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].product_sum, dut.mstage[1].product_sum, dut.mstage[2].product_sum, dut.mstage[3].product_sum);
        $display("\n      mplier_n  |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].next_mplier, dut.mstage[1].next_mplier, dut.mstage[2].next_mplier, dut.mstage[3].next_mplier);
        $display("\n      mcand_n   |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].next_mcand, dut.mstage[1].next_mcand, dut.mstage[2].next_mcand, dut.mstage[3].next_mcand);
          $display("\n   next_func  |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].next_func, dut.mstage[1].next_func, dut.mstage[2].next_func, dut.mstage[3].next_func);
        $display("\n      start      |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].start, dut.mstage[1].start, dut.mstage[2].start, dut.mstage[3].start);
        $display("\n      done      |       %d       |       %d        |       %d        |       %d        |",
        dut.new_done[0], dut.new_done[1], dut.new_done[2], dut.new_done[3]);
        $display("\n      empty      |       %d       |       %d        |       %d        |       %d        |",
        dut.empty[0], dut.empty[1], dut.empty[2], dut.empty[3]);
        $display("\n      Dest_tag  |       %d       |       %d        |       %d        |       %d        |",
        dut.mstage[0].dest_tag_out, dut.mstage[1].dest_tag_out, dut.mstage[2].dest_tag_out, dut.mstage[3].dest_tag_out);

        $display("\nInputs: Mplier: %d  |   Mcand: %d  |   Reset: %d    |   Start: %d    |   CDB_Taken: %d    |",
        r1, r2, reset, start, cdb_taken);
        $display("\nOutputs: Dest_tag: %d  |   result: %d |   done: %d   |  full: %b    |",
        dest_tag_out, result, done, full);

        
    endtask


    initial begin
        clock = 0;
        reset = 1;
        start = 0;
        cdb_taken = 1;
        r1 = 1;
        r2 = 2;
        dest_tag_in = 4;
        f = M_MUL;
        cdb_taken = 1;

        
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        reset = 0;
        start = 1;
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MULH;
        start = 1;
        r1 = 0;
        r2 = 0;
        dest_tag_in = 0;
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        start = 0;
        cdb_taken = 1;
        
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        cdb_taken = 1;
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        @(negedge clock);
        @(posedge clock);
        print_pipeline_reg();
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        cdb_taken = 1;
        
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        cdb_taken = 0;
        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MUL;
        start = 1;
        r1 = 6;
        r2 = 8;
        dest_tag_in = 2;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        start = 0;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MUL;
        start = 1;
        r1 = 4;
        r2 = 5;
        dest_tag_in = 6;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MUL;
        start = 1;
        r1 = 2;
        r2 = 5;
        dest_tag_in = 7;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MUL;
        start = 1;
        r1 = 3;
        r2 = 5;
        dest_tag_in = 8;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        f = M_MUL;
        start = 1;
        r1 = 7;
        r2 = 5;
        dest_tag_in = 9;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        cdb_taken = 0;    

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();
        cdb_taken = 1;

        @(posedge clock);
        @(negedge clock);
        print_pipeline_reg();


        $finish;
    end




endmodule