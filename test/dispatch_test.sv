`include "sys_defs.svh"
`include "ISA.svh"

`timescale 1us/1ns

module dispatch_test;

logic branch_mispredict;
logic [$clog2(`ROB_SZ+1)-1:0] rob_spots;
logic [$clog2(`RS_SZ): 0] rs_spots;
logic [4:0] lsq_spots; //just set >3 in testbench for now until we have a lsq
logic [31:0] fetch1;
logic [31:0] fetch2;
logic [31:0] fetch3;
logic f1val, f2val, f3val;
logic reset, clock;
logic [1:0] num;

dispatch_packet inst1;
dispatch_packet inst2;
dispatch_packet inst3;

dispatch_packet o1;
dispatch_packet o2;
dispatch_packet o3;


/* For testing dispatch fifo
DispatchFifo dut(
    .in1(inst1),
    .in2(inst2),
    .in3(inst3),
    .valid1(f1val),
    .valid2(f2val),
    .valid3(f3val),
    .num_release(num),
    .clock(clock),
    .reset(reset),

    .out1(o1),
    .out2(o2),
    .out3(o3)
);
*/

dispatch dut(
    .branch_mispredict(branch_mispredict),
    .rob_spots(rob_spots),
    .rs_spots(rs_spots),
    .lsq_spots(lsq_spots), //just set >3 in testbench for now until we have a lsq
    .fetch1(fetch1),
    .fetch2(fetch2),
    .fetch3(fetch3),
    .f1val(f1val), 
    .f2val(f2val), 
    .f3val(f3val),
    .reset(reset),
    .clock(clock),

    //decoded dispatched insts
    .inst1(inst1),
    .inst2(inst2),
    .inst3(inst3)
);


task print_dispatch_packet(input dispatch_packet packet);
    if(packet.valid) begin
        $display("\n|  %b  |  %d  |  %d  |  %d  |  %d  |  %b  |  %b  |  %b  |  %b  |  %b  |  %b  |  %b  |",
        packet.inst,
        packet.dest,
        packet.src1,
        packet.src2,
        packet.imm,
        packet.has_imm,
        packet.alufunc,
        packet.multfunc,
        packet.branchfunc,
        packet.condbr,
        packet.uncond_branchfunc,
        packet.uncondbr
        );
    end else begin
        $display("\n Invalid packet ");
    end
endtask

task print_dispatch();
    $display("\n Printing Dispatch State at time: %d", $time);
    $display("\n| inst | dest | src1 | src2 | imm  |has_im|alufun|multfu|brfunc|condbr|uncfunc|uncond|");
    print_dispatch_packet(inst1);
    print_dispatch_packet(inst2);
    print_dispatch_packet(inst3);
    $display("\n End Of Dispatch Printing");
endtask
task print_dispatch_fifo();
    $display("\n Printing Dispatch FIFO State at time: %d", $time);
    $display("\n| inst | dest | src1 | src2 | imm  |has_im|alufun|");
    print_dispatch_packet(dut.fifo.fifo[0]);
    print_dispatch_packet(dut.fifo.fifo[1]);
    print_dispatch_packet(dut.fifo.fifo[2]);
    $display("\n End Of Dispatch FIFO Printing");
endtask

always begin
    #(`CLOCK_PERIOD/2.0);
    clock = ~clock;
end

initial begin
    clock = 0;
    branch_mispredict = 0;
    rob_spots = `ROB_SZ;
    rs_spots = `RS_SZ;
    lsq_spots = 0;
    fetch1 = 32'h003100b3;
    fetch2 = 32'h00310133;
    fetch3 = 32'h003101b3;
    f1val = 1;
    f2val = 1;
    f3val = 1;
    reset = 1;
    @(negedge clock);
    reset = 0;
    print_dispatch();
    print_dispatch_fifo();
    $display(dut.numdisp);
    @(negedge clock);
    print_dispatch();
    print_dispatch_fifo();
    $display(dut.numdisp);
    @(negedge clock);
    print_dispatch();
    print_dispatch_fifo();
    $display(dut.numdisp);
    lsq_spots = 1;
    fetch1 = 32'h00310233;
    f2val = 0;
    f3val = 0;
    @(negedge clock);
    $display(dut.numdisp);
    print_dispatch();
    print_dispatch_fifo();
    f1val = 0;
    lsq_spots = 3;
    @(negedge clock);
    print_dispatch();
    print_dispatch_fifo();
    $display(dut.numdisp);
    @(negedge clock);
    print_dispatch();
    print_dispatch_fifo();
    $display(dut.numdisp);
    @(negedge clock);
    $display("dispatching JAL");
    f1val = 1;
    f2val = 1;
    f3val = 1;
    fetch1 = 32'hd0dff06f;
    fetch2 = 32'hd0dff06f;
    fetch3 = 32'hd0dff06f;
    print_dispatch();
    print_dispatch_fifo();
    @(negedge clock);
    print_dispatch();
    print_dispatch_fifo();
    @(negedge clock);

    $finish;


    /* for testing dispatch fifo
    clock = 0;
    inst1.imm = 1;
    inst1.valid = 1;
    inst2.imm = 2;
    inst2.valid = 1;
    inst3.imm = 3;
    inst3.valid = 1;
    reset = 1;
    num = 0;
    f1val = 1;
    f2val = 1;
    f3val = 1;

    @(negedge clock);
    reset = 0;
    $display("\n openspots: %d",dut.open_spots);
    @(negedge clock);
    $display("\n openspots: %d",dut.open_spots);
    $display(dut.head);
    $display(dut.tail);
    print_dispatch_packet(dut.fifo[0]);
    print_dispatch_packet(dut.fifo[1]);
    print_dispatch_packet(dut.fifo[2]);
    $display(dut.fifo[2].valid);
    @(negedge clock);
    $display("\n openspots: %d",dut.open_spots);
    num = 1;
    inst1.imm = 4;
    print_dispatch_packet(o1);
    @(negedge clock);
    f1val = 0;
    f2val = 0;
    f3val = 0;
    num = 3;
    $display("\n fifo state =======================");
    print_dispatch_packet(dut.fifo[0]);
    print_dispatch_packet(dut.fifo[1]);
    print_dispatch_packet(dut.fifo[2]);
    $display("\n outputs");
    print_dispatch_packet(o1);
    print_dispatch_packet(o2);
    print_dispatch_packet(o3);
    @(negedge clock);
    $display("\n fifo state");
    print_dispatch_packet(dut.fifo[0]);
    print_dispatch_packet(dut.fifo[1]);
    print_dispatch_packet(dut.fifo[2]);
    $display("\n outputs");
    print_dispatch_packet(o1);
    print_dispatch_packet(o2);
    print_dispatch_packet(o3);
    */


    

end

endmodule