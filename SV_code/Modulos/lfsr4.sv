module lfsr4 (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       en_i,
    input  logic [3:0] seed_i,
    input  logic       load_i,
    output logic [3:0] q_o
);

    logic [3:0] lfsr_reg;
    logic       feedback;

    assign feedback = lfsr_reg[3] ^ lfsr_reg[2];

    always_ff @(posedge clk_i) begin
        if (rst_i)
            lfsr_reg <= 4'b1001;
        else if (load_i)
            lfsr_reg <= (seed_i == 4'b0) ? 4'b1001 : seed_i;
        else if (en_i)
            lfsr_reg <= {lfsr_reg[2:0], feedback};
    end

    assign q_o = lfsr_reg;

endmodule