module uart #(
    parameter TX_BAUD_CLK_TICKS     = 139,
    parameter RX_BAUD_X16_CLK_TICKS = 9
)(
    input  logic       clk,
    input  logic       reset,

    // TX
    input  logic       tx_start,
    input  logic [7:0] tx_data_in,
    output logic       tx_data_out,
    output logic       tx_rdy,

    // RX
    input  logic       rx_data_in,
    output logic [7:0] rx_data_out,
    output logic       rx_data_rdy
);

    uart_tx #(
        .BAUD_CLK_TICKS(TX_BAUD_CLK_TICKS)
    ) u_uart_tx (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_data_out(tx_data_out),
        .tx_rdy(tx_rdy)
    );

    uart_rx #(
        .BAUD_X16_CLK_TICKS(RX_BAUD_X16_CLK_TICKS)
    ) u_uart_rx (
        .clk(clk),
        .reset(reset),
        .rx_data_in(rx_data_in),
        .rx_data_rdy(rx_data_rdy),
        .rx_data_out(rx_data_out)
    );

endmodule
