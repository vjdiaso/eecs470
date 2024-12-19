//testbench for regfile

`include "sys_defs.svh"
module regfile_test ();

logic clock;
logic [12:0] [`PHYS_REG_BITS-1 : 0] read_idx;
logic [2:0] [`PHYS_REG_BITS-1 : 0] write_idx;
logic [2:0] write_en;
DATA [2:0] write_data;
DATA [12:0] read_out;

regfile dut (
    .clock(clock),
    .read_idx(read_idx),
    .write_idx(write_idx),
    .write_en(write_en),
    .write_data(write_data),
    .read_out(read_out)
);

always begin
    #(`CLOCK_PERIOD/2.0);
    clock = ~clock;
end

task print_regfile();
    $display("\n Regfile contents");
    for(int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
        $display("\n Reg %d:%d",i,dut.regs[i]);
    end
endtask
task read13();
    $display("\n Read data");
    for(int i = 0; i < 13; i++) begin
        $display("\n read %d from idx %d",read_out[i],read_idx[i]);
    end
endtask

initial begin
    clock = 0;
    read_idx = '0;
    write_idx = '0;
    write_en = '0;
    write_data = '0;
    @(negedge clock);

    for(int i = 0; i < 64; i++) begin
        write_en[0] = 1;
        write_data[0] = i;
        write_idx[0] = i;
        @(negedge clock);
        print_regfile();
    end
    write_data[0] = 9999;
    write_idx[0] = 55;
    @(negedge clock);
    print_regfile();
    write_en = '0;
    for(int i = 0; i < 13; i++) begin
        read_idx[i] = i+20;
    end
    @(negedge clock);
    read13();
    read_idx = '0;
    read_idx[0] = 0;
    write_idx[0] = 63;
    write_data[0] = 68008;
    print_regfile();
    @(negedge clock);
    write_en [0] = 1;
    @(negedge clock);
    print_regfile();
    $display(read_out[0]);
    write_en[0] = 0;
    @(negedge clock);
    write_en[1] = 1;
    write_idx[1] = 10;
    write_data[1] = 69;
    read_idx[1] = 10;
    #2
    $display("read and write same cycle:%d",read_out[1]);
    $display("read_idx[1]:%d",dut.read_idx[1]);
    $display("write_idx[1]:%d",dut.write_idx[1]);
    $display("re[1]:%b",dut.re[1]);

    @(negedge clock);
    $display("next cycle?: %d",read_out[1]);
    @(negedge clock);



    $finish;
end
endmodule