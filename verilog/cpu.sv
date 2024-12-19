`include "sys_defs.svh"
`include "ISA.svh"

module cpu(
    input clock, // System clock
    input reset, // System reset

    input MEM_TAG   mem2proc_transaction_tag, // Memory tag for current transaction
    input MEM_BLOCK mem2proc_data,            // Data coming back from memory
    input MEM_TAG   mem2proc_data_tag,        // Tag for which transaction data is for

    output MEM_COMMAND proc2mem_command, // Command sent to memory
    output ADDR        proc2mem_addr,    // Address sent to memory
    output MEM_BLOCK   proc2mem_data,    // Data sent to memory
    output MEM_SIZE    proc2mem_size,    // Data size sent to memory
    output DCACHE_ENTRY [`DCACHE_NUM_SETS-1:0] [`DCACHE_ASSOCIATIVITY-1:0] dcache_out,

    // Note: these are assigned at the very bottom of the module
    output COMMIT_PACKET [`N-1:0] committed_insts,
    output logic halt
);

    //////////////////////////////////////////////////
    //                                              //
    //                  Dispatch                    //
    //                                              //
    //////////////////////////////////////////////////

    /* 
    Dispatch:

    Inputs: PC
    Sequential Output: Next PC, Architectual dest reg (Map Table) and source regs (Map Table)

    Map Table:

    Inputs: architectural dest reg (dispatch), physical dest reg (free list), architectrual source reg (disptach), cdbs
    Combinational output: physical source reg (RS)

    Architectural Map Table: 
    
    Inputs:physical register(ROB), Architectrual reg (ROB)
    Combinational Outputs: old physical reg

    */
    //Dispatch
    dispatch_packet inst1, inst2, inst3;
    logic [31:0] fetch1, fetch2, fetch3;
    logic f1val, f2val, f3val;
    logic halt1, halt2, halt3;
    logic [1:0] numtags;
    logic recval1, recval2, recval3;

    // ROB inputs and outputs
    rob_input rob_in;
    rob_output rob_out;
    logic [4:0] lsq_spots;
    assign lsq_spots = 4; //change later, we dont have an lsq for milestone 2

    // RS inputs and outputs
    rs_input rs_in;
    rs_output rs_out;

    //Free List input 
    logic [`N-1:0][`PHYS_REG_BITS-1:0] enqueue_preg;
    //Freelist output
    logic [`N-1:0][`PHYS_REG_BITS-1:0] dequeue_preg;
    logic [`N-1:0] valid_preg;


    // Arch Map input
    archMap_retire_input archMap_retire_in;
    // Arch Map output
    logic [`ARCH_REG_SZ-1:0][`PHYS_REG_BITS-1:0] arch_map_mispredict_out;

    // Map Table
    map_table_input map_in;
    map_table_output map_out;

    // CDB
    logic [`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] cdb_gnt;
    logic [`N-1:0][`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] cdb_gnt_bus;
    logic cdb_empty;
    logic [`N-1:0][`PHYS_REG_BITS-1:0] cdb_tags;
    logic [`N-1:0] cdb_tags_valid;

    // Multiplier
    logic mult_done;
    logic mult_full;

    assign halt = halt1 || halt2 || halt3;

    logic [1:0] numdisp;
    logic [2:0] fetch_val;

    logic [2:0] icache_misses;

    DATA raw_inst1, raw_inst2, raw_inst3;

    ADDR icache_req;
    logic icache_req_val, icache_req_sent;

    //Store_queue
    store_queue_input store_in;
    store_queue_output store_out;

    MEM_BLOCK mem_con_store_req_data;
    ADDR mem_con_req;

    MEM_COMMAND memcmd;
    logic req_valid;

    logic load_req_sent, store_req_sent;


    ADDR pc;

    DATA data_from_cache;
    // load unit outputs
    logic load_unit_free;
    logic load_unit_done;
  
    logic [`PHYS_REG_BITS-1:0] load_unit_dest_tag_out;
    ADDR load_unit_load_addr;
    ADDR load_unit_load_addr_for_cache;
    logic load_unit_load_valid;
    logic load_unit_load_addr_for_cache_valid;
    logic [7:0] load_unit_valid_bytes;
    MEM_SIZE load_unit_size, size_to_load;
    logic load_in_load_unit;
    // end load unit outputs


    // regfile
    DATA [15:0] reg_output;
    DATA [6:0] reg_write_data;
    logic [6:0] reg_write_en;
    logic [6:0] [`PHYS_REG_BITS-1 : 0] reg_write_idx;
    logic [15:0] [`PHYS_REG_BITS-1 : 0] reg_read_idx;

    logic load_wen;

    logic branch_wen;
    logic alu3_wen;
    logic [`PHYS_REG_BITS-1:0] alu3_dest;
    logic alu2_wen;
    logic [`PHYS_REG_BITS-1:0] alu2_dest;
    logic alu1_wen;
    logic [`PHYS_REG_BITS-1:0] alu1_dest;
    logic mult_wen;
    logic [`PHYS_REG_BITS-1:0] mult_dest;

    logic comb_free;
    logic load_cdb_taken;
    logic [`LSQ_SZ-1:0] store_queue_free_bits_out;


    mem_controller memcon(
        .icache_req(icache_req),
        .icache_req_val(icache_req_val),
        .load_req(mem_con_req),
        .load_req_val(memcmd == MEM_LOAD && req_valid),
        .store_req(mem_con_req),
        .store_req_data(mem_con_store_req_data),
        .store_req_val(memcmd == MEM_STORE && req_valid),
`ifdef DEBUG_FLAG
        .clock(clock),
`endif  
        .reset(reset),
        .proc2mem_size(proc2mem_size),
        .proc2mem_command(proc2mem_command),
        .proc2mem_addr(proc2mem_addr),
        .proc2mem_data(proc2mem_data),
        .icache_req_sent(icache_req_sent),
        .load_req_sent(load_req_sent),
        .store_req_sent(store_req_sent)
    );

    ICACHE icache(
        .MDB_tag(mem2proc_data_tag),
        .MDB_data(mem2proc_data),
        .req_memtag_in(mem2proc_transaction_tag),
        .req_sent(icache_req_sent),
        .access1(pc),
        .access2(pc + 4),
        .access3(pc + 8),
        .clock(clock),
        .reset(reset),
        .val1(recval1),
        .val2(recval2),
        .val3(recval3),

        .inst1(raw_inst1),
        .inst2(raw_inst2),
        .inst3(raw_inst3),
        .mem_request(icache_req),
        .req_valid(icache_req_val),
        .miss1(icache_misses[0]),
        .miss2(icache_misses[1]),
        .miss3(icache_misses[2])
    );

    fetch fetch(
        .numfetch(numdisp),
        .branch_target(rob_out.branch_target),
        .branch_taken(rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3),
        .in1(raw_inst1),
        .in2(raw_inst2),
        .in3(raw_inst3),
        .clock(clock),
        .reset(reset),
        .miss1(icache_misses[0]),
        .miss2(icache_misses[1]), 
        .miss3(icache_misses[2]), 

        .pc_out(pc),
        .inst1(fetch1),
        .inst2(fetch2),
        .inst3(fetch3),

        .f1val(fetch_val[0]),
        .f2val(fetch_val[1]),
        .f3val(fetch_val[2]),
        .recval1(recval1),
        .recval2(recval2),
        .recval3(recval3),
        .fetch_stall() //TODO
    );


    dispatch dispatch_cpu(
        .branch_mispredict(rob_out.branch_misspredict_retired1|| rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3),
        .rob_spots(rob_out.openSpots),
        .rs_spots(rs_out.openSpots),
        .lsq_spots(store_out.openSpots), //just set >3 in testbench for now until we have a lsq
        .fetch1(fetch1),
        .fetch2(fetch2),
        .fetch3(fetch3),
        .reset(reset), 
        .clock(clock),
        .f1val(fetch_val[0]),
        .f2val(fetch_val[1]),
        .f3val(fetch_val[2]),
        .PC(pc),

        //decoded dispatched insts
        .inst1(inst1),
        .inst2(inst2),
        .inst3(inst3),
        .num_disp(numdisp),
        .num_tags(numtags)
    );

    //Assigning inputs to ROB
    logic [`PHYS_REG_BITS -1 :0] branch_tag;
    ADDR branch_target;
    logic branch_taken;
    always_comb begin
        rob_in.dispatch1_valid = inst1.valid;
        rob_in.dispatch2_valid = inst2.valid;
        rob_in.dispatch3_valid = inst3.valid;
        rob_in.halt1 = inst1.halt;
        rob_in.halt2 = inst2.halt;
        rob_in.halt3 = inst3.halt;
        //Physical reg from free list
        rob_in.physical_reg1 = dequeue_preg[0];
        rob_in.physical_reg2 = dequeue_preg[1];
        rob_in.physical_reg3 = dequeue_preg[2];

        //Arch reg from dispatch
        rob_in.archReg1 = inst1.dest;
        rob_in.archReg2 = inst2.dest;
        rob_in.archReg3 = inst3.dest;

        // T_old from map table
        rob_in.physical_old_reg1 = map_out.dest_preg_old[0];
        rob_in.physical_old_reg2 = map_out.dest_preg_old[1];
        rob_in.physical_old_reg3 = map_out.dest_preg_old[2];

        // CDB
        rob_in.cdb_tag1 = cdb_tags[0];
        rob_in.cdb_valid1 = cdb_tags_valid[0];
        rob_in.cdb_tag2 = cdb_tags[1];
        rob_in.cdb_valid2 = cdb_tags_valid[1];
        rob_in.cdb_tag3 = cdb_tags[2];
        rob_in.cdb_valid3 = cdb_tags_valid[2]; 

        // Branch
        rob_in.branch_unit_tag = branch_tag;
        rob_in.branch_unit_taken = branch_taken; 
        rob_in.branch_valid = rs_out.issue_valid[6];
        rob_in.branch_target = branch_target;

        rob_in.branch1 = inst1.condbr;
        rob_in.branch2 = inst2.condbr;
        rob_in.branch3 = inst3.condbr;

        rob_in.uncondbr1 = inst1.uncondbr;
        rob_in.uncondbr2 = inst2.uncondbr;
        rob_in.uncondbr3 = inst3.uncondbr;

        //insts
        rob_in.inst1 = inst1.inst;
        rob_in.inst2 = inst2.inst;
        rob_in.inst3 = inst3.inst;

        //PCs

        rob_in.PC1 = inst1.PC;
        rob_in.PC2 = inst2.PC;
        rob_in.PC3 = inst3.PC;

        rob_in.store_retire = store_out.store_set_to_retire;
        rob_in.valid_store_retire = store_out.store_set_to_retire_valid;

        rob_in.cache_hit1 = store_out.cache_hit1;
        rob_in.cache_hit2 = store_out.cache_hit2;
        rob_in.cache_hit3 = store_out.cache_hit3;

        rob_in.store_tag1 = store_out.store_tag1;
        rob_in.store_tag2 = store_out.store_tag2;
        rob_in.store_tag3 = store_out.store_tag3;

        rob_in.wrmem1 = inst1.wrmem;
        rob_in.wrmem2 = inst2.wrmem;
        rob_in.wrmem3 = inst3.wrmem;


    end

    ROB #(
        .ROB_SZ(`ROB_SZ)
    )
    rob_cpu(
        .rob_packet(rob_in),
        .clock(clock),
        .reset(reset),
        .rob_out(rob_out)
    );

    // Assigning inputs to RS

    always_comb begin
        
        // from dispatch
        rs_in.inst1 = inst1.inst;
        rs_in.inst2 = inst2.inst;
        rs_in.inst3 = inst3.inst;
        rs_in.dispatch1_valid = inst1.valid;
        rs_in.dispatch2_valid = inst2.valid;
        rs_in.dispatch3_valid = inst3.valid;
        rs_in.aui1 = inst1.aui;
        rs_in.aui2 = inst2.aui;
        rs_in.aui3 = inst3.aui;
        rs_in.lui1 = inst1.lui;
        rs_in.lui2 = inst2.lui;
        rs_in.lui3 = inst3.lui;


        // from free list
        rs_in.dest_reg1 = dequeue_preg[0];
        rs_in.dest_reg2 = dequeue_preg[1];
        rs_in.dest_reg3 = dequeue_preg[2];

        // from map table 
        rs_in.inst1_T1 = map_out.operand_preg[0];
        rs_in.inst1_T1_ready = map_out.operand_ready[0];
        rs_in.inst1_T2 = map_out.operand_preg[1];
        rs_in.inst1_T2_ready = map_out.operand_ready[1];
        rs_in.inst2_T1 = map_out.operand_preg[2];
        rs_in.inst2_T1_ready = map_out.operand_ready[2];
        rs_in.inst2_T2 = map_out.operand_preg[3];
        rs_in.inst2_T2_ready = map_out.operand_ready[3];
        rs_in.inst3_T1 = map_out.operand_preg[4];
        rs_in.inst3_T1_ready = map_out.operand_ready[4];
        rs_in.inst3_T2 = map_out.operand_preg[5];
        rs_in.inst3_T2_ready = map_out.operand_ready[5];

        // more from dispatch
        rs_in.imm1 = inst1.imm;
        rs_in.imm1_valid = inst1.has_imm;
        rs_in.imm2 = inst2.imm;
        rs_in.imm2_valid = inst2.has_imm;
        rs_in.imm3 = inst3.imm;
        rs_in.imm3_valid = inst3.has_imm;

        rs_in.alufunc1 = inst1.alufunc;
        rs_in.mult1 = inst1.mult;
        rs_in.multfunc1 = inst1.multfunc;
        rs_in.rdmem1 = inst1.rdmem;
        rs_in.wrmem1 = inst1.wrmem;
        rs_in.condbr1 = inst1.condbr;
        rs_in.uncondbr1 = inst1.uncondbr;
        rs_in.uncond_branchfunc1 = inst1.uncond_branchfunc;
        rs_in.halt1 = inst1.halt;
        rs_in.archZeroReg1 = (inst1.dest == `ZERO_REG) && inst1.has_dest && (~inst1.uncondbr);
        rs_in.branchfunc1 = inst1.branchfunc;
        rs_in.PC1 = inst1.PC;

        rs_in.alufunc2 = inst2.alufunc;
        rs_in.mult2 = inst2.mult;
        rs_in.multfunc2 = inst2.multfunc;
        rs_in.rdmem2 = inst2.rdmem;
        rs_in.wrmem2 = inst2.wrmem;
        rs_in.condbr2 = inst2.condbr;
        rs_in.uncondbr2 = inst2.uncondbr;
        rs_in.uncond_branchfunc2 = inst2.uncond_branchfunc;
        rs_in.halt2 = inst2.halt;
        rs_in.archZeroReg2 = (inst2.dest == `ZERO_REG) && inst2.has_dest && (~inst2.uncondbr);
        rs_in.branchfunc2 = inst2.branchfunc;
        rs_in.PC2 = inst2.PC;

        rs_in.alufunc3 = inst3.alufunc;
        rs_in.mult3 = inst3.mult;
        rs_in.multfunc3 = inst3.multfunc;
        rs_in.rdmem3 = inst3.rdmem;
        rs_in.wrmem3 = inst3.wrmem;
        rs_in.condbr3 = inst3.condbr;
        rs_in.uncondbr3 = inst3.uncondbr;
        rs_in.uncond_branchfunc3 = inst3.uncond_branchfunc;
        rs_in.halt3 = inst3.halt;
        rs_in.archZeroReg3 = (inst3.dest == `ZERO_REG) && inst3.has_dest && (~inst3.uncondbr);
        rs_in.branchfunc3 = inst3.branchfunc;
        rs_in.PC3 = inst3.PC;

        rs_in.cdb_tag1 = cdb_tags[0];
        rs_in.cdb_valid1 = cdb_tags_valid[0];
        rs_in.cdb_tag2 = cdb_tags[1];
        rs_in.cdb_valid2 = cdb_tags_valid[1];
        rs_in.cdb_tag3 = cdb_tags[2];
        rs_in.cdb_valid3 = cdb_tags_valid[2];

        rs_in.leftover_issues_from_execute[0] = mult_full; // possibly wrong
        //rs_in.leftover_issues_from_execute[5:1] = cdb_gnt[5:1] ^ rs_out.issue_valid[5:1];
        rs_in.leftover_issues_from_execute[3:1] = cdb_gnt[3:1] ^ rs_out.issue_valid[3:1];
        rs_in.leftover_issues_from_execute[4] = 0;
        rs_in.leftover_issues_from_execute[5] = 0; 
        rs_in.leftover_issues_from_execute[6] = 0; // branch
        
        rs_in.branch_misspredict_retired = rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3;

        rs_in.branchfunc1 = inst1.branchfunc;

        rs_in.load_dependencies = store_out.prev_store_queue_ready_bits;
        rs_in.sq_spot_ready = store_out.sq_spot_ready;
        rs_in.sq_spot_ready_valid = store_out.sq_spot_ready_valid;
        rs_in.sq_spot1 = store_out.tail1;
        rs_in.sq_spot2 = store_out.tail2;
        rs_in.sq_spot3 = store_out.tail3;
        rs_in.load_unit_free = comb_free;
        rs_in.mul_unit_free = mult_full;
        rs_in.dependent_stores_in_sq = store_out.store_queue_free_bits;

        
    end

    rs #(
        .RS_SIZE(`RS_SZ)
    )
    rs_cpu(
        .rs_input(rs_in),
        .clock(clock),
        .reset(reset),
        .rs_output(rs_out)
    );

    logic cache_wmiss1, cache_wmiss2, cache_wmiss3, cache_rmiss;

    always_comb begin
        store_in.inst1 = inst1.inst;
        store_in.inst2 = inst2.inst;
        store_in.inst3 = inst3.inst;
        store_in.dispatch1_valid = inst1.valid;
        store_in.dispatch2_valid = inst2.valid;
        store_in.dispatch3_valid = inst3.valid;

        // from free list
        store_in.dest_tag1 = dequeue_preg[0];
        store_in.dest_tag2 = dequeue_preg[1];
        store_in.dest_tag3 = dequeue_preg[2];

        store_in.PC1 = inst1.PC;
        store_in.PC2 = inst2.PC;
        store_in.PC3 = inst3.PC;

        store_in.imm1 = inst1.imm;
        store_in.imm2 = inst2.imm;
        store_in.imm3 = inst3.imm;

        store_in.wrmem1 = inst1.wrmem;
        store_in.wrmem2 = inst2.wrmem;
        store_in.wrmem3 = inst3.wrmem;

        store_in.valid_retire_1 = rob_out.store_retire1;
        store_in.valid_retire_2 = rob_out.store_retire2;
        store_in.valid_retire_3 = rob_out.store_retire3;
        store_in.physReg1 = rob_out.store_retire_tag1;
        store_in.physReg2 = rob_out.store_retire_tag2;
        store_in.physReg3 = rob_out.store_retire_tag3;

        store_in.branch_mispredict = rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3;

        store_in.reg1_data = reg_output[9];
        store_in.reg2_data = reg_output[10];
        store_in.sq_spot = rs_out.issue_reg[5].sq_spot;
        store_in.sq_spot_valid = rs_out.issue_valid[5];

        store_in.load_addr = load_unit_load_addr;
        store_in.load_size = size_to_load;
        store_in.load_valid = load_unit_load_valid;
        store_in.store_queue_free_bits_out = store_queue_free_bits_out;

        store_in.cache_miss1 = cache_wmiss1;
        store_in.cache_miss2 = cache_wmiss2;
        store_in.cache_miss3 = cache_wmiss3;

        store_in.rdmem1 = inst1.rdmem;
        store_in.rdmem2 = inst2.rdmem;
        store_in.rdmem3 = inst3.rdmem;

    end
    
    store_queue store_queue_cpu(
        .store_in(store_in),
        .clock(clock),
        .reset(reset),
        .store_out(store_out)
    );


    assign reg_read_idx[8] = rs_out.issue_reg[4].t1;
    assign reg_read_idx[9] = rs_out.issue_reg[5].t1;
    assign reg_read_idx[10] = rs_out.issue_reg[5].t2;

    

    load_unit load_unit_cpu(
        .clock(clock),
        .reset(reset),
        .valid_load_from_store_queue(store_out.load_valid), //Makes sure the data from store queue is valid
        .valid_load_from_issue_reg(rs_out.issue_valid[4]),
        .load_size(MEM_SIZE'(rs_out.issue_reg[4].inst.r.funct3[1:0])),
        .load_data_foward(store_out.load_data_fwd),// valid data from store queue
        .load_data_fwd_bytes_valid(store_out.load_data_fwd_bytes_valid),//valid bytes from store queue
        .PC(rs_out.issue_reg[4].PC),
        .dest_tag_in(rs_out.issue_reg[4].dest_reg),
        .t1(reg_output[8]),
        .offset(rs_out.issue_reg[4].imm),
        .data_from_cache(data_from_cache),// whole word of data from data cache
        .cache_miss(cache_rmiss),
        .rd_unsigned(rs_out.issue_reg[4].inst.r.funct3[2]),//get from inst.r.func3[2] in issue reg
        .cdb_taken(cdb_gnt[4]),
        .dependent_stores_in_sq(rs_out.issue_reg[4].dependent_stores_in_sq),
        .branch_mispredict(rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3) ,


        .free(load_unit_free),//input to left_over_issue_from_excute to keep load in issue reg
        .done(load_unit_done),//to let cdb know this is a valid choice(sequential output to cdb)
        .data_to_reg(reg_write_data[4]), //data written to regfile(sequential output to cdb)
        .dest_tag_out(load_unit_dest_tag_out),//tag for regfile(sequential output to cdb)
        .load_addr(load_unit_load_addr),//address sent to store queue
        .load_addr_for_cache(load_unit_load_addr_for_cache),//address sent to cache
        .load_valid(load_unit_load_valid),
        .load_addr_for_cache_valid(load_unit_load_addr_for_cache_valid),
        .valid_bytes(load_unit_valid_bytes), // internal signal
        .size(load_unit_size),
        .size_to_load(size_to_load),
        .comb_free(comb_free),
        .cdb_taken_out(load_cdb_taken),
        .store_queue_free_bits_out(store_queue_free_bits_out)
    );

    DCACHE_ENTRY [`DCACHE_NUM_SETS-1:0] [`DCACHE_ASSOCIATIVITY-1:0] dcache_out_dump;

    DCACHE D_CACHE_cpu (
        .MDB_tag(mem2proc_data_tag),
        .MDB_data(mem2proc_data),

        .req_memtag(mem2proc_transaction_tag),
        .req_sent(load_req_sent || store_req_sent),

        .wen1(store_out.valid_data1),
        .wen2(store_out.valid_data2),
        .wen3(store_out.valid_data3),

        .wdata1(store_out.data1),
        .wdata2(store_out.data2),
        .wdata3(store_out.data3),

        .store_size1(store_out.store_size1),
        .store_size2(store_out.store_size2),
        .store_size3(store_out.store_size3),

        .waccess1(store_out.wr_addr1),
        .waccess2(store_out.wr_addr2),
        .waccess3(store_out.wr_addr3),

        .raccess(load_unit_load_addr_for_cache),
        .ren(load_unit_load_addr_for_cache_valid),

        .clock(clock),
        .reset(reset),
        .rdata(data_from_cache),
        .wb(mem_con_store_req_data),
        .mem_request(mem_con_req),
        .memcmd(memcmd),
        .req_valid(req_valid),
        .wmiss1(cache_wmiss1),
        .wmiss2(cache_wmiss2),
        .wmiss3(cache_wmiss3),
        .rmiss(cache_rmiss),
        .dcache_halt_dump(dcache_out_dump)
    );

    assign dcache_out = dcache_out_dump;







    // always_comb begin
    //     if(rs_out.freeTag1_taken == rob_out.freeTag1_taken || rs_out.freeTag2_taken == rob_out.freeTag2_taken || rs_out.freeTag3_taken == rob_out.freeTag3_taken)begin
    //         $display("\033[31m@Failed: ROB Free tag and RS free tag do not match\033[0m");
    //     end
    // end
    
    assign load_wen = cdb_gnt[4]; // change this when we do loads
    
    
    assign reg_write_en = {branch_wen, load_wen, alu3_wen, alu2_wen, alu1_wen, mult_wen};
    assign reg_write_idx[0] = mult_dest;
    assign reg_write_idx[1] = alu1_dest;
    assign reg_write_idx[2] = alu2_dest;
    assign reg_write_idx[3] = alu3_dest;
    assign reg_write_idx[4] = load_unit_dest_tag_out;
   
    regfile regs(
        .clock(clock),
        .read_idx(reg_read_idx),
        .write_idx(reg_write_idx),
        .write_en({rs_out.issue_reg[6].uncondbr, 1'b0, cdb_gnt[4], cdb_gnt[3:0]}),
        .write_data(reg_write_data),
        .read_out(reg_output)
    );

    assign reg_read_idx[2] = rs_out.issue_reg[1].t1;
    assign reg_read_idx[3] = rs_out.issue_reg[1].t2;
    DATA alu1_in2;
    assign alu1_in2 = (rs_out.issue_reg[1].imm_valid) ? rs_out.issue_reg[1].imm : reg_output[3];


    assign alu1_wen = ((alu1_dest == cdb_tags[0]) && cdb_tags_valid[0])||((alu1_dest == cdb_tags[1]) && cdb_tags_valid[1])||((alu1_dest == cdb_tags[2]) && cdb_tags_valid[2]);

    alu alu1(
        .func(rs_out.issue_reg[1].alufunc),
        .in1(reg_output[2]),
        .in2(alu1_in2),
        .dest_tag_in(rs_out.issue_reg[1].dest_reg),
        .lui(rs_out.issue_reg[1].lui),
        .aui(rs_out.issue_reg[1].aui),
        .PC(rs_out.issue_reg[1].PC),
`ifdef DEBUG_FLAG
        .clock(clock),
`endif
        .dest_tag_out(alu1_dest),
        .out(reg_write_data[1])
    );

    assign reg_read_idx[4] = rs_out.issue_reg[2].t1;
    assign reg_read_idx[5] = rs_out.issue_reg[2].t2;
    DATA alu2_in2;
    assign alu2_in2 = (rs_out.issue_reg[2].imm_valid) ? rs_out.issue_reg[2].imm : reg_output[5];

    assign alu2_wen = ((alu2_dest == cdb_tags[0]) && cdb_tags_valid[0])||((alu2_dest == cdb_tags[1]) && cdb_tags_valid[1])||((alu2_dest == cdb_tags[2]) && cdb_tags_valid[2]);

    alu alu2(
        .func(rs_out.issue_reg[2].alufunc),
        .in1(reg_output[4]),
        .in2(alu2_in2),
        .dest_tag_in(rs_out.issue_reg[2].dest_reg),
        .lui(rs_out.issue_reg[2].lui),
        .aui(rs_out.issue_reg[2].aui),
        .PC(rs_out.issue_reg[2].PC),
`ifdef DEBUG_FLAG
        .clock(clock),
`endif
        .dest_tag_out(alu2_dest),
        .out(reg_write_data[2])
    );

    assign reg_read_idx[6] = rs_out.issue_reg[3].t1;
    assign reg_read_idx[7] = rs_out.issue_reg[3].t2;
    DATA alu3_in2;
    assign alu3_in2 = (rs_out.issue_reg[3].imm_valid) ? rs_out.issue_reg[3].imm : reg_output[7];
    
    assign alu3_wen = ((alu3_dest == cdb_tags[0]) && cdb_tags_valid[0])||((alu3_dest == cdb_tags[1]) && cdb_tags_valid[1])||((alu3_dest == cdb_tags[2]) && cdb_tags_valid[2]);

    alu alu3(
        .func(rs_out.issue_reg[3].alufunc),
        .in1(reg_output[6]),
        .in2(alu3_in2),
        .dest_tag_in(rs_out.issue_reg[3].dest_reg),
        .lui(rs_out.issue_reg[3].lui),
        .aui(rs_out.issue_reg[3].aui),
        .PC(rs_out.issue_reg[3].PC),
`ifdef DEBUG_FLAG
        .clock(clock),
`endif
        .dest_tag_out(alu3_dest),
        .out(reg_write_data[3])
    );

    assign reg_read_idx[11] = rs_out.issue_reg[6].t1;
    assign reg_read_idx[12] = rs_out.issue_reg[6].t2;


    assign branch_wen = rs_out.issue_valid[6];
    assign reg_write_idx[6] = branch_tag;

    branch_unit b_unit (
        .val1(reg_output[11]),
        .val2(reg_output[12]),
        .func(rs_out.issue_reg[6].branchfunc),
        .PC(rs_out.issue_reg[6].PC),
        .offset(rs_out.issue_reg[6].imm),
        .cond_branch(rs_out.issue_reg[6].condbr),
        .uncond_branchfunc(rs_out.issue_reg[6].uncond_branchfunc),
`ifdef DEBUG_FLAG
        .clock(clock),
        .reset(reset),
`endif
        .dest_tag_in(rs_out.issue_reg[6].dest_reg),

        .dest_tag_out(branch_tag),
        .branch_taken(branch_taken),
        .NPC(reg_write_data[6]),
        .out(branch_target)
    );

 

    assign mult_wen = ((mult_dest == cdb_tags[0]) && cdb_tags_valid[0])||((mult_dest == cdb_tags[1]) && cdb_tags_valid[1])||((mult_dest == cdb_tags[2]) && cdb_tags_valid[2]);
    assign reg_read_idx[0] = rs_out.issue_reg[0].t1;
    assign reg_read_idx[1] = rs_out.issue_reg[0].t2;

    mult multiplier (
        .clock(clock),
        .reset(reset),
        .start(rs_out.issue_valid[0]),
        .rs1(reg_output[0]),
        .rs2(reg_output[1]),
        .func(rs_out.issue_reg[0].multfunc),
        .dest_tag_in(rs_out.issue_reg[0].dest_reg),
        .cdb_taken(cdb_gnt[0]),
        .branch_mispredict(rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3),

        .dest_tag_out(mult_dest),
        .result(reg_write_data[0]),
        .done(mult_done),
        .full(mult_full)
    );



   

    assign enqueue_preg[0] = rob_out.retiring_Told_1;
    assign enqueue_preg[1] = rob_out.retiring_Told_2;
    assign enqueue_preg[2] = rob_out.retiring_Told_3;

    free_list #(
        .FREELIST_NUM(`PHYS_REG_SZ_R10K),
        .ARCH_REG_SZ(`ARCH_REG_SZ)
    )
    free_list_cpu(
        .clock(clock),
        .reset(reset),
        // possibly change dest_reg_request to use dispatch packet if critical path is bad
        .num_tags(numtags),    // Number of preg allocation requests - <=3
        .free_reg_request({rob_out.valid_retire_3, rob_out.valid_retire_2,rob_out.valid_retire_1}),    // Number of preg to be freed
        .retired_pregs(enqueue_preg),   // List of registers to free

        .branch_mispredict(rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3),
        //Array of physical registers from arch map off of mispredict
       .arch_map_mispredict_input(arch_map_mispredict_out),

        .allocated_pregs(dequeue_preg),               // list of allocated registers
        
        .valid_preg(valid_preg)
    );

    // assign map table inputs
    always_comb begin
        map_in.dest_arch[0] = inst1.dest;
        map_in.dest_arch[1] = inst2.dest;
        map_in.dest_arch[2] = inst3.dest;
        map_in.dest_preg_new[0] = dequeue_preg[0];
        map_in.dest_preg_new[1] = dequeue_preg[1];
        map_in.dest_preg_new[2] = dequeue_preg[2];

        map_in.operand_arch[0] = inst1.src1;
        map_in.operand_arch[1] = inst1.src2;
        map_in.operand_arch[2] = inst2.src1;
        map_in.operand_arch[3] = inst2.src2;
        map_in.operand_arch[4] = inst3.src1;
        map_in.operand_arch[5] = inst3.src2;

        map_in.imm1_valid = inst1.has_imm;
        map_in.imm2_valid = inst2.has_imm;
        map_in.imm3_valid = inst3.has_imm;

        map_in.store1_valid = inst1.wrmem;
        map_in.store2_valid = inst2.wrmem;
        map_in.store3_valid = inst3.wrmem;

        map_in.has_dest1 = inst1.has_dest;
        map_in.has_dest2 = inst2.has_dest;
        map_in.has_dest3 = inst3.has_dest;

        map_in.dispatch_enable[0] = inst1.valid;
        map_in.dispatch_enable[1] = inst2.valid;
        map_in.dispatch_enable[2] = inst3.valid;

        map_in.cdb_valid = cdb_tags_valid;
        map_in.cdb_preg = cdb_tags;

        map_in.branch_misprediction = rob_out.branch_misspredict_retired1 || rob_out.branch_misspredict_retired2 || rob_out.branch_misspredict_retired3;
        map_in.archMap_state = arch_map_mispredict_out;

        map_in.branch1 = inst1.condbr;
        map_in.branch2 = inst2.condbr;
        map_in.branch3 = inst3.condbr;
    end


    map_table map_table_cpu(
        .map_input_packet(map_in),
        .clock(clock),
        .reset(reset),
        .map_output_packet(map_out)
    );


    // assign inputs for archMap

    always_comb begin
        archMap_retire_in.retire1 = rob_out.valid_retire_1;
        archMap_retire_in.retire2 = rob_out.valid_retire_2;
        archMap_retire_in.retire3 = rob_out.valid_retire_3;
        archMap_retire_in.archIndex1 = rob_out.archIndex1;
        archMap_retire_in.archTag1 = rob_out.archTag1;
        archMap_retire_in.archIndex2 = rob_out.archIndex2;
        archMap_retire_in.archTag2 = rob_out.archTag2;
        archMap_retire_in.archIndex3 = rob_out.archIndex3;
        archMap_retire_in.archTag3 = rob_out.archTag3;
        archMap_retire_in.uncondbr1 = rob_out.uncondbr1;
        archMap_retire_in.uncondbr2 = rob_out.uncondbr2;
        archMap_retire_in.uncondbr3 = rob_out.uncondbr3;
    end

    archMap #(
        .ARCH_REG_SIZE(`ARCH_REG_SZ),
        .PHYS_REG_SIZE(`PHYS_REG_SZ_R10K)
    )
    archMap_cpu(
        .clock(clock),
        .reset(reset),
        .retire_input(archMap_retire_in),
        .mispredict1(rob_out.branch_misspredict_retired1), 
        .mispredict2(rob_out.branch_misspredict_retired2), 
        .mispredict3(rob_out.branch_misspredict_retired3),                 
        .mispredict_branch_output(arch_map_mispredict_out)
    );

    psel_gen#(
        .WIDTH(`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT), .REQS(`CDB_SZ))
    cdb_sel(
        .req({1'b0, 1'b0, load_unit_done && !load_cdb_taken, rs_out.issue_valid[3:1], mult_done}), 
        .gnt(cdb_gnt),
        .gnt_bus(cdb_gnt_bus),
        .empty(cdb_empty)
    );
    // always_ff@(negedge clock)begin
    //     $display("cdb_gnt: %b",cdb_gnt);
    // end

    // Decoder for CDB gnt line
    logic [$clog2(`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT)-1:0] cdb_gnt_bus_0;
    logic [$clog2(`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT)-1:0] cdb_gnt_bus_1;
    logic [$clog2(`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT)-1:0] cdb_gnt_bus_2;

    always_comb begin
        cdb_gnt_bus_0 = '0;
        for(int i = 0; i < `NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT; i++)begin
            if(cdb_gnt_bus[0][i])begin
                cdb_gnt_bus_0 = i;
                break;
            end
        end
    end

     always_comb begin
        cdb_gnt_bus_1 = '0;
        for(int i = 0; i < `NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT; i++)begin
            if(cdb_gnt_bus[1][i])begin
                cdb_gnt_bus_1 = i;
                break;
            end
        end
    end

     always_comb begin
        cdb_gnt_bus_2 = '0;
        for(int i = 0; i < `NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT; i++)begin
            if(cdb_gnt_bus[2][i])begin
                cdb_gnt_bus_2 = i;
                break;
            end
        end
    end

    logic [`PHYS_REG_BITS-1:0] cdb1PhysTagIn;
    logic cdb1PhysTagIn_valid;
    assign cdb1PhysTagIn = cdb_gnt_bus[0] == 1 ? mult_dest : cdb_gnt_bus[0] == 7'b0010000 ? load_unit_dest_tag_out: rs_out.issue_reg[cdb_gnt_bus_0].dest_reg;

    cdb #(
        .CDB_SZ(`PHYS_REG_BITS)
    )
    cdb1(
        .physTagIn(cdb1PhysTagIn),
        .validInputTag(cdb_gnt_bus[0]!=0),
        .clock(clock),
        .reset(reset),
        .physTagOut(cdb_tags[0]),
        .validOutputTag(cdb_tags_valid[0])
    );
    
    logic [`PHYS_REG_BITS-1:0] cdb2PhysTagIn;
    logic cdb2PhysTagIn_valid;
    assign cdb2PhysTagIn = cdb_gnt_bus[1] == 1 ? mult_dest : cdb_gnt_bus[1] == 7'b0010000 ? load_unit_dest_tag_out : rs_out.issue_reg[cdb_gnt_bus_1].dest_reg;

    cdb #(
        .CDB_SZ(`PHYS_REG_BITS)
    )
    cdb2(
        .physTagIn(cdb2PhysTagIn),
        .validInputTag(cdb_gnt_bus[1]!=0),
        .clock(clock),
        .reset(reset),
        .physTagOut(cdb_tags[1]),
        .validOutputTag(cdb_tags_valid[1])
    );

    logic [`PHYS_REG_BITS-1:0] cdb3PhysTagIn;
    logic cdb3PhysTagIn_valid;
    assign cdb3PhysTagIn = cdb_gnt_bus[2] == 1 ? mult_dest : cdb_gnt_bus[2] == 7'b0010000 ? load_unit_dest_tag_out : rs_out.issue_reg[cdb_gnt_bus_2].dest_reg;

    cdb #(
        .CDB_SZ(`PHYS_REG_BITS)
    )
    cdb3(
        .physTagIn(cdb3PhysTagIn),
        .validInputTag(cdb_gnt_bus[2]!=0),
        .clock(clock),
        .reset(reset),
        .physTagOut(cdb_tags[2]),
        .validOutputTag(cdb_tags_valid[2])
    );

    //////////////////////////////////////////////////
    //                                              //
    //                Writeback                     //
    //                                              //
    //////////////////////////////////////////////////
    //COMMIT PACKETS probably done
    always_comb begin
        reg_read_idx[13] = rob_out.archTag1;
        reg_read_idx[14] = rob_out.archTag2;
        reg_read_idx[15] = rob_out.archTag3;
    end
    always_ff @(negedge clock) begin
        if(rob_out.valid_retire_1)begin
            committed_insts[0].NPC <= rob_out.PC1 +4;
            committed_insts[0].data <= reg_output[13];
            committed_insts[0].reg_idx <= rob_out.archIndex1;
            committed_insts[0].halt <= rob_out.halt1;
            committed_insts[0].illegal <= '0;
            committed_insts[0].valid  <= 1;
            `ifdef DCACHE_FLAG
            $display("Committed1: Data: %d | PC : %h | Reg: %d | Halt: %b", reg_output[13], rob_out.PC1+4, rob_out.archIndex1, rob_out.halt1);
            `endif 
        end else begin
            committed_insts[0].valid <= 0;
        end
        if(rob_out.valid_retire_2)begin
            committed_insts[1].NPC <= rob_out.PC2 +4;
            committed_insts[1].data <= reg_output[14];
            committed_insts[1].reg_idx <= rob_out.archIndex2;
            committed_insts[1].halt <= rob_out.halt2;
            committed_insts[1].illegal <= '0;
            committed_insts[1].valid  <= 1;
            `ifdef DCACHE_FLAG
            $display("Committed2: Data: %d | PC : %h | Reg: %d | Halt: %b", reg_output[14], rob_out.PC2+4, rob_out.archIndex2, rob_out.halt2);
            `endif
        end else begin
            committed_insts[1].valid <= 0;
        end
        if(rob_out.valid_retire_3)begin
            committed_insts[2].NPC <= rob_out.PC3 +4;
            committed_insts[2].data <= reg_output[15];
            committed_insts[2].reg_idx <= rob_out.archIndex3;
            committed_insts[2].halt <= rob_out.halt3;
            committed_insts[2].illegal <= '0;
            committed_insts[2].valid  <= 1;
            `ifdef DCACHE_FLAG
            $display("Committed3: Data: %d | PC : %h | Reg: %d | Halt: %b", reg_output[15], rob_out.PC3+4, rob_out.archIndex3, rob_out.halt3);
            `endif
        end else begin
            committed_insts[2].valid <= 0;
        end
    end
endmodule