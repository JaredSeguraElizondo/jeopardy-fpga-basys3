`timescale 1ns / 1ps

module question_picker (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       solicitar_i,
    input  logic       confirmar_i,
    input  logic       pregunta_usada_i,  // refleja used_reg[candidato_actual]
    input  logic [3:0] seed_i,
    input  logic       load_seed_i,
    output logic [3:0] pregunta_sel_o,    // pregunta confirmada (0-9)
    output logic       q_valid_o,
    output logic [3:0] lfsr_val_o         // candidato actual del LFSR (para consulta)
);

    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        SEARCHING = 2'b01,
        FOUND     = 2'b10
    } state_t;

    state_t state;
    logic [3:0] lfsr_val;
    logic       lfsr_en;

    lfsr4 u_lfsr (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .en_i   (lfsr_en),
        .seed_i (seed_i),
        .load_i (load_seed_i),
        .q_o    (lfsr_val)
    );

    // Exponer el valor actual del LFSR como candidato
    // question_memory usara esto para consultar si ya fue usada
    assign lfsr_val_o = lfsr_val;

    // Candidato en rango valido (1-10)
    logic en_rango;
    assign en_rango = (lfsr_val >= 4'd1) && (lfsr_val <= 4'd10);

    // candidato_valido: en rango Y pregunta_usada_i=0
    // pregunta_usada_i viene de question_memory indexado con lfsr_val-1
    logic candidato_valido;
    assign candidato_valido = en_rango && (pregunta_usada_i == 1'b0);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state          <= IDLE;
            pregunta_sel_o <= 4'd0;
            q_valid_o      <= 1'b0;
            lfsr_en        <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    q_valid_o <= 1'b0;
                    lfsr_en   <= 1'b0;
                    if (solicitar_i) begin
                        lfsr_en <= 1'b1;
                        state   <= SEARCHING;
                    end
                end

                SEARCHING: begin
                    if (candidato_valido) begin
                        lfsr_en        <= 1'b0;
                        pregunta_sel_o <= lfsr_val - 4'd1;
                        q_valid_o      <= 1'b1;
                        state          <= FOUND;
                    end else begin
                        lfsr_en <= 1'b1;
                    end
                end

                FOUND: begin
                    if (confirmar_i) begin
                        q_valid_o <= 1'b0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule