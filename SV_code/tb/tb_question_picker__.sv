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
    logic [9:0] used_reg;

    question_picker dut (
        .clk_i           (clk_i),
        .rst_i           (rst_i),
        .solicitar_i     (solicitar_i),
        .confirmar_i     (confirmar_i),
        .pregunta_usada_i(pregunta_usada_i),
        .seed_i          (seed_i),
        .load_seed_i     (load_seed_i),
        .pregunta_sel_o  (pregunta_sel_o),
        .q_valid_o       (q_valid_o),
        .lfsr_val_o      (lfsr_val_o)
    );

    initial clk_i = 0;
    always #31.25 clk_i = ~clk_i;

    // Consulta el candidato actual del LFSR contra el registro de usadas
    assign pregunta_usada_i = (lfsr_val_o >= 4'd1 && lfsr_val_o <= 4'd10) ?
                               used_reg[lfsr_val_o - 4'd1] : 1'b0;

    task pulso_solicitar();
        @(negedge clk_i); solicitar_i = 1;
        @(negedge clk_i); solicitar_i = 0;
    endtask

    task pulso_confirmar();
        @(negedge clk_i); confirmar_i = 1;
        @(negedge clk_i); confirmar_i = 0;
    endtask

    integer ronda;
    logic [3:0] preguntas_jugadas [0:6];

    initial begin
        rst_i       = 1;
        solicitar_i = 0;
        confirmar_i = 0;
        seed_i      = 4'b0011; // Cambiar aqui para probar distintas semillas
        load_seed_i = 0;
        used_reg    = 10'b0;

        $display("============================================");
        $display("  Simulacion partida completa - 7 rondas");
        $display("============================================");

        @(negedge clk_i); @(negedge clk_i);
        rst_i = 0;

        @(negedge clk_i); load_seed_i = 1;
        @(negedge clk_i); load_seed_i = 0;
        $display("Semilla: %0d", seed_i);

        for (ronda = 1; ronda <= 7; ronda++) begin
            $display("\n── RONDA %0d ──", ronda);
            $display("  Usadas: %010b", used_reg);
            $display("  [IDLE]");

            pulso_solicitar();
            $display("  [SEARCHING] buscando...");

            begin : bloque_busqueda
                integer ciclos;
                ciclos = 0;
                while (!q_valid_o) begin
                    @(posedge clk_i); #1;
                    ciclos++;
                    $display("  [SEARCHING] LFSR=%0d usada=%0b",
                        lfsr_val_o, pregunta_usada_i);
                    if (ciclos > 50) begin
                        $display("  ERROR: timeout en ronda %0d", ronda);
                        $finish;
                    end
                end
            end

            $display("  [FOUND] pregunta=%0d", pregunta_sel_o);

            begin : bloque_verificar
                integer r;
                logic   rep;
                rep = 0;
                for (r = 0; r < ronda-1; r++)
                    if (preguntas_jugadas[r] === pregunta_sel_o) rep = 1;
                if (rep)
                    $display("  *** ERROR: pregunta %0d REPETIDA ***", pregunta_sel_o);
                else
                    $display("  OK: pregunta %0d", pregunta_sel_o);
            end

            preguntas_jugadas[ronda-1] = pregunta_sel_o;
            used_reg[pregunta_sel_o]   = 1'b1;

            pulso_confirmar();
            @(posedge clk_i); #1;
            $display("  [IDLE]");
        end

        $display("\n============================================");
        $display("  RESUMEN");
        $display("============================================");
        for (ronda = 0; ronda < 7; ronda++)
            $display("  Ronda %0d: pregunta %0d", ronda+1, preguntas_jugadas[ronda]);
        $display("  Usadas: %010b", used_reg);
        $display("============================================\n");

        $finish;
    end

endmodule