# Jeopardy 

## Investigación previa 

**Investigue el funcionamiento general de módulos LCD compatibles con controlador HD44780 y su secuencia de inicialización**

## LCD compatible con controlador HD44780

Los módulos LCD alfanuméricos basados en el controlador **HD44780** son ampliamente utilizados en sistemas embebidos para la visualización de texto. Estos dispositivos permiten mostrar caracteres en configuraciones típicas como 16x2 o 20x4.

### Funcionamiento general

El controlador HD44780 gestiona internamente la memoria de caracteres y el control del display. Su operación se basa en el envío de comandos e información mediante un bus paralelo.

El LCD dispone de dos tipos principales de registros:

- **Registro de instrucciones (IR):**  
  Se utiliza para enviar comandos de control, como limpiar pantalla, configurar el modo de operación o posicionar el cursor.

- **Registro de datos (DR):**  
  Se utiliza para enviar los caracteres que se desean mostrar en pantalla.

El acceso a estos registros se realiza mediante las siguientes señales:

- **RS (Register Select):**
  - 0 → comando (IR)
  - 1 → dato (DR)

- **RW (Read/Write):**
  - 0 → escritura
  - 1 → lectura (usualmente no se usa en FPGA)

- **E (Enable):**  
  Señal de habilitación. El dato se captura en el flanco de esta señal.

- **D0–D7:**  
  Bus de datos (modo de 8 bits). También puede operar en modo de 4 bits usando solo D4–D7.

Internamente, el LCD posee:

- **DDRAM (Display Data RAM):** almacena los caracteres a mostrar.
- **CGRAM (Character Generator RAM):** permite definir caracteres personalizados.

---

### Modos de operación

El LCD puede operar en:

- **Modo de 8 bits:**  
  Se utilizan las 8 líneas de datos (más rápido).

- **Modo de 4 bits:**  
  Se utilizan solo 4 líneas, enviando cada byte en dos partes (más común en FPGA para ahorrar pines).

---

### Secuencia de inicialización

Para que el LCD funcione correctamente, es necesario ejecutar una secuencia específica de inicialización después de encender el sistema.

#### Pasos generales (modo 4 bits)

1. **Espera inicial:**  
   Se debe esperar al menos 15 ms después del encendido para garantizar estabilidad.

2. **Configuración inicial (forzar modo):**
   - Enviar `0x33`
   - Enviar `0x32`  
   Esto asegura que el LCD entre en modo de 4 bits.

3. **Función del display (Function Set):**
   - `0x28` → modo 4 bits, 2 líneas, fuente 5x8

4. **Control del display:**
   - `0x0C` → display encendido, cursor apagado

5. **Modo de entrada:**
   - `0x06` → incremento automático del cursor

6. **Limpiar pantalla:**
   - `0x01` → borra el display y posiciona el cursor en el inicio

---

### Escritura de datos

Para escribir un carácter:

1. RS = 1 (dato)
2. RW = 0 (escritura)
3. Colocar el dato en el bus
4. Generar pulso en E

Para enviar un comando:

1. RS = 0
2. RW = 0
3. Colocar el comando
4. Pulso en E

En modo de 4 bits, cada byte se envía en dos partes:
- primero los 4 bits más significativos
- luego los 4 bits menos significativos

---

### Consideraciones importantes

- Es necesario respetar los tiempos mínimos entre comandos (del orden de microsegundos a milisegundos).
- El comando `0x01` (clear display) requiere mayor tiempo de ejecución.
- En FPGA, normalmente se implementa una FSM para controlar la inicialización y escritura.

---

### Aplicación en el proyecto

En este proyecto, el LCD se utiliza para mostrar:

- La pregunta actual
- Las opciones de respuesta
- Información del estado del juego

El controlador del LCD debe encargarse de:

- Ejecutar la secuencia de inicialización
- Recibir datos desde la unidad de control
- Formatear y enviar los caracteres al display

Esto permite una interfaz visual clara para el jugador en la FPGA.



## Módulo de visualización: PmodCLP 

El PmodCLP es un módulo LCD de 16×2 caracteres que utiliza una interfaz paralela de 8 bits
para mostrar hasta 32 caracteres distintos de entre más de 200 opciones posibles. Utiliza un
controlador Samsung KS0066 para desplegar información en un panel Sunlike. El módulo puede
ejecutar instrucciones como borrar caracteres específicos, configurar diferentes modos de
visualización, desplazamiento y mostrar caracteres definidos por el usuario.

La comunicación con la tarjeta host se realiza mediante el protocolo GPIO. Este módulo requiere
temporizaciones específicas para programar el KS0066 correctamente.

---

### Características

- LCD 16×2 con interfaz paralela
- 192 caracteres predefinidos incluyendo 93 caracteres ASCII
- Hasta 8 caracteres definibles por el usuario
- Capacidad de lectura y escritura hacia y desde el display
- Sigue la especificación Digilent Pmod Interface Type 1
- Para la Rev. B, la alimentación VCC debe ser de **3.3V**

---

### Señales del conector 

| Conector | Pin | Señal | Descripción |
|----------|-----|-------|-------------|
| J1 - Top Half | 1 | DB0 | Data Bit 0 |
| J1 - Top Half | 2 | DB1 | Data Bit 1 |
| J1 - Top Half | 3 | DB2 | Data Bit 2 |
| J1 - Top Half | 4 | DB3 | Data Bit 3 |
| J1 - Top Half | 5 | GND | Power Supply Ground |
| J1 - Top Half | 6 | VCC | Positive Power Supply |
| J1 - Bottom Half | 7 | DB4 | Data Bit 4 |
| J1 - Bottom Half | 8 | DB5 | Data Bit 5 |
| J1 - Bottom Half | 9 | DB6 | Data Bit 6 |
| J1 - Bottom Half | 10 | DB7 | Data Bit 7 |
| J1 - Bottom Half | 11 | GND | Power Supply Ground |
| J1 - Bottom Half | 12 | VCC | Positive Power Supply |
| J2 | 1 | RS | Register Select: alto = transferencia de dato, bajo = transferencia de instrucción |
| J2 | 2 | R/W | Read/Write: alto = modo lectura, bajo = modo escritura |
| J2 | 3 | E | Read/Write Enable: alto = lectura habilitada; flanco de bajada escribe datos |
| J2 | 4 | NC | Habilitación de backlight (no conectado en el PmodCLP) |
| J2 | 5 | GND | Power Supply Ground |
| J2 | 6 | VCC | Positive Power Supply |

---

### Requerimientos de temporización 

Antes de enviar cualquier instrucción o dato, debe ejecutarse la siguiente secuencia de
inicialización (ver Figura 1 del Reference Manual):

| Paso | Acción | Espera mínima posterior |
|------|--------|------------------------|
| 1 | Power On | ≥ 20 ms |
| 2 | Function Set (bus 8-bit, 2 líneas, 5×8 dots) | ≥ 37 µs |
| 3 | Display On/Off Control | ≥ 37 µs |
| 4 | Clear Display | ≥ 1.52 ms |
| 5 | Entry Mode Set | Listo (OK) |

Para transferir datos al controlador, el pin E debe llevarse a '1' y luego a '0' al final de
la secuencia, con los 8 bits de datos (DB7–DB0) presentes en el bus.

---

### Códigos de instrucción 

| Instrucción | RS | R/W | DB7 | DB6 | DB5 | DB4 | DB3 | DB2 | DB1 | DB0 | Descripción |
|-------------|----|----|-----|-----|-----|-----|-----|-----|-----|-----|-------------|
| Clear Display | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | Escribe 20H en toda la DDRAM; pone dirección a 00H; cursor al inicio |
| Return Home | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | X | Cursor al inicio; contenido DDRAM no cambia |
| Entry Mode Set | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | I/D | SH | I/D='1': cursor se mueve a la derecha e incrementa dirección; SH='1': shift de display |
| Display On/Off Control | 0 | 0 | 0 | 0 | 0 | 0 | 1 | D | C | B | D=display, C=cursor, B=blink: activa o desactiva cada uno |
| Cursor or Display Shift | 0 | 0 | 0 | 0 | 0 | 1 | S/C | R/L | X | X | S/C='0': mueve cursor; S/C='1': desplaza display; R/L='1': hacia la derecha |
| Function Set | 0 | 0 | 0 | 0 | 1 | DL | N | F | X | X | DL='1': 8 bits; N='1': 2 líneas; F='0': fuente 5×8 |
| Set CGRAM Address | 0 | 0 | 0 | 1 | AC5 | AC4 | AC3 | AC2 | AC1 | AC0 | Establece contador de dirección CGRAM AC5–AC0 |
| Set DDRAM Address | 0 | 0 | 1 | AC6 | AC5 | AC4 | AC3 | AC2 | AC1 | AC0 | Establece contador de dirección DDRAM AC6–AC0 |
| Read Busy Flag/Address | 0 | 1 | BF | AC6 | AC5 | AC4 | AC3 | AC2 | AC1 | AC0 | Lee busy flag (BF) y contador de dirección AC6–AC0 |
| Write Data to RAM | 1 | 0 | D7 | D6 | D5 | D4 | D3 | D2 | D1 | D0 | Escribe dato en DDRAM o CGRAM según última dirección establecida |
| Read Data from RAM | 1 | 1 | D7 | D6 | D5 | D4 | D3 | D2 | D1 | D0 | Lee dato de DDRAM o CGRAM según última dirección establecida |

> **Nota:** "X" representa un bit don't care.

---

### CGRAM y DDRAM 

El controlador LCD contiene:
- **CGROM:** 192 patrones de caracteres 5×8 predefinidos
- **CGRAM:** hasta 8 caracteres 5×8 definibles por el usuario
- **DDRAM:** capacidad para 80 códigos de caracteres

Los códigos escritos en la DDRAM funcionan como índices hacia la CGROM (o CGRAM). Escribir
un código en una posición de DDRAM hace aparecer el carácter correspondiente en pantalla.

Mapeo de DDRAM a pantalla:
- **Fila 1:** posiciones 00H a 27H
- **Fila 2:** posiciones 40H a 67H

Normalmente 00H corresponde a la esquina superior izquierda ("home") y 40H a la esquina
inferior izquierda. El desplazamiento del display puede cambiar este mapeo.

El registro de direcciones se incrementa automáticamente tras cada operación de lectura o
escritura. El display utiliza códigos de caracteres ASCII: códigos hasta 7FH corresponden a
ASCII estándar; códigos superiores a 7FH producen caracteres internacionales.

Un busy flag indica si el display completó la última operación solicitada; debe verificarse
antes de iniciar una nueva operación.

---


## Protocolo UART

### Estructura de la trama

El protocolo UART  es un método de comunicación serial asíncrona que transmite los datos bit a bit sin señal de reloj compartida. Cada trama de datos está compuesta por:

- **Bit de inicio (Start):** 1 bit en nivel bajo (0) que indica el comienzo de la transmisión.
- **Bits de datos:** Generalmente 8 bits (configurable entre 5 y 9), enviados LSB primero.
- **Bit de paridad (opcional):** Permite detección básica de errores (par, impar o sin paridad).
- **Bit(es) de parada (Stop):** 1 o 2 bits en nivel alto (1) que indican el final de la trama.

Una configuración común es **8N1**: 8 bits de datos, sin paridad y 1 bit de parada.

---

#### Relación entre reloj y baud rate

El **baud rate** define la cantidad de bits transmitidos por segundo (por ejemplo, 9600 bps).  

En una FPGA, se parte de un reloj principal (`f_clk`) y se utiliza un divisor de frecuencia para generar el tiempo correspondiente a cada bit transmitido:

 #### Divisor f_clk / BaudRate


Por ejemplo, si `f_clk = 50 MHz` y `BaudRate = 9600`, el divisor será aproximadamente 5208 ciclos de reloj por bit.

---

### Consideraciones para transmisión y recepción confiable en FPGA

- El transmisor y receptor deben configurarse con el mismo baud rate.
- Es recomendable realizar **oversampling** (por ejemplo, 16x) en recepción para muestrear en el centro del bit.
- Detectar correctamente el flanco de bajada del bit de inicio.
- Validar el bit de paridad (si se usa) y el/los bit(s) de parada.
- Implementar la lógica mediante una **máquina de estados finitos (FSM)**.
- Utilizar sincronización de entrada (doble flip-flop) para evitar problemas de metastabilidad en la señal RX.


## Buenas prácticas para diseño de periféricos mapeados a memoria con buses de 32 bits.
#### Alineación y espacio de direcciones
Los registros de periféricos en procesadores son normalmente alineados a 32 bits, es decir, sus direcciones son múltiplos de 4. Esto es fundamental: en un espacio de direccionamiento byte-addressable de 32 bits, los accesos de lectura/escritura son de 4 bytes a la vez, por lo que las direcciones de registros de 32 bits deben ser múltiplos de cuatro. A estos se les llama offset addresses, y el periférico recibe una dirección base que lo identifica unívocamente en el bus.
#### Clasificación de registros por tipo de acceso
Los registros de control deben especificarse como solo-lectura, solo-escritura, o lectura-escritura, y deben leerse/escribirse en palabras de 32 bits alineadas a 4 bytes. La mayoría de los registros de control tienen múltiples campos que pueden modificarse independientemente mediante ciclos de lectura-modificación-escritura.
#### Uso de `volatile` y acceso directo
El caché puede interferir con las operaciones de I/O, ya que las escrituras a registros mapeados a memoria deben ser inmediatamente visibles al hardware. ARM provee mecanismos como barreras de memoria y mapeos no cacheados para garantizar que las operaciones de I/O no pasen por caché.
#### Estructura de registros recomendada
Antes de definir el espacio de registros, se deben especificar los requisitos de configurabilidad y accesibilidad en tiempo de ejecución del IP: habilitar/deshabilitar el periférico, configurar entradas, leer salidas, indicar si el periférico está ocupado, e indicar cuando la salida es válida.
#### Interrupciones y handshaking
Los registros mapeados a memoria se combinan frecuentemente con un mecanismo de interrupción: cuando el módulo de hardware completa una tarea, emite un interrupt request. Cuando el software atiende la interrupción, accede al hardware a través de los registros. Este mecanismo es estándar en UARTs, Timers y periféricos ADC.
#### Elección de bus estándar
APB de 32 bits es una interfaz de control interna simple y liviana, adecuada para acceder a registros de configuración con suficiente velocidad. AXI4-Lite es una alternativa más pesada pero más extensible para periféricos de mayor rendimiento. 

## Técnicas de arbitraje y sincronización para entradas de dos fuentes de respuesta concurrentes.
#### Problema central: metaestabilidad
Cuando dos fuentes asíncronas (en este caso J1 vía botones y J2 vía UART) activan señales simultáneamente, el árbitro puede entrar en estado metaestable. Aunque no es posible construir un árbitro que tome una decisión en tiempo fijo, sí es posible construir uno que ocasionalmente tome un poco más de tiempo en casos difíciles (llegadas simultáneas). La solución es usar un circuito de sincronización multietapa que detecte cuando el árbitro aún no ha alcanzado un estado estable y retrase el procesamiento hasta lograrlo.
#### Técnicas de arbitraje
Los métodos más comunes de arbitraje de bus son: prioridad fija centralizada (un árbitro central selecciona según prioridad estática); daisy chain serial (la señal de grant se propaga en cadena, y el primer dispositivo que la solicita la retiene); y round-robin (los masters se turnan en orden cíclico). Wikipedia
Para dos fuentes competidoras, las opciones prácticas son:

- *Prioridad fija:* J1 siempre gana si ambos responden en el mismo ciclo. Simple, determinístico, pero introduce sesgo.
- *Round-robin:* J1 y J2 se turnan la prioridad en cada ronda. Equitativo y libre de inanición.
- *Timestamp-based:* Gana quien registró primero su respuesta. Requiere comparar timestamps capturados con resolución de ciclo de reloj.

#### Sincronizador de doble flip-flop (2-FF)
Para señales de control de un solo bit provenientes de dominios asíncronos (como los botones de J1):
El sincronizador de dos flip-flops es la técnica CDC más básica para señales de un solo bit. El primer flip-flop captura la señal y el segundo garantiza que esté estable antes de usarla en el dominio destino, reduciendo la probabilidad de metaestabilidad a niveles cercanos a cero.
Restricciones importantes del 2-FF: se debe usar solo para señales de un bit; el reset debe ser sincrónico con el reloj destino; agrega un ciclo de latencia; y se pueden agregar más etapas para mayor confiabilidad a costa de más latencia.
#### Handshake para señales multi-bit
Para transferir datos de múltiples bits de forma segura (como la respuesta UART de J2):
En la técnica de handshake, el dominio fuente envía una señal de request al dominio destino a través de un sincronizador 2-FF. Una vez que el dominio destino recibe el request, responde con un ack que también pasa por un sincronizador 2-FF. El ack indica a la fuente que el destino recibió el valor y que el bus puede actualizarse.
#### FIFO asíncrono para flujos de datos
Para transferir flujos de datos entre dos relojes independientes, la mejor solución es un FIFO asíncrono con Block RAM de puertos duales con relojes de lectura y escritura independientes. Es el método estándar y robusto para transferencia de datos de alta tasa entre dominios de reloj.
#### Aplicación al proyecto (Reception FSM)

En el contexto del juego Jeopardy, el escenario relevante es: J1 y J2 responden dentro del mismo ciclo de reloj o en ciclos muy cercanos. La estrategia recomendada es:

1. Sincronizar ambas señales de llegada con sincronizadores 2-FF antes de ingresarlas al árbitro.
2. Capturar timestamps en el momento en que cada señal supera el sincronizador.
3. Comparar timestamps: si son iguales, aplicar la política de desempate documentada (prioridad fija o round-robin).
En el contexto del juego Jeopardy, el escenario relevante es: J1 y J2 responden dentro del mismo ciclo de reloj o en ciclos muy cercanos. La estrategia recomendada es:

1. Sincronizar ambas señales de llegada con sincronizadores 2-FF antes de ingresarlas al árbitro.
2. Capturar timestamps en el momento en que cada señal supera el sincronizador.
3. Comparar timestamps: si son iguales, aplicar la política de desempate documentada (prioridad fija o round-robin).

---


## Implementación en Vivado 


El sistema implementa un juego Jeopardy de dos jugadores sobre una FPGA Basys3. Un jugador
interactúa directamente con la tarjeta (botones físicos) y el otro lo hace desde una PC vía UART.
El diagrama muestra la interconexión de ocho bloques principales que comparten reloj y reset
provenientes de un PLL.

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/design/imagenes/diagramaN3.png
" width="800">

---

## 1. PLL

**Entradas:** `clk_in1`, `reset`

**Salidas:** `CLK_i` (reloj sintetizado, típicamente 16 MHz)

Genera el reloj interno del sistema a partir del oscilador de la tarjeta. Todos los demás
bloques operan síncronos con `CLK_i`. El reset de sistema también pasa a través de este
bloque para garantizar que el PLL esté bloqueado antes de liberar los demás módulos.

---

## 2. Seleccionador de Pregunta (question_picker)

**Entradas:** `CLK_i`, `rst`, `confirmar`, `load_seed`, `btn_pulse_i[2:0]`, `pregunta_usada`

**Salidas:** `consulta_sel[3:0]`, `pregunta_sel`, `solicitar` (o `solicitar_pregunta`), `q_valid`

Selecciona aleatoriamente una pregunta no usada del banco. Internamente contiene un LFSR
que genera un índice pseudoaleatorio. La señal `confirmar` y `load_seed` permiten cargar
una semilla inicial y confirmar la selección. La señal `pregunta_usada` (retroalimentada
desde la Memoria de Pregunta) indica qué preguntas ya fueron jugadas para evitar repetición.
Cuando encuentra una pregunta válida, activa `q_valid` y coloca el índice en `consulta_sel[3:0]`.

### Bloque: Máquina de Estados (FSM)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Controlar la secuencia de búsqueda de pregunta no usada |
| **Entradas** | `solicitar_i`, `confirmar_i`, `candidato_valido` |
| **Salidas** | `lfsr_en`, `q_valid_o`, `pregunta_sel_o` |
| **Explicación** | Estados: IDLE → SEARCHING → FOUND. En SEARCHING avanza LFSR hasta hallar candidato válido. |

### Bloque: LFSR (4 bits)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Generar números pseudoaleatorios entre 1 y 15 |
| **Entradas** | `clk_i`, `rst_i`, `en_i`, `seed_i`, `load_i` |
| **Salidas** | `q_o[3:0]` |
| **Explicación** | Registro de desplazamiento con realimentación XOR. Produce secuencia de 2⁴-1 valores. |

### Bloque: Comparador (rango + usado)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Verificar si el valor del LFSR es válido (1-10 y no usado) |
| **Entradas** | `lfsr_val[3:0]`, `pregunta_usada_i` |
| **Salidas** | `candidato_valido` |
| **Explicación** | Compara lfsr_val con 1 y 10, y AND con NOT usado. |

### Bloque: Restador

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Convertir rango 1-10 a 0-9 (índice de pregunta) |
| **Entradas** | `lfsr_val[3:0]` |
| **Salidas** | `pregunta_sel_o[3:0]` |
| **Explicación** | Resta 1 al valor del LFSR cuando es válido. |

---

## Cuarto Nivel – Módulo LFSR (4 bits)

###  Nombre del módulo
`lfsr`

###  Diagrama modular

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/SeleccionadorPreguntas_3Nivel.png?ref_type=heads" width="800">

###  Objetivo
Generar una secuencia pseudoaleatoria de 4 bits usando realimentación lineal.

###  Entradas
- `clk_i`: reloj
- `rst_i`: reset síncrono
- `en_i`: habilitación de avance
- `seed_i[3:0]`: semilla inicial
- `load_i`: carga paralela de semilla

###  Salidas
- `q_o[3:0]`: valor actual del LFSR

###  Relación con otros módulos
- Alimenta a la FSM y al comparador en `question_picker`
- Su salida determina el candidato a pregunta

###  Explicación de funcionamiento
En cada flanco de reloj, si `en_i=1` y no hay reset, el registro se desplaza a la derecha introduciendo un nuevo bit calculado como XOR de los taps. Si `load_i=1`, carga `seed_i`.

###  Diseño
**Polinomio de realimentación:** x⁴ + x³ + 1 (taps en bits 4 y 3, contando desde 1)

**Fórmula de realimentación:** `nuevo_bit = q3 ⊕ q2`

**Tabla de verdad del feedback (para 4 bits):**

| q3 | q2 | q1 | q0 | nuevo_bit |
|----|----|----|----|-----------|
| 0  | 0  | 0  | 0  | 0 (estado prohibido) |
| 0  | 0  | 0  | 1  | 0 |
| 0  | 0  | 1  | 0  | 0 |
| 0  | 0  | 1  | 1  | 0 |
| 0  | 1  | 0  | 0  | 1 |
| 0  | 1  | 0  | 1  | 1 |
| 0  | 1  | 1  | 0  | 1 |
| 0  | 1  | 1  | 1  | 1 |
| 1  | 0  | 0  | 0  | 1 |
| 1  | 0  | 0  | 1  | 1 |
| 1  | 0  | 1  | 0  | 1 |
| 1  | 0  | 1  | 1  | 1 |
| 1  | 1  | 0  | 0  | 0 |
| 1  | 1  | 0  | 1  | 0 |
| 1  | 1  | 1  | 0  | 0 |
| 1  | 1  | 1  | 1  | 0 |

**Simplificación:** `nuevo_bit = q3 ⊕ q2`

**Uso de módulos integrados:** No aplica (diseño con compuertas)

### i) Diagrama esquemático detallado

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/DEsqDetallado_SP.png?ref_type=heads" width="250">

---

## 3. Memoria de Pregunta (question_memory)

**Entradas:** `CLK_i`, `rst`, `consulta_sel[3:0]`, `next_char` (o `next_char_i`), `marcar_usada`

**Salidas:** `tipo`, `char[7:0]`, `fin_bloque`, `pregunta_usada`, `pregunta_sel[3:0]`

ROM de preguntas implementada como Block Memory Generator IP (Single Port ROM, 8 bits de
ancho, profundidad 1024). Almacena el banco de preguntas codificadas en ASCII. Al recibir
un índice por `consulta_sel`, expone los caracteres de la pregunta uno a uno a través de
`char[7:0]` conforme se reciben pulsos `next_char`. La señal `tipo` indica si el carácter
pertenece al enunciado o a las opciones. `fin_bloque` se activa al llegar al último carácter
del bloque actual. Cuando una ronda termina, `marcar_usada` activa el bit correspondiente
en el registro de preguntas usadas, y `pregunta_usada` retroalimenta al Seleccionador.

### Bloque: Generador de Dirección

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Calcular dirección lineal en ROM para cada carácter |
| **Entradas** | `pregunta_sel_i[3:0]` (0-9), `contador[6:0]` (0-64) |
| **Salidas** | `addr_final[9:0]` |
| **Explicación** | Dirección = (pregunta × 65) + contador. Cada pregunta ocupa 65 bytes |

### Bloque: ROM

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Almacenar las 10 preguntas (65 caracteres cada una) |
| **Entradas** | `clk_i`, `addr_final[9:0]` |
| **Salidas** | `char_o[7:0]` (carácter ASCII) |
| **Explicación** | IP de Block Memory Generator. 650 bytes total (10×65) |

### Bloque: Contador de Caracteres

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Llevar la posición actual dentro de la pregunta (0 a 64) |
| **Entradas** | `clk_i`, `rst_i`, `next_char_i` |
| **Salidas** | `contador[6:0]`, `fin_bloque_o` |
| **Explicación** | Incrementa con next_char_i. Al llegar a 64, vuelve a 0 y activa fin_bloque_o |

### Bloque: Decodificador de Tipo

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Clasificar región del carácter dentro de la pregunta |
| **Entradas** | `contador[6:0]` |
| **Salidas** | `tipo_o[1:0]` |
| **Explicación** | 0-31→tipo=00 (texto), 32-63→tipo=01 (opciones), 64→tipo=10 (fin) |

### Bloque: Registro de Preguntas Usadas

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Marcar qué preguntas ya fueron seleccionadas |
| **Entradas** | `clk_i`, `rst_i`, `marcar_usada`, `pregunta_sel_i[3:0]`, `consulta_sel_i[3:0]` |
| **Salidas** | `pregunta_usada_o` |
| **Explicación** | Array de 10 bits. Escritura en índice pregunta_sel_i cuando marcar_usada=1. Lectura en índice consulta_sel_i |

## Cuarto Nivel – Módulo Contador de Caracteres

### Nombre del módulo
`contador_caracteres` (parte de `question_memory`)

### Diagrama modular

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/MemoriaDePreguntas_3Nivel.png?ref_type=heads" width="430">

### Objetivo
Contar de 0 a 64 cíclicamente para recorrer los caracteres de una pregunta.

### Entradas
- `clk_i`: reloj
- `rst_i`: reset
- `next_char_i`: pulso de avance

### Salidas
- `contador[6:0]`: valor actual (0-64)
- `fin_bloque_o`: 1 cuando contador=64

### Relación con otros módulos
- Alimenta al generador de dirección ROM
- Alimenta al decodificador de tipo
- `fin_bloque_o` indica fin de pregunta al sistema superior

### Explicación de funcionamiento
En cada flanco de reloj, si `next_char_i=1` y no hay reset, el contador incrementa. Al llegar a 64, el siguiente incremento lo lleva a 0 (wrap). `fin_bloque_o` se activa cuando contador=64.

### Diseño

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/i_moduloDeco.png?ref_type=heads" width="300">

contador_next = (contador == 64) ? 0 : contador + 1
fin_bloque_o = (contador == 64)

**Justificación:** Se usa contador de 7 bits porque 65 valores requieren 7 bits (2⁷=128). El wrap es manual para que solo ocurra después de 64.

## Cuarto Nivel – Módulo Decodificador de Tipo

###  Nombre del módulo
`decodificador_tipo` (parte de `question_memory`)

###  Objetivo
Clasificar la posición del carácter en tres regiones.

###  Entradas
- `contador[6:0]`

###  Salidas
- `tipo_o[1:0]`

###  Relación con otros módulos
Recibe contador del contador de caracteres.

###  Explicación de funcionamiento
- Si contador ≤ 31 → tipo=00 (texto enunciado)
- Si contador ≤ 63 → tipo=01 (opciones)
- Si contador = 64 → tipo=10 (fin de bloque)

### h) Diseño

**Tabla de verdad:**

| Rango contador | condición                  | tipo_o[1] | tipo_o[0] |
|----------------|----------------------------|-----------|-----------|
| 0 a 31         | contador[6:5]=00           | 0         | 0         |
| 32 a 63        | contador[6:5]=01           | 0         | 1         |
| 64             | contador[6:0]=1000000      | 1         | 0         |

**Simplificación:**

tipo_o[1] = (contador == 64)
tipo_o[0] = (contador[6:5] == 2'b01)

**Uso de módulos integrados:** Comparadores

## Cuarto Nivel – Módulo Registro de Usadas

###  Nombre del módulo
`used_reg` (parte de `question_memory`)

###  Diagrama modular

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/i_ModuloRegistros.png?ref_type=heads" width="300">

###  Objetivo
Almacenar qué preguntas (0-9) ya fueron seleccionadas.

###  Entradas
- `clk_i`, `rst_i`
- `marcar_usada`: enable de escritura
- `pregunta_sel_i[3:0]`: índice de escritura
- `consulta_sel_i[3:0]`: índice de lectura

###  Salidas
- `pregunta_usada_o`: 1 si consulta_sel_i ya fue usada

###  Relación con otros módulos
- Escritura desde FSM del sistema cuando se confirma pregunta
- Lectura por el `question_picker` para verificar candidatos

###  Explicación de funcionamiento
Array de 10 flip-flops (bits). En cada ciclo, si `marcar_usada=1`, se escribe 1 en la posición `pregunta_sel_i`. Simultáneamente se lee la posición `consulta_sel_i` para salida.

###  Diseño

**Estructura:**

used_reg[9:0] // 10 bits

Escritura: used_reg[pregunta_sel_i] <= marcar_usada ? 1'b1 : used_reg[pregunta_sel_i]
Lectura: pregunta_usada_o = used_reg[consulta_sel_i]

**Justificación:** Solo se marcan usadas (nunca se desmarcan). Por eso no hay escritura de 0.

**Tabla de verdad (por bit individual):**

| marcar_usada | índice_match | Q_next |
|--------------|--------------|--------|
| 0            | X            | Q      |
| 1            | 0            | Q      |
| 1            | 1            | 1      |

**Simplificación:** Cada bit es un flip-flop D con enable condicional.

**Uso de módulos integrados:** No aplica

---



---

## 4. FSM (Unidad de Control)

**Entradas:** `btn_pulse[2:0]`, `q_valid`, `pregunta_sel[3:0]`, `solicitar`, confirmaciones UART,
             `fin_bloque`, `pregunta_usada`, `lcd_rdata[31:0]`

**Salidas:** `hex_data[15:0]`, `lcd_addr[1:0]`, `lcd_wdata[31:0]`, `lcd_writedata[31:0]`,
            `lcd_write_enable[31:0]`, `sound_correct`, `sound_pl`, `addr_i`, `wdata[31:0]`,
            `write_enable`, `marcar_usada`

Es el núcleo de decisión del sistema. Secuencia los estados del juego (espera de pregunta,
ventana de respuesta, evaluación, fin de partida), arbitra las respuestas concurrentes de
ambos jugadores, evalúa resultados y coordina todos los demás bloques. Genera las señales
de escritura hacia el módulo de Visualización (LCD) y el Output/Input Manager (7 segmentos),
así como las señales de sonido para el módulo SONIDO.

---

## 5. Periférico UART

**Entradas:** `addr_i`, `wdata[31:0]`, `write_enable`

**Salidas:** `vart_rdata[31:0]`, `RsTx`

Gestiona la comunicación serial con la PC del jugador 2. La FSM escribe en sus registros
internos (mapeados por `addr_i`) para enviar datos (pregunta, marcador, tiempo) y lee
`vart_rdata` para obtener la respuesta del jugador PC. La salida física `RsTx` va al conector
UART de la Basys3.

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/design/imagenes/UartP.jpeg" width="800">



## Entradas

| Señal | Descripción |
|---|---|
| `clk_i` | Reloj principal de 16 MHz. |
| `rst_i` | Reset síncrono. Lleva todos los registros internos a su estado inicial. |
| `write_enable_i` | Habilita la escritura desde la FSM en el ciclo actual. |
| `addr_i[1:0]` | Selecciona el registro interno al que se accede (ver mapa de registros). |
| `wdata_i[31:0]` | Dato de escritura proveniente de la FSM. Solo se usan los bits relevantes según el registro. |
| `RsRx` | Línea serial de recepción física (pin de la Basys3). Dato en serie proveniente de la PC. |

---

## Salidas

| Señal | Descripción |
|---|---|
| `rdata_o[31:0]` | Dato de lectura hacia la FSM. El contenido depende de `addr_i` (ver mapa de registros). |
| `RsTx` | Línea serial de transmisión física (pin de la Basys3). Dato en serie hacia la PC. |

---

## Mapa de registros

| `addr_i` | Registro | Escritura (`wdata_i`) | Lectura (`rdata_o`) |
|---|---|---|---|
| `2'b00` | CONTROL | `bit0 = 1` lanza la transmisión del byte en DATA TX; `bit1` escribe `reg_ctrl_new_rx` (permite limpiar la bandera de recepción) | `bit0 = tx_busy` (transmisión en curso); `bit1 = rx_available` (byte recibido pendiente de leer) |
| `2'b10` | DATO TX | `bits[7:0]` cargan el byte a transmitir en `reg_data_tx` | Lee el byte actualmente en el registro TX |
| `2'b11` | DATO RX | — (solo lectura) | `bits[7:0]` contienen el último byte recibido desde la PC |

---

## Relación con otros módulos

| Módulo | Relación |
|---|---|
| FSM (Unidad de Control) | Escribe en DATO TX el byte a enviar, luego pulsa el bit `send` en CONTROL para lanzar la transmisión. Sondea el bit `rx_available` en CONTROL para saber si llegó una respuesta del jugador PC y lee DATO RX para obtenerla. |
| Aplicación Python (PC) | Recibe los bytes transmitidos por `RsTx` (preguntas, marcador, tiempo) y envía las respuestas del jugador PC por `RsRx` a 115200 baudios. |

---

## Arquitectura interna

El módulo instancia el núcleo UART en VHDL (`UART`) y agrega encima una capa de registros
mapeados en SystemVerilog:

| Sub-bloque | Módulo | Función |
|---|---|---|
| Núcleo UART | `UART` (VHDL) | Contiene el transmisor (`UART_tx`) y el receptor (`UART_rx`) |
| Transmisor serie | `UART_tx` (VHDL) | FSM que serializa un byte a 115 200 baudios |
| Receptor serie | `UART_rx` (VHDL) | FSM que deserializa la trama entrante con sobremuestreo ×16 |
| Capa de registros | `uart_peripheral` (SV) | Expone los registros CONTROL, DATO TX y DATO RX a la FSM |

---



### `uart_peripheral`

##### Objetivo

Traducir el protocolo de bus de la FSM (dirección + dato + write_enable) a las señales de
control del núcleo UART (`tx_start`, `data_in`) y capturar los datos recibidos
(`data_out`, `rx_data_rdy`) en registros accesibles por la FSM.

##### Explicación de funcionamiento

El módulo mantiene cuatro registros internos: `reg_ctrl_send`, `reg_ctrl_new_rx`,
`reg_data_tx` y `reg_data_rx`. Su comportamiento en cada ciclo de reloj es el siguiente:

**Recepción con prioridad hardware.**
Si el núcleo UART señala `uart_rx_data_rdy`, el dato en `uart_data_out` se captura
inmediatamente en `reg_data_rx` y se activa la bandera `reg_ctrl_new_rx`. Esta lógica
tiene prioridad sobre cualquier escritura simultánea de la FSM, garantizando que ningún
byte recibido se pierda.

```systemverilog
if (uart_rx_data_rdy) begin
    reg_ctrl_new_rx <= 1'b1;
    reg_data_rx     <= uart_data_out;
end
```

**Auto-limpieza del bit `send`.**
Una vez que el transmisor termina (`uart_tx_rdy` sube), el bit `reg_ctrl_send` se baja
automáticamente sin intervención de la FSM, evitando que se reenvíe el mismo byte.

```systemverilog
if (reg_ctrl_send && uart_tx_rdy)
    reg_ctrl_send <= 1'b0;
```

**Escrituras de la FSM.**
Cuando `write_enable_i` está activo, `addr_i` selecciona el registro a modificar:
- `2'b00` (CONTROL): `wdata_i[0]` activa `reg_ctrl_send` para lanzar la transmisión;
  `wdata_i[1]` sobreescribe `reg_ctrl_new_rx` (permite a la FSM limpiar la bandera tras leer).
- `2'b10` (DATO TX): carga `wdata_i[7:0]` en `reg_data_tx`.
- `2'b11` es de solo lectura; las escrituras a esa dirección se ignoran.

**Lectura combinacional.**
`rdata_o` se forma de forma combinacional según `addr_i`, independientemente de
`write_enable_i`, de modo que la FSM puede leer en cualquier ciclo sin ciclos de espera.

---

### `UART_tx`

##### Objetivo

Serializar un byte de 8 bits según el protocolo UART 8N1 (8 bits de datos, sin paridad,
1 bit de parada) a 115 200 baudios, generando la trama completa en la línea `tx`.

##### Parámetros

| Parámetro | Valor | Descripción |
|---|---|---|
| `BAUD_CLK_TICKS` | 139 | Ciclos de reloj por bit: `16 000 000 / 115 200 ≈ 139` |

##### Explicación de funcionamiento

El módulo opera con cuatro procesos concurrentes en VHDL:

**Generador de reloj de baudios.**
Un contador decreciente libre genera un pulso `baud_rate_clk` cada 139 ciclos del reloj
principal. La FSM del transmisor avanza un estado por cada pulso de este reloj, lo que
hace que cada bit transmitido dure exactamente 1/115 200 s.

**Detector de inicio (`tx_start_detector`).**
Opera al ritmo del reloj principal (más rápido que el de baudios). Cuando detecta un
pulso en `tx_start`, captura inmediatamente el dato presente en `tx_data_in` dentro de
`stored_data` y activa `start_detected`. Esto asegura que el dato no cambie durante la
transmisión, aunque la FSM modifique el bus antes de que termine.

**Contador de índice de bit.**
Cuenta de 0 a 7 al ritmo del reloj de baudios. La FSM lo usa para indexar los bits de
`stored_data` uno a uno durante el estado DATA.

**FSM de transmisión (4 estados).**

| Estado | Acción |
|---|---|
| `IDLE` | Línea `tx` en alto (reposo). Espera `start_detected = 1`. |
| `START` | Emite el bit de inicio: `tx = 0` durante un período de baudios. Habilita el contador de índice. |
| `DATA` | Emite `stored_data[data_index]` en cada pulso de baudios. Cuando `data_index = 7`, pasa a STOP. |
| `STOP` | Emite el bit de parada: `tx = 1`. Activa `tx_end` y vuelve a IDLE. |

**Generación de `tx_rdy`.**
Un proceso adicional detecta el flanco ascendente de `tx_end` para generar un pulso de
un solo ciclo en `tx_rdy`, que la capa de registros usa para limpiar `reg_ctrl_send`.

---

### `UART_rx`

##### Objetivo

Detectar tramas UART entrantes en la línea `rx`, deserializar los 8 bits de datos y
entregar el byte reconstruido junto con un pulso de validez (`rx_data_rdy`).

##### Parámetros

| Parámetro | Valor | Descripción |
|---|---|---|
| `BAUD_X16_CLK_TICKS` | 9 | Ciclos por tick de sobremuestreo: `(16 000 000 / 115 200) / 16 ≈ 9` |

##### Explicación de funcionamiento

**Generador de reloj ×16.**
A diferencia del transmisor, el receptor trabaja a 16 veces la frecuencia de baudios
(16 × 115 200 = 1 843 200 Hz). Esto divide cada período de bit en 16 ventanas de
muestreo, lo que permite centrar el punto de captura en la mitad del bit para máxima
inmunidad al ruido.

**FSM de recepción (4 estados).**

| Estado | Acción |
|---|---|
| `IDLE` | Espera que `rx = 0` (bit de inicio). |
| `START` | Cuenta 8 ticks del reloj ×16 (medio período de bit) para confirmar que el bit de inicio es válido y no un glitch. Si `rx` vuelve a 1 antes, regresa a IDLE. |
| `DATA` | Cuenta 16 ticks por bit. Al llegar al tick 15 (punto medio del siguiente bit), muestrea `rx_data_in` y lo almacena en `rx_stored_data[bit_count]`. Repite 8 veces (bits 0 a 7). |
| `STOP` | Cuenta 16 ticks y espera el bit de parada. Al completarse, copia `rx_stored_data` a `rx_data_out` y activa `rx_end`. |

El muestreo en el tick 15 de cada período coloca el punto de captura en el centro del bit,
maximizando el margen frente a diferencias de baudios entre el transmisor y el receptor.

**Generación de `rx_data_rdy`.**
Dos procesos separados detectan el flanco ascendente de `rx_end` mediante un registro
`edge_signal`, generando un pulso de un ciclo en `rx_data_rdy` que la capa de registros
captura para actualizar `reg_data_rx` y activar `reg_ctrl_new_rx`.

---

## Funcionamiento del sistema en conjunto

Un ciclo completo de envío y recepción desde la perspectiva de la FSM es el siguiente:

**Transmisión (FSM → PC):**
1. La FSM escribe el byte a enviar en DATO TX (`addr = 2'b10`, `write_enable = 1`).
2. En el ciclo siguiente, escribe en CONTROL con `wdata[0] = 1` para activar `reg_ctrl_send`.
3. La capa de registros conecta `reg_ctrl_send` a `uart_tx_start`, y `UART_tx` comienza
   a serializar el byte almacenado en `stored_data`.
4. Cuando `UART_tx` termina, emite `tx_rdy`, y `reg_ctrl_send` se limpia automáticamente.
5. La FSM puede verificar que la transmisión terminó leyendo el bit `tx_busy` en CONTROL.

**Recepción (PC → FSM):**
1. La PC envía un byte por la línea `RsRx`. `UART_rx` detecta el bit de inicio y comienza
   a deserializar la trama.
2. Al completarse la recepción, `rx_data_rdy` pulsa durante un ciclo, lo que dispara la
   captura del byte en `reg_data_rx` y activa `reg_ctrl_new_rx`.
3. En su próximo ciclo de sondeo, la FSM lee CONTROL y detecta `bit1 = 1` (byte disponible).
4. La FSM lee DATO RX (`addr = 2'b11`) para obtener el byte recibido.
5. Opcionalmente, la FSM escribe en CONTROL con `wdata[1] = 0` para limpiar la bandera
   y quedar lista para la siguiente recepción.


<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/UARTN4.jpeg?ref_type=heads" width="900">

---

## 6. Output/Input Manager 

**Entradas:** `clk_i`, `rst`, `bit_async[2:0]`, `hex_data[15:0]` (o datos desde FSM vía bus interno)

**Salidas:** `an[3:0]`, `seg[6:0]`

Controla los cuatro displays de 7 segmentos de la Basys3 mediante multiplexación dinámica.
Recibe un dato hexadecimal de 16 bits y lo convierte en los códigos de segmento apropiados,
activando cada display en secuencia rápida. Muestra información como puntajes, tiempo
restante u otros indicadores del estado del juego.

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/design/imagenes/IOmanager.jpeg" width="800">

---


## Entradas

| Señal | Descripción |
|---|---|
| `clk_i` | Reloj principal de 16 MHz. Todas las operaciones internas son síncronas con esta señal. |
| `rst_i` | Reset síncrono. Lleva todos los sub-bloques a su estado inicial. |
| `btn_async_i[2:0]` | Señales crudas (asíncronas) de los tres botones físicos de la Basys3 (BTN_SEL, BTN_OK, BTN_SCR). |
| `hex_data_i[15:0]` | Dato hexadecimal de 16 bits a mostrar en los cuatro displays. Los 4 bits más significativos corresponden al dígito de la izquierda y los 4 menos significativos al de la derecha. |
| `buzz_en_i` | Habilita la generación de tono en el buzzer. Mientras esté en alto, el módulo PWM produce una señal activa. |
| `buzz_period_i[15:0]` | Define el período de la señal PWM en ciclos de reloj, determinando así la frecuencia del tono. |

---

## Salidas

| Señal | Descripción |
|---|---|
| `btn_pulse_o[2:0]` | Pulsos limpios de un ciclo de reloj, uno por cada botón, generados tras sincronización, antirrebote y detección de flanco ascendente. Se envían a la FSM. |
| `an_o[3:0]` | Señales de ánodo (activo en bajo) para el multiplexado de los cuatro displays de 7 segmentos. |
| `seg_o[6:0]` | Código de segmentos (activo en bajo) para el display activo en cada momento. |
| `buzzer_o` | Señal PWM de salida hacia el pin físico del buzzer. |

---

## Relación con otros módulos

| Módulo | Relación |
|---|---|
| FSM (Unidad de Control) | Consume `btn_pulse_o[2:0]` para detectar eventos de los jugadores. Suministra `hex_data_i`, `buzz_en_i` y `buzz_period_i` para controlar la visualización y el sonido. |
| Hardware físico (Basys3) | Recibe `btn_async_i[2:0]` directamente desde los pines del FPGA y conduce `an_o`, `seg_o` y `buzzer_o` hacia los periféricos de la tarjeta. |

---

## Arquitectura interna

El módulo instancia tres sub-bloques independientes, cada uno responsable de un periférico distinto:

| Sub-bloque | Módulo | Función |
|---|---|---|
| Antirrebote y detector de flancos | `button_debouncer` | Sincroniza, filtra rebotes y genera pulsos limpios de los botones |
| Display de 7 segmentos | `display_7seg` | Multiplexa y decodifica el dato hexadecimal en los cuatro dígitos |
| Generador PWM para buzzer | `pwm_buzzer` | Produce la señal de tono con frecuencia configurable |

---


### `button_debouncer`

##### Objetivo

Recibir las señales asíncronas y ruidosas de los botones físicos y producir, por cada uno, un pulso limpio de exactamente un ciclo de reloj en el flanco de subida del evento.

##### Entradas

| Señal | Descripción |
|---|---|
| `clk_i` | Reloj de 16 MHz |
| `rst_i` | Reset síncrono |
| `btn_async_i[WIDTH-1:0]` | Señales crudas de los botones. El parámetro `WIDTH` vale 3 en la instancia del top. |

##### Salidas

| Señal | Descripción |
|---|---|
| `btn_pulse_o[WIDTH-1:0]` | Un pulso de un ciclo por cada botón, generado al confirmar un flanco ascendente estable. |

##### Explicación de funcionamiento

El módulo aplica tres etapas en secuencia, todas registradas en el mismo `always_ff`:

**Etapa 1 — Sincronización (doble flip-flop).**
Las señales de botón provienen del mundo asíncrono y pueden causar metaestabilidad si se muestrean directamente. Dos registros en cascada (`sync_1`, `sync_2`) resuelven esto: la probabilidad de que `sync_2` quede metaestable es despreciable.

```
btn_async_i → [FF] sync_1 → [FF] sync_2
```

**Etapa 2 — Antirrebote por contador.**
Cuando `sync_2` difiere del valor estable aceptado (`stable`), se incrementa un contador de 18 bits. Si el valor se mantiene diferente durante `DEBOUNCE_MAX = 160 000` ciclos (equivalente a 10 ms a 16 MHz), el cambio se acepta y `stable` se actualiza. Si en cualquier momento `sync_2` vuelve a coincidir con `stable` (rebote), el contador se reinicia a cero. Esto garantiza que solo los cambios sostenidos durante al menos 10 ms se propaguen.

```systemverilog
localparam DEBOUNCE_MAX = 18'd160_000; // 10 ms @ 16 MHz

if (sync_2 == stable) begin
    count <= '0;
end else begin
    count <= count + 1'b1;
    if (count >= DEBOUNCE_MAX) begin
        stable <= sync_2;
        count  <= '0;
    end
end
```

**Etapa 3 — Detección de flanco ascendente.**
Un registro adicional (`stable_reg`) almacena el valor de `stable` del ciclo anterior. La operación AND entre el valor actual y la negación del anterior produce un pulso de exactamente un ciclo cada vez que `stable` pasa de 0 a 1.

```systemverilog
stable_reg <= stable;
// ...
assign btn_pulse_o = stable & ~stable_reg;
```

---

### `display_7seg`

##### Objetivo

Mostrar en los cuatro displays de 7 segmentos de la Basys3 el valor hexadecimal de 16 bits recibido, mediante multiplexación dinámica a alta frecuencia para que el ojo humano perciba los cuatro dígitos simultáneamente.

##### Entradas

| Señal | Descripción |
|---|---|
| `clk_i` | Reloj de 16 MHz |
| `rst_i` | Reset síncrono |
| `hex_data_i[15:0]` | Cuatro dígitos hexadecimales empaquetados: `[15:12]` es el más significativo (izquierda) y `[3:0]` el menos significativo (derecha). |

##### Salidas

| Señal | Descripción |
|---|---|
| `an_o[3:0]` | Selección de ánodo activo (activo en bajo). Solo un bit vale `0` en cada momento. |
| `seg_o[6:0]` | Código de segmentos del dígito activo (activo en bajo). |

##### Explicación de funcionamiento

El módulo se divide en tres bloques combinacionales/secuenciales:

**Contador de refresco.**
Un contador de 17 bits libre (`refresh_cnt`) se incrementa en cada ciclo de reloj. Los bits `[14:13]` generan una señal de selección de 2 bits que cambia a una frecuencia de:

```
f_sel = 16 MHz / 2^15 ≈ 488 Hz
```

Esto significa que cada display se refresca aproximadamente cada 2 ms, y el ciclo completo de los cuatro dígitos ocurre a ~122 Hz, suficiente para eliminar el parpadeo visible.

**Selector de ánodo y dígito.**
Según el valor de `refresh_cnt[14:13]`, se activa un ánodo y se selecciona el nibble correspondiente de `hex_data_i`:

| `refresh_cnt[14:13]` | Ánodo activo (`an_o`) | Nibble mostrado |
|---|---|---|
| `2'b00` | `4'b1110` (display 0, derecha) | `hex_data_i[3:0]` |
| `2'b01` | `4'b1101` (display 1) | `hex_data_i[7:4]` |
| `2'b10` | `4'b1011` (display 2) | `hex_data_i[11:8]` |
| `2'b11` | `4'b0111` (display 3, izquierda) | `hex_data_i[15:12]` |

**Decodificador hexadecimal a 7 segmentos.**
Una tabla `case` convierte el nibble de 4 bits seleccionado en el patrón de 7 segmentos correspondiente (activo en bajo). Cubre todos los dígitos del `0` al `F`:

```systemverilog
case (digit)
    4'h0: seg_o = 7'b1000000;
    4'h1: seg_o = 7'b1111001;
    // ...
    4'hF: seg_o = 7'b0001110;
    default: seg_o = 7'b1111111; // Apagado
endcase
```

---

### `pwm_buzzer`

##### Objetivo

Generar una señal PWM con frecuencia configurable en tiempo real para producir tonos audibles en el buzzer piezoeléctrico de la Basys3, con activación y desactivación controladas externamente.

##### Entradas

| Señal | Descripción |
|---|---|
| `clk_i` | Reloj de 16 MHz |
| `rst_i` | Reset síncrono |
| `en_i` | Habilita la generación de la señal PWM. En bajo, la salida se fuerza a cero. |
| `period_i[15:0]` | Semiperíodo de la señal PWM en ciclos de reloj. La frecuencia resultante es `f = 16 MHz / (2 × period_i)`. |

##### Salidas

| Señal | Descripción |
|---|---|
| `pwm_o` | Señal PWM de ciclo de trabajo del 50% hacia el pin del buzzer. |

##### Explicación de funcionamiento

El módulo implementa un oscilador de ciclo de trabajo fijo del 50% basado en un contador y un registro de salida que se invierte cada vez que el contador alcanza `period_i`:

```systemverilog
if (en_i) begin
    if (count >= period_i) begin
        count   <= '0;
        pwm_reg <= ~pwm_reg; // Invierte la salida → genera el tono
    end else begin
        count <= count + 1'b1;
    end
end else begin
    count   <= '0;
    pwm_reg <= 1'b0; // Silencio cuando no está habilitado
end
```

Cada vez que `count` llega a `period_i`, se reinicia y se invierte `pwm_reg`. El período completo de la onda cuadrada resultante es `2 × period_i` ciclos de reloj. Para obtener una frecuencia `f` deseada:

```
period_i = 16 000 000 / (2 × f)
```

Por ejemplo, para 1 kHz: `period_i = 8 000`. Para 500 Hz: `period_i = 16 000`.

Cuando `en_i` cae a cero, el contador y la salida se reinician inmediatamente, garantizando que el buzzer quede en silencio sin producir pulsos incompletos.

---

## Funcionamiento del sistema en conjunto

Ante cada flanco de reloj, los tres sub-bloques operan en paralelo de forma independiente:

1. `button_debouncer` monitorea continuamente los tres botones. Cuando detecta que uno ha permanecido presionado más de 10 ms, emite un pulso de un ciclo por `btn_pulse_o` hacia la FSM, que lo consume para avanzar su estado.

2. `display_7seg` mantiene el ciclo de multiplexado de forma autónoma. La FSM actualiza `hex_data_i` cuando el marcador o el tiempo cambian; el módulo de display toma el nuevo valor y lo muestra en el siguiente ciclo de refresco sin necesidad de handshake.

3. `pwm_buzzer` genera tono mientras la FSM mantenga `buzz_en_i` en alto, con la frecuencia indicada por `buzz_period_i`. La FSM decide cuándo activar el buzzer y con qué tono según el resultado de la ronda.

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/IOmanagerN4.jpeg?ref_type=heads" width="820">


---

## 7. SONIDO

**Entradas:** `sound_correct`, `sound_pl` (desde FSM), `CLK_i`, `rst`

**Salidas:** `speaker`

Genera tonos de audio mediante PWM hacia el buzzer (piezoeléctrico) de la Basys3. Produce
una señal sonora diferente según si la respuesta fue correcta (`sound_correct`) o si
simplemente hay un evento de juego (`sound_pl`). El pin `speaker` conecta directamente
al conector JA1

---

## 8. Visualización

**Entradas:** Bus de datos de la FSM (`lcd_addr[1:0]`, `lcd_wdata[31:0]`, `lcd_write_enable`,
             `lcd_writedata[31:0]`), `CLK_i`, `rst`

**Salidas:** `lcd_data[7:0]`, `lcd_en`, `lcd_rs`, `lcd_rw`, `lcd_rdata[31:0]`

Controla el LCD PmodCLP (16x2 caracteres) para mostrar las preguntas, opciones de respuesta,
marcador y otros estados del juego al jugador FPGA. La FSM lo trata como un periférico
mapeado a registros: escribe datos y comandos por el bus de escritura, y lee el estado de
ocupado (`busy`) por `lcd_rdata`. Internamente contiene su propia FSM de control del
protocolo LCD (Enable, RS, RW), un búfer de caracteres y lógica de refresco.

### Bloque: Registros de Configuración (LCD)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Almacenar comandos y datos escritos por el CPU |
| **Entradas** | `write_enable_i`, `addr_i`, `wdata_i` |
| **Salidas** | `reg_start`, `reg_rs`, `reg_clear`, `reg_home`, `reg_data` |
| **Explicación** | En addr=00 escribe CONTROL, addr=01 escribe DATOS. Auto-limpiadores |

### Bloque: FSM LCD

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Generar la secuencia de pulsos y temporizaciones del LCD |
| **Entradas** | `reg_start/clear/home`, `delay_cnt_reg` |
| **Salidas** | `lcd_rs_reg`, `lcd_en_reg`, `lcd_data_reg`, `flag_busy` |
| **Explicación** | Estados: IDLE→SETUP→ENABLE_HIGH→ENABLE_LOW→WAIT_CMD→IDLE |

### Bloque: Contador de Delays (LCD)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Generar esperas de 10, 40, 800 y 30000 ciclos |
| **Entradas** | `clk_i`, `rst_i`, `delay_cnt_next` |
| **Salidas** | `delay_cnt_reg`, `flag zero` |
| **Explicación** | Cuenta descendente desde valor cargado hasta 0 |

### Bloque: Display 7 Segmentos

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Mostrar 4 dígitos hexadecimales en display multiplexado |
| **Entradas** | `clk_i`, `rst_i`, `hex_data_i[15:0]` |
| **Salidas** | `seg_o[6:0]` (7 segmentos), `an_o[3:0]` (ánodos) |
| **Explicación** | Barrido a ~1kHz, decodifica cada dígito a 7 segmentos |

### Bloque: Contador de Refresco (7seg)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Generar la base de tiempo para multiplexar 4 dígitos |
| **Entradas** | `clk_i`, `rst_i` |
| **Salidas** | `refresh_cnt[16:0]` |
| **Explicación** | Cuenta continua de 17 bits. Bits[14:13] seleccionan dígito |

### Bloque: Selector de Dígito (MUX 4:1)

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Elegir qué nibble de hex_data_i se muestra |
| **Entradas** | `refresh_cnt[14:13]`, `hex_data_i[15:0]` |
| **Salidas** | `digit[3:0]` |
| **Explicación** | 00→nibble0, 01→nibble1, 10→nibble2, 11→nibble3 |

### Bloque: Decodificador 7 Segmentos

| Elemento | Descripción |
|----------|-------------|
| **Objetivo** | Convertir hex a patrón de segmentos (ánodo común) |
| **Entradas** | `digit[3:0]` |
| **Salidas** | `seg_o[6:0]` |
| **Explicación** | Tabla LUT: 0→1000000, 1→1111001, ... F→0001110 |

---

## Cuarto Nivel – Módulo FSM LCD (detallado)

###  Nombre del módulo
`lcd_peripheral` (submódulo: FSM interna)

###  Diagrama modular

<img src="https://gitlab.com/grupo0003/jeopardy/-/raw/main/Imagenes%20Finales/Visualizacion_3Nivel.png?ref_type=heads" width="820">

###  Objetivo
Generar la secuencia exacta de pulsos Enable y tiempos de espera para inicializar/enviar datos al LCD HD44780.

###  Entradas
- `clk_i`, `rst_i`
- `reg_start`, `reg_clear`, `reg_home`, `reg_rs`, `reg_data`
- `delay_cnt_reg`

###  Salidas
- `lcd_rs_next`, `lcd_en_next`, `lcd_data_next`
- `flag_busy`
- `state_next`, `delay_cnt_next`

###  Relación con otros módulos
- Recibe comandos desde los registros de configuración
- Controla las salidas físicas del LCD
- Comunica estado `busy` al bus de lectura

###  Explicación de funcionamiento
La FSM espera en IDLE. Al detectar `reg_start`, `reg_clear` o `reg_home`, configura RS y DATA, carga delay 10 ciclos, pasa a SETUP. Luego genera pulso ENABLE (40 ciclos alto, 10 bajo). Finalmente espera 800 ciclos (comando normal) o 30000 ciclos (clear/home).

###  Diseño

**Tabla de tiempos:**

| Estado | Duración (ciclos) | Acción |
|--------|-------------------|--------|
| IDLE   | ∞                 | Espera comando |
| SETUP  | 10                | Establece RS/DATA |
| ENABLE_HIGH | 40         | E=1 |
| ENABLE_LOW  | 10         | E=0 |
| WAIT_CMD | 800 o 30000      | Espera ejecución LCD |

**Justificación:** Basado en datasheet HD44780: setup time ≥40ns, enable pulse ≥230ns, wait command ≥37µs (clear/home ≥1.52ms). Con reloj de 50MHz (20ns ciclo), los valores son conservadores.

## Cuarto Nivel – Módulo Decodificador 7 Segmentos

###  Nombre del módulo
`decodificador_7seg` (parte de `display_7seg`)

###  Objetivo
Convertir un nibble hexadecimal en patrón de 7 segmentos (ánodo común activo bajo).

###  Entradas
- `digit[3:0]`

###  Salidas
- `seg_o[6:0]` (orden: a,b,c,d,e,f,g)

###  Relación con otros módulos
Recibe el dígito del selector MUX 4:1. Entrega seg_o al display.

###  Explicación de funcionamiento
Mediante tabla de verdad mapea cada valor 0-F a 7 bits. Los segmentos se activan con '0' porque es ánodo común.

###  Diseño

**Tabla de verdad del decodificador 7 segmentos (ánodo común, active low):**

| Dígito | d3 d2 d1 d0 | seg_a | seg_b | seg_c | seg_d | seg_e | seg_f | seg_g | Salida (gfedcba) |
|--------|-------------|-------|-------|-------|-------|-------|-------|-------|------------------|
| 0      | 0 0 0 0     | 0     | 0     | 0     | 0     | 0     | 0     | 1     | 1000000 |
| 1      | 0 0 0 1     | 1     | 1     | 1     | 1     | 0     | 0     | 1     | 1111001 |
| 2      | 0 0 1 0     | 0     | 0     | 1     | 0     | 0     | 1     | 0     | 0100100 |
| 3      | 0 0 1 1     | 0     | 0     | 0     | 0     | 1     | 1     | 0     | 0110000 |
| 4      | 0 1 0 0     | 1     | 0     | 0     | 1     | 1     | 0     | 0     | 0011001 |
| 5      | 0 1 0 1     | 0     | 1     | 0     | 0     | 1     | 0     | 0     | 0010010 |
| 6      | 0 1 1 0     | 0     | 1     | 0     | 0     | 0     | 0     | 0     | 0000010 |
| 7      | 0 1 1 1     | 0     | 0     | 0     | 1     | 1     | 1     | 1     | 1111000 |
| 8      | 1 0 0 0     | 0     | 0     | 0     | 0     | 0     | 0     | 0     | 0000000 |
| 9      | 1 0 0 1     | 0     | 0     | 0     | 0     | 1     | 0     | 0     | 0010000 |
| A      | 1 0 1 0     | 0     | 0     | 0     | 1     | 0     | 0     | 0     | 0001000 |
| b      | 1 0 1 1     | 1     | 0     | 0     | 0     | 0     | 0     | 1     | 1000011 |
| C      | 1 1 0 0     | 0     | 1     | 1     | 0     | 0     | 0     | 1     | 1000110 |
| d      | 1 1 0 1     | 1     | 0     | 0     | 0     | 0     | 1     | 0     | 0100001 |
| E      | 1 1 1 0     | 0     | 1     | 1     | 0     | 0     | 0     | 0     | 0000110 |
| F      | 1 1 1 1     | 0     | 1     | 1     | 1     | 0     | 0     | 0     | 0001110 |

**Nota:** 
- `0` = segmento encendido (activo bajo, ánodo común)
- `1` = segmento apagado
- Orden de salida `seg_o[6:0]` = {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a}
- Los valores coinciden con el código proporcionado en el módulo `display_7seg`


---

## Flujo general del sistema

1. El PLL estabiliza el reloj y libera el reset.
2. La FSM solicita una nueva pregunta al Seleccionador (`solicitar`).
3. El Seleccionador usa el LFSR para elegir un índice libre y activa `q_valid`.
4. La FSM comienza a leer caracteres de la Memoria de Pregunta (`next_char`) y los
   escribe en el módulo de Visualización para mostrarlos en el LCD.
5. Simultáneamente, envía la pregunta al jugador PC por UART.
6. Se abre la ventana de respuesta: ambos jugadores pueden confirmar (botones físicos o UART).
7. La FSM arbitra quién respondió primero y evalúa si la respuesta es correcta.
8. Se actualiza el marcador en los 7 segmentos, se activa la señal de sonido apropiada,
   y se marca la pregunta como usada en la Memoria.
9. Tras 7 rondas, la FSM entra al estado de fin de partida y muestra el ganador.

