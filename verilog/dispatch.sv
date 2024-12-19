//fetches up to 3 instructions in order from imem,
//dispatches as many as allowed by space in LSQ RS ROB
//fetches from new pc in the case of a taken branch

`include "sys_defs.svh"
`include "ISA.svh"

module BetterDecode (
    input logic [31:0] inst,
    input logic valid,

    output INST decoded_inst,
    output logic [`ARCH_REG_BITS - 1:0] dest,
    output logic [`ARCH_REG_BITS - 1:0] src1,
    output logic [`ARCH_REG_BITS - 1:0] src2,
    output DATA imm,
    output logic has_dest, has_imm,
    output ALU_FUNC alufunc,
    output MULT_FUNC multfunc,
    output logic [2:0] branchfunc,
    output logic mult, rd_mem, wr_mem, cond_branch, uncond_branch, uncond_branchfunc,
    output logic halt,
    output logic aui, lui
);

INST inst_in;
assign inst_in.inst = inst;

ALU_OPA_SELECT opa_select;
ALU_OPB_SELECT opb_select;
logic          has_dest1; // if there is a destination register
ALU_FUNC       alu_func1;
logic          mult1, rd_mem1, wr_mem1, cond_branch1, uncond_branch1;
logic          csr_op; // used for CSR operations, we only use this as a cheap way to get the return code out
logic          halt1;   // non-zero on a halt
logic          illegal; // non-zero on an illegal instruction

decoder decode (
    .inst(inst_in),
    .valid(valid),

    .opa_select(opa_select),
    .opb_select(opb_select),
    .has_dest(has_dest1), // if there is a destination register
    .alu_func(alu_func1),
    .mult(mult1),
    .rd_mem(rd_mem1), 
    .wr_mem(wr_mem1), 
    .cond_branch(cond_branch1), 
    .uncond_branch(uncond_branch1),
    .csr_op(csr_op), // used for CSR operations, we only use this as a cheap way to get the return code out
    .halt(halt1),   // non-zero on a halt
    .illegal(illegal) // non-zero on an illegal instruction
);

always_comb begin
    uncond_branchfunc = '0;
    decoded_inst = inst_in;
    dest = (has_dest1) ? inst_in.r.rd : `ZERO_REG;
    src1 = (opa_select == OPA_IS_RS1) ? inst_in.r.rs1 : `ZERO_REG;
    src2 = (opb_select == OPB_IS_RS2) ? inst_in.r.rs2 : `ZERO_REG;
    lui = 0;
    aui = 0;
    case (opb_select)
    OPB_IS_I_IMM: begin
        has_imm = 1;
        //imm = inst_in.i.imm;
        imm = `RV32_signext_Iimm(inst_in);
        uncond_branchfunc = 0; // JALR
    end
    OPB_IS_S_IMM: begin
        has_imm = 1;
        //imm = {inst_in.s.off, inst_in.s.set};
        imm = `RV32_signext_Simm(inst_in);
    end
    OPB_IS_B_IMM: begin
        has_imm = 1;
        //imm = {inst_in.b.of, inst_in.b.f, inst_in.b.s, inst_in.b.et};
        imm = `RV32_signext_Bimm(inst_in);
    end
    OPB_IS_U_IMM: begin
        has_imm = 1;
        //imm = inst_in.u.imm;
        imm = `RV32_signext_Uimm(inst_in);
    end
    OPB_IS_J_IMM: begin
        has_imm = 1;
        //imm = {inst_in.j.of, inst_in.j.f, inst_in.j.s, inst_in.j.et};
        imm = `RV32_signext_Jimm(inst_in);
        uncond_branchfunc = 1; // JAL
    end
    default: begin
        has_imm = 0;
        imm = '0;
    end
    endcase
    
    if(mult1) begin
        multfunc = inst_in.r.funct3;
    end else begin
        multfunc = '0;
    end
    if(cond_branch1) begin
        branchfunc = inst_in.b.funct3;
        src1 = inst_in.b.rs1;
        src2 = inst_in.b.rs2;
    end else begin
        branchfunc = '0;
    end
    if(uncond_branch1) begin
        if(~uncond_branchfunc) begin
            src1 = inst_in.i.rs1;
        end else begin
            src1 = `ZERO_REG;
        end
        src2 = `ZERO_REG;
    end if(wr_mem1) begin
        src2 = inst_in.r.rs2;
    end

    if(opb_select == OPB_IS_U_IMM) begin
        if(opa_select == OPA_IS_ZERO) begin
            lui = 1;
        end else if (opa_select == OPA_IS_PC) begin
            aui = 1;
        end
    end

    has_dest = has_dest1;
    alufunc = alu_func1;
    mult = mult1;
    rd_mem = rd_mem1;
    wr_mem = wr_mem1;
    cond_branch = cond_branch1;
    uncond_branch = uncond_branch1;
    halt = halt1;
end
endmodule

module DispatchFifo (
    input dispatch_packet in1,
    input dispatch_packet in2,
    input dispatch_packet in3,
    input logic valid1, valid2, valid3,
    input logic [1:0] num_release,
    input logic clock,
    input logic reset,

    output dispatch_packet out1,
    output dispatch_packet out2,
    output dispatch_packet out3
);
    logic [$clog2(`INST_BUFFER_SZ)-1:0] head, head_n, tail, tail_n;
    dispatch_packet [`INST_BUFFER_SZ-1:0]  fifo, fifo_n;
    logic [$clog2(`INST_BUFFER_SZ):0] open_spots, open_spots_n;

    always_comb begin
        fifo_n = fifo;
        tail_n = tail;
        head_n = head;
        open_spots_n = open_spots;

        if((num_release >= 1)&&(fifo_n[head_n].valid)) begin
            fifo_n[head_n].valid = 0;
            head_n = (head + 1) % `INST_BUFFER_SZ;
            open_spots_n ++;
            if((num_release >= 2)&&(fifo_n[head_n].valid)) begin
                fifo_n[head_n].valid = 0;
                head_n = (head_n + 1) % `INST_BUFFER_SZ;
                open_spots_n ++;
                if((num_release >= 3)&&(fifo_n[head_n].valid)) begin
                fifo_n[head_n].valid = 0;
                head_n = (head_n + 1) % `INST_BUFFER_SZ;
                open_spots_n ++;
                end
            end
        end

        if(open_spots_n >= 1)begin
            if(valid1) begin
                fifo_n[tail_n] = in1;
                fifo_n[tail_n].valid = 1;
                tail_n = (tail_n+1) % `INST_BUFFER_SZ;
                open_spots_n --;
            end
        end
        if(open_spots_n >= 1)begin
            if(valid2) begin
                fifo_n[tail_n] = in2;
                fifo_n[tail_n].valid = 1;
                tail_n = (tail_n+1) % `INST_BUFFER_SZ;
                open_spots_n --;
            end
        end
        if(open_spots_n >= 1)begin
            if(valid3) begin
                fifo_n[tail_n] = in3;
                fifo_n[tail_n].valid = 1;
                tail_n = (tail_n+1) % `INST_BUFFER_SZ;
                open_spots_n --;
            end
        end
        out1 = '0;
        out2 = '0;
        out3 = '0;

        if(num_release>=1)begin
            out1 = fifo[head];
        end
        if(num_release>=2)begin
            out2 = fifo[(head+1)%`INST_BUFFER_SZ];
        end
        if(num_release>=3)begin
            out3 = fifo[(head+2)%`INST_BUFFER_SZ];
        end
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            open_spots <= `INST_BUFFER_SZ;
            head <= 0;
            tail <= 0;
            fifo <= '0;
        end else begin
            fifo <= fifo_n;
            head <= head_n;
            tail <= tail_n;
            open_spots <= open_spots_n;
        end
    end

endmodule

module dispatch (
    input logic branch_mispredict,
    input logic [$clog2(`ROB_SZ+1)-1:0] rob_spots,
    input logic [$clog2(`RS_SZ): 0] rs_spots,
    input logic [4:0] lsq_spots, //just set >3 in testbench for now until we have a lsq
    input logic [31:0] fetch1,
    input logic [31:0] fetch2,
    input logic [31:0] fetch3,
    input logic f1val, f2val, f3val,
    input logic reset, clock,
    input ADDR PC,

    //decoded dispatched insts
    output dispatch_packet inst1,
    output dispatch_packet inst2,
    output dispatch_packet inst3,
    output logic [1:0] num_disp,
    output logic [1:0] num_tags
);
    //Debug Displays
    `ifdef DEBUG_FLAG
        task print_dispatch_packet(input dispatch_packet packet);
            if(packet.valid) begin
                $display("\n|  %h  |  %d  |  %d  |  %d  |  %h  |  %b  |  %h  |  %b  |  %b  |",
                packet.inst,
                packet.dest,
                packet.src1,
                packet.src2,
                packet.imm,
                packet.has_imm,
                packet.alufunc,
                packet.condbr,
                packet.uncondbr,
                );
            end else begin
                $display("\n Invalid packet ");
            end
        endtask

        task print_dispatch();
            $display("\n Printing Dispatched insts");
            $display("\n| inst | dest | src1 | src2 | imm  |has_im|alufun|condbr|uncondbr|");
            print_dispatch_packet(inst1);
            print_dispatch_packet(inst2);
            print_dispatch_packet(inst3);
            $display("\n");
        endtask
        task print_dispatch_fifo();
            $display("\n Printing Dispatch FIFO State at time: %d", $time);
            $display("\n| inst | dest | src1 | src2 | imm  |has_im|alufun|condbr|uncondbr|");
            for(int i = 0; i < `INST_BUFFER_SZ; i++) begin
                print_dispatch_packet(fifo.fifo[i]);
            end
            $display("\n End Of Dispatch FIFO Printing");
        endtask

        //print out dispatch state every cycle
        always @(negedge clock) begin
            $display("\n____________Dispatch Debug Output____________");
            $display("\n num dispatched: %d",numdisp);
            $display("\nfetch1: %h",fetch1);
            $display("\nfetch2: %h",fetch2);
            $display("\nfetch3: %h",fetch3);
            $display("\npc1: %h",decoded_insts[0].PC);
            $display("\npc2: %h",decoded_insts[1].PC);
            $display("\npc3: %h",decoded_insts[2].PC);
            $display("RS_spots: %d",rs_spots);
            $display("ROB_spots: %d",rob_spots);
            $display("lsq_spots: %d",lsq_spots);
            $display("lui:%b %b %b",inst1.lui,inst2.lui,inst3.lui);
            $display("aui:%b %b %b",inst1.aui,inst2.aui,inst3.aui);
            print_dispatch();
            print_dispatch_fifo();
            $display("\n_____________End Dispatch Output_____________");
        end
    `endif
    logic [1:0] numdisp;
    assign num_disp = numdisp;
    //calc num_tags
    always_comb begin
        if(!inst1.valid)begin
            num_tags = 0;
        end else if(!inst2.valid)begin
            num_tags = 1;
        end else if(!inst3.valid)begin
            num_tags = 2;
        end else begin
            num_tags = 3;
        end
    end

    dispatch_packet [2:0] decoded_insts;
    assign decoded_insts[0].PC = PC;
    assign decoded_insts[1].PC = PC + 4;
    assign decoded_insts[2].PC = PC + 8;
    

    BetterDecode decode1(
        .inst(fetch1),
        .valid(f1val),

        .decoded_inst(decoded_insts[0].inst),
        .dest(decoded_insts[0].dest),
        .src1(decoded_insts[0].src1),
        .src2(decoded_insts[0].src2),
        .imm(decoded_insts[0].imm),
        .has_dest(decoded_insts[0].has_dest), 
        .has_imm(decoded_insts[0].has_imm),
        .alufunc(decoded_insts[0].alufunc),
        .multfunc(decoded_insts[0].multfunc),
        .branchfunc(decoded_insts[0].branchfunc),
        .mult(decoded_insts[0].mult), 
        .rd_mem(decoded_insts[0].rdmem), 
        .wr_mem(decoded_insts[0].wrmem), 
        .cond_branch(decoded_insts[0].condbr), 
        .uncond_branch(decoded_insts[0].uncondbr),
        .uncond_branchfunc(decoded_insts[0].uncond_branchfunc),
        .halt(decoded_insts[0].halt),
        .lui(decoded_insts[0].lui),
        .aui(decoded_insts[0].aui)
    );

    BetterDecode decode2(
        .inst(fetch2),
        .valid(f2val),

        .decoded_inst(decoded_insts[1].inst),
        .dest(decoded_insts[1].dest),
        .src1(decoded_insts[1].src1),
        .src2(decoded_insts[1].src2),
        .imm(decoded_insts[1].imm),
        .has_dest(decoded_insts[1].has_dest), 
        .has_imm(decoded_insts[1].has_imm),
        .alufunc(decoded_insts[1].alufunc),
        .multfunc(decoded_insts[1].multfunc),
        .branchfunc(decoded_insts[1].branchfunc),
        .mult(decoded_insts[1].mult), 
        .rd_mem(decoded_insts[1].rdmem), 
        .wr_mem(decoded_insts[1].wrmem), 
        .cond_branch(decoded_insts[1].condbr), 
        .uncond_branch(decoded_insts[1].uncondbr),
        .uncond_branchfunc(decoded_insts[1].uncond_branchfunc),
        .halt(decoded_insts[1].halt),
        .lui(decoded_insts[1].lui),
        .aui(decoded_insts[1].aui)
    );

    BetterDecode decode3(
        .inst(fetch3),
        .valid(f3val),

        .decoded_inst(decoded_insts[2].inst),
        .dest(decoded_insts[2].dest),
        .src1(decoded_insts[2].src1),
        .src2(decoded_insts[2].src2),
        .imm(decoded_insts[2].imm),
        .has_dest(decoded_insts[2].has_dest), 
        .has_imm(decoded_insts[2].has_imm),
        .alufunc(decoded_insts[2].alufunc),
        .multfunc(decoded_insts[2].multfunc),
        .branchfunc(decoded_insts[2].branchfunc),
        .mult(decoded_insts[2].mult), 
        .rd_mem(decoded_insts[2].rdmem), 
        .wr_mem(decoded_insts[2].wrmem), 
        .cond_branch(decoded_insts[2].condbr), 
        .uncond_branch(decoded_insts[2].uncondbr),
        .uncond_branchfunc(decoded_insts[2].uncond_branchfunc),
        .halt(decoded_insts[2].halt),
        .lui(decoded_insts[2].lui),
        .aui(decoded_insts[2].aui)

    );

    DispatchFifo fifo(
        .in1(decoded_insts[0]),
        .in2(decoded_insts[1]),
        .in3(decoded_insts[2]),
        .valid1(f1val), 
        .valid2(f2val), 
        .valid3(f3val),
        .num_release(numdisp),
        .clock(clock),
        .reset((reset || branch_mispredict)),

        .out1(inst1),
        .out2(inst2),
        .out3(inst3)
    );


 
    always_comb begin // sequential logic to find the number of insts we can dispatch
        numdisp = 3;
        //determine if we have a structural hazard preventing 3 way dispatch
        if((rob_spots<3)||(lsq_spots<3)||(rs_spots<3)) begin
            numdisp = 0;
            //there is a structural haz
            if((rob_spots<=lsq_spots)&&(rob_spots<=rs_spots)) begin //ROB limited
                numdisp = rob_spots;
            end else if ((lsq_spots<=rob_spots)&&(lsq_spots<=rs_spots)) begin // LSQ limited
                numdisp = lsq_spots;
            end else if ((rs_spots<=rob_spots)&&(rs_spots<=lsq_spots)) begin // RS limited
                numdisp = rs_spots;
            end
        end
    end



endmodule