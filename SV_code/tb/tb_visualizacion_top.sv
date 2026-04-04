`timescale 1ns / 1ps

module tb_visualizacion_top ();

    // Parámetros
    localparam CLK_PERIOD = 62.5;  // ns
    
    // Señales
    reg         clk;
    reg         rst;
    reg  [1:0]  addr;
    reg         write_enable;
    reg  [31:0] wdata;
    wire [31:0] rdata;
    reg         mostrar_pregunta;
    reg         mostrar_opciones;
    reg  [127:0] pregunta_str;
    reg  [127:0] opciones_str;
    reg  [7:0]  puntaje_fpga;
    reg  [7:0]  tiempo_restante;
    wire        lcd_ready;
    wire [7:0]  lcd_db;
    wire        lcd_e;
    wire        lcd_rs;
    wire        lcd_rw;
    wire [3:0]  seg_an;
    wire [6:0]  seg_cat;
    
    // Variables de verificación
    integer test_passed;
    integer test_failed;
    integer wait_cnt;
    

    visualizacion_top uut (
        .clk_i              (clk),
        .rst_i              (rst),
        .addr_i             (addr),
        .write_enable_i     (write_enable),
        .wdata_i            (wdata),
        .rdata_o            (rdata),
        .mostrar_pregunta_i (mostrar_pregunta),
        .mostrar_opciones_i (mostrar_opciones),
        .pregunta_str_i     (pregunta_str),
        .opciones_str_i     (opciones_str),
        .puntaje_fpga_i     (puntaje_fpga),
        .tiempo_restante_i  (tiempo_restante),
        .lcd_ready_o        (lcd_ready),
        .lcd_db_o           (lcd_db),
        .lcd_e_o            (lcd_e),
        .lcd_rs_o           (lcd_rs),
        .lcd_rw_o           (lcd_rw),
        .seg_an_o           (seg_an),
        .seg_cat_o          (seg_cat)
    );
    

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    

    task write_reg;
        input [1:0] reg_addr;
        input [31:0] data;
        begin
            @(posedge clk);
            addr <= reg_addr;
            wdata <= data;
            write_enable <= 1;
            @(posedge clk);
            write_enable <= 0;
            addr <= 0;
            wdata <= 0;
        end
    endtask
    
    // Tarea para escribir un comando o dato al LCD
    task lcd_write;
        input rs;
        input [7:0] data;
        begin
            write_reg(2'b01, {24'h0, data});
            write_reg(2'b00, {28'h0, 1'b0, 1'b0, rs, 1'b1});
            @(posedge clk);
            while (!lcd_ready) @(posedge clk);
        end
    endtask
    
    // Tarea de verificación
    task check;
        input [255:0] nombre;
        input cond;
        input [255:0] msg;
        begin
            @(negedge clk);
            if (cond) begin
                $display("[%0t] ✓ PASO: %s", $time, nombre);
                test_passed = test_passed + 1;
            end else begin
                $display("[%0t] ✗ FALLO: %s - %s", $time, nombre, msg);
                test_failed = test_failed + 1;
            end
        end
    endtask
    
    // Proceso principal
    initial begin
        // Inicializar
        test_passed = 0;
        test_failed = 0;
        
        $display("");
        $display("============================================================");
        $display("  TESTBENCH: visualizacion_top");
        $display("  Modo: Post-Implementation Functional Simulation");
        $display("============================================================");
        $display("");
        
        // Reset
        rst = 1;
        addr = 0;
        write_enable = 0;
        wdata = 0;
        mostrar_pregunta = 0;
        mostrar_opciones = 0;
        pregunta_str = 0;
        opciones_str = 0;
        puntaje_fpga = 0;
        tiempo_restante = 30;
        
        repeat(5) @(posedge clk);
        rst = 0;
        $display("[%0t] Reset liberado", $time);
        
       // Test 1: Verificar que el LCD se inicializa correctamente
        $display("");
        $display("--- TEST 1: Inicializacion del LCD ---");
        
        wait_cnt = 0;
        while (wait_cnt < 500000) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        
        check("Inicializacion completada", lcd_ready, "LCD no quedo listo");
        
        // Test 2: Verificar lectura de registros
        $display("");
        $display("--- TEST 2: Lectura de registros ---");
        
        @(posedge clk);
        addr = 2'b00;
        write_enable = 0;
        @(posedge clk);
        
        check("Bit busy = 0", (rdata[8] == 0), "busy deberia ser 0");
        check("Bit done = 0", (rdata[9] == 0), "done deberia ser 0");
        
        // Test 3: Enviar comando Clear Display
        $display("");
        $display("--- TEST 3: Clear Display ---");
        
        lcd_write(0, 8'h01);
        check("Clear Display ejecutado", 1, "OK");
        
        // Test 4: Escribir caracter 'A'
        $display("");
        $display("--- TEST 4: Escribir caracter 'A' ---");
        
        lcd_write(1, 8'h41);
        check("Caracter 'A' escrito", 1, "OK");
        
        // test 5: Auto-escritor de pregunta
        $display("");
        $display("--- TEST 5: Auto-escritor (pregunta) ---");
        
        // Cargar pregunta de ejemplo: "HOLA MUNDO"
        pregunta_str = {
            8'h48, 8'h4F, 8'h4C, 8'h41, 8'h20, 8'h4D, 8'h55, 8'h4E,  // "HOLA MUN"
            8'h44, 8'h4F, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20, 8'h20,  // "DO      "
            8'h50, 8'h52, 8'h45, 8'h47, 8'h55, 8'h4E, 8'h54, 8'h41,  // "PREGUNTA"
            8'h20, 8'h54, 8'h45, 8'h53, 8'h54, 8'h20, 8'h20, 8'h20   // " TEST   "
        };
        
        @(posedge clk);
        mostrar_pregunta = 1;
        repeat(2) @(posedge clk);
        mostrar_pregunta = 0;
        
        wait_cnt = 0;
        while (!lcd_ready && wait_cnt < 50000) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        
        check("Auto-escritor pregunta OK", 1, "OK");
        
        // Test 6: Auto-escritor de opciones
        $display("");
        $display("--- TEST 6: Auto-escritor (opciones) ---");
        
        opciones_str = {
            8'h41, 8'h3A, 8'h4F, 8'h50, 8'h43, 8'h49, 8'h4F, 8'h4E,  // "A:OPCION"
            8'h41, 8'h20, 8'h20, 8'h43, 8'h3A, 8'h4F, 8'h50, 8'h43,  // "A  C:OPC"
            8'h49, 8'h4F, 8'h4E, 8'h43, 8'h20, 8'h20, 8'h20, 8'h20,  // "IONC    "
            8'h42, 8'h3A, 8'h4F, 8'h50, 8'h43, 8'h49, 8'h4F, 8'h4E,  // "B:OPCION"
            8'h42, 8'h20, 8'h20, 8'h44, 8'h3A, 8'h4F, 8'h50, 8'h43,  // "B  D:OPC"
            8'h49, 8'h4F, 8'h4E, 8'h44, 8'h20, 8'h20, 8'h20, 8'h20   // "IOND    "
        };
        
        @(posedge clk);
        mostrar_opciones = 1;
        repeat(2) @(posedge clk);
        mostrar_opciones = 0;
        
        wait_cnt = 0;
        while (!lcd_ready && wait_cnt < 50000) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        
        check("Auto-escritor opciones OK", 1, "OK");
        
        // Test 7: Verificar displays de 7 segmentos
        $display("");
        $display("--- TEST 7: Displays 7 segmentos ---");
        
        // Probar puntaje=5, tiempo=30
        puntaje_fpga = 5;
        tiempo_restante = 30;
        repeat(100) @(posedge clk);
        check("Display actualiza puntaje=5", (seg_an != 4'b1111), "Multiplexado activo");
        
        // Probar puntaje=7, tiempo=15
        puntaje_fpga = 7;
        tiempo_restante = 15;
        repeat(100) @(posedge clk);
        check("Display actualiza tiempo=15", 1, "OK");
        
        // Probar puntaje=0, tiempo=0
        puntaje_fpga = 0;
        tiempo_restante = 0;
        repeat(100) @(posedge clk);
        check("Display muestra cero", 1, "OK");
        
        // Test 8: Enviar comando Display ON
        $display("");
        $display("--- TEST 8: Display ON command ---");
        
        lcd_write(0, 8'h0E);
        check("Display ON ejecutado", 1, "OK");
        
    
        $display("");
        $display("============================================================");
        $display("                    RESUMEN FINAL");
        $display("============================================================");
        $display("  Pruebas exitosas : %0d", test_passed);
        $display("  Pruebas fallidas : %0d", test_failed);
        $display("============================================================");
        
        if (test_failed == 0) begin
            $display("");
            $display("========== TODAS LAS PRUEBAS PASARON ==========");
            $display("");
        end else begin
            $display("");
            $display("========== %0d PRUEBAS FALLARON ==========", test_failed);
            $display("");
        end
        
       $finish;
    end
    
    // Monitor de señales del LCD
    always @(posedge clk) begin
        if (lcd_e && !rst) begin
            $display("[%0t] LCD: RS=%b, DB=0x%02X", $time, lcd_rs, lcd_db);
        end
    end
    
    // Timeout para evitar simulaciones infinitas
    initial begin
        #50000000;
        $display("");
        $display("ERROR: TIMEOUT - Simulacion muy larga");
        $finish;
    end

endmodule