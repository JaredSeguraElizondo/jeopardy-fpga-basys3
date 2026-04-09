// tb_score_counter.sv
// Testbench autoverificable para score_counter.

`timescale 1ns/1ps

module tb_score_counter;

    // -------------------------------------------------------------------------
    // Parámetros
    // -------------------------------------------------------------------------
    parameter W = 3;

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic       clk, rst;
    logic       win_j1, win_j2;
    logic [W-1:0] score_j1, score_j2;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    score_counter #(.W(W)) dut (
        .clk     (clk),
        .rst     (rst),
        .win_j1  (win_j1),
        .win_j2  (win_j2),
        .score_j1(score_j1),
        .score_j2(score_j2)
    );

    // -------------------------------------------------------------------------
    // Reloj: periodo 10 ns
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Contador de errores
    // -------------------------------------------------------------------------
    int errores = 0;

    // -------------------------------------------------------------------------
    // Tarea: avanzar un ciclo con entradas dadas
    // -------------------------------------------------------------------------
    task automatic ciclo(
        input logic i_win_j1,
        input logic i_win_j2
    );
        win_j1 = i_win_j1;
        win_j2 = i_win_j2;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificar puntajes
    // -------------------------------------------------------------------------
    task automatic verificar(
        input string     descripcion,
        input logic [W-1:0] exp_j1,
        input logic [W-1:0] exp_j2
    );
        if (score_j1 !== exp_j1 || score_j2 !== exp_j2) begin
            $display("FALLO [%s]", descripcion);
            $display("  score_j1: esp=%0d obt=%0d", exp_j1, score_j1);
            $display("  score_j2: esp=%0d obt=%0d", exp_j2, score_j2);
            errores++;
        end else
            $display("OK    [%s]", descripcion);
    endtask

    // =========================================================================
    // Estimulos
    // =========================================================================
    initial begin
        // Estado inicial
        rst    = 1'b1;
        win_j1 = 1'b0;
        win_j2 = 1'b0;

        // =====================================================================
        // CASO 0: Reset inicial — ambos scores en cero
        // =====================================================================
        @(posedge clk); #1;
        verificar("Reset inicial: score_j1=0, score_j2=0",
                  W'(0), W'(0));
        rst = 1'b0;

        // =====================================================================
        // CASO 1: win_j1 inactivo — score_j1 no cambia
        // =====================================================================
        ciclo(1'b0, 1'b0);
        verificar("Sin victorias: scores sin cambio",
                  W'(0), W'(0));

        // =====================================================================
        // CASO 2: J1 gana 3 rondas consecutivas
        // =====================================================================
        ciclo(1'b1, 1'b0);
        verificar("J1 gana ronda 1: score_j1=1",
                  W'(1), W'(0));

        ciclo(1'b1, 1'b0);
        verificar("J1 gana ronda 2: score_j1=2",
                  W'(2), W'(0));

        ciclo(1'b1, 1'b0);
        verificar("J1 gana ronda 3: score_j1=3",
                  W'(3), W'(0));

        // =====================================================================
        // CASO 3: J2 gana 2 rondas consecutivas
        // =====================================================================
        ciclo(1'b0, 1'b1);
        verificar("J2 gana ronda 1: score_j2=1",
                  W'(3), W'(1));

        ciclo(1'b0, 1'b1);
        verificar("J2 gana ronda 2: score_j2=2",
                  W'(3), W'(2));

        // =====================================================================
        // CASO 4: Ronda sin ganador — ningún score cambia
        // =====================================================================
        ciclo(1'b0, 1'b0);
        verificar("Ronda sin ganador: scores sin cambio",
                  W'(3), W'(2));

        // =====================================================================
        // CASO 5: win_j1 y win_j2 simultáneos
        // Por diseño no ocurre, pero el hardware debe responder predeciblemente:
        // ambos contadores se incrementan (dos if independientes)
        // =====================================================================
        ciclo(1'b1, 1'b1);
        verificar("win_j1 y win_j2 simultaneos: ambos incrementan",
                  W'(4), W'(3));

        // =====================================================================
        // CASO 6: Reset tras capturas — ambos scores vuelven a cero
        // =====================================================================
        rst = 1'b1;
        @(posedge clk); #1;
        verificar("Reset tras capturas: score_j1=0, score_j2=0",
                  W'(0), W'(0));
        rst = 1'b0;

        // =====================================================================
        // CASO 7: J2 gana primero, luego J1 — verificar independencia
        // =====================================================================
        ciclo(1'b0, 1'b1);
        verificar("J2 gana primero tras reset: score_j2=1",
                  W'(0), W'(1));

        ciclo(1'b1, 1'b0);
        verificar("J1 gana despues: score_j1=1",
                  W'(1), W'(1));

        // =====================================================================
        // Resultado final
        // =====================================================================
        $display("--------------------------------------------");
        if (errores == 0)
            $display("TODOS LOS CASOS PASARON (0 errores)");
        else
            $display("FALLARON %0d CASO(S)", errores);
        $display("--------------------------------------------");

        $finish;
    end

endmodule