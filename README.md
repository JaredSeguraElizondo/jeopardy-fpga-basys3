# Jeopardy! — FPGA Implementation (Basys3)

A two-player Jeopardy-style quiz game implemented in SystemVerilog and
deployed on a Digilent Basys3 FPGA board (Artix-7). One player interacts
directly with the board via physical buttons and a 16×2 LCD display, while
the second player connects remotely from a PC via UART. All game logic
resides entirely on the FPGA. Developed as part of the Digital Design
Workshop course (EL3313) at the Costa Rica Institute of Technology (TEC),
Semester I 2026.

## Overview

The system presents 7 rounds of questions selected pseudo-randomly from a
bank of 10. Both players can answer simultaneously; the system arbitrates
based on response timestamp. A 30-second timeout applies per round. Scores
are displayed on the 7-segment displays and the winner is announced at the
end of the game.

## Features

- Two simultaneous players: FPGA (buttons + LCD) and PC (Python app via UART)
- Pseudo-random question selection using a 4-bit LFSR with no repetition within a game
- Concurrent response arbitration with timestamp-based priority
- 30-second per-round timeout
- LCD PmodCLP (16×2) displaying questions, options, and game state
- 7-segment displays showing score and remaining time
- Audio feedback via buzzer (correct/incorrect tones)
- UART communication at 115200 baud with Python PC application
- Fully modular RTL architecture in SystemVerilog (plus VHDL UART core)
- Post-implementation timed simulations with self-checking testbenches

## Hardware

| Component | Details |
|-----------|---------|
| **Board** | Digilent Basys3 (Artix-7 FPGA) |
| **Clock** | 16 MHz (generated via PLL from onboard 100 MHz oscillator) |
| **Inputs** | 3 push buttons (BTN_SEL, BTN_OK, BTN_SCR), UART RX |
| **Outputs** | LCD PmodCLP (16×2), 4-digit 7-segment display, buzzer, UART TX |

## System Architecture

<img width="1477" height="802" alt="System block diagram" src="https://github.com/user-attachments/assets/060deb60-f1c1-45b0-85c5-248614622299" />

The system is composed of 8 main blocks sharing a common clock and reset
from a PLL:

| Module | Description |
|--------|-------------|
| `PLL` | Generates 16 MHz system clock from onboard 100 MHz oscillator |
| `question_picker` | LFSR-based pseudo-random question selector, avoids repetition |
| `question_memory` | Block RAM ROM storing 10 questions (65 bytes each) in ASCII |
| `FSM` | Main game controller — arbitrates responses, updates score, sequences all blocks |
| `uart_peripheral` | Register-mapped UART peripheral for bidirectional PC communication |
| `uc_hw_controller` | Button debouncer, 7-segment display multiplexer, PWM buzzer |
| `SONIDO` | PWM audio tone generator for correct/incorrect feedback |
| `Visualización` | LCD PmodCLP controller (HD44780-compatible) |

---

## Module Descriptions

### 1. PLL

Generates the internal 16 MHz system clock from the Basys3's 100 MHz
oscillator. All other modules operate synchronously with this clock. The
system reset is also gated through this block to ensure the PLL is locked
before releasing the rest of the design.

---

### 2. Question Picker (`question_picker`)

Selects a pseudo-random unused question from the bank each round.

#### Inputs

| Signal | Description |
|--------|-------------|
| `CLK_i` | System clock |
| `rst` | Synchronous reset |
| `confirmar` | Confirms selection |
| `load_seed` | Loads LFSR seed |
| `btn_pulse_i[2:0]` | Button pulses from Output Manager |
| `pregunta_usada` | Feedback from Question Memory indicating used questions |

#### Outputs

| Signal | Description |
|--------|-------------|
| `consulta_sel[3:0]` | Index being queried |
| `pregunta_sel[3:0]` | Selected question index (0–9) |
| `q_valid` | Pulses high for one cycle when a valid unused question is found |

#### Internal Architecture

| Sub-block | Description |
|-----------|-------------|
| Internal FSM | States: IDLE → SEARCHING → FOUND |
| LFSR (4-bit) | Feedback polynomial x⁴ + x³ + 1, generates values 1–15 |
| Range + Used Comparator | Validates candidate: must be in range 1–10 and unused |
| Subtractor | Converts range 1–10 to index 0–9 |

#### LFSR Feedback

nuevo_bit = q3 ⊕ q2

<img width="781" height="352" alt="LFSR feedback diagram" src="https://github.com/user-attachments/assets/2c046adb-ac6f-48f8-9606-aaf9a3a3d494" />

<img width="406" height="391" alt="LFSR schematic" src="https://github.com/user-attachments/assets/65449629-74bc-4996-97c8-5a61ad708be5" />

<img width="1366" height="768" alt="question_picker simulation" src="https://github.com/user-attachments/assets/f48249fd-83f4-48ae-be16-2363a4720e9f" />

---

### 3. Question Memory (`question_memory`)

ROM storing the 10 questions encoded in ASCII. Each question occupies 65
bytes: 32 bytes for the question text, 32 bytes for the 4 answer options,
and 1 end-of-block byte.

#### Inputs

| Signal | Description |
|--------|-------------|
| `CLK_i` | System clock |
| `rst` | Synchronous reset |
| `consulta_sel[3:0]` | Question index to query |
| `next_char` | Pulse to advance to the next character |
| `marcar_usada` | Marks current question as used |

#### Outputs

| Signal | Description |
|--------|-------------|
| `tipo[1:0]` | Character type: 00 = text, 01 = options, 10 = end of block |
| `char[7:0]` | Current ASCII character |
| `fin_bloque` | High when last character of block is reached |
| `pregunta_usada` | Indicates if queried question was already used |

#### Internal Architecture

| Sub-block | Description |
|-----------|-------------|
| Address Generator | Computes ROM address: (question × 65) + counter |
| Block RAM ROM | Single Port ROM IP, 8-bit wide, 1024 deep (650 bytes used) |
| Character Counter | 7-bit counter (0–64), wraps after 64 |
| Type Decoder | Classifies character position: 0–31 → text, 32–63 → options, 64 → end |
| Used Questions Register | 10-bit array marking which questions have been played |

<img width="659" height="625" alt="question_memory block diagram" src="https://github.com/user-attachments/assets/acaac426-f2ce-499b-94dc-5dfafd2be423" />

<img width="1366" height="768" alt="question_memory simulation — enunciado" src="https://github.com/user-attachments/assets/b3e2b0be-7c33-40b7-8a93-755955ab2321" />

<img width="1366" height="768" alt="question_memory simulation — opciones y fin de bloque" src="https://github.com/user-attachments/assets/bed28e26-7804-4a81-a8a0-9dc25095ef06" />

---

### 4. Main FSM (Game Control Unit)

The decision core of the system. Sequences all game states, arbitrates
concurrent responses from both players, evaluates answers, updates the
scoreboard, and coordinates all other blocks.

#### Inputs

| Signal | Description |
|--------|-------------|
| `btn_pulse[2:0]` | Button events from Output Manager |
| `q_valid` | Valid question available signal |
| `pregunta_sel[3:0]` | Selected question index |
| `solicitar` | Question request signal |
| `fin_bloque` | End of question block signal |
| `pregunta_usada` | Used question feedback |
| `lcd_rdata[31:0]` | LCD peripheral read data (busy flag) |
| UART confirmations | Response received from PC player |

#### Outputs

| Signal | Description |
|--------|-------------|
| `hex_data[15:0]` | Score and time data for 7-segment display |
| `lcd_addr[1:0]` | LCD peripheral register address |
| `lcd_wdata[31:0]` | LCD peripheral write data |
| `lcd_write_enable` | LCD peripheral write enable |
| `sound_correct` | Triggers correct answer tone |
| `sound_pl` | Triggers game event tone |
| `addr_i / wdata / write_enable` | UART peripheral bus signals |
| `marcar_usada` | Marks current question as used in memory |

#### Game Flow

1. FSM requests a question from `question_picker`
2. Reads characters from `question_memory` and writes them to the LCD
3. Simultaneously sends the question to the PC via UART
4. Opens the response window for both players
5. Arbitrates concurrent responses by timestamp
6. Evaluates correctness, updates score, triggers audio feedback
7. After 7 rounds, enters end-of-game state and announces winner

---

### 5. UART Peripheral (`uart_peripheral`)

Register-mapped UART peripheral for bidirectional communication with the
PC player at 115200 baud.

#### Standard Peripheral Interface

| Signal | Direction | Description |
|--------|-----------|-------------|
| `clk_i` | Input | 16 MHz system clock |
| `rst_i` | Input | Synchronous reset |
| `write_enable_i` | Input | Write enable from FSM |
| `addr_i[1:0]` | Input | Register address |
| `wdata_i[31:0]` | Input | Write data from FSM |
| `RsRx` | Input | Serial RX line from PC |
| `rdata_o[31:0]` | Output | Read data to FSM |
| `RsTx` | Output | Serial TX line to PC |

#### Register Map

| `addr_i` | Register | Write | Read |
|----------|----------|-------|------|
| `2'b00` | CONTROL | bit0 = send (launch TX); bit1 = clear RX flag | bit0 = tx_busy; bit1 = rx_available |
| `2'b10` | DATA TX | bits[7:0] = byte to transmit | Current TX register |
| `2'b11` | DATA RX | Read only | bits[7:0] = last received byte |

#### Internal Architecture

| Sub-block | Language | Function |
|-----------|----------|----------|
| `UART_tx` | VHDL | Serializes byte to 8N1 UART at 115200 baud |
| `UART_rx` | VHDL | Deserializes incoming frame with ×16 oversampling |
| `uart_peripheral` | SystemVerilog | Register layer exposing CONTROL, DATA TX, DATA RX |

**TX:** 139 clock cycles per bit — `16 000 000 / 115 200 ≈ 139`

**RX:** 9 clock cycles per ×16 sample tick; samples at center of each bit

<img width="1504" height="904" alt="UART peripheral architecture" src="https://github.com/user-attachments/assets/7598d651-a561-4bda-8af9-d7f3d01ee50b" />

---

### 6. Output/Input Manager (`uc_hw_controller`)

Handles all physical I/O: button debouncing, 7-segment display multiplexing,
and PWM buzzer generation.

#### Inputs

| Signal | Description |
|--------|-------------|
| `clk_i` | System clock (16 MHz) |
| `rst_i` | Synchronous reset |
| `btn_async_i[2:0]` | Raw asynchronous button signals (BTN_SEL, BTN_OK, BTN_SCR) |
| `hex_data_i[15:0]` | 16-bit hex value to display on the 7-segment displays |
| `buzz_en_i` | Buzzer enable |
| `buzz_period_i[15:0]` | PWM half-period in clock cycles |

#### Outputs

| Signal | Description |
|--------|-------------|
| `btn_pulse_o[2:0]` | Clean single-cycle button pulses to FSM |
| `an_o[3:0]` | 7-segment anode signals (active low) |
| `seg_o[6:0]` | 7-segment segment signals (active low) |
| `buzzer_o` | PWM output to buzzer pin |

#### Internal Architecture

| Sub-block | Module | Function |
|-----------|--------|----------|
| `button_debouncer` | SystemVerilog | 2-stage synchronizer + 10 ms debounce counter + rising-edge detector |
| `display_7seg` | SystemVerilog | 17-bit refresh counter, 4:1 MUX, hex-to-7seg decoder |
| `pwm_buzzer` | SystemVerilog | 50% duty cycle oscillator with configurable period |

**`button_debouncer`** — Two-stage synchronizer resolves metastability from asynchronous
inputs. An 18-bit counter (`DEBOUNCE_MAX = 160 000` cycles = 10 ms at 16 MHz) filters
glitches; a rising-edge detector produces a single-cycle pulse per confirmed press.

**`display_7seg`** — A 17-bit free-running counter drives a 4:1 MUX that selects one nibble
of `hex_data_i` every ~2 ms (~488 Hz per digit, ~122 Hz full cycle). A `case` table converts
each nibble to its active-low 7-segment pattern (0–F).

**`pwm_buzzer`** — A counter inverts the output register every `period_i` cycles, producing a
50% duty-cycle square wave. Frequency: `f = 16 MHz / (2 × period_i)`. Example: 1 kHz →
`period_i = 8 000`.

<img width="1465" height="735" alt="uc_hw_controller block diagram" src="https://github.com/user-attachments/assets/4237fe63-e234-4412-aceb-d3550dec91b8" />

---

### 7. Sound Module (`SONIDO`)

Generates audio feedback via PWM to the Basys3 buzzer. Produces distinct
tones for correct answers and game events.

#### Inputs

| Signal | Description |
|--------|-------------|
| `CLK_i` | System clock (16 MHz) |
| `rst` | Synchronous reset |
| `sound_correct` | Triggers correct-answer tone (from FSM) |
| `sound_pl` | Triggers game-event tone (from FSM) |

#### Outputs

| Signal | Description |
|--------|-------------|
| `speaker` | PWM output connected directly to connector JA1 |

#### Internal Architecture

| Sub-block | Description |
|-----------|-------------|
| Tone selector | Combinational MUX: selects PWM period based on `sound_correct` / `sound_pl` |
| PWM oscillator | 50% duty-cycle counter; inverts output every N cycles to produce the target frequency |
| Enable logic | Output forced low when neither `sound_correct` nor `sound_pl` is asserted |

The two input signals are mutually exclusive: `sound_correct` plays a higher-pitched tone
(correct answer) and `sound_pl` plays a lower-pitched tone (game events such as timeout or
wrong answer). The FSM asserts each signal for a fixed number of clock cycles to control
tone duration.

---

### 8. Visualization Module (`Visualización`)

Controls the PmodCLP LCD (16×2, HD44780-compatible) to display questions,
answer options, scores, and game status for the FPGA player.

#### Inputs

| Signal | Description |
|--------|-------------|
| `CLK_i` | System clock (16 MHz) |
| `rst` | Synchronous reset |
| `lcd_addr[1:0]` | Register address from FSM |
| `lcd_wdata[31:0]` | Write data from FSM |
| `lcd_write_enable` | Write enable |

#### Outputs

| Signal | Description |
|--------|-------------|
| `lcd_data[7:0]` | 8-bit parallel data bus to LCD |
| `lcd_en` | LCD Enable signal |
| `lcd_rs` | Register Select (0 = command, 1 = data) |
| `lcd_rw` | Read/Write (fixed to 0 = write) |
| `lcd_rdata[31:0]` | Read data to FSM (includes busy flag) |

#### LCD Register Map

| `addr_i` | Register | Description |
|----------|----------|-------------|
| `2'b00` | CONTROL | bit0 = start (W1P); bit1 = RS; bit2 = clear (W1P); bit3 = home (W1P); bit8 = busy (RO); bit9 = done (RO) |
| `2'b01` | DATA | bits[7:0] = ASCII byte or instruction code |

#### Internal Architecture

| Sub-block | Description |
|-----------|-------------|
| Config registers | Store FSM-written commands and data; auto-clear after one cycle |
| LCD FSM | Sequences Enable pulses and timing delays per HD44780 spec |
| Delay counter | Countdown timer generating 10, 40, 800, and 30 000-cycle waits |

#### LCD FSM States

| State | Duration (cycles) | Action |
|-------|-------------------|--------|
| IDLE | ∞ | Waits for command; `flag_busy = 0` |
| SETUP | 10 | Sets RS and DATA lines before raising Enable |
| ENABLE_HIGH | 40 | E = 1 (data captured by LCD on falling edge) |
| ENABLE_LOW | 10 | E = 0 |
| WAIT_CMD | 800 or 30 000 | Waits for LCD execution (30 000 for Clear/Home) |

LCD initialization follows the HD44780 power-on sequence: ≥20 ms delay,
Function Set (8-bit, 2 lines, 5×8 font), Display On, Clear Display, Entry Mode Set.

<img width="609" height="632" alt="Visualización block diagram" src="https://github.com/user-attachments/assets/89103601-2fed-481d-b8f2-9655389c2062" />

---

## PC Application (Python)

A Python application running on the PC acts as the interface for Player 2
via UART at 115200 baud. It displays the current question, options, score,
and remaining time; sends the player's answer (A/B/C/D); handles invalid
inputs; and plays audio feedback for correct/incorrect responses.

Located in: `py_code/`

---

## Project Structure

```
├── Banco_de_preguntas_y_Traductor/  # Question bank and .coe file translator
├── Imagenes Finales/                 # Simulation and architecture screenshots
├── SV_code/                          # SystemVerilog source files and testbenches
├── py_code/                          # Python PC application
└── README.md
```

## Tools

| Tool | Details |
|------|---------|
| **Languages** | SystemVerilog + VHDL (UART core) |
| **IDE** | Vivado 2025.2 |
| **Board** | Digilent Basys3 (Artix-7 FPGA) |
| **PC Interface** | Python 3 — UART at 115200 baud (8N1) |
| **Simulation** | Post-implementation timed simulations with self-checking testbenches |

## Team

Developed by Electronic Engineering students at the Costa Rica Institute of
Technology (TEC) as part of the Digital Design Workshop course (EL3313),
Semester I 2026.

| Name |
|------|
| Jared Segura Elizondo |
| Victoria Cerdas López |
| Galilea González Méndez |
| Felipe Sánchez Segura |
