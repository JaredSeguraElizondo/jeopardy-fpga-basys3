// tb_time_reg.sv
// Testbench autoverificable para time_reg.
// Las entradas se aplican en posedge clk y se verifica tras el negedge siguiente,
// ya que la captura ocurre en flanco de bajada.

`timescale 1ns/1ps

module tb_time_reg;

    // ------------------------------------------------------------
    // Parametros — valores reducidos para simulacion
    // ------------------------------------------------------------
    parameter FREQ  = 16;   // Reducido: no necesitamos el contador real
    parameter TIME  = 4;
    parameter COUNT = $clog2(FREQ * TIME); // 6 bits

    // ------------------------------------------------------------
    // Senales
    // ------------------------------------------------------------
    logic             clk;
    logic             rst;
    logic [COUNT-1:0] count;
    logic             save_time_j1;
    logic             save_time_j2;
    logic             R1_valid;
    logic             R2_valid;
    logic [COUNT-1:0] timestamp_j1;
    logic [COUNT-1:0] timestamp_j2;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    time_reg #(
        .FREQ (FREQ),
        .TIME (TIME)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .count       (count),
        .save_time_j1(save_time_j1),
        .save_time_j2(save_time_j2),
        .R1_valid    (R1_valid),
        .R2_valid    (R2_valid),
        .timestamp_j1(timestamp_j1),
        .timestamp_j2(timestamp_j2)
    );

    // ------------------------------------------------------------
    // Generador de reloj: periodo 10 ns
    // ------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Contador de errores
    // ------------------------------------------------------------
    int errores = 0;

    // ------------------------------------------------------------
    // Tarea: aplicar estimulos en posedge y verificar tras negedge
    // ------------------------------------------------------------
    task automatic aplicar_y_verificar(
        input string         descripcion,
        input logic          i_save_j1,
        input logic          i_save_j2,
        input logic [COUNT-1:0] i_count,
        input logic          r1v_esperado,
        input logic          r2v_esperado,
        input logic [COUNT-1:0] ts_j1_esperado,
        input logic [COUNT-1:0] ts_j2_esperado
    );
        // Aplicar entradas en posedge (estables antes del negedge)
        @(posedge clk);
        save_time_j1 = i_save_j1;
        save_time_j2 = i_save_j2;
        count        = i_count;

        // Esperar el negedge donde ocurre la captura
        @(negedge clk);
        #1; // Pequeno retardo para propagacion de assigns

        if (R1_valid    !== r1v_esperado    ||
            R2_valid    !== r2v_esperado    ||
            timestamp_j1 !== ts_j1_esperado ||
            timestamp_j2 !== ts_j2_esperado) begin

            $display("FALLO [%s]", descripcion);
            $display("  R1_valid    : esperado=%b  obtenido=%b", r1v_esperado,    R1_valid);
            $display("  R2_valid    : esperado=%b  obtenido=%b", r2v_esperado,    R2_valid);
            $display("  timestamp_j1: esperado=%0d obtenido=%0d", ts_j1_esperado, timestamp_j1);
            $display("  timestamp_j2: esperado=%0d obtenido=%0d", ts_j2_esperado, timestamp_j2);
            errores++;
        end else begin
            $display("OK    [%s]", descripcion);
        end

        // Limpiar pulsos para el siguiente ciclo
        save_time_j1 = 1'b0;
        save_time_j2 = 1'b0;
    endtask

    // ------------------------------------------------------------
    // Estimulos
    // ------------------------------------------------------------
    initial begin
        // Estado inicial
        rst          = 1'b1;
        save_time_j1 = 1'b0;
        save_time_j2 = 1'b0;
        count        = '0;

        // --------------------------------------------------------
        // CASO 0: Reset activo — todo debe estar en cero
        // --------------------------------------------------------
        @(negedge clk); #1;
        if (R1_valid !== 1'b0 || R2_valid !== 1'b0 ||
            timestamp_j1 !== '0 || timestamp_j2 !== '0) begin
            $display("FALLO [Reset inicial: salidas no son cero]");
            errores++;
        end else
            $display("OK    [Reset inicial: salidas en cero]");

        @(posedge clk);
        rst = 1'b0; // Liberar reset

        // --------------------------------------------------------
        // CASO 1: J1 no registrado — save_time_j1=0, count cualquiera
        // Esperado: R1_valid=0, timestamp_j1=0 (sin cambio)
        // --------------------------------------------------------
        aplicar_y_verificar(
            "J1 sin save: R1_valid=0, timestamp=0",
            1'b0, 1'b0,        // save_j1=0, save_j2=0
            COUNT'(10),        // count=10 (no debe capturarse)
            1'b0, 1'b0,        // R1_valid=0, R2_valid=0
            COUNT'(0), COUNT'(0) // timestamps sin cambio
        );

        // --------------------------------------------------------
        // CASO 2: J2 no registrado — save_time_j2=0
        // Esperado: R2_valid=0, timestamp_j2=0 (sin cambio)
        // --------------------------------------------------------
        aplicar_y_verificar(
            "J2 sin save: R2_valid=0, timestamp=0",
            1'b0, 1'b0,
            COUNT'(15),
            1'b0, 1'b0,
            COUNT'(0), COUNT'(0)
        );

        // --------------------------------------------------------
        // CASO 3: Captura J1 — save_time_j1=1, R1_valid estaba en 0
        // Esperado: R1_valid=1, timestamp_j1=count
        // --------------------------------------------------------
        aplicar_y_verificar(
            "Captura J1: R1_valid=1, timestamp_j1=20",
            1'b1, 1'b0,        // save_j1=1
            COUNT'(20),        // count=20
            1'b1, 1'b0,        // R1_valid=1, R2_valid=0
            COUNT'(20), COUNT'(0)
        );

        // --------------------------------------------------------
        // CASO 4: Captura J2 — save_time_j2=1, R2_valid estaba en 0
        // Esperado: R2_valid=1, timestamp_j2=count
        // --------------------------------------------------------
        aplicar_y_verificar(
            "Captura J2: R2_valid=1, timestamp_j2=35",
            1'b0, 1'b1,        // save_j2=1
            COUNT'(35),        // count=35
            1'b1, 1'b1,        // R1_valid=1 (ya estaba), R2_valid=1
            COUNT'(20), COUNT'(35)
        );

        // --------------------------------------------------------
        // CASO 5: Intento de sobreescritura J1 — R1_valid ya es 1
        // Esperado: timestamp_j1 NO cambia (guarda activa)
        // --------------------------------------------------------
        aplicar_y_verificar(
            "J1 ya capturado: save_time_j1 ignorado (no sobreescribe)",
            1'b1, 1'b0,        // save_j1=1 pero R1_valid ya es 1
            COUNT'(50),        // count=50, NO debe capturarse
            1'b1, 1'b1,        // R1_valid=1, R2_valid=1
            COUNT'(20), COUNT'(35) // timestamps sin cambio
        );

        // --------------------------------------------------------
        // CASO 6: Intento de sobreescritura J2 — R2_valid ya es 1
        // Esperado: timestamp_j2 NO cambia
        // --------------------------------------------------------
        aplicar_y_verificar(
            "J2 ya capturado: save_time_j2 ignorado (no sobreescribe)",
            1'b0, 1'b1,        // save_j2=1 pero R2_valid ya es 1
            COUNT'(55),
            1'b1, 1'b1,
            COUNT'(20), COUNT'(35) // timestamps sin cambio
        );

        // --------------------------------------------------------
        // CASO 7: save_j1 y save_j2 simultaneos — prioridad J1
        // Primero reset para partir desde cero
        // --------------------------------------------------------
        @(posedge clk); rst = 1'b1;
        @(negedge clk); #1;
        @(posedge clk); rst = 1'b0;

        aplicar_y_verificar(
            "save_j1 y save_j2 simultaneos: solo J1 capturado (prioridad)",
            1'b1, 1'b1,        // ambos save activos
            COUNT'(40),
            1'b1, 1'b0,        // solo R1_valid sube (else if)
            COUNT'(40), COUNT'(0)
        );

        // Ciclo siguiente: ahora J2 puede capturar
        aplicar_y_verificar(
            "save_j2 en ciclo siguiente tras simultaneo: J2 capturado",
            1'b0, 1'b1,
            COUNT'(42),
            1'b1, 1'b1,
            COUNT'(40), COUNT'(42)
        );

        // --------------------------------------------------------
        // CASO 8: Reset tras capturas — todo vuelve a cero
        // --------------------------------------------------------
        @(posedge clk); rst = 1'b1;
        @(negedge clk); #1;
        if (R1_valid !== 1'b0 || R2_valid !== 1'b0 ||
            timestamp_j1 !== '0 || timestamp_j2 !== '0) begin
            $display("FALLO [Reset tras capturas: no limpio correctamente]");
            errores++;
        end else
            $display("OK    [Reset tras capturas: todo limpio]");

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

endmodule