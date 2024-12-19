/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

// P4 TODO: update this with the new parameters from sys_defs
// namely: PHYS_REG_SZ_P6 or PHYS_REG_SZ_R10K

module regfile (
    input logic    clock, // system clock
    // note: no system reset, register values must be written before they can be read
    input logic [15:0] [`PHYS_REG_BITS-1 : 0] read_idx,
    input logic [6:0] [`PHYS_REG_BITS-1 : 0] write_idx,
    input logic [6:0] write_en,
    input DATA [6:0] write_data,

    output DATA [15:0] read_out
);




    // Intermediate data before accounting for register 0
    DATA  [15:0] rdata;
    // Don't read or write when dealing with register 0
    logic [15:0] re, internal_forward;
    logic [6:0] we;

    // array of regs
    logic [(`PHYS_REG_SZ_R10K - 1):0] [31:0] regs, nregs;

`ifdef DEBUG_FLAG
    task print_regs();
        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++)begin
            $display("preg%d:%h",i,regs[i]);
        end
    endtask
    always @(negedge clock) begin
        $display("============ regfile print ============");
        $display("write_en:%b",write_en);
        print_regs();
    end
`endif

    always_comb begin
        nregs = regs;
        read_out = '0;

        for(int i = 0; i<16; i++)begin
            for(int j = 0; j<7; j++)begin
                if((read_idx[i] == write_idx[j])&&(read_idx[i] != `ZERO_REG)&&(write_en[j] == 1)) begin
                    read_out[i] = write_data[j];
                    internal_forward[i] = 1;
                end else begin
                    internal_forward[i] = 0;
                end
            end
        end
        //set re and we to ensure r0 never r/w
        for(int i = 0; i < 16; i++) begin
            if(read_idx[i] != `ZERO_REG) begin
                re[i] = 1'b1;
            end else begin
                re[i] = 1'b0;
            end
        end
        for(int i = 0; i < 7; i++) begin
            if(write_idx[i] == `ZERO_REG) begin
                we[i] = 1'b0;
            end else begin
                we[i] = 1'b1;
            end
        end

        //next state logic for reg array
        //write at valid we
        for(int i = 0; i < 7; i++) begin
            if(we[i] && write_en[i]) begin
                nregs[write_idx[i]] = write_data[i];
            end
        end

        //read from valid re with forwarding
        for(int i = 0; i < 16; i++) begin
            if(~internal_forward[i]) begin
                if(re[i]) begin
                    read_out[i] = regs[read_idx[i]];
                end else begin
                    read_out[i] = '0;
                end
            end
        end



    end

    always_ff @(posedge clock) begin    
        regs <= nregs;
    end

    //next state logic for reg array
endmodule // regfile
