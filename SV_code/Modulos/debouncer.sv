`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 06:45:14 PM
// Design Name: 
// Module Name: debouncer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module button_debouncer #(parameter WIDTH = 3) (
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic [WIDTH-1:0] btn_async_i,
    output logic [WIDTH-1:0] btn_pulse_o
);

    localparam DEBOUNCE_MAX = 18'd160_000; // 10ms @ 16MHz

    logic [WIDTH-1:0] sync_1, sync_2;
    logic [WIDTH-1:0] stable, stable_reg;
    logic [17:0]      count;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sync_1     <= '0;
            sync_2     <= '0;
            stable     <= '0;
            stable_reg <= '0;
            count      <= '0;
        end else begin
            // 1. Doble FF para evitar metaestabilidad
            sync_1 <= btn_async_i;
            sync_2 <= sync_1;

            // 2. Contador anti-rebotes
            if (sync_2 == stable) begin
                count <= '0;
            end else begin
                count <= count + 1'b1;
                if (count >= DEBOUNCE_MAX) begin
                    stable <= sync_2;
                    count  <= '0;
                end
            end

            // 3. Registro para detector de flanco
            stable_reg <= stable;
        end
    end

    // Pulso de 1 ciclo en flanco de subida
    assign btn_pulse_o = stable & ~stable_reg;

endmodule