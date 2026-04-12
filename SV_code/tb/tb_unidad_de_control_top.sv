// tb_unidad_de_control_top.sv
// Testbench autoverificable para unidad_de_control_top.
// Usa parametros reducidos para simulacion: FREQ=4, TIME=4 (timeout en 16 ciclos).
// Simula una partida completa de 7 rondas con distintos resultados.

`timescale 1ns/1ps

module tb_unidad_de_control_top;

    // -------------------------------------------------------------------------
    // Parametros de simulacion
    // -------------------------------------------------------------------------
    parameter N     = 2;
    parameter W     = 3;
    parameter FREQ  = 4;
    parameter TIME  = 4;
    parameter COUNT = $clog2(FREQ * TIME); // 4 bits, timeout en 16 ciclos

    // -------------------------------------------------------------------------
    // Senales
    // -------------------------------------------------------------------------
    logic             clk, rst;
    logic             fpga_ok, pc_ok;
    logic [N-1:0]     respuesta_correcta;
    logic [N-1:0]     respuesta_fpga;
    logic [N-1:0]     respuesta_pc;

    logic             solicitar_pregunta;
    logic             mostrar_pregunta_i;
    logic             mostrar_opciones_i;
    logic [2:0]       estado_juego;
    logic [W-1:0]     score_j1;
    logic [W-1:0]     score_j2;
    logic [1:0]       resultado_ronda;
    logic [W-1:0]     ronda;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    unidad_de_control_top #(
        .N    (N),
        .W    (W),
        .FREQ (FREQ),
        .TIME (TIME)
    ) dut (
        .clk                (clk),
        .rst                (rst),
        .fpga_ok            (fpga_ok),
        .pc_ok              (pc_ok),
        .respuesta_correcta (respuesta_correcta),
        .respuesta_fpga     (respuesta_fpga),
        .respuesta_pc       (respuesta_pc),
        .solicitar_pregunta (solicitar_pregunta),
        .mostrar_pregunta_i (mostrar_pregunta_i),
        .mostrar_opciones_i (mostrar_opciones_i),
        .estado_juego       (estado_juego),
        .score_j1           (score_j1),
        .score_j2           (score_j2),
        .resultado_ronda    (resultado_ronda),
        .ronda              (ronda)
    );

    // -------------------------------------------------------------------------
    // Reloj: periodo 10 ns
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Contador de errores
    // -------------------------------------------------------------------------
    int errores = 0;

    // -------------------------------------------------------------------------
    // Tarea: reset del sistema
    // -------------------------------------------------------------------------
    task automatic reset_sistema();
        rst                = 1'b1;
        fpga_ok            = 1'b0;
        pc_ok              = 1'b0;
        respuesta_correcta = 2'b01;
        respuesta_fpga     = 2'b00;
        respuesta_pc       = 2'b00;
        @(posedge clk); #1;
        rst = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: avanzar un ciclo con entradas dadas
    // -------------------------------------------------------------------------
    task automatic ciclo(
        input logic i_fpga_ok,
        input logic i_pc_ok,
        input logic [N-1:0] i_resp_fpga,
        input logic [N-1:0] i_resp_pc
    );
        fpga_ok        = i_fpga_ok;
        pc_ok          = i_pc_ok;
        respuesta_fpga = i_resp_fpga;
        respuesta_pc   = i_resp_pc;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificar salidas del top
    // -------------------------------------------------------------------------
    task automatic verificar(
        input string      descripcion,
        input logic [2:0] exp_estado_juego,
        input logic       exp_sol_preg,
        input logic       exp_mostrar_preg,
        input logic       exp_mostrar_opc
    );
        if (estado_juego       !== exp_estado_juego ||
            solicitar_pregunta !== exp_sol_preg      ||
            mostrar_pregunta_i !== exp_mostrar_preg  ||
            mostrar_opciones_i !== exp_mostrar_opc) begin
            $display("FALLO [%s]", descripcion);
            $display("  estado_juego       : esp=%03b obt=%03b", exp_estado_juego, estado_juego);
            $display("  solicitar_pregunta : esp=%b   obt=%b",   exp_sol_preg,     solicitar_pregunta);
            $display("  mostrar_pregunta_i : esp=%b   obt=%b",   exp_mostrar_preg, mostrar_pregunta_i);
            $display("  mostrar_opciones_i : esp=%b   obt=%b",   exp_mostrar_opc,  mostrar_opciones_i);
            errores++;
        end else
            $display("OK    [%s]", descripcion);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: esperar a que el top llegue a WAIT_R desde ROUND_Q
    // IDLE(reset) → ROUND_Q → SEL_Q → SHOW → WAIT_R
    // -------------------------------------------------------------------------
    task automatic avanzar_a_wait_r();
        // IDLE → ROUND_Q
        ciclo(1'b0, 1'b0, 2'b00, 2'b00);
        verificar("ROUND_Q", 3'b001, 1'b0, 1'b0, 1'b0);
        // ROUND_Q → SEL_Q
        ciclo(1'b0, 1'b0, 2'b00, 2'b00);
        verificar("SEL_Q", 3'b010, 1'b1, 1'b0, 1'b0);
        // SEL_Q → SHOW
        ciclo(1'b0, 1'b0, 2'b00, 2'b00);
        verificar("SHOW", 3'b011, 1'b0, 1'b1, 1'b1);
        // SHOW → WAIT_R
        ciclo(1'b0, 1'b0, 2'b00, 2'b00);
        verificar("WAIT_R", 3'b100, 1'b0, 1'b1, 1'b1);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: simular una ronda completa con respuestas de los jugadores
    // Espera que el top ya este en WAIT_R
    // -------------------------------------------------------------------------
    task automatic ronda_con_respuestas(
        input string      descripcion,
        input logic       j1_responde,       // J1 confirma su respuesta
        input logic       j2_responde,       // J2 confirma su respuesta
        input logic [N-1:0] resp_fpga_val,   // Respuesta de J1
        input logic [N-1:0] resp_pc_val,     // Respuesta de J2
        input logic [N-1:0] resp_correcta,   // Respuesta correcta
        input logic [1:0] resultado_esperado,
        input logic [W-1:0] score_j1_esp,
        input logic [W-1:0] score_j2_esp,
        input logic [W-1:0] ronda_esp
    );
        respuesta_correcta = resp_correcta;

        // J1 confirma primero si aplica
        if (j1_responde) begin
            ciclo(1'b1, 1'b0, resp_fpga_val, resp_pc_val);
            ciclo(1'b0, 1'b0, resp_fpga_val, resp_pc_val); // pulso de un ciclo
        end

        // J2 confirma si aplica
        if (j2_responde) begin
            ciclo(1'b0, 1'b1, resp_fpga_val, resp_pc_val);
            ciclo(1'b0, 1'b0, resp_fpga_val, resp_pc_val);
        end

        // Esperar que rcp_fsm transite a DONE y main_fsm a CHECK
        // (puede tomar varios ciclos hasta que ambos R_valid suban)
        repeat(6) ciclo(1'b0, 1'b0, resp_fpga_val, resp_pc_val);

        // CHECK → STEP → ROUND_Q (3 ciclos)
        repeat(3) ciclo(1'b0, 1'b0, resp_fpga_val, resp_pc_val);

        // Verificar resultado y puntajes en ROUND_Q
        #1;
        if (resultado_ronda !== resultado_esperado) begin
            $display("FALLO [%s - resultado_ronda: esp=%02b obt=%02b]",
                     descripcion, resultado_esperado, resultado_ronda);
            errores++;
        end else
            $display("OK    [%s - resultado_ronda=%02b]", descripcion, resultado_ronda);

        if (score_j1 !== score_j1_esp || score_j2 !== score_j2_esp) begin
            $display("FALLO [%s - scores: esp=j1:%0d j2:%0d obt=j1:%0d j2:%0d]",
                     descripcion, score_j1_esp, score_j2_esp, score_j1, score_j2);
            errores++;
        end else
            $display("OK    [%s - score_j1=%0d score_j2=%0d]",
                     descripcion, score_j1, score_j2);

        if (ronda !== ronda_esp) begin
            $display("FALLO [%s - ronda: esp=%0d obt=%0d]",
                     descripcion, ronda_esp, ronda);
            errores++;
        end else
            $display("OK    [%s - ronda=%0d]", descripcion, ronda);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: simular una ronda que termina por timeout
    // Espera que el top ya este en WAIT_R
    // -------------------------------------------------------------------------
    task automatic ronda_con_timeout(
        input string      descripcion,
        input logic [W-1:0] score_j1_esp,
        input logic [W-1:0] score_j2_esp,
        input logic [W-1:0] ronda_esp
    );
        // Esperar timeout: FREQ*TIME = 16 ciclos + margen
        repeat(FREQ * TIME + 4) ciclo(1'b0, 1'b0, 2'b00, 2'b00);

        // CHECK → STEP → ROUND_Q
        repeat(3) ciclo(1'b0, 1'b0, 2'b00, 2'b00);

        #1;
        if (resultado_ronda !== 2'b00) begin
            $display("FALLO [%s - resultado_ronda: esp=00 obt=%02b]",
                     descripcion, resultado_ronda);
            errores++;
        end else
            $display("OK    [%s - resultado_ronda=00 (timeout)]", descripcion);

        if (ronda !== ronda_esp) begin
            $display("FALLO [%s - ronda: esp=%0d obt=%0d]",
                     descripcion, ronda_esp, ronda);
            errores++;
        end else
            $display("OK    [%s - ronda=%0d]", descripcion, ronda);

        if (score_j1 !== score_j1_esp || score_j2 !== score_j2_esp) begin
            $display("FALLO [%s - scores sin cambio: esp=j1:%0d j2:%0d obt=j1:%0d j2:%0d]",
                     descripcion, score_j1_esp, score_j2_esp, score_j1, score_j2);
            errores++;
        end else
            $display("OK    [%s - scores sin cambio j1=%0d j2=%0d]",
                     descripcion, score_j1, score_j2);
    endtask

    // =========================================================================
    // Estimulos: partida completa de 7 rondas
    // =========================================================================
    initial begin

        // =====================================================================
        // CASO 0: Reset — IDLE, salidas en estado inicial
        // =====================================================================
        reset_sistema();
        verificar("IDLE tras reset", 3'b000, 1'b0, 1'b0, 1'b0);

        // =====================================================================
        // RONDA 1: J1 gana (respuesta correcta, J1 mas rapido)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 1 - J1 gana",
            1'b1, 1'b1,       // ambos responden
            2'b01, 2'b01,     // ambos correctos
            2'b01,            // respuesta correcta = B
            2'b01,            // J1 gana (respondio primero)
            W'(1), W'(0),     // score_j1=1, score_j2=0
            W'(1));           // ronda=1

        // =====================================================================
        // RONDA 2: J2 gana (solo J2 correcto)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 2 - J2 gana",
            1'b1, 1'b1,
            2'b00, 2'b10,     // J1 incorrecto (A), J2 correcto (C)
            2'b10,            // respuesta correcta = C
            2'b10,            // J2 gana
            W'(1), W'(1),
            W'(2));

        // =====================================================================
        // RONDA 3: Nadie gana (timeout)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_timeout("Ronda 3 - timeout",
            W'(1), W'(1),     // scores sin cambio
            W'(3));           // ronda=3

        // =====================================================================
        // RONDA 4: J1 gana (solo J1 correcto)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 4 - J1 gana",
            1'b1, 1'b1,
            2'b11, 2'b00,     // J1 correcto (D), J2 incorrecto (A)
            2'b11,            // respuesta correcta = D
            2'b01,
            W'(2), W'(1),
            W'(4));

        // =====================================================================
        // RONDA 5: Nadie gana (ambos incorrectos)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 5 - nadie gana",
            1'b1, 1'b1,
            2'b00, 2'b01,     // ambos incorrectos
            2'b11,            // respuesta correcta = D
            2'b00,
            W'(2), W'(1),
            W'(5));

        // =====================================================================
        // RONDA 6: J2 gana (solo J2 responde)
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 6 - J2 gana (solo J2 responde)",
            1'b0, 1'b1,       // solo J2 responde
            2'b00, 2'b01,
            2'b01,
            2'b10,
            W'(2), W'(2),
            W'(6));

        // =====================================================================
        // RONDA 7: J1 gana — ultima ronda, debe activar game_done y END_GAME
        // =====================================================================
        avanzar_a_wait_r();
        ronda_con_respuestas("Ronda 7 - J1 gana (ultima ronda)",
            1'b1, 1'b0,       // solo J1 responde
            2'b10, 2'b00,
            2'b10,
            2'b01,
            W'(3), W'(2),
            W'(7));

        // Verificar que tras la ronda 7 el sistema llega a END_GAME
        #1;
        if (estado_juego !== 3'b111) begin
            $display("FALLO [END_GAME tras 7 rondas: esp=111 obt=%03b]", estado_juego);
            errores++;
        end else
            $display("OK    [END_GAME activo tras 7 rondas]");

        // END_GAME persiste
        repeat(4) ciclo(1'b0, 1'b0, 2'b00, 2'b00);
        #1;
        if (estado_juego !== 3'b111) begin
            $display("FALLO [END_GAME no persiste: obt=%03b]", estado_juego);
            errores++;
        end else
            $display("OK    [END_GAME persiste]");

        // =====================================================================
        // CASO: Reset desde END_GAME — sistema vuelve a IDLE
        // =====================================================================
        reset_sistema();
        verificar("IDLE tras reset desde END_GAME", 3'b000, 1'b0, 1'b0, 1'b0);

        // Verificar que scores y ronda se limpiaron
        #1;
        if (score_j1 !== W'(0) || score_j2 !== W'(0)) begin
            $display("FALLO [scores limpios tras reset: j1=%0d j2=%0d]", score_j1, score_j2);
            errores++;
        end else
            $display("OK    [scores en cero tras reset]");

        // =====================================================================
        // Resultado final
        // =====================================================================
        $display("--------------------------------------------");
        if (errores == 0)
            $display("TODOS LOS CASOS PASARON (0 errores)");
        else
            $display("FALLARON %0d CASO(S)", errores);
        $display("--------------------------------------------");

        $finish;
    end

endmodule