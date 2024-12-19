// new non blocking i cache
`include "sys_defs.svh"
`include "ISA.svh"


module ICACHE (
    input MEM_TAG MDB_tag, //watch to see if it matches any outstanding req
    input MEM_BLOCK MDB_data, //my req's data if tag match

    input MEM_TAG req_memtag_in,
    input logic req_sent,

    input ADDR access1, //addr of cache access 1
    input ADDR access2, //addr of cache access 2
    input ADDR access3, //addr of cache access 3

    input logic val1, val2, val3,

    input logic clock, reset,

    output DATA inst1,  //32 bit inst outputs
    output DATA inst2,
    output DATA inst3,

    output ADDR mem_request, // address of memory block we want if miss
    output logic req_valid,
    output logic miss1, //high if miss at that pc
    output logic miss2, 
    output logic miss3
);


// struct ICACHE_ENTRY begin

//      logic [7:0] lru_cnt;
//      logic waiting_for_mem;
//      MEM_BLOCK data;
//      logic empty;
//      MEM_TAG req_memtag;
//      logic [(28 - $clog2(`ICACHE_SIZE / `ICACHE_ASSOCIATIVITY)) : 0] tag


//Declarations
logic [16:0] num_sets;
assign num_sets = `ICACHE_NUM_SETS; // need to add these to sysdefs
logic [16:0] set_size;
assign set_size = `ICACHE_ASSOCIATIVITY;

logic [$clog2(`ICACHE_NUM_SETS) - 1 :0] set1, set2, set3;
assign set1 = access1[$clog2(`ICACHE_NUM_SETS)+2:3];
assign set2 = access2[$clog2(`ICACHE_NUM_SETS)+2:3];
assign set3 = access3[$clog2(`ICACHE_NUM_SETS)+2:3];

logic [2:0] bo1, bo2, bo3;
assign bo1 = access1[2:0];
assign bo2 = access2[2:0];
assign bo3 = access3[2:0];

logic [(29 - $clog2(`ICACHE_NUM_SETS)) : 0] tag1, tag2, tag3; 
assign tag1 = access1[31 : $clog2(`ICACHE_NUM_SETS) + 3];
assign tag2 = access2[31 : $clog2(`ICACHE_NUM_SETS) + 3];
assign tag3 = access3[31 : $clog2(`ICACHE_NUM_SETS) + 3];

ICACHE_ENTRY [`ICACHE_NUM_SETS-1:0] [`ICACHE_ASSOCIATIVITY-1:0] cache, cache_n; 

logic [$clog2(`ICACHE_ASSOCIATIVITY)-1:0] lru1, lru2, lru3, empty1_idx, empty2_idx, empty3_idx;
logic empty1, empty2, empty3;
logic [7:0] max1, max2, max3;


logic already_req1, already_req2, already_req3;
logic already_waiting1, already_waiting2, already_waiting3;

logic [$clog2(`ICACHE_NUM_SETS) - 1 :0] req_set;
logic [(28 - $clog2(`ICACHE_NUM_SETS)) : 0] req_tag;


assign req_set = mem_request[$clog2(`ICACHE_NUM_SETS)+2:3];
assign req_tag = mem_request[31 : $clog2(`ICACHE_NUM_SETS) + 3];



`ifdef DEBUG_FLAG
    always @(negedge clock) begin
        $display("\nIcache contents========================");
        for(int i = 0; i<`ICACHE_NUM_SETS; i++) begin
            $display("\nSet %d", i);
            for(int j=0; j<`ICACHE_ASSOCIATIVITY; j++)begin
                $display("block %d: tag:%d data: %h waiting: %b memtag: %h lrucnt: %d empty: %b",j,cache[i][j].tag,cache[i][j].data, cache[i][j].waiting_for_mem, cache[i][j].req_memtag, cache[i][j].lru_cnt, cache[i][j].empty);
            end
        end
        $display("lru1: %d lru2: %d lru3: %d",lru1, lru2, lru3);
        $display("\n fetch requesting at: %h, %h, %h", access1, access2, access3);
        $display("\n sets : %d, %d, %d",set1,set2,set3);
        $display("\n tags : %d, %d, %d",tag1,tag2,tag3);
        $display("misses 1 2 3 %b %b %b",miss1,miss2,miss3);
        $display("alr req: %b %b %b", already_req1, already_req2, already_req3);
        if(req_valid)begin
            $display("\n requesting addr %h from memory", mem_request);
        end
        if(req_sent) begin
            $display("req sent, tag %h",req_memtag_in);
        end else begin
            $display("req not sent, mem busy");
        end
        $display("MDB data: %h tag: %h", MDB_data, MDB_tag);
        $display("\nend Icache========================");
    end
`endif

//Combinational
always_comb begin
    //$display("comb_req_memtag: %b",req_memtag_in);
    cache_n = cache;
    miss1 = 1;
    miss2 = 1;
    miss3 = 1;
    mem_request = 0;
    req_valid = 0;
    already_waiting1 = 0;
    already_waiting2 = 0;
    already_waiting3 = 0;
    inst1 = '0;
    inst2 = '0;
    inst3 = '0;

    //=================== check to see if accesses are misses or not ===================
    //iterate through corresponding set and look for match
    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin // access 1
        if((cache[set1][i].tag == tag1) && cache[set1][i].waiting_for_mem && val1) begin
            already_waiting1 = 1;
            cache_n[set1][i].lru_cnt = 0;
            break;
        end
        if((cache[set1][i].tag == tag1) && !cache[set1][i].waiting_for_mem && !cache[set1][i].empty && val1 && !cache[set1][i].reset) begin
            miss1 = 0;
            cache_n[set1][i].lru_cnt = 0;
            if(bo1[2]) begin
                inst1 = cache[set1][i].data.word_level[1];
            end else begin
                inst1 = cache[set1][i].data.word_level[0];
            end
        end
    end

    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin // access 2
        if((cache[set2][i].tag == tag2) && cache[set2][i].waiting_for_mem && val2) begin
            already_waiting2 = 1;
            cache_n[set2][i].lru_cnt = 0;
            break;
        end
        if((cache[set2][i].tag == tag2) && !cache[set2][i].waiting_for_mem && !cache[set2][i].empty && val2 && !cache[set2][i].reset) begin
            miss2 = 0;
            cache_n[set2][i].lru_cnt = 0;
            if(bo2[2]) begin
                inst2 = cache[set2][i].data.word_level[1];
            end else begin
                inst2 = cache[set2][i].data.word_level[0];
            end
        end
    end

    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin // access 3
        if((cache[set3][i].tag == tag3) && cache[set3][i].waiting_for_mem && val3) begin
            already_waiting3 = 1;
            cache_n[set3][i].lru_cnt = 0;
            break;
        end
        if((cache[set3][i].tag == tag3) && !cache[set3][i].waiting_for_mem && !cache[set3][i].empty && val3 && !cache[set1][i].reset) begin
            miss3 = 0;
            cache_n[set3][i].lru_cnt = 0;
            if(bo3[2]) begin
                inst3 = cache[set3][i].data.word_level[1];
            end else begin
                inst3 = cache[set3][i].data.word_level[0];
            end
        end
    end

//increment all lru counters
    for(int i = 0; i < `ICACHE_NUM_SETS; i++) begin
        for(int j = 0; j < `ICACHE_ASSOCIATIVITY; j++) begin
            if(!cache[i][j].empty) begin
                cache_n[i][j].lru_cnt++;
            end
        end
    end

    max1 = 0;
    max2 = 0;
    max3 = 0;
    lru1 = 0;
    lru2 = 0;
    lru3 = 0;
//If miss  
    //evict lru, put placeholder in it's place

    //find lru's
    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set1][i].lru_cnt >= max1) begin
            //$display("lru find i: %d",i);
            lru1 = i;
            max1 = cache[set1][i].lru_cnt;
        end
    end
    //$display("calc lru1: %d",lru1);

    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set2][i].lru_cnt >= max2) begin
            lru2 = i;
            max2 = cache[set2][i].lru_cnt;
        end
    end
    //$display("calc lru2: %d",lru2);

    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set3][i].lru_cnt >= max3) begin
            lru3 = i;
            max3 = cache[set3][i].lru_cnt;
        end
    end
    //$display("calc lru3: %d",lru3);
    //find empties if there are any,
    empty1 = 0;
    empty2 = 0;
    empty3 = 0;
    empty1_idx = 0;
    empty2_idx = 0;
    empty3_idx = 0;
    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set1][i].empty && ~cache[set1][i].waiting_for_mem) begin
            empty1 = 1;
            empty1_idx = i;
            break;
        end
    end
    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set2][i].empty && ~cache[set2][i].waiting_for_mem) begin
            empty2 = 1;
            empty2_idx = i;
            break;
        end
    end
    for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
        if(cache[set3][i].empty && ~cache[set3][i].waiting_for_mem) begin
            empty3 = 1;
            empty3_idx = i;
            break;
        end
    end

    //evict lru's if there was a miss
    if(miss1 && !already_waiting1 && val1) begin
        if(~empty1)begin
            cache_n[set1][lru1].empty = 1;
            cache_n[set1][lru1].tag = tag1;
            cache_n[set1][lru1].reset = 0;
        end else begin
            cache_n[set1][empty1_idx].tag = tag1;
            cache_n[set1][empty1_idx].reset = 0;
        end
    end
    if(miss2 && !already_waiting2 && val2) begin
        if(~empty2)begin
            cache_n[set2][lru2].empty = 1;
            cache_n[set2][lru2].tag = tag2;
            cache_n[set2][lru2].reset = 0;
        end else begin
            cache_n[set2][empty2_idx].tag = tag2;
            cache_n[set2][empty2_idx].reset = 0;
        end
    end
    if(miss3 && !already_waiting3 && val3) begin
        if(~empty3)begin
            cache_n[set3][lru3].empty = 1;
            cache_n[set3][lru3].tag = tag3;
            cache_n[set3][lru3].reset = 0;
        end else begin
            cache_n[set3][empty3_idx].tag = tag3;
            cache_n[set3][empty3_idx].reset = 0;
        end
    end

    //=================== send requests to memory ===================
    //Prioritize oldest miss, send mem_request, put tag in placeholder
    already_req1 = 0;
    already_req2 = 0;
    already_req3 = 0;

    //do not send a new requesst if there is already a request for that block
    if(miss1 && !already_waiting1 && val1) begin
        for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
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
            mem_request = access1;
            req_valid = 1;
        end
    end else if(miss2 && !already_waiting2 && val2) begin
        for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
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
            mem_request = access2;
            req_valid = 1;
        end
    end else if(miss3 && !already_waiting3 && val3) begin
        for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++) begin
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
            mem_request = access3;
            req_valid = 1;
        end
    end
        //=================== watch MDB ===================
    //If MDP_tag matches 
    for(int i = 0; i < `ICACHE_NUM_SETS; ++i) begin
        for(int j = 0; j < `ICACHE_ASSOCIATIVITY; ++j) begin
            if(cache[i][j].waiting_for_mem && (cache[i][j].req_memtag == MDB_tag) && (MDB_tag != 0)) begin
                //$display("ruining everything, memtag: %d MDB tag: %d",cache_n[i][j].req_memtag,MDB_tag);
                //set value of placeholder to MDP data
                cache_n[i][j].waiting_for_mem = 0;
                cache_n[i][j].empty = 0;
                cache_n[i][j].data = MDB_data;
                cache_n[i][j].lru_cnt = 0;
                cache_n[i][j].req_memtag = 0;
            end
        end
    end

    //assign memtag if it has arrived
    if(req_sent) begin
        for(int i = 0; i < `ICACHE_ASSOCIATIVITY; i++)begin
            if(cache_n[req_set][i].tag == req_tag) begin
                //$display("here word, req_memtag_in %d",req_memtag_in);
                //$display("req_set, %d, i %d",req_set, i);
                cache_n[req_set][i].req_memtag = req_memtag_in;
                cache_n[req_set][i].waiting_for_mem = 1;
                cache_n[req_set][i].lru_cnt = 0;
               // $display("actual val %d",cache_n[req_set][i].req_memtag);
                break;
            end
        end
    end

end

//Sequential
// always_ff @(negedge clock) begin
//     if(req_sent) begin
//         for(int i = 0; i < set_size; i++)begin
//             if(cache[req_set][i].waiting_for_mem && cache[req_set][i].tag == req_tag) begin
//                 cache_n[req_set][i].req_memtag = req_memtag_in;
//             end
//         end
//     end 
// end
always_ff @(posedge clock) begin
    if (reset) begin
    // clear cache
    //set all to emptyx
    for(int i = 0; i < `ICACHE_NUM_SETS; ++i) begin
        for(int j = 0; j < `ICACHE_ASSOCIATIVITY; j++) begin
            cache[i][j].waiting_for_mem <= 0;
            cache[i][j].empty <= 1;
            cache[i][j].data <= '0;
            cache[i][j].lru_cnt <= 0;
            cache[i][j].req_memtag <= 0;
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