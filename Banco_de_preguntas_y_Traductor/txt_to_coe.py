"""
txt_to_coe.py  —  Convierte banco de preguntas a formato .coe para ROM de Vivado
Formato de bloque por pregunta (65 bytes total):
  Bytes  0–31 : Enunciado  (32 chars, 2 filas LCD de 16 chars)
  Bytes 32–47 : Opciones fila 1  "A:XXXXX C:XXXXX"  (16 chars)
  Bytes 48–63 : Opciones fila 2  "B:XXXXX D:XXXXX"  (16 chars)
  Byte    64  : Respuesta correcta ('A', 'B', 'C' o 'D')

Formato del archivo fuente (.txt):
  Q##
  Enunciado de la pregunta
  A:XXXXX C:XXXXX
  B:XXXXX D:XXXXX
  X              <- letra correcta
  (linea en blanco)
"""

import sys

BLOCK_SIZE   = 65
ENUNCIADO_SZ = 32   # 2 filas × 16
OPCIONES_SZ  = 32   # 2 filas × 16
RESPUESTA_SZ = 1

def pad_or_truncate(s, length):
    """Ajusta el string a exactamente `length` bytes ASCII, rellenando con espacios."""
    s = s[:length]
    return s.ljust(length)

def parse_questions(filename):
    with open(filename, 'r', encoding='ascii', errors='replace') as f:
        content = f.read()

    questions = []
    blocks = [b.strip() for b in content.split('\n\n') if b.strip()]

    for block in blocks:
        lines = [l for l in block.split('\n') if l.strip() != '']
        # Esperar: Q##, enunciado, fila_opciones_1, fila_opciones_2, respuesta
        if len(lines) < 5:
            print(f"[WARN] Bloque incompleto ignorado: {lines}")
            continue

        q_id        = lines[0].strip()
        enunciado   = lines[1].strip()
        opciones_f1 = lines[2].strip()   # "A:XXXXX C:XXXXX"
        opciones_f2 = lines[3].strip()   # "B:XXXXX D:XXXXX"
        respuesta   = lines[4].strip()   # "A", "B", "C" o "D"

        if respuesta not in ('A', 'B', 'C', 'D'):
            print(f"[WARN] Respuesta invalida en {q_id}: '{respuesta}'")

        questions.append({
            'id':         q_id,
            'enunciado':  enunciado,
            'opciones_f1': opciones_f1,
            'opciones_f2': opciones_f2,
            'respuesta':  respuesta,
        })

    return questions

def build_block(q):
    """Construye un bloque de exactamente BLOCK_SIZE bytes."""
    enunciado_bytes = pad_or_truncate(q['enunciado'],   ENUNCIADO_SZ).encode('ascii')
    opcf1_bytes     = pad_or_truncate(q['opciones_f1'], 16).encode('ascii')
    opcf2_bytes     = pad_or_truncate(q['opciones_f2'], 16).encode('ascii')
    resp_bytes      = q['respuesta'].encode('ascii')

    block = enunciado_bytes + opcf1_bytes + opcf2_bytes + resp_bytes
    assert len(block) == BLOCK_SIZE, f"Bloque de tamano incorrecto: {len(block)}"
    return block

def to_coe(questions, output_file):
    total_depth = len(questions) * BLOCK_SIZE
    lines = []
    lines.append("memory_initialization_radix=16;")
    lines.append(f"memory_initialization_vector=")

    all_bytes = []
    for q in questions:
        block = build_block(q)
        all_bytes.extend(block)

    hex_vals = [f"{b:02X}" for b in all_bytes]
    # Ultimo elemento sin coma
    for i, h in enumerate(hex_vals):
        if i < len(hex_vals) - 1:
            lines.append(f"{h},")
        else:
            lines.append(f"{h};")

    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))

    print(f"[OK] {output_file} generado")
    print(f"     Preguntas : {len(questions)}")
    print(f"     Bytes/blq : {BLOCK_SIZE}")
    print(f"     ROM depth : {total_depth}  (configurar en Vivado IP)")

def validate_questions(questions):
    ok = True
    for q in questions:
        # Verificar largo de opciones
        if len(q['opciones_f1']) > 16:
            print(f"[ERR] {q['id']} opciones_f1 excede 16 chars: '{q['opciones_f1']}' ({len(q['opciones_f1'])})")
            ok = False
        if len(q['opciones_f2']) > 16:
            print(f"[ERR] {q['id']} opciones_f2 excede 16 chars: '{q['opciones_f2']}' ({len(q['opciones_f2'])})")
            ok = False
        if len(q['enunciado']) > 32:
            print(f"[WARN] {q['id']} enunciado excede 32 chars y sera truncado: '{q['enunciado']}' ({len(q['enunciado'])})")
        # Verificar ASCII puro
        for field in ('enunciado', 'opciones_f1', 'opciones_f2'):
            try:
                q[field].encode('ascii')
            except UnicodeEncodeError:
                print(f"[ERR] {q['id']} campo '{field}' contiene caracteres no-ASCII")
                ok = False
    return ok

if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else 'preguntas.txt'
    dst = sys.argv[2] if len(sys.argv) > 2 else 'preguntas.coe'

    questions = parse_questions(src)
    print(f"[INFO] {len(questions)} preguntas leidas de '{src}'")

    if not validate_questions(questions):
        print("[ABORT] Corregir errores antes de generar .coe")
        sys.exit(1)

    to_coe(questions, dst)
