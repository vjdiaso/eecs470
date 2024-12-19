`include "sys_defs.svh"

module load_unit(
    input logic clock,
    input logic reset,
    input logic valid_load_from_store_queue, //Makes sure the data from store queue is valid
    input logic valid_load_from_issue_reg,
    input MEM_SIZE load_size,
    input MEM_BLOCK load_data_foward,// valid data from store queue
    input logic [7:0] load_data_fwd_bytes_valid,//valid bytes from store queue
    input ADDR PC,
    input logic [`PHYS_REG_BITS-1:0]dest_tag_in,
    input DATA t1,
    input DATA offset,
    input DATA data_from_cache,// whole word of data from data cache
    input logic cache_miss,
    input logic rd_unsigned,//get from inst.r.func3[2] in issue reg
    input logic cdb_taken,
    input logic [`LSQ_SZ-1:0] dependent_stores_in_sq,
    input logic branch_mispredict,



    output logic free,//input to left_over_issue_from_excute to keep load in issue reg
    output logic done,//to let cdb know this is a valid choice(sequential output to cdb)
    output DATA data_to_reg, //data written to regfile(sequential output to cdb)
    output logic [`PHYS_REG_BITS-1:0] dest_tag_out,//tag for regfile(sequential output to cdb)
    output ADDR load_addr,//address sent to store queue
    output ADDR load_addr_for_cache,//address sent to cache
    output logic load_valid,
    output logic load_addr_for_cache_valid,
    output logic [7:0] valid_bytes,
    output MEM_SIZE size,
    output MEM_SIZE size_to_load,
    output logic comb_free, 
    output logic cdb_taken_out,
    output logic [`LSQ_SZ-1:0] store_queue_free_bits_out
    

);

MEM_SIZE next_size;
DATA data, next_data; 
logic next_free, next_free2, cur_free;
logic next_load_valid, cur_load_valid;
logic [7:0] next_valid_bytes;
logic next_done, cur_unsigned, next_unsigned;
logic [`PHYS_REG_BITS-1:0] next_dest_tag;
logic [4:0] cache_offset;
ADDR next_addr, addr;
logic sq_done, next_sq_done;
logic first_load, next_first_load;
logic next_cdb_taken;

`ifdef DEBUG_FLAG
    task print_load_unit();
        $display("\nLoad_Unit inputs: reset: %b, valid_load_from_store_queue: %b, valid_load_from_issue_reg: %b, load_size: %s, load_data_foward: %h, load_data_foward_bytes_valid: %b,\n                 PC: %h, dest_tag_in: %d, t1: %h, offset: %h, data_from_cache: %h, cache_miss: %b, rd_unsigned: %b, cdb_taken: %b",
        reset,
        valid_load_from_store_queue, //Makes sure the data from store queue is valid
        valid_load_from_issue_reg,
        load_size == BYTE ? "BYTE" : load_size == HALF ? "HALF" : load_size == WORD ? "WORD" : "NULL" ,
        load_data_foward,// valid data from store queue
        load_data_fwd_bytes_valid,//valid bytes from store queue
        PC,
        dest_tag_in,
        t1,
        offset,
        data_from_cache,// whole word of data from data cache
        cache_miss,
        rd_unsigned,//get from inst.r.func3[2] in issue reg
        cdb_taken);

        $display("\n\nLoad_Unit contents: Data: %h, Dest_tag_out: %d, Valid_bytes: %b, Size: %s",
        data_to_reg,
        dest_tag_out,
        valid_bytes,
        size == BYTE ? "BYTE" : size == HALF ? "HALF" : size == WORD ? "WORD" : "NULL"
        );

        $display("\n\nLoad Unit Outputs: Free: %b, done: %b, load_addr: %h, load_size: %s, load_valid: %b, load_addr_for_cache: %h, , load_addr_for_cache_valid: %b, comnb_free: %b, first_load: %b, cdb_taken_out: %b",
        free,
        done,
        load_addr,
        size_to_load == BYTE ? "BYTE" : size_to_load == HALF ? "HALF" : size_to_load == WORD ? "WORD" : "NULL",
        load_valid,
        load_addr_for_cache,
        load_addr_for_cache_valid,
        comb_free,
        first_load,
        cdb_taken_out);

    endtask

   
    logic[31:0] count;
    always @(negedge clock) begin 
        if(reset) begin
            count <= 0;
        end else begin
            count <= count+1;
        end
        $display("\n____________LOAD UNIT Debug Output____________");
        $display("cycle: %d",count);
        print_load_unit();
        $display("\n_____________End LOAD Unit Output_____________");

    end

`endif


always_comb begin
    next_data = data;
    next_size = size;
    next_free = cur_free;
    load_valid = 0;
    load_addr = '0;
    next_dest_tag = dest_tag_out;
    next_addr = addr;
    next_valid_bytes = valid_bytes;
    next_done = done;
    next_unsigned = cur_unsigned;
    cache_offset = '0;
    load_addr_for_cache_valid = 0;
    load_addr_for_cache = '0;
    next_sq_done = sq_done;
    next_first_load = first_load;
    comb_free = 0;
    next_cdb_taken = cdb_taken_out;
    store_queue_free_bits_out = '0;
    size_to_load = '0;

    if(first_load) begin
        comb_free = 1;
    end
    

    if(cdb_taken)begin
        next_free = 1;
        //free = 1; //combinational output to let issue reg know it can send a load to the load unit
        next_done = 0;
        comb_free = 1;
        next_cdb_taken = 1;
    end 
    if(cdb_taken_out)begin
        comb_free = 1;
    end
    // else begin
    //     free = cur_free;
    // end
    next_free2 = next_free;
    
    //$display("next_free: ",next_free );
    //$display("cur_free: ",cur_free );
    

    
    //currently in load unit
    if(!cur_free && !done)begin
        load_addr_for_cache = addr;
        load_addr_for_cache_valid = 1;
    end
     if(!cache_miss)begin
        
        //$display("data from cache: %h", data_from_cache);
        cache_offset = (addr % 4);
        if(next_size == BYTE)begin
            if(valid_bytes == 0)begin
                if(cache_offset == 0)begin
                    next_data[7:0] = data_from_cache[7:0];
                end else if(cache_offset == 1)begin
                    next_data[7:0] = data_from_cache[15:8];
                end else if(cache_offset == 2)begin 
                    next_data[7:0] = data_from_cache[23:16];
                end else if(cache_offset == 3)begin
                    next_data[7:0] = data_from_cache[31:24];
                end
                
                next_valid_bytes[addr % 8] = 1;
            end
        end else if (next_size == HALF) begin
            if(!valid_bytes[(addr) % 8])begin
                
                if(cache_offset == 0)begin
                    //$display("cache_test0");
                    next_data[7:0] = data_from_cache[7:0];
                end else if(cache_offset == 2)begin
                    //$display("cache_test1");
                    //$display("next_valid_bytes: %b", next_valid_bytes);
                    next_data[7:0] = data_from_cache[23:16];
                end
                next_valid_bytes[addr % 8] = 1;
            end
            if(!valid_bytes[(addr + 1) % 8])begin
               // $display("cache_offset: ", cache_offset);
                
                if(cache_offset + 1 == 1)begin
                   // $display("cache_test2");
                    next_data[15:8] = data_from_cache[15:8];
                end else if(cache_offset + 1 == 3)begin
                   // $display("cache_test3");
                    next_data[15:8] = data_from_cache[31:24];
                end
                next_valid_bytes[(addr + 1) % 8] = 1;
            end
        end else if (next_size == WORD)begin
            if(!valid_bytes[(addr) % 8])begin
                next_data[7:0] = data_from_cache[7:0];
                next_valid_bytes[addr % 8] = 1;
            end
            if(!next_valid_bytes[(addr + 1) % 8])begin
                next_data[15:8] = data_from_cache[15:8];
                next_valid_bytes[(addr + 1) % 8] = 1;
            end
            if(!next_valid_bytes[(addr + 2) % 8])begin
                next_data[23:16] = data_from_cache[23:16];
                next_valid_bytes[(addr + 2) % 8] = 1;
            end
            if(!next_valid_bytes[(addr + 3) % 8])begin
                next_data[31:24] = data_from_cache[31:24];
                next_valid_bytes[(addr + 3) % 8] = 1;
            end
        end
    end 

    if(next_size == BYTE)begin
        if(next_valid_bytes != 0)begin
            if(next_unsigned)begin
                next_data[31:8] = '0;
            end else begin 
                //$display("signed");
                next_data[31:8] = {(24){next_data[7]}};
            end
            next_done = 1;
        end
    end else if (next_size == HALF) begin
        if(next_valid_bytes[(next_addr) % 8] && next_valid_bytes[(next_addr + 1) % 8])begin
            next_done = 1;
            if(next_unsigned)begin
                next_data[31:16] = '0;
            end else begin
                next_data [31:16] = {(16){next_data[15]}};
            end
        end
    end else if (next_size == WORD)begin
        if(next_valid_bytes[(next_addr ) % 8] && next_valid_bytes[(next_addr + 1) % 8] && next_valid_bytes[(next_addr + 2) % 8] && next_valid_bytes[(next_addr + 3) % 8])begin
            next_done = 1;
        end 
    end

    if(valid_load_from_issue_reg && cur_free) begin
        next_addr = offset + t1;
        //$display("addr: %d", addr);
        if(dependent_stores_in_sq != '1)begin
            load_addr = offset + t1;//output to store Queue
            //$display("load_addr: %d", load_addr);
            store_queue_free_bits_out = dependent_stores_in_sq;
            load_valid = 1;//output to store Queue
            size_to_load = load_size;
            next_sq_done = 0;
        end else begin
            load_addr_for_cache = offset + t1;;
            load_addr_for_cache_valid = 1;
            next_sq_done = 1;
            next_valid_bytes = '0;
        end
        next_free = 0;
        next_size = load_size;
        next_dest_tag = dest_tag_in;
        next_done = 0;
        next_unsigned = rd_unsigned;
        next_data = '0; 
        //free = 0; 
        
        
        next_first_load = 0;
        comb_free = 0;
        next_cdb_taken = 0;

        if(valid_load_from_store_queue && cur_free)begin
            next_first_load = 0;
            comb_free = 0;
            next_cdb_taken = 0;
            //$display("store_queue inputs");
            next_valid_bytes = load_data_fwd_bytes_valid;
            //$display("next_valid_bytes before: %b", next_valid_bytes);
            if(next_size == BYTE)begin
                if(next_valid_bytes == 0)begin//If store has no info load needs
                    load_addr_for_cache = next_addr;
                    load_addr_for_cache_valid = 1;
                end else begin //If store has all the info the load needs
                    //$display("cool");
                    next_data[7:0] = load_data_foward.byte_level[(next_addr) % 8];
                end
            end else if(next_size == HALF) begin
                if(next_valid_bytes == 0)begin//If store has no info load needs
                    load_addr_for_cache = next_addr;
                    load_addr_for_cache_valid = 1;
                end else begin
                    if(next_valid_bytes[(next_addr) % 8])begin
                        next_data[7:0] = load_data_foward.byte_level[(next_addr) % 8];
                    end
                    if(next_valid_bytes[(next_addr + 1) % 8])begin
                        next_data[15:8] = load_data_foward.byte_level[(next_addr + 1) % 8];
                    end
                    // If the needs info from cache send a read request
                    if(!next_valid_bytes[(next_addr) % 8] || !next_valid_bytes[(next_addr + 1) % 8])begin
                        load_addr_for_cache = next_addr;
                        load_addr_for_cache_valid = 1;
                    end
                    
                end
            end else if(next_size == WORD) begin
                if(next_valid_bytes == 0)begin//If store has no info load needs
                    load_addr_for_cache = next_addr;
                    load_addr_for_cache_valid = 1;
                end else begin
                    if(next_valid_bytes[(next_addr) % 8])begin
                        next_data[7:0] = load_data_foward.byte_level[(next_addr) % 8];
                    end
                    if(next_valid_bytes[(next_addr + 1) % 8])begin
                        next_data[15:8] = load_data_foward.byte_level[(next_addr + 1) % 8];
                    end
                    if(next_valid_bytes[(next_addr + 2) % 8])begin
                        next_data[23:16] = load_data_foward.byte_level[(next_addr + 2) % 8];
                    end
                    if(next_valid_bytes[(next_addr + 3) % 8])begin
                        next_data[31:24] = load_data_foward.byte_level[(next_addr + 3) % 8];
                    end
                    // If the needs info from cache send a read request
                    if(!next_valid_bytes[(next_addr ) % 8] || !next_valid_bytes[(next_addr + 1) % 8] || !next_valid_bytes[(next_addr + 2) % 8] || !next_valid_bytes[(next_addr + 3) % 8])begin
                        load_addr_for_cache = next_addr;
                        load_addr_for_cache_valid = 1;
                    end 
                end
            end
            next_sq_done = 1;

        end

        if(!cache_miss && next_sq_done)begin
                
            //$display("data from cache: %h", data_from_cache);
            cache_offset = (next_addr % 4);
            if(next_size == BYTE)begin
                if(next_valid_bytes == 0)begin
                    if(cache_offset == 0)begin
                        next_data[7:0] = data_from_cache[7:0];
                    end else if(cache_offset == 1)begin
                        next_data[7:0] = data_from_cache[15:8];
                    end else if(cache_offset == 2)begin 
                        next_data[7:0] = data_from_cache[23:16];
                    end else if(cache_offset == 3)begin
                        next_data[7:0] = data_from_cache[31:24];
                    end
                    
                    next_valid_bytes[next_addr % 8] = 1;
                end
            end else if (next_size == HALF) begin
                if(!next_valid_bytes[(next_addr) % 8])begin
                    
                    if(cache_offset == 0)begin
                        //$display("cache_test0");
                        next_data[7:0] = data_from_cache[7:0];
                    end else if(cache_offset == 2)begin
                        //$display("cache_test1");
                       // $display("next_valid_bytes: %b", next_valid_bytes);
                        next_data[7:0] = data_from_cache[23:16];
                    end
                    next_valid_bytes[next_addr % 8] = 1;
                end
                if(!next_valid_bytes[(next_addr + 1) % 8])begin
                   // $display("cache_offset: ", cache_offset);
                    
                    if(cache_offset + 1 == 1)begin
                        //$display("cache_test2");
                        next_data[15:8] = data_from_cache[15:8];
                    end else if(cache_offset + 1 == 3)begin
                        //$display("cache_test3");
                        next_data[15:8] = data_from_cache[31:24];
                    end
                    next_valid_bytes[(next_addr + 1) % 8] = 1;
                end
            end else if (next_size == WORD)begin
                if(!next_valid_bytes[(next_addr) % 8])begin
                    next_data[7:0] = data_from_cache[7:0];
                    next_valid_bytes[next_addr % 8] = 1;
                end
                if(!next_valid_bytes[(next_addr + 1) % 8])begin
                    next_data[15:8] = data_from_cache[15:8];
                    next_valid_bytes[(next_addr + 1) % 8] = 1;
                end
                if(!next_valid_bytes[(next_addr + 2) % 8])begin
                    next_data[23:16] = data_from_cache[23:16];
                    next_valid_bytes[(next_addr + 2) % 8] = 1;
                end
                if(!next_valid_bytes[(next_addr + 3) % 8])begin
                    next_data[31:24] = data_from_cache[31:24];
                    next_valid_bytes[(next_addr + 3) % 8] = 1;
                end
            end
        end 

        if(next_size == BYTE)begin
            if(next_valid_bytes != 0)begin
                if(next_unsigned)begin
                    next_data[31:8] = '0;
                end else begin 
                    //$display("signed");
                    next_data[31:8] = {(24){next_data[7]}};
                end
                next_done = 1;
            end
        end else if (next_size == HALF) begin
            if(next_valid_bytes[(next_addr) % 8] && next_valid_bytes[(next_addr + 1) % 8])begin
                next_done = 1;
                if(next_unsigned)begin
                    next_data[31:16] = '0;
                end else begin
                    next_data [31:16] = {(16){next_data[15]}};
                end
            end
        end else if (next_size == WORD)begin
            if(next_valid_bytes[(next_addr ) % 8] && next_valid_bytes[(next_addr + 1) % 8] && next_valid_bytes[(next_addr + 2) % 8] && next_valid_bytes[(next_addr + 3) % 8])begin
                next_done = 1;
            end 
        end
        
    end

    //not in load unit
    
    // $display("cach raccess addr: %h", addr);
    // $display("cach raccess next_addr: %h", next_addr);
    // $display("cache miss in lu: %b",cache_miss);
   

    
   // $display("load_addr_for_cache: %h", load_addr_for_cache);

   
end

always_ff @(posedge clock) begin
    
    if(reset||branch_mispredict)begin
        data <= '0;
        size <= '0;
        cur_free <= 1;
        dest_tag_out <= '0;
        valid_bytes <= '0;
        done <= 0;
        data_to_reg <= '0;
        addr <= '0;
        cur_unsigned <= 0;
        sq_done <= 0;
        free <= 1;
        first_load <= 1;
        cdb_taken_out <= 0;

    end else begin
        data <= next_data;
        size <= next_size;
        cur_free <= next_free;
        dest_tag_out <= next_dest_tag;
        valid_bytes <= next_valid_bytes;
        done <= next_done;
        data_to_reg <= next_data;
        addr <= next_addr;
        cur_unsigned <= next_unsigned;
        sq_done <= next_sq_done;
        free <= next_free;
        first_load <= next_first_load;
        cdb_taken_out <= next_cdb_taken;
    end
end


endmodule
