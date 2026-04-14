`timescale 1ns / 1ps

module game_core (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [2:0]  btn_pulse_i,

    output logic [15:0] hex_data_o,
    output logic        sound_play_o,
    output logic        sound_correct_o,

    output logic        uart_we_o,
    output logic [1:0]  uart_addr_o,
    output logic [31:0] uart_wdata_o,
    input  logic [31:0] uart_rdata_i,

    output logic        lcd_we_o,
    output logic [1:0]  lcd_addr_o,
    output logic [31:0] lcd_wdata_o,
    input  logic [31:0] lcd_rdata_i,

    input  logic [7:0]  char_i,
    input  logic [1:0]  tipo_i,
    input  logic        fin_bloque_i,
    output logic        next_char_o,
    output logic        marcar_usada_o,

    input  logic [3:0]  pregunta_sel_i,
    input  logic        q_valid_i,
    output logic        solicitar_o,
    output logic        confirmar_o
);

    localparam logic [7:0] INIT_CMDS [0:3] = '{8'h38, 8'h0C, 8'h06, 8'h01};
    localparam logic [7:0] MSG_L1 [0:15] = '{
        "P","u","l","s","a"," ","A","r","r","i","b","a"," ","-",">"," "};
    localparam logic [7:0] MSG_L2 [0:15] = '{
        "o"," ","'","3","'"," ","e","n"," ","P","C"," "," "," "," "," "};

    typedef enum logic [4:0] {
        ST_BOOT       = 5'd0,
        ST_INIT_D     = 5'd1,  ST_INIT_C    = 5'd2,  ST_INIT_W    = 5'd3,
        ST_IDLE       = 5'd4,
        ST_IDLE_CLR   = 5'd5,  // limpiar UART al entrar a IDLE
        ST_WAIT_Q     = 5'd6,  ST_CONFIRM_Q = 5'd7,
        ST_ROM_WAIT   = 5'd8,  ST_READ_ROM  = 5'd9,
        ST_ROM_LAST   = 5'd10, // esperar latencia ROM
        ST_ROM_LAST2  = 5'd25, // capturar byte 64 (respuesta correcta)
        ST_TX_IDX_W   = 5'd11, ST_TX_IDX_L  = 5'd12, ST_TX_IDX_S  = 5'd13,
        ST_REFRESH_D  = 5'd14, ST_REFRESH_C = 5'd15, ST_REFRESH_W = 5'd16,
        ST_PLAYING    = 5'd17,
        ST_RESULT     = 5'd18,
        ST_GAME_OVER  = 5'd19,
        ST_UART_READ  = 5'd20, ST_UART_CLR  = 5'd21,
        ST_TX_WAIT    = 5'd22, ST_TX_LOAD   = 5'd23, ST_TX_START  = 5'd24
    } state_t;

    state_t state_reg, state_next, return_state, tx_return_state;

    logic [1:0]  fpga_sel_idx, pc_sel_idx;
    logic [7:0]  score_fpga, score_pc, timer_val;
    logic        view_mode, is_in_menu;
    logic [2:0]  round_cnt;
    logic        last_ans_correct, pc_ok_pressed, pc_sel_changed;
    logic        fpga_respondio, pc_respondio;  // flags de respuesta en ronda actual
    logic        fpga_fue_primero; // 1 si FPGA respondio antes que PC
    logic [7:0]  tx_byte;

    logic [7:0]  buf_enunciado [0:31];
    logic [7:0]  buf_opciones  [0:31];
    logic [6:0]  buf_idx;
    logic        buf_ready;
    logic [7:0]  respuesta_correcta;

    logic [26:0] sec_cnt;
    logic [27:0] auto_start_cnt;
    logic [17:0] delay_cnt;
    logic [5:0]  sweep_idx;
    logic [2:0]  init_idx;

    logic        solicitar_reg;
    assign solicitar_o = solicitar_reg;
    logic [7:0]  rx_char;

    logic [7:0] fpga_ans_char, pc_ans_char;
    assign fpga_ans_char = (fpga_sel_idx == 2'd0) ? "A" :
                           (fpga_sel_idx == 2'd1) ? "B" :
                           (fpga_sel_idx == 2'd2) ? "C" : "D";
    assign pc_ans_char   = (pc_sel_idx   == 2'd0) ? "A" :
                           (pc_sel_idx   == 2'd1) ? "B" :
                           (pc_sel_idx   == 2'd2) ? "C" : "D";

    logic fpga_is_correct, pc_is_correct;
    assign fpga_is_correct = buf_ready && (fpga_ans_char == respuesta_correcta);
    assign pc_is_correct   = buf_ready && (pc_ans_char   == respuesta_correcta);

    assign hex_data_o     = {score_fpga[3:0], score_pc[3:0],
                             timer_val[7:4],  timer_val[3:0]};
    assign confirmar_o    = (state_reg == ST_CONFIRM_Q) ? 1'b1 : 1'b0;
    assign marcar_usada_o = (state_reg == ST_CONFIRM_Q) ? 1'b1 : 1'b0;
    // next_char_o sube en ST_ROM_WAIT: ROM actualiza char_i en el ciclo siguiente
    assign next_char_o    = (state_reg == ST_ROM_WAIT)  ? 1'b1 : 1'b0;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_reg          <= ST_BOOT;
            score_fpga         <= 0;   score_pc       <= 0;
            round_cnt          <= 0;
            is_in_menu         <= 1;   timer_val      <= 8'h30;
            fpga_sel_idx       <= 0;   pc_sel_idx     <= 0;
            view_mode          <= 0;
            pc_ok_pressed      <= 0;   pc_sel_changed <= 0;
            fpga_respondio     <= 0;   pc_respondio   <= 0;
            fpga_fue_primero   <= 0;
            last_ans_correct   <= 0;
            sec_cnt            <= 0;   auto_start_cnt <= 0;
            delay_cnt          <= 0;   sweep_idx      <= 0;
            init_idx           <= 0;
            buf_idx            <= 0;   buf_ready      <= 0;
            respuesta_correcta <= "A";
            tx_byte            <= 0;
            return_state       <= ST_IDLE;
            tx_return_state    <= ST_IDLE;
            rx_char            <= 0;
            solicitar_reg      <= 0;
        end else begin
            state_reg     <= state_next;
            solicitar_reg <= 0;

            if (state_reg == ST_IDLE    ||
                state_reg == ST_PLAYING ||
                state_reg == ST_GAME_OVER)
                return_state <= state_reg;

            // Timer BCD descendente
            if (sec_cnt >= 27'd15_999_999) begin
                sec_cnt <= 0;
                if (state_reg == ST_PLAYING && timer_val > 0) begin
                    if (timer_val[3:0] == 0) begin
                        timer_val[3:0] <= 9;
                        timer_val[7:4] <= timer_val[7:4] - 1;
                    end else
                        timer_val[3:0] <= timer_val[3:0] - 1;
                end
            end else
                sec_cnt <= sec_cnt + 1;

            if (state_reg == ST_IDLE || is_in_menu)
                timer_val <= 8'h30;

            // Lectura UART
            if (state_reg == ST_UART_READ) begin
                rx_char = uart_rdata_i[7:0];
                if (return_state == ST_IDLE || return_state == ST_GAME_OVER) begin
                    if (rx_char == "3") pc_ok_pressed <= 1'b1;
                end
                if (return_state == ST_PLAYING) begin
                    if (rx_char == "A") begin pc_sel_idx <= 0; pc_sel_changed <= 1; pc_ok_pressed <= 1; end
                    if (rx_char == "B") begin pc_sel_idx <= 1; pc_sel_changed <= 1; pc_ok_pressed <= 1; end
                    if (rx_char == "C") begin pc_sel_idx <= 2; pc_sel_changed <= 1; pc_ok_pressed <= 1; end
                    if (rx_char == "D") begin pc_sel_idx <= 3; pc_sel_changed <= 1; pc_ok_pressed <= 1; end
                end
            end

            // Captura ROM
            // ST_ROM_WAIT: next_char_o=1, contador avanza al final del ciclo
            // ST_READ_ROM: char_i = byte[contador-1] (latencia 1 ciclo de la ROM)
            //              capturamos bytes 0-63 normalmente
            //              cuando fin_bloque_i=1 (contador==64), char_i = byte[63]
            //              todavia NO es el byte 64
            // ST_ROM_LAST: un ciclo extra sin next_char_o, ahora char_i = byte[64]
            //              aqui capturamos la respuesta correcta
            if (state_reg == ST_READ_ROM) begin
                if (!fin_bloque_i) begin
                    // Bytes 0-63
                    if (tipo_i == 2'b00 && buf_idx < 7'd32)
                        buf_enunciado[buf_idx[4:0]] <= char_i;
                    else if (tipo_i == 2'b01 && buf_idx >= 7'd32 && buf_idx < 7'd64)
                        buf_opciones[buf_idx[4:0]] <= char_i;
                    buf_idx <= buf_idx + 1;
                end
                // Si fin_bloque_i=1 no capturamos aqui, lo hacemos en ST_ROM_LAST
            end

            // ST_ROM_LAST:  addr=64 presentada, ROM procesando (1 ciclo latencia)
            // ST_ROM_LAST2: char_i = byte[64] = respuesta correcta
            if (state_reg == ST_ROM_LAST2) begin
                respuesta_correcta <= char_i;
                buf_idx            <= 0;
                buf_ready          <= 1;
            end

            if (state_reg == ST_CONFIRM_Q) begin
                buf_idx   <= 0;
                buf_ready <= 0;
            end

            // IDLE: preparar inicio de ronda
            if (state_reg == ST_IDLE && (btn_pulse_i[2] || pc_ok_pressed)) begin
                is_in_menu      <= 0;
                pc_ok_pressed   <= 0;
                tx_return_state <= ST_REFRESH_D;
            end
            // Generar pulso de 1 ciclo al ENTRAR a ST_WAIT_Q
            // (cuando state_reg todavia es ST_IDLE pero state_next ya es ST_WAIT_Q)
            if (state_reg == ST_IDLE && state_next == ST_WAIT_Q)
                solicitar_reg <= 1'b1;

            // Playing
            if (state_reg == ST_PLAYING) begin
                if (btn_pulse_i[0]) fpga_sel_idx <= fpga_sel_idx + 1;
                if (btn_pulse_i[1]) view_mode    <= ~view_mode;

                // Registrar respuesta de FPGA (solo la primera vez)
                if (btn_pulse_i[2] && !fpga_respondio) begin
                    fpga_respondio  <= 1'b1;
                    // FPGA fue primero si PC aun no habia respondido
                    if (!pc_respondio) fpga_fue_primero <= 1'b1;
                end

                // Registrar respuesta de PC (solo la primera vez)
                if (pc_ok_pressed && !pc_respondio) begin
                    pc_respondio  <= 1'b1;
                    pc_ok_pressed <= 0;
                end

                // Terminar cuando ambos respondieron O se acabo el tiempo
                if (((fpga_respondio || btn_pulse_i[2]) && pc_respondio) || timer_val == 0) begin
                    // Solo gana el punto quien respondio primero Y acerto
                    // Si solo uno respondio (timeout), gana si acerto
                    // fpga_fue_primero=1: FPGA respondio antes que PC
                    // fpga_fue_primero=0: PC respondio antes que FPGA
                    if (timer_val == 0) begin
                        // Timeout: gana quien acerto (independiente)
                        if ((fpga_respondio || btn_pulse_i[2]) && fpga_is_correct)
                            score_fpga <= score_fpga + 1;
                        if (pc_respondio && pc_is_correct)
                            score_pc <= score_pc + 1;
                    end else if (fpga_fue_primero || btn_pulse_i[2]) begin
                        // FPGA respondio primero
                        if (fpga_is_correct)
                            score_fpga <= score_fpga + 1;
                        // PC solo gana si FPGA no acerto y PC si acerto
                        else if (pc_respondio && pc_is_correct)
                            score_pc <= score_pc + 1;
                    end else begin
                        // PC respondio primero
                        if (pc_is_correct)
                            score_pc <= score_pc + 1;
                        // FPGA solo gana si PC no acerto y FPGA si acerto
                        else if ((fpga_respondio || btn_pulse_i[2]) && fpga_is_correct)
                            score_fpga <= score_fpga + 1;
                    end
                    // Sonido basado unicamente en el resultado del jugador FPGA
                    last_ans_correct <= (fpga_respondio || btn_pulse_i[2]) && fpga_is_correct;
                    tx_byte         <= (pc_respondio && pc_is_correct) ? "W" : "F";
                    tx_return_state <= ST_RESULT;
                    fpga_respondio  <= 0;
                    pc_respondio    <= 0;
                    fpga_fue_primero <= 0;
                    pc_ok_pressed   <= 0;
                end
            end

            if (state_reg == ST_REFRESH_D) pc_sel_changed <= 0;

            // Game Over reset
            if (state_reg == ST_GAME_OVER && (btn_pulse_i[2] || pc_ok_pressed)) begin
                score_fpga    <= 0; score_pc      <= 0;
                round_cnt     <= 0; is_in_menu    <= 1;
                fpga_sel_idx  <= 0; pc_sel_idx    <= 0;
                pc_ok_pressed <= 0;
            end

            // Resultado: tras 2s vuelve a menu automaticamente
            if (state_reg == ST_RESULT && auto_start_cnt >= 28'd32_000_000) begin
                is_in_menu   <= 1;  view_mode    <= 0;
                fpga_sel_idx <= 0;  pc_sel_idx   <= 0;
                if (round_cnt < 7) round_cnt <= round_cnt + 1;
            end

            if (state_reg == ST_BOOT || state_reg == ST_RESULT)
                auto_start_cnt <= auto_start_cnt + 1;
            else
                auto_start_cnt <= 0;

            // delay_cnt / sweep_idx / init_idx — una sola fuente de verdad
            if (state_reg == ST_INIT_W || state_reg == ST_REFRESH_W) begin
                if (delay_cnt < 18'd32_000) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    delay_cnt <= 0;
                    if (state_reg == ST_INIT_W) begin
                        init_idx <= init_idx + 1;
                    end else begin
                        if (sweep_idx >= 33)
                            sweep_idx <= 0;
                        else
                            sweep_idx <= sweep_idx + 1;
                    end
                end
            end else begin
                delay_cnt <= 0;
                if (state_next == ST_IDLE) begin
                    sweep_idx <= 0;
                    init_idx  <= 0;
                end
            end
        end
    end

    // Cursor > para seleccion de opciones
    logic es_pos_cursor;
    always_comb begin
        es_pos_cursor = 1'b0;
        if (view_mode && buf_ready) begin
            case (fpga_sel_idx)
                2'd0: es_pos_cursor = (sweep_idx == 6'd1);
                2'd2: es_pos_cursor = (sweep_idx == 6'd9);
                2'd1: es_pos_cursor = (sweep_idx == 6'd18);
                2'd3: es_pos_cursor = (sweep_idx == 6'd26);
                default: es_pos_cursor = 1'b0;
            endcase
        end
    end

    logic [7:0] current_char;
    always_comb begin
        current_char = 8'h20;

        if (round_cnt >= 7) begin
            if (sweep_idx >= 1 && sweep_idx <= 16)
                case (sweep_idx - 1)
                    0: current_char = "G"; 1: current_char = "a";
                    2: current_char = "m"; 3: current_char = "e";
                    5: current_char = "O"; 6: current_char = "v";
                    7: current_char = "e"; 8: current_char = "r";
                    default: current_char = 8'h20;
                endcase
            else if (sweep_idx >= 18 && sweep_idx <= 33)
                case (sweep_idx - 18)
                    0: current_char = "F"; 1: current_char = "P";
                    2: current_char = "G"; 3: current_char = "A";
                    4: current_char = ":"; 5: current_char = score_fpga + 8'd48;
                    7: current_char = "P"; 8: current_char = "C";
                    9: current_char = ":"; 10: current_char = score_pc + 8'd48;
                    default: current_char = 8'h20;
                endcase
        end else if (is_in_menu) begin
            if (sweep_idx >= 1  && sweep_idx <= 16) current_char = MSG_L1[sweep_idx - 1];
            if (sweep_idx >= 18 && sweep_idx <= 33) current_char = MSG_L2[sweep_idx - 18];
        end else if (buf_ready) begin
            if (!view_mode) begin
                if (sweep_idx >= 1  && sweep_idx <= 16) current_char = buf_enunciado[sweep_idx - 1];
                if (sweep_idx >= 18 && sweep_idx <= 33) current_char = buf_enunciado[sweep_idx - 2];
            end else begin
                if (es_pos_cursor)
                    current_char = ">";
                else begin
                    if (sweep_idx >= 1  && sweep_idx <= 16) current_char = buf_opciones[sweep_idx - 1];
                    if (sweep_idx >= 18 && sweep_idx <= 33) current_char = buf_opciones[sweep_idx - 2];
                end
            end
        end
    end

    always_comb begin
        state_next      = state_reg;
        uart_we_o       = 0; uart_addr_o = 2'b00; uart_wdata_o = 32'd0;
        lcd_we_o        = 0; lcd_addr_o  = 0;     lcd_wdata_o  = 0;
        sound_play_o    = 0; sound_correct_o = 0;

        case (state_reg)
            ST_BOOT:
                if (auto_start_cnt >= 28'd32_000_000) state_next = ST_INIT_D;

            ST_INIT_D: begin
                lcd_we_o    = 1; lcd_addr_o  = 2'b01;
                lcd_wdata_o = {24'd0, INIT_CMDS[init_idx]};
                state_next  = ST_INIT_C;
            end
            ST_INIT_C: begin
                lcd_we_o    = 1; lcd_addr_o  = 2'b00; lcd_wdata_o = 32'h1;
                state_next  = ST_INIT_W;
            end
            ST_INIT_W:
                if (delay_cnt >= 18'd32_000)
                    state_next = (init_idx == 3) ? ST_REFRESH_D : ST_INIT_D;

            // Limpiar buffer UART antes de escuchar
            // Evita que basura residual dispare UART_READ en loop
            ST_IDLE_CLR: begin
                uart_we_o    = 1; uart_addr_o = 2'b00; uart_wdata_o = 32'd0;
                state_next   = ST_IDLE;
            end

            ST_IDLE:
                // Boton fisico tiene prioridad sobre UART en IDLE
                if (btn_pulse_i[2] || pc_ok_pressed)
                    state_next = ST_WAIT_Q;
                else if (uart_rdata_i[1])
                    state_next = ST_UART_READ;

            ST_WAIT_Q:
                if (q_valid_i) state_next = ST_CONFIRM_Q;

            ST_CONFIRM_Q: state_next = ST_ROM_WAIT;

            // Pulso next_char_o=1, ROM actualiza en el ciclo siguiente
            ST_ROM_WAIT:  state_next = ST_READ_ROM;

            // Capturar bytes 0-63; cuando fin_bloque_i ir a ST_ROM_LAST
            ST_READ_ROM:
                if (fin_bloque_i) state_next = ST_ROM_LAST;
                else              state_next = ST_ROM_WAIT;

            // Ciclo extra: char_i ahora tiene el byte 64 (respuesta correcta)
            ST_ROM_LAST:  state_next = ST_ROM_LAST2;
            ST_ROM_LAST2: state_next = ST_TX_IDX_W;

            // Transmitir indice de pregunta a Python
            ST_TX_IDX_W: begin
                uart_addr_o = 2'b00;
                if (uart_rdata_i[0] == 0) state_next = ST_TX_IDX_L;
            end
            ST_TX_IDX_L: begin
                uart_we_o    = 1; uart_addr_o  = 2'b10;
                uart_wdata_o = {24'd0, 4'd0, pregunta_sel_i} + 32'd48;
                state_next   = ST_TX_IDX_S;
            end
            ST_TX_IDX_S: begin
                uart_we_o    = 1; uart_addr_o  = 2'b00; uart_wdata_o = 32'h1;
                state_next   = ST_REFRESH_D;
            end

            ST_UART_READ: begin uart_addr_o = 2'b11; state_next = ST_UART_CLR; end
            ST_UART_CLR: begin
                uart_we_o   = 1; uart_addr_o = 2'b00; uart_wdata_o = 32'd0;
                state_next  = return_state;
            end

            ST_TX_WAIT: begin
                uart_addr_o = 2'b00;
                if (uart_rdata_i[0] == 0) state_next = ST_TX_LOAD;
            end
            ST_TX_LOAD: begin
                uart_we_o    = 1; uart_addr_o  = 2'b10;
                uart_wdata_o = {24'd0, tx_byte};
                state_next   = ST_TX_START;
            end
            ST_TX_START: begin
                uart_we_o    = 1; uart_addr_o  = 2'b00; uart_wdata_o = 32'h1;
                state_next   = tx_return_state;
            end

            ST_REFRESH_D: begin
                lcd_we_o    = 1; lcd_addr_o = 2'b01;
                if      (sweep_idx == 0)  lcd_wdata_o = 32'h80;
                else if (sweep_idx == 17) lcd_wdata_o = 32'hC0;
                else                      lcd_wdata_o = {24'd0, current_char};
                state_next  = ST_REFRESH_C;
            end
            ST_REFRESH_C: begin
                lcd_we_o    = 1; lcd_addr_o  = 2'b00;
                lcd_wdata_o = (sweep_idx == 0 || sweep_idx == 17) ? 32'h1 : 32'h3;
                state_next  = ST_REFRESH_W;
            end
            ST_REFRESH_W:
                if (delay_cnt >= 18'd32_000)
                    state_next = (sweep_idx == 33) ?
                        (round_cnt >= 7  ? ST_GAME_OVER :
                        (is_in_menu      ? ST_IDLE_CLR  : ST_PLAYING)) :
                        ST_REFRESH_D;

            ST_PLAYING:
                if (uart_rdata_i[1])
                    state_next = ST_UART_READ;
                // Terminar cuando ambos respondieron o timeout
                else if (((fpga_respondio || btn_pulse_i[2]) && pc_respondio) || timer_val == 0)
                    state_next = ST_TX_WAIT;
                else if (btn_pulse_i[0] || btn_pulse_i[1] || pc_sel_changed)
                    state_next = ST_REFRESH_D;

            ST_RESULT: begin
                sound_play_o    = 1;
                sound_correct_o = last_ans_correct;
                if (auto_start_cnt >= 28'd32_000_000) state_next = ST_REFRESH_D;
            end

            ST_GAME_OVER:
                if (uart_rdata_i[1])
                    state_next = ST_UART_READ;
                else if (btn_pulse_i[2] || pc_ok_pressed)
                    state_next = ST_REFRESH_D;

            default: state_next = ST_BOOT;
        endcase
    end

endmodule