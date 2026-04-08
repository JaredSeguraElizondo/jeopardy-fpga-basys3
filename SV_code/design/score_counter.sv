// score_counter.sv
// Contadores de rondas ganadas por cada jugador.
// Se incrementan con los pulsos wins_j1 / wins_j2 provenientes de la Main FSM.
// El ancho W es parametrizable segun el numero maximo de rondas (7 rondas -> 3 bits).

module score_counter #(
    parameter W = 3  // $clog2(7) = 3 bits
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       win_j1,       // Pulso: J1 gano la ronda (resultado_eval == 01)
    input  logic       win_j2,       // Pulso: J2 gano la ronda (resultado_eval == 10)
    output logic [W-1:0] score_j1,
    output logic [W-1:0] score_j2
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            score_j1 <= '0;
            score_j2 <= '0;
        end
        else begin
            if (win_j1) score_j1 <= score_j1 + 1'b1;
            if (win_j2) score_j2 <= score_j2 + 1'b1;
        end
    end

endmodule