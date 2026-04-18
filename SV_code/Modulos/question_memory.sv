`timescale 1ns / 1ps


module question_memory (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic [3:0] pregunta_sel_i,    // pregunta activa para lectura ROM
    input  logic [3:0] consulta_sel_i,    // candidato del picker para verificar si fue usada
    input  logic       next_char_i,
    input  logic       marcar_usada,
    output logic [7:0] char_o,
    output logic [1:0] tipo_o,
    output logic       fin_bloque_o,
    output logic       pregunta_usada_o   // refleja used_reg[consulta_sel_i]
);

    localparam BYTES_PER_Q = 7'd65;
    localparam MAX_OFFSET  = 7'd64;

    // Contador de caracteres
    logic [6:0] contador;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            contador <= 7'd0;
        else if (next_char_i) begin
            if (contador == MAX_OFFSET)
                contador <= 7'd0;
            else
                contador <= contador + 7'd1;
        end
    end

    assign fin_bloque_o = (contador == MAX_OFFSET);

    // Direccion base — usa pregunta_sel_i (la pregunta confirmada)
    logic [9:0] addr_final;
    assign addr_final = (pregunta_sel_i * BYTES_PER_Q) + {3'b000, contador};

    // ROM IP
    blk_mem_gen_0 u_rom (
        .clka  (clk_i),
        .ena   (1'b1),
        .addra (addr_final),
        .douta (char_o)
    );

    // Decodificador de indice
    assign tipo_o = (contador <= 7'd31) ? 2'b00 :
                    (contador <= 7'd63) ? 2'b01 :
                                         2'b10;

    // Registro de preguntas usadas
    logic [9:0] used_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i)
            used_reg <= 10'b0;
        else if (marcar_usada && pregunta_sel_i <= 4'd9)
            used_reg[pregunta_sel_i] <= 1'b1;
    end

    // pregunta_usada_o usa consulta_sel_i (el candidato del picker)
    // Asi el picker puede verificar cualquier candidato sin cambiar pregunta_sel_i
    assign pregunta_usada_o = (consulta_sel_i <= 4'd9) ? used_reg[consulta_sel_i] : 1'b1;

endmodule