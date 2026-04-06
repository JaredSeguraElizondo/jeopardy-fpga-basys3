module rcp_fsm (

    input  logic clk,
    input  logic rst,        // reset global
    input  logic en_rcp,     // habilitación desde main_fsm
    input  logic rst_rcp,    // reset interno desde main_fsm

    // Entradas jugadores
    input  logic btn_j1,
    input  logic btn_j2,

    // Salidas
    output logic j1_done,
    output logic j2_done,
    output logic play_rcp    // ambos listos
);

typedef enum logic [1:0] {
    IDLE,
    WAIT_P1,
    WAIT_P2,
    DONE
} state_t;

state_t state, next_stat

// Registro de estado.

always_ff @(posedge clk) begin
    if (rst || rst_rcp)
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
                next_state = WAIT_P1;
        end

        // Espera a que al menos uno responda
        WAIT_P1: begin
            if (btn_j1 && btn_j2)
                next_state = DONE;
            else if (btn_j1)
                next_state = WAIT_P2;
            else if (btn_j2)
                next_state = WAIT_P2;
        end

        // Ya uno respondió → espera el otro
        WAIT_P2: begin
            if (btn_j1 && btn_j2)
                next_state = DONE;
        end

        DONE: begin
            // Se mantiene hasta reset externo (rst_rcp)
            next_state = DONE;
        end

        default: begin
            next_state = IDLE;
        end

    endcase
end

always_comb begin

    // Defaults
    j1_done = 1'b0;
    j2_done = 1'b0;
    play_rcp = 1'b0;

    case (state)

        IDLE: begin
            // todo en 0
        end

        WAIT_P1: begin
            // nadie confirmado aún
        end

        WAIT_P2: begin
            // uno ya respondió (pero Moore → no distinguimos cuál aquí)
        end

        DONE: begin
            j1_done = 1'b1;
            j2_done = 1'b1;
            play_rcp = 1'b1;
        end

    endcase
end
endmodule