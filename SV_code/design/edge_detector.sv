
// Función  : Detecta flancos positivos en una señal de entrada y genera
//            un pulso de un ciclo de reloj.
//
// Convierte pulsos de respuesta (correcta/incorrecta) en
//             solicitudes de un ciclo para la FSM.


`timescale 1ns / 1ps
module edge_detector (
    input  logic clk_i,
    input  logic rst_i,
    input  logic signal_i,
    output logic pulse_o
);

    logic signal_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            signal_reg <= 1'b0;
        end else begin
            signal_reg <= signal_i;
        end
    end

    assign pulse_o = signal_i & ~signal_reg;

endmodule