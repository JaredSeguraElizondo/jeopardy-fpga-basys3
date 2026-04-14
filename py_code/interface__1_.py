import customtkinter as ctk
import serial
import threading
import time
import os
import re
import winsound

ctk.set_appearance_mode("Light")
ctk.set_default_color_theme("green")

PUERTO_COM         = "COM11"
ARCHIVO_COE        = "questions.coe"
BYTES_POR_PREGUNTA = 65


def cargar_preguntas(archivo_coe: str):
    if not os.path.exists(archivo_coe):
        raise FileNotFoundError(f"No se encuentra {archivo_coe}")
    with open(archivo_coe, "r") as f:
        contenido = f.read()
    match = re.search(r"memory_initialization_vector=\s*\n(.*?);", contenido, re.DOTALL)
    if not match:
        raise ValueError("Formato COE invalido")
    hex_vals = re.findall(r"([0-9A-Fa-f]+),?", match.group(1))
    data     = bytes(int(h, 16) for h in hex_vals if h)
    n        = len(data) // BYTES_POR_PREGUNTA
    banco, respuestas = {}, {}
    for i in range(n):
        bloque    = data[i * BYTES_POR_PREGUNTA : (i + 1) * BYTES_POR_PREGUNTA]
        enunciado = bloque[0:32].decode("ascii", errors="ignore").strip()
        opc1      = bloque[32:48].decode("ascii", errors="ignore").rstrip()
        opc2      = bloque[48:64].decode("ascii", errors="ignore").rstrip()
        respuesta = bloque[64:65].decode("ascii", errors="ignore").strip()
        banco[str(i)]      = f"{enunciado}\n\n{opc1}\n{opc2}"
        respuestas[str(i)] = respuesta
    return banco, respuestas


def sonar_victoria():
    """Tono agudo de victoria en hilo separado para no bloquear UI."""
    def _play():
        winsound.Beep(1000, 150)
        winsound.Beep(1200, 150)
        winsound.Beep(1500, 300)
    threading.Thread(target=_play, daemon=True).start()


def sonar_derrota():
    """Tono grave de derrota en hilo separado para no bloquear UI."""
    def _play():
        winsound.Beep(400, 300)
        winsound.Beep(300, 400)
    threading.Thread(target=_play, daemon=True).start()


class JeopardyPC(ctk.CTk):

    C_BG      = "#FAF7F2"
    C_PRIMARY = "#E8D5B7"
    C_GREEN   = "#A8C3A6"
    C_ROSE    = "#D4A5A5"
    C_TEXT    = "#4A4A4A"

    def __init__(self):
        super().__init__()
        self.title("Jeopardy — Terminal PC")
        self.geometry("900x620")
        self.resizable(False, False)
        self.configure(fg_color=self.C_BG)

        self.respondido  = False
        self.serial_port = None

        self.banco, self.respuestas = cargar_preguntas(ARCHIVO_COE)

        self._build_ui()
        self._conectar_uart()

    def _build_ui(self):
        self.grid_columnconfigure((0, 1), weight=1)

        # Boton inicio
        ctk.CTkButton(
            self, text="start game",
            command=self._iniciar,
            font=("Georgia", 16, "bold"),
            fg_color=self.C_ROSE, hover_color="#C49494",
            text_color="white", corner_radius=25, height=44
        ).grid(row=0, column=0, columnspan=2, padx=80, pady=(24, 12), sticky="ew")

        # Caja de pregunta
        frame_q = ctk.CTkFrame(
            self, fg_color="white", corner_radius=18,
            border_width=1, border_color=self.C_PRIMARY
        )
        frame_q.grid(row=1, column=0, columnspan=2, padx=50, pady=8, sticky="ew")

        self.txt_pregunta = ctk.CTkTextbox(
            frame_q, height=175, width=720,
            font=("Courier", 17), corner_radius=14,
            fg_color="white", text_color=self.C_TEXT, border_spacing=18
        )
        self.txt_pregunta.pack(padx=16, pady=16)
        self._set_texto("Presiona start game para comenzar.")

        # Botones A B C D
        frame_opts = ctk.CTkFrame(self, fg_color="transparent")
        frame_opts.grid(row=2, column=0, columnspan=2, pady=18)
        frame_opts.grid_columnconfigure((0, 1), weight=1)

        self.buttons = {}
        for i, letra in enumerate(["A", "B", "C", "D"]):
            btn = ctk.CTkButton(
                frame_opts, text=f"  {letra}",
                command=lambda l=letra: self._responder(l),
                font=("Georgia", 20, "bold"),
                height=60, width=210,
                fg_color=self.C_PRIMARY, hover_color="#DDCEB0",
                text_color=self.C_TEXT, corner_radius=30,
                state="disabled"
            )
            btn.grid(row=i // 2, column=i % 2, padx=18, pady=10)
            self.buttons[letra] = btn

        # Status
        self.lbl_status = ctk.CTkLabel(
            self, text="status: desconectado",
            font=("Georgia", 12, "italic"), text_color=self.C_TEXT
        )
        self.lbl_status.grid(row=3, column=0, columnspan=2, pady=12)

    def _conectar_uart(self):
        try:
            self.serial_port = serial.Serial(PUERTO_COM, 115200, timeout=0.1)
            self.serial_port.setDTR(False)
            self.serial_port.setRTS(False)
            self.lbl_status.configure(
                text=f"status: conectado a {PUERTO_COM}", text_color=self.C_GREEN
            )
            threading.Thread(target=self._escuchar, daemon=True).start()
        except Exception as e:
            self.lbl_status.configure(
                text=f"status: error — {e}", text_color=self.C_ROSE
            )

    def _escuchar(self):
        while True:
            try:
                if self.serial_port and self.serial_port.in_waiting > 0:
                    raw = self.serial_port.read(self.serial_port.in_waiting)
                    for byte in raw:
                        ch = chr(byte)
                        if ch in self.banco:
                            self.after(10, self._mostrar_pregunta, ch)
                        elif ch == "W":
                            self.after(10, self._resultado, True)
                        elif ch == "F":
                            self.after(10, self._resultado, False)
            except Exception:
                pass
            time.sleep(0.05)

    def _iniciar(self):
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.write(b"3")
            self.lbl_status.configure(
                text="esperando pregunta...", text_color="#E5A800"
            )
        else:
            self.lbl_status.configure(
                text="sin conexion serial", text_color=self.C_ROSE
            )

    def _mostrar_pregunta(self, idx: str):
        if idx not in self.banco:
            return
        num = int(idx) + 1
        self._set_texto(f"pregunta {num}\n\n{self.banco[idx]}")
        self.respondido = False
        for btn in self.buttons.values():
            btn.configure(state="normal", fg_color=self.C_GREEN, text_color="white")
        self.lbl_status.configure(
            text=f"pregunta {num} activa", text_color="#E5A800"
        )

    def _responder(self, letra: str):
        if self.respondido or not (self.serial_port and self.serial_port.is_open):
            return
        self.respondido = True
        self.serial_port.write(letra.encode())
        for btn in self.buttons.values():
            btn.configure(state="disabled")
        self.buttons[letra].configure(fg_color=self.C_ROSE)
        self.lbl_status.configure(
            text=f"respuesta enviada: {letra}", text_color="#E5A800"
        )

    def _resultado(self, correcto: bool):
        self.txt_pregunta.configure(state="normal")
        if correcto:
            self.txt_pregunta.insert("end", "\n\n✅  correcto")
            self.lbl_status.configure(text="ronda terminada", text_color=self.C_GREEN)
            sonar_victoria()
        else:
            self.txt_pregunta.insert("end", "\n\n❌  incorrecto")
            self.lbl_status.configure(text="ronda terminada", text_color=self.C_ROSE)
            sonar_derrota()
        self.txt_pregunta.configure(state="disabled")

    def _set_texto(self, texto: str):
        self.txt_pregunta.configure(state="normal")
        self.txt_pregunta.delete("0.0", "end")
        self.txt_pregunta.insert("0.0", texto)
        self.txt_pregunta.configure(state="disabled")


if __name__ == "__main__":
    app = JeopardyPC()
    app.mainloop()
