`timescale 1ns / 1ps
// Función  : Cuando la FSM del juego activa mostrar_pregunta_i o
//            mostrar_opciones_i, este módulo vuelca automáticamente el
//            string de 16 caracteres al LCD (8 chars en línea 1,
//            8 chars en línea 2), liberando a la FSM principal de
//            tener que hacer polling byte a byte.
//
// Formato del string de 128 bits (pregunta_str_i / opciones_str_i):
//   [127:120] = char 0  (primer carácter, línea 1)
//   [119:112] = char 1
//      ...
//   [ 63: 56] = char 8  (primer carácter, línea 2)
//      ...
//   [  7:  0] = char 15 (último carácter, línea 2)
//
// Secuencia de escritura:
//   1. Clear Display (0x01)
//   2. Chars 0-7  → línea 1 (DDRAM 0x00-0x07)
//   3. Set DDRAM  → 0xC0 (inicio línea 2)
//   4. Chars 8-15 → línea 2 (DDRAM 0x40-0x47)
// =============================================================================

module lcd_auto_escritor (
    input  logic        clk_i,
    input  logic        rst_i,

    // Control desde FSM del juego 
    input  logic        mostrar_pregunta_i,
    input  logic        mostrar_opciones_i,
    input  logic [127:0] pregunta_str_i,
    input  logic [127:0] opciones_str_i,

    // Asociación con el árbitro / FSM del LCD 
    input  logic        lcd_busy_i,    // LCD ocupado
    input  logic        lcd_done_i,    // Pulso fin de operación
    // También bloquea si el árbitro ya tiene solicitud pendiente
    input  logic        cmd_req_busy_i,// 1 si el árbitro ya generó cmd_req

    // Solicitud al árbitro 
    output logic        auto_req_o,
    output logic        auto_rs_o,
    output logic [7:0]  auto_data_o
);

    // Estados 
    typedef enum logic [2:0] {
        AW_IDLE,
        AW_CLEAR,      // Enviar Clear Display
        AW_WAIT_CLEAR, // Esperar done del clear
        AW_LINE1,      // Enviar chars 0-7 (línea 1)
        AW_SETLINE2,   // Enviar Set DDRAM 0xC0
        AW_WAIT_SET2,  // Esperar done del set DDRAM
        AW_LINE2,      // Enviar chars 8-15 (línea 2)
        AW_DONE        // Esperar a que se desactive la señal de control
    } aw_state_t;

    aw_state_t    aw_state;
    logic [127:0] str_buf;   // Copia del string activo
    logic [3:0]   char_idx;  // Índice del carácter en curso (0-7 por línea)

    // FSM 
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            aw_state   <= AW_IDLE;
            auto_req_o  <= 1'b0;
            auto_rs_o   <= 1'b0;
            auto_data_o <= 8'd0;
            char_idx    <= 4'd0;
            str_buf     <= 128'd0;
        end else begin
            auto_req_o <= 1'b0; // default: sin solicitud

            case (aw_state)

                AW_IDLE: begin
                    if (mostrar_pregunta_i || mostrar_opciones_i) begin
                        str_buf  <= mostrar_pregunta_i ? pregunta_str_i
                                                       : opciones_str_i;
                        aw_state <= AW_CLEAR;
                    end
                end

                // Clear display 
                AW_CLEAR: begin
                    if (!lcd_busy_i && !cmd_req_busy_i) begin
                        auto_rs_o   <= 1'b0;
                        auto_data_o <= 8'h01; // Clear Display
                        auto_req_o  <= 1'b1;
                        aw_state    <= AW_WAIT_CLEAR;
                    end
                end

                AW_WAIT_CLEAR: begin
                    if (lcd_done_i) begin
                        char_idx <= 4'd0;
                        aw_state <= AW_LINE1;
                    end
                end

                // Línea 1: chars 0-7 
                AW_LINE1: begin
                    if (char_idx == 4'd8) begin
                        aw_state <= AW_SETLINE2;
                    end else if (!lcd_busy_i && !cmd_req_busy_i) begin
                        auto_rs_o   <= 1'b1;
                        auto_data_o <= str_buf[127 - (char_idx * 8) -: 8];
                        auto_req_o  <= 1'b1;
                        char_idx    <= char_idx + 1'b1;
                    end
                end

                // Posicionar cursor en línea 2 (DDRAM 0x40)
                AW_SETLINE2: begin
                    if (!lcd_busy_i && !cmd_req_busy_i) begin
                        auto_rs_o   <= 1'b0;
                        auto_data_o <= 8'hC0; // Set DDRAM address = 0x40
                        auto_req_o  <= 1'b1;
                        aw_state    <= AW_WAIT_SET2;
                    end
                end

                AW_WAIT_SET2: begin
                    if (lcd_done_i) begin
                        char_idx <= 4'd0;
                        aw_state <= AW_LINE2;
                    end
                end

                // Línea 2: chars 8-15 
                AW_LINE2: begin
                    if (char_idx == 4'd8) begin
                        aw_state <= AW_DONE;
                    end else if (!lcd_busy_i && !cmd_req_busy_i) begin
                        auto_rs_o   <= 1'b1;
                        // char 8 : bits [63:56], char 9 : [55:48], etc.
                        auto_data_o <= str_buf[63 - (char_idx * 8) -: 8];
                        auto_req_o  <= 1'b1;
                        char_idx    <= char_idx + 1'b1;
                    end
                end

                // Fin: esperar que la FSM desactive la señal
                AW_DONE: begin
                    if (!mostrar_pregunta_i && !mostrar_opciones_i)
                        aw_state <= AW_IDLE;
                end

                default: aw_state <= AW_IDLE;
            endcase
        end
    end

endmodule
