`include "sys_defs.svh"


module rob_test();

    logic                                clock, reset;
    archMap_retire_input                 retire_input;
    archMap_index_input                  index_input;
    archMap_index_output                 index_output;

    archMap#(.ARCH_REG_SIZE(4), .PHYS_REG_SIZE(8))
    dut(
        .clock(clock),
        .reset(reset),
        .retire_input(retire_input),
        .index_input(index_input),
        .index_output(index_output)
    );

    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    initial begin
        clock = 1;
        reset = 1;
        $display("\nStart Testbench");
        @(negedge clock);
        retire_input.retire1 = 0;
        retire_input.retire2 = 0;
        retire_input.retire3 = 0;
        retire_input.archIndex1 = 0;
        retire_input.archTag1 = 0;
        retire_input.archIndex2 = 1;
        retire_input.archTag2 = 1;
        retire_input.archIndex3 = 2;
        retire_input.archTag3 = 2;

        index_input.valid1 = 0;
        index_input.valid2 = 0;
        index_input.valid3 = 0;
        index_input.archIndex1 = 0;
        index_input.archIndex2 = 1;
        index_input.archIndex3 = 2;

        $monitor(" %3d | r1: %b tag1: %d r2: %b tag2: %d r3: %b tag3: %d v_i1: %b v_i2: %b v_i3: %b | v_o1: %b tag1: %d v_o2: %b tag2: %d v_o3: %b tag3: %d",
                $time, retire_input.retire1, retire_input.archTag1, retire_input.retire2, retire_input.archTag2, retire_input.retire3, retire_input.archTag3, 
                index_input.valid1, index_input.valid2, index_input.valid3, index_output.valid1, index_output.archTag1, index_output.valid2, index_output.archTag2, 
                index_output.valid3, index_output.archTag3);

        @(negedge clock);
        @(negedge clock);
        reset= 0;

        $display("\nTest 1: Index into map table");
        index_input.valid1 = 1;
        index_input.valid2 = 1;
        index_input.valid3 = 1;

        @(negedge clock);
        index_input.valid1 = 0;
        index_input.valid2 = 0;
        index_input.valid3 = 0;
        @(negedge clock);
        $display("\nTest 2: Changing three registers");
        retire_input.retire1 = 1;
        retire_input.retire2 = 1;
        retire_input.retire3 = 1;
        retire_input.archIndex1 = 0;
        retire_input.archTag1 = 3;
        retire_input.archIndex2 = 1;
        retire_input.archTag2 = 4;
        retire_input.archIndex3 = 2;
        retire_input.archTag3 = 5;
        @(negedge clock);
        retire_input.retire1 = 0;
        retire_input.retire2 = 0;
        retire_input.retire3 = 0;
        @(negedge clock);
        index_input.valid1 = 1;
        index_input.valid2 = 1;
        index_input.valid3 = 1;

        @(negedge clock);
        index_input.valid1 = 0;
        index_input.valid2 = 0;
        index_input.valid3 = 0;
        @(negedge clock);


        $display("\n\033[32m@@@ Passed\033[0m\n");

        $finish;
        
    end

endmodule