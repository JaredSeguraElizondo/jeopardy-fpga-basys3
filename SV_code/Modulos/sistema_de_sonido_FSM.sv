`timescale 1ns / 1ps

module sound_manager (
    input  logic clk_i,
    input  logic rst_i,
    input  logic play_i,        // Viene del game_core: 1 = Reproducir sonido
    input  logic correct_i,     // Viene del game_core: 1 = Acierto, 0 = Fallo
    output logic speaker_pwm_o  // Va directo al pin de la placa (J1)
);

    
    localparam [15:0] TONE_CORRECT = 16'd8000;  // Sonido Agudo (~1000 Hz)
    localparam [15:0] TONE_WRONG   = 16'd53000; // Sonido Grave (~150 Hz)

    logic [15:0] current_period;

    // Multiplexor de tonos
    always_comb begin
        if (correct_i) current_period = TONE_CORRECT;
        else           current_period = TONE_WRONG;
    end

    pwm_buzzer buzzer_inst (
        .clk_i    (clk_i),
        .rst_i    (rst_i),
        .en_i     (play_i),
        .period_i (current_period),
        .pwm_o    (speaker_pwm_o)
    );

endmodule