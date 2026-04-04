`timescale 1ns / 1ps

module sound_top (
    input  logic clk_i,
    input  logic rst_i,
    input  logic respuesta_correcta_i,
    input  logic respuesta_incorrecta_i,
    input  logic enable_i,
    output logic buzzer_out_o,
    output logic busy_o
);

    // Parámetros para 16 MHz
    localparam TONE_1KHZ_MAX = 8_000;   // 1 kHz (correcto)
    localparam TONE_500HZ_MAX = 16_000; // 500 Hz (incorrecto)
    localparam DURATION_MAX = 3_200_000; // 200 ms
    
    // Detector de flanco
    reg correcta_prev, incorrecta_prev;
    wire correcta_pulse, incorrecta_pulse;
    
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            correcta_prev <= 0;
            incorrecta_prev <= 0;
        end else begin
            correcta_prev <= respuesta_correcta_i;
            incorrecta_prev <= respuesta_incorrecta_i;
        end
    end
    
    assign correcta_pulse = respuesta_correcta_i & ~correcta_prev;
    assign incorrecta_pulse = respuesta_incorrecta_i & ~incorrecta_prev;
    
    // FSM
    logic playing;
    logic [21:0] duration_cnt;
    logic [13:0] tone_cnt;
    logic tone;
    logic tone_select; // 0=correcto, 1=incorrecto
    logic tone_max;
    
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            playing <= 0;
            duration_cnt <= 0;
            tone_cnt <= 0;
            tone <= 0;
            tone_select <= 0;
        end else if (correcta_pulse) begin
            playing <= 1;
            duration_cnt <= 0;
            tone_cnt <= 0;
            tone <= 0;
            tone_select <= 0;
        end else if (incorrecta_pulse) begin
            playing <= 1;
            duration_cnt <= 0;
            tone_cnt <= 0;
            tone <= 0;
            tone_select <= 1;
        end else if (playing) begin
            // Contador de duración
            if (duration_cnt >= DURATION_MAX - 1) begin
                playing <= 0;
                duration_cnt <= 0;
                tone <= 0;
            end else begin
                duration_cnt <= duration_cnt + 1;
                
                // Generador de tono
                if (tone_select == 0) begin
                    // Tono correcto (1 kHz)
                    if (tone_cnt >= TONE_1KHZ_MAX - 1) begin
                        tone_cnt <= 0;
                        tone <= ~tone;
                    end else begin
                        tone_cnt <= tone_cnt + 1;
                    end
                end else begin
                    // Tono incorrecto (500 Hz)
                    if (tone_cnt >= TONE_500HZ_MAX - 1) begin
                        tone_cnt <= 0;
                        tone <= ~tone;
                    end else begin
                        tone_cnt <= tone_cnt + 1;
                    end
                end
            end
        end else begin
            duration_cnt <= 0;
            tone_cnt <= 0;
            tone <= 0;
        end
    end
    
    assign buzzer_out_o = tone & playing & enable_i;
    assign busy_o = playing & enable_i;

endmodule