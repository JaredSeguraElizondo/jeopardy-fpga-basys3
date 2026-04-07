module uart_tx #(
    parameter int BAUD_CLK_TICKS = 139   // 16 MHz / 115200 ≈ 138.89 139
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_start,
    input  logic [7:0] tx_data_in,
    output logic       tx_data_out,
    output logic       tx_rdy
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } tx_state_t;

    tx_state_t state;

    logic baud_rate_clk;
    logic [$clog2(BAUD_CLK_TICKS):0] baud_count;

    logic [2:0] data_index;
    logic [7:0] stored_data;

    logic start_detected;
    logic start_reset;

    logic tx_end;
    logic edge_signal;

    logic data_index_reset;

    // ------------------------------------------------------------
    // Generador de tick a baud rate
    // Produce un pulso de 1 ciclo cada BAUD_CLK_TICKS ciclos de clk
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            baud_rate_clk <= 1'b0;
            baud_count    <= BAUD_CLK_TICKS - 1;
        end
        else begin
            if (baud_count == 0) begin
                baud_rate_clk <= 1'b1;
                baud_count    <= BAUD_CLK_TICKS - 1;
            end
            else begin
                baud_rate_clk <= 1'b0;
                baud_count    <= baud_count - 1;
            end
        end
    end

    // ------------------------------------------------------------
    // Detector de tx_start
    // Guarda el dato cuando llega el pulso de inicio
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset || start_reset) begin
            start_detected <= 1'b0;
        end
        else begin
            if (tx_start && !start_detected) begin
                start_detected <= 1'b1;
                stored_data    <= tx_data_in;
            end
        end
    end

    // ------------------------------------------------------------
    // Contador de índice de bits
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset || data_index_reset) begin
            data_index <= 3'd0;
        end
        else if (baud_rate_clk) begin
            data_index <= data_index + 3'd1;
        end
    end

    // ------------------------------------------------------------
    // FSM del transmisor UART
    // Formato: 1 start, 8 data, 1 stop
    // LSB primero
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            state            <= IDLE;
            data_index_reset <= 1'b1;
            start_reset      <= 1'b1;
            tx_data_out      <= 1'b1;   // línea UART en reposo = 1
            tx_end           <= 1'b0;
        end
        else begin
            if (baud_rate_clk) begin
                case (state)

                    IDLE: begin
                        tx_end           <= 1'b0;
                        data_index_reset <= 1'b1;
                        start_reset      <= 1'b0;
                        tx_data_out      <= 1'b1;

                        if (start_detected) begin
                            state <= START;
                        end
                    end

                    START: begin
                        tx_end           <= 1'b0;
                        data_index_reset <= 1'b0;
                        tx_data_out      <= 1'b0;   // bit de inicio
                        state            <= DATA;
                    end

                    DATA: begin
                        tx_data_out <= stored_data[data_index];

                        if (data_index == 3'd7) begin
                            data_index_reset <= 1'b1;
                            state            <= STOP;
                        end
                    end

                    STOP: begin
                        tx_data_out <= 1'b1;  // bit de parada
                        start_reset <= 1'b1;
                        tx_end      <= 1'b1;
                        state       <= IDLE;
                    end

                    default: begin
                        tx_data_out <= 1'b1;
                        tx_end      <= 1'b0;
                        state       <= IDLE;
                    end
                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // Pulso de "listo" al terminar transmisión
    // Igual a la idea del VHDL del profe
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            tx_rdy      <= 1'b0;
            edge_signal <= 1'b0;
        end
        else begin
            tx_rdy      <= tx_end && !edge_signal;
            edge_signal <= tx_end;
        end
    end

endmodule