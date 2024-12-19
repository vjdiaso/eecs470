// Description: This is the testbench for free list module

`include "sys_defs.svh"

`timescale 1us/1ns

module free_list_tb;
    localparam FREELIST_NUM = `PHYS_REG_SZ_R10K;
    localparam FREELIST_SIZE = $clog2(FREELIST_NUM);
    logic clock;
    logic reset;
    logic [`N-1:0] allocation_request;
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
        .dest_reg_request(allocation_request),
        .free_reg_request(free_request),
        .enqueue_preg(enqueue_preg),
        .branch_mispredict(branch_mispredict),
        .arch_map_mispredict_input(arch_map_mispredict_input),
        .dequeue_preg(dequeue_preg),
        .valid_preg(valid_preg)
    );



    // The global CLOCK_PERIOD has been defined in the Makefile
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    initial begin
        clock = 0;
        allocation_request[0] = 0;
        allocation_request[1] = 0;
        allocation_request[2] = 0;
        free_request[0] = 0;
        free_request[1] = 0;
        free_request[2] = 0;

        // Wait till the first negative clock edge for the initialization check by checking output display
        @(posedge clock);
        reset = 1;
        @(posedge clock);
        reset = 0;

        for (int i=0; i<FREELIST_NUM; i=i+1) begin
            if ((i < 32 && (freelist_inst.free_list[i] != 0)) || ( i >=32 && freelist_inst.free_list[i] != 1)) begin
                $display("\033[31m@Failed the initialization test\033[0m");
                $finish;
            end else begin
                continue;
            end
        end

        $display("\033[32m@Passed the initialization test\033[0m");
        
        @(negedge clock);
    
        $display("Update the control signal but take one cycle to see the effect on the free_list state");
        $display("Still initial free_list state for this cycle");
        // Test case 1 - single preg allocation + single preg free
        allocation_request[0] = 1;
        free_request[0] = 1;
        enqueue_preg[0] = 0;
        
        @(posedge clock);
        allocation_request[0] = 0;
        free_request[0] = 0;        
        $write("Time: %3d |   ", $time);

        
        if (freelist_inst.next_free_list[0] == 1 && valid_preg[0]) begin
            $display("\033[32m@Passed the test case 1\033[0m");
        end else begin
            $display("\033[31m@Failed the test case 1\033[0m");
        end
            
        @(negedge clock);
       
        
    

        // Test case 2 - multiple preg allocation + multiple preg free
        allocation_request = 3'b111;
        free_request = 3'b111;
        enqueue_preg[0] = 1;
        enqueue_preg[1] = 2;
        enqueue_preg[2] = 3;

        @(posedge clock);
        allocation_request = '0;
        free_request = '0;   
        $write("Time: %3d |   ", $time);
        
        
        if (freelist_inst.next_free_list[1] == 1 && freelist_inst.valid_preg[0] == 1 &&
            freelist_inst.next_free_list[2] == 1 && freelist_inst.valid_preg[1] == 1 &&
            freelist_inst.next_free_list[3] == 1 && freelist_inst.valid_preg[2] == 1) begin
            $display("\033[32m@Passed the test case 2\033[0m");
        end else begin
            $display("\033[31m@Failed the test case 2\033[0m");
        end
            
        @(negedge clock);
        @(posedge clock);
        reset = 1;
        @(posedge clock);
        reset = 0;
        @(negedge clock);
        branch_mispredict = 1;
        for(int i = 0; i < `ARCH_REG_SZ; i++)begin
            arch_map_mispredict_input[i] = `ARCH_REG_SZ + i;
        end

        @(posedge clock);
        branch_mispredict = 0;
        arch_map_mispredict_input = '0;
        $write("Time: %3d |   ", $time);

        @(negedge clock);
        @(negedge clock);

        for(int i = 0; i < 15; i++)begin
            @(negedge clock);
            allocation_request = 3'b111;
            @(posedge clock);
            allocation_request = '0;

        end
        @(negedge clock);
        allocation_request = 3'b111;
        @(posedge clock);
        $write("Time: %3d |   ", $time);
        
        
        if (freelist_inst.valid_preg[0] == 0 && freelist_inst.valid_preg[1] == 0 && freelist_inst.valid_preg[2] == 0) begin
            $display("\033[32m@Passed the test case 2\033[0m");
        end else begin
            $display("\033[31m@Failed the test case 2\033[0m");
        end

        @(negedge clock);
        allocation_request = '0;

        for(int i = 0; i < 67; i+=3)begin
            @(negedge clock);
            free_request = 3'b111;
            enqueue_preg[0] = i;
            enqueue_preg[1] = i+1;
            enqueue_preg[2] = i+2;
            @(posedge clock);
            free_request = '0;

        end
        @(negedge clock);
        @(posedge clock);

        allocation_request[0] = 0;
        @(negedge clock);
        @(posedge clock);
        allocation_request[0] = 0;
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
        allocation_request = '0;
        free_request = '1;
        enqueue_preg[0] = 1;
        enqueue_preg[1] = 2;
        enqueue_preg[2] = 3;
        @(negedge clock);
        allocation_request = '1;
        free_request = '0;
        @(negedge clock);
        @(negedge clock);
        allocation_request = '0;
        free_request = '0;
        // @(negedge clock);
        // @(posedge clock);
       
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


    always @(negedge clock) begin
        $display("negedge\n");
        $display("Time: %3d |   dequeue_preg1: %d val1: %b | dequeue_preg2: %d val2: %b| dequeue_reg3: %d val3: %b| Reset: %b ",
                $time, dequeue_preg[0],valid_preg[0], dequeue_preg[1],valid_preg[1], dequeue_preg[2],valid_preg[2],reset);

        $write("Time: %3d    free_list: ", $time);
        for (int i=0; i<FREELIST_NUM; i=i+1) begin
            if(freelist_inst.free_list[i])begin
                $write("%2d ", i);
            end
        end
        $display("\n");

    end

    always_comb begin
        if(freelist_inst.free_list[dequeue_preg[0]] == 0 )begin
            $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[0]);
        end
         if(freelist_inst.free_list[dequeue_preg[1]] == 0 )begin
            $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[1]);
        end
         if(freelist_inst.free_list[dequeue_preg[2]] == 0 )begin
            $display("\033[31m@Failed %d already used\033[0m", dequeue_preg[2]);
        end
    end








endmodule

