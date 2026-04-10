// tb_main_fsm.sv
// Testbench autoverificable para main_fsm.
// Simula el flujo completo del juego: partida normal, timeout, y fin de partida.

`timescale 1ns/1ps

module tb_main_fsm;

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic        clk, rst;
    logic        game_done, timeout, play_rcp;
    logic [1:0]  resultado_eval;

    logic        round_rst, round_inc;
    logic        iniciar_ronda, temporizador_rst;
    logic        solicitar_pregunta;
    logic        en_rcp, rst_rcp;
    logic        eval_en;
    logic        mostrar_opciones_i, mostrar_pregunta_i;
    logic [2:0]  estado_juego;
    logic [1:0]  resultado_ronda;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    main_fsm dut (
        .clk                (clk),
        .rst                (rst),
        .game_done          (game_done),
        .timeout            (timeout),
        .play_rcp           (play_rcp),
        .resultado_eval     (resultado_eval),
        .round_rst          (round_rst),
        .round_inc          (round_inc),
        .iniciar_ronda      (iniciar_ronda),
        .temporizador_rst   (temporizador_rst),
        .solicitar_pregunta (solicitar_pregunta),
        .en_rcp             (en_rcp),
        .rst_rcp            (rst_rcp),
        .eval_en            (eval_en),
        .mostrar_opciones_i (mostrar_opciones_i),
        .mostrar_pregunta_i (mostrar_pregunta_i),
        .estado_juego       (estado_juego),
        .resultado_ronda    (resultado_ronda)
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
    // Tarea: reset y dejar FSM en IDLE
    // -------------------------------------------------------------------------
    task automatic reset_fsm();
        rst            = 1'b1;
        game_done      = 1'b0;
        timeout        = 1'b0;
        play_rcp       = 1'b0;
        resultado_eval = 2'b00;
        @(posedge clk); #1;
        rst = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: avanzar un ciclo con entradas dadas
    // -------------------------------------------------------------------------
    task automatic ciclo(
        input logic       i_game_done,
        input logic       i_timeout,
        input logic       i_play_rcp,
        input logic [1:0] i_resultado_eval
    );
        game_done      = i_game_done;
        timeout        = i_timeout;
        play_rcp       = i_play_rcp;
        resultado_eval = i_resultado_eval;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificar salidas del estado actual
    // -------------------------------------------------------------------------
    task automatic verificar(
        input string      descripcion,
        input logic       exp_round_rst,
        input logic       exp_round_inc,
        input logic       exp_iniciar_ronda,
        input logic       exp_temporizador_rst,
        input logic       exp_solicitar_pregunta,
        input logic       exp_en_rcp,
        input logic       exp_rst_rcp,
        input logic       exp_eval_en,
        input logic       exp_mostrar_opc,
        input logic       exp_mostrar_preg,
        input logic [2:0] exp_estado_juego
    );
        #1;
        if (round_rst           !== exp_round_rst          ||
            round_inc           !== exp_round_inc          ||
            iniciar_ronda       !== exp_iniciar_ronda      ||
            temporizador_rst    !== exp_temporizador_rst   ||
            solicitar_pregunta  !== exp_solicitar_pregunta ||
            en_rcp              !== exp_en_rcp             ||
            rst_rcp             !== exp_rst_rcp            ||
            eval_en             !== exp_eval_en            ||
            mostrar_opciones_i  !== exp_mostrar_opc        ||
            mostrar_pregunta_i  !== exp_mostrar_preg       ||
            estado_juego        !== exp_estado_juego) begin

            $display("FALLO [%s]", descripcion);
            $display("  round_rst          : esp=%b obt=%b", exp_round_rst,          round_rst);
            $display("  round_inc          : esp=%b obt=%b", exp_round_inc,          round_inc);
            $display("  iniciar_ronda      : esp=%b obt=%b", exp_iniciar_ronda,      iniciar_ronda);
            $display("  temporizador_rst   : esp=%b obt=%b", exp_temporizador_rst,   temporizador_rst);
            $display("  solicitar_pregunta : esp=%b obt=%b", exp_solicitar_pregunta, solicitar_pregunta);
            $display("  en_rcp             : esp=%b obt=%b", exp_en_rcp,             en_rcp);
            $display("  rst_rcp            : esp=%b obt=%b", exp_rst_rcp,            rst_rcp);
            $display("  eval_en            : esp=%b obt=%b", exp_eval_en,            eval_en);
            $display("  mostrar_opciones_i : esp=%b obt=%b", exp_mostrar_opc,        mostrar_opciones_i);
            $display("  mostrar_pregunta_i : esp=%b obt=%b", exp_mostrar_preg,       mostrar_pregunta_i);
            $display("  estado_juego       : esp=%03b obt=%03b", exp_estado_juego,   estado_juego);
            errores++;
        end else
            $display("OK    [%s]", descripcion);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: aplicar rst asincrono y verificar con negedge como referencia
    // -------------------------------------------------------------------------
    task automatic aplicar_rst_y_verificar(input string descripcion);
        rst = 1'b1;
        @(posedge clk); #1;
        verificar(descripcion,
            1'b1, 1'b0, 1'b0, 1'b1,
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b0, 3'b000);
         rst = 1'b0;
    endtask

    // =========================================================================
    // Estimulos
    // =========================================================================
    initial begin

        // =====================================================================
        // CASO 0: Reset — FSM en IDLE
        // =====================================================================
        reset_fsm();
        verificar("IDLE tras reset",
            1'b1, 1'b0, 1'b0, 1'b1,
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b0, 3'b000);

        // =====================================================================
        // FLUJO A: Ronda normal — J1 gana por play_rcp, luego segunda ronda
        // Verifica que STEP regresa a ROUND_Q y no a IDLE
        // =====================================================================

        // IDLE → ROUND_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("ROUND_Q: game_done=0",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b001);

        // ROUND_Q → SEL_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("SEL_Q: solicitar_pregunta=1",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b010);

        // SEL_Q → SHOW
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("SHOW: mostrar_opciones=1, mostrar_pregunta=1",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b011);

        // SHOW → WAIT_R
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("WAIT_R: iniciar_ronda=1, en_rcp=1",
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b100);

        // WAIT_R persiste sin condicion
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("WAIT_R persiste (sin timeout ni play_rcp)",
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b100);

        // WAIT_R → CHECK por play_rcp, J1 gana
        ciclo(1'b0, 1'b0, 1'b1, 2'b01);
        verificar("CHECK: eval_en=1, rst_rcp=1",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1,
            1'b0, 1'b0, 3'b101);

        // CHECK → STEP
        ciclo(1'b0, 1'b0, 1'b0, 2'b01);
        verificar("STEP: round_inc=1",
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b110);

        // resultado_ronda estable en STEP
        if (resultado_ronda !== 2'b01) begin
            $display("FALLO [resultado_ronda=01 estable en STEP: obt=%02b]", resultado_ronda);
            errores++;
        end else
            $display("OK    [resultado_ronda=01 estable en STEP]");

        // STEP → ROUND_Q (no IDLE — este es el cambio clave)
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("STEP->ROUND_Q: confirma que no regresa a IDLE",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b001);

        // =====================================================================
        // FLUJO B: Ronda con timeout — nadie gana
        // =====================================================================
        reset_fsm();

        // IDLE → ROUND_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO B - ROUND_Q",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b001);

        // ROUND_Q → SEL_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO B - SEL_Q",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b010);

        // SEL_Q → SHOW
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO B - SHOW",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b011);

        // SHOW → WAIT_R
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO B - WAIT_R",
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b100);

        // WAIT_R → CHECK por timeout, nadie gana
        ciclo(1'b0, 1'b1, 1'b0, 2'b00);
        verificar("FLUJO B - CHECK tras timeout",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1,
            1'b0, 1'b0, 3'b101);

        // CHECK → STEP
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO B - STEP: round_inc=1",
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b110);

        if (resultado_ronda !== 2'b00) begin
            $display("FALLO [FLUJO B - resultado_ronda=00 tras timeout: obt=%02b]", resultado_ronda);
            errores++;
        end else
            $display("OK    [FLUJO B - resultado_ronda=00 tras timeout]");

        // =====================================================================
        // FLUJO C: Ronda con timeout — J2 gana
        // =====================================================================
        reset_fsm();

        // IDLE → ROUND_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        // ROUND_Q → SEL_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        // SEL_Q → SHOW
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        // SHOW → WAIT_R
        ciclo(1'b0, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO C - WAIT_R",
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b100);

        // WAIT_R → CHECK por timeout, J2 gana
        ciclo(1'b0, 1'b1, 1'b0, 2'b10);
        verificar("FLUJO C - CHECK: eval_en=1, rst_rcp=1",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b1, 1'b1,
            1'b0, 1'b0, 3'b101);

        // CHECK → STEP
        ciclo(1'b0, 1'b0, 1'b0, 2'b10);
        verificar("FLUJO C - STEP: round_inc=1",
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b110);

        if (resultado_ronda !== 2'b10) begin
            $display("FALLO [FLUJO C - resultado_ronda=10 (J2 gana): obt=%02b]", resultado_ronda);
            errores++;
        end else
            $display("OK    [FLUJO C - resultado_ronda=10 (J2 gana)]");

        // =====================================================================
        // FLUJO D: game_done=1 en ROUND_Q → END_GAME
        // =====================================================================
        reset_fsm();

        // IDLE → ROUND_Q con game_done=1
        ciclo(1'b1, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO D - ROUND_Q con game_done=1",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b001);

        // ROUND_Q → END_GAME
        ciclo(1'b1, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO D - END_GAME: estado_juego=111",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b111);

        // END_GAME persiste sin rst
        ciclo(1'b1, 1'b0, 1'b0, 2'b00);
        verificar("FLUJO D - END_GAME persiste (sin rst)",
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 1'b0, 1'b0,
            1'b0, 1'b0, 3'b111);

        // =====================================================================
        // CASO BORDE: rst asincrono desde END_GAME → IDLE inmediato
        // =====================================================================
        aplicar_rst_y_verificar("rst asincrono desde END_GAME: IDLE inmediato");

        // =====================================================================
        // CASO BORDE: rst asincrono desde WAIT_R → IDLE inmediato
        // =====================================================================
        reset_fsm();

        ciclo(1'b0, 1'b0, 1'b0, 2'b00); // IDLE → ROUND_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00); // ROUND_Q → SEL_Q
        ciclo(1'b0, 1'b0, 1'b0, 2'b00); // SEL_Q → SHOW
        ciclo(1'b0, 1'b0, 1'b0, 2'b00); // SHOW → WAIT_R
        verificar("Pre-rst: en WAIT_R",
            1'b0, 1'b0, 1'b1, 1'b0,
            1'b0, 1'b1, 1'b0, 1'b0,
            1'b1, 1'b1, 3'b100);

        aplicar_rst_y_verificar("rst asincrono desde WAIT_R: IDLE inmediato");

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