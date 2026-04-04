`timescale 1ns / 1ps

//   Mapa de registros (addr_i[1:0]) 
//   2'b00 → REG_CONTROL
//            [0] start (W1P) | [1] rs | [2] clear (W1P) | [3] home (W1P)
//            [8] busy  (RO)  | [9] done (RO)
//   2'b01 → REG_DATOS : [7:0] data_byte
//
// Salidas al PmodCLP (conectar al conector JA de la Basys3) ─────────────────
// lcd_db_o[7:0]  → DB7..DB0
// lcd_e_o        → E  (Enable)
// lcd_rs_o       → RS (Register Select)
// lcd_rw_o       → RW (siempre 0)
//
// Displays de 7 segmentos 
// seg_an_o[3:0]  → AN3..AN0 (activos-bajos)
// seg_cat_o[6:0] → CA..CG   (activos-bajos, orden {a,b,c,d,e,f,g})


module visualizacion_top (
    
    input  logic        clk_i,             // 16 MHz 
    input  logic        rst_i,             // Reset síncrono activo-alto

    // Interfaz de periférico
    input  logic [1:0]  addr_i,
    input  logic        write_enable_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // Control desde la FSM principal del juego 
    input  logic        mostrar_pregunta_i,
    input  logic        mostrar_opciones_i,
    input  logic [127:0] pregunta_str_i,   // 16 chars ASCII, char0=[127:120]
    input  logic [127:0] opciones_str_i,

    // Puntaje y tiempo para 7 segmentos
    input  logic [7:0]  puntaje_fpga_i,    // 0-7 rondas
    input  logic [7:0]  tiempo_restante_i, // 0-30 segundos

    // Salidas físicas 
    output logic        lcd_ready_o,       // 1 = LCD listo para nueva instrucción
    output logic [7:0]  lcd_db_o,          // Bus de datos
    output logic        lcd_e_o,           // Enable
    output logic        lcd_rs_o,          // Register Select
    output logic        lcd_rw_o,          // Read/Write (siempre 0)
    output logic [3:0]  seg_an_o,          // Ánodos  7-seg (activo-bajo)
    output logic [6:0]  seg_cat_o          // Cátodos 7-seg (activo-bajo)
);
    // Señales internas

    // lcd_registros a árbitro / FSM
    logic        pulse_start;
    logic        pulse_clear;
    logic        pulse_home;
    logic        rs_reg;
    logic [7:0]  data_byte_reg;

    // lcd_fsm a lcd_registros / árbitro
    logic        lcd_busy;
    logic        lcd_done;

    // lcd_auto_escritor a árbitro
    logic        auto_req;
    logic        auto_rs;
    logic [7:0]  auto_data;

    // lcd_arbitro a lcd_fsm
    logic        cmd_req;
    logic [1:0]  cmd_type;
    logic        cmd_rs;
    logic [7:0]  cmd_data;

    // Instancias

    // Registros mapeados a memoria 
    lcd_registros u_registros (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .addr_i         (addr_i),
        .write_enable_i (write_enable_i),
        .wdata_i        (wdata_i),
        .rdata_o        (rdata_o),
        .lcd_busy_i     (lcd_busy),
        .lcd_done_i     (lcd_done),
        .pulse_start_o  (pulse_start),
        .pulse_clear_o  (pulse_clear),
        .pulse_home_o   (pulse_home),
        .rs_o           (rs_reg),
        .data_byte_o    (data_byte_reg)
    );

    // Árbitro de comandos 
    lcd_arbitro u_arbitro (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .pulse_start_i  (pulse_start),
        .pulse_clear_i  (pulse_clear),
        .pulse_home_i   (pulse_home),
        .rs_i           (rs_reg),
        .data_byte_i    (data_byte_reg),
        .auto_req_i     (auto_req),
        .auto_rs_i      (auto_rs),
        .auto_data_i    (auto_data),
        .lcd_busy_i     (lcd_busy),
        .cmd_req_o      (cmd_req),
        .cmd_type_o     (cmd_type),
        .cmd_rs_o       (cmd_rs),
        .cmd_data_o     (cmd_data)
    );

    // FSM del LCD (HD44780 modo 8-bit) 
    lcd_fsm u_fsm (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .cmd_req_i      (cmd_req),
        .cmd_type_i     (cmd_type),
        .cmd_rs_i       (cmd_rs),
        .cmd_data_i     (cmd_data),
        .lcd_busy_o     (lcd_busy),
        .lcd_done_o     (lcd_done),
        .lcd_db_o       (lcd_db_o),
        .lcd_e_o        (lcd_e_o),
        .lcd_rs_o       (lcd_rs_o),
        .lcd_rw_o       (lcd_rw_o)
    );

    // Auto-escritor de strings
    lcd_auto_escritor u_auto (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .mostrar_pregunta_i (mostrar_pregunta_i),
        .mostrar_opciones_i (mostrar_opciones_i),
        .pregunta_str_i  (pregunta_str_i),
        .opciones_str_i  (opciones_str_i),
        .lcd_busy_i      (lcd_busy),
        .lcd_done_i      (lcd_done),
        .cmd_req_busy_i  (cmd_req),   // Si el árbitro ya tiene algo, espera
        .auto_req_o      (auto_req),
        .auto_rs_o       (auto_rs),
        .auto_data_o     (auto_data)
    );

    // Displays de 7 segmentos 
    seg7_display u_seg7 (
        .clk_i              (clk_i),
        .rst_i              (rst_i),
        .puntaje_fpga_i     (puntaje_fpga_i),
        .tiempo_restante_i  (tiempo_restante_i),
        .seg_an_o           (seg_an_o),
        .seg_cat_o          (seg_cat_o)
    );

    // Señal lcd_ready 
    assign lcd_ready_o = ~lcd_busy;

endmodule