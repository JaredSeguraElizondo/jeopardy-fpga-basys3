`timescale 1ns / 1ps

// Función  : Generador de onda cuadrada programable mediante un divisor
//            de reloj con toggle. Produce una frecuencia = CLK / (2 * max_count)
//
//            Para CLK = 16 MHz:
//              max_count = 16,000 → 500 Hz  (tono grave, incorrecto)
//              max_count =  8,000 → 1 kHz  (tono agudo, correcto)

module tone_generator #(
    parameter int MAX_COUNT = 16_000    
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic enable_i,              // Habilita la generación del tono
    output logic tone_o                 // Onda cuadrada a la frecuencia deseada
);

    logic [$clog2(MAX_COUNT)-1:0] counter;
    logic toggle;

    // Contador que cuenta hasta MAX_COUNT-1
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            counter <= '0;
            toggle  <= 1'b0;
        end else if (enable_i) begin
            if (counter == MAX_COUNT - 1) begin
                counter <= '0;
                toggle  <= ~toggle;     // Toggle cada vez que alcanza el máximo
            end else begin
                counter <= counter + 1'b1;
            end
        end else begin
            counter <= '0;
            toggle  <= 1'b0;            // Apagar cuando no está habilitado
        end
    end

    assign tone_o = toggle & enable_i;

endmodule