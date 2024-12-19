`include "sys_defs.svh"

module archMap#(parameter ARCH_REG_SIZE=32, PHYS_REG_SIZE=64)(
    input  logic                     clock,
    input   logic                    reset,
    input archMap_retire_input  retire_input,
    input    logic                   mispredict1, mispredict2, mispredict3,                 
    output  logic    [`ARCH_REG_SZ-1:0][`PHYS_REG_BITS-1:0]mispredict_branch_output
    
);

    logic [`ARCH_REG_SZ-1:0][$clog2(PHYS_REG_SIZE)-1:0] archMap;
    logic [`ARCH_REG_SZ-1:0][$clog2(PHYS_REG_SIZE)-1:0] newArchMap;
    //add asset stattement to check that tag isn't already in arch reg
    `ifdef DEBUG_FLAG
    always @(negedge clock) begin
        $display("=================Printing Arch map table =======================");
        $display("Arch Map inputs: R1: %b, BMP1: %b, R2: %b, BMP2: %b, R3: %b, BMP3: %b", retire_input.retire1, mispredict1, retire_input.retire2, mispredict2, retire_input.retire3, mispredict3);
        
        for(int i = 0; i<`ARCH_REG_SZ; i++) begin
            $display(" arch reg: %d phys reg: %d",i,archMap[i]);
        end
        $display("=================end map table =======================");
    end
`endif

    always_comb begin
        newArchMap                                      = archMap;
        mispredict_branch_output                        = '0;
        if((retire_input.retire1 && !mispredict1)||(retire_input.retire1 && retire_input.uncondbr1))begin
            //$display("Mispredict1");
            if(retire_input.archIndex1 != `ZERO_REG)begin
                newArchMap[retire_input.archIndex1]          = retire_input.archTag1;
            end
            if((retire_input.retire2 && !mispredict2)||(retire_input.retire2 && retire_input.uncondbr2))begin
               // $display("Mispredict2");
                if(retire_input.archIndex2 != `ZERO_REG)begin
                    newArchMap[retire_input.archIndex2]      = retire_input.archTag2;
                end
                if((retire_input.retire3 && !mispredict3)||(retire_input.retire3 && retire_input.uncondbr3))begin
                    //$display("Mispredict3");
                    if(retire_input.archIndex3 != `ZERO_REG)begin
                        newArchMap[retire_input.archIndex3]  = retire_input.archTag3;
                    end
                end
            end

        end

        if(mispredict1 || mispredict2 || mispredict3) begin
            for(int i = 0; i < `ARCH_REG_SZ; i ++) begin
                mispredict_branch_output[i] = newArchMap[i];
            end
        end
        
        
    end

    always_ff @(posedge clock)begin

        if(reset)begin
            //initialize arch map
            for(int i = 0; i < `ARCH_REG_SZ; i++) begin
                archMap[i]                              <= i;
            end
        end else begin
            //Physical reg output for ROB
            archMap <= newArchMap;
            

            
        end

    end


endmodule
