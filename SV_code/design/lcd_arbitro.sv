`timescale 1ns / 1ps

// Función  : Árbitro entre las fuentes de comandos al LCD.
//            Prioridad: clear > home > start (manual FSM) > auto-escritor
//
//            Recibe los pulsos W1P del módulo de registros y la solicitud
//            del auto-escritor, y genera una única solicitud (cmd_req_o)
//            con el tipo, RS y dato correspondientes hacia la FSM del LCD.
//
// Tipos de comando (cmd_type_o):
//   2'd0 → dato/comando genérico  (usa rs y data del bus)
//   2'd1 → clear display          (0x01, RS=0)
//   2'd2 → return home            (0x02, RS=0)


module lcd_arbitro (
    input  logic        clk_i,
    input  logic        rst_i,

    // Desde lcd_registros (pulsos W1P)
    input  logic        pulse_start_i,
    input  logic        pulse_clear_i,
    input  logic        pulse_home_i,
    input  logic        rs_i,          // rs actual del registro CONTROL
    input  logic [7:0]  data_byte_i,   // data_byte actual del registro DATOS

    // Desde lcd_auto_escritor
    input  logic        auto_req_i,
    input  logic        auto_rs_i,
    input  logic [7:0]  auto_data_i,

    // Estado de la FSM del LCD 
    input  logic        lcd_busy_i,

    // Hacia lcd_fsm 
    output logic        cmd_req_o,
    output logic [1:0]  cmd_type_o,
    output logic        cmd_rs_o,
    output logic [7:0]  cmd_data_o
);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            cmd_req_o  <= 1'b0;
            cmd_type_o <= 2'd0;
            cmd_rs_o   <= 1'b0;
            cmd_data_o <= 8'd0;
        end else begin
            cmd_req_o <= 1'b0; // default: sin solicitud

            // Solo arbitrar si el LCD está libre
            if (!lcd_busy_i) begin
                if (pulse_clear_i) begin
                    cmd_req_o  <= 1'b1;
                    cmd_type_o <= 2'd1;
                    cmd_rs_o   <= 1'b0;
                    cmd_data_o <= 8'h01;
                end else if (pulse_home_i) begin
                    cmd_req_o  <= 1'b1;
                    cmd_type_o <= 2'd2;
                    cmd_rs_o   <= 1'b0;
                    cmd_data_o <= 8'h02;
                end else if (pulse_start_i) begin
                    cmd_req_o  <= 1'b1;
                    cmd_type_o <= 2'd0;
                    cmd_rs_o   <= rs_i;
                    cmd_data_o <= data_byte_i;
                end else if (auto_req_i) begin
                    cmd_req_o  <= 1'b1;
                    cmd_type_o <= 2'd0;
                    cmd_rs_o   <= auto_rs_i;
                    cmd_data_o <= auto_data_i;
                end
            end
        end
    end

endmodule
