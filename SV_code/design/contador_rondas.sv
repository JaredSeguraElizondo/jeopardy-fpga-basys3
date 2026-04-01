module contador_rondas #(
    parameter RONDAS = 7,
    parameter COUNT  = $clog2(RONDAS)
)(
    input  logic            clk,
    input  logic            rst,
    input  logic            en,
    output logic            game_done,
    output logic [COUNT-1:0] ronda
);

    logic [COUNT-1:0] ronda_reg;

    always_ff @(negedge clk) begin
        if (rst) begin
            ronda_reg <= '0;
        end else if (en && !game_done) begin
            if (ronda_reg == RONDAS - 1)
                ronda_reg <= ronda_reg; // se congela en el máximo
            else
                ronda_reg <= ronda_reg + 1'b1;
        end
    end

    assign ronda     = ronda_reg;
    assign game_done = (ronda_reg == RONDAS - 1 );

endmodule