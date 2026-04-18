`timescale 1ns / 1ps

module top_jeopardy (
    input  logic        clk_100mhz,
    input  logic        rst_btn,
    input  logic [3:0]  sw,          // SW[3:0] = semilla LFSR
    input  logic [2:0]  btn_async,
    output logic [6:0]  seg,
    output logic [3:0]  an,
    output logic        buzzer_pwm,
    input  logic        RsRx,
    output logic        RsTx,
    output logic        lcd_rs,
    output logic        lcd_rw,
    output logic        lcd_en,
    output logic [7:0]  lcd_data
);

    // Reloj y reset 
    logic clk_16mhz, locked;
    logic sys_rst;
    assign sys_rst = rst_btn | ~locked;

    clk_wiz_0 sys_clk_inst (
        .clk_in1  (clk_100mhz),
        .clk_out1 (clk_16mhz),
        .reset    (rst_btn),
        .locked   (locked)
    );

    //  Cables internos 
    logic [2:0]  btn_pulse;
    logic [15:0] hex_data;
    logic        sound_play, sound_correct;
    logic        uart_we;
    logic [1:0]  uart_addr;
    logic [31:0] uart_wdata, uart_rdata;
    logic        lcd_we;
    logic [1:0]  lcd_addr;
    logic [31:0] lcd_wdata, lcd_rdata;

    // question_memory
    logic [7:0]  qm_char;
    logic [1:0]  qm_tipo;
    logic        qm_fin_bloque;
    logic        qm_next_char;
    logic        qm_marcar_usada;
    logic        qm_pregunta_usada;
    logic [3:0]  qm_pregunta_sel;

    // question_picker
    logic [3:0]  qp_pregunta_sel;
    logic        qp_q_valid;
    logic        qp_solicitar;
    logic        qp_confirmar;
    logic [3:0]  qp_lfsr_val;  // candidato actual del LFSR para consulta de usadas

    assign qm_pregunta_sel = qp_pregunta_sel;

    // load_seed: carga la semilla de los switches cuando se presiona
    // el boton de inicio (btn_async[2] debounced). Esto permite cambiar
    // la semilla antes de cada partida poniendo los switches y luego
    // presionando el boton.
    logic load_seed;
    assign load_seed = btn_pulse[2];


    // 1. UI Controller
    // buzzer_o no se usa aqui (el audio lo maneja sound_manager)
    // se conecta a un wire flotante para evitar warning
    logic buzzer_unused;
    ui_hw_controller ui_inst (
        .clk_i         (clk_16mhz),
        .rst_i         (sys_rst),
        .hex_data_i    (hex_data),
        .buzz_en_i     (1'b0),
        .buzz_period_i (16'd0),
        .btn_pulse_o   (btn_pulse),
        .btn_async_i   (btn_async),
        .seg_o         (seg),
        .an_o          (an),
        .buzzer_o      (buzzer_unused)   // desconectado intencionalmente
    );

    // 2. Audio
    sound_manager audio_sys_inst (
        .clk_i         (clk_16mhz),
        .rst_i         (sys_rst),
        .play_i        (sound_play),
        .correct_i     (sound_correct),
        .speaker_pwm_o (buzzer_pwm)
    );

    // 3. UART
    uart_peripheral uart_inst (
        .clk_i          (clk_16mhz),
        .rst_i          (sys_rst),
        .write_enable_i (uart_we),
        .addr_i         (uart_addr),
        .wdata_i        (uart_wdata),
        .rdata_o        (uart_rdata),
        .RsRx             (RsRx),
        .RsTx             (RsTx)
    );

    // 4. LCD
    lcd_peripheral lcd_inst (
        .clk_i          (clk_16mhz),
        .rst_i          (sys_rst),
        .write_enable_i (lcd_we),
        .addr_i         (lcd_addr),
        .wdata_i        (lcd_wdata),
        .rdata_o        (lcd_rdata),
        .lcd_rs         (lcd_rs),
        .lcd_rw         (lcd_rw),
        .lcd_en         (lcd_en),
        .lcd_data       (lcd_data)
    );

    // 5. Memoria de preguntas (ROM .coe)
    question_memory qmem_inst (
        .clk_i           (clk_16mhz),
        .rst_i           (sys_rst),
        .pregunta_sel_i  (qm_pregunta_sel),
        // consulta_sel_i: el candidato actual del LFSR (1-10) convertido a indice (0-9)
        // Si lfsr_val esta fuera de rango, usamos 0 (no importa, candidato_valido=0)
        .consulta_sel_i  (qp_lfsr_val >= 4'd1 ? qp_lfsr_val - 4'd1 : 4'd0),
        .next_char_i     (qm_next_char),
        .marcar_usada    (qm_marcar_usada),
        .char_o          (qm_char),
        .tipo_o          (qm_tipo),
        .fin_bloque_o    (qm_fin_bloque),
        .pregunta_usada_o(qm_pregunta_usada)
    );

    // 6. Question Picker (incluye lfsr4 internamente)
    question_picker qpicker_inst (
        .clk_i           (clk_16mhz),
        .rst_i           (sys_rst),
        .solicitar_i     (qp_solicitar),
        .confirmar_i     (qp_confirmar),
        .pregunta_usada_i(qm_pregunta_usada),
        .seed_i          (sw),
        .load_seed_i     (load_seed),
        .pregunta_sel_o  (qp_pregunta_sel),
        .q_valid_o       (qp_q_valid),
        .lfsr_val_o      (qp_lfsr_val)
    );

    // 7. Game Core
    game_core core_inst (
        .clk_i           (clk_16mhz),
        .rst_i           (sys_rst),
        .btn_pulse_i     (btn_pulse),
        .hex_data_o      (hex_data),
        .sound_play_o    (sound_play),
        .sound_correct_o (sound_correct),
        .uart_we_o       (uart_we),
        .uart_addr_o     (uart_addr),
        .uart_wdata_o    (uart_wdata),
        .uart_rdata_i    (uart_rdata),
        .lcd_we_o        (lcd_we),
        .lcd_addr_o      (lcd_addr),
        .lcd_wdata_o     (lcd_wdata),
        .lcd_rdata_i     (lcd_rdata),
        .char_i          (qm_char),
        .tipo_i          (qm_tipo),
        .fin_bloque_i    (qm_fin_bloque),
        .next_char_o     (qm_next_char),
        .marcar_usada_o  (qm_marcar_usada),
        .pregunta_sel_i  (qp_pregunta_sel),
        .q_valid_i       (qp_q_valid),
        .solicitar_o     (qp_solicitar),
        .confirmar_o     (qp_confirmar)
    );

endmodule