`include "sys_defs.svh"
//Identify Parameters
module ROB#(parameter ROB_SZ=4)(
    input rob_input rob_packet,
    input clock,
    input reset,
    output rob_output rob_out
);
    logic [4:0] head, new_head, head2, head3, head_db;
    logic [4:0] store_head2, store_head3;
    logic [4:0] tail, new_tail, tail_db;
    logic [5:0] new_open_spots, new_open_spots2, open_spots;

    rob_entry [ROB_SZ-1:0] cur_rob, newRob;
    logic [ROB_SZ-1:0] [`PHYS_REG_BITS - 1:0] new_misspredict_freelist;
    logic new_branch_misspredict_retired;
    logic [31:0] next_target_branch;
    logic [2:0] new_valid_entries;
    `ifdef DEBUG_FLAG
       task print_rob_entry(rob_entry rob);
        
        $display("\n |          %d           |          %d          |          %d          |          %b          |          %b          |          %b          |          %b          |          %d          |          %b          |          %h          |          %h          |          %b          |  ",
        rob.destReg,
        rob.oldReg,
        rob.archReg,
        rob.free,
        rob.retire,
        rob.taken,
        rob.mispredict,
        rob.branch_target,
        rob.halt,
        rob.inst,
        rob.PC,
        rob.store_retire
        );
        
           
    endtask
    task print_rob();
        
        $display("\nROB inputs: D1: %b, D2: %b, D3: %b, Halt1: %b, Halt2: %b, Halt3: %b, PhysReg1: %d, PhysReg2: %d, PhysReg3: %d, ArchReg1: %d, ArchReg2: %d, ArchReg3: %d, OldPhysReg1: %d, OldPhysReg2: %d, OldPhysReg3: %d, CDB1: %d, CDB1V: %b, CDB2: %d, CDB2V: %b, CDB3: %d, CDB3V: %b, BranchTag: %d, BranchTaken: %b, BranchValid: %b, BranchTarget: %h, Inst1: %h, Inst2: %h, Inst3: %h, PC1: %h, PC2: %h, PC3: %h, store_retire: %d, valid_store_retire: %b, cache_hit1: %b, cache_hit2: %b, cache_hit3: %b, store_tag1: %d, store_tag2: %d, store_tag3: %d",
        rob_packet.dispatch1_valid,
        rob_packet.dispatch2_valid,
        rob_packet.dispatch3_valid,
        rob_packet.halt1,
        rob_packet.halt2,
        rob_packet.halt3,
        rob_packet.physical_reg1,
        rob_packet.physical_reg2,
        rob_packet.physical_reg3,
        rob_packet.archReg1,
        rob_packet.archReg2,
        rob_packet.archReg3,
        rob_packet.physical_old_reg1,
        rob_packet.physical_old_reg2,
        rob_packet.physical_old_reg3,
        rob_packet.cdb_tag1,
        rob_packet.cdb_valid1,
        rob_packet.cdb_tag2,
        rob_packet.cdb_valid2,
        rob_packet.cdb_tag3,
        rob_packet.cdb_valid3,
        rob_packet.branch_unit_tag,
        rob_packet.branch_unit_taken,
        rob_packet.branch_valid,
        rob_packet.branch_target,
        rob_packet.inst1,
        rob_packet.inst2,
        rob_packet.inst3,
        rob_packet.PC1,
        rob_packet.PC2,
        rob_packet.PC3,
        rob_packet.store_retire,
        rob_packet.valid_store_retire,
        rob_packet.cache_hit1,
        rob_packet.cache_hit2,
        rob_packet.cache_hit3,
        rob_packet.store_tag1,
        rob_packet.store_tag2,
        rob_packet.store_tag3
        );

        $display("\n ---------------- Reorder Buffer Contents ----------------");
        $display("\n |       destReg        |         oldReg       |        archReg       |         free         |         retire       |         taken        |       mispredict     |    branch_target    |        halt         |        inst         |         PC          |");

        for(int i = 0; i < `ROB_SZ; i++) begin
            print_rob_entry(cur_rob[i]);
        end
        
        $display("\nROB outputs: OpenSpots: %d, ArchIndex1: %d, ArchTag1: %d, ArchIndex2: %d, ArchTag2: %d, ArchIndex3: %d, ArchTag3: %d, ValidDisp1: %b, ValidDisp2: %b, ValidDisp3: %b, ValidRetire1: %b, ValidRetire2: %b, ValidRetire3: %b, RetiringTold1: %d, RetiringTold2: %d, RetiringTold3: %d, Halt1: %b, Halt2: %b, Halt3: %b, FreeTag1Taken: %b, FreeTag2Taken: %b, FreeTag3Taken: %b, BranchMissRet1: %b, BranchMissRet2: %b, BranchMissRet3: %b, BranchTarget: %h, Inst1: %h, Inst2: %h, Inst3: %h, PC1: %h, PC2: %h, PC3: %h",
            rob_out.openSpots,
            rob_out.archIndex1,
            rob_out.archTag1,
            rob_out.archIndex2,
            rob_out.archTag2,
            rob_out.archIndex3,
            rob_out.archTag3,
            rob_out.valid_dispatch1,
            rob_out.valid_dispatch2,
            rob_out.valid_dispatch3,
            rob_out.valid_retire_1,
            rob_out.valid_retire_2,
            rob_out.valid_retire_3,
            rob_out.retiring_Told_1,
            rob_out.retiring_Told_2,
            rob_out.retiring_Told_3,
            rob_out.halt1,
            rob_out.halt2,
            rob_out.halt3,
            rob_out.freeTag1_taken,
            rob_out.freeTag2_taken,
            rob_out.freeTag3_taken,
            rob_out.branch_misspredict_retired1,
            rob_out.branch_misspredict_retired2,
            rob_out.branch_misspredict_retired3,
            rob_out.branch_target,
            rob_out.inst1,
            rob_out.inst2,
            rob_out.inst3,
            rob_out.PC1,
            rob_out.PC2,
            rob_out.PC3
        );

    endtask


        logic [31:0] count;
        //print out fetch state every cycle (just pc for now lol)
        always @(negedge clock) begin
            if(reset) begin
                count <= 0;
            end else begin
                count <=count+1;
            end
            $display("\n____________ROB Debug Output____________");
            $display("cycle: %d",count);
            print_rob();
            for(int i = 0; i < `ROB_SZ - 1; i++) begin
                for(int z = i + 1; z < `ROB_SZ; z++)begin
                    if((cur_rob[i].destReg == cur_rob[z].destReg) && ~cur_rob[i].free && ~cur_rob[z].free)begin
                        $display("\033[31m@Failed: %d in 2 dest reg spots\033[0m", cur_rob[i].destReg);
                        
                    end
                end
            end
            $display("\n_____________End ROB Output_____________");

        end
    `endif
    

    always_comb begin
        newRob = cur_rob;
        new_open_spots = open_spots;
        new_head = head;
        new_tail = tail;
        new_valid_entries = 0;
        rob_out.valid_retire_1 = 0;
        rob_out.retiring_Told_1 = '0;
        rob_out.valid_retire_2 = 0;
        rob_out.retiring_Told_2 = '0;
        rob_out.valid_retire_3 = 0;
        rob_out.retiring_Told_3 = '0;
        head2 = 0;
        head3 = 0;
        rob_out.freeTag1_taken = 0;
        rob_out.freeTag2_taken = 0;
        rob_out.freeTag3_taken = 0;
        new_branch_misspredict_retired = 0;
        next_target_branch = '0;
        rob_out.archIndex1 = '0;
        rob_out.archTag1 = '0;
        rob_out.archIndex2 = '0;
        rob_out.archTag2 = '0; 
        rob_out.archIndex3 = '0;
        rob_out.archTag3 = '0;
        rob_out.branch_misspredict_retired1 =  0;
        rob_out.branch_misspredict_retired2 =  0;
        rob_out.branch_misspredict_retired3 =  0;
        rob_out.branch_target = '0;
        rob_out.halt1 = 0;
        rob_out.halt2 = 0;
        rob_out.halt3 = 0;   
        rob_out.valid_dispatch1 = 0;
        rob_out.valid_dispatch2 = 0;
        rob_out.valid_dispatch3 = 0;
        rob_out.inst1 = '0;
        rob_out.inst2 = '0;
        rob_out.inst3 = '0;
        rob_out.PC1 = '0;
        rob_out.PC2 = '0;
        rob_out.PC3 = '0;
        rob_out.uncondbr1 = '0;
        rob_out.uncondbr2 = '0;
        rob_out.uncondbr3 = '0;

        rob_out.store_retire1 = 0;
        rob_out.store_retire2 = 0;
        rob_out.store_retire3 = 0;
        rob_out.store_retire_tag1 = '0;
        rob_out.store_retire_tag2 = '0;
        rob_out.store_retire_tag3 = '0;
        /*rob_out.predict_target = 0;
        rob_out.predict_take = 0;
        rob_out.predict_tag = 0;
        rob_out.predict_tag_valid = 0;*/


        //Marks instructions ready to retire
        for(int i = 0; i < ROB_SZ; i++)begin
            if(~cur_rob[i].free) begin
                if((rob_packet.cdb_valid1 && (cur_rob[i].destReg == rob_packet.cdb_tag1))|| (rob_packet.cdb_valid2 && (cur_rob[i].destReg == rob_packet.cdb_tag2)) || (rob_packet.cdb_valid3 && (cur_rob[i].destReg == rob_packet.cdb_tag3)))begin
                    //$display("i: %d", i);
                    newRob[i].retire = 1;
                end
                if((rob_packet.cache_hit1 && (cur_rob[i].destReg == rob_packet.store_tag1))|| (rob_packet.cache_hit2 && (cur_rob[i].destReg == rob_packet.store_tag2)) || (rob_packet.cache_hit3 && (cur_rob[i].destReg == rob_packet.store_tag3)))begin
                    //$display("i: %d", i);
                    newRob[i].retire = 1;
                end
                //Check Branch FU for miss prediction and mark instruction as mispredicted
                if((rob_packet.branch_unit_tag == cur_rob[i].destReg) && rob_packet.branch_valid)begin
                    if(rob_packet.branch_unit_taken != cur_rob[i].taken)begin
                        newRob[i].mispredict = 1;
                        newRob[i].branch_target = rob_packet.branch_target;
                    end
                    newRob[i].retire = 1;
                end 

                if(rob_packet.valid_store_retire && (rob_packet.store_retire == cur_rob[i].destReg))begin
                    newRob[i].store_retire = 1;

                end
            end
        end
        

        
        
        //$display("head: %d cur_rob[head]: %d", head, cur_rob[head].retire);
        //Allocates new head
        //$display("head %d", head );
        //$display("tail %d", tail );

        //$display("retire 1 %b", cur_rob[(head)%ROB_SZ].retire);
        // $display("retire 2 %b", cur_rob[(head+1)%ROB_SZ].retire);
        // $display("retire 3 %b", cur_rob[(head+2)%ROB_SZ].retire);

        if(!cur_rob[head].retire && cur_rob[head].store_retire && ~cur_rob[head].free )begin
            rob_out.store_retire1 = 1;
            rob_out.store_retire_tag1 = cur_rob[head].destReg;
            store_head2 = (head + 1) >= ROB_SZ ? (head + 1) - ROB_SZ : head + 1;
            if(!cur_rob[store_head2].retire && cur_rob[store_head2].store_retire && ~cur_rob[store_head2].free )begin
                rob_out.store_retire2 = 1;
                rob_out.store_retire_tag2 = cur_rob[store_head2].destReg;
                store_head3 = (head + 2) >= ROB_SZ ? head + 2 - ROB_SZ : head + 2;
                if(!cur_rob[store_head3].retire && cur_rob[store_head3].store_retire && ~cur_rob[store_head3].free )begin
                    rob_out.store_retire3 = 1;
                    rob_out.store_retire_tag3 = cur_rob[store_head3].destReg;
                end
            end
        end

        // Retiring instructions
        if(cur_rob[head].retire && ~cur_rob[head].free )begin
            //$display("1st if");
            //If the head is a misprediction
            rob_out.valid_retire_1 = 1;
            rob_out.retiring_Told_1 = cur_rob[head].oldReg;
            rob_out.archIndex1 = cur_rob[head].archReg;
            rob_out.archTag1 = cur_rob[head].destReg;
            rob_out.halt1 = cur_rob[head].halt;
            rob_out.inst1 = cur_rob[head].inst;
            rob_out.PC1 = cur_rob[head].PC;
            rob_out.uncondbr1 = cur_rob[head].uncondbr;
            newRob[head].free = 1;

            if(cur_rob[head].mispredict)begin
                for(int i = 0; i < ROB_SZ; i++)begin
                    //Mark every element as free
                    newRob[i].free = 1;
                    //Add all valid dest regs to an array to be returned to free list
                    // if(~cur_rob[i].free)begin
                    //     new_misspredict_freelist[i] = cur_rob[i].destReg;
                    // end
                end
                //Set head and tail to zero
                new_head = 0;
                new_tail = 0;
                //Make open spots equal to rob size
                new_open_spots = ROB_SZ;
                rob_out.branch_misspredict_retired1 =  1; 
                new_branch_misspredict_retired = 1;
                rob_out.branch_target = cur_rob[head].branch_target;
            end else begin
                new_head = (head + 1) >= ROB_SZ ? head + 1 - ROB_SZ : head + 1;
                newRob[head].free = 1;
                new_open_spots++;
                head2 = (head + 1) >= ROB_SZ ? (head + 1) - ROB_SZ : head + 1;
            end

            
            if(cur_rob[head2].retire && ~cur_rob[head2].free && !new_branch_misspredict_retired)begin
                //$display("2nd if");
                rob_out.valid_retire_2 = 1;
                rob_out.retiring_Told_2 = cur_rob[head2].oldReg;
                rob_out.archIndex2 = cur_rob[head2].archReg;
                rob_out.archTag2 = cur_rob[head2].destReg;
                rob_out.halt2 = cur_rob[head2].halt;
                rob_out.inst2 = cur_rob[head2].inst;
                rob_out.PC2 = cur_rob[head2].PC;
                rob_out.uncondbr2 = cur_rob[head2].uncondbr;
                newRob[head2].free = 1;
                if(cur_rob[head2].mispredict)begin
                   for(int i = 0; i < ROB_SZ; i++)begin
                        newRob[i].free = 1;
                        // if(~cur_rob[i].free)begin
                        //     new_misspredict_freelist[i] = cur_rob[i].destReg;
                        // end
                    end
                    new_head = 0;
                    new_tail = 0;
                    new_open_spots = ROB_SZ;
                    rob_out.branch_misspredict_retired2 =  1;
                    new_branch_misspredict_retired = 1;
                    rob_out.branch_target = cur_rob[head2].branch_target;
                end else begin
                
                    new_head = (head + 2) >= ROB_SZ ? head + 2 - ROB_SZ : head + 2;
                    newRob[head2].free = 1;
                   
                    new_open_spots++;
                    head3 = (head + 2) >= ROB_SZ ? head + 2 - ROB_SZ : head + 2;
                end

                if(cur_rob[head3].retire && ~cur_rob[head3].free && !new_branch_misspredict_retired)begin
                    //$display("3rd if");
                    rob_out.valid_retire_3 = 1;
                    rob_out.retiring_Told_3 = cur_rob[head3].oldReg;
                    rob_out.archIndex3 = cur_rob[head3].archReg;
                    rob_out.archTag3 = cur_rob[head3].destReg;
                    rob_out.halt3 = cur_rob[head3].halt;
                    rob_out.inst3 = cur_rob[head3].inst;
                    rob_out.PC3 = cur_rob[head3].PC;
                    rob_out.uncondbr3 = cur_rob[head3].uncondbr;
                    newRob[head3].free = 1;
                    if(cur_rob[head3].mispredict)begin
                        for(int i = 0; i < ROB_SZ; i++)begin
                            newRob[i].free = 1;
                            // if(~cur_rob[i].free)begin
                            //     new_misspredict_freelist[i] = cur_rob[i].destReg;
                            // end
                        end
                        new_head = 0;
                        new_tail = 0;
                        new_open_spots = ROB_SZ;
                        rob_out.branch_misspredict_retired3 =  1;
                        new_branch_misspredict_retired = 1;
                        rob_out.branch_target = cur_rob[head3].branch_target;
                    end else begin
                        new_head = (head + 3) >= ROB_SZ ? head + 3 - ROB_SZ : head + 3;
                        newRob[head3].free = 1;
                        new_open_spots++;
                        
                    end
                end
            end
        end
        
        new_open_spots2 = new_open_spots;
        rob_out.openSpots = new_open_spots;
        
    //allocates new tail
        if(rob_packet.dispatch1_valid && (new_open_spots >= 1) && !new_branch_misspredict_retired) begin
            newRob[new_tail].branch = rob_packet.branch1;
            newRob[new_tail].halt = rob_packet.halt1;
            if(newRob[new_tail].halt || (rob_packet.archReg1 == 0 && !rob_packet.wrmem1 && !rob_packet.branch1 && !rob_packet.uncondbr1))begin
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 1;
                newRob[new_tail].destReg = rob_packet.physical_reg1;
                newRob[new_tail].archReg = rob_packet.archReg1;
                newRob[new_tail].oldReg = rob_packet.physical_reg1;

            end else begin
                newRob[new_tail].destReg = rob_packet.physical_reg1;
                newRob[new_tail].oldReg = rob_packet.physical_old_reg1;
                newRob[new_tail].archReg = rob_packet.archReg1;
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 0;
                rob_out.freeTag1_taken = 1;
            end
            if(newRob[new_tail].branch || rob_packet.wrmem1 || (rob_packet.uncondbr1 && rob_packet.archReg1 == 0)) begin
                newRob[new_tail].oldReg = newRob[new_tail].destReg;
            end
            newRob[new_tail].taken = 0;
            newRob[new_tail].mispredict = 0;
            newRob[new_tail].branch_target = '0;
            newRob[new_tail].inst = rob_packet.inst1;
            newRob[new_tail].PC = rob_packet.PC1;
            newRob[new_tail].uncondbr = rob_packet.uncondbr1;
            newRob[new_tail].store_retire = 0;

            new_open_spots2--;
            new_tail = (new_tail + 1) >= ROB_SZ ? 0 : new_tail + 1;
            rob_out.valid_dispatch1 = 1;
            //new_valid_entries[0] = 1;
            

        end
        if(rob_packet.dispatch2_valid && (new_open_spots >= 2) && !new_branch_misspredict_retired) begin
            newRob[new_tail].branch = rob_packet.branch2;
            newRob[new_tail].halt = rob_packet.halt2;
            if(newRob[new_tail].halt || (rob_packet.archReg2 == 0 && !rob_packet.wrmem2 && !rob_packet.branch2 && !rob_packet.uncondbr2))begin
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 1;
                newRob[new_tail].destReg = rob_packet.physical_reg2;
                newRob[new_tail].archReg = rob_packet.archReg2;
                newRob[new_tail].oldReg = rob_packet.physical_reg2;
            end else begin
                newRob[new_tail].destReg = rob_packet.physical_reg2;
                newRob[new_tail].oldReg = rob_packet.physical_old_reg2;
                newRob[new_tail].archReg = rob_packet.archReg2;
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 0;
                rob_out.freeTag2_taken = 1;
            end
            if(newRob[new_tail].branch || rob_packet.wrmem2 || (rob_packet.uncondbr2 && rob_packet.archReg2 == 0)) begin
                newRob[new_tail].oldReg = newRob[new_tail].destReg;
            end
            newRob[new_tail].taken = 0;
            newRob[new_tail].mispredict = 0;
            newRob[new_tail].branch_target = '0;
            newRob[new_tail].inst = rob_packet.inst2;
            newRob[new_tail].PC = rob_packet.PC2;
            newRob[new_tail].uncondbr = rob_packet.uncondbr2;
            newRob[new_tail].store_retire = 0;

            new_open_spots2--;
            new_tail = (new_tail + 1) >= ROB_SZ ? 0 : new_tail + 1;
            rob_out.valid_dispatch2 = 1;
            //new_valid_entries[1] = 1;
            
        end
        if(rob_packet.dispatch3_valid && (new_open_spots >= 3) && !new_branch_misspredict_retired) begin
            newRob[new_tail].branch = rob_packet.branch3;
            newRob[new_tail].halt = rob_packet.halt3;
            if(newRob[new_tail].halt || (rob_packet.archReg3 == 0 && !rob_packet.wrmem3 && !rob_packet.branch3 && !rob_packet.uncondbr3))begin
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 1;
                newRob[new_tail].destReg = rob_packet.physical_reg3;
                newRob[new_tail].archReg = rob_packet.archReg3;
                newRob[new_tail].oldReg = rob_packet.physical_reg3;
            end else begin
                newRob[new_tail].destReg = rob_packet.physical_reg3;
                newRob[new_tail].oldReg = rob_packet.physical_old_reg3;
                newRob[new_tail].archReg = rob_packet.archReg3;
                newRob[new_tail].free = 0;
                newRob[new_tail].retire = 0;
                rob_out.freeTag3_taken = 1;
            end
            if(newRob[new_tail].branch || rob_packet.wrmem3 || (rob_packet.uncondbr3 && rob_packet.archReg3 == 0)) begin
                newRob[new_tail].oldReg = newRob[new_tail].destReg;
            end
            newRob[new_tail].taken = 0;
            newRob[new_tail].mispredict = 0;
            newRob[new_tail].branch_target = '0 ;  
            newRob[new_tail].inst = rob_packet.inst3; 
            newRob[new_tail].PC = rob_packet.PC3;
            newRob[new_tail].uncondbr = rob_packet.uncondbr3;
            newRob[new_tail].store_retire = 0;

            new_open_spots2--;
            new_tail = (new_tail + 1) >= ROB_SZ ? 0 : new_tail + 1;
            rob_out.valid_dispatch3 = 1;
            //new_valid_entries[2] = 1;
            
        end

    end

    always_ff @(posedge clock ) begin 
        //$display("\n phs1ret: %b", phys1ReturnFree);
        if(reset)begin
            for(int i = 0; i < ROB_SZ; i++)begin
                cur_rob[i].destReg <= '0;
                cur_rob[i].oldReg <= '0;
                cur_rob[i].archReg <= '0;
                cur_rob[i].free <= 1;
                cur_rob[i].retire <= 0;
                cur_rob[i].taken <= 0;
                cur_rob[i].mispredict <= 0;
                cur_rob[i].branch_target <= '0;
                cur_rob[i].halt <= 0;
                cur_rob[i].inst <= '0;
                cur_rob[i].PC <= '0;
                cur_rob[i].store_retire <= 0;
                //rob_out.misspredict_freelist[i] <= '0;
                rob_out.rob[i].destReg <= '0;
                rob_out.rob[i].oldReg <= '0;
                rob_out.rob[i].archReg <= '0;
                rob_out.rob[i].free <= 1;
                rob_out.rob[i].retire <= 0;
                rob_out.rob[i].taken <= 0;
                rob_out.rob[i].mispredict <= 0;
                rob_out.rob[i].branch_target <= '0;
                rob_out.rob[i].halt <= 0;
                rob_out.rob[i].inst <= '0;
                rob_out.rob[i].PC <= '0;
                rob_out.rob[i].store_retire <= 0;

            end
            head <= 0;
            tail <= 0;
            head_db <= '0;
            tail_db <= '0;
            open_spots <= ROB_SZ;
            // rob_out.branch_misspredict_retired <= 0;
            // rob_out.branch_target <= '0;
            // rob_out.freeTag1_taken <= 0;
            // rob_out.freeTag2_taken <= 0;
            // rob_out.freeTag3_taken <= 0;

            //$display("ROB size %d ", rob_out.openSpots);
        end else begin
            cur_rob <= newRob;
            open_spots <= new_open_spots2;
            head <= new_head;
            tail <= new_tail;
            //rob_out.misspredict_freelist <= new_misspredict_freelist;
            rob_out.rob <= newRob;
            head_db <= new_head;
            tail_db <= new_tail;



            // rob_out.branch_misspredict_retired <= new_branch_misspredict_retired;
            // rob_out.branch_target <= next_target_branch;
            

            // if(phys1ReturnFree)begin
            //     rob_out.valid_retire_1 <= 1;
            //     rob_out.retiring_Told_1 <= physTag1;
            //     //$display("\n phs1ret: %b", phys1ReturnFree);
            // end else begin
            //     rob_out.valid_retire_1 <= 0;
            //     rob_out.retiring_Told_1 <= 0;
            //     //$display("\n ~phs1ret");
            // end

            // if(phys2ReturnFree)begin
            //     rob_out.valid_retire_2 <= 1;
            //     rob_out.retiring_Told_2 <= physTag2;
            // end else begin
            //     rob_out.valid_retire_2 <= 0;
            //     rob_out.retiring_Told_2 <= 0;
            // end
            // if(phys3ReturnFree)begin
            //     rob_out.valid_retire_3 <= 1;
            //     rob_out.retiring_Told_3<= physTag3;
            // end else begin
            //     rob_out.valid_retire_3 <= 0;
            //     rob_out.retiring_Told_3 <= 0;
            // end


            // if(new_valid_entries[0])begin
            //     rob_out.freeTag1_taken <= 1;
            // end else begin
            //     rob_out.freeTag1_taken <= 0;
            // end
            // if(new_valid_entries[1])begin
            //     rob_out.freeTag2_taken <= 1;
            // end else begin
            //     rob_out.freeTag2_taken <= 0;
            // end
            // if(new_valid_entries[2])begin
            //     rob_out.freeTag3_taken <= 1;
            // end else begin
            //     rob_out.freeTag3_taken <= 0;
            // end
            



        end

    end

    `ifdef MISSPRED_CNT
        logic [64:0] misspredict_cnt;
        logic [64:0] br_cnt;
        always_ff@(negedge clock) begin
            if(reset) begin
                misspredict_cnt = '0;
                br_cnt = '0;
            end else begin
                if(rob_out.branch_misspredict_retired1||rob_out.branch_misspredict_retired2||rob_out.branch_misspredict_retired3) begin
                    misspredict_cnt ++;
                end
                if(cur_rob[head].retire && (cur_rob[head].branch || cur_rob[head].uncondbr)) begin
                    br_cnt ++;
                end
                if(cur_rob[(head + 1) % `ROB_SZ].retire && (cur_rob[(head + 1) % `ROB_SZ].branch || cur_rob[(head + 1) % `ROB_SZ].uncondbr)) begin
                    br_cnt ++;
                end
                if(cur_rob[(head + 2) % `ROB_SZ].retire && (cur_rob[(head + 2) % `ROB_SZ].branch || cur_rob[(head + 2) % `ROB_SZ].uncondbr)) begin
                    br_cnt ++;
                end
            end
            $display("\n num br: %d             num misspred: %d", br_cnt, misspredict_cnt );
        end
    `endif
   






endmodule

