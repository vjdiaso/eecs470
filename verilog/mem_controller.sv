`include "sys_defs.svh"

module mem_controller(
    input ADDR icache_req,
    input logic icache_req_val,
    input ADDR load_req,
    input logic load_req_val,
    input ADDR store_req,
    input MEM_BLOCK store_req_data,
    input logic store_req_val,
`ifdef DEBUG_FLAG
    input clock,
`endif
    input reset,
    
    output MEM_SIZE proc2mem_size, //size of request, for icache requests always double
    output MEM_COMMAND proc2mem_command,
    output ADDR proc2mem_addr,
    output MEM_BLOCK proc2mem_data,
    output logic icache_req_sent,
    output logic load_req_sent,
    output logic store_req_sent
);
//Sys defs additions
// define STORE_OVER_LOAD
// define ICACHE_OVER_DCACHE

//declarations
`ifdef DEBUG_FLAG
always @(negedge clock) begin
    $display("memcon printing -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
    if(icache_req_val) begin
        $display("Icache Requesting addr %h",icache_req);
        if(icache_req_sent)begin
            $display("sent");
        end else begin
            $display("not sent, mem busy");
        end
    end
    if(store_req_val) begin
        $display("Store Requesting addr %h",store_req);
        if(store_req)begin
            $display("sent");
        end else begin
            $display("not sent, mem busy");
        end
    end
    if(load_req_val) begin
        $display("LOAD Requesting addr %h",load_req);
        if(load_req)begin
            $display("sent");
        end else begin
            $display("not sent, mem busy");
        end
    end
    $display(icache_req_val);
    $display(store_req_val);
    $display(load_req_val);

    $display("proc2memsize:%d",proc2mem_size);
    $display("proc2memcmd: %d",proc2mem_command);
    $display("memcon end -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
end
`endif
//combinational
always_comb begin
    // Priority: Store, Load, Fetch
    if(~reset) begin
        if(store_req_val) begin
            proc2mem_size = DOUBLE;
            proc2mem_command = MEM_STORE;
            icache_req_sent = 0;
            load_req_sent = 0;
            store_req_sent = 1;
            proc2mem_addr = store_req;
            proc2mem_data = store_req_data;
        end else if(load_req_val) begin
            proc2mem_size = DOUBLE;
            proc2mem_command = MEM_LOAD;
            icache_req_sent = 0;
            load_req_sent = 1;
            store_req_sent = 0;
            proc2mem_addr = load_req;
            proc2mem_data = 0;
        end else if(icache_req_val) begin
            proc2mem_size = DOUBLE;
            proc2mem_command = MEM_LOAD;
            icache_req_sent = 1;
            load_req_sent = 0;
            store_req_sent = 0;
            proc2mem_addr = icache_req;
            proc2mem_data = 0;
        end else begin
            proc2mem_size = DOUBLE;
            proc2mem_command = MEM_NONE;
            icache_req_sent = 0;
            load_req_sent = 0;
            store_req_sent = 0;
            proc2mem_addr = 0;
            proc2mem_data = 0;
        end
    end else begin
        proc2mem_size = DOUBLE;
        proc2mem_command = MEM_NONE;
        icache_req_sent = 0;
        load_req_sent = 0;
        store_req_sent = 0;
        proc2mem_addr = 0;
        proc2mem_data = 0;
    end
  
end

endmodule