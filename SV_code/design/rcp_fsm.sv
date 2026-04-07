module rcp_fsm (

    input  logic clk,
    input  logic rst,        // reset global
    input  logic en_rcp,     // habilitación desde main_fsm
    input  logic rst_rcp,    // reset interno desde main_fsm

    // Entradas jugadores
    input  logic fpga_ok,
    input  logic pc_ok,

    // Entradas registro de tiempo
    input logic R1_valid,
    input logic R2_valid,

    // Salidas de registro de tiempo
    output logic save_time_j1,
    output logic save_time_j2,
    output logic time_rst,

    //Salidas hacia el bloque evaluador de respuestas 
    output logic check_j1,
    output logic check_j2,
    output logic eval_en,

    //Salidas hacia fsm principal
    output logic play_rcp    // ambos listos
);

typedef enum logic [2:0] {
    IDLE = 3'b000,
    MONITOR = 3'b001,
    REG_J1 = 3'b010,
    REG_J2 = 3'b011,
    DONE = 3'b100
} state_t;

state_t state, next_state

// Registro de estado.

always_ff @(posedge clk) begin
    if (rst_rcp)
        state <= IDLE;
    else
        state <= next_state;
end

// Lógica de siguiente estado

always_comb begin

    next_state = state;

    case (state)

        IDLE: begin
            if (en_rcp)
                next_state = MONITOR;
        end

        MONITOR: begin
        if(fpga_ok && ˜R1_valid) next_state = REG_J1;
        else if(pc_ok && ˜R2_valid) next_state = REG_J2;
        else if(R1_valid && R2_valid) next_state = DONE;
        end

        REG_J1: begin
        next_state = MONITOR;
        end

        REG_J2: begin
        next_state = MONITOR;
        end

        DONE: begin
        next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end

// Lógica de salida

always_comb begin

    // Defaults
    save_time_j1 = 1'b0;
    save_time_j2 = 1'b0;
    time_rst = 1'b0;
    check_j1 = 1'b0;
    check_j2 = 1'b0;
    eval_en = 1'b0;
    play_rcp = 1'b0;

    case (state)

        IDLE: begin
            time_rst = 1'b1;
        end

        MONITOR: begin
        save_time_j1 = 1'b0;
        save_time_j2 = 1'b0;
        time_rst = 1'b0;
        check_j1 = 1'b0;
        check_j2 = 1'b0;
        eval_en = 1'b0;
        play_rcp = 1'b0;
        end

        REG_J1: begin
        save_time_j1 = 1'b1;
        check_j1 = 1'b1;
        end
        
        REG_J2: begin
        save_time_j2 = 1'b1;
        check_j2 = 1'b1;
        end

        DONE: begin
        eval_en = 1'b1;
        play_rcp = 1'b1;
        end
    default:
    save_time_j1 = 1'b0;
    save_time_j2 = 1'b0;
    time_rst = 1'b0;
    check_j1 = 1'b0;
    check_j2 = 1'b0;
    eval_en = 1'b0;
    play_rcp = 1'b0;
    endcase
end
endmodule