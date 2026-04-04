`timescale 1ns / 1ps

// Función  : Controla el LCD HD44780 (PmodCLP) en modo 8 bits.
//            Ejecuta la secuencia de inicialización al arranque y luego
//            atiende solicitudes de escritura (comando o dato) con los
//            retardos correctos exigidos por el datasheet.
//
// Temporización (CLK = 16 MHz → 62.5 ns/ciclo):
//   Power-up wait : 15   ms son 240 000 ciclos
//   Entre init cmds: 4.1 ms son  64 000 ciclos
//   Cmd estándar  : 100  µs son   1 600 ciclos
//   Clear / Home  : 1.64 ms son 26 240 ciclos
//   Pulso Enable  : 750  ns son     12 ciclos  
//
// Salidas físicas al PmodCLP:
//   lcd_db_o[7:0]  = DB7..DB0 (bus de datos, modo 8 bits)
//   lcd_e_o        = Enable   (pulso activo-alto)
//   lcd_rs_o       = RS       (0=comando, 1=dato)
//   lcd_rw_o       = RW       (siempre 0, modo escritura)


module lcd_fsm (
    input  logic        clk_i,
    input  logic        rst_i,

    // Solicitud de comando desde el árbitro 
    input  logic        cmd_req_i,     // Pulso 1 ciclo: hay comando pendiente
    input  logic [1:0]  cmd_type_i,    // 2'd0=dato/cmd, 2'd1=clear, 2'd2=home
    input  logic        cmd_rs_i,      // RS del comando solicitado
    input  logic [7:0]  cmd_data_i,    // Byte del comando solicitado

    // Estado hacia los registros y árbitro 
    output logic        lcd_busy_o,    // 1 mientras se ejecuta una operación
    output logic        lcd_done_o,    // Pulso 1 ciclo al finalizar

    // Salidas físicas al LCD 
    output logic [7:0]  lcd_db_o,
    output logic        lcd_e_o,
    output logic        lcd_rs_o,
    output logic        lcd_rw_o
);

    // Parámetros de temporización
    localparam int unsigned TICKS_15MS   = 240_000;
    localparam int unsigned TICKS_4MS    =  64_000;
    localparam int unsigned TICKS_100US  =   1_600;
    localparam int unsigned TICKS_1640US =  26_240;
    localparam int unsigned TICKS_ENABLE =      12;

    // Temporizador interno 
    logic [17:0] timer_cnt;
    logic [17:0] timer_load;
    logic        timer_start;
    logic        timer_done;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            timer_cnt <= 18'(TICKS_15MS - 1);
        end else if (timer_start) begin
            timer_cnt <= timer_load;
        end else if (timer_cnt != '0) begin
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
    assign timer_done = (timer_cnt == '0);

    // Estados de la FSM (5 bits para tener suficiente espacio)
    typedef enum logic [4:0] {
        S_POWER_WAIT = 5'd0,
        S_I1_PULSE   = 5'd1,
        S_I1_WAIT    = 5'd2,
        S_I2_PULSE   = 5'd3,
        S_I2_WAIT    = 5'd4,
        S_I3_PULSE   = 5'd5,
        S_I3_WAIT    = 5'd6,
        S_DON_PULSE  = 5'd7,
        S_DON_WAIT   = 5'd8,
        S_CLR_PULSE  = 5'd9,
        S_CLR_WAIT   = 5'd10,
        S_ENT_PULSE  = 5'd11,
        S_ENT_WAIT   = 5'd12,
        S_IDLE       = 5'd13,
        S_SETUP      = 5'd14,
        S_EN_HI      = 5'd15,
        S_EN_LO      = 5'd16,
        S_DONE       = 5'd17
    } lcd_state_t;

    lcd_state_t lcd_state;

    // Registros de salida 
    logic [7:0]  db_r;
    logic        e_r, rs_r;

    // Latch del comando en curso (para mantener bus estable durante envío)
    logic [1:0]  cmd_type_lat;
    logic        cmd_rs_lat;
    logic [7:0]  cmd_data_lat;

    // FSM 
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            lcd_state    <= S_POWER_WAIT;
            lcd_busy_o   <= 1'b1;
            lcd_done_o   <= 1'b0;
            db_r         <= 8'd0;
            e_r          <= 1'b0;
            rs_r         <= 1'b0;
            timer_load   <= 18'(TICKS_15MS - 1);
            timer_start  <= 1'b1;
            cmd_type_lat <= 2'd0;
            cmd_rs_lat   <= 1'b0;
            cmd_data_lat <= 8'd0;
        end else begin
            // Defaults de 1 ciclo
            timer_start <= 1'b0;
            lcd_done_o  <= 1'b0;

            case (lcd_state)

                // Secuencia de inicialización 

                S_POWER_WAIT: begin
                    if (timer_done) begin
                        db_r <= 8'h38; rs_r <= 1'b0; e_r <= 1'b1;
                        timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                        lcd_state  <= S_I1_PULSE;
                    end
                end

                S_I1_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_4MS - 1); timer_start <= 1'b1;
                    lcd_state  <= S_I1_WAIT;
                end

                S_I1_WAIT: if (timer_done) begin
                    db_r <= 8'h38; e_r <= 1'b1;
                    timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                    lcd_state  <= S_I2_PULSE;
                end

                S_I2_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_100US - 1); timer_start <= 1'b1;
                    lcd_state  <= S_I2_WAIT;
                end

                S_I2_WAIT: if (timer_done) begin
                    db_r <= 8'h38; e_r <= 1'b1;
                    timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                    lcd_state  <= S_I3_PULSE;
                end

                S_I3_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_100US - 1); timer_start <= 1'b1;
                    lcd_state  <= S_I3_WAIT;
                end

                S_I3_WAIT: if (timer_done) begin
                    db_r <= 8'h0E; e_r <= 1'b1;   // Display ON, cursor ON
                    timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                    lcd_state  <= S_DON_PULSE;
                end

                S_DON_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_100US - 1); timer_start <= 1'b1;
                    lcd_state  <= S_DON_WAIT;
                end

                S_DON_WAIT: if (timer_done) begin
                    db_r <= 8'h01; e_r <= 1'b1;   // Clear Display
                    timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                    lcd_state  <= S_CLR_PULSE;
                end

                S_CLR_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_1640US - 1); timer_start <= 1'b1;
                    lcd_state  <= S_CLR_WAIT;
                end

                S_CLR_WAIT: if (timer_done) begin
                    db_r <= 8'h06; e_r <= 1'b1;   // Entry Mode: inc, no shift
                    timer_load <= 18'(TICKS_ENABLE - 1); timer_start <= 1'b1;
                    lcd_state  <= S_ENT_PULSE;
                end

                S_ENT_PULSE: if (timer_done) begin
                    e_r <= 1'b0;
                    timer_load <= 18'(TICKS_100US - 1); timer_start <= 1'b1;
                    lcd_state  <= S_ENT_WAIT;
                end

                S_ENT_WAIT: if (timer_done) begin
                    lcd_busy_o <= 1'b0;
                    lcd_state  <= S_IDLE;
                end

                // Operación normal 

                S_IDLE: begin
                    lcd_busy_o <= 1'b0;
                    e_r        <= 1'b0;
                    if (cmd_req_i) begin
                        // Latchar comando para mantener bus estable
                        cmd_type_lat <= cmd_type_i;
                        cmd_rs_lat   <= cmd_rs_i;
                        cmd_data_lat <= cmd_data_i;
                        lcd_busy_o   <= 1'b1;
                        db_r         <= cmd_data_i;
                        rs_r         <= cmd_rs_i;
                        timer_load   <= 18'(TICKS_ENABLE - 1);
                        timer_start  <= 1'b1;
                        lcd_state    <= S_SETUP;
                    end
                end

                // Bus estable (E=0) antes de subir Enable
                S_SETUP: if (timer_done) begin
                    e_r        <= 1'b1;
                    timer_load <= 18'(TICKS_ENABLE - 1);
                    timer_start <= 1'b1;
                    lcd_state  <= S_EN_HI;
                end

                // Enable = 1 durante TICKS_ENABLE
                S_EN_HI: if (timer_done) begin
                    e_r <= 1'b0;
                    // Tiempo de ejecución depende del tipo de comando
                    case (cmd_type_lat)
                        2'd1:    timer_load <= 18'(TICKS_1640US - 1); // clear
                        2'd2:    timer_load <= 18'(TICKS_1640US - 1); // home
                        default: timer_load <= 18'(TICKS_100US  - 1); // estándar
                    endcase
                    timer_start <= 1'b1;
                    lcd_state   <= S_EN_LO;
                end

                // Esperar ejecución del comando en el LCD
                S_EN_LO: if (timer_done) begin
                    lcd_state <= S_DONE;
                end

                // Pulso done de 1 ciclo pasa volver a IDLE
                S_DONE: begin
                    lcd_done_o <= 1'b1;
                    lcd_busy_o <= 1'b0;
                    lcd_state  <= S_IDLE;
                end

                default: lcd_state <= S_IDLE;
            endcase
        end
    end

    // Asignación de salidas físicas
    assign lcd_db_o = db_r;
    assign lcd_e_o  = e_r;
    assign lcd_rs_o = rs_r;
    assign lcd_rw_o = 1'b0;  // Siempre escritura

endmodule