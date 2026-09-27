-- ===========================================================================
-- 07_siluetas.lua - las siluetas de la familia (capa narrativa)
-- ===========================================================================
-- la inspiración del juego (una subida real en familia) se cuenta solo
-- con figuras de fondo: una por zona, más una en la cima para el cierre.
--
-- reglas de diseño (así se definió el prototipo):
--   * sprites SIN colisión y SIN lógica de ia: no bloquean ni interactúan.
--   * animación mínima de 1-2 frames: mirar el paisaje, saludar, descansar.
--   * se dibujan en la capa de fondo, detrás del terreno jugable.
--
-- no hay diálogo ni misión con ellas: el jugador las descubre al subir.
-- ===========================================================================

siluetas = {}   -- las llena 09_datos_nivel

-- -- constructor ----------------------------------------------------------
-- silueta(x, y, pose): y es la esquina superior del sprite de 8x16;
-- para que "esté de pie" sobre una plataforma de y=p.y, se pasa y = p.y-16.
-- pose: "mirando" | "saludando" | "sentado"

function silueta(x, y, pose)
  siluetas[#siluetas + 1] = {
    x = x, y = y,
    pose = pose,
    -- desfase de animación derivado del orden: cada silueta anima a su
    -- ritmo sin necesidad de rnd (este constructor corre al cargar el
    -- cartucho, antes de srand(), donde rnd no sería estable)
    fase = #siluetas * 0.37,
  }
end

-- -- dibujo ---------------------------------------------------------------
-- se dibujan con camera() ya activa (coordenadas de mundo), justo ANTES
-- de las plataformas: quedan detrás del terreno jugable.
--
-- nota del puerto: pico-8 recoloreaba el sprite con pal(1, color), pero
-- tic-80 no tiene pal(). en su lugar, la hoja de sprites trae una copia
-- GRIS de cada silueta (ids 48-84) para la zona 3, donde la figura debe
-- "perderse" en la bruma. simple, rápido y sin memoria de paletas.

function dibujar_siluetas()
  for i = 1, #siluetas do
    local s = siluetas[i]
    local gris = zona_de_y(s.y) == 3   -- la niebla pide siluetas grises

    if s.pose == "saludando" then
      -- 2 frames alternados: brazo arriba / brazo más alto
      local frame = 10        -- azul marino (11 = segundo frame)
      if gris then frame = 50 end   -- gris (51 = segundo frame)
      if (flr(t() * 2 + s.fase) % 2) == 0 then
        frame = frame + 1
      end
      spr(frame, s.x, s.y, 1, 2)

    elseif s.pose == "sentado" then
      -- 1 frame fijo (está descansando mirando el paisaje)
      if gris then
        spr(52, s.x, s.y, 1, 2)
      else
        spr(12, s.x, s.y, 1, 2)
      end

    else
      -- "mirando": 1 frame con un balanceo mínimo (respiración),
      -- 1px arriba y abajo: animación casi imperceptible a propósito
      local bob = 0
      if sin(t() * 0.3 + s.fase) > 0.6 then
        bob = -1
      end
      if gris then
        spr(48, s.x, s.y + bob, 1, 2)
      else
        spr(8, s.x, s.y + bob, 1, 2)
      end
    end
  end
end
