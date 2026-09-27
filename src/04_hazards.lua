-- ===========================================================================
-- 04_hazards.lua - cardones (knockback) y la muerte por caída
-- ===========================================================================
-- dos formas de "perder" en este juego, ninguna castiga de verdad:
--
--   cardón  -> empuja al jugador (knockback), no mata ni resetea nada.
--              castiga quedarse quieto cerca de las púas.
--   caída   -> salir por el borde inferior de la cámara es precipicio:
--              muerte simbólica = reaparición en el último checkpoint.
--
-- no hay enemigos con ia (fuera de alcance): los cardones son obstáculos
-- fijos del matorral desértico, como en la vida real.
-- ===========================================================================

hazards   = {}   -- cardones con colisión (los llena 09_datos_nivel)
decorados = {}   -- cardones de fondo, sin colisión: solo paisaje

-- -- constructores --------------------------------------------------------
-- cardon(x, y): el cardón ocupa 8x16 con la esquina superior en (x, y).
-- decorado(x, y): igual pero sin hitbox (detrás del terreno).

function cardon(x, y)
  hazards[#hazards + 1] = { x = x, y = y, w = 8, h = 16 }
end

function decorado(x, y)
  decorados[#decorados + 1] = { x = x, y = y }
end

-- -- colisión con cardones: knockback, sin muerte -------------------------

function update_hazards()
  for i = 1, #hazards do
    local h = hazards[i]
    -- la hitbox es algo más pequeña que el sprite: las puntas del dibujo
    -- no deberían chocar "por accidente"
    if player.invuln <= 0
      and solapan(player.x, player.y, player.w, player.h, h.x + 1, h.y + 4, 6, 12) then

      -- knockback: se empuja hacia ATRÁS respecto del centro del cardón
      -- y un poco hacia arriba, para que el golpe se sienta pero el
      -- jugador no pierda lo que ya subió
      local centro_jugador = player.x + player.w / 2
      local centro_cardon  = h.x + h.w / 2
      if centro_jugador < centro_cardon then
        player.dx = -2.2
      else
        player.dx = 2.2
      end
      player.dy = -1.8

      -- frames de gracia: sin esto, el jugador volvería a chocar en el
      -- frame siguiente y quedaría atrapado en el cardón
      player.invuln = 40
    end
  end
end

function dibujar_hazards()
  for i = 1, #hazards do
    local h = hazards[i]
    -- 8x16 = dos tiles verticales: spr(id, x, y, w_en_tiles, h_en_tiles)
    spr(6, h.x, h.y, 1, 2)
  end
end

function dibujar_decorados()
  -- los decorados son el cardón en tonos de fondo ("apagado"): la hoja
  -- de sprites trae esa copia ya recoloreada (ids 54/86), porque tic-80
  -- no tiene pal() para remapear colores al dibujar.
  -- así el mismo diseño sirve para el hazard (nítido) y el paisaje.
  for i = 1, #decorados do
    local d = decorados[i]
    spr(54, d.x, d.y, 1, 2)
  end
end

-- -- comprobación de precipicio -------------------------------------------
-- la cámara no sigue las caídas (ver actualizar_camara), así que caer
-- mucho es literalmente "irse por el borde de la pantalla": ahí cortamos.

function comprobar_caida()
  if player.y > cam_y + margen_caida then
    morir()
  end
end
