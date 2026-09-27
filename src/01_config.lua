-- ===========================================================================
-- 01_config.lua - compatibilidad tic-80/pico-8 + constantes del juego
-- ===========================================================================

-- -- capa de compatibilidad: nombres de pico-8 sobre la api de tic-80 -----
-- tic-80 y pico-8 son primos, pero sus apis difieren en detalles que
-- aparecen por todo el código. en lugar de reescribir el juego entero,
-- definimos aquí funciones con los nombres de pico-8 implementadas sobre
-- tic-80: así el resto del código se lee igual que la versión original y
-- las diferencias viven en un solo lugar (decisión de diseño del puerto).
--
-- diferencias que cubrimos:
--   * matemáticas: tic-80 trae la biblioteca estándar de lua (math.*);
--     pico-8 usa nombres cortos (flr, mid, sin en "giros"...). definimos
--     los cortos nosotros: el resultado es determinista y portable.
--   * dibujo: pico-8 rectfill(x0,y0,x1,y1) usa esquinas inclusivas;
--     tic-80 rect(x,y,w,h) usa posición + tamaño.
--   * cámara: tic-80 NO tiene camera(); la simulamos restando un offset
--     en cada dibujo (el "truco de cámara" clásico de la comunidad).
--   * tiempo: tic-80 time() devuelve milisegundos; nosotros contamos
--     frames y los convertimos a segundos (más determinista para pruebas).
--   * transparencia: spr() de tic-80 pide el colorkey explícito.
--   * botones: los ids cambian (ver la tabla de abajo).

-- números de pico-8 -> math de lua estándar
function flr(x) return math.floor(x) end
function abs(x) return math.abs(x) end
function sqrt(x) return math.sqrt(x) end
function min(a, b)
  if a < b then return a end
  return b
end
function max(a, b)
  if a > b then return a end
  return b
end
function sgn(x)
  if x < 0 then return -1 end
  return 1
end

-- mid(a,b,c) devuelve el valor intermedio de tres: con el orden
-- (mínimo, valor, máximo) funciona como "clamp", que es como lo usamos.
function mid(a, b, c)
  return max(a, min(b, c))
end

-- azar: math.random es determinista si se siembra con math.randomseed
function rnd(n)
  return math.random() * (n or 1)
end

function srand(n)
  math.randomseed(n)
end

-- sin/cos "de consola": el argumento va en GIROS (0..1 = vuelta completa)
-- y el seno sale invertido, igual que en pico-8. así las fórmulas del
-- viento y las animaciones dan exactamente el mismo resultado que allí.
function sin(x)
  return -math.sin(x * 6.283185307)
end

function cos(x)
  return math.cos(x * 6.283185307)
end

-- utilidades de tablas/cadenas con nombres de pico-8
function sub(s, a, b)
  return string.sub(s, a, b)
end

function deli(t, i)
  table.remove(t, i)
end

-- -- cámara virtual -------------------------------------------------------
-- camera(x,y) de pico-8 desplaza TODOS los dibujos. en tic-80 guardamos
-- el desplazamiento y cada primitiva de dibujo lo resta al llamar a la
-- función nativa. cuando la cámara vuelve a (0,0) se dibuja en pantalla.

cam_ox, cam_oy = 0, 0

function camera(x, y)
  cam_ox = x or 0
  cam_oy = y or 0
end

-- guardamos las funciones nativas de tic-80 ANTES de redefinir los nombres
-- de pico-8 (en lua, "local f = f" captura la global anterior).
local tic_rect  = rect
local tic_rectb = rectb
local tic_circ  = circ
local tic_circb = circb
local tic_line  = line
local tic_pix   = pix
local tic_print = print
local tic_spr   = spr

-- color transparente de los sprites: en pico-8 el color 0 es transparente
-- al dibujar spr(). aquí lo pedimos explícito con el colorkey 0.
local COLOR_TRANSPARENTE = 0

function rectfill(x0, y0, x1, y1, c)
  -- pico-8: esquinas (x0,y0)-(x1,y1) INCLUSIVAS -> tic-80: posición + tamaño
  tic_rect(x0 - cam_ox, y0 - cam_oy, x1 - x0 + 1, y1 - y0 + 1, c)
end

function rect(x0, y0, x1, y1, c)
  tic_rectb(x0 - cam_ox, y0 - cam_oy, x1 - x0 + 1, y1 - y0 + 1, c)
end

function circfill(x, y, r, c)
  -- ojo: en tic-80 "circ" ya es el relleno (el borde es "circb")
  tic_circ(x - cam_ox, y - cam_oy, r, c)
end

function circ(x, y, r, c)
  tic_circb(x - cam_ox, y - cam_oy, r, c)
end

function line(x0, y0, x1, y1, c)
  tic_line(x0 - cam_ox, y0 - cam_oy, x1 - cam_ox, y1 - cam_oy, c)
end

function pset(x, y, c)
  tic_pix(x - cam_ox, y - cam_oy, c)
end

function pget(x, y)
  return tic_pix(x - cam_ox, y - cam_oy)
end

function print(txt, x, y, c)
  return tic_print(txt, x - cam_ox, y - cam_oy, c or 15)
end

function spr(id, x, y, w, h)
  -- pico-8: spr(n, x, y, [w, h]) con color 0 transparente
  -- tic-80:  spr(id, x, y, colorkey, escala, flip, rotar, w, h)
  tic_spr(id, x - cam_ox, y - cam_oy, COLOR_TRANSPARENTE, 1, 0, 0, w or 1, h or 1)
end

-- -- tiempo de juego en segundos ------------------------------------------
-- contamos frames en 11_main.lua (TIC se llama 60 veces por segundo) y
-- t() devuelve los segundos transcurridos, como en pico-8. no usamos
-- time() de tic-80 (milisegundos reales) para que todo sea determinista:
-- mismo frame = mismo estado, ideal para pruebas y repetición.

frames_juego = 0

function t()
  return frames_juego / 60
end

-- -- ids de botones en tic-80 (p1) ----------------------------------------
-- tic-80: 0=arriba 1=abajo 2=izq 3=der 4=A 5=B 6=X 7=Y
-- (en pico-8 era: 0=izq 1=der 2=arriba 3=abajo 4=o 5=x)
-- mover: 2/3 - saltar y confirmar: A o B (4/5)

IZQ, DER, BTN_A, BTN_B = 2, 3, 4, 5

-- -- geometría del mundo --------------------------------------------------
-- el mundo es tan ancho como la pantalla (240) y muy alto: el scroll es
-- solo vertical. las coordenadas y crecen hacia ABAJO (convención de
-- consola), así que "subir" es restar y.

mundo_ancho = 240
mundo_alto  = 2200

-- -- física del jugador (por frame) ---------------------------------------
-- con salto_vy = -3.9 y gravedad = 0.22 el salto sube ~34px:
--     altura = vy2 / (2*g) = 3.92 / 0.44 ~ 34
-- eso permite salvar escalones de hasta ~28px de alto con margen.

gravedad        = 0.22   -- caída: px/frame2
salto_vy        = -3.9   -- impulso instantáneo al saltar (negativo = arriba)
vel_max         = 2.2    -- velocidad horizontal máxima caminando
acel_suelo      = 0.4    -- aceleración horizontal con los pies en el suelo
acel_aire       = 0.25   -- aceleración en el aire (control aéreo más débil)
acel_musgo      = 0.18   -- aceleración sobre musgo: cuesta empezar a frenar
frenado         = 0.70   -- fricción sin input en el suelo (0 = frena en seco)
frenado_musgo   = 0.94   -- fricción sobre musgo: ¡resbala! (casi no frena)
frenado_aire    = 0.96   -- deriva suave en el aire (también frena al viento)
vel_caida_max   = 4.5    -- velocidad de caída máxima (evita atravesar suelos)
vel_viento_max  = 3.0    -- tope de |dx| cuando el viento empuja en el aire

-- -- jugador --------------------------------------------------------------
-- la caja de colisión es más estrecha que el sprite de 8x8: se dibuja
-- el sprite 1px a la izquierda para centrarlo sobre la caja (ver 02).

jugador_ancho   = 6
jugador_alto    = 8

-- -- cámara ---------------------------------------------------------------
-- la cámara coloca al jugador a 56px del borde superior de la pantalla.
-- solo se mueve hacia arriba: si el jugador cae, la cámara no lo sigue,
-- y al salir por abajo se considera precipicio (ver 04_hazards.lua).

cam_altura_jugador = 56
margen_caida       = 144  -- player.y > cam_y + margen_caida  =>  precipicio
                           -- (136 de pantalla + 8 de margen)

-- -- rompibles ------------------------------------------------------------
frames_antes_de_romper = 60  -- 1 segundo desde el primer contacto con el pie

-- -- niebla de la cima ----------------------------------------------------
radio_niebla_base = 42   -- radio del círculo de visión (px)
niebla_suave      = 18   -- grosor del degradado del borde

-- -- umbrales de zona (en coordenada y del mundo) -------------------------
-- el estado del juego cambia cuando el jugador cruza hacia arriba cada
-- umbral. los checkpoints de cada zona están justo debajo de estos.

limite_zona2 = 1500  -- por encima de esta y: bosque seco
limite_zona3 = 850   -- por encima de esta y: bosque nublado
y_cima       = 200   -- por encima de esta y (y en el suelo): secuencia final
                     -- (el jugador, de pie en la cima, está en y=188)
