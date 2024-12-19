
`include "sys_defs.svh"

// This is a pipelined multiplier that multiplies two 64-bit integers and
// returns the low 64 bits of the result.
// This is not an ideal multiplier but is sufficient to allow a faster clock
// period than straight multiplication.

module mult (
    input clock, reset, start,
    input DATA rs1, rs2,
    input MULT_FUNC func,
    input logic [`PHYS_REG_BITS-1:0] dest_tag_in,
    input logic cdb_taken,
    input logic branch_mispredict,

    output logic [`PHYS_REG_BITS-1:0] dest_tag_out,
    output DATA result,
    output logic done,
    output logic full
);

    MULT_FUNC [`MULT_STAGES-2:0] internal_funcs;
    MULT_FUNC func_out;
    logic cool;

    logic [(64*(`MULT_STAGES-1))-1:0] internal_sums, internal_mcands, internal_mpliers;
    logic [`MULT_STAGES-2:0] internal_dones;

    logic  [`MULT_STAGES-2:0][`PHYS_REG_BITS-1:0] dest_tag_internal;

    logic [63:0] mcand, mplier, product;
    logic [63:0] mcand_out, mplier_out; // unused, just for wiring

    logic [`MULT_STAGES-1:0][63:0] product_sum_reg, next_mplier_reg, next_mcand_reg;
    logic [`MULT_STAGES-1:0] empty, new_empty, new_start, new_done, new_done2;
    //MULT_FUNC [`MULT_STAGES-1:0] next_func_reg;
    //logic [`MULT_STAGES-1:0] done_reg;

    // instantiate an array of mult_stage modules
    // this uses concatenation syntax for internal wiring, see lab 2 slides
    mult_stage mstage [`MULT_STAGES-1:0] (
        .clock (clock),
        .reset (reset || branch_mispredict),
        .func        ({internal_funcs,   func}),
        .dest_tag_in({dest_tag_internal, dest_tag_in}),
        .start       (new_start), // forward prev done as next start
        .prev_sum    ({internal_sums,    64'h0}), // start the sum at 0
        .mplier      ({internal_mpliers, mplier}),
        .mcand       ({internal_mcands,  mcand}),
        .product_sum ({product,    internal_sums}),
        .next_mplier ({mplier_out, internal_mpliers}),
        .next_mcand  ({mcand_out,  internal_mcands}),
        .next_func   ({func_out,   internal_funcs}),
        .done        ({cool,       internal_dones}), // done when the final stage is done
        .dest_tag_out({dest_tag_out, dest_tag_internal})
    );

   always_ff @(posedge clock) begin
        if(reset || branch_mispredict)begin
            empty <= '1;
            new_done <= '0;
            done <= 0;
        end else begin
            empty <= new_empty;
            new_done <= new_done2;
            done <= new_done2[`MULT_STAGES - 1];
        end
   end

   always_comb begin
        new_empty = empty;
        new_start = '0;
        new_done2 = new_done;
        full = 0;

        if(cdb_taken)begin
            new_empty = new_empty << 1;
            new_empty[0] = ~start;
            new_start = ~new_empty;
            new_done2 = ~new_empty;
        end else begin
            
            for(int i = `MULT_STAGES - 2; i >=0; i--)begin
                if(new_empty[i+1] && !new_empty[i])begin
                    new_empty[i+1] = 0;
                    new_empty[i] = 1;
                    new_start[i+1] = 1;
                    new_done2[i+1] = 1;
                    new_done2[i] = 0;
                end else begin
                    new_start[i+1] = 0;
                end
            end

            if(new_empty[0])begin
                new_empty[0] = ~start;
                new_start[0] = start;
                new_done2[0] = start;
            end else begin
                new_start[0] = 0;
            end
        end
        if(~cdb_taken && ~new_empty[0] && ~new_empty[1] && ~new_empty[2] && ~new_empty[3]) begin
            full = 1;
        end
   end

    

    // Sign-extend the multiplier inputs based on the operation
    always_comb begin
        case (func)
            M_MUL, M_MULH, M_MULHSU: mcand = {{(32){rs1[31]}}, rs1};
            default:                 mcand = {32'b0, rs1};
        endcase
        case (func)
            M_MUL, M_MULH: mplier = {{(32){rs2[31]}}, rs2};
            default:       mplier = {32'b0, rs2};
        endcase
    end

    // Use the high or low bits of the product based on the output func
   
    assign result = (func_out == M_MUL) ? product[31:0] : product[63:32];

    logic [31:0] count;
    `ifdef DEBUG_FLAG
        task print_pipeline_reg();
            $display("\n      Info        |      Stage 1     |       Stage 2     |       Stage 3     |       Stage 4     |");
            $display("\nInputs");
            $display("\n      Prevsum   |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].prev_sum,mstage[1].prev_sum,mstage[2].prev_sum,mstage[3].prev_sum);
            $display("\n      mplier    |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].mplier, mstage[1].mplier, mstage[2].mplier, mstage[3].mplier);
            $display("\n      mcand     |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].mcand, mstage[1].mcand, mstage[2].mcand, mstage[3].mcand);
            $display("\n      func      |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].func, mstage[1].func, mstage[2].func, mstage[3].func);
            $display("\nOutputs");
            $display("\n      pro_sum   |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].product_sum, mstage[1].product_sum, mstage[2].product_sum, mstage[3].product_sum);
            $display("\n      mplier_n  |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].next_mplier, mstage[1].next_mplier, mstage[2].next_mplier, mstage[3].next_mplier);
            $display("\n      mcand_n   |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].next_mcand, mstage[1].next_mcand, mstage[2].next_mcand, mstage[3].next_mcand);
            $display("\n   next_func  |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].next_func, mstage[1].next_func, mstage[2].next_func, mstage[3].next_func);
            $display("\n      start      |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].start, mstage[1].start, mstage[2].start, mstage[3].start);
            $display("\n      done      |       %d       |       %d        |       %d        |       %d        |",
            new_done[0], new_done[1], new_done[2], new_done[3]);
            $display("\n      empty      |       %d       |       %d        |       %d        |       %d        |",
            empty[0], empty[1], empty[2], empty[3]);
            $display("\n      Dest_tag  |       %d       |       %d        |       %d        |       %d        |",
            mstage[0].dest_tag_out, mstage[1].dest_tag_out, mstage[2].dest_tag_out, mstage[3].dest_tag_out);

            $display("\nInputs: Mplier: %d  |   Mcand: %d  |   Reset: %d    |   Start: %d    |   CDB_Taken: %d    |",
            rs1, rs2, reset, start, cdb_taken);
            $display("\nOutputs: Dest_tag: %d  |   result: %d |   done: %d   |  full: %b    |",
            dest_tag_out, result, done, full);
        endtask
        
        always @(negedge clock) begin
            if(reset) begin
                    count <= 0;
            end else begin
                count <=count + 1;
            end

            $display("\n_________Multiplier Output_________");
            $display("\ncycle: %d",count);
            print_pipeline_reg();
            $display("\nmult_done: %b", done);    
            $display("\n__________End Mult Output_________");
        
        end
    `endif
    



endmodule // mult


module mult_stage (
    input clock, reset, start,
    input [63:0] prev_sum, mplier, mcand,
    input MULT_FUNC func,
    input  [`PHYS_REG_BITS-1:0] dest_tag_in,

    output logic [63:0] product_sum, next_mplier, next_mcand,
    output MULT_FUNC next_func,
    output logic done,
    output logic [`PHYS_REG_BITS-1:0] dest_tag_out

);

    parameter SHIFT = 64/`MULT_STAGES;

    logic [63:0] partial_product, shifted_mplier, shifted_mcand;

    assign partial_product = mplier[SHIFT-1:0] * mcand;

    assign shifted_mplier = {SHIFT'('b0), mplier[63:SHIFT]};
    assign shifted_mcand = {mcand[63-SHIFT:0], SHIFT'('b0)};

    always_ff @(posedge clock) begin
        
        if(start) begin
            product_sum <= prev_sum + partial_product;
            next_mplier <= shifted_mplier;
            next_mcand  <= shifted_mcand;
            next_func   <= func;
            dest_tag_out <= dest_tag_in;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            done <= 1'b0;

            //$display("reset");
        end else begin
            done <= start;
            // if(start)begin
            //     empty <= 0;
            // end else begin
            //     empty <= 1;
            // end
        end
    end

endmodule // mult_stage
//if(!done || !cdb_stall)

//if(!done || !cdb_stall)begin