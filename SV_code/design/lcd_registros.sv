`timescale 1ns / 1ps

// Implementa los dos registros de 32 bits mapeados a memoria del
// periférico LCD, y el decodificador W1P (Write-1-to-Pulse) para
// los bits start, clear y home.
//
// Mapa de registros:
//   addr 2'b00 → REG_CONTROL
//     [0]  start (W1P) : inicia transacción con el byte/rs actuales
//     [1]  rs          : 0=comando, 1=dato de carácter
//     [2]  clear (W1P) : clear display + reset DDRAM
//     [3]  home  (W1P) : cursor a posición 0,0 sin borrar contenido
//     [8]  busy  (RO)  : 1 mientras el LCD está procesando
//     [9]  done  (RO)  : pulso de 1 ciclo al finalizar cada operación
//   addr 2'b01 → REG_DATOS
//     [7:0] data_byte  : byte ASCII o código de instrucción a enviar


module lcd_registros (
    input  logic        clk_i,
    input  logic        rst_i,

    // Interfaz de periférico 
    input  logic [1:0]  addr_i,
    input  logic        write_enable_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // Estado que escribe la FSM interna 
    input  logic        lcd_busy_i,
    input  logic        lcd_done_i,

    // Campos decodificados hacia el árbitro de comandos
    output logic        pulse_start_o,   // Pulso 1 ciclo: escritura de start=1
    output logic        pulse_clear_o,   // Pulso 1 ciclo: escritura de clear=1
    output logic        pulse_home_o,    // Pulso 1 ciclo: escritura de home=1
    output logic        rs_o,            // Valor actual del bit rs
    output logic [7:0]  data_byte_o      // Valor actual de data_byte
);

    // Registros internos
    logic [31:0] reg_control;
    logic [31:0] reg_datos;

    // Detección de flanco ascendente 
    logic prev_start, prev_clear, prev_home;

    assign pulse_start_o = reg_control[0] & ~prev_start;
    assign pulse_clear_o = reg_control[2] & ~prev_clear;
    assign pulse_home_o  = reg_control[3] & ~prev_home;

    // Escritura de registros
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            reg_control <= 32'd0;
            reg_datos   <= 32'd0;
            prev_start  <= 1'b0;
            prev_clear  <= 1'b0;
            prev_home   <= 1'b0;
        end else begin
            // Actualiza bits de estado RO desde la FSM
            reg_control[8] <= lcd_busy_i;
            reg_control[9] <= lcd_done_i;

            // Auto-clear de bits W1P un ciclo después de haber sido detectados
            if (pulse_start_o) reg_control[0] <= 1'b0;
            if (pulse_clear_o) reg_control[2] <= 1'b0;
            if (pulse_home_o)  reg_control[3] <= 1'b0;

            // Escritura desde la FSM principal del juego
            if (write_enable_i) begin
                case (addr_i)
                    2'b00: reg_control[3:0] <= wdata_i[3:0]; // solo bits W
                    2'b01: reg_datos        <= wdata_i;
                    default: ;
                endcase
            end

            // Actualizar prev para detección de flanco
            prev_start <= reg_control[0];
            prev_clear <= reg_control[2];
            prev_home  <= reg_control[3];
        end
    end

    // Lectura de registros 
    always_comb begin
        case (addr_i)
            2'b00:   rdata_o = reg_control;
            2'b01:   rdata_o = reg_datos;
            default: rdata_o = 32'd0;
        endcase
    end

    // Salidas de campos 
    assign rs_o        = reg_control[1];
    assign data_byte_o = reg_datos[7:0];

endmodule