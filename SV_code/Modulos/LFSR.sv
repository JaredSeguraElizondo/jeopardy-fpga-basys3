`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2026 04:53:43 PM
// Design Name: 
// Module Name: LFSR
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

module lfsr (
    input  logic       clk_i,
    input  logic       rst_i,
    output logic [7:0] rnd_o
);

    logic [7:0] lfsr_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            lfsr_reg <= 8'hA5; // Semilla inicial (no puede ser 0)
        end else begin
            // Feedback polinomial para 8 bits
            lfsr_reg <= {lfsr_reg[6:0], lfsr_reg[7] ^ lfsr_reg[5] ^ lfsr_reg[4] ^ lfsr_reg[3]};
        end
    end

    assign rnd_o = lfsr_reg;

endmodule