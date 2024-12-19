`include "sys_defs.svh"

module load_unit_test();
    logic clock, reset;
    
    logic valid_load_from_store_queue; //Makes sure the data from store queue is valid
    logic valid_load_from_issue_reg;
    MEM_SIZE load_size;
    MEM_BLOCK load_data_foward;// valid data from store queue
    logic [7:0] load_data_fwd_bytes_valid;//valid bytes from store queue
    ADDR PC;
    logic [`PHYS_REG_BITS-1:0]dest_tag_in;
    DATA t1;
    DATA offset;
    DATA data_from_cache;// whole word of data from data cache
    logic cache_miss;
    logic rd_unsigned;//get from inst.r.func3[2] in issue reg
    logic cdb_taken;
    logic free;//input to left_over_issue_from_excute to keep load in issue reg
    logic done;//to let cdb know this is a valid choice(sequential  to cdb)
    DATA data_to_reg; //data written to regfile(sequential  to cdb)
    logic [`PHYS_REG_BITS-1:0] dest_tag_out;//tag for regfile(sequential  to cdb)
    ADDR load_addr;//address sent to store queue
    ADDR load_addr_for_cache;//address sent to cache
    logic load_addr_for_cache_valid;
    logic load_valid;
    logic [7:0] valid_bytes;
    MEM_SIZE size;


load_unit#()
    dut(
    .clock(clock),                              // Connect clock
    .reset(reset),                              // Connect reset
    .valid_load_from_store_queue(valid_load_from_store_queue),  // Connect valid load from store queue
    .valid_load_from_issue_reg(valid_load_from_issue_reg),    // Connect valid load from issue register
    .load_size(load_size),                      // Connect load size
    .load_data_foward(load_data_foward),        // Connect data forwarded from store queue
    .load_data_fwd_bytes_valid(load_data_fwd_bytes_valid),     // Connect valid bytes from store queue
    .PC(PC),                                    // Connect program counter
    .dest_tag_in(dest_tag_in),                  // Connect destination tag input
    .t1(t1),                                    // Connect t1
    .offset(offset),                            // Connect offset
    .data_from_cache(data_from_cache),          // Connect data from cache
    .cache_miss(cache_miss),                    // Connect cache miss signal
    .rd_unsigned(rd_unsigned),                  // Connect rd_unsigned signal
    .cdb_taken(cdb_taken),                      // Connect cdb_taken signal

    // Outputs
    .free(free),                                // Connect free output
    .done(done),                                // Connect done output
    .data_to_reg(data_to_reg),                  // Connect data to register output
    .dest_tag_out(dest_tag_out),                // Connect destination tag output
    .load_addr(load_addr),                      // Connect load address for store queue
    .load_addr_for_cache(load_addr_for_cache),  // Connect load address for cache
    .load_valid(load_valid),                    // Connect load valid signal
    .load_addr_for_cache_valid(load_addr_for_cache_valid),
    .valid_bytes(valid_bytes),                  // Connect valid bytes output
    .size(size)                                 // Connect size of the load
);

task print_load_unit();
    $display("\nLoad_Unit inputs: reset: %b, valid_load_from_store_queue: %b, valid_load_from_store_queue: %b, load_size: %s, load_data_foward: %h, load_data_foward_bytes_valid: %b,\n                 PC: %h, dest_tag_in: %d, t1: %h, offset: %h, data_from_cache: %h, cache_miss: %b, rd_unsigned: %b, cdb_taken: %b",
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

    $display("\n\nLoad Unit Outputs: Free: %b, done: %b, load_addr: %h, load_valid: %b, load_addr_for_cache: %h, , load_addr_for_cache_valid: %b",
    free,
    done,
    load_addr,
    load_valid,
    load_addr_for_cache,
    load_addr_for_cache_valid);

endtask

always begin
    #(`CLOCK_PERIOD/2) clock = ~clock;
end
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

initial begin
    clock = 0;
    reset = 1;
    
    valid_load_from_store_queue = 0; //Makes sure the data from store queue is valid
    valid_load_from_issue_reg = 0;
    load_size = BYTE;
    load_data_foward = '0;// valid data from store queue
    load_data_fwd_bytes_valid = '0;//valid bytes from store queue
    PC = '0;
    dest_tag_in = '0;
    t1 = '0;
    offset = '0;
    data_from_cache = '0;// whole word of data from data cache
    cache_miss = 1;
    rd_unsigned = 0;//get from inst.r.func3[2] in issue reg
    cdb_taken = 0;

    $display("\nStart Testbench");
    @(negedge clock);#2
    $display("RESET");
    reset = 0;
    @(negedge clock);#2
    //cycle 1
    valid_load_from_issue_reg = 1;
    load_size = BYTE;
    PC = 1;
    dest_tag_in = 1;
    t1 = 1;
    offset = 0;
    valid_load_from_store_queue = 1;
    load_data_foward.byte_level[1] = 8'h02;
    load_data_fwd_bytes_valid = 8'b00000010;
    @(negedge clock);#2
    //cycle 2
    valid_load_from_issue_reg = 1;
    load_size = BYTE;
    PC = 2;
    dest_tag_in = 2;
    t1 = 1;
    offset = 1;#5
    valid_load_from_store_queue = 1;
    load_data_foward.byte_level[2] = 8'h0a;
    load_data_fwd_bytes_valid = 8'b00000100;
    @(negedge clock);#2
    //cycle 3

    cdb_taken = 1;
    @(negedge clock);#2
    //cycle 4
    cdb_taken = 1;
    valid_load_from_issue_reg = 1;
    load_size = BYTE;
    PC = 3;
    dest_tag_in = 3;
    t1 = 1;
    offset = 0;#5
    valid_load_from_store_queue = 1;
    load_data_foward.byte_level[1] = 8'h0a;
    load_data_fwd_bytes_valid = 8'b00000000;
    rd_unsigned = 0;
    @(negedge clock);#2
    //cycle 5
    cdb_taken = 0;
    valid_load_from_store_queue = 0;
    @(negedge clock);#2
    cdb_taken = 1;
    cache_miss = 0;
    data_from_cache = 32'hdeadbeef;
    valid_load_from_issue_reg = 0;
    dest_tag_in = 4;
    PC = 4;
    @(negedge clock);#2
    valid_load_from_issue_reg = 1;
    load_size = HALF;
    t1 = 3;
    //cache_miss = 1;
    offset = 3;#5
    valid_load_from_store_queue = 1;
    load_data_foward.half_level[3] = 16'habcd;
    load_data_fwd_bytes_valid = 8'b01000000;#5
    cache_miss = 0;
    data_from_cache = 32'hdeadbeef;
    @(negedge clock);#2
    cdb_taken = 0;
    valid_load_from_issue_reg = 0;
    valid_load_from_store_queue = 0;
    cache_miss = 1;
    @(negedge clock);#2
    cdb_taken = 1;
    @(negedge clock);#2
    cdb_taken = 0;
    valid_load_from_issue_reg = 1;
    load_size = WORD;
    t1 = 4;
    //cache_miss = 1;
    offset = 0;#5
    valid_load_from_store_queue = 1;
    load_data_foward.word_level[1] = 32'hfacebeef;
    load_data_fwd_bytes_valid = 8'b10100000;#5
    cache_miss = 1;
    data_from_cache = 32'h12345678;
    @(negedge clock);#2
    @(negedge clock);#2
    cache_miss = 0;
    @(negedge clock);#2
    $finish;
end

endmodule