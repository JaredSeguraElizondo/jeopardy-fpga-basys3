`timescale 1ns / 1ps

module tb_sound_top_auto ();

    localparam CLK_PERIOD = 62.5;
    
    reg         clk;
    reg         rst;
    reg         respuesta_correcta;
    reg         respuesta_incorrecta;
    reg         enable;
    wire        buzzer_out;
    wire        busy;
    
    integer test_passed;
    integer test_failed;
    
    sound_top uut (
        .clk_i                  (clk),
        .rst_i                  (rst),
        .respuesta_correcta_i   (respuesta_correcta),
        .respuesta_incorrecta_i (respuesta_incorrecta),
        .enable_i               (enable),
        .buzzer_out_o           (buzzer_out),
        .busy_o                 (busy)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task generar_pulso_correcto;
        begin
            @(negedge clk);
            respuesta_correcta = 1;
            @(negedge clk);
            respuesta_correcta = 0;
        end
    endtask
    
    task generar_pulso_incorrecto;
        begin
            @(negedge clk);
            respuesta_incorrecta = 1;
            @(negedge clk);
            respuesta_incorrecta = 0;
        end
    endtask
    
    task generar_ambos_pulsos;
        begin
            @(negedge clk);
            respuesta_correcta = 1;
            respuesta_incorrecta = 1;
            @(negedge clk);
            respuesta_correcta = 0;
            respuesta_incorrecta = 0;
        end
    endtask
    
    task esperar_us;
        input int us;
        repeat (us * 16) @(posedge clk);
    endtask
    
    task esperar_ms;
        input int ms;
        repeat (ms * 16000) @(posedge clk);
    endtask
    
    task verificar;
        input [255:0] nombre;
        input cond;
        input [255:0] msg;
        begin
            @(negedge clk);
            if (cond) begin
                $display("  [%0t] CORRECTO: %s", $time, nombre);
                test_passed = test_passed + 1;
            end else begin
                $display("  [%0t] FALLO: %s - %s", $time, nombre, msg);
                test_failed = test_failed + 1;
            end
        end
    endtask
    
    task verificar_buzzer;
        input [255:0] nombre;
        input deberia_sonar;
        integer i;
        logic sonido_detectado;
        begin
            sonido_detectado = 0;
            // Buscar durante 1ms si hay algún pulso en buzzer_out
            for (i = 0; i < 16000; i = i + 1) begin
                @(posedge clk);
                if (buzzer_out == 1) begin
                    sonido_detectado = 1;
                end
            end
            
            @(negedge clk);
            if (sonido_detectado == deberia_sonar) begin
                $display("  [%0t] CORRECTO: %s", $time, nombre);
                test_passed = test_passed + 1;
            end else begin
                if (deberia_sonar) begin
                    $display("  [%0t] FALLO: %s - No se detecto sonido", $time, nombre);
                end else begin
                    $display("  [%0t] FALLO: %s - Se detecto sonido cuando no debia", $time, nombre);
                end
                test_failed = test_failed + 1;
            end
        end
    endtask
    
    initial begin
        test_passed = 0;
        test_failed = 0;
        
        $display("");
        $display("=============================");
        $display("  TESTBENCH Autoverificable ");
        $display("=============================");
        $display("");
        
        rst = 1;
        respuesta_correcta = 0;
        respuesta_incorrecta = 0;
        enable = 1;
        
        repeat(10) @(posedge clk);
        rst = 0;
        $display("[%0t] Reset liberado", $time);
        
        esperar_ms(1);
        
        $display("");
        $display("--- TEST 1: Estado inicial ---");
        verificar("busy = 0 en IDLE", (busy == 0), "busy deberia ser 0");
        verificar("buzzer_out = 0 en IDLE", (buzzer_out == 0), "buzzer deberia estar apagado");
        
        $display("");
        $display("--- TEST 2: Respuesta correcta ---");
        generar_pulso_correcto();
        esperar_us(100);
        verificar("busy se activa", (busy == 1), "busy deberia ser 1");
        verificar_buzzer("buzzer suena (correcto)", 1);
        
        $display("");
        $display("--- TEST 3: Fin del sonido (200ms) ---");
        esperar_ms(250);
        verificar("busy vuelve a 0", (busy == 0), "busy deberia ser 0");
        verificar("buzzer se apaga", (buzzer_out == 0), "buzzer deberia estar apagado");
        
        $display("");
        $display("--- TEST 4: Respuesta incorrecta ---");
        generar_pulso_incorrecto();
        esperar_us(100);
        verificar("busy se activa", (busy == 1), "busy deberia ser 1");
        verificar_buzzer("buzzer suena (incorrecto)", 1);
        
        esperar_ms(250);
        verificar("busy vuelve a 0 despues incorrecto", (busy == 0), "busy deberia ser 0");
        
        $display("");
        $display("--- TEST 5: Mute (enable=0) ---");
        enable = 0;
        generar_pulso_correcto();
        esperar_us(100);
        verificar("busy NO se activa con mute", (busy == 0), "busy deberia ser 0");
        verificar_buzzer("buzzer NO suena con mute", 0);
        
        enable = 1;
        
        $display("");
        $display("--- TEST 6: Prioridad correcta > incorrecta ---");
        generar_ambos_pulsos();
        esperar_us(100);
        verificar("prioridad correcta (busy activo)", (busy == 1), "debe reproducir tono correcto");
        
        esperar_ms(250);
        
        $display("");
        $display("============================================================");
        $display("  RESULTADOS");
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

endmodule

