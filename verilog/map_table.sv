`include "sys_defs.svh"

module map_table (
    input map_table_input map_input_packet,
    input clock,
    input reset,
    output map_table_output map_output_packet
);

    // Inner states initialization
    logic [31:0] [`PHYS_REG_BITS - 1:0] maptable; 
    logic [31:0] [`PHYS_REG_BITS - 1:0] next_maptable;    // Corresponding preg mapping each archreg in the map table
    logic [`PHYS_REG_SZ_R10K-1:0] ready_bit, next_ready_bit;
    logic [`PHYS_REG_SZ_R10K-1:0] [`PHYS_REG_BITS - 1:0] preg;
    logic [`ARCH_REG_BITS - 1:0] archreg_index;
    // Next-state initialization
    

    // Utilize a reverse mapping table to optimize the iteration at the ready bit assertion 
    // The reverse mapping table maps an preg to an archreg
    logic [`PHYS_REG_SZ_R10K-1:0] [`ARCH_REG_BITS - 1:0] reverse_maptable;
    logic [`PHYS_REG_SZ_R10K-1:0] [`ARCH_REG_BITS - 1:0] next_reverse_maptable;

    // Variables for holding complex expressions inside the always_comb
    logic [`ARCH_REG_BITS - 1:0] dest_arch;
    logic [`PHYS_REG_BITS - 1:0] preg_new;
    logic [`PHYS_REG_BITS - 1:0] preg_old;

`ifdef DEBUG_FLAG
    always @(negedge clock) begin
        $display("=================Printing map table =======================");
        for(int i = 0; i<`ARCH_REG_SZ; i++) begin
            $display(" arch reg: %d phys reg: %d ready: %b",i,maptable[i],ready_bit[i]);
        end
        $display("=================end map table =======================");
    end
`endif
    
    always_comb begin
        next_maptable = maptable;
        next_ready_bit = ready_bit;
        next_reverse_maptable = reverse_maptable;
        dest_arch = '0;
        preg_new = '0;
        preg_old = '0;
        map_output_packet.imm1_valid = 0;
        map_output_packet.imm2_valid = 0;
        map_output_packet.imm3_valid = 0;
        map_output_packet.store1_valid = 0;
        map_output_packet.store2_valid = 0;
        map_output_packet.store3_valid = 0;
        map_output_packet.operand_preg = '0;
        map_output_packet.operand_ready = '0;
        map_output_packet.valid_inst = '0;
        map_output_packet.dest_preg_old = '0;
        

    // Restore all the Told pregs from the Arch Map after branch misprediction
    if (map_input_packet.branch_misprediction) begin
        next_maptable = map_input_packet.archMap_state;
        next_ready_bit = '1;
        for(int i = 0 ; i < `ARCH_REG_SZ; i++)begin
            next_ready_bit[map_input_packet.archMap_state[i]] = 1;
        end
    end else begin
        // Complete:
        // CDB broadcasts the preg to set the insn's output register ready bit
            for (int i=0; i<3; i=i+1) begin
                if (map_input_packet.cdb_valid[i]) begin
                    //$display("Archreg_index: %d", archreg_index);
                    next_ready_bit[map_input_packet.cdb_preg[i]] = 1'b1;      
                end
            end

        // Dispatch:
        // Read preg tags for input registers and store them in RS -
        // Identify the arch input reg and output the corresponding preg tags, may have two input regs for each insn
        // Read preg tags for output registers and store in ROB -
        // Identify the arch output reg and output the corresponding preg tags Told into ROB

        // For instruction 1

            if (map_input_packet.dispatch_enable[0]) begin
                // Source operands
                if (!map_input_packet.imm1_valid || map_input_packet.store1_valid || map_input_packet.branch1) begin
                    map_output_packet.operand_preg[1] = next_maptable[map_input_packet.operand_arch[1]];
                    map_output_packet.operand_preg[0] = next_maptable[map_input_packet.operand_arch[0]];
                    map_output_packet.operand_ready[1] = next_ready_bit[next_maptable[map_input_packet.operand_arch[1]]];
                    map_output_packet.operand_ready[0] = next_ready_bit[next_maptable[map_input_packet.operand_arch[0]]];
                end else begin
                    map_output_packet.operand_preg[0] = next_maptable[map_input_packet.operand_arch[0]];
                    map_output_packet.operand_ready[0] = next_ready_bit[next_maptable[map_input_packet.operand_arch[0]]];                   
                end
                map_output_packet.imm1_valid = map_input_packet.imm1_valid;
                map_output_packet.store1_valid = map_input_packet.store1_valid;


                if (map_input_packet.has_dest1 && map_input_packet.dest_arch[0] != `ZERO_REG) begin
                    // Destination operands
                    
                    dest_arch = map_input_packet.dest_arch[0];
                    preg_new = map_input_packet.dest_preg_new[0];
                    preg_old = next_maptable[dest_arch];

                    map_output_packet.dest_preg_old[0] = preg_old;
                    
                    next_reverse_maptable[preg_new] = dest_arch;
                    
                    // Update the maptable - preg + ready_bit
                    next_maptable[dest_arch] = preg_new;
                    next_ready_bit[preg_new] = 1'b0;

                    // Update the reverse maptable
                    next_reverse_maptable[preg_new] = dest_arch;

                    //map_output_packet.dest_preg_new[0] = map_input_packet.dest_preg_new[0];
                end
                map_output_packet.valid_inst[0] = 1;
            end


        // For instruction 2
            if (map_input_packet.dispatch_enable[1]) begin
                // Source operands
                if (!map_input_packet.imm2_valid || map_input_packet.store2_valid || map_input_packet.branch2) begin
                    map_output_packet.operand_preg[3] = next_maptable[map_input_packet.operand_arch[3]];
                    map_output_packet.operand_preg[2] = next_maptable[map_input_packet.operand_arch[2]];
                    map_output_packet.operand_ready[3] = next_ready_bit[next_maptable[map_input_packet.operand_arch[3]]];
                    map_output_packet.operand_ready[2] = next_ready_bit[next_maptable[map_input_packet.operand_arch[2]]];
                end else begin
                    map_output_packet.operand_preg[2] = next_maptable[map_input_packet.operand_arch[2]];
                    map_output_packet.operand_ready[2] = next_ready_bit[next_maptable[map_input_packet.operand_arch[2]]];
                end
                map_output_packet.imm2_valid = map_input_packet.imm2_valid;
                map_output_packet.store2_valid = map_input_packet.store2_valid;
                

                if (map_input_packet.has_dest2 && map_input_packet.dest_arch[1] != `ZERO_REG) begin
                    // Destination operands
                    dest_arch = map_input_packet.dest_arch[1];
                    preg_new = map_input_packet.dest_preg_new[1];
                    preg_old = next_maptable[dest_arch];
                    //$display("DEST_PREG: %d", preg_new);

                    // Solve the old dest_preg_old mapping issue, avoid the delay update of the maptable
                    if (map_input_packet.dest_arch[0] == map_input_packet.dest_arch[1]) begin
                        map_output_packet.dest_preg_old[1] = map_input_packet.dest_preg_new[0];
                    end else begin
                        // Output old preg to ROB
                        map_output_packet.dest_preg_old[1] = preg_old;  
                    end

                    // Update the maptable - preg + ready_bit
                    next_maptable[dest_arch] = preg_new;
                    next_ready_bit[preg_new] = 1'b0;
                    //$display("DEST_PREG1: %b", next_ready_bit[preg_new]);

                    // Update the reverse maptable
                    next_reverse_maptable[preg_new] = dest_arch;


                    //map_output_packet.dest_preg_new[1] = map_input_packet.dest_preg_new[1];
                end
                map_output_packet.valid_inst[1] = 1;
            end

        // For instruction 3 
        if (map_input_packet.dispatch_enable[2]) begin
                // Source operands - sent to RS
                if (!map_input_packet.imm3_valid || map_input_packet.store3_valid || map_input_packet.branch3) begin
                    map_output_packet.operand_preg[5] = next_maptable[map_input_packet.operand_arch[5]];
                    map_output_packet.operand_ready[5] = next_ready_bit[next_maptable[map_input_packet.operand_arch[5]]];
                    map_output_packet.operand_preg[4] = next_maptable[map_input_packet.operand_arch[4]];
                    map_output_packet.operand_ready[4] = next_ready_bit[next_maptable[map_input_packet.operand_arch[4]]];
                end else begin
                    map_output_packet.operand_preg[4] = next_maptable[map_input_packet.operand_arch[4]];
                    map_output_packet.operand_ready[4] = next_ready_bit[next_maptable[map_input_packet.operand_arch[4]]];                   
                end
                map_output_packet.imm1_valid = map_input_packet.imm3_valid;
                map_output_packet.store1_valid = map_input_packet.store1_valid;
                
                
                // Destination operands - Told sent to ROB
                if (map_input_packet.has_dest3 && map_input_packet.dest_arch[2] != `ZERO_REG) begin
                    dest_arch = map_input_packet.dest_arch[2];
                    preg_new = map_input_packet.dest_preg_new[2];
                    preg_old = next_maptable[dest_arch];
                    //$display("dest_arch: %d", map_input_packet.dest_arch[2]);
                
                    // Output old preg to ROB
                    map_output_packet.dest_preg_old[2] = preg_old;   

                    // Update the maptable - preg + ready_bit
                    next_maptable[dest_arch] = preg_new;
                    next_ready_bit[preg_new] = 1'b0;

                    // Update the reverse maptable
                    if (map_input_packet.dest_arch[2] == map_input_packet.dest_arch[1]) begin
                        map_output_packet.dest_preg_old[2] = map_input_packet.dest_preg_new[1];
                    end else if (map_input_packet.dest_arch[2] == map_input_packet.dest_arch[0]) begin
                        map_output_packet.dest_preg_old[2] = map_input_packet.dest_preg_new[0];
                    end else begin
                        // Output old preg to ROB
                        map_output_packet.dest_preg_old[2] = preg_old;  
                    end

                    next_reverse_maptable[preg_new] = dest_arch;
                    //map_output_packet.dest_preg_new[2] = map_input_packet.dest_preg_new[2];
                end
                map_output_packet.valid_inst[2] = 1;
            end   
            
    end   
   // $display("DEST_PREG2: %b", next_ready_bit[5]); 
end


    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i=0; i<`ARCH_REG_SZ; i=i+1) begin
                maptable[i] <= i;
                reverse_maptable[i] <= i;
            end
            // initialize the remaining unmapped physical registers
            for (int i=`ARCH_REG_SZ; i<`PHYS_REG_SZ_R10K; i=i+1) begin
                reverse_maptable[i] <= '0;
            end
            for(int i = 0; i< `PHYS_REG_SZ_R10K; i++)begin
                if(i<32)begin
                    ready_bit[i] <= 1'b1;
                end else begin
                    ready_bit[i] <= 1'b0;
                end
            end


        end else begin
            maptable <= next_maptable;
            reverse_maptable <= next_reverse_maptable;
            ready_bit <= next_ready_bit;
        end
    end
    

endmodule