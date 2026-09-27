-- ===========================================================================
-- 05_viento.lua - ráfagas de viento y hojas indicadoras
-- ===========================================================================
-- el viento es la mecánica nueva de la zona 2 (y sigue en la zona 3):
-- empuja al jugador HORIZONTALMENTE mientras está en el aire.
--
-- regla de diseño importante: el viento NO empuja con los pies en el
-- suelo. así el suelo sigue siendo "lugar seguro" y el reto aparece solo
-- al saltar, que es donde el jugador ya está comprometido.
--
-- cada tramo de viento es un rectángulo del mundo con dirección e
-- intensidad propias. las hojas que vuelan dentro del rectángulo son el
-- indicador visual PREVIO: el jugador ve hacia dónde sopla antes de saltar.
-- ===========================================================================

vientos = {}   -- zonas de viento del nivel (las llena 09_datos_nivel)
hojas   = {}   -- partículas-hoja: el "anuncio" visual del viento

-- -- constructor ----------------------------------------------------------
-- viento(x, y, w, h, dir, fuerza, fase)
--   dir    = 1 empuja a la derecha, -1 a la izquierda
--   fuerza = aceleración extra en px/frame2 mientras se está dentro
--   fase   = desfase del ciclo de ráfagas (0..1)
--
-- ¿por qué la fase es un parámetro y no rnd(1)?
--   porque forma parte del DISEÑO del nivel: cada tramo tiene su ciclo y
--   así el reto es siempre el mismo (además, este constructor se ejecuta
--   al cargar el cartucho, antes de srand(), donde rnd no sería estable).

function viento(x, y, w, h, dir, fuerza, fase)
  vientos[#vientos + 1] = {
    x = x, y = y, w = w, h = h,
    dir = dir,
    fuerza = fuerza,
    fase = fase,
  }
end

-- -- bloque clave 2 de 3: el viento sobre la velocidad en el aire ---------
-- ===========================================================================
-- ¿por qué solo en el aire?
--   1) es la mecánica que enseña la zona 2: "saltar en contra del viento".
--   2) en el suelo la fricción ya frena al jugador; aplicar viento ahí
--      solo generaría forcejeos confusos contra el terreno.
--
-- ¿por qué una ráfaga variable y no una fuerza fija?
--   con sin(t) la fuerza oscila entre el 60% y el 100% de su valor: el
--   empuje "respire" y cada salto se siente un poco distinto, pero sin
--   sorpresas injustas (la dirección nunca cambia dentro de un tramo).
--
-- se suma como aceleración a player.dx (no como velocidad fija) para que
-- el jugador pueda CORREGIR en contra, gastando su control aéreo.
-- ===========================================================================

function update_viento()
  -- con los pies en el suelo el viento no empuja (regla del diseño)
  if player.on_ground then
    return
  end

  for i = 1, #vientos do
    local v = vientos[i]
    if solapan(player.x, player.y, player.w, player.h, v.x, v.y, v.w, v.h) then
      -- ciclo de ráfaga: 0.6 + 0.4*sin(...) oscila entre 0.6 y 1.0
      -- (sin de tic-80 trabaja en "vueltas", no en radianes)
      local intensidad = v.fuerza * (0.6 + 0.4 * sin(t() * 0.35 + v.fase))
      player.dx = player.dx + v.dir * intensidad
    end
  end

  -- tope de velocidad con viento: puede superar vel_max (el viento gana),
  -- pero nunca tanto como para que el jugador se convierta en un proyectil
  player.dx = mid(-vel_viento_max, player.dx, vel_viento_max)
end

-- -- hojas indicadoras ----------------------------------------------------
-- una hoja por cada ~24px de ancho del tramo, siempre dentro del
-- rectángulo del viento. se mueven en su dirección y revolotean con sin.

function crear_hojas()
  hojas = {}
  for i = 1, #vientos do
    local v = vientos[i]
    local cantidad = flr(v.w * v.h / 900)   -- densidad aproximada
    for j = 1, cantidad do
      hojas[#hojas + 1] = {
        x = v.x + rnd(v.w),
        y = v.y + rnd(v.h),
        v = v,                    -- referencia al tramo: sabe hacia dónde volar
        fase = rnd(1),            -- desfase del revoloteo
        velocidad = 0.4 + rnd(0.8),
      }
    end
  end
end

function reset_hojas()
  crear_hojas()
end

function update_hojas()
  for i = 1, #hojas do
    local h = hojas[i]
    local v = h.v
    -- vuelan con el viento (más rápido cuanto más cerca del "soplo" base)
    h.x = h.x + v.dir * h.velocidad * (0.6 + 0.4 * sin(t() * 0.35 + v.fase))
    -- revoloteo vertical: el movimiento senoidal da sensación de brisa
    h.y = h.y + sin(t() * 0.8 + h.fase) * 0.35

    -- si sale de su tramo, reaparece en el borde contrario:
    -- así la corriente de hojas es continua
    if h.x < v.x then
      h.x = v.x + v.w
      h.y = v.y + rnd(v.h)
    elseif h.x > v.x + v.w then
      h.x = v.x
      h.y = v.y + rnd(v.h)
    end
    if h.y < v.y then
      h.y = v.y + v.h
    elseif h.y > v.y + v.h then
      h.y = v.y
    end
  end
end

function dibujar_hojas()
  -- color de la hoja según la zona: hoja seca amarilla en el bosque
  -- seco, hoja verde-grisácea en el bosque nublado
  for i = 1, #hojas do
    local h = hojas[i]
    local z = zona_de_y(h.y)
    pset(h.x, h.y, paletas[z].hoja)
    pset(h.x + 1, h.y, paletas[z].hoja)   -- 2px: se lee mejor en movimiento
  end
end
