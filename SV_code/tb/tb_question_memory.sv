`timescale 1ns/1ps

module tb_question_memory;

    logic       clk_i;
    logic       rst_i;
    logic [3:0] pregunta_sel_i;
    logic       next_char_i;
    logic       marcar_usada;
    logic [7:0] char_o;
    logic [1:0] tipo_o;
    logic       fin_bloque_o;
    logic       pregunta_usada_o;

    question_memory dut (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .pregunta_sel_i  (pregunta_sel_i),
        .next_char_i     (next_char_i),
        .marcar_usada    (marcar_usada),
        .char_o          (char_o),
        .tipo_o          (tipo_o),
        .fin_bloque_o    (fin_bloque_o),
        .pregunta_usada_o(pregunta_usada_o)
    );

    initial clk_i = 0;
    always #31.25 clk_i = ~clk_i;

    integer errores;

    task automatic pulso(ref logic senal);
        @(negedge clk_i); senal = 1;
        @(negedge clk_i); senal = 0;
    endtask

    task avanzar_chars(input integer n);
        integer k;
        for (k = 0; k < n; k++) begin
            @(negedge clk_i); next_char_i = 1;
            @(negedge clk_i); next_char_i = 0;
            @(posedge clk_i); #2;
            @(posedge clk_i); #2;
        end
    endtask

    // Tarea: leer e imprimir un bloque completo de pregunta
    task leer_pregunta(input logic [3:0] num_pregunta);
        string enunciado;
        string opcion_a, opcion_b, opcion_c, opcion_d;
        byte   respuesta;
        integer i;
        byte c;

        enunciado = "";
        opcion_a  = "";
        opcion_b  = "";
        opcion_c  = "";
        opcion_d  = "";

        pregunta_sel_i = num_pregunta;
        rst_i = 1; @(negedge clk_i); @(negedge clk_i); rst_i = 0;
        @(posedge clk_i); #2;
        @(posedge clk_i); #2;
        @(posedge clk_i); #2;

        // Leer enunciado (offsets 0-31)
        for (i = 0; i < 32; i++) begin
            c = char_o;
            if (c != 8'h20) enunciado = {enunciado, string'(c)};
            if (i < 31) avanzar_chars(1);
        end

        // Leer opcion A (offsets 32-45)
        avanzar_chars(1);
        for (i = 0; i < 14; i++) begin
            c = char_o;
            if (c != 8'h20) opcion_a = {opcion_a, string'(c)};
            if (i < 13) avanzar_chars(1);
        end

        // Leer opcion B (offsets 46-59)
        avanzar_chars(1);
        for (i = 0; i < 14; i++) begin
            c = char_o;
            if (c != 8'h20) opcion_b = {opcion_b, string'(c)};
            if (i < 13) avanzar_chars(1);
        end

        // Leer opcion C (offsets 60-73)
        avanzar_chars(1);
        for (i = 0; i < 14; i++) begin
            c = char_o;
            if (c != 8'h20) opcion_c = {opcion_c, string'(c)};
            if (i < 13) avanzar_chars(1);
        end

        // Leer opcion D (offsets 74-87)
        avanzar_chars(1);
        for (i = 0; i < 14; i++) begin
            c = char_o;
            if (c != 8'h20) opcion_d = {opcion_d, string'(c)};
            if (i < 13) avanzar_chars(1);
        end

        // Leer respuesta correcta (offset 88)
        avanzar_chars(1);
        respuesta = char_o;

        $display("  P%0d: %s", num_pregunta, enunciado);
        $display("    A: %s", opcion_a);
        $display("    B: %s", opcion_b);
        $display("    C: %s", opcion_c);
        $display("    D: %s", opcion_d);
        $display("    ANS: %s", string'(respuesta));
    endtask

    initial begin
        errores        = 0;
        rst_i          = 1;
        pregunta_sel_i = 4'd0;
        next_char_i    = 0;
        marcar_usada   = 0;

        $display("============================================");
        $display("  Testbench question_memory");
        $display("============================================");

        @(negedge clk_i); @(negedge clk_i);
        rst_i = 0;
        @(posedge clk_i); #2;
        @(posedge clk_i); #2;
        @(posedge clk_i); #2;

        // ── TEST 1: Reset ─────────────────────────────────────
        $display("\n[TEST 1] Reset sincrono");
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO"); errores++;
        end else
            $display("  OK: pregunta_usada_o=0");

        // ── TEST 2: Leer pregunta 0 completa ──────────────────
        $display("\n[TEST 2] Lectura completa pregunta 0");
        leer_pregunta(4'd0);

        // ── TEST 3: Leer pregunta 1 completa ──────────────────
        $display("\n[TEST 3] Lectura completa pregunta 1");
        leer_pregunta(4'd1);

        // ── TEST 4: Decodificador de indice ───────────────────
        $display("\n[TEST 4] Decodificador de indice");
        rst_i = 1; @(negedge clk_i); @(negedge clk_i); rst_i = 0;
        pregunta_sel_i = 4'd0;
        @(posedge clk_i); #2;

        if (tipo_o !== 2'b00) begin
            $display("  FALLO offset 0: tipo=%0b", tipo_o); errores++;
        end else $display("  OK: offset 0 -> tipo=00 (enunciado)");

        avanzar_chars(32);
        if (tipo_o !== 2'b01) begin
            $display("  FALLO offset 32: tipo=%0b", tipo_o); errores++;
        end else $display("  OK: offset 32 -> tipo=01 (opcion A)");

        avanzar_chars(14);
        if (tipo_o !== 2'b10) begin
            $display("  FALLO offset 46: tipo=%0b", tipo_o); errores++;
        end else $display("  OK: offset 46 -> tipo=10 (opcion B)");

        avanzar_chars(14);
        if (tipo_o !== 2'b11) begin
            $display("  FALLO offset 60: tipo=%0b", tipo_o); errores++;
        end else $display("  OK: offset 60 -> tipo=11 (opciones C/D)");

        // ── TEST 5: fin_bloque_o ──────────────────────────────
        $display("\n[TEST 5] fin_bloque_o en offset 88");
        rst_i = 1; @(negedge clk_i); @(negedge clk_i); rst_i = 0;
        avanzar_chars(88);
        if (!fin_bloque_o) begin
            $display("  FALLO"); errores++;
        end else $display("  OK: fin_bloque_o=1 en offset 88");

        avanzar_chars(1);
        if (fin_bloque_o) begin
            $display("  FALLO"); errores++;
        end else $display("  OK: contador reiniciado");

        // ── TEST 6: Registro de preguntas usadas ──────────────
        $display("\n[TEST 6] Registro de preguntas usadas");
        rst_i = 1; @(negedge clk_i); @(negedge clk_i); rst_i = 0;
        pregunta_sel_i = 4'd3;
        @(posedge clk_i); #2;

        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: pregunta 3 deberia estar libre"); errores++;
        end else $display("  OK: pregunta 3 libre");

        pulso(marcar_usada);
        @(posedge clk_i); #2;
        if (pregunta_usada_o !== 1'b1) begin
            $display("  FALLO: pregunta 3 deberia estar usada"); errores++;
        end else $display("  OK: pregunta 3 marcada como usada");

        pregunta_sel_i = 4'd5;
        @(posedge clk_i); #2;
        if (pregunta_usada_o !== 1'b0) begin
            $display("  FALLO: pregunta 5 deberia estar libre"); errores++;
        end else $display("  OK: pregunta 5 sigue libre");

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