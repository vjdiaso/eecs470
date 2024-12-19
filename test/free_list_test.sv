// Description: This is the testbench for free list module

`include "sys_defs.svh"

`timescale 1us/1ns

module free_list_tb;
    localparam FREELIST_NUM = `PHYS_REG_SZ_R10K;
    localparam FREELIST_SIZE = $clog2(FREELIST_NUM);
    logic clock;
    logic reset;
    logic [1:0] num_tags;
    logic [`N-1:0] free_request;
    logic [`N-1:0] [`PHYS_REG_BITS-1:0] enqueue_preg;
    logic [`N-1:0] [`PHYS_REG_BITS-1:0] dequeue_preg;
    logic [`N-1:0] valid_preg;
    logic branch_mispredict;
    logic [`ARCH_REG_SZ-1:0][`PHYS_REG_BITS-1:0] arch_map_mispredict_input;
    

    free_list #(
        .ARCH_REGS(`ARCH_REG_SZ),
        .PHYS_REGS(`PHYS_REG_SZ_R10K),
        .MAX_ALLOC(3)
    ) freelist_inst(
        .clock(clock),
        .reset(reset),
        .num_tags(num_tags),
        .free_reg_request(free_request),
        .retired_pregs(enqueue_preg),
        .branch_mispredict(branch_mispredict),
        .arch_map_mispredict_input(arch_map_mispredict_input),
        .allocated_pregs(dequeue_preg),
        .valid_preg(valid_preg)
    );



    // The global CLOCK_PERIOD has been defined in the Makefile
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    initial begin
        clock = 0;
        num_tags = 0;
        free_request[0] = 0;
        free_request[1] = 0;
        free_request[2] = 0;
        reset = 1;

        $monitor("preg1 monitor : %d time : %d",dequeue_preg[0], $time);

        @(negedge clock);
        $display("\033[31mRESET\033[0m");
        reset = 0;
        @(posedge clock);
        num_tags = 1;
        $display("\033[31mREQUEST 1\033[0m");
        @(posedge clock);
        num_tags = 0;
        @(posedge clock);
        num_tags = 3;
        $display("\033[31mREQUEST 3\033[0m");
        @(posedge clock);
        num_tags = 0;
        @(posedge clock);
        free_request = '1;
        num_tags = 3;
        enqueue_preg[0] = 13;
        enqueue_preg[1] = 11;
        enqueue_preg[2] = 12;
        @(posedge clock);
         free_request = '0;
        @(negedge clock);
        @(negedge clock);




       
        $finish;
    end

    //     @(negedge clock);

    //     // Test case 3 - multiple preg allocation + single preg free
    //     allocation_request = 3;
    //     free_request = 1;
    //     enqueue_preg[0] = 4;    

    //     @(posedge clock);
    //     allocation_request = 0;
    //     free_request = 0;
    //     $write("Time: %3d |   ", $time);
    //     if (freelist_inst.free_list[4] == 36 && freelist_inst.freelist_valid[4] == 0 &&
    //         freelist_inst.free_list[5] == 37 && freelist_inst.freelist_valid[5] == 0 &&
    //         freelist_inst.free_list[6] == 38 && freelist_inst.freelist_valid[6] == 0 &&
    //         dequeue_preg[0] == 36 && dequeue_preg[1] == 37 && dequeue_preg[2] == 38) begin
    //             @(posedge clock);
    //             if (freelist_inst.free_list[4] == 4 && freelist_inst.freelist_valid[4] == 0 &&
    //                 freelist_inst.free_list[5] == -1 && freelist_inst.freelist_valid[5] == 1 &&
    //                 freelist_inst.free_list[6] == -1 && freelist_inst.freelist_valid[6] == 1 &&
    //                 available_preg == 30) begin
    //                 $display("\033[32m@Passed the test case 3\033[0m");
    //             end else begin
    //                 $display("\033[31m@Failed the test case 3\033[0m");
    //             end
    //         end
    //     #5;
        
    //     $finish;



    // end


    // always @(negedge clock) begin
    //     $display("negedge\n");
    //     $display("Time: %3d |   dequeue_preg1: %d val1: %b | dequeue_preg2: %d val2: %b| dequeue_reg3: %d val3: %b| Reset: %b ",
    //             $time, dequeue_preg[0],valid_preg[0], dequeue_preg[1],valid_preg[1], dequeue_preg[2],valid_preg[2],reset);

    //     $write("Time: %3d    free_list: ", $time);
    //     for (int i=0; i<FREELIST_NUM; i=i+1) begin
    //         if(freelist_inst.free_list[i])begin
    //             $write("%2d ", i);
    //         end
    //     end
    //     $display("\n");

    // end

    // always_comb begin
    //     if(freelist_inst.free_list[dequeue_preg[0]] == 0 )begin
    //         $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[0]);
    //     end
    //      if(freelist_inst.free_list[dequeue_preg[1]] == 0 )begin
    //         $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[1]);
    //     end
    //      if(freelist_inst.free_list[dequeue_preg[2]] == 0 )begin
    //         $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[2]);
    //     end
    // end








endmodule

