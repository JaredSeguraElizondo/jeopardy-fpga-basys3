"""
txt_to_coe.py
Convierte questions.txt al formato .coe para IP Catalog ROM de Vivado.

Layout por pregunta (89 bytes):
  Offset  0-31  : Enunciado     (32 chars, relleno con espacios)
  Offset 32-45  : Opción A      (14 chars, relleno con espacios)
  Offset 46-59  : Opción B      (14 chars, relleno con espacios)
  Offset 60-73  : Opción C      (14 chars, relleno con espacios)
  Offset 74-87  : Opción D      (14 chars, relleno con espacios)
  Offset 88     : Respuesta correcta (ASCII: 'A', 'B', 'C' o 'D')

ROM total: 10 preguntas x 89 bytes = 890 palabras → depth 1024, width 8
Dirección base de pregunta n = n * 89
"""

import re
import sys

# ── Parámetros de layout ──────────────────────────────────────────────────────
Q_LEN   = 32   # caracteres del enunciado
OPT_LEN = 14   # caracteres por opción
BYTES_PER_Q = Q_LEN + 4 * OPT_LEN + 1   # 89
ROM_DEPTH = 1024
ROM_WIDTH = 8

INPUT_FILE  = "questions.txt"
OUTPUT_FILE = "questions.coe"

# ── Funciones de ayuda ────────────────────────────────────────────────────────

def pad_or_truncate(text: str, length: int) -> str:
    """Ajusta el texto a exactamente 'length' caracteres ASCII imprimibles."""
    text = text[:length]          # truncar si es necesario
    text = text.ljust(length)     # rellenar con espacios si es más corto
    return text


def parse_questions(filepath: str) -> list[dict]:
    """Lee el archivo .txt y devuelve una lista de dicts con Q/A/B/C/D/ANS."""
    questions = []
    current = {}

    with open(filepath, encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.rstrip("\n")

            # Ignorar comentarios y líneas vacías
            if line.startswith("#") or line.strip() == "":
                if current:
                    questions.append(current)
                    current = {}
                continue

            for key in ("Q", "A", "B", "C", "D", "ANS"):
                prefix = f"{key}:"
                if line.startswith(prefix):
                    current[key] = line[len(prefix):]
                    break

    if current:
        questions.append(current)

    return questions


def question_to_bytes(q: dict, idx: int) -> list[int]:
    """Convierte un dict de pregunta a lista de 89 bytes."""
    errors = []

    enunciado = pad_or_truncate(q.get("Q", ""), Q_LEN)
    opt_a     = pad_or_truncate(q.get("A", ""), OPT_LEN)
    opt_b     = pad_or_truncate(q.get("B", ""), OPT_LEN)
    opt_c     = pad_or_truncate(q.get("C", ""), OPT_LEN)
    opt_d     = pad_or_truncate(q.get("D", ""), OPT_LEN)
    ans       = q.get("ANS", "").strip().upper()

    if ans not in ("A", "B", "C", "D"):
        errors.append(f"Pregunta {idx+1}: ANS inválida '{ans}'")

    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(1)

    data = []
    for segment in (enunciado, opt_a, opt_b, opt_c, opt_d):
        for ch in segment:
            code = ord(ch)
            if code > 127:
                print(f"[WARN] Pregunta {idx+1}: carácter no-ASCII '{ch}' → reemplazado por '?'")
                code = ord("?")
            data.append(code)

    data.append(ord(ans))   # byte 88: respuesta correcta
    assert len(data) == BYTES_PER_Q, f"Error interno: {len(data)} bytes en pregunta {idx+1}"
    return data


def write_coe(all_bytes: list[int], filepath: str):
    """Escribe el archivo .coe con depth=1024, width=8."""
    # Rellenar hasta ROM_DEPTH con ceros
    padded = all_bytes + [0] * (ROM_DEPTH - len(all_bytes))

    with open(filepath, "w", encoding="utf-8") as f:
        f.write("; Generado por txt_to_coe.py\n")
        f.write(f"; Layout: {BYTES_PER_Q} bytes/pregunta, 10 preguntas\n")
        f.write(f"; Direccion base de pregunta n = n * {BYTES_PER_Q}\n")
        f.write(";\n")
        f.write(f"memory_initialization_radix=16;\n")
        f.write(f"memory_initialization_vector=\n")

        for i, byte in enumerate(padded):
            separator = "," if i < ROM_DEPTH - 1 else ";"
            f.write(f"{byte:02X}{separator}\n")

    print(f"[OK] Archivo generado: {filepath}")
    print(f"     Palabras usadas : {len(all_bytes)} / {ROM_DEPTH}")
    print(f"     Palabras libres : {ROM_DEPTH - len(all_bytes)}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    questions = parse_questions(INPUT_FILE)

    if len(questions) != 10:
        print(f"[ERROR] Se esperaban 10 preguntas, se encontraron {len(questions)}", file=sys.stderr)
        sys.exit(1)

    print(f"[OK] {len(questions)} preguntas leídas")

    all_bytes = []
    for i, q in enumerate(questions):
        q_bytes = question_to_bytes(q, i)
        base_addr = i * BYTES_PER_Q
        ans_char = chr(q_bytes[88])
        print(f"  P{i+1:02d} → base addr 0x{base_addr:03X} ({base_addr:3d}) | ANS={ans_char} | '{q.get('Q','').strip()[:30]}'")
        all_bytes.extend(q_bytes)

    write_coe(all_bytes, OUTPUT_FILE)


if __name__ == "__main__":
    main()
