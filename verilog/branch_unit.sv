module branch_unit (
    input logic [31:0] val1,
    input logic [31:0] val2,
    input logic [2:0] func, // Which branch condition to check
    input ADDR PC,
    input logic [31:0] offset,
    input logic cond_branch,
    input logic uncond_branchfunc, //add to cpu
`ifdef DEBUG_FLAG
    input logic clock,
    input logic reset,
`endif
    input [`PHYS_REG_BITS-1:0] dest_tag_in,

    output logic [`PHYS_REG_BITS-1:0] dest_tag_out,
    output logic branch_taken,
    output logic [31:0] NPC,//Add to cpu
    output logic [31:0] out
);

logic take;
`ifdef DEBUG_FLAG
logic [31:0] count;
    always @(negedge clock) begin
        if(reset)begin
            count <= '0;
        end else begin
            count <= count + 1;
        end
        $display("BRANCH UNIT print _____________________");
        $display("VAL1: %d VAL2: %d Branch_taken: %d OUT: %h dest: %d func: %d", val1, val2, branch_taken, out, dest_tag_out, func);
        $display("end BRANCH _______________________");
    end
`endif
assign dest_tag_out = dest_tag_in;
assign NPC = PC + 4;

always_comb begin
    
    if(cond_branch) begin
        case (func)
            3'b000:  take = signed'(val1) == signed'(val2); // BEQ
            3'b001:  take = signed'(val1) != signed'(val2); // BNE
            3'b100:  take = signed'(val1) <  signed'(val2); // BLT
            3'b101:  take = signed'(val1) >= signed'(val2); // BGE
            3'b110:  take = val1 < val2;                    // BLTU
            3'b111:  take = val1 >= val2;                   // BGEU
            default: take = `FALSE;
        endcase
    end else begin
        take = 1'b1;
    end
    if(take && cond_branch) begin
        out = PC  + offset;
        branch_taken = 1;
    end else if(take && uncond_branchfunc)begin
        out = PC + offset;
        branch_taken = 1;
    end else if (take && !uncond_branchfunc)begin
        out = val1 + offset;
        branch_taken = 1;
    end else begin
        out = '0;
        branch_taken = 0;
    end
end

endmodule