module cdb#(parameter CDB_SZ = `PHYS_REG_BITS)(
    input logic [`PHYS_REG_BITS - 1:0] physTagIn,
    input logic validInputTag, clock, reset,
    output logic [`PHYS_REG_BITS - 1:0] physTagOut,
    output logic validOutputTag
);

always_ff @(posedge clock)begin
    if(reset)begin
        physTagOut <= '0;
        validOutputTag <= 0;
    end else begin
        if(validInputTag)begin
            physTagOut <= physTagIn;
            validOutputTag <= 1;
        end else begin
            physTagOut <= '0;
            validOutputTag <= 0;
        end
    end
end

endmodule