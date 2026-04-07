`timescale 1ns/1ps

module uart_tx_tb;

    localparam int CLK_PERIOD_NS  = 10;
    localparam int BAUD_CLK_TICKS = 8;  
    // En hardware usarás 139 para 16 MHz / 115200,
    // pero en simulación conviene un valor pequeño para que corra rápido.

    logic clk;
    logic reset;
    logic tx_start;
    logic [7:0] tx_data_in;
    logic tx_data_out;
    logic tx_rdy;

    int tests_passed;
    int tests_failed;

    uart_tx #(
        .BAUD_CLK_TICKS(BAUD_CLK_TICKS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_data_out(tx_data_out),
        .tx_rdy(tx_rdy)
    );

    // ------------------------------------------------------------
    // Reloj
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // ------------------------------------------------------------
    // Utilidad de chequeo
    // ------------------------------------------------------------
    task automatic check_equal(
        input logic actual,
        input logic expected,
        input string msg
    );
        begin
            if (actual !== expected) begin
                $error("FALLO: %s | actual=%0b expected=%0b | t=%0t",
                       msg, actual, expected, $time);
                tests_failed++;
            end
            else begin
                tests_passed++;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Espera un número de ticks de baud internos del DUT
    // ------------------------------------------------------------
    task automatic wait_baud_ticks(input int n);
        int k;
        begin
            for (k = 0; k < n; k++) begin
                @(posedge dut.baud_rate_clk);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Envía un byte y verifica toda la trama UART
    // Formato esperado:
    // idle=1, start=0, 8 datos LSB first, stop=1
    // ------------------------------------------------------------
    task automatic send_and_check(input logic [7:0] data);
        int i;
        begin
            // Antes de iniciar, la línea debe estar en reposo
            check_equal(tx_data_out, 1'b1,
                        $sformatf("Idle antes de enviar 0x%02h", data));

            // Pulso de inicio
            @(posedge clk);
            tx_data_in <= data;
            tx_start   <= 1'b1;

            @(posedge clk);
            tx_start   <= 1'b0;

            // Esperar a que aparezca el start bit
            wait (tx_data_out === 1'b0);
            check_equal(tx_data_out, 1'b0,
                        $sformatf("Start bit para 0x%02h", data));

            // Verificar bits de datos
            // Se revisan en cada tick de baud posterior
            for (i = 0; i < 8; i++) begin
                @(posedge dut.baud_rate_clk);
                check_equal(tx_data_out, data[i],
                            $sformatf("Bit de dato %0d para 0x%02h", i, data));
            end

            // Verificar stop bit
            @(posedge dut.baud_rate_clk);
            check_equal(tx_data_out, 1'b1,
                        $sformatf("Stop bit para 0x%02h", data));

            // Verificar pulso tx_rdy
            @(posedge clk);
            check_equal(tx_rdy, 1'b1,
                        $sformatf("Pulso tx_rdy para 0x%02h", data));

            @(posedge clk);
            check_equal(tx_rdy, 1'b0,
                        $sformatf("tx_rdy de un ciclo para 0x%02h", data));

            // Verificar regreso a idle
            check_equal(tx_data_out, 1'b1,
                        $sformatf("Regreso a idle para 0x%02h", data));
        end
    endtask

    // ------------------------------------------------------------
    // Secuencia principal de pruebas
    // ------------------------------------------------------------
    initial begin
        tests_passed = 0;
        tests_failed = 0;

        reset      = 1'b1;
        tx_start   = 1'b0;
        tx_data_in = 8'h00;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        repeat (2) @(posedge clk);

        // Casos de prueba
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'hA5);
        send_and_check(8'h3C);
        send_and_check(8'h81);

        $display("========================================");
        $display("Tests pasados : %0d", tests_passed);
        $display("Tests fallidos: %0d", tests_failed);
        $display("========================================");

        if (tests_failed == 0) begin
            $display("RESULTADO FINAL: UART TX TB APROBADO");
        end
        else begin
            $fatal(1, "RESULTADO FINAL: UART TX TB FALLÓ");
        end

        #50;
        $finish;
    end

endmodule