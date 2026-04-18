`timescale 1ns / 1ps



module uart_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    input  logic        RsRx,
    output logic        RsTx
);

    logic       uart_tx_start, uart_tx_rdy;
    logic       uart_rx_data_rdy;
    logic [7:0] uart_data_in, uart_data_out;

    logic       reg_ctrl_send, reg_ctrl_new_rx;
    logic [7:0] reg_data_tx, reg_data_rx;

    UART uart_core_inst (
        .clk         (clk_i),
        .reset       (rst_i),
        .tx_start    (uart_tx_start),
        .tx_rdy      (uart_tx_rdy),
        .rx_data_rdy (uart_rx_data_rdy),
        .data_in     (uart_data_in),
        .data_out    (uart_data_out),
        .rx          (RsRx),
        .tx          (RsTx)
    );

    assign uart_data_in  = reg_data_tx;
    assign uart_tx_start = reg_ctrl_send;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            reg_ctrl_send   <= 0;
            reg_ctrl_new_rx <= 0;
            reg_data_tx     <= 0;
            reg_data_rx     <= 0;
        end else begin
            // Recepcion hardware 
            if (uart_rx_data_rdy) begin
                reg_ctrl_new_rx <= 1'b1;
                reg_data_rx     <= uart_data_out;
            end

            // Auto-clear send cuando TX termina
            if (reg_ctrl_send && uart_tx_rdy)
                reg_ctrl_send <= 1'b0;

            // Escrituras desde la FSM
            if (write_enable_i) begin
                case (addr_i)
                    2'b00: begin
                        if (wdata_i[0]) reg_ctrl_send   <= 1'b1;
                        reg_ctrl_new_rx <= wdata_i[1];
                    end
                    2'b10: reg_data_tx <= wdata_i[7:0];
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        rdata_o = 32'h0;
        case (addr_i)
            2'b00: rdata_o = {30'd0, reg_ctrl_new_rx, reg_ctrl_send};
            2'b10: rdata_o = {24'd0, reg_data_tx};
            2'b11: rdata_o = {24'd0, reg_data_rx};
            default: rdata_o = 32'h0;
        endcase
    end

endmodule