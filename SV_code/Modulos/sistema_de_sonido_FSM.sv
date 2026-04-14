`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2026 05:48:22 PM
// Design Name: 
// Module Name: sistema de sonido FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module sound_manager (
    input  logic clk_i,
    input  logic rst_i,
    input  logic play_i,        // Viene del game_core: 1 = Reproducir sonido
    input  logic correct_i,     // Viene del game_core: 1 = Acierto, 0 = Fallo
    output logic speaker_pwm_o  // Va directo al pin de la placa (J1)
);

    // =========================================================
    // BANCO DE FRECUENCIAS (A 16 MHz)
    // =========================================================
    localparam [15:0] TONE_CORRECT = 16'd8000;  // Sonido Agudo (~1000 Hz)
    localparam [15:0] TONE_WRONG   = 16'd53000; // Sonido Grave (~150 Hz)

    logic [15:0] current_period;

    // Multiplexor de tonos
    always_comb begin
        if (correct_i) current_period = TONE_CORRECT;
        else           current_period = TONE_WRONG;
    end

    // =========================================================
    // INSTANCIA DEL GENERADOR PWM (Tu código original)
    // =========================================================
    pwm_buzzer buzzer_inst (
        .clk_i    (clk_i),
        .rst_i    (rst_i),
        .en_i     (play_i),
        .period_i (current_period),
        .pwm_o    (speaker_pwm_o)
    );

endmodule