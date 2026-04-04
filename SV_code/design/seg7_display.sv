`timescale 1ns / 1ps
// Función  : Muestra el puntaje del jugador FPGA y el tiempo restante en los
//            cuatro displays de 7 segmentos de la Basys3, usando multiplexado
//            temporal a ~250 Hz de refresco por dígito.
//
// Distribución de dígitos:
//   AN3 → Decenas del puntaje   
//   AN2 → Unidades del puntaje  
//   AN1 → Decenas del tiempo    
//   AN0 → Unidades del tiempo   
//
// Hardware Basys3:
//   Ánodos    activos-bajos : seg_an_o[3:0]
//   Cátodos   activos-bajos : seg_cat_o[6:0] 
//                                                 
// Temporización (CLK = 16 MHz):
//   TICKS_MUX = 16 000 ciclos → ~1 ms por dígito → ~250 Hz de refresco total

module seg7_display (
    input  logic       clk_i,
    input  logic       rst_i,

    input  logic [7:0] puntaje_fpga_i,    // Puntaje jugador FPGA (0-7)
    input  logic [7:0] tiempo_restante_i, // Segundos restantes (0-30)

    output logic [3:0] seg_an_o,          // Ánodos  (activo-bajo)
    output logic [6:0] seg_cat_o          // Cátodos (activo-bajo)
);

    localparam int unsigned TICKS_MUX = 16_000;

    // Conversión binaria a BCD (valores acotados: puntaje ≤ 7, tiempo ≤ 30) ─
    logic [3:0] puntaje_dec, puntaje_uni;
    logic [3:0] tiempo_dec,  tiempo_uni;

    always_comb begin
        // Puntaje: máximo 7 rondas son siempre un solo dígito
        puntaje_dec = 4'd0;
        puntaje_uni = puntaje_fpga_i[3:0]; // nunca supera 9

        // Tiempo: 0-30 segundos
        if (tiempo_restante_i >= 8'd30) begin
            tiempo_dec = 4'd3; tiempo_uni = 4'd0;
        end else if (tiempo_restante_i >= 8'd20) begin
            tiempo_dec = 4'd2; tiempo_uni = tiempo_restante_i[3:0] - 4'd4;
        end else if (tiempo_restante_i >= 8'd10) begin
            tiempo_dec = 4'd1; tiempo_uni = tiempo_restante_i[3:0] - 4'd10;
        end else begin
            tiempo_dec = 4'd0; tiempo_uni = tiempo_restante_i[3:0];
        end
    end

    // Contador de multiplexado 
    logic [13:0] mux_cnt;
    logic [1:0]  digit_sel; // 0=AN3, 1=AN2, 2=AN1, 3=AN0

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            mux_cnt   <= '0;
            digit_sel <= 2'd0;
        end else if (mux_cnt == 14'(TICKS_MUX - 1)) begin
            mux_cnt   <= '0;
            digit_sel <= digit_sel + 1'b1;
        end else begin
            mux_cnt <= mux_cnt + 1'b1;
        end
    end

    // MUX de valor BCD activo 
    logic [3:0] digit_val;

    always_comb begin
        case (digit_sel)
            2'd0: digit_val = puntaje_dec; // AN3
            2'd1: digit_val = puntaje_uni; // AN2
            2'd2: digit_val = tiempo_dec;  // AN1
            2'd3: digit_val = tiempo_uni;  // AN0
            default: digit_val = 4'd0;
        endcase
    end

    // Decodificador de ánodos (activo-bajo)
    always_comb begin
        case (digit_sel)
            2'd0: seg_an_o = 4'b0111; // AN3 encendido
            2'd1: seg_an_o = 4'b1011; // AN2 encendido
            2'd2: seg_an_o = 4'b1101; // AN1 encendido
            2'd3: seg_an_o = 4'b1110; // AN0 encendido
            default: seg_an_o = 4'b1111;
        endcase
    end

    // Decodificador BCD → 7 segmentos (cátodos activos-bajos) ──────────────
    // Orden de bits: {CA(a), CB(b), CC(c), CD(d), CE(e), CF(f), CG(g)}
    always_comb begin
        case (digit_val)
            //                   abcdefg
            4'd0: seg_cat_o = 7'b0000001; // 0 → a,b,c,d,e,f ON  | g OFF
            4'd1: seg_cat_o = 7'b1001111; // 1 → b,c ON
            4'd2: seg_cat_o = 7'b0010010; // 2 → a,b,d,e,g ON
            4'd3: seg_cat_o = 7'b0000110; // 3 → a,b,c,d,g ON
            4'd4: seg_cat_o = 7'b1001100; // 4 → b,c,f,g ON
            4'd5: seg_cat_o = 7'b0100100; // 5 → a,c,d,f,g ON
            4'd6: seg_cat_o = 7'b0100000; // 6 → a,c,d,e,f,g ON
            4'd7: seg_cat_o = 7'b0001111; // 7 → a,b,c ON
            4'd8: seg_cat_o = 7'b0000000; // 8 → todos ON
            4'd9: seg_cat_o = 7'b0000100; // 9 → a,b,c,d,f,g ON
            default: seg_cat_o = 7'b1111111; // apagado
        endcase
    end

endmodule