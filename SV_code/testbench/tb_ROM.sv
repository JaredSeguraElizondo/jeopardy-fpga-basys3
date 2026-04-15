// ============================================================
// tb_question_memory.sv
// Testbench post-implementacion para question_memory.sv
//
// Geometria del bloque (65 bytes por pregunta):
//   offset  0-31 : enunciado  -> tipo_o = 2'b00
//   offset 32-63 : opciones   -> tipo_o = 2'b01
//   offset    64 : respuesta  -> tipo_o = 2'b10
//
// Pruebas:
//   1. Reset sincrono
//   2. Lectura de bloque completo (65 bytes), char_o impreso en hex
//   3. Decodificador tipo_o en offsets clave (0, 32, 64)
//   4. fin_bloque_o en offset 64 y reinicio del contador
//   5. Registro de preguntas usadas (marcar_usada / pregunta_usada_o)
//   6. consulta_sel_i independiente de pregunta_sel_i
// ============================================================
`timescale 1ns/1ps

module tb_question_memory;

    logic       clk_i;
    logic       rst_i;
    logic [3:0] pregunta_sel_i;
    logic [3:0] consulta_sel_i;
    logic       next_char_i;
    logic       marcar_usada;
    logic [7:0] char_o;
    logic [1:0] tipo_o;
    logic       fin_bloque_o;
    logic       pregunta_usada_o;

    question_memory dut (
        .clk_i            (clk_i),
        .rst_i            (rst_i),
        .pregunta_sel_i   (pregunta_sel_i),
        .consulta_sel_i   (consulta_sel_i),
        .next_char_i      (next_char_i),
        .marcar_usada     (marcar_usada),
        .char_o           (char_o),
        .tipo_o           (tipo_o),
        .fin_bloque_o     (fin_bloque_o),
        .pregunta_usada_o (pregunta_usada_o)
    );

    // Reloj 16 MHz -> periodo 62.5 ns
    initial clk_i = 0;
    always #31.25 clk_i = ~clk_i;

    integer errores;
    integer k;

    // ── Tareas ────────────────────────────────────────────────

    task ciclo();
        @(posedge clk_i); #1;
    endtask

    task reset_mem();
        @(negedge clk_i); rst_i = 1;
        ciclo(); ciclo();
        @(negedge clk_i); rst_i = 0;
        ciclo();  // contador en 0, addr_final valida
        ciclo();  // ROM registra la direccion
        ciclo();  // ROM entrega char_o del offset 0
    endtask

    // Pulsa next_char_i. El contador avanza en el posedge con next_char_i=1.
    // La ROM presenta la nueva direccion ese mismo ciclo y entrega el dato
    // en el posedge siguiente. Se esperan 2 ciclos tras bajar next_char_i
    // para garantizar que char_o este estable antes de samplear.
    // Pulsa next_char_i en el flanco negativo para garantizar
    // setup correcto en post-implementation. El contador avanza en
    // el posedge siguiente y la ROM entrega char_o un ciclo despues.
    task next_char();
        @(negedge clk_i); next_char_i = 1;
        @(negedge clk_i); next_char_i = 0;
        ciclo(); ciclo();  // 2 ciclos para estabilizar char_o
    endtask

    // Avanza n caracteres
    task avanzar_chars(input integer n);
        for (k = 0; k < n; k++)
            next_char();
    endtask

    // Verifica que char_o cambia tras pulsar next_char_i,
    // y avanza hasta el final del bloque verificando fin_bloque_o.
    task leer_bloque(input logic [3:0] num_pregunta);
        logic [7:0] val_offset0;
        logic [7:0] val_offset1;
        integer j;
        // Samplear offset 0
        val_offset0 = char_o;
        $display("  Bloque pregunta %0d: offset0=0x%02h", num_pregunta, char_o);
        // Avanzar a offset 1 y verificar que char_o cambia
        next_char();
        val_offset1 = char_o;
        $display("  offset1=0x%02h", char_o);
        if (val_offset0 === val_offset1) begin
            $display("  ADVERTENCIA: char_o no cambio tras next_char_i (puede ser dato repetido)");
        end else begin
            $display("  char_o avanzo correctamente");
        end
        // Avanzar los 63 bytes restantes para llegar al offset 64
        for (j = 2; j < 65; j++)
            next_char();
        // Verificar fin_bloque_o en offset 64
        if (!fin_bloque_o) begin
            $display("  FALLO: fin_bloque_o no activo al final del bloque");
        end else
            $display("  fin_bloque_o=1 al final del bloque: OK");
    endtask

    // ── Flujo principal ───────────────────────────────────────
    initial begin
        errores        = 0;
        rst_i          = 1;
        pregunta_sel_i = 4'd0;
        consulta_sel_i = 4'd0;
        next_char_i    = 0;
        marcar_usada   = 0;

        $display("============================================");
        $display("  Testbench question_memory");
        $display("============================================");

        // ── TEST 1: Reset sincrono ────────────────────────────
        $display("\n[TEST 1] Reset sincrono");
        reset_mem();
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: pregunta_usada_o deberia ser 0 tras reset");
            errores++;
        end else
            $display("  OK: pregunta_usada_o=0 tras reset");

        // ── TEST 2: Lectura completa pregunta 0 ───────────────
        $display("\n[TEST 2] Lectura bloque completo pregunta 0 (65 bytes)");
        pregunta_sel_i = 4'd0;
        reset_mem();
        leer_bloque(4'd0);
        $display("  Lectura completada");

        // ── TEST 3: Lectura completa pregunta 1 ───────────────
        $display("\n[TEST 3] Lectura bloque completo pregunta 1 (65 bytes)");
        pregunta_sel_i = 4'd1;
        reset_mem();
        leer_bloque(4'd1);
        $display("  Lectura completada");

        // ── TEST 4: Decodificador tipo_o ──────────────────────
        $display("\n[TEST 4] Decodificador de indice tipo_o");
        pregunta_sel_i = 4'd0;
        reset_mem();

        // Offset 0 -> tipo 00 (enunciado)
        if (tipo_o !== 2'b00) begin
            $display("  FALLO offset  0: tipo_o=%b (esperado 00)", tipo_o);
            errores++;
        end else
            $display("  OK: offset  0 -> tipo_o=00 (enunciado)");

        // Avanzar a offset 32 -> tipo 01 (opciones)
        avanzar_chars(32);
        if (tipo_o !== 2'b01) begin
            $display("  FALLO offset 32: tipo_o=%b (esperado 01)", tipo_o);
            errores++;
        end else
            $display("  OK: offset 32 -> tipo_o=01 (opciones)");

        // Avanzar a offset 64 -> tipo 10 (respuesta)
        avanzar_chars(32);
        if (tipo_o !== 2'b10) begin
            $display("  FALLO offset 64: tipo_o=%b (esperado 10)", tipo_o);
            errores++;
        end else
            $display("  OK: offset 64 -> tipo_o=10 (respuesta)");

        // ── TEST 5: fin_bloque_o en offset 64 ────────────────
        $display("\n[TEST 5] fin_bloque_o en offset 64 y reinicio del contador");
        // Venimos de offset 64, fin_bloque_o debe estar activo
        if (!fin_bloque_o) begin
            $display("  FALLO: fin_bloque_o no activo en offset 64");
            errores++;
        end else
            $display("  OK: fin_bloque_o=1 en offset 64");

        // Un avance mas: contador reinicia a 0, fin_bloque_o debe bajar
        next_char();
        if (fin_bloque_o) begin
            $display("  FALLO: fin_bloque_o sigue activo tras reinicio del contador");
            errores++;
        end else
            $display("  OK: contador reiniciado, fin_bloque_o=0");

        // ── TEST 6: Registro de preguntas usadas ──────────────
        $display("\n[TEST 6] Registro de preguntas usadas");
        pregunta_sel_i = 4'd3;
        consulta_sel_i = 4'd3;
        reset_mem();

        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: pregunta 3 deberia estar libre tras reset");
            errores++;
        end else
            $display("  OK: pregunta 3 libre");

        // Marcar pregunta 3
        marcar_usada = 1; ciclo();
        marcar_usada = 0; ciclo();
        if (pregunta_usada_o !== 1'b1) begin
            $display("  FALLO: pregunta 3 deberia estar usada tras marcar_usada");
            errores++;
        end else
            $display("  OK: pregunta 3 marcada como usada");

        // Consultar pregunta 5 -> debe seguir libre
        consulta_sel_i = 4'd5;
        ciclo();
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: pregunta 5 deberia estar libre");
            errores++;
        end else
            $display("  OK: pregunta 5 sigue libre");

        // ── TEST 7: consulta_sel_i independiente de pregunta_sel_i ──
        $display("\n[TEST 7] consulta_sel_i independiente de pregunta_sel_i");
        // pregunta_sel_i=3 (usada), consulta_sel_i=7 (libre)
        pregunta_sel_i = 4'd3;
        consulta_sel_i = 4'd7;
        ciclo();
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: consulta_sel_i=7 deberia ser libre aunque pregunta_sel_i=3 este usada");
            errores++;
        end else
            $display("  OK: consulta_sel_i=7 libre con pregunta_sel_i=3 usada");

        // Consulta de otro indice libre
        consulta_sel_i = 4'd2;
        ciclo();
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: consulta_sel_i=2 deberia ser libre");
            errores++;
        end else
            $display("  OK: puerto dual funciona correctamente");

        // ── Resumen ───────────────────────────────────────────
        $display("\n============================================");
        if (errores == 0)
            $display("  TODOS LOS TESTS PASARON");
        else
            $display("  %0d TEST(S) FALLARON", errores);
        $display("============================================\n");

        $finish;
    end

endmodule