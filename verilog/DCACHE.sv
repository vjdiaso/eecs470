
`include "sys_defs.svh"
`include "ISA.svh"


module DCACHE (
    input MEM_TAG MDB_tag, //watch to see if it matches any outstanding req
    input MEM_BLOCK MDB_data, //my req's data if tag match
    
    input MEM_TAG req_memtag,
    input logic req_sent,

    input logic wen1, // when true access 1 is processed as a store (false=load)
    input logic wen2,
    input logic wen3,

    input DATA wdata1, //data to be written at addr access1 if wen1
    input DATA wdata2,
    input DATA wdata3,

    input MEM_SIZE store_size1, //size of store
    input MEM_SIZE store_size2, //size of store
    input MEM_SIZE store_size3, //size of store

    input ADDR waccess1, //addr of cache w access 1
    input ADDR waccess2, //addr of cache w access 2
    input ADDR waccess3, //addr of cache w access 3

    input ADDR raccess, //addr
    input logic ren, 

    input logic clock, reset,

    output DATA rdata,  //32 bit data outputs, 

    output MEM_BLOCK wb, // mem block being written back
    output ADDR mem_request, // address of memory block we want if miss
    output MEM_COMMAND memcmd,
    output logic req_valid,
    output logic wmiss1, //high if miss at that pc
    output logic wmiss2, 
    output logic wmiss3,
    output logic rmiss,
    output DCACHE_ENTRY [`DCACHE_NUM_SETS-1:0] [`DCACHE_ASSOCIATIVITY-1:0] dcache_halt_dump
);

//add to sys defs
// define DCACHE_SIZE
// define DCACHE_ASSOCIAIIVITY

// struct DCACHE_ENTRY 

//      logic [7:0] lru_cnt;
//      logic waiting_for_mem;
//      MEM_BLOCK data;
//      logic empty;
//      MEM_TAG req_memtag;
//      logic [(28 - $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)) : 0] tag
//      logic dirty;


//Declarations
logic [16:0] num_sets;
assign num_sets = `DCACHE_NUM_SETS; // need to add these to sysdefs
logic [16:0] set_size;
assign set_size = `DCACHE_ASSOCIATIVITY;

logic [$clog2(`DCACHE_NUM_SETS) - 1 :0] set1, set2, set3, set4;
assign set1 = waccess1[$clog2(`DCACHE_NUM_SETS)+2:3];
assign set2 = waccess2[$clog2(`DCACHE_NUM_SETS)+2:3];
assign set3 = waccess3[$clog2(`DCACHE_NUM_SETS)+2:3];
assign set4 = raccess[$clog2(`DCACHE_NUM_SETS)+2:3];

logic [2:0] bo1, bo2, bo3, bo4;
assign bo1 = waccess1[2:0];
assign bo2 = waccess2[2:0];
assign bo3 = waccess3[2:0];
assign bo4 = raccess[2:0];



logic [(28 - $clog2(`DCACHE_NUM_SETS)) : 0] tag1, tag2, tag3, tag4; 
assign tag1 = waccess1[31 : $clog2(`DCACHE_NUM_SETS) + 3];
assign tag2 = waccess2[31 : $clog2(`DCACHE_NUM_SETS) + 3];
assign tag3 = waccess3[31 : $clog2(`DCACHE_NUM_SETS) + 3];
assign tag4 = raccess[31 : $clog2(`DCACHE_NUM_SETS) + 3];

DCACHE_ENTRY [`DCACHE_NUM_SETS-1:0] [`DCACHE_ASSOCIATIVITY-1:0] cache, cache_n; 
assign dcache_halt_dump = cache;

logic [$clog2(`DCACHE_ASSOCIATIVITY)-1:0] lru1, lru2, lru3, lru4, empty1_idx, empty2_idx, empty3_idx, empty4_idx;
logic empty1, empty2, empty3, empty4;
logic [7:0] max1, max2, max3, max4;

logic already_req1, already_req2, already_req3, already_req4;

logic dirtywb1, dirtywb2, dirtywb3, dirtywb4;
logic already_waiting1, already_waiting2, already_waiting3, already_waiting4;
ADDR dirtyaddr1, dirtyaddr2, dirtyaddr3, dirtyaddr4;


logic [$clog2(`DCACHE_NUM_SETS) - 1 :0] req_set;
logic [(28 - $clog2(`DCACHE_NUM_SETS)) : 0] req_tag;


assign req_set = mem_request[$clog2(`DCACHE_NUM_SETS)+2:3];
assign req_tag = mem_request[31 : $clog2(`DCACHE_NUM_SETS) + 3];


`ifdef DCACHE_FLAG
    always_ff@(negedge clock)begin
        $display("\nDcache contents========================");
        for(int i = 0; i<`DCACHE_NUM_SETS; i++) begin
            $display("\nSet %d", i);
            for(int j=0; j<`DCACHE_ASSOCIATIVITY; j++)begin
                $display("block %d: tag:%d data: %h waiting: %b memtag: %h lrucnt: %d dirty: %b, empty: %b, reset %b", j,cache[i][j].tag,cache[i][j].data, cache[i][j].waiting_for_mem, cache[i][j].req_memtag, cache[i][j].lru_cnt, cache[i][j].dirty, cache[i][j].empty, cache[i][j].reset);
            end
        end
        $display("\n sets : %d, %d, %d, %d",set1,set2,set3,set4);
        $display("\n tags : %d, %d, %d, %d",tag1,tag2,tag3,tag4);
        if(req_valid)begin
            if(memcmd == MEM_LOAD) begin
                $display("\n requesting load from addr %h from memory", mem_request);
            end else if(memcmd == MEM_STORE) begin
                $display("\n requesting store at addr %h in memory", mem_request);
            end

        end else begin
            $display("not requesting");
        end
        $display("\n store requesting at: %h, %h, %h, %h", waccess1, waccess2, waccess3, raccess);
        $display("already waiting : %b %b %b %b ", already_waiting1, already_waiting2, already_waiting3, already_waiting4);
        $display("empty idx : %d %d %d %d", empty1_idx, empty2_idx, empty3_idx, empty4_idx);
        $display("\n dirty wb: ",dirtywb1,dirtywb2,dirtywb3,dirtywb4);
        $display("misses 1 2 3 4 %b %b %b %b",wmiss1,wmiss2,wmiss3, rmiss);
        $display("wen1: %b, wen2: %b, wen3: %b, ren: %b",wen1,wen2,wen3,ren);
        $display("rdata: %h",rdata);
         if(req_sent) begin
            $display("req sent, tag %h",req_memtag);
        end else begin
            $display("req not sent, mem busy");
        end
        $display("MDB data: %h tag: %h", MDB_data, MDB_tag);
        $display("\nend Dcache========================");
    end
`endif
//Combinational
always_comb begin
    //$display("dcache requesting %h from mem", mem_request);
    cache_n = cache;
    wmiss1 = 1;
    wmiss2 = 1;
    wmiss3 = 1;
    rmiss = 1;
    memcmd = MEM_NONE;
    req_valid = 0;
    mem_request = 0;

    already_waiting1 = 0;
    already_waiting2 = 0;
    already_waiting3 = 0;
    already_waiting4 = 0;
    wb = '0;
    rdata = '0;


    //=================== check to see if accesses are misses or not ===================
    //iterate through corresponding set and look for match
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin // w access 1
        if((cache[set1][i].tag == tag1) && cache[set1][i].waiting_for_mem && wen1) begin
            already_waiting1 = 1;
            cache_n[set1][i].lru_cnt = 0;
            break;
        end
        if((cache[set1][i].tag == tag1) && !cache[set1][i].waiting_for_mem && !cache[set1][i].empty && wen1 && ~cache[set1][i].reset) begin
            wmiss1 = 0;
            cache_n[set1][i].lru_cnt = 0;
            cache_n[set1][i].dirty = 1;
            if(store_size1 == WORD) begin
                cache_n[set1][i].data.word_level[bo1[2]] = wdata1;
            end else if(store_size1 == HALF) begin
                cache_n[set1][i].data.half_level[bo1[2:1]] = wdata1[15:0];
            end else if(store_size1 == BYTE) begin
                cache_n[set1][i].data.byte_level[bo1] = wdata1[7:0];
            end
        end
        if(waccess1 >= `MEM_SIZE_IN_BYTES) begin //invalid request due to miss predict
            wmiss1 = 0;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin // w access 2
        if((cache[set2][i].tag == tag2) && cache[set2][i].waiting_for_mem && wen2) begin
            already_waiting2 = 1;
            cache_n[set2][i].lru_cnt = 0;
            break;
        end
        if((cache[set2][i].tag == tag2) && !cache[set2][i].waiting_for_mem && !cache[set2][i].empty && wen2 && ~cache[set2][i].reset) begin
            wmiss2 = 0;
            cache_n[set2][i].lru_cnt = 0;
            cache_n[set2][i].dirty = 1;
            if(store_size2 == WORD) begin
                cache_n[set2][i].data.word_level[bo2[2]] = wdata2;
            end else if(store_size2 == HALF) begin
                cache_n[set2][i].data.half_level[bo2[2:1]] = wdata2[15:0];
            end else if(store_size2 == BYTE) begin
                cache_n[set2][i].data.byte_level[bo2] = wdata2[7:0];
            end
        end
        if(waccess2 >= `MEM_SIZE_IN_BYTES) begin //invalid request due to miss predict
            wmiss2 = 0;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin // w access 3
        if((cache[set3][i].tag == tag3) && cache[set3][i].waiting_for_mem && wen3) begin
            already_waiting3 = 1;
            cache_n[set3][i].lru_cnt = 0;
            break;
        end
        if((cache[set3][i].tag == tag3) && !cache[set3][i].waiting_for_mem && !cache[set3][i].empty && wen3 && ~cache[set3][i].reset) begin
            wmiss3 = 0;
            cache_n[set3][i].lru_cnt = 0;
            cache_n[set3][i].dirty = 1;
            if(store_size3 == WORD) begin
                cache_n[set3][i].data.word_level[bo3[2]] = wdata3;
            end else if(store_size3 == HALF) begin
                cache_n[set3][i].data.half_level[bo3[2:1]] = wdata3[15:0];
            end else if(store_size3 == BYTE) begin
                cache_n[set3][i].data.byte_level[bo3] = wdata3[7:0];
            end
        end
        if(waccess3 >= `MEM_SIZE_IN_BYTES) begin //invalid request due to miss predict
            wmiss3 = 0;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin // r access 
        if((cache[set4][i].tag == tag4) && cache[set4][i].waiting_for_mem && ren) begin
            already_waiting4 = 1;
            break;
        end
        if((cache[set4][i].tag == tag4) && !cache[set4][i].waiting_for_mem && !cache[set4][i].empty && ren && ~cache[set4][i].reset) begin
            rmiss = 0;
            cache_n[set4][i].lru_cnt = 0;
            if(bo4[2]) begin
                rdata = cache[set4][i].data.word_level[1];
            end else begin
                rdata = cache[set4][i].data.word_level[0];
            end
        end
        if(raccess >= `MEM_SIZE_IN_BYTES) begin //invalid request due to miss predict
            rmiss = 0;
            rdata = 32'hfacebeef;
        end
    end
    

    //increment all lru counters
    for(int i = 0; i < `DCACHE_NUM_SETS; i++) begin
        for(int j = 0; j < `DCACHE_ASSOCIATIVITY; j++) begin
            if(!cache[i][j].empty) begin
                cache_n[i][j].lru_cnt++;
            end
        end
    end

    max1 = 0;
    max2 = 0;
    max3 = 0;
    max4 = 0;
    lru1 = 0;
    lru2 = 0;
    lru3 = 0;
    lru4 = 0;
    //If miss  
    //evict lru, put placeholder in it's place

    //find lru's
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set1][i].lru_cnt >= max1) begin
            lru1 = i;
            max1 = cache[set1][i].lru_cnt;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set2][i].lru_cnt >= max2) begin
            lru2 = i;
            max2 = cache[set2][i].lru_cnt;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set3][i].lru_cnt >= max3) begin
            lru3 = i;
            max3 = cache[set3][i].lru_cnt;
        end
    end

    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set4][i].lru_cnt >= max4) begin
            lru4 = i;
            max4 = cache[set4][i].lru_cnt;
        end
    end


    //find empties if there are any,
    empty1 = 0;
    empty2 = 0;
    empty3 = 0;
    empty4 = 0;
    empty1_idx = 0;
    empty2_idx = 0;
    empty3_idx = 0;
    empty4_idx = 0;
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set1][i].empty && ~cache[set1][i].waiting_for_mem) begin
            empty1 = 1;
            empty1_idx = i;
            break;
        end
    end
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set2][i].empty && ~cache[set2][i].waiting_for_mem) begin
            empty2 = 1;
            empty2_idx = i;
            break;
        end
    end
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set3][i].empty && ~cache[set3][i].waiting_for_mem) begin
            empty3 = 1;
            empty3_idx = i;
            break;
        end
    end
    for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
        if(cache[set4][i].empty && ~cache[set4][i].waiting_for_mem) begin
            empty4 = 1;
            empty4_idx = i;
            break;
        end
    end



    dirtywb1 = 0;
    dirtywb2 = 0;
    dirtywb3 = 0;
    dirtywb4 = 0;

    dirtyaddr1 = '0;
    dirtyaddr2 = '0;
    dirtyaddr3 = '0;
    dirtyaddr4 = '0;
    //evict lru's if there was a miss
    if(wmiss1 && wen1 && !already_waiting1) begin
        if(~empty1)begin
            dirtyaddr1 = {cache_n[set1][lru1].tag,set1,bo1};
            if(cache_n[set1][lru1].dirty) begin
                dirtywb1 =1;
            end
            cache_n[set1][lru1].tag = tag1;
            cache_n[set1][lru1].empty = 1;
            cache_n[set1][lru1].reset = 0;
        end else begin
            cache_n[set1][empty1_idx].tag = tag1;
            cache_n[set1][empty1_idx].reset = 0;
        end

    end else if(wmiss2 && wen2 && !already_waiting2) begin
        if(~empty2)begin
            dirtyaddr2 = {cache_n[set2][lru2].tag,set2,bo2};
            if(cache_n[set2][lru2].dirty) begin
                dirtywb2 =1;
            end
            cache_n[set2][lru2].tag = tag2;
            cache_n[set2][lru2].empty = 1;
            cache_n[set2][lru2].reset = 0;
        end else begin
            cache_n[set2][empty2_idx].tag = tag2;
            cache_n[set2][empty2_idx].reset = 0;
        end
        
    end else if(wmiss3 && wen3 && !already_waiting3) begin
        if(~empty3)begin
            dirtyaddr3 = {cache_n[set3][lru3].tag,set3,bo3};
            if(cache_n[set3][lru3].dirty) begin
                dirtywb3 =1;
            end
            cache_n[set3][lru3].tag = tag3;
            cache_n[set3][lru3].empty = 1;
            cache_n[set3][lru3].reset = 0;
        end else begin
            cache_n[set3][empty3_idx].tag = tag3;
            cache_n[set3][empty3_idx].reset = 0;
        end
        
    end else if(rmiss && ren && !already_waiting4) begin
        if(~empty4)begin
            dirtyaddr4 = {cache_n[set4][lru4].tag,set4,bo4};
            if(cache_n[set4][lru4].dirty) begin
                dirtywb4 =1;
            end
            cache_n[set4][lru4].tag = tag4;
            cache_n[set4][lru4].empty = 1;
            cache_n[set4][lru4].reset = 0;
        end else begin
            cache_n[set4][empty4_idx].tag = tag4;
            cache_n[set4][empty4_idx].reset = 0;
        end
        
    end

    //=================== send requests to memory ===================
    //NEW FOR DCACHE prioritize wb over requesting new blocks
    if(dirtywb1) begin
        //$display("in dwb1");
        mem_request = dirtyaddr1;
        memcmd = MEM_STORE;
        req_valid = 1;
        wb = cache_n[set1][lru1].data;
        cache_n[set1][lru1].dirty = 0;
    end else if (dirtywb2) begin
        mem_request = dirtyaddr2;
        memcmd = MEM_STORE;
        req_valid = 1;
        wb = cache_n[set2][lru2].data;
        cache_n[set2][lru2].dirty = 0;
    end else if (dirtywb3) begin
        mem_request = dirtyaddr3;
        memcmd = MEM_STORE;
        req_valid = 1;
        wb = cache_n[set3][lru3].data;
        cache_n[set3][lru3].dirty = 0;
    end else if (dirtywb4) begin
        mem_request = dirtyaddr4;
        memcmd = MEM_STORE;
        req_valid = 1;
        wb = cache_n[set4][lru4].data;
        cache_n[set4][lru4].dirty = 0;
    end
    //Prioritize oldest miss, send mem_request, put tag in placeholder
    already_req1 = 0;
    already_req2 = 0;
    already_req3 = 0;
    already_req4 = 0;

    //req_valid = wmiss1 || wmiss2 || wmiss3 || rmiss;
    
    //do not send a new requesst if there is already a request for that block

    if(!(dirtywb1||dirtywb2||dirtywb3||dirtywb4)) begin
        //$display("no dwb");
        if(wmiss1 && wen1 && !already_waiting1) begin
            for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
                if((cache[set1][i].tag == tag1) && cache[set1][i].waiting_for_mem) begin
                    already_req1 = 1;
                end
            end
            if(~already_req1) begin
                // if(~empty1)begin
                //     cache_n[set1][lru1].waiting_for_mem = 1;
                // end else begin
                //     cache_n[set1][empty1_idx].waiting_for_mem = 1;
                // end
                mem_request = waccess1;
                req_valid = 1;
                memcmd = MEM_LOAD;
    
            end
        end else if(wmiss2 && wen2 && !already_waiting2) begin
            for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
                if((cache[set2][i].tag == tag1) && cache[set2][i].waiting_for_mem) begin
                    already_req2 = 1;
                end
            end
            if(~already_req2) begin
                // if(~empty2)begin
                //     cache_n[set2][lru2].waiting_for_mem = 1;
                // end else begin
                //     cache_n[set2][empty2_idx].waiting_for_mem = 1;
                // end
                mem_request = waccess2;
                req_valid = 1;
                memcmd = MEM_LOAD;
                
            end
        end else if(wmiss3 && wen3 && !already_waiting3) begin
            for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
                if((cache[set3][i].tag == tag3) && cache[set3][i].waiting_for_mem) begin
                    already_req3 = 1;
                end
            end
            if(~already_req3) begin
                // if(~empty3)begin
                //     cache_n[set3][lru3].waiting_for_mem = 1;
                // end else begin
                //     cache_n[set3][empty3_idx].waiting_for_mem = 1;
                // end
                mem_request = waccess3;
                req_valid = 1;
                memcmd = MEM_LOAD;
               
            end
        end else if(rmiss && ren && !already_waiting4) begin
            for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++) begin
                if((cache[set4][i].tag == tag4) && cache[set4][i].waiting_for_mem) begin
                    already_req4 = 1;
                end
            end
            if(~already_req4) begin
                // if(~empty4)begin
                //     cache_n[set4][lru4].waiting_for_mem = 1;
                // end else begin
                //     cache_n[set4][empty4_idx].waiting_for_mem = 1;
                // end
                mem_request = raccess;
                req_valid = 1;
                memcmd = MEM_LOAD;
               
            end
        end
    end
    //=================== watch MDB ===================
    //If MDP_tag matches 
    
    for(int i = 0; i < `DCACHE_NUM_SETS; ++i) begin
        for(int j = 0; j < `DCACHE_ASSOCIATIVITY; ++j) begin
            if(cache[i][j].waiting_for_mem && (cache[i][j].req_memtag == MDB_tag) && (MDB_tag != 0)) begin
                //set value of placeholder to MDP data
                cache_n[i][j].waiting_for_mem = 0;
                cache_n[i][j].empty = 0;
                cache_n[i][j].data = MDB_data;
                cache_n[i][j].lru_cnt = 0;
                cache_n[i][j].req_memtag = 0;
                cache_n[i][j].dirty = 0;
            end
        end
    end

    //assign memtag if it has arrived
    if(req_sent && (req_memtag != 0)) begin
        for(int i = 0; i < `DCACHE_ASSOCIATIVITY; i++)begin
            if(cache_n[req_set][i].tag == req_tag) begin
                cache_n[req_set][i].req_memtag = req_memtag;
                cache_n[req_set][i].lru_cnt = 0;
                cache_n[req_set][i].waiting_for_mem = 1;
            end
        end
    end 

end

//Sequential
always_ff @(posedge clock) begin
    if (reset) begin
    // clear cache
    //set all to empty
    for(int i = 0; i < `DCACHE_NUM_SETS; ++i) begin
        for(int j = 0; j < `DCACHE_ASSOCIATIVITY; j++) begin
            cache[i][j].waiting_for_mem <= 0;
            cache[i][j].empty <= 1;
            cache[i][j].data <= '0;
            cache[i][j].lru_cnt <= 0;
            cache[i][j].req_memtag <= 0;
            cache[i][j].dirty <= 0;
            cache[i][j].tag <= 0;
            cache[i][j].reset <= 1;
        end
    end
    end else begin
    // update state
    cache <= cache_n;
    end
end

endmodule