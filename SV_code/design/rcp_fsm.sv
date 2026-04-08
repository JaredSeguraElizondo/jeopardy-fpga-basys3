// =============================================================================
// Módulo   : rcp_fsm
// Proyecto : Jeopardy FPGA
// Archivo  : rcp_fsm.sv
// Descripción:
//   FSM de recepción de respuestas. Monitorea concurrentemente fpga_ok y
//   pc_ok, captura timestamps y habilita la validación de respuestas.
//   Solo opera cuando en_rcp = 1.
//
//   Reset FSM       : asíncrono, activo en alto (rst || rst_rcp)
//   Reset registros : síncrono, activo en alto
//   Reloj           : 16 MHz (clk)
// =============================================================================

module rcp_fsm (
    input  logic clk,
    input  logic rst,           // Reset global asíncrono
    input  logic en_rcp,        // Habilitación desde main_fsm
    input  logic rst_rcp,       // Reset interno desde main_fsm

    // ── Entradas jugadores ────────────────────────────────────────────────
    input  logic fpga_ok,       // Captura exitosa de timestamp J1
    input  logic pc_ok,         // Captura exitosa de timestamp J2

    // ── Entradas desde evaluador ──────────────────────────────────────────
    input  logic R1_valid,      // Respuesta de J1 procesada por el evaluador
    input  logic R2_valid,      // Respuesta de J2 procesada por el evaluador

    // ── Salidas hacia registros de tiempo ─────────────────────────────────
    output logic save_time_j1,  // Pulso: captura timestamp de J1
    output logic save_time_j2,  // Pulso: captura timestamp de J2
    output logic time_rst,      // Limpia ambos registros de timestamp

    // ── Salidas hacia evaluador de respuestas ─────────────────────────────
    output logic eval_en,       // Habilita cálculo final del evaluador

    // ── Salidas hacia main_fsm ────────────────────────────────────────────
    output logic play_rcp       // Ambos jugadores han confirmado
);

    // =========================================================================
    // Definición de estados
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        MONITOR = 3'b001,
        REG_J1  = 3'b010,
        REG_J2  = 3'b011,
        DONE    = 3'b100
    } state_t;

    state_t state, next_state;

    // =========================================================================
    // Registro de estado
    // Reset asíncrono activo en alto: tanto rst global como rst_rcp llevan
    // la FSM a IDLE de forma inmediata.
    // =========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst || rst_rcp) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // =========================================================================
    // Bloque 1: Lógica de siguiente estado
    // =========================================================================
    always_comb begin

        next_state = state;

        case (state)

            // -----------------------------------------------------------------
            // IDLE: espera a que main_fsm active en_rcp.
            // -----------------------------------------------------------------
            IDLE : begin
                if (en_rcp) begin
                    next_state = MONITOR;
                end
                else begin
                    next_state = IDLE;
                end
            end

            // -----------------------------------------------------------------
            // MONITOR: espera confirmaciones de ambos jugadores.
            // Prioridad fija J1 si fpga_ok y pc_ok llegan simultáneamente.
            // -----------------------------------------------------------------
            MONITOR : begin
                if (fpga_ok && ~R1_valid) begin
                    next_state = REG_J1;
                end
                else if (pc_ok && ~R2_valid) begin
                    next_state = REG_J2;
                end
                else if (R1_valid && R2_valid) begin
                    next_state = DONE;
                end
                else begin
                    next_state = MONITOR;
                end
            end

            // -----------------------------------------------------------------
            // REG_J1: registra timestamp y habilita check de J1.
            // Regresa a MONITOR a esperar J2.
            // -----------------------------------------------------------------
            REG_J1 : begin
                next_state = MONITOR;
            end

            // -----------------------------------------------------------------
            // REG_J2: registra timestamp y habilita check de J2.
            // Regresa a MONITOR a esperar J1.
            // -----------------------------------------------------------------
            REG_J2 : begin
                next_state = MONITOR;
            end

            // -----------------------------------------------------------------
            // DONE: mantiene play_rcp activo hasta que main_fsm pulse rst_rcp.
            // rst_rcp es asíncrono para el always_ff, por lo que la FSM vuelve
            // a IDLE por la rama de reset, no por esta transición.
            // Este estado permanece estable mientras rst_rcp = 0.
            // -----------------------------------------------------------------
            DONE : begin
                next_state = DONE;
            end

            default : begin
                next_state = IDLE;
            end

        endcase
    end

    // =========================================================================
    // Bloque 2: Lógica de salidas
    // =========================================================================
    always_comb begin

        // ── Valores por defecto ───────────────────────────────────────────
        save_time_j1 = 1'b0;
        save_time_j2 = 1'b0;
        time_rst     = 1'b0;
        eval_en      = 1'b0;
        play_rcp     = 1'b0;

        case (state)

            // -----------------------------------------------------------------
            // IDLE: mantiene los registros de tiempo limpios.
            // -----------------------------------------------------------------
            IDLE : begin
                time_rst = 1'b1;
            end

            // -----------------------------------------------------------------
            // MONITOR: todas las salidas inactivas (cubiertas por defaults).
            // -----------------------------------------------------------------
            MONITOR : begin
            end

            // -----------------------------------------------------------------
            // REG_J1: captura timestamp y habilita validación de J1.
            // -----------------------------------------------------------------
            REG_J1 : begin
                save_time_j1 = 1'b1;
            end

            // -----------------------------------------------------------------
            // REG_J2: captura timestamp y habilita validación de J2.
            // -----------------------------------------------------------------
            REG_J2 : begin
                save_time_j2 = 1'b1;
            end

            // -----------------------------------------------------------------
            // DONE: activa evaluador y notifica a main_fsm.
            // Permanece activo hasta rst_rcp.
            // -----------------------------------------------------------------
            DONE : begin
                eval_en  = 1'b1;
                play_rcp = 1'b1;
            end

            default : begin
                save_time_j1 = 1'b0;
                save_time_j2 = 1'b0;
                time_rst     = 1'b0;
                eval_en      = 1'b0;
                play_rcp     = 1'b0;
            end

        endcase
    end

endmodule