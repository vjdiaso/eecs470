`include "sys_defs.svh"

module free_list #(
    parameter FREELIST_NUM = `PHYS_REG_SZ_R10K,
    parameter ARCH_REG_SZ = `ARCH_REG_SZ
    ) (
    input logic clock,
    input logic reset,

    input logic [`N-1:0] dest_reg_request,    // Number of preg allocation requests - <=3
    input logic [`N-1:0] free_reg_request,    // Number of preg to be freed
    input logic [`N-1:0][`PHYS_REG_BITS-1:0] enqueue_preg,   // List of registers to free

    input logic branch_mispredict,
    input logic [ARCH_REG_SZ-1:0][`PHYS_REG_BITS-1:0] arch_map_mispredict_input,

    output logic [`N-1:0][`PHYS_REG_BITS-1:0] dequeue_preg,               // list of allocated registers
    output logic [`N-1:0] valid_preg
);

logic [FREELIST_NUM-1:0] free_list, next_free_list, free_gnt, next_free_list2;

logic [`N-1:0][FREELIST_NUM-1:0] free_gnt_bus;
logic no_req;
logic [`N-1:0][`PHYS_REG_BITS-1:0]  next_dequeue_preg;

psel_gen#(
    .WIDTH(FREELIST_NUM), .REQS(3)
    )
free_sel(
    .req(next_free_list),
    .gnt(free_gnt),
    .gnt_bus(free_gnt_bus),
    .empty(no_req)
);

// {next_free_list[`PHYS_REG_BITS - 1:1], 1'b0}
always_comb begin
    next_free_list = free_list;
    valid_preg[0] = 0;
    valid_preg[1] = 0;
    valid_preg[2] = 0;
    next_dequeue_preg = '0;
    if(free_reg_request[0])begin
        next_free_list[enqueue_preg[0]] = 1;
    end
    if(free_reg_request[1])begin
        next_free_list[enqueue_preg[1]] = 1;
    end
    if(free_reg_request[2])begin
        next_free_list[enqueue_preg[2]] = 1;
    end
    
    
    if(branch_mispredict) begin
        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++)begin
            for(int z = 0; z < `ARCH_REG_SZ; z++)begin
                if(z == 0 && i == 0)begin
                    next_free_list[i] = 0;
                    break;
                end else if(arch_map_mispredict_input[z] == i)begin
                    next_free_list[i] = 0;
                    break;
                end else if(z == `ARCH_REG_SZ-1)begin
                    next_free_list[i] = 1;
                end
            end
        end

    end 
    next_free_list[0] = 0;
    next_free_list2 = next_free_list;

    for(int z = 0; z < 3; z++)begin
        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++)begin
            if(free_gnt_bus[z][i])begin
                valid_preg[z] = 1;
                next_dequeue_preg[z] = i;
                next_free_list2[i] =0;
                break;
            end
            if(i == 0) begin
                next_free_list2[i] = 0;
            end
        end
    end
end

always_ff @(posedge clock)begin
    if(reset)begin
        for(int i = 0; i < `ARCH_REG_SZ; i++)begin
            free_list[i] <= 0;
        end
        for(int i = `ARCH_REG_SZ; i < `PHYS_REG_SZ_R10K; i++)begin
            free_list[i] <= 1;
        end
        dequeue_preg[0] <= 32;
        dequeue_preg[1] <= 33;
        dequeue_preg[2] <= 34;
    end else begin
        free_list <= next_free_list2;
        dequeue_preg <= next_dequeue_preg;
    end

end
`ifdef DEBUG_FLAG
int count;
always_ff @(negedge clock) begin
    if(reset)begin
        count <=0;
    end else begin
        count <= count + 1;
    end

    $display("\n================FREE LIST======================");
    $display("count: %d", count);
    $display("Time: %3d |   dequeue_preg1: %d | dequeue_preg2: %d | dequeue_reg3: %d | Reset: %b ",
            $time, dequeue_preg[0], dequeue_preg[1], dequeue_preg[2], reset);

    $write("Time: %3d    free_list: ", $time);
    for (int i=0; i<FREELIST_NUM; i=i+1) begin
        if(free_list[i]) begin
            $write("%2d ",i);
        end
    end
    $display("\n==================END FREE LIST==========================\n");

end
`endif
endmodule