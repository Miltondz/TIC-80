-- ==========================================================================
-- tools/tic80_mock.lua - simulacion minima de la api de tic-80
-- ==========================================================================
-- este archivo NO forma parte del juego: es una herramienta de desarrollo
-- que implementa la api nativa de tic-80 (pix, rect, circ, spr, print...)
-- sobre un framebuffer de 240x136, para poder ejecutar y PROBAR el juego
-- con un interprete de lua normal (ver tools/simulate.py).
--
-- que implementa y que no:
--   * graficos: cls, pix, rect, rectb, circ, circb, line, print, spr
--   * input: btn, btnp (ids 0-7 como tic-80)
--   * utilidades: trace, time, exit, reset
--   * NO define flr/sin/rnd...: esas las define la capa de compatibilidad
--     del juego (01_config.lua) sobre math.* de lua estandar
--   * la camara virtual y rectfill/circfill tambien son del juego: aqui
--     solo estan las primitivas NATIVAS de tic-80
-- ==========================================================================

mock = {
  ancho = 240,
  alto = 136,
  fb = {},
  boton = {},          -- estado actual de los 8 botones
  boton_prev = {},     -- estado del frame anterior (para btnp)
  tiles = {},          -- hoja de sprites: tiles[id] = 32 bytes (4bpp)
  reloj_ms = 0,
}

-- paleta del cartucho (la misma "clasica" que graba build_cart.py)
mock.paleta_rgb = {
  [0] = { 0, 0, 0 },          -- #000000 negro
  [1] = { 29, 43, 83 },       -- #1d2b53 azul marino
  [2] = { 126, 37, 83 },      -- #7e2553 morado oscuro
  [3] = { 0, 135, 81 },       -- #008751 verde oscuro
  [4] = { 171, 82, 54 },      -- #ab5236 marron
  [5] = { 95, 87, 79 },       -- #5f574f gris oscuro
  [6] = { 194, 195, 199 },    -- #c2c3c7 gris claro
  [7] = { 255, 241, 232 },    -- #fff1e8 blanco
  [8] = { 255, 0, 77 },       -- #ff004d rojo
  [9] = { 255, 163, 0 },      -- #ffa300 naranja
  [10] = { 255, 236, 39 },    -- #ffec27 amarillo
  [11] = { 0, 228, 54 },      -- #00e436 verde
  [12] = { 41, 173, 255 },    -- #29adff azul cielo
  [13] = { 131, 118, 156 },   -- #83769c lila
  [14] = { 255, 204, 170 },   -- #ffccaa piel
  [15] = { 255, 119, 168 },   -- #ff77a8 rosa
}

-- =====================================================================
-- framebuffer
-- =====================================================================

function mock.limpiar_fb(c)
  for i = 0, mock.ancho * mock.alto - 1 do
    mock.fb[i] = c or 0
  end
end
mock.limpiar_fb(0)

-- =====================================================================
-- input: los tests fijan botones con mock.pulsar / mock.soltar
-- =====================================================================

function mock.pulsar(i) mock.boton[i] = true end
function mock.soltar(i) mock.boton[i] = false end

function btn(i)
  return mock.boton[i] == true
end

function btnp(i)
  -- "pulsado en este frame": flanco respecto al frame anterior
  return mock.boton[i] == true and mock.boton_prev[i] ~= true
end

-- =====================================================================
-- dibujo: primitivas nativas de tic-80 (sin camara: el juego la aplica)
-- =====================================================================

function mock.pintar(sx, sy, c)
  sx = math.floor(sx) sy = math.floor(sy)
  if sx < 0 or sx > 239 or sy < 0 or sy > 135 then return end
  mock.fb[sy * 240 + sx] = c
end

function mock.leer(sx, sy)
  sx = math.floor(sx) sy = math.floor(sy)
  if sx < 0 or sx > 239 or sy < 0 or sy > 135 then return 0 end
  return mock.fb[sy * 240 + sx]
end

function cls(c)
  mock.limpiar_fb(c or 0)
end

function pix(x, y, c)
  if c == nil then
    return mock.leer(x, y)
  end
  mock.pintar(x, y, c)
end

function rect(x, y, w, h, c)
  -- rectangulo RELLENO (tic-80: rect = relleno, rectb = borde)
  for py = y, y + h - 1 do
    for px = x, x + w - 1 do
      mock.pintar(px, py, c)
    end
  end
end

function rectb(x, y, w, h, c)
  for px = x, x + w - 1 do
    mock.pintar(px, y, c) mock.pintar(px, y + h - 1, c)
  end
  for py = y, y + h - 1 do
    mock.pintar(x, py, c) mock.pintar(x + w - 1, py, c)
  end
end

function circ(cx, cy, r, c)
  -- circulo RELLENO (tic-80: circ = relleno, circb = borde)
  for y = -r, r do
    local ancho = math.floor(math.sqrt(r * r - y * y))
    for x = -ancho, ancho do
      mock.pintar(cx + x, cy + y, c)
    end
  end
end

function circb(cx, cy, r, c)
  for y = -r - 1, r + 1 do
    for x = -r - 1, r + 1 do
      local d2 = x * x + y * y
      if d2 <= r * r + r and d2 >= r * r - r then
        mock.pintar(cx + x, cy + y, c)
      end
    end
  end
end

function line(x0, y0, x1, y1, c)
  local dx = math.abs(x1 - x0) local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0) local sy = y0 < y1 and 1 or -1
  local err = dx + dy
  while true do
    mock.pintar(x0, y0, c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy x0 = x0 + sx end
    if e2 <= dx then err = err + dx y0 = y0 + sy end
  end
end

-- =====================================================================
-- fuente de 3x5 (solo lo necesario para verificar pantallas)
-- =====================================================================
-- tic-80 tiene su propia fuente; aqui usamos glifos minimos (5 filas de
-- 3 pixeles, con '#' = pixel encendido). print() devuelve el ancho, como
-- la api real, para poder centrar textos.

local fuente = {
  ["a"] = { ".#.", "#.#", "###", "#.#", "#.#" },
  ["b"] = { "##.", "#.#", "##.", "#.#", "##." },
  ["c"] = { ".##", "#..", "#..", "#..", ".##" },
  ["d"] = { "##.", "#.#", "#.#", "#.#", "##." },
  ["e"] = { "###", "#..", "##.", "#..", "###" },
  ["f"] = { "###", "#..", "##.", "#..", "#.." },
  ["g"] = { ".##", "#..", "#.#", "#.#", ".##" },
  ["h"] = { "#.#", "#.#", "###", "#.#", "#.#" },
  ["i"] = { "###", ".#.", ".#.", ".#.", "###" },
  ["j"] = { "..#", "..#", "..#", "#.#", ".#." },
  ["k"] = { "#.#", "#.#", "##.", "#.#", "#.#" },
  ["l"] = { "#..", "#..", "#..", "#..", "###" },
  ["m"] = { "#.#", "###", "###", "#.#", "#.#" },
  ["n"] = { "##.", "#.#", "#.#", "#.#", "#.#" },
  ["o"] = { ".#.", "#.#", "#.#", "#.#", ".#." },
  ["p"] = { "##.", "#.#", "##.", "#..", "#.." },
  ["q"] = { ".#.", "#.#", "#.#", "##.", ".##" },
  ["r"] = { "##.", "#.#", "##.", "#.#", "#.#" },
  ["s"] = { ".##", "#..", ".#.", "..#", "##." },
  ["t"] = { "###", ".#.", ".#.", ".#.", ".#." },
  ["u"] = { "#.#", "#.#", "#.#", "#.#", ".##" },
  ["v"] = { "#.#", "#.#", "#.#", "#.#", ".#." },
  ["w"] = { "#.#", "#.#", "###", "###", "#.#" },
  ["x"] = { "#.#", "#.#", ".#.", "#.#", "#.#" },
  ["y"] = { "#.#", "#.#", ".#.", ".#.", ".#." },
  ["z"] = { "###", "..#", ".#.", "#..", "###" },
  ["0"] = { "###", "#.#", "#.#", "#.#", "###" },
  ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
  ["2"] = { "##.", "..#", ".#.", "#..", "###" },
  ["3"] = { "###", "..#", ".##", "..#", "###" },
  ["4"] = { "#.#", "#.#", "###", "..#", "..#" },
  ["5"] = { "###", "#..", "##.", "..#", "##." },
  ["6"] = { ".##", "#..", "###", "#.#", "###" },
  ["7"] = { "###", "..#", ".#.", ".#.", ".#." },
  ["8"] = { "###", "#.#", "###", "#.#", "###" },
  ["9"] = { "###", "#.#", "###", "..#", "##." },
  [" "] = { "...", "...", "...", "...", "..." },
  ["."] = { "...", "...", "...", "...", ".#." },
  [","] = { "...", "...", "...", ".#.", "#.." },
  [":"] = { "...", ".#.", "...", ".#.", "..." },
  ["!"] = { ".#.", ".#.", ".#.", "...", ".#." },
  ["?"] = { "##.", "..#", ".#.", "...", ".#." },
  ["/"] = { "..#", "..#", ".#.", "#..", "#.." },
  ["-"] = { "...", "...", "###", "...", "..." },
  ["<"] = { "..#", ".#.", "#..", ".#.", "..#" },
  [">"] = { "#..", ".#.", "..#", ".#.", "#.." },
  ["'"] = { ".#.", ".#.", "...", "...", "..." },
  ["("] = { "..#", ".#.", ".#.", ".#.", "..#" },
  [")"] = { "#..", ".#.", ".#.", ".#.", "#.." },
  ["+"] = { "...", ".#.", "###", ".#.", "..." },
  ["="] = { "...", "###", "...", "###", "..." },
}

function print(txt, x, y, c, fixed, scale, smallfont)
  txt = tostring(txt)
  local cx = x
  for i = 1, #txt do
    local ch = string.lower(string.sub(txt, i, i))
    local g = fuente[ch]
    if g == nil then g = fuente["?"] end
    for fila = 1, 5 do
      for col = 1, 3 do
        if string.sub(g[fila], col, col) == "#" then
          mock.pintar(cx + col - 1, y + fila - 1, c or 7)
        end
      end
    end
    cx = cx + 4   -- avance de 4px por caracter (metrica del mock)
  end
  return #txt * 4   -- como tic-80: devolvemos el ancho dibujado
end

-- =====================================================================
-- sprites: hoja de 256 tiles de 8x8 a 4bpp (2 pixeles/byte)
-- =====================================================================

function mock.pixel_tile(id, px, py)
  local datos = mock.tiles[id]
  if datos == nil then return 0 end
  local byte = datos[py * 4 + math.floor(px / 2) + 1]
  if byte == nil then return 0 end
  if px % 2 == 0 then
    return byte % 16        -- pixel izquierdo: nibble bajo
  end
  return math.floor(byte / 16)  -- pixel derecho: nibble alto
end

function spr(id, x, y, colorkey, scale, flip, rotate, w, h)
  -- firma de tic-80: spr(id, x, y, colorkey, scale, flip, rotate, w, h)
  -- el colorkey (color transparente) es explicito; -1 = opaco
  w = w or 1 h = h or 1
  for ty = 0, h - 1 do
    for tx = 0, w - 1 do
      local tile = id + tx + ty * 32   -- la hoja de tic-80 es 32 de ancho
      for py = 0, 7 do
        for px = 0, 7 do
          local c = mock.pixel_tile(tile, px, py)
          if c ~= (colorkey or -1) then
            mock.pintar(x + tx * 8 + px, y + ty * 8 + py, c)
          end
        end
      end
    end
  end
end

-- =====================================================================
-- misc: funciones que existen en tic-80 pero el juego no usa
-- =====================================================================

function trace(msg, c) end
function exit() end
function reset() end
function clip(x, y, w, h) end
function music(...) end
function sfx(...) end
function mget(x, y) return 0 end
function mset(x, y, id) end
function map(...) end
function peek(a) return 0 end
function poke(a, v) end
function memcpy(d, s, n) end
function memset(d, v, n) end
function pmem(i, v) return 0 end
function mouse() return 0, 0, false, false, false, 0, 0 end
function key(i) return false end
function keyp(i) return false end
function fget(id, f) return false end
function fset(id, f, v) end
function time() return mock.reloj_ms end
function tstamp() return 0 end

-- =====================================================================
-- utilidades de prueba: paso de frames y capturas
-- =====================================================================

function mock.tick(solo_logica)
  -- un frame completo del juego. con solo_logica=true se salta el dibujo
  -- (el dibujo software del mock es lento: para tests de fisica basta
  -- con la logica). TIC() normal = logica + dibujo juntos.
  if solo_logica then
    frames_juego = frames_juego + 1
    if arrancado then
      estados[estado].update()
    end
  else
    TIC()
  end
  mock.reloj_ms = mock.reloj_ms + 1000 / 60
  -- al TERMINAR el frame, el estado de los botones pasa a ser "el previo"
  -- (asi btnp detecta el flanco de pulsacion)
  for i = 0, 7 do
    mock.boton_prev[i] = mock.boton[i]
    if mock.boton[i] == nil then mock.boton[i] = false end
  end
end

function mock.dump_ppm(ruta)
  -- escribe la pantalla como pnm (p6) para convertirla a png
  local partes = {}
  for y = 0, 135 do
    for x = 0, 239 do
      local rgb = mock.paleta_rgb[mock.fb[y * 240 + x]] or { 0, 0, 0 }
      partes[#partes + 1] = string.char(rgb[1], rgb[2], rgb[3])
    end
  end
  local f = io.open(ruta, "wb")
  f:write("P6\n240 136\n255\n")
  f:write(table.concat(partes))
  f:close()
end
