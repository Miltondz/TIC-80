#!/usr/bin/env python3
"""
build_cart.py — ensambla el cartucho de TIC-80 a partir de src/ y assets/

Genera DOS artefactos equivalentes:
  * cumbre_santa_ana.tic  cartucho binario (lo carga cualquier TIC-80)
  * cumbre_santa_ana.lua  cartucho en formato texto (sección oficial de
                          TIC-80: código + secciones -- <TILES>, -- <PALETTE>)

Formato .tic (ver src/cart.c de TIC-80): una secuencia de chunks de 4
bytes de cabecera + datos:
    bits 0-4   tipo de chunk (1=TILES, 5=CODE, 12=PALETTE, ...)
    bits 5-7   banco (siempre 0 aquí)
    bits 8-23  tamaño en bytes (LE)
    bits 24-31 reservado

Formato de tiles: 8x8 píxeles a 4bpp = 32 bytes por tile. Cada byte
guarda 2 píxeles: el píxel IZQUIERDO en el nibble bajo. En el formato
texto cada píxel es un carácter hex y se leen en orden de lectura.
"""

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SRC = RAIZ / "src"
ARTE = RAIZ / "assets" / "arte.py"

METADATOS = """-- title: cumbre santa ana
-- author: miltondz
-- desc: una subida en familia por el cerro santa ana (paraguaná)
-- site: https://github.com/Miltondz/TIC-80
-- license: MIT
-- version: 1.0
-- script: lua"""

# paleta clásica de 16 colores (los mismos índices de la versión pico-8):
# el juego la usa tal cual; la grabamos en el cartucho en lugar de la
# paleta por defecto de tic-80 ("sweetie16").
PALETA = [
    (0x00, 0x00, 0x00), (0x1d, 0x2b, 0x53), (0x7e, 0x25, 0x53), (0x00, 0x87, 0x51),
    (0xab, 0x52, 0x36), (0x5f, 0x57, 0x4f), (0xc2, 0xc3, 0xc7), (0xff, 0xf1, 0xe8),
    (0xff, 0x00, 0x4d), (0xff, 0xa3, 0x00), (0xff, 0xec, 0x27), (0x00, 0xe4, 0x36),
    (0x29, 0xad, 0xff), (0x83, 0x76, 0x9c), (0xff, 0xcc, 0xaa), (0xff, 0x77, 0xa8),
]

# tipos de chunk del formato .tic
CHUNK_TILES, CHUNK_CODE, CHUNK_PALETTE = 1, 5, 12


def cargar_arte():
    """importa arte.py y devuelve {id_sprite: [8 filas de 8 chars]}"""
    sys.path.insert(0, str(ARTE.parent))
    import arte
    return arte.SPRITES


def pixel_a_nibble(ch):
    """'.' = transparente (color 0); '0'-'9'/'a'-'f' = su valor hex"""
    if ch == ".":
        return 0
    return int(ch, 16)


def tile_bytes(filas):
    """8 filas de 8 chars → 32 bytes (2 píxeles/byte, izquierdo en nibble bajo)"""
    datos = []
    for fila in filas:
        for x in range(0, 8, 2):
            izq = pixel_a_nibble(fila[x])
            der = pixel_a_nibble(fila[x + 1])
            datos.append(izq | (der << 4))
    assert len(datos) == 32
    return bytes(datos)


def construir_tiles(sprites):
    """banco de 256 tiles (8192 bytes) con los sprites en su id"""
    banco = bytearray(256 * 32)
    for id_sprite, filas in sprites.items():
        if not 0 <= id_sprite < 256:
            raise ValueError(f"sprite {id_sprite} fuera del banco 0 (0-255)")
        banco[id_sprite * 32:(id_sprite + 1) * 32] = tile_bytes(filas)
    return bytes(banco)


def concat_codigo():
    """src/*.lua en orden alfabético (la numeración define el orden)"""
    partes = [METADATOS, ""]
    for ruta in sorted(SRC.glob("*.lua")):
        partes.append(ruta.read_text(encoding="utf-8").rstrip())
        partes.append("")
    return "\n".join(partes).encode("utf-8")


def chunk(tipo, datos, banco=0):
    """cabecera de chunk .tic (u32 LE: tipo | banco<<5 | tamaño<<8) + datos"""
    assert len(datos) <= 0xFFFF
    cabecera = tipo | (banco << 5) | (len(datos) << 8)
    return cabecera.to_bytes(4, "little") + datos


def construir_tic(codigo, tiles, paleta):
    return (
        chunk(CHUNK_TILES, tiles)
        + chunk(CHUNK_PALETTE, paleta)
        + chunk(CHUNK_CODE, codigo)
    )


def hex_pixels(filas):
    """64 chars por tile: los píxeles en orden de lectura (izq→der)"""
    return "".join(fila for fila in filas)


def construir_lua_texto(codigo, sprites, paleta):
    """cartucho en formato texto oficial de TIC-80 (project.c):
    código en claro + secciones de datos como comentarios.
    cada línea de datos es  -- NNN:hex  (NNN = índice de fila/tile)."""
    lineas = [codigo.decode("utf-8").rstrip(), ""]

    lineas.append("-- <TILES>")
    for id_sprite in sorted(sprites):
        filas = sprites[id_sprite]
        # en el formato texto los píxeles se leen en orden natural
        hexstr = "".join(
            ("0123456789abcdef" if c == "." else c)
            for fila in filas for c in fila
        ).replace(".", "0")
        lineas.append(f"-- {id_sprite:03d}:{hexstr}")
    lineas.append("-- </TILES>")
    lineas.append("")

    lineas.append("-- <PALETTE>")
    # dos paletas de 48 bytes (vbank0 y vbank1); solo guardamos vbank0
    hexpal = "".join(f"{v:02x}" for color in paleta for v in color)
    lineas.append(f"-- 000:{hexpal}")
    lineas.append("-- </PALETTE>")
    lineas.append("")
    return "\n".join(lineas)


def contar_tokens(codigo):
    """aproximación del tamaño del script (el límite de tic-80 es 64KB)"""
    return len(codigo)


def main():
    sprites = cargar_arte()
    tiles = construir_tiles(sprites)
    paleta = bytes(v for color in PALETA for v in color)
    codigo = concat_codigo()

    tic = construir_tic(codigo, tiles, paleta)
    (RAIZ / "cumbre_santa_ana.tic").write_bytes(tic)

    texto = construir_lua_texto(codigo, sprites, PALETA)
    (RAIZ / "cumbre_santa_ana.lua").write_text(texto, encoding="utf-8")

    print(f"escrito: cumbre_santa_ana.tic  ({len(tic)} bytes)")
    print(f"escrito: cumbre_santa_ana.lua  ({len(texto)} bytes)")
    print(f"código: {contar_tokens(codigo)} bytes / 65536 límite")
    return codigo, sprites, PALETA


if __name__ == "__main__":
    main()
