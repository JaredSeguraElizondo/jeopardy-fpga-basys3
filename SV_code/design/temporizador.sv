module temporizador #(
    parameter FREQ  = 16_000_000,
    parameter TIME  = 30,
    parameter COUNT = $clog2(FREQ * TIME)
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             en,
    output logic             timeout,
    output logic [COUNT-1:0] count
);

    logic [COUNT-1:0] count_reg;

    always_ff @(negedge clk) begin
        if (rst) begin
            count_reg <= '0;
        end 
        else if (en) begin
            if (count_reg == (FREQ * TIME) - 1)
                count_reg <= '0;
            else
                count_reg <= count_reg + 1'b1;
        end
    end

    assign count   = count_reg;
    assign timeout = en && (count_reg == (FREQ * TIME) - 1);

endmodule