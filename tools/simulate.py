#!/usr/bin/env python3
# ==========================================================================
# tools/simulate.py - pruebas headless del juego + capturas de pantalla
# ==========================================================================
# ejecuta el MISMO codigo que va en el cartucho sobre el mock de la api de
# tic-80 (tools/tic80_mock.lua) usando lupa (lua embebido en python).
#
# incluye:
#   * pruebas de cada mecanica (salto, rompibles, cardones, viento, niebla,
#     checkpoints, caidas, secuencia final)
#   * un "bot de escalada" que intenta saltar de plataforma en plataforma
#     usando la fisica real: si el bot no llega, el nivel esta mal trazado
#   * capturas de pantalla a docs/screenshots/ (ppm -> png con convert)
#
# uso:  python3 tools/simulate.py [--solo-capturas]
# ==========================================================================

import subprocess
import sys
from pathlib import Path

import lupa

RAIZ = Path(__file__).resolve().parent.parent
SHOTS = RAIZ / "docs" / "screenshots"

FALLOS = []
OKS = []


def comprobar(nombre, condicion, detalle=""):
    if condicion:
        OKS.append(nombre)
        print(f"  ✔ {nombre}")
    else:
        FALLOS.append(nombre)
        print(f"  ✘ {nombre}  {detalle}")


# ── carga del cartucho ────────────────────────────────────────────────────

def construir_cartucho():
    r = subprocess.run(
        [sys.executable, str(RAIZ / "tools" / "build_cart.py")],
        capture_output=True, text=True, check=True,
    )
    return r.stdout


def cargar():
    construir_cartucho()
    cart = (RAIZ / "cumbre_santa_ana.lua").read_text(encoding="utf-8")

    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute((RAIZ / "tools" / "tic80_mock.lua").read_text(encoding="utf-8"))

    # la seccion -- <TILES> del cartucho de texto trae los sprites como
    # hex: 64 caracteres = 64 pixeles en orden de lectura. los empaquetamos
    # a 32 bytes (2 pixeles/byte, el izquierdo en el nibble bajo) y los
    # cargamos en la hoja del mock, igual que hace tic-80 con el .tic
    dentro = False
    for linea in cart.splitlines():
        if linea.startswith("-- <TILES>"):
            dentro = True
            continue
        if linea.startswith("-- </TILES>"):
            break
        if dentro and linea.startswith("-- ") and len(linea) > 7:
            idx = int(linea[3:6])
            pixeles = linea[7:].strip()
            datos = []
            for i in range(0, 64, 2):
                izq = int(pixeles[i], 16)
                der = int(pixeles[i + 1], 16)
                datos.append(izq | (der << 4))
            # (lupa: crear la tabla lua directamente)
            tabla = L.eval("{}")
            for j, b in enumerate(datos, start=1):
                tabla[j] = b
            L.globals().mock.tiles[idx] = tabla

    # el codigo entero del cartucho: las secciones de datos son comentarios
    L.execute(cart)
    L.execute("BOOT()")
    return L


# ── helpers de simulación ─────────────────────────────────────────────────

# ids de botones de tic-80 (p1):
# 0=arriba 1=abajo 2=izq 3=der 4=A 5=B 6=X 7=Y
ARR, ABA, IZQ, DER, A, B, X, Y = 0, 1, 2, 3, 4, 5, 6, 7


def frames(L, n, botones=(), solo_logica=False):
    """avanza n frames del juego con los botones dados pulsados"""
    for b in range(8):   # 0..7: los 8 botones de tic-80
        if b in botones:
            L.globals().mock.pulsar(b)
        else:
            L.globals().mock.soltar(b)
    for _ in range(n):
        L.globals().mock.tick(solo_logica)


def captura(L, nombre):
    SHOTS.mkdir(parents=True, exist_ok=True)
    ppm = SHOTS / f"{nombre}.ppm"
    png = SHOTS / f"{nombre}.png"
    L.globals().mock.dump_ppm(str(ppm))
    subprocess.run(["convert", str(ppm), str(png)], check=True)
    ppm.unlink()
    print(f"  📸 {png.relative_to(RAIZ)}")


def g(L, nombre):
    """lee una global del juego"""
    return L.globals()[nombre]


def poner_jugador(L, x, y, dx=0, dy=0):
    p = g(L, "player")
    p["x"], p["y"], p["dx"], p["dy"] = x, y, dx, dy
    p["on_ground"] = False


# ── pruebas ───────────────────────────────────────────────────────────────

def test_arranque_y_menu(L):
    print("· arranque y menú")
    comprobar("arranca en el menú", g(L, "estado") == "menu", g(L, "estado"))
    frames(L, 2)
    captura(L, "01_menu")

    # estructura del menú a nivel de pixel: sol en (180, 30) y letras
    # blancas del título -- si el dibujo se rompe, esto lo detecta
    comprobar("el sol del menú es amarillo", L.eval('pix(180, 30)') == 10,
              f"pix(180,30)={L.eval('pix(180, 30)')}")
    n_texto = L.eval("""
      (function()
        local n = 0
        for y = 14, 30 do
          for x = 60, 180 do
            if pix(x, y) == 7 then n = n + 1 end
          end
        end
        return n
      end)()
    """)
    comprobar("los títulos del menú se ven", n_texto > 40, f"{n_texto} px")

    frames(L, 1, botones=(A,))   # pulsar A/B comienza la partida
    comprobar("A/B empieza la partida", g(L, "estado") == "zona1", g(L, "estado"))
    p = g(L, "player")
    comprobar("aparece en el checkpoint 1", p["y"] > 2000, f"y={p['y']}")


def test_movimiento_y_salto(L):
    print("· movimiento y salto")
    p = g(L, "player")
    x0 = p["x"]
    frames(L, 30, botones=(DER,))
    comprobar("mover a la derecha aumenta x", p["x"] > x0 + 20, f"x={p['x']}")
    comprobar("está en el suelo", p["on_ground"] is True)

    frames(L, 1, botones=(A,))
    tras_salto = p["dy"]
    comprobar("saltar da velocidad negativa", tras_salto < 0, f"dy={tras_salto}")

    frames(L, 20, botones=(A,))
    comprobar("sube con el salto", p["y"] < 2090, f"y={p['y']}")

    frames(L, 80)
    comprobar("vuelve a caer al suelo", p["on_ground"] is True)

    # sin doble salto: en el aire, volver a pulsar no cambia dy
    frames(L, 1, botones=(A,))
    y_aire = p["dy"]
    frames(L, 10, botones=(A,))
    comprobar("sin doble salto (la gravedad sigue)", p["dy"] > y_aire)


def test_plataforma_rompible(L):
    print("· plataformas rompibles (bloque clave 1)")
    L.execute("""
        -- buscamos una rompible entera y colocamos al jugador sobre ella
        for i = 1, #plataformas do
            local p = plataformas[i]
            if p.tipo == "rompible" and p.estado == "entera" then
                player.x, player.y = p.x + 4, p.y - player.h
                player.dx, player.dy = 0, 0
                rompible_de_prueba = p
                break
            end
        end
    """)
    p = g(L, "player")
    rom = L.globals().rompible_de_prueba
    comprobar("existe una rompible de prueba", rom is not None)

    frames(L, 3)  # aterrizar
    comprobar("está sobre la rompible", p["on_ground"] is True)
    comprobar("empieza a temblar al pisarla", rom["estado"] == "temblando", rom["estado"])

    frames(L, int(rom["temporizador"]) + 5)
    comprobar("se rompe tras el temporizador", rom["estado"] == "rota", rom["estado"])
    comprobar("el jugador cae al romperse", p["on_ground"] is False)

    # al morir, las rompibles vuelven a su estado inicial
    L.globals().morir()
    comprobar("morir restaura las rompibles", rom["estado"] == "entera", rom["estado"])


def test_cardon_knockback(L):
    print("· cardones (knockback, sin muerte)")
    L.execute("""
        local h = hazards[1]
        -- nos ponemos rozando el cardón, con checkpoint guardado
        player.x, player.y = h.x - 2, h.y + 4
        player.dx, player.dy = 0, 0
        player.invuln = 0
        x_cardon = h.x
    """)
    p = g(L, "player")
    frames(L, 2)
    comprobar("el cardón empuja hacia atrás", p["dx"] < -1 or p["dx"] > 1, f"dx={p['dx']}")
    comprobar("queda invulnerable unos frames", p["invuln"] > 0, f"invuln={p['invuln']}")
    comprobar("el cardón no mata", g(L, "estado") == "zona1")
    frames(L, 45)
    comprobar("la invulnerabilidad se acaba", p["invuln"] == 0)


def test_viento(L):
    print("· viento (bloque clave 2)")
    L.execute("""
        iniciar_partida()
        local v = vientos[1]   -- primer tramo: dir = 1 (empuja a la derecha)
        -- en el aire, dentro del tramo: debe recibir empuje
        player.x, player.y = v.x + 40, v.y + 40
        player.dx, player.dy = 0, 0
        player.on_ground = false
        dir_viento = v.dir
    """)
    p = g(L, "player")
    frames(L, 10)  # sin input
    comprobar("en el aire el viento empuja hacia su dirección",
              (p["dx"] > 0) == (L.globals().dir_viento > 0), f"dx={p['dx']}")

    # en el suelo NO empuja: usamos una plataforma real dentro del tramo
    L.execute("""
        local v = vientos[1]
        local elegida = nil
        for i = 1, #plataformas do
            local pl = plataformas[i]
            -- plataforma dentro del rectángulo del viento y con hueco libre
            -- justo encima (para que el salto no dé con la cabeza)
            if pl.y > v.y and pl.y < v.y + v.h and elegida == nil then
                elegida = pl
            end
        end
        player.x, player.y = elegida.x + 8, elegida.y - player.h
        player.dx, player.dy = 0, 0
    """)
    frames(L, 30)  # aterrizar y asentarse: sin input, el suelo frena
    comprobar("en el suelo el viento no empuja", abs(p["dx"]) < 0.05, f"dx={p['dx']}")
    comprobar("está de pie sobre la plataforma", p["on_ground"] is True)

    # saltando desde esa misma plataforma, el viento lo empuja en el aire
    frames(L, 1, botones=(A,))
    frames(L, 15)
    comprobar("al saltar, el viento actúa en el aire", p["dx"] > 0.3, f"dx={p['dx']}")

    # el viento nunca supera el tope
    L.execute("""
        local v = vientos[1]
        player.x, player.y = v.x + 40, v.y + 40
        player.dx, player.dy = 0, 0
        player.on_ground = false
    """)
    frames(L, 120)
    comprobar("el viento tiene tope de velocidad", abs(p["dx"]) <= 3.001, f"dx={p['dx']}")


def test_niebla(L):
    print("· niebla (bloque clave 3)")
    L.execute("""
        estado = "zona3"
        player.x, player.y = 40, 700
        player.dx, player.dy = 0, 0
        cam_y = 700 - 56
        update_niebla()
    """)
    L.globals().mock.tick()  # un frame de lógica+dibujo con la niebla activa

    # en coordenadas de pantalla el jugador está en (43, 60)
    # 1) cerca del jugador debe verse el escenario (no niebla pura)
    cerca = L.eval("pix(44, 62)")
    # 2) lejos (esquina superior) debe haber niebla
    lejos = L.eval("pix(2, 2)")
    comprobar("lejos del jugador hay niebla", lejos == 6, f"color={lejos}")
    comprobar("cerca del jugador se ve el escenario", cerca != 6, f"color={cerca}")

    # al disiparse (radio enorme) la niebla desaparece. en zona3 el update
    # "respira" el radio, así que probamos con el estado final (que es donde
    # de verdad se disipa la niebla)
    L.execute("""
        estado = "final"
        final_fase = 2
        niebla_radio = 200
        cam_y = 644
    """)
    L.globals().mock.tick()  # frame completo: la escena se redibuja sin niebla
    esquina = L.eval("pix(2, 2)")
    comprobar("al crecer el radio, la niebla se disipa", esquina != 6, f"color={esquina}")
    L.execute('estado = "zona3"')


def test_checkpoint_y_caida(L):
    print("· checkpoints y precipicio")
    L.execute("""
        iniciar_partida()
        -- nos acercamos al checkpoint 2 (zona 2) sin tocar el 3
        local cp = checkpoints[2]
        player.x, player.y = cp.x, cp.y
        player.dx, player.dy = 0, 0
    """)
    p = g(L, "player")
    frames(L, 2)
    comprobar("tocar el checkpoint 2 lo guarda", p["checkpoint"] == 2, f"cp={p['checkpoint']}")

    # caída fuera del borde de la cámara -> reaparece en el checkpoint 2
    L.execute("player.y = cam_y + 500")
    frames(L, 2)
    comprobar("el precipicio devuelve al checkpoint 2", p["checkpoint"] == 2)
    comprobar("reaparece en la posición del checkpoint 2",
              abs(p["y"] - L.eval("checkpoints[2].y")) < 1, f"y={p['y']}")
    frames(L, 5)
    comprobar("tras morir, el jugador puede seguir jugando",
              g(L, "estado") == "zona1" or g(L, "estado") == "zona2")


def test_secuencia_final(L):
    print("· secuencia final")
    L.execute("""
        iniciar_partida()
        estado = "zona3"
        -- colocamos al jugador aterrizando en la plataforma de la cima
        local cima = nil
        for i = 1, #plataformas do
            if plataformas[i].y == 196 then cima = plataformas[i] end
        end
        player.x, player.y = cima.x + 20, cima.y - player.h - 2
        player.dx, player.dy = 0, 0
        cam_y = 196 - 56
    """)
    p = g(L, "player")
    frames(L, 10)
    comprobar("llegar a la cima inicia el final", g(L, "estado") == "final", g(L, "estado"))
    comprobar("la niebla empieza a disiparse", g(L, "final_fase") == 1)

    frames(L, 200)
    comprobar("la niebla se disipa y se ve el panorama", g(L, "final_fase") == 2, str(g(L, "final_fase")))

    frames(L, 170)
    comprobar("aparece el texto de cierre", g(L, "final_fase") == 3, str(g(L, "final_fase")))
    frames(L, 260)

    frames(L, 2, botones=(A,))
    comprobar("A/B vuelve al menú", g(L, "estado") == "menu", g(L, "estado"))


def test_bot_escalada(L):
    print("· bot de escalada (el nivel es trazable con la física real)")
    L.execute("""
        iniciar_partida()
        -- lista de plataformas del camino, ordenadas de abajo a arriba
        camino = {}
        for i = 1, #plataformas do
            camino[#camino + 1] = plataformas[i]
        end
        -- ordenar por y descendente (la base primero)
        for i = 1, #camino - 1 do
            for j = i + 1, #camino do
                if camino[j].y > camino[i].y then
                    camino[i], camino[j] = camino[j], camino[i]
                end
            end
        end
        -- el bot ejecuta los sistemas jugables SIN transiciones ni cámara:
        -- así medimos solo la física (y el viento, que también cuenta)
        function tick_fisica()
            update_jugador()
            update_plataformas()
            update_viento()
            update_hazards()
            update_escombros()
        end
    """)
    camino = L.globals().camino
    n = L.eval("#camino")
    malos = []

    for i in range(1, n):
        a = camino[i]
        b = camino[i + 1]
        if b["y"] >= a["y"]:
            continue  # misma altura o más abajo: no es un paso del ascenso
        if not intentar_salto(L, a, b):
            malos.append((i, a["x"], a["y"], b["x"], b["y"]))

    comprobar(f"el bot recorre los {n - 1} pasos del nivel", not malos, str(malos[:8]))


def _frames_fisica(L, n, botones=()):
    """avanza n frames solo con la física del juego (sin dibujo ni estados)"""
    for _ in range(n):
        for b in range(8):
            if b in botones:
                L.globals().mock.pulsar(b)
            else:
                L.globals().mock.soltar(b)
        L.execute("tick_fisica()")
        # el flanco de btnp se actualiza al terminar el frame (como mock.tick)
        L.execute("for i = 0, 7 do mock.boton_prev[i] = mock.boton[i] end")


def intentar_salto(L, a, b):
    """
    intenta ir de la plataforma a la b con la física real.
    un jugador modula cada salto (dónde despega, a qué velocidad, cuánto
    mantiene la dirección), así que el bot prueba combinaciones:
      desfase: despegar más lejos del borde (para ganar altura antes de
               acercarse a la esquina de la plataforma de arriba)
      m:       frames frenando en dirección opuesta antes de saltar
      k:       frames manteniendo la dirección tras despegar
    además se resetean las rompibles entre intentos: medimos geometría,
    no puntería contra el temporizador.
    """
    for desfase in (0, 24, 48, 72):
        for m in (0, 2):
            for k in (0, 6, 14, 30):
                if _intento_salto(L, a, b, desfase, m, k):
                    return True
    return False


def _intento_salto(L, a, b, desfase, m, k):
    p = g(L, "player")
    w = p["w"]
    centro_a = a["x"] + a["w"] / 2
    centro_b = b["x"] + b["w"] / 2
    dirn = 0 if abs(centro_b - centro_a) < 10 else (1 if centro_b > centro_a else -1)

    # punto de despegue: el borde de a hacia b, alejado "desfase" px.
    # la carrerilla es corta (24px): basta para alcanzar la velocidad
    # máxima sin importar lo ancha que sea la plataforma.
    if dirn > 0:
        x_borde = a["x"] + a["w"] - w - 1
        x_despegue = max(a["x"], x_borde - desfase)
        x0 = max(a["x"], x_despegue - 24)
    elif dirn < 0:
        x_borde = a["x"] + 1
        x_despegue = min(a["x"] + a["w"] - w - 1, x_borde + desfase)
        x0 = min(a["x"] + a["w"] - w - 1, x_despegue + 24)
    else:
        x_despegue = mid_py(a["x"], centro_b - w / 2, a["x"] + a["w"] - w)
        x0 = mid_py(a["x"], x_despegue - 24, a["x"] + a["w"] - w - 1)

    L.execute(f"""
        reset_plataformas()
        player.x, player.y = {x0}, {a['y'] - 8}
        player.dx, player.dy = 0, 0
        player.on_ground = true
        player.bajo_pies = nil
        player.invuln = 999999
    """)

    def boton_dir():
        if dirn != 0:
            return (DER,) if dirn > 0 else (IZQ,)
        return (DER,) if x_despegue > x0 else (IZQ,)

    def boton_contrario():
        d = boton_dir()
        return (IZQ,) if d == (DER,) else (DER,)

    # fase 1: correr hasta el punto de despegue
    run_dir = 1 if x_despegue > x0 else -1
    llego = False
    for _ in range(36):
        _frames_fisica(L, 1, boton_dir())
        if (run_dir > 0 and p["x"] >= x_despegue) or (run_dir < 0 and p["x"] <= x_despegue):
            llego = True
            break
    if not llego:
        return False

    # fase 2: frenar m frames (dirección opuesta) para modular la velocidad
    for _ in range(m):
        _frames_fisica(L, 1, boton_contrario())

    # fase 3: saltar
    _frames_fisica(L, 1, boton_dir() + (A,))

    # fase 4: vuelo; mantener la dirección k frames
    mant = k
    for _ in range(34):
        if mant > 0:
            _frames_fisica(L, 1, boton_dir())
            mant -= 1
        else:
            _frames_fisica(L, 1)
        if _aterrizo_en(p, a, b, w):
            return True
        if p["y"] > a["y"] + 30:
            return False  # se cayó al vacío
    return _aterrizo_en(p, a, b, w)



def _aterrizo_en(p, a, b, w):
    """¿está el jugador de pie, dentro de los límites, sobre la plataforma b?"""
    return (p["on_ground"] and abs(p["y"] - (b["y"] - 8)) < 2
            and b["x"] - 2 <= p["x"] <= b["x"] + b["w"] - w + 2)


def mid_py(a, b, c):
    return max(min(a, b), min(max(a, b), c))



def capturas_escena(L):
    print("· capturas de escena")
    # zona 1: mitad de la base (el jugador, de pie en una plataforma real)
    L.execute("""
        iniciar_partida()
        estado = "zona1"
        mostrar_mensaje("", 0)
        player.x, player.y = 108, 1852     -- sobre plataforma(88, 1860, 40)
        player.dx, player.dy = 0, 0
        cam_y = 1852 - 56
    """)
    frames(L, 12)
    captura(L, "02_zona1_base")

    # zona 2: tramo de viento (con hojas a la vista)
    L.execute("""
        estado = "zona2"
        mostrar_mensaje("", 0)
        player.x, player.y = 104, 1280     -- sobre plataforma(84, 1288, 40)
        player.dx, player.dy = 0, 0
        cam_y = 1436 - 56
    """)
    frames(L, 30)
    captura(L, "03_zona2_viento")

    # zona 3: niebla y musgo
    L.execute("""
        estado = "zona3"
        mostrar_mensaje("", 0)
        player.x, player.y = 104, 604      -- sobre musgo(88, 612, 32)
        player.dx, player.dy = 0, 0
        cam_y = 604 - 56
        update_niebla()
    """)
    frames(L, 12)
    captura(L, "04_zona3_niebla")

    # la cima, justo al comenzar la secuencia final (niebla abriéndose)
    L.execute("""
        estado = "zona3"
        mostrar_mensaje("", 0)
        player.x, player.y = 120, 188      -- de pie en la plataforma de la cima
        player.dx, player.dy = 0, 0
        cam_y = 196 - 56
    """)
    frames(L, 2)
    frames(L, 40)   # la niebla ya se está disipando
    captura(L, "05_final_niebla")
    frames(L, 170)  # panorama revelado del todo (la niebla ya no pinta ni bordes)
    captura(L, "06_final_panorama")
    frames(L, 380)  # texto de cierre (completo + aviso parpadeante)
    captura(L, "07_final_texto")




# ── main ──────────────────────────────────────────────────────────────────

def main():
    solo_capturas = "--solo-capturas" in sys.argv
    print(construir_cartucho().strip())
    L = cargar()

    if solo_capturas:
        capturas_escena(L)
        return

    test_arranque_y_menu(L)
    test_movimiento_y_salto(L)
    test_plataforma_rompible(L)
    test_cardon_knockback(L)
    test_viento(L)
    test_niebla(L)
    test_checkpoint_y_caida(L)
    test_secuencia_final(L)
    test_bot_escalada(L)
    capturas_escena(L)

    print()
    print(f"pruebas ok: {len(OKS)}   fallos: {len(FALLOS)}")
    if FALLOS:
        sys.exit(1)


if __name__ == "__main__":
    main()
