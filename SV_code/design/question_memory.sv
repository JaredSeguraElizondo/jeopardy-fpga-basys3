// ============================================================
// question_memory.sv
// Modulo de memoria y seleccion de preguntas.
//
// Sub-bloques internos:
//   1. Logica de direccion base  (combinacional)
//   2. ROM IP Catalog            (blk_mem_gen_0)
//   3. Contador de caracteres    (secuencial)
//   4. Decodificador de indice   (combinacional)
//   5. Registro de preguntas usadas (secuencial)
//
// Layout ROM (65 bytes/pregunta):
//   [0 -31] Enunciado            (32 bytes, 2 filas LCD x 16 chars)
//   [32-47] Opciones fila 1      (16 bytes, "A:XXXXX C:XXXXX")
//   [48-63] Opciones fila 2      (16 bytes, "B:XXXXX D:XXXXX")
//   [64]    Respuesta correcta ASCII ('A','B','C' o 'D')
//
// ROM configurada en Vivado: Width=8, Depth=650
// ============================================================

module question_memory (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic [3:0] pregunta_sel_i,  // Numero de pregunta (0-9) del question_picker
    input  logic       next_char_i,     // Pulso para avanzar al siguiente caracter
    input  logic       marcar_usada,    // Pulso de la UC para marcar pregunta como jugada
    output logic [7:0] char_o,          // Caracter ASCII actual de la ROM
    output logic [1:0] tipo_o,          // Seccion actual: 00=enunciado, 01=opciones, 10=respuesta
    output logic       fin_bloque_o,    // Fin del bloque de la pregunta actual
    output logic       pregunta_usada_o // 1 si la pregunta ya fue jugada en esta partida
);

    // ── Parametros ────────────────────────────────────────────
    localparam BYTES_PER_Q = 7'd65;  // Bytes por pregunta
    localparam MAX_OFFSET  = 7'd64;  // Ultimo byte del bloque (indice 0-64)

    // =========================================================
    // Sub-bloque 3: Contador de caracteres
    // =========================================================
    logic [6:0] contador;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            contador <= 7'd0;
        end else if (next_char_i) begin
            if (contador == MAX_OFFSET)
                contador <= 7'd0;
            else
                contador <= contador + 7'd1;
        end
    end

    assign fin_bloque_o = (contador == MAX_OFFSET);

    // =========================================================
    // Sub-bloque 1: Logica de direccion base
    // =========================================================
    // addr_final = pregunta_sel_i * 65 + contador
    // Maximo: 9*65+64 = 649 < 1024 (cabe en 10 bits)
    logic [9:0] addr_final;

    assign addr_final = (pregunta_sel_i * BYTES_PER_Q) + {3'b000, contador};

    // =========================================================
    // Sub-bloque 2: ROM IP Catalog
    // =========================================================
    // Instancia generada por Vivado IP Catalog:
    //   - Width : 8 bits
    //   - Depth : 650 palabras
    //   - Latencia: 1 ciclo (Primitives Output Register habilitado)
    //   - Archivo: preguntas.coe
    blk_mem_gen_0 u_rom (
        .clka  (clk_i),
        .addra (addr_final),
        .douta (char_o)
    );

    // =========================================================
    // Sub-bloque 4: Decodificador de indice
    // =========================================================
    // Determina que seccion del bloque se esta leyendo:
    //   0  - 31 : enunciado          → tipo_o = 00
    //   32 - 63 : opciones (2 filas) → tipo_o = 01
    //   64      : respuesta correcta → tipo_o = 10
    assign tipo_o = (contador <= 7'd31) ? 2'b00 :
                    (contador <= 7'd63) ? 2'b01 :
                                         2'b10;

    // =========================================================
    // Sub-bloque 5: Registro de preguntas usadas
    // =========================================================
    logic [9:0] used_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            used_reg <= 10'b0;
        end else if (marcar_usada && pregunta_sel_i <= 4'd9) begin
            used_reg[pregunta_sel_i] <= 1'b1;
        end
    end

    assign pregunta_usada_o = used_reg[pregunta_sel_i];

endmodule