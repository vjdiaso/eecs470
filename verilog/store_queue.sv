`include "sys_defs.svh"

module store_queue(
    input store_queue_input store_in,
    input logic clock,
    input logic reset,
    output store_queue_output store_out
);

logic [$clog2(`LSQ_SZ)-1:0] head, new_head, head2, head3, head_db, temp_head;
logic [$clog2(`LSQ_SZ)-1:0] tail, new_tail, tail_db, new_tail2;
logic [$clog2(`LSQ_SZ):0] new_open_spots, new_open_spots2, open_spots;
logic next_store_set_to_retire_valid;
logic [`PHYS_REG_BITS-1:0] next_store_set_to_retire; 
logic [$clog2(`LSQ_SZ):0] loop_counter;
logic [$clog2(`LSQ_SZ)-1:0] next_sq_spot_ready;
logic next_sq_spot_ready_valid;
store_queue_entry [`LSQ_SZ-1:0] store_queue, new_store_queue;
logic first_dependent_store;

`ifdef DEBUG_FLAG
    task print_store_queue();
    
        $display("\nStore Queue inputs: D1: %b, D2: %b, D3: %b, Dest1: %d, Dest2: %d, Dest3: %d, IMM1: %d, IMM2: %d, IMM3: %d, WR1: %b, WR2: %b, WR3: %b, Ret1: %b, Ret2: %b, Ret3: %b, Phys1: %d, Phys2: %d, Phys3: %d, Branch_mispredict: %b, LAddr: %h, LSize: %d, LValid: %b, SQSpot: %d, Reg1_DATA: %d, Reg2_DATA: %d, SQSpotValid: %b, cache_miss1: %b, cache_miss2: %b, cache_miss3: %b",
            store_in.dispatch1_valid,
            store_in.dispatch2_valid,
            store_in.dispatch3_valid,
            store_in.dest_tag1,
            store_in.dest_tag2,
            store_in.dest_tag3,
            store_in.imm1,
            store_in.imm2,
            store_in.imm3,
            store_in.wrmem1,
            store_in.wrmem2,
            store_in.wrmem3,
            store_in.valid_retire_1,
            store_in.valid_retire_2,
            store_in.valid_retire_3,
            store_in.physReg1,
            store_in.physReg2,
            store_in.physReg3,
            store_in.branch_mispredict,
            store_in.load_addr,
            store_in.load_size,
            store_in.load_valid,
            store_in.sq_spot,
            store_in.reg1_data,
            store_in.reg2_data,
            store_in.sq_spot_valid,
            store_in.cache_miss1,
            store_in.cache_miss2,
            store_in.cache_miss3
        );
        
        $display("\n =============================================================================   Store Queue Contents ================================================================================");
        $display("| h/t | Entry |        inst        |  free  |  store_size  |   dest_tag   |     T2_data      |     offset      |        PC        |     wr_addr      |   ready   | store_range_sz |");
        $display("|-----|-------|--------------------|--------|--------------|--------------|------------------|-----------------|------------------|------------------|-----------|----------------|");
        for (int i = 0; i < `LSQ_SZ; i++) begin

            if(i == store_out.head_debug && i != store_out.tail_debug) begin
                $write("|  h  ");
            end else if (i == store_out.tail_debug && i != store_out.head_debug)begin
                $write("|  t  ");
            end else if (i == store_out.head_debug && i == store_out.tail_debug) begin
                $write("| h/t ");
            end else begin
                $write("|     ");
            end

            $display("|   %2d  |      %h      |   %b    |      %s    |      %d      |     %h     |    %d   |     %h     |     %h     |     %b     |       %b       |",
                i,
                store_out.store_queue[i].inst,
                store_out.store_queue[i].free,
                store_out.store_queue[i].store_size == BYTE ? "BYTE" : (store_out.store_queue[i].store_size == HALF ? "HALF": (store_out.store_queue[i].store_size == WORD ? "WORD": "NULL")),
                store_out.store_queue[i].dest_tag,
                store_out.store_queue[i].t2_data,
                store_out.store_queue[i].offset,
                store_out.store_queue[i].PC,
                store_out.store_queue[i].wr_addr,
                store_out.store_queue[i].ready,
                store_out.store_queue[i].store_range_sz
            );
        end
        $display(" =========================================================================  End Store Queue Contents =============================================================================");

        $display("\nSQ Logic Outputs: OpenSpots: %d, PrevStoreQueueReadyBits: %b\nLoad Forwarding: load_valid: %b, load_data_fwd: %h, load_data_fwd_bytes_valid: %b\nRetirement Outputs: WrAddr1: %h, Data1: %h, ValidData1: %b, StoreSize1: %d\nWrAddr2: %h, Data2: %h, ValidData2: %b, StoreSize2: %d\nWrAddr3: %h, Data3: %h, ValidData3: %b, StoreSize3: %d\nInputs: SQ_SpotReady: %d, SQ_SpotReadyValid: %b, Tail1: %d, Tail2: %d, Tail3: %d\nRetirement Input: StoreSetToRetireValid: %b, StoreSetToRetire: %d",
            store_out.openSpots,
            store_out.prev_store_queue_ready_bits,
            store_out.load_valid,
            store_out.load_data_fwd,
            store_out.load_data_fwd_bytes_valid,
            store_out.wr_addr1,
            store_out.data1,
            store_out.valid_data1,
            store_out.store_size1,
            store_out.wr_addr2,
            store_out.data2,
            store_out.valid_data2,
            store_out.store_size2,
            store_out.wr_addr3,
            store_out.data3,
            store_out.valid_data3,
            store_out.store_size3,
            store_out.sq_spot_ready,
            store_out.sq_spot_ready_valid,
            store_out.tail1,
            store_out.tail2,
            store_out.tail3,
            store_out.store_set_to_retire_valid,
            store_out.store_set_to_retire
        );

    endtask

    logic[31:0] count;
    always @(negedge clock) begin 
        if(reset) begin
            count <= 0;
        end else begin
            count <= count+1;
        end
        $display("\n____________STORE QUEUE Debug Output____________");
        $display("cycle: %d",count);
        print_store_queue();
        $display("\n_____________STORE QUEUE Unit Output_____________");

    end

`endif 


always_comb begin

    new_open_spots = open_spots;
    new_head = head;
    new_tail = tail;
    new_store_queue = store_queue;
    store_out.wr_addr1 = '0;
    store_out.wr_addr2 = '0;
    store_out.wr_addr3 = '0;
    store_out.data1 = '0;
    store_out.data2 = '0;
    store_out.data3 = '0;
    store_out.valid_data1 = 0;
    store_out.valid_data2 = 0;
    store_out.valid_data3 = 0;
    store_out.store_size1 = '0;
    store_out.store_size2 = '0;
    store_out.store_size3 = '0;


    store_out.load_data_fwd = '0;
    store_out.load_data_fwd_bytes_valid = '0;

    store_out.cache_hit1 = '0;
    store_out.cache_hit2 = '0;
    store_out.cache_hit3 = '0;

    store_out.store_tag1 = '0;
    store_out.store_tag2 = '0;
    store_out.store_tag3 = '0;
   
    next_store_set_to_retire_valid = 0;
    next_store_set_to_retire = '0;
    store_out.prev_store_queue_ready_bits = '0;
    store_out.load_valid = 0;
    next_sq_spot_ready = '0;
    next_sq_spot_ready_valid = 0;
    first_dependent_store = 0;

   

    //Comes from reg file triggers by reservation station
    if((store_in.sq_spot_valid))begin
        new_store_queue[store_in.sq_spot].wr_addr = store_in.reg1_data + new_store_queue[store_in.sq_spot].offset;
        new_store_queue[store_in.sq_spot].t2_data = store_in.reg2_data;
        new_store_queue[store_in.sq_spot].ready = 1;
        next_store_set_to_retire = new_store_queue[store_in.sq_spot].dest_tag;
        next_store_set_to_retire_valid = 1;
        next_sq_spot_ready = store_in.sq_spot;
        next_sq_spot_ready_valid = 1;
    end
 
    for(int i = 0; i < `LSQ_SZ; i++)begin
        if(!new_store_queue[i].free)begin
            store_out.prev_store_queue_ready_bits[i] = new_store_queue[i].ready;    
        end else begin
            store_out.prev_store_queue_ready_bits[i] = 1;
        end
    end

    loop_counter = 0;
    temp_head = head;
    //Load forwarding
    if(store_in.load_valid)begin
        if(store_in.load_size == BYTE) begin
           // $display("LOAD_size to sq is BYTE");
            store_out.load_valid = 1;
            while(loop_counter != `LSQ_SZ)begin
                if(!store_in.store_queue_free_bits_out[temp_head] && !first_dependent_store)begin
                    first_dependent_store = 1;
                end

                if(store_in.store_queue_free_bits_out[temp_head] && first_dependent_store)begin
                    break;
                end
                
                if(store_queue[temp_head].store_size == BYTE && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 1
                    end
                end else if (store_queue[temp_head].store_size == HALF && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 2
                    end else if (store_in.load_addr == store_queue[temp_head].wr_addr + 1) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[15:8];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 3
                    end
                end else if (store_queue[temp_head].store_size == WORD && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 4
                    end else if (store_in.load_addr == store_queue[temp_head].wr_addr + 1) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[15:8];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 5
                    end else if (store_in.load_addr == store_queue[temp_head].wr_addr + 2) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[23:16];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 6
                    end else if (store_in.load_addr == store_queue[temp_head].wr_addr + 3) begin
                        store_out.load_data_fwd.byte_level[store_in.load_addr % 8] = store_queue[temp_head].t2_data[31:24];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 7
                    end
                end
                loop_counter++;
                temp_head = (temp_head + 1) % `LSQ_SZ;
            end
        end else if(store_in.load_size == HALF) begin
           // $display("LOAD_size to sq is HALF");
            store_out.load_valid = 1;
            while(loop_counter!=`LSQ_SZ)begin

                if(!store_in.store_queue_free_bits_out[temp_head] && !first_dependent_store)begin
                    first_dependent_store = 1;
                end

                if(store_in.store_queue_free_bits_out[temp_head] && first_dependent_store)begin
                    break;
                end
                
                if(store_queue[temp_head].store_size == BYTE && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 8
                    end else if(store_in.load_addr + 1 == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 9
                    end
                end else if (store_queue[temp_head].store_size == HALF && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                       // $display("t2 data from store_queue:", store_queue[temp_head].t2_data[15:0]);
                        //$display("load index in half level:", (store_in.load_addr % 8) /2);
                        store_out.load_data_fwd.half_level[(store_in.load_addr % 8) /2] = store_queue[temp_head].t2_data[15:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 10
                        store_out.load_data_fwd_bytes_valid[(store_in.load_addr + 1 )% 8] = 1; // case 11
                    end
                end else if (store_queue[temp_head].store_size == WORD && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.half_level[(store_in.load_addr % 8) / 2] = store_queue[temp_head].t2_data[15:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 12
                        store_out.load_data_fwd_bytes_valid[(store_in.load_addr + 1 )% 8] = 1; // case 13
                    end else if(store_in.load_addr == store_queue[temp_head].wr_addr + 2) begin
                        store_out.load_data_fwd.half_level[(store_in.load_addr % 8) / 2] = store_queue[temp_head].t2_data[31:16];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 14
                        store_out.load_data_fwd_bytes_valid[(store_in.load_addr + 1) % 8] = 1; // case 15
                    end
                end
                //$display("temp head: %d", temp_head);
                loop_counter++;
                temp_head = (temp_head + 1) % `LSQ_SZ;
                
            end
        end else if(store_in.load_size == WORD) begin
            //$display("LOAD_size to sq is WORD");
            store_out.load_valid = 1;
            while(loop_counter != `LSQ_SZ)begin
                
                
                if(!store_in.store_queue_free_bits_out[temp_head] && !first_dependent_store)begin
                    first_dependent_store = 1;
                end

                if(store_in.store_queue_free_bits_out[temp_head] && first_dependent_store)begin
                    break;
                end
                
                if(store_queue[temp_head].store_size == BYTE && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    //$display("WORD ADDRS BYTE");
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 16
                    end else if (store_in.load_addr + 1 == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 17
                    end else if (store_in.load_addr + 2 == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 18
                    end else if (store_in.load_addr + 3 == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.byte_level[store_queue[temp_head].wr_addr % 8] = store_queue[temp_head].t2_data[7:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 19
                    end
                end else if (store_queue[temp_head].store_size == HALF && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                   // $display("WORD ADDRS HALF");
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.half_level[(store_queue[temp_head].wr_addr % 8) / 2] = store_queue[temp_head].t2_data[15:0];
                        store_out.load_data_fwd_bytes_valid[store_queue[temp_head].wr_addr % 8] = 1; // case 20
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr + 1) % 8] = 1; // case 21
                    end else if(store_in.load_addr + 1 == store_queue[temp_head].wr_addr) begin
                        store_out.load_data_fwd.half_level[(store_queue[temp_head].wr_addr % 8) / 2] = store_queue[temp_head].t2_data[15:0];
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr) % 8] = 1; // case 22
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr + 1) % 8] = 1; // case 23
                    end
                end else if (store_queue[temp_head].store_size == WORD && store_queue[temp_head].ready && ~store_queue[temp_head].free) begin
                    if(store_in.load_addr == store_queue[temp_head].wr_addr) begin
                       // $display("WORD ADDRS MATCH");
                        store_out.load_data_fwd.word_level[(store_in.load_addr % 8) / 4] = store_queue[temp_head].t2_data[31:0];
                        store_out.load_data_fwd_bytes_valid[store_in.load_addr % 8] = 1; // case 24 
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr + 1) % 8] = 1; // case 25
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr + 2) % 8] = 1; // case 26
                        store_out.load_data_fwd_bytes_valid[(store_queue[temp_head].wr_addr + 3) % 8] = 1; // case 27
                        //$display("LOAD_FWD_BYTES: %b", store_out.load_data_fwd_bytes_valid);
                    end
                end
                loop_counter++;
                temp_head = (temp_head + 1) % `LSQ_SZ;
            end
        end
    end

    // cache request logic
    // if(store_queue[head].cache_requesting)begin
    //     store_out.wr_addr1 = store_queue[head].wr_addr;
    //     store_out.data1 = store_queue[head].t2_data;
    //     store_out.store_size1 = store_queue[head].store_size;
    //     store_out.valid_data1 = 1;
    //     if(store_queue[(head+1)%`LSQ_SZ].cache_requesting)begin
    //         if(store_queue[(head+2)%`LSQ].cache_requesting)begin
        
    //         end    
    //     end
    // end

     if(store_in.branch_mispredict)begin
        for(int i = 0; i < `LSQ_SZ; i++)begin
            new_store_queue[i].free = 1;
            new_store_queue[i].ready = 0;
        end
        //Set head and tail to zero
        new_head = 0;
        new_tail = 0;
        new_open_spots = `LSQ_SZ;

    //retire logic
    end else if(store_in.valid_retire_1 && store_queue[head].ready && store_queue[head].dest_tag == store_in.physReg1 && ~store_queue[head].free)begin
        
        store_out.wr_addr1 = store_queue[head].wr_addr;
        store_out.data1 = store_queue[head].t2_data;
        store_out.store_size1 = store_queue[head].store_size;
        store_out.valid_data1 = 1;
        //store_queue[head].cache_requesting = 1;
        if(!store_in.cache_miss1) begin
            new_head = (head + 1) >= `LSQ_SZ ? head + 1 - `LSQ_SZ : head + 1;
            new_store_queue[head].free = 1;
            new_store_queue[head].ready = 0;
            store_out.cache_hit1 = 1;
            store_out.store_tag1 = store_queue[head].dest_tag;
            //store_queue[head].cache_requesting = 0;
            new_open_spots++;
        end
        head2 = (head + 1) >= `LSQ_SZ ? (head + 1) - `LSQ_SZ : head + 1;

        if(store_in.valid_retire_2 && store_queue[head2].ready && store_queue[head2].dest_tag == store_in.physReg2 && ~store_queue[head2].free && ~store_in.branch_mispredict && !store_in.cache_miss1)begin

            store_out.wr_addr2 = store_queue[head2].wr_addr;
            store_out.data2 = store_queue[head2].t2_data;
            store_out.store_size2 = store_queue[head2].store_size;
            store_out.valid_data2 = 1;
            //store_queue[head2].cache_requesting = 1;
            if(!store_in.cache_miss2) begin
                new_head = (head + 2) >= `LSQ_SZ ? head + 2 - `LSQ_SZ : head + 2;
                new_open_spots++;
                new_store_queue[head2].free = 1;
                new_store_queue[head2].ready = 0;
                store_out.cache_hit2 = 1;
                store_out.store_tag2 = store_queue[head2].dest_tag;
                //store_queue[head2].cache_requesting = 0;
                
            end
            head3 = (head + 2) >= `LSQ_SZ ? (head + 2) - `LSQ_SZ : head + 2;
            

            if(store_in.valid_retire_3 && store_queue[head3].ready && store_queue[head3].dest_tag == store_in.physReg3 && ~store_queue[head3].free && ~store_in.branch_mispredict && !store_in.cache_miss1 && !store_in.cache_miss2)begin
                
                store_out.wr_addr3 = store_queue[head3].wr_addr;
                store_out.data3 = store_queue[head3].t2_data;
                store_out.store_size3 = store_queue[head3].store_size;
                store_out.valid_data3 = 1;
                //store_queue[head3].cache_requesting = 1;
                if(!store_in.cache_miss3) begin
                    new_head = (head + 3) >= `LSQ_SZ ? head + 3 - `LSQ_SZ : head + 3;
                    new_open_spots++;
                    new_store_queue[head3].free = 1;
                    new_store_queue[head3].ready = 0;
                    store_out.cache_hit3 = 1;
                    store_out.store_tag3 = store_queue[head3].dest_tag;
                    //store_queue[head3].cache_requesting = 0;
                end
                    
                
            end
        end

    end

    new_open_spots2 = new_open_spots;
    store_out.openSpots = new_open_spots;
    new_tail2 = new_tail;
    store_out.tail1 = new_tail2;
    store_out.tail2 = (new_tail2 + 1) % `LSQ_SZ;
    store_out.tail3 = (new_tail2 + 2) % `LSQ_SZ;

    for(int i = 0; i < `LSQ_SZ; i++)begin
        store_out.store_queue_free_bits[i] = new_store_queue[i].free;
            
    end

    //Go to RS for dispatch of lw


    //adding logic
    if(store_in.dispatch1_valid && (new_open_spots >= 1) && !store_in.branch_mispredict && store_in.wrmem1) begin
        //$display("-----------dispatch1-----------");
        new_store_queue[new_tail].dest_tag = store_in.dest_tag1;
        new_store_queue[new_tail].free = 0;    
        new_store_queue[new_tail].inst = store_in.inst1;
        new_store_queue[new_tail].PC = store_in.PC1;
        new_store_queue[new_tail].ready = 0;
        new_store_queue[new_tail].offset = store_in.imm1;
        new_store_queue[new_tail].store_size = MEM_SIZE'(store_in.inst1.r.funct3[1:0]);
        new_store_queue[new_tail].t2_data = '0;
        new_store_queue[new_tail].wr_addr = '0;
        if( new_store_queue[new_tail].store_size == BYTE) begin
            new_store_queue[new_tail].store_range_sz = 0;
        end else if( new_store_queue[new_tail].store_size == HALF) begin
            new_store_queue[new_tail].store_range_sz = 1;
        end else if( new_store_queue[new_tail].store_size == WORD) begin
            new_store_queue[new_tail].store_range_sz = 3;
        end

        if(store_in.dispatch2_valid && store_in.rdmem2 || store_in.dispatch3_valid && store_in.rdmem3)begin
            store_out.store_queue_free_bits[new_tail] = 0;
        end
        
        new_open_spots2--;
        new_tail = (new_tail + 1) >= `LSQ_SZ ? 0 : new_tail + 1;
    end 
    if(store_in.dispatch2_valid && (new_open_spots >= 2) && !store_in.branch_mispredict && store_in.wrmem2) begin
        //$display("-----------dispatch2-----------");
        new_store_queue[new_tail].dest_tag = store_in.dest_tag2;
        new_store_queue[new_tail].free = 0;    
        new_store_queue[new_tail].inst = store_in.inst2;
        new_store_queue[new_tail].PC = store_in.PC2;
        new_store_queue[new_tail].ready = 0;
        new_store_queue[new_tail].offset = store_in.imm2;
        new_store_queue[new_tail].store_size = MEM_SIZE'(store_in.inst2.r.funct3[1:0]);
        new_store_queue[new_tail].t2_data = '0;
        new_store_queue[new_tail].wr_addr = '0;

        if( new_store_queue[new_tail].store_size == BYTE) begin
            new_store_queue[new_tail].store_range_sz = 0;
        end else if( new_store_queue[new_tail].store_size == HALF) begin
            new_store_queue[new_tail].store_range_sz = 1;
        end else if( new_store_queue[new_tail].store_size == WORD) begin
            new_store_queue[new_tail].store_range_sz = 3;
        end
        
        if(store_in.dispatch3_valid && store_in.rdmem3)begin
            store_out.store_queue_free_bits[new_tail] = 0;
        end

        new_open_spots2--;
        new_tail = (new_tail + 1) >= `LSQ_SZ ? 0 : new_tail + 1;
    end 
    if(store_in.dispatch3_valid && (new_open_spots >= 3) && !store_in.branch_mispredict && store_in.wrmem3) begin
        //$display("-----------dispatch3-----------");
        new_store_queue[new_tail].dest_tag = store_in.dest_tag3;
        new_store_queue[new_tail].free = 0;    
        new_store_queue[new_tail].inst = store_in.inst3;
        new_store_queue[new_tail].PC = store_in.PC3;
        new_store_queue[new_tail].ready = 0;
        new_store_queue[new_tail].offset = store_in.imm3;
        new_store_queue[new_tail].store_size = MEM_SIZE'(store_in.inst3.r.funct3[1:0]);
        new_store_queue[new_tail].t2_data = '0;
        new_store_queue[new_tail].wr_addr = '0;
        
        if( new_store_queue[new_tail].store_size == BYTE) begin
            new_store_queue[new_tail].store_range_sz = 0;
        end else if( new_store_queue[new_tail].store_size == HALF) begin
            new_store_queue[new_tail].store_range_sz = 1;
        end else if( new_store_queue[new_tail].store_size == WORD) begin
            new_store_queue[new_tail].store_range_sz = 3;
        end
        new_open_spots2--;
        new_tail = (new_tail + 1) >= `LSQ_SZ ? 0 : new_tail + 1;
    end

    

end

always_ff @(posedge clock) begin
    if(reset) begin
        head <= '0;
        tail <= '0;
        open_spots <= `LSQ_SZ;
        store_out.store_set_to_retire_valid <= 0;
        store_out.store_set_to_retire <= '0;
        store_out.sq_spot_ready_valid <= 0;
        store_out.sq_spot_ready <= '0;
        for(int i = 0; i < `LSQ_SZ; i++) begin
            store_out.store_queue[i].inst <= 32'b0;
            store_out.store_queue[i].store_size <= '0;
            store_out.store_queue[i].dest_tag <= '0;
            store_out.store_queue[i].t2_data <= '0;
            store_out.store_queue[i].offset <= '0;
            store_out.store_queue[i].PC <= '0;
            store_out.store_queue[i].wr_addr <= 1'b0;
            store_out.store_queue[i].ready <= 1'b0;
            store_out.store_queue[i].store_range_sz <= 2'b0;
            store_out.store_queue[i].free <= 1;
            store_out.store_queue[i].cache_requesting <= 0;
        end
        for(int i = 0; i < `LSQ_SZ; i++) begin
            store_queue[i].inst <= 32'b0;
            store_queue[i].store_size <= '0;
            store_queue[i].dest_tag <= '0;
            store_queue[i].t2_data <= '0;
            store_queue[i].offset <= '0;
            store_queue[i].PC <= '0;
            store_queue[i].wr_addr <= 1'b0;
            store_queue[i].ready <= 1'b0;
            store_queue[i].store_range_sz <= 2'b0;
            store_queue[i].free <= 1;
            store_queue[i].cache_requesting <= 0;
        end
        
    end
    else begin
        tail <= new_tail;
        head <= new_head;
        store_out.head_debug <= new_head;
        store_out.tail_debug <= new_tail;
        //$display("HEAD: %d",head);
        store_queue <= new_store_queue;
        store_out.store_set_to_retire_valid <= next_store_set_to_retire_valid;
        store_out.store_set_to_retire <= next_store_set_to_retire;
        store_out.store_queue <= new_store_queue;
        open_spots <= new_open_spots2;
        store_out.sq_spot_ready <= next_sq_spot_ready;
        store_out.sq_spot_ready_valid <= next_sq_spot_ready_valid;
    end


end

endmodule