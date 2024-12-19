`include "sys_defs.svh"

module rs#(parameter RS_SIZE=`RS_SZ)(
    input rs_input rs_input,
    input logic clock, reset,
    output rs_output rs_output
);

rs_entry [RS_SIZE - 1 : 0] rs, new_rs;
logic [$clog2(RS_SIZE): 0] new_openSpots, openSpots, dispatch1, dispatch2, dispatch3;
logic [RS_SIZE-1:0] mult, mult_gnt, mult_gnt_wire, adders, adder_gnt, adder_gnt_wire, branch, branch_gnt, branch_gnt_wire, total_gnt;
logic [RS_SIZE-1:0] store, store_gnt, store_gnt_wire;
logic [RS_SIZE-1:0] load, load_gnt, load_gnt_wire;
logic [`NUM_FU_ALU-1:0][RS_SIZE-1:0] adder_gnt_bus;
logic [`NUM_FU_MULT-1:0][RS_SIZE-1:0] mult_gnt_bus;
logic [`NUM_FU_BRANCH-1:0][RS_SIZE-1:0] branch_gnt_bus;
logic [`NUM_FU_STORE-1:0][RS_SIZE-1:0] store_gnt_bus;
logic [`NUM_FU_LOAD-1:0][RS_SIZE-1:0] load_gnt_bus;
logic no_add, no_mult, no_free_spots, no_branch, no_store, no_load;
logic [RS_SIZE-1:0] free_spots, new_free_spots, free_spots_gnt, new_free_spots2;
logic [`N-1:0][RS_SIZE-1:0] free_spots_gnt_bus;
logic valid_store_leave;
logic [`PHYS_REG_BITS-1:0] next_store_leave_t1, next_store_leave_t2;
logic [$clog2(`LSQ_SZ)-1:0] next_store_spot_leave;
//logic [2:0] new_valid_entries;
psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`N))
rs_sel(
    .req(new_free_spots),
    .gnt(free_spots_gnt),
    .gnt_bus(free_spots_gnt_bus),
    .empty(no_free_spots)
);

psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_MULT))
mult_sel(
    .req(mult),  // possibly wrong
    .gnt(mult_gnt),
    .gnt_bus(mult_gnt_bus),
    .empty(no_mult)
);

psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_ALU))
adder_sel(
    .req(adders),
    .gnt(adder_gnt),
    .gnt_bus(adder_gnt_bus),
    .empty(no_add)
);

psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_BRANCH))
branch_sel(
    .req(branch),
    .gnt(branch_gnt),
    .gnt_bus(branch_gnt_bus),
    .empty(no_branch)
);

psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_STORE))
store_sel(
    .req(store),
    .gnt(store_gnt),
    .gnt_bus(store_gnt_bus),
    .empty(no_store)
);

psel_gen#(
    .WIDTH(RS_SIZE), .REQS(`NUM_FU_LOAD))
load_sel(
    .req(rs_input.load_unit_free ? load : '0),
    .gnt(load_gnt),
    .gnt_bus(load_gnt_bus),
    .empty(no_load)
);

//Use selctors to index into rs, put selcted instructions into an issue reg for each FU,
//Clear those instructions from the reservation station, next cycle send those instructions in the issue regs to execute 
rs_entry [`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] new_issue_reg;
logic [`NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT - 1:0] issue_valid;




`ifdef DEBUG_FLAG
    task opcode_to_string(input rs_entry rs_entry, output string out);
        if(rs_entry.mult) begin
            case (rs_entry.multfunc)
                M_MUL:  out = "M_MUL";
                M_MULH: out = "M_MULH";
                M_MULHSU: out = "M_MULSHU";
                M_MULHU: out = "M_MULHU";
                // here to prevent latches:
                default:  out = "null";
            endcase
        end else if(rs_entry.condbr) begin
            case (rs_entry.branchfunc)
                3'b000:  out = "BEQ"; // BEQ
                3'b001:  out = "BNE"; // BNE
                3'b100:  out = "BLT"; // BLT
                3'b101:  out = "BGE"; // BGE
                3'b110:  out = "BLTU";// BLTU
                3'b111:  out = "BGEU";// BGEU
                default: out = "null";
            endcase
        end else if(rs_entry.uncondbr) begin
            case (rs_entry.uncond_branchfunc)
                1'b0:  out = "JALR"; 
                1'b1:  out = "JAL"; 
                default: out = "null";
            endcase
        end else if(rs_entry.uncondbr) begin
            case (rs_entry.uncond_branchfunc)
                1'b0:  out = "JALR"; 
                1'b1:  out = "JAL"; 
                default: out = "null";
            endcase
        end else if(rs_entry.rdmem)begin
            out = "Load";
        
        end else if(rs_entry.wrmem)begin
            out = "Store";
        
        end else begin
            case (rs_entry.alufunc)
                ALU_ADD:  out = "ALU_ADD";
                ALU_SUB:  out = "ALU_SUB";
                ALU_AND:  out = "ALU_AND";
                ALU_SLT:  out = "ALU_SLT";
                ALU_SLTU: out = "ALU_SLTU";
                ALU_OR:   out = "ALU_OR";
                ALU_XOR:  out = "ALU_XOR";
                ALU_SRL:  out = "ALU_SRL";
                ALU_SLL:  out = "ALU_SLL";
                ALU_SRA:  out = "ALU_SRA"; // arithmetic from logical shift
                // here to prevent latches:
                default:  out = "null";
            endcase
        end

    endtask
    
    task print_rs_entry(input rs_entry rs_entry);
        string out;
        opcode_to_string(rs_entry,out);
        
        $display("\n |          %s           |          %b          |          %d          |          %d          |          %b          |          %d          |          %b           |        %h          |          %b          |          %b          |          %b          |          %h          | %b : %b |          %b          |",
        out,
        rs_entry.free,
        rs_entry.dest_reg,
        rs_entry.t1,
        rs_entry.t1_ready,
        rs_entry.t2,
        rs_entry.t2_ready,
        rs_entry.imm,
        rs_entry.imm_valid,
        rs_entry.condbr || rs_entry.uncondbr,
        rs_entry.load_dependencies,
        rs_entry.inst,
        rs_entry.lui,
        rs_entry.aui,
        rs_entry.dependent_stores_in_sq
        );
       
    endtask


    // define task to print issue reg contents
    task print_issue_reg();

        $display("\n ---------------- Issue Reg Contents ----------------");
        $display("\n |        opcode         |         free        |       dest_reg       |          T1          |       T1_ready      |       T2             |       T2_ready      |          imm          |      imm valid     |        branch        |   store dependencies  |          inst         |lui : aui|store dependencies free|");

        for(int i = 0; i < `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_BRANCH; i++) begin
            print_rs_entry(rs_output.issue_reg[i]);
            
        end
        $display("Issue_reg_valid entries: %b", rs_output.issue_valid);
        $display("aui1: %b aui2: %b aui3: %b",rs_output.issue_reg[1].aui,rs_output.issue_reg[2].aui,rs_output.issue_reg[3].aui);
        $display("lui1: %b lui2: %b lui3: %b",rs_output.issue_reg[1].lui,rs_output.issue_reg[2].lui,rs_output.issue_reg[3].lui);
    endtask

    // define task to print reservation station contents
    task print_res_station();
        
        $display("\nRS inputs: D1: %b, D2: %b, D3: %b, Dest1: %d, T1-1 %d, T2-1 %d, Dest2: %d, T1-2 %d, T2-2 %d, Dest3: %d, T1-3 %d, T2-3 %d, CBD1: %d, CBD1V: %b, CBD2: %d, CBD2V: %b, CBD3: %d, CBD3V: %b, BMR: %b, luis: %b %b %b, auis: %b %b %b",
        rs_input.dispatch1_valid,
        rs_input.dispatch2_valid,
        rs_input.dispatch3_valid,
        rs_input.dest_reg1,
        rs_input.inst1_T1,
        rs_input.inst1_T2,
        rs_input.dest_reg2,
        rs_input.inst2_T1,
        rs_input.inst2_T2,
        rs_input.dest_reg3,
        rs_input.inst3_T1,
        rs_input.inst3_T2,
        rs_input.cdb_tag1,
        rs_input.cdb_valid1,
        rs_input.cdb_tag2,
        rs_input.cdb_valid2,
        rs_input.cdb_tag3,
        rs_input.cdb_valid3,
        rs_input.branch_misspredict_retired,
        rs_input.lui1,
        rs_input.lui2,
        rs_input.lui3,
        rs_input.aui1,
        rs_input.aui2,
        rs_input.aui3
        );
        $display("\n ---------------- Reservation Station Contents ----------------");
        $display("\n |        opcode         |         free        |       dest_reg       |          T1          |       T1_ready      |       T2             |       T2_ready      |          imm          |      imm valid     |        branch        |   store dependencies  |          inst         | lui : aui|store dependencies free|");

        for(int i = 0; i < `RS_SZ; i++) begin
            print_rs_entry(rs[i]);
        end
        
        $display("\nRS outputs: Openspots: %d, freeTag1_taken: %b, freeTag2_taken: %b, freeTag3_taken: %b, issuevalid: %b, store_leave_t1: %d, store_leave_t2: %d, store_spot_leave: %d,",
        rs_output.openSpots,
        rs_output.freeTag1_taken,
        rs_output.freeTag2_taken,
        rs_output.freeTag3_taken,
        rs_output.issue_valid,
        rs_output.store_leave_t1,
        rs_output.store_leave_t2,
        rs_output.store_spot_leave);
    endtask
    logic[31:0] count;
    always @(negedge clock) begin
        if(reset) begin
                count <= 0;
            end else begin
                count <= count+1;
            end
        $display("\n____________RS Debug Output____________");
        $display("cycle: %d",count);
        print_res_station();
        print_issue_reg();
        $display("\n_____________End RS Output_____________");
    end
`endif
//create and issue data structure that only holds 3 instructions ready to issue
//Use the priority selector to find what is ready to multiply/add
//

always_comb begin
    new_rs = rs;
    mult = '0;
    adders = '0;
    branch = '0;
    store = '0;
    load = '0;
    total_gnt = '0;
    mult_gnt_wire = mult_gnt;
    adder_gnt_wire = adder_gnt;
    branch_gnt_wire = branch_gnt;
    store_gnt_wire = store_gnt;
    load_gnt_wire = load_gnt;

    //$monitor("branch gnt: %b", branch_gnt);
    new_openSpots = openSpots;
    new_issue_reg = rs_output.issue_reg;
    issue_valid = '0;
    rs_output.freeTag1_taken = 0;
    rs_output.freeTag2_taken = 0;
    rs_output.freeTag3_taken = 0;
    new_free_spots = free_spots;
    next_store_leave_t1 = '0;
    next_store_leave_t2 = '0;
    next_store_spot_leave = '0;

    dispatch1 = 0;
    dispatch2 = 0;
    dispatch3 = 0;
   // $display("Gnt Bus: ", free_spots_gnt_bus);
    //Marks existing source register as ready

   
    for(int i = 0; i < RS_SIZE; i++) begin
        if(~rs[i].free)begin
            if((rs[i].t1 == rs_input.cdb_tag1 && rs_input.cdb_valid1)||
            (rs[i].t1 == rs_input.cdb_tag2 && rs_input.cdb_valid2) ||
            (rs[i].t1 == rs_input.cdb_tag3 && rs_input.cdb_valid3))begin
                new_rs[i].t1_ready = 1;
            end
            if(((rs[i].t2 == rs_input.cdb_tag1 && rs_input.cdb_valid1)||
            (rs[i].t2 == rs_input.cdb_tag2 && rs_input.cdb_valid2) ||
            (rs[i].t2 == rs_input.cdb_tag3 && rs_input.cdb_valid3))
            && (!new_rs[i].imm_valid || new_rs[i].wrmem || new_rs[i].condbr)) begin
                new_rs[i].t2_ready = 1;
            end

            if(rs[i].rdmem && rs_input.sq_spot_ready_valid) begin
                new_rs[i].load_dependencies[rs_input.sq_spot_ready] = 1;
            end

            if(rs[i].rdmem) begin
                new_rs[i].dependent_stores_in_sq |= rs_input.dependent_stores_in_sq;
            end

            if(new_rs[i].t1_ready && new_rs[i].rdmem && new_rs[i].load_dependencies == '1)begin
               // $display("cool");
                load[i] = 1;
            end else if(new_rs[i].t1_ready && new_rs[i].t2_ready && new_rs[i].wrmem)begin
                store[i] = 1;
            end else if(new_rs[i].t1_ready && new_rs[i].t2_ready && new_rs[i].mult)begin
                mult[i] = 1;
            end else if (new_rs[i].t1_ready && ((new_rs[i].t2_ready && new_rs[i].imm_valid && new_rs[i].condbr) || (new_rs[i].uncondbr && new_rs[i].imm_valid)))begin
                branch[i] = 1;
            end else if(new_rs[i].t1_ready && (new_rs[i].t2_ready || new_rs[i].imm_valid) && !new_rs[i].wrmem && !new_rs[i].rdmem && !new_rs[i].uncondbr && !new_rs[i].condbr && !new_rs[i].mult)begin
                //$display("adders: %b", adders);
                //$display("i: %d",i);
                adders[i] = 1;
            end


        end
    end

    //$display("adders: %b", adders);


    //Multipliers
    issue_valid = rs_input.leftover_issues_from_execute;
    for(int i = 0; i < `NUM_FU_MULT; i++)begin
        for(int z = 0; z < RS_SIZE; z++) begin
            if(mult_gnt_wire[z])begin
                if(!issue_valid[i]) begin
                    issue_valid[i] = 1;
                    new_issue_reg[i] = new_rs[z];
                    new_rs[z].free = 1;
                    new_free_spots[z] = 1;
                    mult_gnt_wire[z] = 0;
                    new_openSpots++;
                    break;
                    //$display("Z: %d", z);
                end
            end
        end
    end

 
    //Adders
    for(int i = `NUM_FU_MULT; i < `NUM_FU_MULT + `NUM_FU_ALU ; i++)begin
        for(int z = 0; z < RS_SIZE; z++) begin
            //$display("adder_gnt_wire: %b", adder_gnt_wire);
            if(adder_gnt_wire[z])begin
                //$display("add");
                if(!issue_valid[i]) begin
                    new_issue_reg[i] = new_rs[z];
                    issue_valid[i] = 1;
                    new_rs[z].free = 1;
                    new_free_spots[z] = 1;
                    adder_gnt_wire[z] = 0;
                    new_openSpots++;
                    break;
                end                
            end
        end
    end
    
    //Branches
    //$display("branch_gnt: %b", branch_gnt);
    for(int i = `NUM_FU_MULT + `NUM_FU_ALU + `NUM_FU_LOAD + `NUM_FU_STORE; i < `NUM_FU_MULT + `NUM_FU_ALU + `NUM_FU_LOAD + `NUM_FU_STORE + `NUM_FU_BRANCH; i++)begin
        for(int z = 0; z < RS_SIZE; z++) begin
            if(branch_gnt_wire[z])begin
                if(!issue_valid[i]) begin
                    new_issue_reg[i] = new_rs[z];
                    issue_valid[i] = 1;
                    new_rs[z].free = 1;
                    new_free_spots[z] = 1;
                    branch_gnt_wire[z] = 0;
                    new_openSpots++;
                    break;
                end                
            end
        end
    end

    // Load
    for(int i = `NUM_FU_MULT + `NUM_FU_ALU; i < `NUM_FU_MULT + `NUM_FU_ALU + `NUM_FU_LOAD; i++)begin
        for(int z = 0; z < RS_SIZE; z++) begin
            if(load_gnt_wire[z])begin
                if(!issue_valid[i]) begin
                    new_issue_reg[i] = new_rs[z];
                    issue_valid[i] = 1;
                    new_rs[z].free = 1;
                    new_free_spots[z] = 1;
                    load_gnt_wire[z] = 0;
                    new_openSpots++;
                    break;
                end                
            end
        end
    end

    // Store
    for(int i = `NUM_FU_MULT + `NUM_FU_ALU + `NUM_FU_LOAD; i < `NUM_FU_MULT + `NUM_FU_ALU + `NUM_FU_LOAD + `NUM_FU_STORE; i++)begin
        for(int z = 0; z < RS_SIZE; z++) begin
            if(store_gnt_wire[z])begin
                if(!issue_valid[i]) begin
                    new_issue_reg[i] = new_rs[z];
                    next_store_leave_t1 = new_issue_reg[i].t1;
                    next_store_leave_t2 = new_issue_reg[i].t2;
                    next_store_spot_leave = new_issue_reg[i].sq_spot;
                    issue_valid[i] = 1;
                    new_rs[z].free = 1;
                    new_free_spots[z] = 1;
                    store_gnt_wire[z] = 0;
                    new_openSpots++;
                    break;
                end                
            end
        end
    end


//Removing entries put into issue

    
    // $display("adder_gnt: %b", adder_gnt);
    // $display("mult_gnt: %b", mult_gnt);
    // $display("rs_input.leftover_issues_from_execute: %b", rs_input.leftover_issues_from_execute);

    
//    $display("total_gnt: %b", total_gnt);
//     for(int i = 0; i < RS_SIZE; i++) begin
//         if(total_gnt[i])begin
//             //$display("granted, leave RS");
//             new_rs[i].free = 1;
//             new_openSpots++;
//         end
//     end


//Decoders for free_spots_gnt_bus
for(int i = 0; i < RS_SIZE; i++)begin
    if(free_spots_gnt_bus[0][i])begin
        dispatch1 = i;
        break;
    end
end
for(int i = 0; i < RS_SIZE; i++)begin
    if(free_spots_gnt_bus[1][i])begin
        dispatch2 = i;
        break;
    end
end
for(int i = 0; i < RS_SIZE; i++)begin
    if(free_spots_gnt_bus[2][i])begin
        dispatch3 = i;
        break;
    end
end
rs_output.openSpots = new_openSpots;

//Inputs dispatched instruction into RS
    //new_valid_entries = '0;
    new_free_spots2 = new_free_spots;
    if(rs_input.dispatch1_valid && new_openSpots >= 1 && !rs_input.halt1 && !rs_input.archZeroReg1) begin
        //$display("1st");
        //for(int i = 0; i < RS_SIZE; i++)begin
            if(free_spots_gnt_bus[0]!=0)begin
                //$display("2nd");
                new_rs[dispatch1].inst = rs_input.inst1;
                new_rs[dispatch1].lui = rs_input.lui1;
                new_rs[dispatch1].aui = rs_input.aui1;
                new_rs[dispatch1].free = 0;
                new_rs[dispatch1].alufunc = rs_input.alufunc1;
                new_rs[dispatch1].mult = rs_input.mult1;
                new_rs[dispatch1].multfunc = rs_input.multfunc1;
                new_rs[dispatch1].rdmem = rs_input.rdmem1;
                new_rs[dispatch1].wrmem = rs_input.wrmem1;
                new_rs[dispatch1].sq_spot = rs_input.sq_spot1;
                new_rs[dispatch1].condbr = rs_input.condbr1;
                new_rs[dispatch1].uncondbr = rs_input.uncondbr1;
                new_rs[dispatch1].uncond_branchfunc = rs_input.uncond_branchfunc1;
                new_rs[dispatch1].branchfunc = rs_input.branchfunc1;
                new_rs[dispatch1].t1 = rs_input.inst1_T1;
                new_rs[dispatch1].PC = rs_input.PC1;
                new_rs[dispatch1].load_dependencies = rs_input.load_dependencies;
                new_rs[dispatch1].dependent_stores_in_sq = rs_input.dependent_stores_in_sq;
                //Checks if source reg is being broadcasted on CDB at same time as instruction dispatch
                if((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst1_T1) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst1_T1) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst1_T1))begin
                    new_rs[dispatch1].t1_ready = 1;
                end else begin
                    new_rs[dispatch1].t1_ready = rs_input.inst1_T1_ready;
                end
                new_rs[dispatch1].t2 = rs_input.inst1_T2;
                if(((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst1_T2) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst1_T2) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst1_T2))
                && !rs_input.imm1_valid) begin
                    new_rs[dispatch1].t2_ready = 1;
                end else begin
                    new_rs[dispatch1].t2_ready = rs_input.inst1_T2_ready;
                end
                new_rs[dispatch1].imm = rs_input.imm1;
                new_rs[dispatch1].imm_valid = rs_input.imm1_valid;
                new_rs[dispatch1].dest_reg = rs_input.dest_reg1;
                //new_valid_entries[0]= 1;
                rs_output.freeTag1_taken = 1;
                new_free_spots2[dispatch1] = 0;
                new_openSpots--;
                //$display("1st dispatch");
                //$display("T1: ", rs_input.inst1_T1);
                //break;
            end
        //end
    end

    if(rs_input.dispatch2_valid && new_openSpots >= 1 && !rs_input.halt2 && !rs_input.archZeroReg2) begin
        //for(int i = 0; i < RS_SIZE; i++)begin
            if(free_spots_gnt_bus[1]!= 0)begin
                new_rs[dispatch2].inst = rs_input.inst2;
                new_rs[dispatch2].lui = rs_input.lui2;
                new_rs[dispatch2].aui = rs_input.aui2;
                new_rs[dispatch2].free = 0;
                new_rs[dispatch2].alufunc = rs_input.alufunc2;
                new_rs[dispatch2].mult = rs_input.mult2;
                new_rs[dispatch2].multfunc = rs_input.multfunc2;
                new_rs[dispatch2].rdmem = rs_input.rdmem2;
                new_rs[dispatch2].wrmem = rs_input.wrmem2;
                if(rs_input.wrmem1) begin
                    new_rs[dispatch2].sq_spot = rs_input.sq_spot2;
                end else begin
                    new_rs[dispatch2].sq_spot = rs_input.sq_spot1;
                end
              
                new_rs[dispatch2].condbr = rs_input.condbr2;
                new_rs[dispatch2].uncondbr = rs_input.uncondbr2;
                new_rs[dispatch2].uncond_branchfunc = rs_input.uncond_branchfunc2;
                new_rs[dispatch2].branchfunc = rs_input.branchfunc2;
                new_rs[dispatch2].t1 = rs_input.inst2_T1;
                new_rs[dispatch2].PC = rs_input.PC2;
                new_rs[dispatch2].load_dependencies = rs_input.load_dependencies;
                new_rs[dispatch2].dependent_stores_in_sq = rs_input.dependent_stores_in_sq;
                if(rs_input.wrmem1) begin
                    new_rs[dispatch2].load_dependencies[new_rs[dispatch1].sq_spot] = 0;
                end
                
                if((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst2_T1) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst2_T1) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst2_T1))begin
                    new_rs[dispatch2].t1_ready = 1;
                end else begin
                    new_rs[dispatch2].t1_ready = rs_input.inst2_T1_ready;
                end
                new_rs[dispatch2].t2 = rs_input.inst2_T2;
                new_rs[dispatch2].t2 = rs_input.inst2_T2;
                if(((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst2_T2) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst2_T2) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst2_T2))
                && !rs_input.imm2_valid)begin
                    new_rs[dispatch2].t2_ready = 1;
                end else begin
                    new_rs[dispatch2].t2_ready = rs_input.inst2_T2_ready;
                end
                new_rs[dispatch2].imm = rs_input.imm2;
                new_rs[dispatch2].imm_valid = rs_input.imm2_valid;
                new_rs[dispatch2].dest_reg = rs_input.dest_reg2;
                //new_valid_entries[1] = 1;
                rs_output.freeTag2_taken = 1;
                new_free_spots2[dispatch2] = 0;
                new_openSpots--;
                //$display("2nd dispatch");
                //break;
            end
       // end
    end

    if(rs_input.dispatch3_valid && new_openSpots >= 1 && !rs_input.halt3 && !rs_input.archZeroReg3) begin
        //for(int i = 0; i < RS_SIZE; i++)begin
            if(free_spots_gnt_bus[2]!=0)begin
                new_rs[dispatch3].inst = rs_input.inst3;
                new_rs[dispatch3].lui = rs_input.lui3;
                new_rs[dispatch3].aui = rs_input.aui3;
                new_rs[dispatch3].free = 0;
                new_rs[dispatch3].alufunc = rs_input.alufunc3;
                new_rs[dispatch3].mult = rs_input.mult3;
                new_rs[dispatch3].multfunc = rs_input.multfunc3;
                new_rs[dispatch3].rdmem = rs_input.rdmem3;
                new_rs[dispatch3].wrmem = rs_input.wrmem3;
                new_rs[dispatch3].sq_spot = rs_input.sq_spot3;
                if(rs_input.wrmem1 && rs_input.wrmem2) begin
                    new_rs[dispatch3].sq_spot = rs_input.sq_spot3;
                end else if ((!rs_input.wrmem1 && rs_input.wrmem2) || (rs_input.wrmem1 && !rs_input.wrmem2) ) begin
                    new_rs[dispatch3].sq_spot = rs_input.sq_spot2;
                end else begin
                    new_rs[dispatch3].sq_spot = rs_input.sq_spot1;
                end
                new_rs[dispatch3].condbr = rs_input.condbr3;
                new_rs[dispatch3].uncondbr = rs_input.uncondbr3;
                new_rs[dispatch3].uncond_branchfunc = rs_input.uncond_branchfunc3;
                new_rs[dispatch3].branchfunc = rs_input.branchfunc3;
                new_rs[dispatch3].t1 = rs_input.inst3_T1;
                new_rs[dispatch3].PC = rs_input.PC3;
                new_rs[dispatch3].load_dependencies = rs_input.load_dependencies;
                new_rs[dispatch3].dependent_stores_in_sq = rs_input.dependent_stores_in_sq;
                if(rs_input.wrmem1) begin
                    new_rs[dispatch3].load_dependencies[new_rs[dispatch1].sq_spot] = 0;
                end
                if(rs_input.wrmem2) begin
                    new_rs[dispatch3].load_dependencies[new_rs[dispatch2].sq_spot] = 0;
                end
                if((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst3_T1) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst3_T1) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst3_T1))begin
                    new_rs[dispatch3].t1_ready = 1;
                end else begin
                    new_rs[dispatch3].t1_ready = rs_input.inst3_T1_ready;
                end
                new_rs[dispatch3].t2 = rs_input.inst3_T2;
                if(((rs_input.cdb_valid1 && rs_input.cdb_tag1 == rs_input.inst3_T2) || 
                (rs_input.cdb_valid2 && rs_input.cdb_tag2 == rs_input.inst3_T2) || 
                (rs_input.cdb_valid3 && rs_input.cdb_tag3 == rs_input.inst3_T2))
                && !rs_input.imm3_valid)begin
                    new_rs[dispatch3].t2_ready = 1;
                end else begin
                    new_rs[dispatch3].t2_ready = rs_input.inst3_T2_ready;
                end
                new_rs[dispatch3].imm = rs_input.imm3;
                new_rs[dispatch3].imm_valid = rs_input.imm3_valid;
                new_rs[dispatch3].dest_reg = rs_input.dest_reg3;
                //new_valid_entries[2] = 1;
                rs_output.freeTag3_taken = 1;
                new_free_spots2[dispatch3] = 0;
                new_openSpots--;
                //$display("3rd dispatch");
                //break;
            end
        //end
    end


end

// always_ff @(posedge rs_input.branch_misspredict_retired)begin
//     for(int i = 0; i < RS_SIZE; i++)begin
//             rs[i].inst <= '0;
//             rs[i].free <= 1;
//             rs[i].op <= NULL;
//             rs[i].t1 <= '0;
//             rs[i].t1_ready <= 0;
//             rs[i].t2 <= '0;
//             rs[i].t2_ready <= 0;
//             rs[i].imm <= '0;
//             rs[i].imm_valid <= 0;
//             rs[i].dest_reg <= '0;
//         end
//         for(int i = 0; i < RS_SIZE; i++)begin
//             rs_output.reservationStation[i].inst <= '0;
//             rs_output.reservationStation[i].free <= 1;
//             rs_output.reservationStation[i].op <= NULL;
//             rs_output.reservationStation[i].t1 <= '0;
//             rs_output.reservationStation[i].t1_ready <= 0;
//             rs_output.reservationStation[i].t2 <= '0;
//             rs_output.reservationStation[i].t2_ready <= 0;
//             rs_output.reservationStation[i].imm <= '0;
//             rs_output.reservationStation[i].imm_valid <= 0;
//             rs_output.reservationStation[i].dest_reg <= '0;
//         end
//         for(int i = 0; i < `NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT; i++)begin
//             rs_output.issue_reg[i].inst <= '0;
//             rs_output.issue_reg[i].free <= 1;
//             rs_output.issue_reg[i].op <= NULL;
//             rs_output.issue_reg[i].t1 <= '0;
//             rs_output.issue_reg[i].t1_ready <= 0;
//             rs_output.issue_reg[i].t2 <= '0;
//             rs_output.issue_reg[i].t2_ready <= 0;
//             rs_output.issue_reg[i].imm <= '0;
//             rs_output.issue_reg[i].imm_valid <= 0;
//             rs_output.issue_reg[i].dest_reg <= '0;
//         end
//         rs_output.openSpots <= RS_SIZE;
//         rs_output.free_spots <= '1;
// end

always_ff @(posedge clock)begin
    if(reset || rs_input.branch_misspredict_retired)begin
        for(int i = 0; i < RS_SIZE; i++)begin
            rs[i].inst <= '0;
            rs[i].free <= 1;
            rs[i].mult <= 0;
            rs[i].multfunc <= '0;
            rs[i].rdmem <= 0;
            rs[i].wrmem <= 0;
            rs[i].condbr <= 0;
            rs[i].uncondbr <= 0;
            rs[i].alufunc <= '0;
            rs[i].t1 <= '0;
            rs[i].t1_ready <= 0;
            rs[i].t2 <= '0;
            rs[i].t2_ready <= 0;
            rs[i].imm <= '0;
            rs[i].imm_valid <= 0;
            rs[i].dest_reg <= '0;
            rs[i].load_dependencies <= '0;
            rs[i].lui <= '0;
            rs[i].aui <= '0;
            rs[i].dependent_stores_in_sq <= '0;

        end
        for(int i = 0; i < RS_SIZE; i++)begin
            rs_output.reservationStation[i].inst <= '0;
            rs_output.reservationStation[i].free <= 1;
            rs_output.reservationStation[i].mult <= 0;
            rs_output.reservationStation[i].multfunc <= '0;
            rs_output.reservationStation[i].rdmem <= 0;
            rs_output.reservationStation[i].wrmem <= 0;
            rs_output.reservationStation[i].condbr <= 0;
            rs_output.reservationStation[i].uncondbr <= 0;
            rs_output.reservationStation[i].alufunc <= '0;
            rs_output.reservationStation[i].t1 <= '0;
            rs_output.reservationStation[i].t1_ready <= 0;
            rs_output.reservationStation[i].t2 <= '0;
            rs_output.reservationStation[i].t2_ready <= 0;
            rs_output.reservationStation[i].imm <= '0;
            rs_output.reservationStation[i].imm_valid <= 0;
            rs_output.reservationStation[i].dest_reg <= '0;
            rs_output.reservationStation[i].load_dependencies <= '0;
            rs_output.reservationStation[i].lui <= '0;
            rs_output.reservationStation[i].aui <= '0;
            rs_output.reservationStation[i].dependent_stores_in_sq <= '0;
        end
        for(int i = 0; i < `NUM_FU_BRANCH + `NUM_FU_STORE + `NUM_FU_LOAD + `NUM_FU_ALU + `NUM_FU_MULT ; i++)begin
            rs_output.issue_reg[i].inst <= '0;
            rs_output.issue_reg[i].free <= 1;
            rs_output.issue_reg[i].mult <= 0;
            rs_output.issue_reg[i].multfunc <= '0;
            rs_output.issue_reg[i].rdmem <= 0;
            rs_output.issue_reg[i].wrmem <= 0;
            rs_output.issue_reg[i].condbr <= 0;
            rs_output.issue_reg[i].uncondbr <= 0;
            rs_output.issue_reg[i].alufunc <= '0;
            rs_output.issue_reg[i].t1 <= '0;
            rs_output.issue_reg[i].t1_ready <= 0;
            rs_output.issue_reg[i].t2 <= '0;
            rs_output.issue_reg[i].t2_ready <= 0;
            rs_output.issue_reg[i].imm <= '0;
            rs_output.issue_reg[i].imm_valid <= 0;
            rs_output.issue_reg[i].dest_reg <= '0;
            rs_output.issue_reg[i].load_dependencies <= '0;
            rs_output.issue_reg[i].lui <= '0;
            rs_output.issue_reg[i].aui <= '0;
            rs_output.issue_reg[i].dependent_stores_in_sq <= '0;
        end
        openSpots <= RS_SIZE;
        free_spots <= '1;
        rs_output.issue_valid <= '0;
        rs_output.store_leave_t1 <= '0;
        rs_output.store_leave_t2 <= '0;
        rs_output.store_spot_leave <= '0;


    end else begin
        openSpots <= new_openSpots;
        rs_output.issue_reg <= new_issue_reg;
        rs_output.issue_valid <= issue_valid;
        rs <= new_rs;
        rs_output.reservationStation <= new_rs;
        free_spots <= new_free_spots2;
        rs_output.store_leave_t1 <= next_store_leave_t1;
        rs_output.store_leave_t2 <= next_store_leave_t2;
        rs_output.store_spot_leave <= next_store_spot_leave;

    

    end


end

endmodule