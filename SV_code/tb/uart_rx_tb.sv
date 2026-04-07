`timescale 1ns/1ps

module uart_rx_tb;

    localparam int CLK_PERIOD_NS       = 10;
    localparam int BAUD_X16_CLK_TICKS  = 4;

    logic clk;
    logic reset;
    logic rx_data_in;
    logic rx_data_rdy;
    logic [7:0] rx_data_out;

    int tests_passed;
    int tests_failed;

    uart_rx #(
        .BAUD_X16_CLK_TICKS(BAUD_X16_CLK_TICKS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .rx_data_in(rx_data_in),
        .rx_data_rdy(rx_data_rdy),
        .rx_data_out(rx_data_out)
    );


    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end


    task automatic check_equal_bit(
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

    task automatic check_equal_byte(
        input logic [7:0] actual,
        input logic [7:0] expected,
        input string msg
    );
        begin
            if (actual !== expected) begin
                $error("FALLO: %s | actual=0x%02h expected=0x%02h | t=%0t",
                       msg, actual, expected, $time);
                tests_failed++;
            end
            else begin
                tests_passed++;
            end
        end
    endtask


    task automatic wait_x16_ticks(input int n);
        int k;
        begin
            for (k = 0; k < n; k++) begin
                @(posedge dut.baud_rate_x16_clk);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Envía un bit UART en la línea RX durante 16 ticks x16
    // ------------------------------------------------------------
    task automatic send_uart_bit(input logic bit_value);
        begin
            rx_data_in <= bit_value;
            wait_x16_ticks(16);
        end
    endtask


    task automatic send_uart_byte(input logic [7:0] data);
        int i;
        begin
            // reposo previo
            rx_data_in <= 1'b1;
            wait_x16_ticks(4);

            // start
            send_uart_bit(1'b0);

            // datos LSB first
            for (i = 0; i < 8; i++) begin
                send_uart_bit(data[i]);
            end

            // stop
            send_uart_bit(1'b1);

            // dejar reposo
            rx_data_in <= 1'b1;
            wait_x16_ticks(4);
        end
    endtask


    task automatic send_and_check(input logic [7:0] data);
        begin
            send_uart_byte(data);

            wait (rx_data_rdy === 1'b1);

            check_equal_bit(
                rx_data_rdy, 1'b1,
                $sformatf("Pulso rx_data_rdy para 0x%02h", data)
            );

            check_equal_byte(
                rx_data_out, data,
                $sformatf("Dato recibido para 0x%02h", data)
            );

            @(posedge clk);
            check_equal_bit(
                rx_data_rdy, 1'b0,
                $sformatf("rx_data_rdy de un ciclo para 0x%02h", data)
            );
        end
    endtask


    initial begin
        tests_passed = 0;
        tests_failed = 0;

        reset      = 1'b1;
        rx_data_in = 1'b1;   // línea UART en reposo

        repeat (4) @(posedge clk);
        reset = 1'b0;

        repeat (2) @(posedge clk);

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
            $display("RESULTADO FINAL: UART RX TB APROBADO");
        end
        else begin
            $fatal(1, "RESULTADO FINAL: UART RX TB FALLÓ");
        end

        #50;
        $finish;
    end

endmodule
