`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 06:52:00 PM
// Design Name: 
// Module Name: Display 7-Segmentos
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:\
/////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module display_7seg (
    input  logic        clk_i,       // Reloj de 16MHz
    input  logic        rst_i,
    input  logic [15:0] hex_data_i,
    output logic [6:0]  seg_o,
    output logic [3:0]  an_o
);

    logic [16:0] refresh_cnt; 
    logic [3:0]  digit;

    // 1. Contador Síncrono (Esto ROMPE cualquier bucle)
    always_ff @(posedge clk_i) begin
        if (rst_i) refresh_cnt <= 0;
        else       refresh_cnt <= refresh_cnt + 1;
    end

    // 2. Selector de Ánodo
    always_comb begin
        case (refresh_cnt[14:13])
            2'b00: begin an_o = 4'b1110; digit = hex_data_i[3:0];   end
            2'b01: begin an_o = 4'b1101; digit = hex_data_i[7:4];   end
            2'b10: begin an_o = 4'b1011; digit = hex_data_i[11:8];  end
            2'b11: begin an_o = 4'b0111; digit = hex_data_i[15:12]; end
            default: begin an_o = 4'b1111; digit = 4'h0; end
        endcase
    end

    // 3. Decodificador
    always_comb begin
        case (digit)
            4'h0: seg_o = 7'b1000000; 4'h1: seg_o = 7'b1111001;
            4'h2: seg_o = 7'b0100100; 4'h3: seg_o = 7'b0110000;
            4'h4: seg_o = 7'b0011001; 4'h5: seg_o = 7'b0010010;
            4'h6: seg_o = 7'b0000010; 4'h7: seg_o = 7'b1111000;
            4'h8: seg_o = 7'b0000000; 4'h9: seg_o = 7'b0010000;
            4'hA: seg_o = 7'b0001000; 4'hB: seg_o = 7'b0000011;
            4'hC: seg_o = 7'b1000110; 4'hD: seg_o = 7'b0100001;
            4'hE: seg_o = 7'b0000110; 4'hF: seg_o = 7'b0001110;
            default: seg_o = 7'b1111111;
        endcase
    end
endmodule