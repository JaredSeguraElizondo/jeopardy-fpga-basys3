// evaluador_respuestas.sv
// Logica combinacional pura. Activada por eval_en.
// Determina el ganador de la ronda segun correccion y tiempo de respuesta.

module evaluador_respuestas #(
    parameter N = 8  // Ancho del timestamp (igual que tiempo_transcurrido)
)(
    // Habilitacion
    input  logic        eval_en,

    // Respuestas de los jugadores (desde interfaces)
    input  logic [1:0]  respuesta_fpga,   // Respuesta J1, desde Interfaz FPGA
    input  logic [1:0]  respuesta_pc,     // Respuesta J2, desde Interfaz PC

    // Respuesta correcta (desde Memoria)
    input  logic [1:0]  respuesta_correcta,

    // Timestamps capturados (tiempo transcurrido desde inicio de ronda)
    input  logic [N-1:0] timestamp_j1,   // Capturado por Registro Tiempo J1
    input  logic [N-1:0] timestamp_j2,   // Capturado por Registro Tiempo J2

    // Indicadores de captura valida (desde Registros de Tiempo)
    input  logic        R1_valid,         // Registro J1 capturado exitosamente
    input  logic        R2_valid,         // Registro J2 capturado exitosamente

    // Salidas
    output logic [1:0]  resultado_eval,   // 00=nadie, 01=J1, 10=J2
    output logic [1:0]  ganador
);

    logic j1_correcto, j2_correcto;

    always_comb begin
        resultado_eval = 2'b00;
        ganador    = 2'b00;

        // Un jugador solo cuenta si respondio (R_valid) y acerto
        j1_correcto = R1_valid && (respuesta_fpga == respuesta_correcta);
        j2_correcto = R2_valid && (respuesta_pc   == respuesta_correcta);

        if (eval_en) begin
            if (j1_correcto && !j2_correcto) begin
                resultado_eval = 2'b01;
                ganador    = 2'b01;

            end else if (!j1_correcto && j2_correcto) begin
                resultado_eval = 2'b10;
                ganador    = 2'b10;

            end else if (j1_correcto && j2_correcto) begin
                // Gana quien respondio mas rapido (menor tiempo transcurrido)
                // Empate exacto: prioridad fija a J1
                if (timestamp_j1 <= timestamp_j2) // Si J1 es mas rapido o empate, gana J1
                    resultado_eval = 2'b01;  // J1 gana
                else // J2 es mas rapido
                    resultado_eval = 2'b10;  // J2 gana
            end
            default: begin
                resultado_eval = 2'b00;
                ganador    = 2'b00;
                 // Si ninguno es correcto: resultado_eval = 00, ganador = 00 (no hay ganador) (defaults)
            end 
        end
    end

endmodule