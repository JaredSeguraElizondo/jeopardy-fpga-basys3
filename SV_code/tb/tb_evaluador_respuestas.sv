// tb_evaluador_respuestas.sv
// Testbench autoverificable para evaluador_respuestas.
// Verifica los 7 casos de la tabla de decision del documento.

`timescale 1ns/1ps

module tb_evaluador_respuestas;

    // ------------------------------------------------------------
    // Parametros
    // ------------------------------------------------------------
    parameter N = 8;

    // ------------------------------------------------------------
    // Senales
    // ------------------------------------------------------------
    logic        eval_en;
    logic [1:0]  respuesta_fpga;
    logic [1:0]  respuesta_pc;
    logic [1:0]  respuesta_correcta;
    logic [N-1:0] timestamp_j1;
    logic [N-1:0] timestamp_j2;
    logic        R1_valid;
    logic        R2_valid;
    logic [1:0]  resultado_eval;
    logic        win_j1;
    logic        win_j2;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    evaluador_respuestas #(.N(N)) dut (
        .eval_en           (eval_en),
        .respuesta_fpga    (respuesta_fpga),
        .respuesta_pc      (respuesta_pc),
        .respuesta_correcta(respuesta_correcta),
        .timestamp_j1      (timestamp_j1),
        .timestamp_j2      (timestamp_j2),
        .R1_valid          (R1_valid),
        .R2_valid          (R2_valid),
        .resultado_eval    (resultado_eval),
        .win_j1            (win_j1),
        .win_j2            (win_j2)
    );

    // ------------------------------------------------------------
    // Contadores de errores
    // ------------------------------------------------------------
    int errores = 0;

    // ------------------------------------------------------------
    // Tarea de verificacion
    // ------------------------------------------------------------
    task automatic verificar(
        input string         descripcion,
        input logic [1:0]    resultado_esperado,
        input logic          win_j1_esperado,
        input logic          win_j2_esperado
    );
        #5; // Esperar propagacion combinacional
        if (resultado_eval !== resultado_esperado ||
            win_j1         !== win_j1_esperado    ||
            win_j2         !== win_j2_esperado) begin

            $display("FALLO [%s]", descripcion);
            $display("  resultado_eval : esperado=%02b  obtenido=%02b", resultado_esperado, resultado_eval);
            $display("  win_j1         : esperado=%b    obtenido=%b",   win_j1_esperado,    win_j1);
            $display("  win_j2         : esperado=%b    obtenido=%b",   win_j2_esperado,    win_j2);
            errores++;
        end else begin
            $display("OK    [%s]", descripcion);
        end
    endtask

    // ------------------------------------------------------------
    // Estimulos
    // ------------------------------------------------------------
    initial begin
        // Valores base
        respuesta_correcta = 2'b01; // Opcion B es la correcta
        eval_en            = 1'b0;
        respuesta_fpga     = 2'b00;
        respuesta_pc       = 2'b00;
        R1_valid           = 1'b0;
        R2_valid           = 1'b0;
        timestamp_j1       = 8'd0;
        timestamp_j2       = 8'd0;

        // --------------------------------------------------------
        // CASO 0: eval_en = 0, debe ignorar todo
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // J1 correcto
        respuesta_pc   = 2'b01; // J2 correcto
        R1_valid       = 1'b1;
        R2_valid       = 1'b1;
        eval_en        = 1'b0;
        verificar("eval_en=0: salidas en cero", 2'b00, 1'b0, 1'b0);

        eval_en = 1'b1; // Habilitar para el resto de casos

        // --------------------------------------------------------
        // CASO 1: Solo J1 correcto (R1_valid=1, R2_valid=0)
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // correcto
        respuesta_pc   = 2'b00; // incorrectoval_en = 0 — salidas deben ser cero sin importar las entradas
        R1_valid       = 1'b1;
        R2_valid       = 1'b0;
        timestamp_j1   = 8'd10;
        timestamp_j2   = 8'd0;
        verificar("Solo J1 correcto -> J1 gana", 2'b01, 1'b1, 1'b0);

        // --------------------------------------------------------
        // CASO 2: Solo J2 correcto (R1_valid=0, R2_valid=1)
        // --------------------------------------------------------
        respuesta_fpga = 2'b00; // incorrecto
        respuesta_pc   = 2'b01; // correcto
        R1_valid       = 1'b0;
        R2_valid       = 1'b1;
        timestamp_j1   = 8'd0;
        timestamp_j2   = 8'd10;
        verificar("Solo J2 correcto -> J2 gana", 2'b10, 1'b0, 1'b1);

        // --------------------------------------------------------
        // CASO 3: Ambos correctos, J1 mas rapido
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // correcto
        respuesta_pc   = 2'b01; // correcto
        R1_valid       = 1'b1;
        R2_valid       = 1'b1;
        timestamp_j1   = 8'd10;
        timestamp_j2   = 8'd20;
        verificar("Ambos correctos, J1 mas rapido -> J1 gana", 2'b01, 1'b1, 1'b0);

        // --------------------------------------------------------
        // CASO 4: Ambos correctos, J2 mas rapido
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // correcto
        respuesta_pc   = 2'b01; // correcto
        R1_valid       = 1'b1;
        R2_valid       = 1'b1;
        timestamp_j1   = 8'd20;
        timestamp_j2   = 8'd10;
        verificar("Ambos correctos, J2 mas rapido -> J2 gana", 2'b10, 1'b0, 1'b1);

        // --------------------------------------------------------
        // CASO 5: Ambos correctos, timestamps identicos -> prioridad J1
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // correcto
        respuesta_pc   = 2'b01; // correcto
        R1_valid       = 1'b1;
        R2_valid       = 1'b1;
        timestamp_j1   = 8'd15;
        timestamp_j2   = 8'd15;
        verificar("Ambos correctos, empate -> J1 gana (prioridad fija)", 2'b01, 1'b1, 1'b0);

        // --------------------------------------------------------
        // CASO 6: Ninguno correcto
        // --------------------------------------------------------
        respuesta_fpga = 2'b00; // incorrecto
        respuesta_pc   = 2'b10; // incorrecto
        R1_valid       = 1'b1;
        R2_valid       = 1'b1;
        timestamp_j1   = 8'd5;
        timestamp_j2   = 8'd5;
        verificar("Ninguno correcto -> nadie gana", 2'b00, 1'b0, 1'b0);

        // --------------------------------------------------------
        // CASO 7: R_valid en cero aunque la respuesta sea correcta
        // --------------------------------------------------------
        respuesta_fpga = 2'b01; // correcto pero R1_valid=0
        respuesta_pc   = 2'b01; // correcto pero R2_valid=0
        R1_valid       = 1'b0;
        R2_valid       = 1'b0;
        verificar("Ambos con respuesta correcta pero sin R_valid -> nadie gana", 2'b00, 1'b0, 1'b0);

        // --------------------------------------------------------
        // Resultado final
        // --------------------------------------------------------
        $display("--------------------------------------------");
        if (errores == 0)
            $display("TODOS LOS CASOS PASARON (0 errores)");
        else
            $display("FALLARON %0d CASO(S)", errores);
        $display("--------------------------------------------");

        $finish;
    end
    initial begin
    $dumpfile("tb_evaluador_respuestas.vcd");
    $dumpvars(0, tb_evaluador_respuestas);
end

endmodule