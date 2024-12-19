`include "sys_defs.svh"
`include "ISA.svh"

//fetch module accesses memory and provides in order output to dispatch
//for now fetch doesnt do much and memory accesses are faked in the testbench
// fetch's in1, in2, in3 MUST be in order. This can easily be done for fakefetch
// by using pc to index memory array and then 
module fetch(
    // TODO: Add logic when wiring in cpu to define the appropriate numfetch according to the instruction buffer open spots
    input logic [1:0] numfetch, 
    input logic [31:0] branch_target, //what to set pc to if branch taken
    // Handle branch taken
    input logic branch_taken, //if a branch has reached the head of rob and was taken
    input logic [31:0] in1, in2, in3,
    input logic clock, reset,
    input logic miss1, miss2, miss3, //comes from icache, indicates if a request is a miss

    output logic [31:0] pc_out, //current PC of cpu
    output logic [31:0] inst1, inst2, inst3, // fetched instructions in order (1 is oldest)
    output logic f1val, f2val, f3val,
    output logic recval3, recval1, recval2,
    output logic fetch_stall
);
    logic [31:0] pc, pc_next;
    logic [31:0] inst1_reg, inst2_reg, inst3_reg;
    logic [31:0] inst1_next, inst2_next, inst3_next;

    logic fetch_halt1, fetch_halt2, fetch_halt3;


    


    //Debug displays
    `ifdef DEBUG_FLAG
        //print out fetch state every cycle (just pc for now lol)
        always @(negedge clock) begin
            $display("\n____________Fetch Debug Output____________");
            $display("\nCurrent PC: %h",pc);
            $display("\ninst1: %h",in1);
            $display("\nCache Miss1: %b",miss1);
            $display("\ninst2: %h",in2);
            $display("\nCache Miss2: %b",miss2);
            $display("\ninst3: %h",in3);
            $display("\nCache Miss3: %b",miss3);
            $display("\nStall: %b", fetch_stall);
            $display("\n_____________End Fetch Output_____________");
        end
    `endif
    
    always_comb begin
        pc_next = pc;
        inst1_next = inst1_reg;
        inst2_next = inst2_reg;
        inst3_next = inst3_reg;
        recval1 = 0;
        recval2 = 0;
        recval3 = 0;
        f2val = 1;
        f1val = 1;
        f3val = 1;

        if (reset) begin
            inst1 = 0;
            inst2 = 0;
            inst3 = 0;
            f1val = 0;
            f2val = 0;
            f3val = 0;
            fetch_stall = 0;
            pc_out = 0;
        end else begin

        if(numfetch == 3) begin
            recval1 = 1;
            recval2 = 1;
            recval3 = 1;
        end else if (numfetch == 2) begin
            recval1 = 1;
            recval2 = 1;
        end else if (numfetch == 1) begin
            recval1 = 1;
        end

            if (branch_taken) begin 
                pc_next = branch_target;
            end
            fetch_stall = miss1 || miss2 || miss3;

            if (~fetch_stall && ~branch_taken) begin
                
                if((numfetch == 3) && ~miss1 && ~miss2 && ~miss3)begin
                    if (f1val) begin
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                    end 
                    if (f2val) begin
                        pc_next = pc_next + 4;
                        inst2_next = in2;
                    end 
                    if (f3val) begin
                        pc_next = pc_next + 4;
                        inst3_next = in3;
                    end
                end

                if((numfetch == 2) && ~miss1 && ~miss2 && ~miss3)begin
                    if (f1val) begin
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                    end 
                    if (f2val) begin
                        pc_next = pc_next + 4;
                        inst2_next = in2;
                    end 
                    if (!(f1val) || !(f2val) && f3val) begin
                        pc_next = pc_next + 4;
                        inst3_next = in3;
                    end else begin
                        f3val = 0;
                    end
                end

                if((numfetch == 1) && ~miss1 && ~miss2 && ~miss3)begin
                    if (f1val) begin   
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                        f2val = 0;
                        f3val = 0;
                    end else
                    if (f2val) begin
                        pc_next = pc_next + 4;
                        inst2_next = in2;
                        f1val = 0;
                        f3val = 0;
                    end else
                    if (f3val) begin
                        pc_next = pc_next + 4;
                        inst3_next = in3;
                        f1val = 0;
                        f2val = 0;
                    end 
                end
            end else if(~branch_taken) begin
                if (miss1) begin
                    f1val = 0;
                    f2val = 0;
                    f3val = 0;
                end else if (miss2) begin
                    if (numfetch>0) begin
                        f1val = 1;
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                        f2val = 0;
                        f3val = 0;
                    end else begin
                        f1val = 0;
                        f2val = 0;
                        f3val = 0;
                    end
                end else if (miss3) begin
                    if (numfetch==1) begin
                        f1val = 1;
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                        f2val = 0;
                        f3val = 0;
                    end else if (numfetch>=2) begin
                        f1val = 1;
                        pc_next = pc_next + 4;
                        inst1_next = in1;
                        f2val = 1;
                        pc_next = pc_next + 4;
                        inst2_next = in2;
                        f3val = 0;
                    end else begin
                        f1val = 0;
                        f2val = 0;
                        f3val = 0;
                    end
                end


            end

            inst1 = inst1_next;
            inst2 = inst2_next;
            inst3 = inst3_next;
            pc_out = pc;

        end 
    end

    


    always_ff @(posedge clock or posedge reset) begin
        if(reset) begin
            pc <= 0;
            inst1_reg <= 0;
            inst2_reg <= 0;
            inst3_reg <= 0;
        end else begin
            pc <= pc_next;
            inst1_reg <= inst1_next;
            inst2_reg <= inst2_next;
            inst3_reg <= inst3_next;
        end
    end



endmodule