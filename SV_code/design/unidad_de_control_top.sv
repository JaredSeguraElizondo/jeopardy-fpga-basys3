// =============================================================================
// Módulo   : unidad_de_control_top
// Proyecto : Jeopardy FPGA
// Archivo  : unidad_de_control_top.sv
// Descripción:
//   Módulo top de la Unidad de Control. Instancia e interconecta los cinco
//   sub-bloques internos: main_fsm, rcp_fsm, time_reg, temporizador,
//   evaluador_respuestas, score_counter y contador_rondas.
// =============================================================================

module unidad_de_control_top #(
    parameter N     = 2,            // Ancho de respuestas (2 bits = 4 opciones)
    parameter W     = 3,            // Ancho contadores de puntaje
    parameter FREQ  = 16_000_000,   // Frecuencia del reloj (16 MHz)
    parameter TIME  = 30,           // Duracion de ronda en segundos
    parameter COUNT = $clog2(FREQ * TIME) // Ancho del contador del temporizador
)(
    input  logic             clk,
    input  logic             rst,

    // ── Interfaces de jugadores ───────────────────────────────────────────
    input  logic             fpga_ok,           // Pulso: jugador FPGA confirmo
    input  logic             pc_ok,             // Pulso: jugador PC confirmo
    input  logic [N-1:0]     respuesta_correcta, // Desde memoria
    input  logic [N-1:0]     respuesta_fpga,     // Desde interfaz FPGA
    input  logic [N-1:0]     respuesta_pc,       // Desde interfaz PC

    // ── Salidas hacia Memoria ─────────────────────────────────────────────
    output logic             solicitar_pregunta,

    // ── Salidas hacia Visualización ───────────────────────────────────────
    output logic             mostrar_pregunta_i,
    output logic             mostrar_opciones_i,
    output logic [2:0]       estado_juego,

    // ── Puntajes ──────────────────────────────────────────────────────────
    output logic [W-1:0]     score_j1,
    output logic [W-1:0]     score_j2
);

    // =========================================================================
    // Señales internas
    // =========================================================================

    // main_fsm → varios
    logic        en_rcp, rst_rcp;
    logic        eval_en;
    logic        round_inc, round_rst;
    logic        iniciar_ronda, temporizador_rst;

    // rcp_fsm → time_reg
    logic        save_time_j1, save_time_j2;
    logic        time_rst;

    // rcp_fsm → main_fsm
    logic        play_rcp;

    // temporizador → main_fsm, time_reg
    logic        timeout;
    logic [COUNT-1:0] count;

    // time_reg → evaluador, rcp_fsm
    logic        R1_valid, R2_valid;
    logic [COUNT-1:0] timestamp_j1, timestamp_j2;

    // evaluador → main_fsm, score_counter
    logic [N-1:0]    resultado_eval;
    logic        win_j1, win_j2;

    // contador_rondas → main_fsm
    logic        game_done;

    // =========================================================================
    // Instancias
    // =========================================================================

    // ── Main FSM ──────────────────────────────────────────────────────────
    main_fsm u_main_fsm (
        .clk                (clk),
        .rst                (rst),
        .game_done          (game_done),
        .timeout            (timeout),
        .play_rcp           (play_rcp),
        .resultado_eval     (resultado_eval),
        .round_rst          (round_rst),
        .round_inc          (round_inc),
        .iniciar_ronda      (iniciar_ronda),
        .temporizador_rst   (temporizador_rst),
        .solicitar_pregunta (solicitar_pregunta),
        .en_rcp             (en_rcp),
        .rst_rcp            (rst_rcp),
        .eval_en            (eval_en),
        .mostrar_opciones_i (mostrar_opciones_i),
        .mostrar_pregunta_i (mostrar_pregunta_i),
        .estado_juego       (estado_juego),
        .resultado_ronda    ()  // No se expone en el top
    );

    // ── FSM de Recepción ──────────────────────────────────────────────────
    rcp_fsm u_rcp_fsm (
        .clk         (clk),
        .rst         (rst),
        .en_rcp      (en_rcp),
        .rst_rcp     (rst_rcp),
        .fpga_ok     (fpga_ok),
        .pc_ok       (pc_ok),
        .R1_valid    (R1_valid),
        .R2_valid    (R2_valid),
        .save_time_j1(save_time_j1),
        .save_time_j2(save_time_j2),
        .time_rst    (time_rst),
        .play_rcp    (play_rcp)
    );

    // ── Temporizador ──────────────────────────────────────────────────────
    temporizador #(
        .FREQ (FREQ),
        .TIME (TIME)
    ) u_temporizador (
        .clk     (clk),
        .rst     (temporizador_rst),
        .en      (iniciar_ronda),
        .timeout (timeout),
        .count   (count)
    );

    // ── Registros de Tiempo J1/J2 ─────────────────────────────────────────
    time_reg #(
        .FREQ (FREQ),
        .TIME (TIME)
    ) u_time_reg (
        .clk         (clk),
        .rst         (time_rst),
        .count       (count),
        .save_time_j1(save_time_j1),
        .save_time_j2(save_time_j2),
        .R1_valid    (R1_valid),
        .R2_valid    (R2_valid),
        .timestamp_j1(timestamp_j1),
        .timestamp_j2(timestamp_j2)
    );

    // ── Evaluador de Respuestas ───────────────────────────────────────────
    evaluador_respuestas #(
        .N (COUNT)  // Ancho del timestamp = ancho del contador
    ) u_evaluador (
        .eval_en           (eval_en),
        .respuesta_fpga    (respuesta_fpga),
        .respuesta_pc      (respuesta_pc),
        .respuesta_correcta(respuesta_correcta),
        .timestamp_j1      (timestamp_j1),
        .timestamp_j2      (timestamp_j2),
        .R1_valid          (R1_valid),
        .R2_valid          (R2_valid),
        .resultado_eval    (resultado_eval),
        .win_j1            (win_j1),
        .win_j2            (win_j2)
    );

    // ── Contador de Rondas ────────────────────────────────────────────────
    contador_rondas u_contador_rondas (
        .clk      (clk),
        .rst      (round_rst),
        .en       (round_inc),
        .game_done(game_done),
        .ronda    ()  // No se expone en el top
    );

    // ── Contador de Puntaje ───────────────────────────────────────────────
    score_counter #(
        .W (W)
    ) u_score_counter (
        .clk     (clk),
        .rst     (rst),         // Reset global limpia puntajes
        .win_j1  (win_j1),
        .win_j2  (win_j2),
        .score_j1(score_j1),
        .score_j2(score_j2)
    );

endmodule