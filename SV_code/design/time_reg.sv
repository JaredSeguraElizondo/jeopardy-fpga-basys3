module time_reg#(
    parameter FREQ  = 16_000_000,
    parameter TIME  = 30,
    parameter COUNT = $clog2(FREQ * TIME)
)(
    input  logic             clk,
    input  logic             rst,
    input  logic [COUNT-1:0] count, 
    input  logic             save_time_j1,
    input  logic             save_time_j2,
    output logic             R1_valid,
    output logic             R2_valid,
    output logic [COUNT-1:0] timestamp_j1,
    output logic [COUNT-1:0] timestamp_j2
);

logic [COUNT-1:0] count_reg_j1;
logic [COUNT-1:0] count_reg_j2;
logic R1_valid_reg,R2_valid_reg;

always_ff @( negedge clk ) begin
    if (rst)begin
        count_reg_j1 <= '0;
        count_reg_j2 <= '0;
        R1_valid_reg <= 1'b0;
        R2_valid_reg <= 1'b0;
    end
    else if (save_time_j1 && !R1_valid_reg) begin
        count_reg_j1 <= count;
        R1_valid_reg <= 1'b1; 
    end
    else if (save_time_j2 && !R2_valid_reg) begin
        count_reg_j2 <= count;
        R2_valid_reg <= 1'b1; 
    end
    else begin
        count_reg_j1 <= count_reg_j1;
        count_reg_j2 <= count_reg_j2;
        R1_valid_reg <= R1_valid_reg;
        R2_valid_reg <= R2_valid_reg;
    end
end

assign timestamp_j1 = count_reg_j1;
assign timestamp_j2 = count_reg_j2;
assign R1_valid     = R1_valid_reg;
assign R2_valid     = R2_valid_reg;

endmodule