`timescale 1ns / 1ps

module duration_timer #(
    parameter int DURATION_MAX = 3_200_000    // 200 ms a 16 MHz
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic start_i,
    output logic done_o
);

    
    localparam int SIM_DURATION = 16_000;  // Para simulación
    
    logic [$clog2(DURATION_MAX)-1:0] counter;
    logic counting;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            counter  <= '0;
            counting <= 1'b0;
            done_o   <= 1'b0;
        end else begin
            done_o <= 1'b0;
            
            if (start_i) begin
                counter  <= '0;
                counting <= 1'b1;
                done_o   <= 1'b0;
            end else if (counting) begin
                if (counter == SIM_DURATION - 1) begin
                    counter  <= '0;
                    counting <= 1'b0;
                    done_o   <= 1'b1;
                end else begin
                    counter <= counter + 1'b1;
                end
            end
        end
    end

endmodule