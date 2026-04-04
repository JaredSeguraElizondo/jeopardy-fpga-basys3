`timescale 1ns / 1ps
// Función  : Máquina de estados que controla la reproducción del sonido.
//            Estados:
//              IDLE  → Esperando solicitud de sonido
//              SETUP → Selecciona la frecuencia según tipo (1 ciclo)
//              PLAY  → Activa el generador de tono y el timer de duración
//              DONE  → Limpia estado y vuelve a IDLE


module sound_fsm (
    input  logic clk_i,
    input  logic rst_i,
    
    // Entradas de control
    input  logic sound_req_i,      // Pulso de solicitud
    input  logic tone_type_i,      // 0=correcto, 1=incorrecto
    input  logic timer_done_i,     // Timer completado
    
    // Salidas
    output logic busy_o,           // Módulo ocupado
    output logic tone_enable_o,    // Habilita generador de tono
    output logic tone_select_o     // Selecciona frecuencia (al generador)
);

    // Codificación de estados (3 bits)
    typedef enum logic [1:0] {
        ST_IDLE  = 2'b00,
        ST_SETUP = 2'b01,
        ST_PLAY  = 2'b10,
        ST_DONE  = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // Latch del tipo de tono 
    logic tone_type_latch;
    
    // Lógica de próximo estado 
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            ST_IDLE: begin
                if (sound_req_i)
                    next_state = ST_SETUP;
            end
            
            ST_SETUP: begin
                next_state = ST_PLAY;
            end
            
            ST_PLAY: begin
                if (timer_done_i)
                    next_state = ST_DONE;
            end
            
            ST_DONE: begin
                next_state = ST_IDLE;
            end
            
            default: next_state = ST_IDLE;
        endcase
    end

    // Registro de estado 
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            current_state   <= ST_IDLE;
            tone_type_latch <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Latchear el tipo de tono en estado SETUP
            if (current_state == ST_IDLE && sound_req_i) begin
                tone_type_latch <= tone_type_i;
            end
        end
    end
   
    // Lógica de salidas
    always_comb begin
        // Valores por defecto
        busy_o         = 1'b0;
        tone_enable_o  = 1'b0;
        tone_select_o  = tone_type_latch;
        
        case (current_state)
            ST_IDLE: begin
                busy_o = 1'b0;
                tone_enable_o = 1'b0;
            end
            
            ST_SETUP: begin
                busy_o = 1'b1;
                tone_enable_o = 1'b0;   // Todavía no, en el próximo ciclo
            end
            
            ST_PLAY: begin
                busy_o = 1'b1;
                tone_enable_o = 1'b1;   // Activar tono
            end
            
            ST_DONE: begin
                busy_o = 1'b1;
                tone_enable_o = 1'b0;   // Apagar tono
            end
        endcase
    end

endmodule