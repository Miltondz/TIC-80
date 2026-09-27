-- ===========================================================================
-- 06_niebla.lua - el círculo de visión de la cima (bloque clave 3 de 3)
-- ===========================================================================
-- la niebla de la zona 3 lo cubre todo menos un círculo de aire limpio
-- alrededor del jugador (un "círculo de luz"). al llegar a la cima el
-- círculo crece poco a poco y la niebla se disipa: ese es el final.
--
-- ¿por qué es complicado?
--   porque tic-80 no tiene recortes con forma de círculo ni alfa por
--   píxel: hay que CONSTRUIR el efecto dibujando la niebla a mano,
--   dejando hueco el círculo.
-- ===========================================================================

niebla_color = 6      -- gris claro: la bruma del bosque nublado
niebla_activa = false -- la encienden zona3 / final
niebla_radio = radio_niebla_base  -- radio del círculo limpio (crece al final)

-- -- bloque clave: el cálculo del radio de visión -------------------------
-- ===========================================================================
-- idea general: la niebla es "toda la pantalla menos un círculo centrado
-- en el jugador". como no podemos recortar un círculo, pintamos la niebla
-- POR FRANJAS HORIZONTALES de 2px, y en cada franja dejamos un hueco.
--
-- para una franja a distancia vertical dy del centro, la ecuación del
-- círculo (x - px)2 + (y - py)2 = r2 nos dice hasta qué distancia
-- horizontal llega el aire limpio:
--
--     dx = sqrt(r2 - dy2)
--
-- el borde no se corta en seco: hay una banda de degradado de grosor
-- `niebla_suave` alrededor del círculo, con dos radios:
--
--     a = sqrt((r_int)2 - dy2)      r_int = radio - suave  (fin del aire)
--     b = sqrt((r_ext)2 - dy2)      r_ext = radio + suave  (inicio sólido)
--
-- y la franja se pinta en tres tramos (y su espejo derecho):
--
--     |dx| < a        -> aire limpio (no se pinta)
--     a <= |dx| <= b    -> degradado: trama de damero al 50%
--     |dx| > b        -> niebla sólida
--
-- el damero se hace pintando celdas de 2x2 a cuadros (la "trama de puntos"
-- clásica de tic-80, pero a mano para poder controlarla).
--
-- coste: 64 franjas x 2 raíces cuadradas; el resto son rectfill y pset.
-- ===========================================================================

function draw_niebla()
  -- centro del efecto: el jugador, en coordenadas de PANTALLA
  -- (el dibujo del mundo usa camera(0, cam_y); la niebla se dibuja
  -- con la cámara a cero, así que restamos cam_y a mano)
  local px = player.x + player.w / 2
  local py = player.y + player.h / 2 - cam_y

  local r_ext = niebla_radio + niebla_suave
  local r_int = max(0, niebla_radio - niebla_suave)

  -- optimización: si el radio interior ya cubre la pantalla entera
  -- (la diagonal media es ~90px), no hay nada que pintar
  if r_int > 140 then
    return
  end

  local alto_franja = 2   -- una franja = una fila de celdas del damero

  for y = 0, 135, alto_franja do
    -- distancia vertical desde el centro del jugador al centro de la franja
    local dy = y + alto_franja / 2 - py

    local b2 = r_ext * r_ext - dy * dy
    if b2 <= 0 then
      -- la franja entera está fuera del halo: niebla sólida
      rectfill(0, y, 239, y + alto_franja - 1, niebla_color)
    else
      local b = sqrt(b2)                    -- semi-ancho exterior del halo
      local a = 0
      local a2 = r_int * r_int - dy * dy
      if a2 > 0 then
        a = sqrt(a2)                        -- semi-ancho del aire limpio
      end

      -- tramos sólidos a izquierda y derecha del degradado
      local izq = flr(px - b)
      local der = flr(px + b)
      if izq > 0 then
        rectfill(0, y, izq - 1, y + alto_franja - 1, niebla_color)
      end
      if der < 239 then
        rectfill(der + 1, y, 239, y + alto_franja - 1, niebla_color)
      end

      -- tramos de degradado: celdas de 2x2 pintadas a cuadros.
      -- (flr(x/2) + flr(y/2)) % 2 decide si la celda lleva niebla:
      -- es el damero clásico de tic-80, calculado a mano.
      local x_ini = flr((px - b) / 2) * 2
      local x_fin_izq = flr(px - a)
      local x_ini_der = flr(px + a)
      local x_fin = flr((px + b) / 2) * 2 + 1

      local x = x_ini
      while x <= x_fin do
        -- solo pintamos dentro de las bandas de degradado
        if x <= x_fin_izq or x >= x_ini_der then
          if (flr(x / 2) + flr(y / 2)) % 2 == 0 then
            rectfill(x, y, x + 1, y + alto_franja - 1, niebla_color)
          end
        end
        x = x + 2
      end
    end
  end
end

-- -- actualización --------------------------------------------------------
-- en la zona 3 el radio "respira" muy despacio: da vida a la bruma
-- sin cambiar el reto. el crecimiento grande lo controla 10_estados.lua
-- durante la secuencia final.

function update_niebla()
  niebla_radio = radio_niebla_base + 2 * sin(t() * 0.5)
end
