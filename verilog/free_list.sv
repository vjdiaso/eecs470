`include "sys_defs.svh"

module free_list #(
    parameter FREELIST_NUM = `PHYS_REG_SZ_R10K,
    parameter ARCH_REG_SZ = `ARCH_REG_SZ
    ) (
    input logic clock,
    input logic reset,

    input logic [1:0] num_tags,    // Number of preg allocation requests - <=3
    input logic [`N-1:0] free_reg_request,    // Number of preg to be freed
    input logic [`N-1:0][`PHYS_REG_BITS-1:0] retired_pregs,   // List of registers to free

    input logic branch_mispredict,
    input logic [ARCH_REG_SZ-1:0][`PHYS_REG_BITS-1:0] arch_map_mispredict_input,

    output logic [`N-1:0][`PHYS_REG_BITS-1:0] allocated_pregs,               // list of allocated registers
    output logic [`N-1:0] valid_preg
);

logic [FREELIST_NUM-1:0] free_list, next_free_list, free_gnt, next_free_list2;

logic [`N-1:0][FREELIST_NUM-1:0] free_gnt_bus;
logic no_req;


psel_gen#(
    .WIDTH(FREELIST_NUM), .REQS(3)
    )
free_sel(
    .req(next_free_list),
    .gnt(free_gnt),
    .gnt_bus(free_gnt_bus),
    .empty(no_req)
);

always_comb begin
    next_free_list = free_list;
    allocated_pregs = '0;
    valid_preg = '0;

    

    //put retired Tolds back in
    for(int i = 0; i<`N; i++) begin
        if(free_reg_request[i]) begin
            next_free_list[retired_pregs[i]] = 1;
        end
    end

    //branch mispredict recovery
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
    
    next_free_list[0] = 0; // never allocate preg0
    next_free_list2 = next_free_list;
    //remove num_tags pregs from free list

    for(int i = 0; i < num_tags; i++) begin
        for (int j = 0; j < `PHYS_REG_SZ_R10K; j++) begin
            if(free_gnt_bus[i][j]) begin
                allocated_pregs[i] = j; //allocate this free reg
                valid_preg[i] = 1;
                next_free_list2[j] = 0; //remove from next free list
            end
        end
    end
end
always_ff @(posedge clock) begin
    if(reset) begin
        //map each arch to their phys
        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++)begin
            if(i<32) begin
                free_list[i] <= 0;
            end else begin
                free_list[i] <= 1;
            end
        end
    end else begin
        free_list <= next_free_list2;
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
    $display("Time: %3d |  preg1: %d | preg2: %d | preg3: %d | Reset: %b | numreq: %d | valid entries: %b | returning: %d %d %d",
            $time, allocated_pregs[0], allocated_pregs[1], allocated_pregs[2], reset, num_tags, free_reg_request, retired_pregs[0], retired_pregs[1], retired_pregs[2]);

    $write("Time: %3d    free_list: ", $time);
    for (int i=0; i<FREELIST_NUM; i=i+1) begin
        if(next_free_list[i]) begin
            $write("%2d ",i);
        end
    end
    $display("\n==================END FREE LIST==========================\n");

end
`endif
endmodule