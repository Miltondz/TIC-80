# ═══════════════════════════════════════════════════════════════════════════
# assets/arte.py — pixel art del juego en ASCII legible
# ═══════════════════════════════════════════════════════════════════════════
#
# ¿por qué ascii y no un .png?
#   porque así el arte se puede LEER y editar como texto, y el script
#   tools/build_cart.py lo convierte a la sección __gfx__ del cartucho.
#
# convenciones:
#   '.'  -> píxel transparente (color 0 con transparencia por defecto)
#   dígito hexadecimal (0-9, a-f) -> índice de color de la paleta pico-8:
#       0 negro   1 azul marino  2 morado     3 verde oscuro
#       4 marrón  5 gris oscuro  6 gris claro 7 blanco
#       8 rojo    9 naranja      a amarillo    b verde
#       c azul    d lavanda      e piel        f rosa
#
# cada sprite es una lista de 8 filas de exactamente 8 caracteres.
# los sprites de 8x16 se definen en DOS ids: el "arriba" y el "abajo",
# y en el juego se dibujan con spr(id, x, y, 1, 2).
#
# disposición de la hoja de sprites (ids del sheet, 16 por fila):
#   1       jugador quieto
#   2       jugador corriendo (fase a)
#   3       jugador corriendo (fase b)
#   4       jugador saltando
#   6 / 22  cardón (8x16: id 6 arriba, id 22 abajo)
#   8 / 24  silueta familiar "mirando el paisaje" (8x16)
#   10 / 26 silueta familiar "saludando" frame 1 (8x16)
#   11 / 27 silueta familiar "saludando" frame 2 (8x16)
#   12 / 28 silueta familiar "sentada descansando" (8x16)
# ═══════════════════════════════════════════════════════════════════════════

# ── jugador ──────────────────────────────────────────────────────────────
# figura pequeña con sombrero (marrón 4), cara (piel e), camisa azul (c),
# mochila/brazos rojos (8) y pantalón oscuro (2).

JUGADOR_QUIETO = [
    "..4444..",   # sombrero (copa)
    ".444444.",   # sombrero (ala)
    "..e11e..",   # cara con dos ojos oscuros (1)
    "..eeee..",   # cara / cuello
    ".8cccc8.",   # brazos rojos a los lados, camisa azul al centro
    "..cccc..",   # torso
    "..2222..",   # pantalón
    "..2..2..",   # piernas separadas (quieto)
]

JUGADOR_CORRE_A = [
    "..4444..",
    ".444444.",
    "..e11e..",
    "..eeee..",
    ".8cccc8.",
    "..cccc..",
    "..2222..",
    ".22..22.",   # piernas abiertas (zancada)
]

JUGADOR_CORRE_B = [
    "..4444..",
    ".444444.",
    "..e11e..",
    "..eeee..",
    ".8cccc8.",
    "..cccc..",
    ".2222...",   # pierna trasera estirada
    "...222..",   # pierna delantera recogida
]

JUGADOR_SALTO = [
    "..4444..",
    ".444444.",
    "..e11e..",
    "..eeee..",
    "88cccc88",   # brazos extendidos
    "..cccc..",
    "..2222..",
    ".2....2.",   # piernas abiertas en el aire
]

# ── cardón (8x16) ────────────────────────────────────────────────────────
# cactus columnar típico del matorral desértico: verde oscuro (3) con
# una franja de luz (b) para que no se lea como un bloque plano.

CARDON_ARRIBA = [
    ".33..33.",   # dos columnas laterales (los brazos del cardón)
    ".33..33.",
    ".333333.",   # se unen al tronco central
    ".33b333.",   # franja de luz vertical
]

CARDON_ABAJO = [
    ".33b333.",
    ".33b333.",
    ".333333.",
    "..3333..",   # base
]

# las filas que faltan para completar 8x8 se rellenan con vacío:
# el sprite completo son 8 filas, así que definimos las dos mitades
# con 8 filas cada una (4 dibujadas + 4 vacías arriba / abajo según toque).

CARDON_ARRIBA_8X8 = CARDON_ARRIBA + ["........"] * 4
CARDON_ABAJO_8X8 = ["........"] * 4 + CARDON_ABAJO

# ── siluetas familiares (8x16) ──────────────────────────────────────────
# siluetas monocromas (color 1 = azul marino): son figuras de fondo,
# sin detalle facial, leídas "a contraluz" contra el cielo.
# el juego les hace pal(1, color_según_zona) para adaptarlas al fondo.

SILUETA_MIRANDO_ARRIBA = [
    "...11...",   # cabeza (estrecha)
    "...11...",
    "...11...",
    "..1111..",   # hombros
    ".111111.",   # brazos + torso
    ".111111.",
    ".111111.",
    "..1111..",   # cintura
]

SILUETA_MIRANDO_ABAJO = [
    "..1111..",
    "..1111..",
    "..1..1..",   # piernas separadas
    "..1..1..",
    "..1..1..",
    "..1..1..",
    ".11..11.",   # pies
    "........",
]

# saludar: brazo derecho hacia arriba; dos frames para la animación mínima.

SILUETA_SALUDA1_ARRIBA = [
    "...11...",
    "...11...",
    "...11...",
    ".1111111",   # brazo extendido a la altura del hombro
    ".111111.",
    ".111111.",
    ".111111.",
    "..1111..",
]

SILUETA_SALUDA2_ARRIBA = [
    "...11..1",   # brazo arriba (junto a la cabeza)
    "...11..1",
    "...11111",
    ".1111111",
    ".111111.",
    ".111111.",
    ".111111.",
    "..1111..",
]

# sentada: figura más baja, con las piernas estiradas hacia un lado.

SILUETA_SENTADO_ARRIBA = [
    "...11...",
    "...11...",
    "...11...",
    "..1111..",
    ".111111.",
    ".111111.",
    "........",
    "........",
]

SILUETA_SENTADO_ABAJO = [
    "........",
    ".111111.",   # muslos
    ".1111111",
    "..111111",   # piernas estiradas
    "........",
    "........",
    "........",
    "........",
]

# ── tabla final: id del sheet -> sprite ─────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════
# tabla de sprites para la hoja de TIC-80
# ═══════════════════════════════════════════════════════════════════════════
# en TIC-80 la hoja tiene 32 sprites de ancho (256px), así que el trozo
# "abajo" de un sprite de 8x16 está en id+32 (en pico-8 era id+16).
# además, TIC-80 no tiene pal() para recolorear: la zona 3 usa copias
# grises de las siluetas (mismas figuras, distinto color).

def _gris(filas):
    # las siluetas se dibujan con el color 1 (azul marino); la versión
    # gris usa el color 5 para "perderse" en la bruma de la cima
    return [f.replace('1', '5') for f in filas]

SILUETA_MIRANDO_ARRIBA_G = _gris(SILUETA_MIRANDO_ARRIBA)
SILUETA_MIRANDO_ABAJO_G = _gris(SILUETA_MIRANDO_ABAJO)
SILUETA_SALUDA1_ARRIBA_G = _gris(SILUETA_SALUDA1_ARRIBA)
SILUETA_SALUDA2_ARRIBA_G = _gris(SILUETA_SALUDA2_ARRIBA)
SILUETA_SENTADO_ARRIBA_G = _gris(SILUETA_SENTADO_ARRIBA)
SILUETA_SENTADO_ABAJO_G = _gris(SILUETA_SENTADO_ABAJO)

SPRITES = {
    # jugador (8x8): quieto / corrida a-b / salto
    1: JUGADOR_QUIETO,
    2: JUGADOR_CORRE_A,
    3: JUGADOR_CORRE_B,
    4: JUGADOR_SALTO,
    # cardón 8x16 (par vertical: 6 y 6+32)
    6: CARDON_ARRIBA_8X8,
    38: CARDON_ABAJO_8X8,
    # siluetas azul marino (zonas 1 y 2), pares 8x16
    8: SILUETA_MIRANDO_ARRIBA,
    40: SILUETA_MIRANDO_ABAJO,
    10: SILUETA_SALUDA1_ARRIBA,
    42: SILUETA_MIRANDO_ABAJO,        # los de pie comparten piernas
    11: SILUETA_SALUDA2_ARRIBA,
    43: SILUETA_MIRANDO_ABAJO,
    12: SILUETA_SENTADO_ARRIBA,
    44: SILUETA_SENTADO_ABAJO,
    # siluetas grises (zona 3, niebla): mismas figuras, color 5
    48: SILUETA_MIRANDO_ARRIBA_G,
    80: SILUETA_MIRANDO_ABAJO_G,
    50: SILUETA_SALUDA1_ARRIBA_G,
    82: SILUETA_MIRANDO_ABAJO_G,
    51: SILUETA_SALUDA2_ARRIBA_G,
    83: SILUETA_MIRANDO_ABAJO_G,
    52: SILUETA_SENTADO_ARRIBA_G,
    84: SILUETA_SENTADO_ABAJO_G,
}

# cardon "decorado": el mismo cardon en tonos de fondo (sin pal() en
# tic-80, la version lejana/apagada vive como sprite propio)
CARDON_DECORADO_ARRIBA = [f.replace('3', '1').replace('b', '5') for f in CARDON_ARRIBA_8X8]
CARDON_DECORADO_ABAJO = [f.replace('3', '1').replace('b', '5') for f in CARDON_ABAJO_8X8]
SPRITES[54] = CARDON_DECORADO_ARRIBA
SPRITES[86] = CARDON_DECORADO_ABAJO

# qué sprite usar según pose y zona (zona 3 = copias grises)
def sprite_silueta(pose, zona):
    gris = (zona == 3)
    if pose == "saludando":
        # la animación alterna 10/11 (gris: 50/51)
        return (50, 51) if gris else (10, 11)
    if pose == "sentado":
        return (52,) if gris else (12,)
    return (48,) if gris else (8,)
