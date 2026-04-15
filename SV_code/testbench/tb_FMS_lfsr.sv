// ============================================================
// tb_question_picker.sv
// Testbench post-implementacion para question_picker.sv
//
// El picker se prueba de forma aislada (sin question_memory).
// pregunta_usada_i se modela con un registro local used_reg,
// indexado como used_reg[lfsr_val_o - 1], igual que
// question_memory con consulta_sel_i = lfsr_val_o - 1.
//
// Pruebas:
//   1. Reset sincrono
//   2. Solicitar -> SEARCHING -> FOUND, pregunta en rango 0-9
//   3. Confirmar baja q_valid, regresa a IDLE
//   4. Partida completa: 7 rondas sin repeticion
//   5. Carga de semilla distinta
// ============================================================
`timescale 1ns/1ps

module tb_question_picker;

    logic       clk_i;
    logic       rst_i;
    logic       solicitar_i;
    logic       confirmar_i;
    logic       pregunta_usada_i;
    logic [3:0] seed_i;
    logic       load_seed_i;
    logic [3:0] pregunta_sel_o;
    logic       q_valid_o;
    logic [3:0] lfsr_val_o;

    // Registro local que modela used_reg de question_memory
    logic [9:0] used_reg;

    question_picker dut (
        .clk_i            (clk_i),
        .rst_i            (rst_i),
        .solicitar_i      (solicitar_i),
        .confirmar_i      (confirmar_i),
        .pregunta_usada_i (pregunta_usada_i),
        .seed_i           (seed_i),
        .load_seed_i      (load_seed_i),
        .pregunta_sel_o   (pregunta_sel_o),
        .q_valid_o        (q_valid_o),
        .lfsr_val_o       (lfsr_val_o)
    );

    // Reloj 16 MHz -> periodo 62.5 ns
    initial clk_i = 0;
    always #31.25 clk_i = ~clk_i;

    // Modelo de pregunta_usada_i igual que question_memory:
    // consulta_sel_i = lfsr_val_o - 1 -> used_reg[consulta_sel_i]
    assign pregunta_usada_i = (lfsr_val_o >= 4'd1 && lfsr_val_o <= 4'd10)
                              ? used_reg[lfsr_val_o - 4'd1]
                              : 1'b0;

    integer      errores;
    integer      ronda;
    integer      ciclos_espera;
    integer      r;
    logic        repetida;
    logic [3:0]  preguntas_jugadas [0:6];

    // ── Tareas ────────────────────────────────────────────────

    task ciclo();
        @(posedge clk_i); #1;
    endtask

    task reset_picker();
        rst_i       = 1;
        solicitar_i = 0;
        confirmar_i = 0;
        load_seed_i = 0;
        ciclo(); ciclo();
        rst_i = 0;
        ciclo();
    endtask

    task pulso_solicitar();
        solicitar_i = 1; ciclo();
        solicitar_i = 0;
    endtask

    task pulso_confirmar();
        confirmar_i = 1; ciclo();
        confirmar_i = 0;
    endtask

    // Espera hasta que q_valid_o sube (max 30 ciclos)
    // Imprime cada candidato evaluado en SEARCHING
    task esperar_found();
        ciclos_espera = 0;
        while (!q_valid_o && ciclos_espera < 30) begin
            $display("    [SEARCHING] lfsr_val=%0d usada=%0b",
                     lfsr_val_o, pregunta_usada_i);
            ciclo();
            ciclos_espera++;
        end
        if (!q_valid_o) begin
            $display("  ERROR: timeout esperando q_valid_o");
            errores++;
        end
    endtask

    // ── Flujo principal ───────────────────────────────────────
    initial begin
        errores  = 0;
        used_reg = 10'b0;
        seed_i   = 4'b0011;

        $display("============================================");
        $display("  Testbench question_picker");
        $display("============================================");

        // ── TEST 1: Reset sincrono ────────────────────────────
        $display("\n[TEST 1] Reset sincrono");
        reset_picker();
        if (q_valid_o !== 1'b0) begin
            $display("  FALLO: q_valid_o debe ser 0 tras reset, vale %b", q_valid_o);
            errores++;
        end else
            $display("  OK: q_valid_o=0, estado=IDLE");

        // ── TEST 2: Solicitar -> FOUND ────────────────────────
        $display("\n[TEST 2] Solicitar -> SEARCHING -> FOUND");
        pulso_solicitar();
        esperar_found();
        if (q_valid_o) begin
            $display("  [FOUND] pregunta_sel_o = %0d", pregunta_sel_o);
            if (pregunta_sel_o > 4'd9) begin
                $display("  FALLO: pregunta_sel_o fuera de rango [0-9]: %0d", pregunta_sel_o);
                errores++;
            end else
                $display("  OK: pregunta en rango [0-9]");
        end

        // ── TEST 3: Confirmar baja q_valid ────────────────────
        $display("\n[TEST 3] Confirmar -> q_valid_o baja, regresa a IDLE");
        pulso_confirmar();
        ciclo();
        if (q_valid_o !== 1'b0) begin
            $display("  FALLO: q_valid_o no bajo tras confirmar");
            errores++;
        end else
            $display("  OK: q_valid_o=0, estado=IDLE");

        // ── TEST 4: Partida completa - 7 rondas ───────────────
        $display("\n[TEST 4] Partida completa - 7 rondas sin repeticion");
        reset_picker();
        used_reg = 10'b0;

        // Cargar semilla
        load_seed_i = 1; ciclo();
        load_seed_i = 0;
        $display("  Semilla cargada: %0d", seed_i);

        for (ronda = 1; ronda <= 7; ronda++) begin
            $display("\n  ── Ronda %0d (usadas: %010b) ──", ronda, used_reg);

            pulso_solicitar();
            esperar_found();

            if (q_valid_o) begin
                $display("    [FOUND] pregunta_sel_o = %0d", pregunta_sel_o);

                // Verificar no repeticion contra rondas anteriores
                repetida = 0;
                for (r = 0; r < ronda - 1; r++) begin
                    if (preguntas_jugadas[r] === pregunta_sel_o)
                        repetida = 1;
                end

                if (repetida) begin
                    $display("    FALLO: pregunta %0d REPETIDA", pregunta_sel_o);
                    errores++;
                end else
                    $display("    OK: pregunta %0d no repetida", pregunta_sel_o);

                preguntas_jugadas[ronda - 1] = pregunta_sel_o;
                used_reg[pregunta_sel_o]     = 1'b1;

                pulso_confirmar();
                ciclo();

                if (q_valid_o) begin
                    $display("    FALLO: q_valid_o no bajo tras confirmar en ronda %0d", ronda);
                    errores++;
                end
            end
        end

        // ── TEST 5: Semilla distinta ──────────────────────────
        $display("\n[TEST 5] Carga de semilla distinta (seed=4'b1010)");
        reset_picker();
        used_reg = 10'b0;
        seed_i   = 4'b1010;
        load_seed_i = 1; ciclo();
        load_seed_i = 0;

        pulso_solicitar();
        esperar_found();
        if (q_valid_o) begin
            $display("  OK: pregunta encontrada con nueva semilla: %0d", pregunta_sel_o);
            pulso_confirmar();
        end

        // ── TEST 6: Forzar descarte de candidatos usados ─────
        // Se marcan 9 de las 10 preguntas como usadas.
        // Solo la pregunta 7 queda libre.
        // El picker debe descartar todos los candidatos usados
        // y retornar exactamente pregunta 7.
        $display("\n[TEST 6] Descarte forzado - solo pregunta 7 disponible");
        reset_picker();
        // Marcar todas menos la pregunta 7 (bit 7 queda en 0)
        used_reg = 10'b1101111111;  // bits 0-6 y 8-9 usados, bit 7 libre
        seed_i   = 4'b1001;        // semilla por defecto
        load_seed_i = 1; ciclo();
        load_seed_i = 0;
        $display("  used_reg = %010b (solo pregunta 7 libre)", used_reg);

        pulso_solicitar();
        esperar_found();

        if (q_valid_o) begin
            $display("  [FOUND] pregunta_sel_o = %0d", pregunta_sel_o);
            if (pregunta_sel_o !== 4'd7) begin
                $display("  FALLO: se esperaba pregunta 7, se obtuvo %0d", pregunta_sel_o);
                errores++;
            end else
                $display("  OK: picker descarto todos los usados y retorno pregunta 7");
            pulso_confirmar();
            ciclo();
            if (q_valid_o) begin
                $display("  FALLO: q_valid_o no bajo tras confirmar");
                errores++;
            end else
                $display("  OK: q_valid_o=0 tras confirmar");
        end

        // ── Resumen ───────────────────────────────────────────
        $display("\n============================================");
        $display("  RESUMEN PARTIDA (TEST 4)");
        for (r = 0; r < 7; r++)
            $display("  Ronda %0d: pregunta %0d", r + 1, preguntas_jugadas[r]);
        $display("  Usadas: %010b", used_reg);
        $display("============================================");
        if (errores == 0)
            $display("  TODOS LOS TESTS PASARON");
        else
            $display("  %0d TEST(S) FALLARON", errores);
        $display("============================================\n");

        $finish;
    end

endmodule