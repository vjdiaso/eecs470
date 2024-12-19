// FIFO module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "sys_defs.svh"

module model_rob #(ROB_SZ)(
    input rob_input rob_in,
    input clock, reset,
    
    output rob_output rob_out
);
rob_entry q [$:ROB_SZ];
rob_entry null_entry;

assign null_entry.destReg = 0;
assign null_entry.oldReg = 0;
assign null_entry.free = 0;
assign null_entry.inst = 0;
assign null_entry.retire = 0;

logic [`PHYS_REG_BITS-1:0] physTag1,physTag2,physTag3;
logic[2:0]new_valid_entries;
logic[2:0]phys_return_free;

always @(posedge clock) begin
    if(reset) begin
        q.delete();
        rob_out.openSpots <= ROB_SZ;
        rob_out.valid_retire_1 <= 0;
        rob_out.retiring_Told_1 <= 0;
        rob_out.valid_retire_2 <= 0;
        rob_out.retiring_Told_2 <= 0;
        rob_out.valid_retire_3 <= 0;
        rob_out.retiring_Told_3 <= 0;
        rob_out.freeTag1_taken <= 0;
        rob_out.freeTag2_taken <= 0;
        rob_out.freeTag3_taken <= 0;
    end else begin
    //Set entries ready to retire
        for(int i=0; i<ROB_SZ; i++)begin
            if(~q[i].free) begin
                if(((rob_in.cdb_tag1 == q[i].destReg) && rob_in.cdb_valid1) || ((rob_in.cdb_tag2 == q[i].destReg) && rob_in.cdb_valid2) || ((rob_in.cdb_tag3 == q[i].destReg) && rob_in.cdb_valid3))begin
                    q[i].retire = 1;
                end
            end
        end

        //Retire entries if possible
        if(q[0].retire && (q.size() > 0))begin
            q[0].retire =0;
            physTag1 = q[0].oldReg;
            q.pop_front();
            phys_return_free[0] = 1;
            if(q[0].retire && (q.size() > 0))begin
                q[0].retire =0;
                physTag2 = q[0].oldReg;
                q.pop_front();
                phys_return_free[1] = 1;
                if(q[0].retire && (q.size() > 0))begin
                    q[0].retire =0;
                    physTag3 = q[0].oldReg;
                    q.pop_front();
                    phys_return_free[2] = 1;
                end
            end
        end

        //Add up to 3 entries if there is room
        if(rob_in.dispatch1_valid)begin
            q.push_back(null_entry);
            q[q.size()-1].inst = rob_in.inst1;
            q[q.size()-1].destReg = rob_in.physical_reg1;
            q[q.size()-1].oldReg = rob_in.physical_old_reg1;
            q[q.size()-1].free = 0;
            q[q.size()-1].retire = 0;
            new_valid_entries[0] = 1;
        end
        if(rob_in.dispatch2_valid)begin
            q.push_back(null_entry);
            q[q.size()-1].inst = rob_in.inst2;
            q[q.size()-1].destReg = rob_in.physical_reg2;
            q[q.size()-1].oldReg = rob_in.physical_old_reg2;
            q[q.size()-1].free = 0;
            q[q.size()-1].retire = 0;
            new_valid_entries[1] = 1;
        end
        if(rob_in.dispatch3_valid)begin
            q.push_back(null_entry);
            q[q.size()-1].inst = rob_in.inst3;
            q[q.size()-1].destReg = rob_in.physical_reg3;
            q[q.size()-1].oldReg = rob_in.physical_old_reg3;
            q[q.size()-1].free = 0;
            q[q.size()-1].retire = 0;
            new_valid_entries[2] = 1;
        end
        
        // assign outputs
        rob_out.openSpots <= ROB_SZ-q.size();

        //Handle outputs for retiring entries
        if(phys_return_free[0])begin
            rob_out.valid_retire_1 <= 1;
            rob_out.retiring_Told_1 <= physTag1;
        end else begin
            rob_out.valid_retire_1 <= 0;
            rob_out.retiring_Told_1 <= 0;
        end
        if(phys_return_free[1])begin
            rob_out.valid_retire_2 <= 1;
            rob_out.retiring_Told_2 <= physTag2;
        end else begin
            rob_out.valid_retire_2 <= 0;
            rob_out.retiring_Told_2 <= 0;
        end
        if(phys_return_free[2])begin
            rob_out.valid_retire_3 <= 1;
            rob_out.retiring_Told_3 <= physTag3;
        end else begin
            rob_out.valid_retire_3 <= 0;
            rob_out.retiring_Told_3 <= 0;
        end

        //Handle outputs for new entries
        if(new_valid_entries[0])begin
            rob_out.freeTag1_taken <= 1;
        end else begin
            rob_out.freeTag1_taken <= 0;
        end
        if(new_valid_entries[1])begin
            rob_out.freeTag2_taken <= 1;
        end else begin
            rob_out.freeTag2_taken <= 0;
        end
        if(new_valid_entries[2])begin
            rob_out.freeTag3_taken <= 1;
        end else begin
            rob_out.freeTag2_taken <= 0;
        end

    end // reset else
end // always posedge clock
endmodule

module rob_test();

    logic              clock, reset;
    rob_input                rob_in;
    rob_output              rob_out4, rob_out7, rob_out8, rob_out32;
    rob_output              cres4, cres7, cres8, cres32;
    logic correct ,correct4, correct7, correct8, correct32, t_en;


    //define task to print rob output
    task print_rob(input rob_output rob);
        $display("\n Rob out | r1: %b r2: %b r3: %b cdb1: %b cdb2: %b cdb %b | open spots: %d | free regs taken %b %b %b",
        rob.valid_retire_1, rob.valid_retire_2, rob.valid_retire_3,
        rob_in.cdb_valid1, rob_in.cdb_valid2, rob_in.cdb_valid3,
        rob.openSpots, 
        rob.freeTag1_taken, rob.freeTag2_taken, rob.freeTag3_taken);
    endtask


    //Instantiate robs and models for various sizes (4,7,8,32)

    //models
    model_rob#(
        .ROB_SZ(4))
    model4 (
        .rob_in     (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (cres4)
    );
    model_rob#(
        .ROB_SZ(7))
    model7 (
        .rob_in     (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (cres7)
    );
    model_rob#(
        .ROB_SZ(8))
    model8 (
        .rob_in     (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (cres8)
    );
    model_rob#(
        .ROB_SZ(32))
    model32 (
        .rob_in     (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (cres32)
    );

    //robs
    ROB#(
        .ROB_SZ(4))
    dut4 (
        .rob_packet      (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (rob_out4)
    );
    ROB#(
        .ROB_SZ(7))
    dut7 (
        .rob_packet      (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (rob_out7)
    );
    ROB#(
        .ROB_SZ(8))
    dut8 (
        .rob_packet      (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (rob_out8)
    );
    ROB#(
        .ROB_SZ(32))
    dut32 (
        .rob_packet      (rob_in),
        .clock      (clock),
        .reset      (reset),
        .rob_out    (rob_out32)
    );

    //Check correct results
    assign correct4 = (cres4 == rob_out4);
    assign correct7 = (cres7 == rob_out7);
    assign correct8 = (cres8 == rob_out8);
    assign correct32 = (cres32 == rob_out32);
    assign correct = !t_en || (correct4&&correct7&&correct8&&correct32);

    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    //if incorrect print fail message
    always @(posedge clock) begin
        #(`CLOCK_PERIOD*0.2); // a short wait to let signals stabilize
        if (!correct) begin
            $display("@@@ Incorrect at time %4.0f", $time);
            if(!correct4) begin
                $display("@@@ ROB4 output");
                print_rob(rob_out4);
                $display("@@@ Expected result");
                print_rob(cres4);
            end
            if(!correct7) begin
                $display("@@@ ROB7 output");
                print_rob(rob_out7);
                $display("@@@ Expected result");
                print_rob(cres7);
            end
            if(!correct8) begin
                $display("@@@ ROB8 output");
                print_rob(rob_out8);
                $display("@@@ Expected result");
                print_rob(cres8);
            end
            if(!correct32) begin
                $display("@@@ ROB32 output");
                print_rob(rob_out32);
                $display("@@@ Expected result");
                print_rob(cres32);
            end
            $finish;
        end
    end

    // START TESTBENCH

    initial begin
        $display("Starting Testbench!\n");
        
        //Initialize testbench state
        t_en = 0;
        reset = 1;
        clock = 0;
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        rob_in.cdb_valid3 = 0;
        rob_in.dispatch1_valid = 0;
        rob_in.dispatch2_valid = 0;
        rob_in.dispatch3_valid = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        t_en = 1;
        //Rob should be reset now,start tests

        $display("\nTest 1: insert one remove one");
        rob_in.dispatch1_valid = 1;
        rob_in.physical_old_reg1 = 2;
        rob_in.physical_reg1 = 1;
        rob_in.cdb_tag1 = 0;
        @(negedge clock);
        rob_in.dispatch1_valid = 0;
        @(negedge clock);
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_tag1 = 1;
        @(negedge clock);
        rob_in.cdb_valid1 = 0;
        @(negedge clock);
        

        $display("cres32 open spots: %d", cres32.openSpots);
        $display("robout32 open spots: %d", rob_out32.openSpots);
        $display("T1: FILL ASAP\n");
        while(cres32.openSpots >0)begin
            @(negedge clock);
            rob_in.dispatch1_valid = 1;
            rob_in.dispatch2_valid = 1;
            rob_in.dispatch3_valid = 1;
            rob_in.physical_reg1 = 1;
            rob_in.physical_reg2 = 1;
            rob_in.physical_reg3= 1;
            @(negedge clock);
            rob_in.dispatch1_valid = 0;
            rob_in.dispatch2_valid = 0;
            rob_in.dispatch3_valid = 0;
            //print_rob(cres32);
        end
        //all robs should be full with entries that all have tag 1

        $display("T2: EMPTY ASAP\n");
        while(cres32.openSpots <32)begin
            @(negedge clock);
            rob_in.cdb_valid1 = 1;
            rob_in.cdb_valid2 = 1;
            rob_in.cdb_valid3 = 1;
            rob_in.cdb_tag1 = 1;
            rob_in.cdb_tag2 = 1;
            rob_in.cdb_tag3 = 1;
            @(negedge clock);
            rob_in.cdb_valid1 = 0;
            rob_in.cdb_valid2 = 0;
            rob_in.cdb_valid3 = 0;
        end
        //all robs should be totally empty now
        reset = 1;
        @(negedge clock);
        reset = 0;
        //reset before further tests

        $display("T3: 3 Way Retire after waiting for head\n");
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        rob_in.physical_reg1 = 1;
        rob_in.physical_reg2 = 2;
        rob_in.physical_reg3 = 3;
        //read in 3 entries tagged 1, 2, 3, head should be at 1;
        @(negedge clock);
        rob_in.dispatch1_valid = 1;
        rob_in.dispatch2_valid = 1;
        rob_in.dispatch3_valid = 1;
        @(negedge clock);
        rob_in.cdb_tag1 = 2;
        rob_in.cdb_tag2 = 3;
        rob_in.cdb_valid1 = 1;
        rob_in.cdb_valid2 = 1;
        @(negedge clock); //the two entries ahead of the head are complete now
        rob_in.cdb_valid1 = 0;
        rob_in.cdb_valid2 = 0;
        @(negedge clock);
        rob_in.cdb_tag1 = 1;
        rob_in.cdb_valid1 = 1;
        @(negedge clock);
        rob_in.cdb_valid1 = 0; // all three should retire this cycle
        @(negedge clock);

        //SUCCESSFULLY END TESTBENCH
        $display("@@@ Passed");
        $display("ENDING TESTBENCH : SUCCESS !\n");
        $finish;
    end //initial
endmodule