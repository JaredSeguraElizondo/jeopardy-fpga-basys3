// tb_rcp_fsm.sv
// Testbench autoverificable para rcp_fsm.
// Simula el flujo del juego con capturas de J1 y J2 en distintos ordenes.

`timescale 1ns/1ps

module tb_rcp_fsm;

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic clk, rst, en_rcp, rst_rcp;
    logic fpga_ok, pc_ok;
    logic R1_valid, R2_valid;
    logic save_time_j1, save_time_j2, time_rst, play_rcp;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    rcp_fsm dut (
        .clk         (clk),
        .rst         (rst),
        .en_rcp      (en_rcp),
        .rst_rcp     (rst_rcp),
        .fpga_ok     (fpga_ok),
        .pc_ok       (pc_ok),
        .R1_valid    (R1_valid),
        .R2_valid    (R2_valid),
        .save_time_j1(save_time_j1),
        .save_time_j2(save_time_j2),
        .time_rst    (time_rst),
        .play_rcp    (play_rcp)
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
    // Tarea: verificar salidas
    // -------------------------------------------------------------------------
    task automatic verificar(
        input string descripcion,
        input logic  exp_save_j1,
        input logic  exp_save_j2,
        input logic  exp_time_rst,
        input logic  exp_play_rcp
    );
        #1;
        if (save_time_j1 !== exp_save_j1 ||
            save_time_j2 !== exp_save_j2 ||
            time_rst     !== exp_time_rst ||
            play_rcp     !== exp_play_rcp) begin
            $display("FALLO [%s]", descripcion);
            $display("  save_time_j1: esp=%b obt=%b", exp_save_j1,  save_time_j1);
            $display("  save_time_j2: esp=%b obt=%b", exp_save_j2,  save_time_j2);
            $display("  time_rst    : esp=%b obt=%b", exp_time_rst, time_rst);
            $display("  play_rcp    : esp=%b obt=%b", exp_play_rcp, play_rcp);
            errores++;
        end else
            $display("OK    [%s]", descripcion);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: reset y dejar FSM en IDLE
    // -------------------------------------------------------------------------
    task automatic reset_fsm();
        rst     = 1'b1;
        rst_rcp = 1'b0;
        en_rcp  = 1'b0;
        fpga_ok = 1'b0;
        pc_ok   = 1'b0;
        R1_valid = 1'b0;
        R2_valid = 1'b0;
        @(posedge clk); #1;
        rst = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: avanzar un ciclo con entradas dadas
    // -------------------------------------------------------------------------
    task automatic ciclo(
        input logic i_en_rcp,
        input logic i_fpga_ok,
        input logic i_pc_ok,
        input logic i_R1_valid,
        input logic i_R2_valid
    );
        en_rcp   = i_en_rcp;
        fpga_ok  = i_fpga_ok;
        pc_ok    = i_pc_ok;
        R1_valid = i_R1_valid;
        R2_valid = i_R2_valid;
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Tarea: aplicar rst_rcp asincrono y verificar con negedge como referencia
    // -------------------------------------------------------------------------
    task automatic aplicar_rst_rcp_y_verificar(input string descripcion);
        rst_rcp = 1'b1;
        @(negedge clk); // Esperar punto estable donde propagacion ya ocurrio
        #1;
        verificar(descripcion, 1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk); rst_rcp = 1'b0;
    endtask

    // =========================================================================
    // Estimulos
    // =========================================================================
    initial begin

        // =====================================================================
        // CASO 0: Reset inicial — IDLE, time_rst activo
        // =====================================================================
        reset_fsm();
        verificar("IDLE tras reset: time_rst=1, resto=0",
                  1'b0, 1'b0, 1'b1, 1'b0);

        // =====================================================================
        // CASO 1: IDLE → MONITOR al activar en_rcp
        // =====================================================================
        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        verificar("MONITOR: todas las salidas inactivas",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // =====================================================================
        // FLUJO A: J1 primero, luego J2
        // =====================================================================

        // MONITOR → REG_J1
        ciclo(1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
        verificar("REG_J1: save_time_j1=1",
                  1'b1, 1'b0, 1'b0, 1'b0);

        // REG_J1 → MONITOR, R1_valid sube
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
        verificar("MONITOR tras REG_J1: salidas inactivas",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // MONITOR → REG_J2
        ciclo(1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
        verificar("REG_J2: save_time_j2=1",
                  1'b0, 1'b1, 1'b0, 1'b0);

        // REG_J2 → MONITOR, R2_valid sube
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("MONITOR con R1_valid=R2_valid=1: transita a DONE",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // MONITOR → DONE
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("DONE: play_rcp=1",
                  1'b0, 1'b0, 1'b0, 1'b1);

        // DONE persiste
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("DONE persiste: play_rcp=1 (sin rst_rcp)",
                  1'b0, 1'b0, 1'b0, 1'b1);
        // DONE a IDLE con rst_rcp asincrono
        reset_fsm();

        // rst_rcp asíncrono → IDLE
        aplicar_rst_rcp_y_verificar("FLUJO A - IDLE tras rst_rcp asincrono");

        // =====================================================================
        // FLUJO B: J2 primero, luego J1
        // =====================================================================

        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        verificar("FLUJO B - MONITOR inicial",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // MONITOR → REG_J2
        ciclo(1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
        verificar("FLUJO B - REG_J2: save_time_j2=1",
                  1'b0, 1'b1, 1'b0, 1'b0);

        // REG_J2 → MONITOR, R2_valid sube
        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b1);
        verificar("FLUJO B - MONITOR tras REG_J2",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // MONITOR → REG_J1
        ciclo(1'b1, 1'b1, 1'b0, 1'b0, 1'b1);
        verificar("FLUJO B - REG_J1: save_time_j1=1",
                  1'b1, 1'b0, 1'b0, 1'b0);

        // REG_J1 → MONITOR, R1_valid sube → ambos activos → DONE
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("FLUJO B - MONITOR con ambos R_valid: transita a DONE",
                  1'b0, 1'b0, 1'b0, 1'b0);

        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("FLUJO B - DONE: play_rcp=1",
                  1'b0, 1'b0, 1'b0, 1'b1);

        // DONE a IDLE con rst_rcp asincrono
        reset_fsm();

        aplicar_rst_rcp_y_verificar("FLUJO B - IDLE tras rst_rcp");

        // =====================================================================
        // FLUJO C: fpga_ok y pc_ok simultáneos → prioridad J1
        // =====================================================================

        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        verificar("FLUJO C - MONITOR inicial",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // Ambos simultáneos → REG_J1 por prioridad
        ciclo(1'b1, 1'b1, 1'b1, 1'b0, 1'b0);
        verificar("FLUJO C - REG_J1 prioritario (simultaneos)",
                  1'b1, 1'b0, 1'b0, 1'b0);

        // REG_J1 → MONITOR, R1_valid sube, pc_ok sigue activo → REG_J2
        ciclo(1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
        verificar("FLUJO C - MONITOR -> REG_J2 en ciclo siguiente",
                  1'b0, 1'b0, 1'b0, 1'b0);

        ciclo(1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
        verificar("FLUJO C - REG_J2: save_time_j2=1",
                  1'b0, 1'b1, 1'b0, 1'b0);

        // R2_valid sube → DONE
        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("FLUJO C - MONITOR con ambos R_valid",
                  1'b0, 1'b0, 1'b0, 1'b0);

        ciclo(1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
        verificar("FLUJO C - DONE: play_rcp=1",
                  1'b0, 1'b0, 1'b0, 1'b1);
        
        // DONE a IDLE con rst_rcp asincrono
        reset_fsm();

        aplicar_rst_rcp_y_verificar("FLUJO C - IDLE tras rst_rcp");

        // =====================================================================
        // CASO BORDE: fpga_ok con R1_valid=1 → MONITOR no transita a REG_J1
        // =====================================================================

        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        ciclo(1'b1, 1'b1, 1'b0, 1'b1, 1'b0); // fpga_ok=1 pero R1_valid=1
        verificar("BORDE - fpga_ok con R1_valid=1: permanece en MONITOR",
                  1'b0, 1'b0, 1'b0, 1'b0);

        // =====================================================================
        // CASO BORDE: rst global asíncrono desde REG_J1
        // =====================================================================

        ciclo(1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        ciclo(1'b1, 1'b1, 1'b0, 1'b0, 1'b0); // → REG_J1
        verificar("Pre-rst: en REG_J1, save_time_j1=1",
                  1'b1, 1'b0, 1'b0, 1'b0);

        rst = 1'b1;
        @(negedge clk); #1;
        verificar("rst asincrono desde REG_J1: IDLE, time_rst=1",
                  1'b0, 1'b0, 1'b1, 1'b0);
        @(posedge clk); rst = 1'b0;

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