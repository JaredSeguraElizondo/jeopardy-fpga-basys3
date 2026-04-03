// ============================================================
// question_picker.sv
// Mini FSM que selecciona una pregunta valida no repetida.
//
// Estados:
//   IDLE      - Espera solicitar_i de la Main FSM
//   SEARCHING - Avanza el LFSR y verifica condiciones
//   FOUND     - Pregunta valida encontrada, espera confirmacion
// ============================================================

module question_picker (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       solicitar_i,      // Pulso de la Main FSM pidiendo pregunta
    input  logic       confirmar_i,      // Pulso de la Main FSM confirmando recepcion
    input  logic       pregunta_usada_i, // Del registro de preguntas usadas
    input  logic [3:0] seed_i,           // Semilla desde switches de la Basys3
    input  logic       load_seed_i,      // Pulso para cargar semilla al inicio
    output logic [3:0] pregunta_sel_o,   // Numero de pregunta valida (0-9)
    output logic       q_valid_o,        // 1 cuando pregunta_sel_o es valida
    output logic [3:0] lfsr_val_o        // Valor actual del LFSR (para registro usadas)
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

    // Exponer valor del LFSR para que el registro de usadas
    // pueda consultarlo durante SEARCHING
    assign lfsr_val_o = lfsr_val;

    // Candidato valido: rango 1-10 y no usada
    logic candidato_valido;
    assign candidato_valido = (lfsr_val >= 4'd1)  &&
                              (lfsr_val <= 4'd10) &&
                              (pregunta_usada_i == 1'b0);

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