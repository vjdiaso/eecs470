module freelist_bitvector #(
    parameter FREELIST_NUM = 32,
    parameter ARCH_REG_SZ = 32
    ) (
    input clock,
    input reset,

    input [1:0] dest_reg_request,    // Number of preg allocation requests - <=3
    input [:0] free_reg_request,    // Number of preg to be freed
    input [2:0][5:0] enqueue_preg,   // List of registers to free

    input branch_mispredict,
    input [ARCH_REG_SZ-1:0][5:0] arch_map_mispredict_input,

    output logic [FREELIST_NUM-1:0] freelist_bitmap,   // bit vector representing free registers, 0 means free
    output logic [2:0][5:0] dequeue_preg               // list of allocated registers
);

    logic [FREELIST_NUM-1:0] freelist_bitmap_n; // Next state of freelist bitmap

    psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_MULT))
    mult_sel(
        .req(mult),
        .gnt(mult_gnt),
        .gnt_bus(mult_gnt_bus),
        .empty(no_mult)
    );
    
    always_comb begin
        // Default assignment for the next state of the freelist bitmap
        freelist_bitmap_n = freelist_bitmap;

        if (branch_mispredict) begin
            // Reset freelist to all free, then mark registers in the architectural map as allocated
            freelist_bitmap_n = {FREELIST_NUM{1'b0}}; // Default to all free
            for (int j = 0; j < ARCH_REG_SZ; j++) begin
                freelist_bitmap_n[arch_map_mispredict_input[j]] = 1'b1; // Mark each architectural register as allocated
            end
        end else begin
            // Allocation logic for requested registers
            int allocated_count = 0;
            for (int i = 0; i < FREELIST_NUM && allocated_count < dest_reg_request; i++) begin
                if (freelist_bitmap_n[i] == 1'b0) begin 
                    freelist_bitmap_n[i] = 1'b1;        
                    dequeue_preg[allocated_count] = i;  
                    allocated_count++;
                end
            end

            // deallocation logic for free requests
            for (int i = 0; i < free_reg_request; i++) begin
                freelist_bitmap_n[enqueue_preg[i]] = 1'b0; // Mark specified registers as free
            end
        end
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            freelist_bitmap <= {FREELIST_NUM{1'b0}}; 
        end else begin
            freelist_bitmap <= freelist_bitmap_n; 
        end
    end

endmodule
