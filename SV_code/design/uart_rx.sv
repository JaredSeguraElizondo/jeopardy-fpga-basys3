module uart_rx #(
    parameter int BAUD_X16_CLK_TICKS = 9   // 16 MHz / (115200 * 16) ≈ 8.68
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       rx_data_in,
    output logic       rx_data_rdy,
    output logic [7:0] rx_data_out
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } rx_state_t;

    rx_state_t rx_state;

    logic baud_rate_x16_clk;
    logic [$clog2(BAUD_X16_CLK_TICKS):0] baud_x16_count;

    logic [7:0] rx_stored_data;
    logic rx_end;
    logic edge_signal;

    logic [3:0] bit_duration_count;   // 0..15
    logic [2:0] bit_count;            // 0..7


    always_ff @(posedge clk) begin
        if (reset) begin
            baud_rate_x16_clk <= 1'b0;
            baud_x16_count    <= BAUD_X16_CLK_TICKS - 1;
        end
        else begin
            if (baud_x16_count == 0) begin
                baud_rate_x16_clk <= 1'b1;
                baud_x16_count    <= BAUD_X16_CLK_TICKS - 1;
            end
            else begin
                baud_rate_x16_clk <= 1'b0;
                baud_x16_count    <= baud_x16_count - 1;
            end
        end
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            rx_state            <= IDLE;
            rx_stored_data      <= 8'h00;
            rx_data_out         <= 8'h00;
            rx_end              <= 1'b0;
            bit_duration_count  <= 4'd0;
            bit_count           <= 3'd0;
        end
        else begin
            if (baud_rate_x16_clk) begin
                case (rx_state)

                    IDLE: begin
                        rx_end             <= 1'b0;
                        rx_stored_data     <= 8'h00;
                        bit_duration_count <= 4'd0;
                        bit_count          <= 3'd0;

                        // Detecta inicio de start bit
                        if (rx_data_in == 1'b0) begin
                            rx_state <= START;
                        end
                    end

                    START: begin
                        rx_end <= 1'b0;

                        // Confirmar que sigue siendo start bit
                        if (rx_data_in == 1'b0) begin
                            // Espera medio bit para muestrear al centro
                            if (bit_duration_count == 4'd7) begin
                                rx_state            <= DATA;
                                bit_duration_count  <= 4'd0;
                            end
                            else begin
                                bit_duration_count <= bit_duration_count + 4'd1;
                            end
                        end
                        else begin
                            // falsa detección
                            rx_state <= IDLE;
                        end
                    end

                    DATA: begin
                        // Espera un bit completo (16 ticks x16)
                        if (bit_duration_count == 4'd15) begin
                            rx_stored_data[bit_count] <= rx_data_in;
                            bit_duration_count        <= 4'd0;

                            if (bit_count == 3'd7) begin
                                rx_state   <= STOP;
                            end
                            else begin
                                bit_count <= bit_count + 3'd1;
                            end
                        end
                        else begin
                            bit_duration_count <= bit_duration_count + 4'd1;
                        end
                    end

                    STOP: begin
                        if (bit_duration_count == 4'd15) begin
                            rx_data_out        <= rx_stored_data;
                            rx_end             <= 1'b1;
                            rx_state           <= IDLE;
                            bit_duration_count <= 4'd0;
                        end
                        else begin
                            bit_duration_count <= bit_duration_count + 4'd1;
                        end
                    end

                    default: begin
                        rx_end   <= 1'b0;
                        rx_state <= IDLE;
                    end
                endcase
            end
        end
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            rx_data_rdy <= 1'b0;
        end
        else begin
            rx_data_rdy <= rx_end && !edge_signal;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            edge_signal <= 1'b0;
        end
        else begin
            edge_signal <= rx_end;
        end
    end

endmodule