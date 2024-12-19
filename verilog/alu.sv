// 32 bit integer alu largely copied from p3 ALU
// added 10/18 by brent
module alu (
    input ALU_FUNC func,
    input [31:0] in1,in2,
    input logic [`PHYS_REG_BITS-1:0] dest_tag_in,
    input logic lui,
    input logic aui,
    input ADDR PC,
`ifdef DEBUG_FLAG
    input logic clock,
`endif

    output logic [`PHYS_REG_BITS-1:0] dest_tag_out,
    
    output logic [31:0] out
);

assign dest_tag_out = dest_tag_in;

`ifdef DEBUG_FLAG
    always @(negedge clock) begin
        $display("ALU print _____________________");
        $display("IN1: %d IN2: %d OUT: %d dest: %d func: %d", in1, in2, out, dest_tag_out, func);
        $display("lui: %b | aui: %b", lui, aui);
        $display("end alu _______________________");
    end
`endif


always_comb begin
    if(lui) begin
        out = 0 + in2;
    end else if(aui)begin
        out = PC + in2;
    end else begin 
        case (func)
            ALU_ADD:  out = in1+in2;
            ALU_SUB:  out = in1-in2;
            ALU_AND:  out = in1&in2;
            ALU_SLT:  out = signed'(in1) < signed'(in2);
            ALU_SLTU: out = in1<in2;
            ALU_OR:   out = in1 | in2;
            ALU_XOR:  out = in1 ^ in2;
            ALU_SLL:  out = in1 << in2[4:0];
            ALU_SRL:  out = in1 >> in2[4:0];
            ALU_SRA:  out = signed'(in1) >>> in2[4:0]; // arithmetic from logical shift
            // here to prevent latches:
            default:  out = 32'hfacebeec;
        endcase
    end
end
endmodule