`timescale 1ns / 1ps

module ui_hw_controller (
    input  logic        clk_i,
    input  logic        rst_i,

    // Interfaz Lógica (Hacia el Game Core)
    input  logic [15:0] hex_data_i,
    input  logic        buzz_en_i,
    input  logic [15:0] buzz_period_i,
    output logic [2:0]  btn_pulse_o,

    // Interfaz Física (Pines de la Basys 3)
    input  logic [2:0]  btn_async_i,
    output logic [6:0]  seg_o,
    output logic [3:0]  an_o,
    output logic        buzzer_o
);

    // 1. Instancia del Debouncer (Configurado para 3 bits)
    button_debouncer #(
        .WIDTH(3)
    ) debouncer_inst (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .btn_async_i (btn_async_i),
        .btn_pulse_o (btn_pulse_o)
    );

    // 2. Instancia del Display 7-Seg
    display_7seg disp_inst (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .hex_data_i (hex_data_i),
        .seg_o      (seg_o),
        .an_o       (an_o)
    );

    // 3. Instancia del Buzzer PWM
    pwm_buzzer buzzer_inst (
        .clk_i    (clk_i),
        .rst_i    (rst_i),
        .en_i     (buzz_en_i),
        .period_i (buzz_period_i),
        .pwm_o    (buzzer_o)
    );

endmodule