/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file defines macros and data structures used   //
//                 throughout the processor.                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__


//Added by Brent, comment out to disable debug output for synth
//`define DEBUG_FLAG
//`define DCACHE_FLAG
//`define MISSPRED_CNT


// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)
`define INST_SZ 32
// superscalar width
`define N 3
`define CDB_SZ `N // This MUST match your superscalar width

// sizes
`define ROB_SZ 32
`define RS_SZ 10
`define PHYS_REG_SZ_P6 32
`define PHYS_REG_SZ_R10K (32 + `ROB_SZ) 
`define PHYS_REG_BITS 6
`define ARCH_REG_SZ 32
`define ARCH_REG_BITS 5
`define INST_BUFFER_SZ 3

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ 10

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU 3
`define NUM_FU_MULT 1
`define NUM_FU_LOAD 1
`define NUM_FU_STORE 1
`define NUM_FU_BRANCH 1

// number of mult stages (2, 4) (you likely don't need 8)
`define MULT_STAGES 4

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// word and register sizes
typedef logic [31:0] ADDR;
typedef logic [31:0] DATA;
typedef logic [4:0] REG_IDX;

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
// TODO: uncomment this line once you've implemented your cache
//`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
//`define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// memory tags represent a unique id for outstanding mem transactions
// 0 is a sentinel value and is not a valid tag
`define NUM_MEM_TAGS 15
typedef logic [3:0] MEM_TAG;

// icache definitions
`define ICACHE_LINES 32
`define ICACHE_LINE_BITS $clog2(`ICACHE_LINES)

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)


//mem_controller priority defs
`define STORE_OVER_LOAD 1
`define ICACHE_OVER_DCACHE 0

//new ICACHE defs
`define ICACHE_SIZE 16 //16 8 byte lines
`define ICACHE_ASSOCIATIVITY 4
`define ICACHE_NUM_SETS (`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)

//dcache defs
`define DCACHE_SIZE 32 //16 8 byte lines
`define DCACHE_ASSOCIATIVITY 8
`define DCACHE_NUM_SETS (`DCACHE_SIZE / `DCACHE_ASSOCIATIVITY)


// A memory or cache block
typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
    logic      [63:0] dbbl_level;
} MEM_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    MEM_NONE   = 2'h0,
    MEM_LOAD   = 2'h1,
    MEM_STORE  = 2'h2
} MEM_COMMAND;

// icache tag struct
typedef struct packed {
    logic [12-`ICACHE_LINE_BITS:0] tags;
    logic                          valid;
} ICACHE_TAG;

///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code
typedef enum logic [3:0] {
    ALU_ADD     = 4'h0,
    ALU_SUB     = 4'h1,
    ALU_SLT     = 4'h2,
    ALU_SLTU    = 4'h3,
    ALU_AND     = 4'h4,
    ALU_OR      = 4'h5,
    ALU_XOR     = 4'h6,
    ALU_SLL     = 4'h7,
    ALU_SRL     = 4'h8,
    ALU_SRA     = 4'h9
} ALU_FUNC;

// MULT funct3 code
// we don't include division or rem options
typedef enum logic [2:0] {
    M_MUL,
    M_MULH,
    M_MULHSU,
    M_MULHU
} MULT_FUNC;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST  inst;
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST inst;
    ADDR PC;
    ADDR NPC; // PC + 4

    DATA rs1_value; // reg A value
    DATA rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    REG_IDX  dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC alu_func;      // ALU function select (ALU_xxx *)
    logic    mult;          // Is inst a multiply instruction?
    logic    rd_mem;        // Does inst read memory?
    logic    wr_mem;        // Does inst write memory?
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
    logic    halt;          // Is this a halt?
    logic    illegal;       // Is this instruction illegal?
    logic    csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic    valid;
} ID_EX_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    DATA alu_result;
    ADDR NPC;

    logic    take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    DATA     rs2_value;
    logic    rd_mem;
    logic    wr_mem;
    REG_IDX  dest_reg_idx;
    logic    halt;
    logic    illegal;
    logic    csr_op;
    logic    rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE mem_size;
    logic    valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    DATA    result;
    ADDR    NPC;
    REG_IDX dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic   take_branch;
    logic   halt;    // not used by wb stage
    logic   illegal; // not used by wb stage
    logic   valid;
} MEM_WB_PACKET;

/**
 * Commit Packet:
 * This is an output of the processor and used in the testbench for counting
 * committed instructions
 *
 * It also acts as a "WB_PACKET", and can be reused in the final project with
 * some slight changes
 */
typedef struct packed {
    ADDR    NPC;
    DATA    data;
    REG_IDX reg_idx;
    logic   halt;
    logic   illegal;
    logic   valid;
} COMMIT_PACKET;


typedef enum  logic [2:0]{
    NULL,
    ADD,
    MULT,
    LW,
    SW,
    COND_BRANCH,
    UNCOND_BRANCH
} opcode;

typedef struct packed{
    logic [`PHYS_REG_BITS - 1:0]destReg;
    logic [`PHYS_REG_BITS - 1:0]oldReg;
    logic [`ARCH_REG_BITS - 1:0]archReg;
    logic branch;
    logic free;
    logic retire;
    logic taken;
    logic mispredict;
    logic [31:0] branch_target;
    logic halt;
    DATA inst;
    ADDR PC;
    logic store_retire;
    logic uncondbr;

}rob_entry;


typedef struct packed{
    
    logic dispatch1_valid;
    logic dispatch2_valid;
    logic dispatch3_valid;
    logic halt1;
    logic halt2;
    logic halt3;
    logic branch1;
    logic branch2;
    logic branch3;
    logic wrmem1;
    logic wrmem2;
    logic wrmem3;
    
    //Free list
    logic [`PHYS_REG_BITS - 1:0]physical_reg1;
    logic [`PHYS_REG_BITS - 1:0]physical_reg2;
    logic [`PHYS_REG_BITS - 1:0]physical_reg3;
    logic [`ARCH_REG_BITS - 1:0]archReg1;
    logic [`ARCH_REG_BITS - 1:0]archReg2;
    logic [`ARCH_REG_BITS - 1:0]archReg3;

    //Comes from Map table
    logic [`PHYS_REG_BITS - 1:0]physical_old_reg1;
    logic [`PHYS_REG_BITS - 1:0]physical_old_reg2;
    logic [`PHYS_REG_BITS - 1:0]physical_old_reg3;
    logic [`PHYS_REG_BITS - 1:0]cdb_tag1;
    logic cdb_valid1;
    logic [`PHYS_REG_BITS - 1:0]cdb_tag2;
    logic cdb_valid2;
    logic [`PHYS_REG_BITS - 1:0]cdb_tag3;
    logic cdb_valid3; 
    logic [`PHYS_REG_BITS - 1:0]branch_unit_tag;
    logic branch_unit_taken;
    logic branch_valid;
    logic [31:0] branch_target;
    DATA inst1;
    DATA inst2;
    DATA inst3;
    ADDR PC1;
    ADDR PC2;
    ADDR PC3;
    logic [`PHYS_REG_BITS - 1:0] store_retire;
    logic valid_store_retire;

    logic cache_hit1;
    logic cache_hit2;
    logic cache_hit3;
    logic [`PHYS_REG_BITS - 1:0]store_tag1;
    logic [`PHYS_REG_BITS - 1:0]store_tag2;
    logic [`PHYS_REG_BITS - 1:0]store_tag3;

    logic uncondbr1;
    logic uncondbr2;
    logic uncondbr3;
    

}rob_input;

typedef struct packed{
    logic [$clog2(`ROB_SZ+1)-1:0] openSpots;//w
    //Arch Map signals
    logic [`ARCH_REG_BITS - 1:0]archIndex1;//w
    logic [`PHYS_REG_BITS - 1:0]archTag1;//w
    logic [`ARCH_REG_BITS - 1:0]archIndex2;//w
    logic [`PHYS_REG_BITS - 1:0]archTag2;//w
    logic [`ARCH_REG_BITS - 1:0]archIndex3;//w
    logic [`PHYS_REG_BITS - 1:0]archTag3;//w

    logic valid_dispatch1;
    logic valid_dispatch2;
    logic valid_dispatch3;

    //What free list needs for retirement
    logic valid_retire_1;//w
    logic valid_retire_2;//w
    logic valid_retire_3;//w
    logic [`PHYS_REG_BITS - 1:0] retiring_Told_1;//w
    logic [`PHYS_REG_BITS - 1:0] retiring_Told_2;//w
    logic [`PHYS_REG_BITS - 1:0] retiring_Told_3;//w


    logic halt1; 
    logic halt2;
    logic halt3;

    //What the free list need
    logic freeTag1_taken;//w
    logic freeTag2_taken;//w
    logic freeTag3_taken;//w

    logic branch_misspredict_retired1; // w
    logic branch_misspredict_retired2; // w
    logic branch_misspredict_retired3;//w
    //logic [`ROB_SZ-1:0] [`PHYS_REG_BITS - 1:0] misspredict_freelist; // 
    logic [31:0] branch_target;

    DATA inst1;
    DATA inst2;
    DATA inst3;

    ADDR PC1;
    ADDR PC2;
    ADDR PC3;
    rob_entry [`ROB_SZ-1:0] rob;

    logic store_retire1;
    logic store_retire2;
    logic store_retire3;

    logic [`PHYS_REG_BITS - 1:0] store_retire_tag1;
    logic [`PHYS_REG_BITS - 1:0] store_retire_tag2;
    logic [`PHYS_REG_BITS - 1:0] store_retire_tag3;

    logic uncondbr1;
    logic uncondbr2;
    logic uncondbr3;

}rob_output;



typedef struct packed{
    logic retire1;
    logic retire2;
    logic retire3;
    logic [`ARCH_REG_BITS - 1:0]archIndex1;
    logic [`PHYS_REG_BITS - 1:0]archTag1;
    logic [`ARCH_REG_BITS - 1:0]archIndex2;
    logic [`PHYS_REG_BITS - 1:0]archTag2;
    logic [`ARCH_REG_BITS - 1:0]archIndex3;
    logic [`PHYS_REG_BITS - 1:0]archTag3; 
    logic uncondbr1;
    logic uncondbr2;
    logic uncondbr3;
}archMap_retire_input;


typedef struct packed {
    INST inst;
    logic free;
    ALU_FUNC alufunc;
    MULT_FUNC multfunc;
    logic [2:0] branchfunc;
    logic uncond_branchfunc;
    logic mult, rdmem, wrmem, condbr, uncondbr;
    logic [`PHYS_REG_BITS - 1:0]t1;//w
    logic t1_ready;
    logic [`PHYS_REG_BITS - 1:0]t2;//w
    logic t2_ready;
    DATA imm;//w
    logic imm_valid;//w
    logic [`PHYS_REG_BITS - 1:0]dest_reg;//w
    ADDR PC;
    logic [$clog2(`LSQ_SZ)-1:0] sq_spot;
    logic [`LSQ_SZ-1:0] load_dependencies;
    logic lui;
    logic aui;
    logic [`LSQ_SZ-1:0] dependent_stores_in_sq;
} rs_entry;

typedef struct packed{
    //Comes from dispatch
    logic [31:0] inst1;
    logic [31:0] inst2;
    logic [31:0] inst3;
    logic dispatch1_valid;
    logic dispatch2_valid;
    logic dispatch3_valid;
    //Free list
    logic [`PHYS_REG_BITS - 1:0]dest_reg1;
    logic [`PHYS_REG_BITS - 1:0]dest_reg2;
    logic [`PHYS_REG_BITS - 1:0]dest_reg3;

    //Map table inputs;
    logic [`PHYS_REG_BITS - 1:0]inst1_T1;
    logic inst1_T1_ready;
    logic [`PHYS_REG_BITS - 1:0]inst1_T2;
    logic inst1_T2_ready;
    logic [`PHYS_REG_BITS - 1:0]inst2_T1;
    logic inst2_T1_ready;
    logic [`PHYS_REG_BITS - 1:0]inst2_T2;
    logic inst2_T2_ready;
    logic [`PHYS_REG_BITS - 1:0]inst3_T1;
    logic inst3_T1_ready;
    logic [`PHYS_REG_BITS - 1:0]inst3_T2;
    logic inst3_T2_ready;

    //Immediate inputs
    DATA imm1;
    logic imm1_valid;
    DATA imm2;
    logic imm2_valid;
    DATA imm3;
    logic imm3_valid;

    ALU_FUNC alufunc1;
    logic mult1, rdmem1, wrmem1, condbr1, uncondbr1, halt1, archZeroReg1;
    ALU_FUNC alufunc2;
    logic mult2, rdmem2, wrmem2, condbr2, uncondbr2, halt2, archZeroReg2; 
    ALU_FUNC alufunc3;
    logic mult3, rdmem3, wrmem3, condbr3, uncondbr3, halt3, archZeroReg3;
    MULT_FUNC multfunc1;
    MULT_FUNC multfunc2;
    MULT_FUNC multfunc3;
    logic [2:0] branchfunc1;
    logic [2:0] branchfunc2;
    logic [2:0] branchfunc3;
    logic uncond_branchfunc1;
    logic uncond_branchfunc2;
    logic uncond_branchfunc3;
    ADDR PC1;
    ADDR PC2;
    ADDR PC3;

    //CBD inputs
    logic [`PHYS_REG_BITS - 1:0]cdb_tag1;
    logic cdb_valid1;
    logic [`PHYS_REG_BITS - 1:0]cdb_tag2;
    logic cdb_valid2;
    logic [`PHYS_REG_BITS - 1:0]cdb_tag3;
    logic cdb_valid3;

    // Vector that tells us what has left the issue reg to go to functional units
    logic [`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] leftover_issues_from_execute;

    logic branch_misspredict_retired;

    logic [$clog2(`LSQ_SZ)-1:0] sq_spot1;
    logic [$clog2(`LSQ_SZ)-1:0] sq_spot2;
    logic [$clog2(`LSQ_SZ)-1:0] sq_spot3;

    logic [`LSQ_SZ-1:0] load_dependencies;
    logic [$clog2(`LSQ_SZ)-1:0] sq_spot_ready;
    logic sq_spot_ready_valid;
    logic [`LSQ_SZ-1:0] dependent_stores_in_sq;

    logic load_unit_free;
    logic mul_unit_free;

    logic aui1, aui2, aui3, lui1, lui2, lui3;

    
}rs_input;

typedef struct packed{
    //Change to output to be for each FU
    //Output fu gnt and output an array of issue registers
    rs_entry [`NUM_FU_BRANCH +`NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] issue_reg;//w
    logic [`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] issue_valid;//w 
    logic [$clog2(`RS_SZ):0] openSpots;//w
    rs_entry [`RS_SZ-1:0] reservationStation; // debug output
    logic freeTag1_taken; //w
    logic freeTag2_taken;//w
    logic freeTag3_taken;//w
    logic [`PHYS_REG_BITS-1:0] store_leave_t1;
    logic [`PHYS_REG_BITS-1:0] store_leave_t2;
    logic [$clog2(`LSQ_SZ)-1:0] store_spot_leave;
}rs_output;



// How many bits do we actually need for a tag pointing to a specific physical / architectural register?
// More physical registers than archi registers to have extra reg in the free list for renaming?
// Assume we have 32 archreg and 64 physreg
typedef struct packed{
    // D - Dispatch
    // Destination tag modification requests during dispatch D
    // Normal 2 operand_arch_regs + 1 dest_reg
    logic [2:0] [`ARCH_REG_BITS-1:0] dest_arch;
    logic [2:0] [`PHYS_REG_BITS-1:0] dest_preg_new;    // Physical registers for result assignment - T_new from freelist
    // Operands reading from archregs by pregs requests during dispatch D
    logic [5:0] [`ARCH_REG_BITS-1:0] operand_arch;     // At most 6 operands

    // 1 operand_arch_reg + 1 immediate value + 1 dest_reg
    logic imm1_valid;
    logic imm2_valid;
    logic imm3_valid;

    // 2 operand_arch_reg + 0 dest_reg
    logic store1_valid;
    logic store2_valid;
    logic store3_valid;

    logic has_dest1;
    logic has_dest2;
    logic has_dest3; 

    // Identify which insn is available for dispatch
    logic [2:0] dispatch_enable;              

    // C - Complete
    logic [2:0] cdb_valid;  // Valid bit for each entry of the cdb
    logic [2:0] [5:0] cdb_preg; 

    // Pregs restore after branch misprediction
    logic branch_misprediction;
    logic [`ARCH_REG_SZ-1:0][$clog2(`PHYS_REG_SZ_R10K)-1:0] archMap_state;

    logic branch1;
    logic branch2;
    logic branch3;

} map_table_input;

typedef struct packed{
    // D - Dispatch
    // Pregs requested by the operands - Read preg tags for input registers, store in RS
    // 1 operand_arch_reg + 1 immediate value + 1 dest_reg
    logic imm1_valid;
    logic imm2_valid;
    logic imm3_valid;

    // 2 operand_arch_reg + 0 dest_reg
    logic store1_valid;
    logic store2_valid;
    logic store3_valid; 

    // For T1 and T2 in the RS
    logic [5:0] [`PHYS_REG_BITS-1:0] operand_preg;
    logic [5:0] operand_ready;
    logic [2:0] valid_inst;

    // Physical registers for previous insn - T_old to ROB
    logic [2:0] [`PHYS_REG_BITS-1:0] dest_preg_old;
    //logic [2:0] [5:0] dest_preg_new;

} map_table_output;

typedef struct packed{
    INST inst;
    logic [`ARCH_REG_BITS - 1:0] dest;
    logic [`ARCH_REG_BITS - 1:0] src1;
    logic [`ARCH_REG_BITS - 1:0] src2;
    DATA imm;
    logic has_dest, has_imm;
    ALU_FUNC alufunc;
    MULT_FUNC multfunc;
    logic [2:0] branchfunc;
    logic uncond_branchfunc;
    logic mult, rdmem, wrmem, condbr, uncondbr, halt, valid, aui, lui;
    ADDR PC;

} dispatch_packet;

typedef struct packed {
    logic [31:0] inst;
    logic free;
    MEM_SIZE store_size;
    logic [`PHYS_REG_BITS-1:0]dest_tag;
    DATA t2_data;
    DATA offset;
    ADDR PC;
    ADDR wr_addr;
    logic ready;
    logic[1:0] store_range_sz;
    logic cache_requesting;
}store_queue_entry;

typedef struct packed{
    INST inst1;
    INST inst2;
    INST inst3;

    logic dispatch1_valid;
    logic dispatch2_valid;
    logic dispatch3_valid;

    ADDR PC1;
    ADDR PC2;
    ADDR PC3;

    logic [`PHYS_REG_BITS-1:0]dest_tag1;
    logic [`PHYS_REG_BITS-1:0]dest_tag2;
    logic [`PHYS_REG_BITS-1:0]dest_tag3;

    //Immediate inputs
    DATA imm1;
    DATA imm2;
    DATA imm3;

    logic wrmem1;
    logic wrmem2;
    logic wrmem3;

    //retire inputs
    logic valid_retire_1;//w
    logic valid_retire_2;//w
    logic valid_retire_3;//w
    logic [`PHYS_REG_BITS - 1:0]physReg1;//w
    logic [`PHYS_REG_BITS - 1:0]physReg2;//w
    logic [`PHYS_REG_BITS - 1:0]physReg3;//w

    logic branch_mispredict;
    
    //outputs from RS and regfile
    DATA reg1_data;
    DATA reg2_data;
    logic [$clog2(`LSQ_SZ)-1:0] sq_spot;
    logic sq_spot_valid;

    //Load inputs
    ADDR load_addr;
    MEM_SIZE load_size;
    logic load_valid;

    logic cache_miss1;
    logic cache_miss2;
    logic cache_miss3;

    logic [`LSQ_SZ-1:0] store_queue_free_bits_out;

    logic rdmem1;
    logic rdmem2;
    logic rdmem3;

}store_queue_input;


typedef struct packed{
    logic [$clog2(`LSQ_SZ):0] openSpots;//D
    //store ready bits so load ca keep track of dependencies in RS
    logic [`LSQ_SZ-1:0] prev_store_queue_ready_bits;//D //updated ready bits for existing rs entries
    logic [`LSQ_SZ-1:0] store_queue_free_bits;
    
    //Load fowarding logic
    MEM_BLOCK load_data_fwd;
    logic load_valid;
    logic [7:0] load_data_fwd_bytes_valid;
    
    //Retirement outputs
    ADDR wr_addr1;
    DATA data1;
    logic valid_data1;
    MEM_SIZE store_size1;
    ADDR wr_addr2;
    DATA data2;
    logic valid_data2;
    MEM_SIZE store_size2;
    ADDR wr_addr3;
    DATA data3;
    logic valid_data3;
    MEM_SIZE store_size3;

    //Inputs to RS to let loads know what stores are ready
    logic [$clog2(`LSQ_SZ):0] sq_spot_ready;//D
    logic sq_spot_ready_valid;//D
    //Inputs to RS off of dispatch
    logic [$clog2(`LSQ_SZ):0] tail1, tail2, tail3;//D

    //Inputs to Rob to know what store entry is ready to retire
    logic store_set_to_retire_valid;//D
    logic [`PHYS_REG_BITS-1:0] store_set_to_retire; //D
    store_queue_entry [`LSQ_SZ-1:0] store_queue;//D

    logic [$clog2(`LSQ_SZ):0] head_debug, tail_debug;//D

    logic cache_hit1;
    logic cache_hit2;
    logic cache_hit3;
    logic [`PHYS_REG_BITS - 1:0]store_tag1;
    logic [`PHYS_REG_BITS - 1:0]store_tag2;
    logic [`PHYS_REG_BITS - 1:0]store_tag3;


}store_queue_output;

typedef struct packed {
    logic [7:0] lru_cnt;
    logic waiting_for_mem;
    MEM_BLOCK data;
    logic empty;
    MEM_TAG req_memtag;
    logic [(28 - $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)) : 0] tag;
    logic reset;
}ICACHE_ENTRY;

typedef struct packed {
    logic [7:0] lru_cnt;
    logic waiting_for_mem;
    MEM_BLOCK data;
    logic empty;
    MEM_TAG req_memtag;
    logic [(28 - $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)) : 0] tag;
    logic dirty;
    logic reset;
}DCACHE_ENTRY;


`endif // __SYS_DEFS_SVH__

