`timescale 1ns/1ps

module uart_tb;

    localparam CLK_PERIOD_NS          = 10;
    localparam TX_BAUD_CLK_TICKS      = 8;
    localparam RX_BAUD_X16_CLK_TICKS  = 4;

    logic clk;
    logic reset;

    logic       tx_start;
    logic [7:0] tx_data_in;
    logic       tx_data_out;
    logic       tx_rdy;

    logic       rx_data_in;
    logic [7:0] rx_data_out;
    logic       rx_data_rdy;

    integer tests_passed;
    integer tests_failed;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart #(
        .TX_BAUD_CLK_TICKS(TX_BAUD_CLK_TICKS),
        .RX_BAUD_X16_CLK_TICKS(RX_BAUD_X16_CLK_TICKS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_data_out(tx_data_out),
        .tx_rdy(tx_rdy),
        .rx_data_in(rx_data_in),
        .rx_data_out(rx_data_out),
        .rx_data_rdy(rx_data_rdy)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // ------------------------------------------------------------
    // Loopback
    // ------------------------------------------------------------
    always_comb begin
        rx_data_in = tx_data_out;
    end

    // ------------------------------------------------------------
    // Tasks de chequeo
    // ------------------------------------------------------------
    task automatic check_bit;
        input actual;
        input expected;
        input [8*80-1:0] msg;
        begin
            if (actual !== expected) begin
                $display("FALLO: %s | actual=%0b expected=%0b | t=%0t",
                         msg, actual, expected, $time);
                tests_failed = tests_failed + 1;
            end
            else begin
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    task automatic check_byte;
        input [7:0] actual;
        input [7:0] expected;
        input [8*80-1:0] msg;
        begin
            if (actual !== expected) begin
                $display("FALLO: %s | actual=0x%02h expected=0x%02h | t=%0t",
                         msg, actual, expected, $time);
                tests_failed = tests_failed + 1;
            end
            else begin
                tests_passed = tests_passed + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Enviar un byte por TX y comprobar que RX reciba lo mismo
    // ------------------------------------------------------------
    task automatic send_and_check;
        input [7:0] data;
        begin
            // Asegurar reposo antes de iniciar
            @(posedge clk);
            check_bit(tx_data_out, 1'b1, "Linea TX en idle antes de transmitir");

            // Pulso de inicio
            tx_data_in <= data;
            tx_start   <= 1'b1;
            @(posedge clk);
            tx_start   <= 1'b0;

            // Esperar a que TX termine
            wait (tx_rdy === 1'b1);
            check_bit(tx_rdy, 1'b1, "Pulso tx_rdy detectado");

            // Esperar a que RX tenga dato listo
            wait (rx_data_rdy === 1'b1);
            check_bit(rx_data_rdy, 1'b1, "Pulso rx_data_rdy detectado");

            // Verificar dato recibido
            check_byte(rx_data_out, data, "Comparacion dato TX->RX");

            // Verificar que los pulsos duren un ciclo
            @(posedge clk);
            check_bit(tx_rdy,      1'b0, "tx_rdy vuelve a 0");
            check_bit(rx_data_rdy, 1'b0, "rx_data_rdy vuelve a 0");

            // Pequeña espera entre transmisiones
            repeat (5) @(posedge clk);
        end
    endtask


    initial begin
        tests_passed = 0;
        tests_failed = 0;

        reset      = 1'b1;
        tx_start   = 1'b0;
        tx_data_in = 8'h00;

        repeat (5) @(posedge clk);
        reset = 1'b0;

        repeat (5) @(posedge clk);

        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'hA5);
        send_and_check(8'h3C);
        send_and_check(8'h81);
        send_and_check(8'h55);
        send_and_check(8'hAA);

        $display("========================================");
        $display("Tests pasados : %0d", tests_passed);
        $display("Tests fallidos: %0d", tests_failed);
        $display("========================================");

        if (tests_failed == 0) begin
            $display("RESULTADO FINAL: UART LOOPBACK TB APROBADO");
        end
        else begin
            $display("RESULTADO FINAL: UART LOOPBACK TB FALLO");
        end

        #50;
        $finish;
    end

endmodule
