`timescale 1ns / 1ps

module tb_temporizador;

    // -------------------------------------------------------------------------
    // Parámetros de simulación
    // -------------------------------------------------------------------------
    localparam FREQ      = 200; // Hz (frecuencia de reloj para la simulación, mucho más baja que en hardware real)
    localparam TIME      = 1;
    localparam COUNT     = $clog2(FREQ * TIME);
    localparam COUNT_MAX = FREQ * TIME;

    // Periodo de reloj: 200 Hz → 5 ms
    localparam CLK_PERIOD = 5; // ms (aproximado para xsim)

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic             clk;
    logic             rst;
    logic             en;
    logic             timeout;
    logic [COUNT-1:0] count;

    // Contadores de pruebas
    int tests_passed = 0;
    int tests_failed = 0;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    temporizador #(
        .FREQ  (FREQ),
        .TIME  (TIME),
        .COUNT (COUNT)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .en      (en),
        .timeout (timeout),
        .count   (count)
    );

    // -------------------------------------------------------------------------
    // Generación de reloj (negedge es el flanco activo del DUT)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Tarea: verificación con reporte
    // -------------------------------------------------------------------------
    task automatic check(
        input string  test_name,
        input logic   got,
        input logic   expected
    );
        if (got === expected) begin
            $display("[PASS] %s | got=%0b expected=%0b", test_name, got, expected);
            tests_passed++;
        end else begin
            $display("[FAIL] %s | got=%0b expected=%0b", test_name, got, expected);
            tests_failed++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: esperar N flancos de bajada (flanco activo del DUT)
    // -------------------------------------------------------------------------
    task automatic wait_negedge(input int n);
        repeat (n) @(negedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Estímulos y verificación
    // -------------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  Testbench: temporizador (FREQ=%0d, TIME=%0d)", FREQ, TIME);
        $display("============================================================");

        // Condición inicial
        rst = 1;
        en  = 0;

        // ------------------------------------------------------------------
        // TEST 1: Reset activo → count=0, timeout=0
        // ------------------------------------------------------------------
        wait_negedge(2);
        check("T1 count==0  tras reset", (count === '0),   1'b1);
        check("T1 timeout==0 tras reset", timeout,          1'b0);

        // ------------------------------------------------------------------
        // TEST 2: Sin enable → contador no avanza
        // ------------------------------------------------------------------
        rst = 0;
        wait_negedge(5);
        check("T2 count==0  sin enable",  (count === '0),  1'b1);
        check("T2 timeout==0 sin enable", timeout,          1'b0);

        // ------------------------------------------------------------------
        // TEST 3: Con enable → contador avanza
        // ------------------------------------------------------------------
        en = 1;
        wait_negedge(1);
        check("T3 count>0 con enable", (count > 0), 1'b1);

        // ------------------------------------------------------------------
        // TEST 4: Reset en medio del conteo → vuelve a 0
        // ------------------------------------------------------------------
        wait_negedge(100);
        rst = 1;
        wait_negedge(1);
        check("T4 count==0 tras reset en conteo", (count === '0), 1'b1);
        check("T4 timeout==0 tras reset en conteo", timeout,       1'b0);
        rst = 0;

        // ------------------------------------------------------------------
        // TEST 5: Enable se baja → timeout se mantiene en 0, count se congela
        // ------------------------------------------------------------------
        en = 1;
        wait_negedge(200);
        en = 0;
        wait_negedge(5);
        check("T5 timeout==0 con en=0", timeout, 1'b0);

        // ------------------------------------------------------------------
        // TEST 6: Conteo completo → timeout se activa exactamente en COUNT_MAX-1
        // ------------------------------------------------------------------
        rst = 1; wait_negedge(1); rst = 0;
        en  = 1;

        // Avanzar hasta un ciclo antes del timeout esperado
        wait_negedge(COUNT_MAX - 1);
        check("T6 timeout==0 un ciclo antes", timeout, 1'b0);

        // En este negedge el contador llega a COUNT_MAX-1 → timeout debe ser 1
        @(negedge clk);
        check("T6 timeout==1 en COUNT_MAX-1", timeout, 1'b1);

        // ------------------------------------------------------------------
        // TEST 7: Tras el timeout el contador se reinicia automáticamente
        // ------------------------------------------------------------------
        @(negedge clk);
        check("T7 count==0  tras timeout",  (count === '0), 1'b1);
        check("T7 timeout==0 tras timeout", timeout,         1'b0);

        // ------------------------------------------------------------------
        // TEST 8: Segundo ciclo completo (timeout periódico)
        // ------------------------------------------------------------------
        wait_negedge(COUNT_MAX - 1);
        check("T8 timeout==0 un ciclo antes (2do ciclo)", timeout, 1'b0);
        @(negedge clk);
        check("T8 timeout==1 en COUNT_MAX-1 (2do ciclo)", timeout, 1'b1);

        // ------------------------------------------------------------------
        // Resumen final
        // ------------------------------------------------------------------
        $display("============================================================");
        $display("  Resultado: %0d/%0d pruebas pasaron",
                 tests_passed, tests_passed + tests_failed);
        if (tests_failed == 0)
            $display("  Estado: TODOS LOS TESTS PASARON ✓");
        else
            $display("  Estado: %0d TESTS FALLARON ✗", tests_failed);
        $display("============================================================");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout de simulación (seguro contra bucles infinitos)
    // -------------------------------------------------------------------------
    initial begin
        // 3 ciclos completos + margen
        #(CLK_PERIOD * COUNT_MAX * 3 + 10_000);
        $display("[ERROR] Timeout de simulación alcanzado — posible bucle infinito");
        $finish;
    end

    initial begin
    $dumpfile("tb_temporizador.vcd");
    $dumpvars(0, tb_temporizador);
end

endmodule