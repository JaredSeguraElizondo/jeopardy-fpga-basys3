`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 06:54:06 PM
// Design Name: 
// Module Name: pwm_buzzer
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

module pwm_buzzer (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        en_i,
    input  logic [15:0] period_i,
    output logic        pwm_o
);

    logic [15:0] count;
    logic        pwm_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            count   <= '0;
            pwm_reg <= 1'b0;
        end else if (en_i) begin
            if (count >= period_i) begin
                count   <= '0;
                pwm_reg <= ~pwm_reg;
            end else begin
                count <= count + 1'b1;
            end
        end else begin
            count   <= '0;
            pwm_reg <= 1'b0;
        end
    end

    assign pwm_o = pwm_reg;

endmodule