`timescale 1ns/1ps

module freelist_tb;

    // Parameters for the test
    parameter FREELIST_NUM = 64;
    parameter ARCH_REG_SZ = 32;
    
    // Inputs and outputs
    reg clock;
    reg reset;
    reg [1:0] dest_reg_request;    // Number of registers requested for allocation
    reg [1:0] free_reg_request;    // Number of registers to free
    reg [2:0][5:0] enqueue_preg;   // List of registers to enqueue (free)
    reg branch_mispredict;
    reg [ARCH_REG_SZ-1:0][5:0] arch_map_mispredict_input; // Registers in arch map during mispredict

    wire [2:0] valid_preg; // Bit vector of free registers
    wire [2:0][5:0] dequeue_preg; // List of allocated registers

    // Instantiate the freelist module
    freelist #(
        .FREELIST_NUM(FREELIST_NUM),
        .ARCH_REG_SZ(ARCH_REG_SZ)
    ) uut (
        .clock(clock),
        .reset(reset),
        .dest_reg_request(dest_reg_request),
        .free_reg_request(free_reg_request),
        .enqueue_preg(enqueue_preg),
        .branch_mispredict(branch_mispredict),
        .arch_map_mispredict_input(arch_map_mispredict_input),
        .valid_preg(valid_preg),
        .dequeue_preg(dequeue_preg)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // 10 ns clock period
    end

    // Test sequence
    initial begin
        // Initialize inputs
        reset = 1;
        dest_reg_request = 0;
        free_reg_request = 0;
        enqueue_preg = '{0, 0, 0};
        branch_mispredict = 0;
        arch_map_mispredict_input = '{default: 6'd0};

        // Wait for reset to propagate
        #10;
        reset = 0;
        
        // Test 1: Allocate 2 registers
        dest_reg_request = 2;
        #10;
        $display("Test 1 - After allocating 2 registers:");
        $display("dequeue_preg: %d, %d", dequeue_preg[0], dequeue_preg[1]);
        $display("freelist_bitmap: %b", freelist_bitmap);

        // Test 2: Free the allocated registers
        free_reg_request = 2;
        enqueue_preg = '{dequeue_preg[0], dequeue_preg[1], 0};
        dest_reg_request = 0; // No allocation request
        #10;
        $display("Test 2 - After freeing the allocated registers:");
        $display("freelist_bitmap: %b", freelist_bitmap);
    
        // Test 3: Allocate 3 registers
        dest_reg_request = 2;
        #10;
        $display("Test 3 - After allocating 3 registers:");
        $display("dequeue_preg: %d, %d, %d", dequeue_preg[0], dequeue_preg[1], dequeue_preg[2]);
        $display("freelist_bitmap: %b", freelist_bitmap);

       // Initialize the architectural map input array with default values

    for (int i = 0; i < ARCH_REG_SZ; i++) begin
        arch_map_mispredict_input[i] = 6'd0;
    end


    // Test 4: Simulate branch mispredict with specific architectural map
    branch_mispredict = 1;
    #1; // Wait a small amount of time to apply the new values
    arch_map_mispredict_input[0] = 6'd5;
    arch_map_mispredict_input[1] = 6'd10;
    arch_map_mispredict_input[2] = 6'd15;
    arch_map_mispredict_input[3] = 6'd20;
    arch_map_mispredict_input[4] = 6'd25;
    arch_map_mispredict_input[5] = 6'd30;
    arch_map_mispredict_input[6] = 6'd35;
    arch_map_mispredict_input[7] = 6'd40;
    arch_map_mispredict_input[8] = 6'd45;
    arch_map_mispredict_input[9] = 6'd50;
    arch_map_mispredict_input[10] = 6'd55;
    arch_map_mispredict_input[11] = 6'd60;
    arch_map_mispredict_input[12] = 6'd61;
    arch_map_mispredict_input[13] = 6'd62;
    arch_map_mispredict_input[14] = 6'd63;

    #10;
    branch_mispredict = 0;
    $display("Test 4 - After branch mispredict with architectural map input:");
    $display("freelist_bitmap: %b", freelist_bitmap);


        // End of test
        $finish;
    end

endmodule
