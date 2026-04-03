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
// Layout ROM (89 bytes/pregunta):
//   [0 -31] Enunciado   (32 bytes)
//   [32-45] Opcion A    (14 bytes)
//   [46-59] Opcion B    (14 bytes)
//   [60-73] Opcion C    (14 bytes)
//   [74-87] Opcion D    (14 bytes)
//   [88]    Respuesta correcta ASCII
// ============================================================

module question_memory (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic [3:0] pregunta_sel_i,  // Numero de pregunta (0-9) del question_picker
    input  logic       next_char_i,     // Pulso para avanzar al siguiente caracter
    input  logic       marcar_usada,    // Pulso de la UC para marcar pregunta como jugada
    output logic [7:0] char_o,          // Caracter ASCII actual de la ROM
    output logic [1:0] tipo_o,          // Seccion actual: 00=enunciado,01=A,10=B,11=C/D
    output logic       fin_bloque_o,    // Fin del bloque de la pregunta actual
    output logic       pregunta_usada_o // 1 si la pregunta ya fue jugada en esta partida
);

    // ── Parametros ────────────────────────────────────────────
    localparam BYTES_PER_Q = 7'd89;  // Bytes por pregunta
    localparam MAX_OFFSET  = 7'd88;  // Ultimo byte del bloque (0-88)

    // =========================================================
    // Sub-bloque 3: Contador de caracteres
    // =========================================================
    logic [6:0] contador;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            contador <= 7'd0;
        end else if (next_char_i) begin
            if (contador == MAX_OFFSET)
                contador <= 7'd0;   // Reinicio automatico al llegar al fin
            else
                contador <= contador + 7'd1;
        end
    end

    // fin_bloque_o: se activa cuando el contador llega al ultimo byte
    assign fin_bloque_o = (contador == MAX_OFFSET);

    // =========================================================
    // Sub-bloque 1: Logica de direccion base
    // =========================================================
    // addr_final = pregunta_sel_i * 89 + contador
    // Maximo: 9*89+88 = 889 < 1024 (cabe en 10 bits)
    logic [9:0] addr_final;

    always_comb begin
        addr_final = (pregunta_sel_i * BYTES_PER_Q) + {3'b000, contador};
    end

    // =========================================================
    // Sub-bloque 2: ROM IP Catalog
    // =========================================================
    // Instancia generada por Vivado IP Catalog:
    //   - Width : 8 bits
    //   - Depth : 1024 palabras
    //   - Latencia: 1 ciclo (modo Read First)
    //   - Archivo: questions.coe
    //
    // NOTA: el nombre blk_mem_gen_0 debe coincidir con el IP
    // generado en Vivado. Ajustar si se usa otro nombre.
    blk_mem_gen_0 u_rom (
        .clka  (clk_i),
        .addra (addr_final),
        .douta (char_o)
    );

    // =========================================================
    // Sub-bloque 4: Decodificador de indice
    // =========================================================
    // Determina que seccion del bloque se esta leyendo
    // segun el valor actual del contador:
    //   0  - 31 : enunciado  → tipo_o = 00
    //   32 - 45 : opcion A   → tipo_o = 01
    //   46 - 59 : opcion B   → tipo_o = 10
    //   60 - 88 : opcion C/D → tipo_o = 11
    always_comb begin
        if      (contador <= 7'd31) tipo_o = 2'b00;
        else if (contador <= 7'd45) tipo_o = 2'b01;
        else if (contador <= 7'd59) tipo_o = 2'b10;
        else                        tipo_o = 2'b11;
    end

    // =========================================================
    // Sub-bloque 5: Registro de preguntas usadas
    // =========================================================
    // Vector de 10 bits, bit i = pregunta i ya jugada
    logic [9:0] used_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            used_reg <= 10'b0;
        end else if (marcar_usada && pregunta_sel_i <= 4'd9) begin
            used_reg[pregunta_sel_i] <= 1'b1;
        end
    end

    // pregunta_usada_o: consulta combinacional del registro
    assign pregunta_usada_o = used_reg[pregunta_sel_i];

endmodule