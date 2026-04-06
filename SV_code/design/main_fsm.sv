// =============================================================================
// Módulo   : main_fsm
// Proyecto : Jeopardy FPGA
// Archivo  : main_fsm.sv
// Descripción:
//   Máquina de estados principal del juego Jeopardy. Secuencia el flujo
//   global de cada ronda: selección de pregunta, visualización, ventana de
//   respuesta, evaluación, avance de ronda y fin de partida.
// =============================================================================

module main_fsm (
    // ── Señales del sistema ───────────────────────────────────────────────
    input  logic        clk,
    input  logic        rst,            // Reset activo en alto

    // ── Entradas de control ───────────────────────────────────────────────
    input  logic        game_done,      // Contador de rondas >= 7
    input  logic        show_done,      // Scroll CTL: presentación inicial lista
    input  logic        timeout,        // Temporizador: tiempo de ronda agotado
    input  logic        play_rcp,       // FSM Recepción: ambos jugadores confirmaron
    input  logic        hay_ganador,    // Evaluador: al menos un jugador correcto
    input  logic [1:0]  resultado_eval, // Evaluador: 00=nadie, 01=J1, 10=J2

    // ── Salidas hacia Contador de Rondas ──────────────────────────────────
    output logic        round_rst,      // Resetea el contador de rondas
    output logic        round_inc,      // Incrementa el contador de rondas

    // ── Salidas hacia Temporizador ────────────────────────────────────────
    output logic        iniciar_ronda,  // Habilita el temporizador de ronda
    output logic        temporizador_rst,

    // ── Salidas hacia Memoria ─────────────────────────────────────────────
    output logic        solicitar_pregunta, // Pulso: pide nueva pregunta al banco

    // ── Salidas hacia Scroll CTL ──────────────────────────────────────────
    output logic        scroll_en,      // Habilita el controlador de scroll
    output logic        scroll_rst,     // Resetea scroll y opcion_seleccionada a A

    // ── Salidas hacia FSM de Recepción ────────────────────────────────────
    output logic        en_rcp,         // Habilita la FSM de Recepción
    output logic        rst_rcp,        // Resetea la FSM de Recepción

    // ── Salidas hacia Evaluador ───────────────────────────────────────────
    output logic        eval_en,        // Habilita el evaluador de respuestas

    // ── Salidas hacia Visualización y Salidas ─────────────────────────────
    output logic [2:0]  estado_juego,   // Codifica el estado actual del juego
    output logic [1:0]  resultado_ronda // Resultado de la ronda evaluada
);

    // =========================================================================
    // Definición de estados
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE     = 3'b000,
        SEL_Q    = 3'b001,
        SHOW     = 3'b010,
        WAIT_R   = 3'b011,
        CHECK    = 3'b100,
        STEP     = 3'b101,
        END_GAME = 3'b110
    } state_t;

    state_t state, next_state;

    // =========================================================================
    // Registro de resultado de ronda
    // Tipo   : registro controlado por la FSM → reset SÍNCRONO activo en alto
    // Se captura en CHECK para mantener el valor estable hacia Visualización
    // durante los estados STEP y END_GAME.
    // =========================================================================
    logic [1:0] resultado_ronda_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            resultado_ronda_reg <= 2'b00;
        end
        else if (state == CHECK) begin
            resultado_ronda_reg <= resultado_eval;
        end
    end

    assign resultado_ronda = resultado_ronda_reg;

    // =========================================================================
    // Registro de estado (secuencial)
    // Tipo : FSM → reset ASÍNCRONO activo en alto
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    // =========================================================================
    // Lógica de siguiente estado 
    // =========================================================================
    
    always_comb begin
    next_state = state;

    case (state)

        IDLE: begin
            if (game_done) 
            next_state = SEL_Q;
        end

        SEL_Q: begin
            next_state = SHOW;
        end

        SHOW: begin
            if (show_done)
                next_state = WAIT_R;
        end

        WAIT_R: begin
            if (timeout || play_rcp)
                next_state = CHECK;
        end

        CHECK: begin
            next_state = STEP;
        end

        STEP: begin
            next_state = IDLE;
        end

        END_GAME: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end
    
    always_comb begin

    round_rst          = 1'b0;
    round_inc          = 1'b0;
    iniciar_ronda      = 1'b0;
    temporizador_rst   = 1'b0;

    solicitar_pregunta = 1'b0;

    scroll_en          = 1'b0;
    scroll_rst         = 1'b0;

    en_rcp             = 1'b0;
    rst_rcp            = 1'b0;

    eval_en            = 1'b0;

    estado_juego       = 3'b000;

    // Logica de salida
    case (state)
        IDLE: begin
            round_rst        = 1'b1;
            scroll_rst       = 1'b1;
            rst_rcp          = 1'b1;
            temporizador_rst = 1'b1;
            estado_juego     = 3'b000;
        end

        SEL_Q: begin
            solicitar_pregunta = 1'b1;
            estado_juego       = 3'b001;
        end

        SHOW: begin
            scroll_en    = 1'b1;
            estado_juego = 3'b010;
        end

        WAIT_R: begin
            iniciar_ronda = 1'b1;
            scroll_en     = 1'b1;
            en_rcp        = 1'b1;
            estado_juego  = 3'b011;
        end

        CHECK: begin
            eval_en      = 1'b1;
            rst_rcp      = 1'b1;
            estado_juego = 3'b100;
        end

        STEP: begin
            round_inc    = 1'b1;
            scroll_rst   = 1'b1;
            rst_rcp      = 1'b1;
            estado_juego = 3'b101;
        end

        END_GAME: begin
            scroll_rst   = 1'b1;
            rst_rcp      = 1'b1;
            estado_juego = 3'b110;
        end

        default: begin
            estado_juego = 3'b000;
        end
    endcase
end
endmodule
