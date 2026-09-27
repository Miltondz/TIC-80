# Cumbre Santa Ana - versión TIC-80

Port completo del juego de plataformas **"Cumbre Santa Ana"** (originalmente
PICO-8) a **TIC-80**, la fantasy console con la misma escuela retro pero
más resolución: **240x136** y 16 colores (Sweetie 16).

El diseño sigue siendo el documento original: una subida de 5-10 minutos por
tres zonas del Cerro Santa Ana (Paraguaná), con rompibles, cardones, viento,
niebla, musgo, siluetas familiares y un final que se abre a la panorámica.

---

## cómo se juega

Arrastra `cumbre_santa_ana.tic` a la ventana de TIC-80 (versión de escritorio
o el editor web) y pulsa **RUN**. O en la consola de TIC-80:

```
load cumbre_santa_ana.tic
run
```

| botón | acción |
|-------|--------|
| flechas | mover / saltar (la flecha ARRIBA también salta) |
| A / B / X / Y | saltar (todas equivalen: comodidad) |
| S | pausa (y vuelve) |
| R | reiniciar la partida (vuelve al menú) |
| A / B en el menú | comenzar la subida |
| A / B en el final | volver al menú |

Sin vidas, sin puntuación, sin enemigos: solo el ascenso.

---

## cómo se construye

Todo el arte y el cartucho se **generan** con Python (sin binarios en el repo):

```bash
cd tic80
python3 assets/arte.py            # imprime/describe los sprites (referencia)
python3 tools/build_cart.py       # genera cumbre_santa_ana.tic + .lua
python3 tools/simulate.py         # 39 pruebas + bot + capturas
```

- `tools/build_cart.py` junta `src/00..11` + los sprites de `assets/arte.py`
  + la paleta y empaqueta el binario `.tic` (chunks TILES / PALETTE / CODE).
- `tools/simulate.py` ejecuta el juego REAL dentro de un motor Lua (lupa) con
  `tools/tic80_mock.lua` (API de TIC-80 sobre un framebuffer de 240x136):
  39 comprobaciones de mecánicas, un bot que recorre los 74 saltos del nivel
  entero con la física real, y 7 capturas de escena en `docs/screenshots/`.
  Necesita `python3`, el paquete `lupa` e ImageMagick (`convert`) para las
  capturas PNG.

---

## cómo está organizado

```
tic80/
├── cumbre_santa_ana.tic      # cartucho TIC-80 listo para jugar
├── cumbre_santa_ana.lua      # el cartucho en formato texto oficial
│                             # (codigo + secciones -- <TILES> y -- <PALETTE>)
├── src/                      # fuentes comentadas, en 12 modulos:
│   ├── 00_guia.lua           # indice + compatibilidad pico-8 -> tic-80
│   ├── 01_config.lua         # constantes, fisica, colores, textos
│   ├── 02_util.lua           # helpers (mid, clamp, textos centrados...)
│   ├── 03_sprites.lua        # jugador + escarabajos animados
│   ├── 04_hazards.lua        # rompibles, cardones, decorados, caidas
│   ├── 05_plataformas.lua    # colisiones + viento + siluetas
│   ├── 06_niebla.lua         # la niebla (bloque clave) + hojas
│   ├── 07_partida.lua        # player, camara, muerte, checkpoints
│   ├── 08_fondo.lua          # cielo por zonas, colinas, panoramica final
│   ├── 09_datos_nivel.lua    # EL NIVEL: plataformas de todo el cerro
│   ├── 10_estados.lua        # menu / zonas / transiciones / final
│   └── 11_main.lua           # TIC(), input y arranque
├── assets/arte.py            # generador de sprites (un solo origen de verdad)
└── tools/
    ├── build_cart.py         # empaquetador .tic / .lua
    ├── tic80_mock.lua        # mock de la API de TIC-80 (240x136)
    └── simulate.py           # arnes de pruebas + bot + capturas
```

El código de `src/` es el que vive dentro del cartucho, comentado en español
como guía de lectura (qué hace cada función y por qué). Claridad por delante
del golf, incluso cerca del límite de tokens.

---

## diferencias con la versión PICO-8

La física, el diseño del nivel por zonas y la narrativa son las mismas. Lo que
cambia es lo que cambia al cambiar de consola:

| tema | PICO-8 | TIC-80 |
|------|--------|--------|
| pantalla | 128x128 | **240x136** (más panorámica) |
| código en cartucho | tokens (~8k) | bytes: **64KB máx** en el chunk CODE |
| botones | ⬅️➡️⬆️⬇️ 🅾️❎ | flechas + A/B/X/Y (indices 0-7) |
| primitivas | `rect/circ` = borde | `rect/circ` = **relleno**; `rectb/circb` = borde |
| rellenar | `rectfill/circfill/cls` | **no existen**: se construyen con `rect/circ/cls` |
| cámara / paleta | `camera()/pal()` | **no existen**: hay compat en `00_guia.lua` |
| sprites | hoja en el cartucho | chunk TILES (256 tiles 8x8, 4bpp) |
| sprites grises | `pal()` recoloreando | copias ya recoloreadas en la hoja (siluetas z3) |
| audio | SFX/MUSIC propios | fuera de alcance (sin audio en esta versión) |

Decisiones concretas del port:

- **Compatibilidad** (`src/00_guia.lua`): `rectfill`, `circfill`, `camera`,
  `sin` (fase de PICO-8), `mid`, `flr`... para que la lógica del juego conserve
  su lectura original. `print()` de TIC-80 devuelve el ancho del texto: eso
  simplifica `texto_centro()`.
- **nivel más ancho**: al pasar de 128 a 240px el nivel se organiza en **tres
  bandas de plataformas** (izquierda x20-60, central x80-132, derecha x144-188)
  unidas por saltos de 20-36px, con el mismo recorrido de altura (2200px) y
  las mismas y de transición entre zonas.
- **sprites grises**: TIC-80 no tiene `pal()`, así que las siluetas de la zona
  3 y el cardón "decorado" del fondo son sprites propios ya apagados
  (`assets/arte.py` los deriva automáticamente).
- **límite de 64KB**: las fuentes caben en el chunk CODE (≈64.3KB usados de
  65.5KB). El decorado de los comentarios es ASCII para no gastar bytes en
  UTF-8; los acentos y todo el contenido se conservan.
- **la niebla del final** sigue creciendo su radio también en la fase 2: en
  240px hacen falta radios grandes para que no queden restos en las esquinas.

---

## pruebas

`python3 tools/simulate.py` ejecuta **39 comprobaciones** sobre el juego real
(cargado tal cual dentro del mock):

- arranque, menú y transiciones por zona (incluye checks de píxeles del menú),
- movimiento, salto, gravedad y colisiones con plataformas,
- rompibles (temporizador, caída, restaurado al morir),
- cardones (knockback + invulnerabilidad, sin muerte),
- viento (solo en el aire, con tope de velocidad),
- niebla (radio, disipación al crecer, limpieza cerca del jugador),
- checkpoints y precipicio (reaparecer donde toca),
- la secuencia final completa (niebla -> panorama -> texto -> volver),
- **bot de escalada**: un bot ejecuta los 74 saltos del nivel entero con la
  física real y termina en la cima: el nivel es trazable sin trampas,
- 7 capturas de escena generadas en `docs/screenshots/`, verificadas después
  píxel a píxel (menú con sol, zonas con sus colores, final en tres fases).
