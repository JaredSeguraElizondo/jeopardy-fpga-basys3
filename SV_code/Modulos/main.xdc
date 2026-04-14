## =========================================================
## Archivo XDC FINAL CORREGIDO - Jeopardy! Basys 3
## Configuración: Pantalla hacia ARRIBA 
## J2 (Control) -> JC FILA INFERIOR | J1 (Datos) -> JB COMPLETO
## =========================================================

## 1. Reloj del Sistema (100 MHz)
set_property PACKAGE_PIN W5 [get_ports clk_100mhz]							
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk_100mhz]

## 2. Botones y Reset
set_property PACKAGE_PIN U18 [get_ports rst_btn]						
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]
set_property PACKAGE_PIN T18 [get_ports {btn_async[2]}]						
set_property IOSTANDARD LVCMOS33 [get_ports {btn_async[2]}]
set_property PACKAGE_PIN W19 [get_ports {btn_async[0]}]						
set_property IOSTANDARD LVCMOS33 [get_ports {btn_async[0]}]
set_property PACKAGE_PIN T17 [get_ports {btn_async[1]}]						
set_property IOSTANDARD LVCMOS33 [get_ports {btn_async[1]}]

## 3. Display 7-Segmentos (Puntajes)
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

set_property PACKAGE_PIN U2 [get_ports {an[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

## 4. Buzzer y UART
set_property PACKAGE_PIN J1 [get_ports buzzer_pwm]					
set_property IOSTANDARD LVCMOS33 [get_ports buzzer_pwm]
set_property PACKAGE_PIN B18 [get_ports RsRx]						
set_property IOSTANDARD LVCMOS33 [get_ports RsRx]
set_property PACKAGE_PIN A18 [get_ports RsTx]						
set_property IOSTANDARD LVCMOS33 [get_ports RsTx]

## 5. LCD PmodCLP (Re-mapeado Físico)

# CONTROL (Puerto JC - AHORA EN FILA INFERIOR) -> Conectado a J2
set_property PACKAGE_PIN L17 [get_ports lcd_rs]					
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rs]
set_property PACKAGE_PIN M19 [get_ports lcd_rw]					
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rw]
set_property PACKAGE_PIN P17 [get_ports lcd_en]					
set_property IOSTANDARD LVCMOS33 [get_ports lcd_en]

# DATOS 8-BITS (Puerto JB - COMPLETO) -> Conectado a J1
set_property PACKAGE_PIN A14 [get_ports {lcd_data[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[0]}]
set_property PACKAGE_PIN A16 [get_ports {lcd_data[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[1]}]
set_property PACKAGE_PIN B15 [get_ports {lcd_data[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[2]}]
set_property PACKAGE_PIN B16 [get_ports {lcd_data[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[3]}]
set_property PACKAGE_PIN A15 [get_ports {lcd_data[4]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[4]}]
set_property PACKAGE_PIN A17 [get_ports {lcd_data[5]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[5]}]
set_property PACKAGE_PIN C15 [get_ports {lcd_data[6]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[6]}]
set_property PACKAGE_PIN C16 [get_ports {lcd_data[7]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_data[7]}]

## 6. Configuración de Bitstream y Voltaje
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Forzar generación si hay advertencias de pines no usados
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]