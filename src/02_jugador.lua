-- ===========================================================================
-- 02_jugador.lua - la tabla player: input, física y colisiones
-- ===========================================================================
-- este es el motor del juego: todo lo demás (viento, musgo, rompibles)
-- se cuelga de estas decisiones de movimiento.
--
-- convención: player.x / player.y son la esquina superior izquierda de la
-- CAJA DE COLISIÓN (jugador_ancho x jugador_alto). el sprite de 8x8 se
-- dibuja 1px más a la izquierda para centrarlo sobre la caja.
-- ===========================================================================

player = {
  x = 0, y = 0,          -- posición (esquina sup-izq de la caja de colisión)
  dx = 0, dy = 0,        -- velocidad en px/frame
  w = jugador_ancho,
  h = jugador_alto,
  on_ground = false,     -- ¿tiene los pies en una plataforma?
  bajo_pies = nil,       -- plataforma que está pisando (para musgo/rompibles)
  mira = 1,              -- hacia dónde mira el sprite: 1 = derecha, -1 = izquierda
  checkpoint = 1,        -- índice del ÚLTIMO checkpoint tocado
  invuln = 0,            -- frames de gracia tras un golpe (parpadea al dibujar)
  anim = 0,              -- acumulador para animar las piernas al correr
}

-- -- utilidades de colisión AABB (caja contra caja) ----------------------

function solapan(x1, y1, w1, h1, x2, y2, w2, h2)
  -- dos rectángulos se solapan si sus intervalos se cruzan en ambos ejes.
  -- se usa estricto (<) para que dos cajas pegadas ("besándose") NO cuenten:
  -- así el jugador puede rozar el borde de una plataforma sin atascarse.
  return x1 < x2 + w2 and x2 < x1 + w1
     and y1 < y2 + h2 and y2 < y1 + h1
end

-- -- input + física -------------------------------------------------------

function update_jugador()
  -- 1) aceleración horizontal según el input (izq / der)
  --    en el suelo se acelera fuerte; en el aire, más suave (control aéreo).
  local acel = acel_aire
  if player.on_ground then
    acel = acel_suelo
    -- sobre musgo la aceleración también baja: cuesta "agarrar" el suelo
    if player.bajo_pies and player.bajo_pies.tipo == "resbaladiza" then
      acel = acel_musgo
    end
  end

  if btn(IZQ) then                       -- izq izquierda
    player.dx = player.dx - acel
    player.mira = -1
  end
  if btn(DER) then                       -- der derecha
    player.dx = player.dx + acel
    player.mira = 1
  end

  -- 2) fricción cuando NO hay input: el suelo frena, el aire apenas deriva.
  if not btn(IZQ) and not btn(DER) then
    local friccion = frenado_aire
    if player.on_ground then
      friccion = frenado
      -- musgo = fricción reducida: el jugador sigue deslizando
      if player.bajo_pies and player.bajo_pies.tipo == "resbaladiza" then
        friccion = frenado_musgo
      end
    end
    player.dx = player.dx * friccion
  end

  -- 3) tope de velocidad horizontal caminando.
  --    (el viento puede superarlo puntualmente: se limita aparte en 05)
  player.dx = mid(-vel_max, player.dx, vel_max)

  -- 4) salto: un solo botón de acción (A o B), sin doble salto.
  --    btnp = "recién pulsado" (flanco), para no saltar seguido al mantener.
  if (btnp(BTN_A) or btnp(BTN_B)) and player.on_ground then
    player.dy = salto_vy
    player.on_ground = false
  end

  -- 5) gravedad, con velocidad de caída máxima.
  --    el tope evita que en caídas largas el jugador atraviese plataformas
  --    de 8px de grosor entre dos frames (un clásico del "tunneling").
  player.dy = player.dy + gravedad
  if player.dy > vel_caida_max then
    player.dy = vel_caida_max
  end

  -- 6) mover por ejes y resolver colisiones: primero x, después y.
  --    mover por ejes por separado permite saber contra qué lado chocamos
  --    (si moviéramos en diagonal no sabríamos si aterrizar o rebotar).
  mover_jugador_x()
  mover_jugador_y()

  -- 7) animación: acumula velocidad para balancear las piernas al correr
  player.anim = player.anim + abs(player.dx) * 0.12

  -- 8) frames de gracia tras un golpe (los usa 04_hazards.lua)
  if player.invuln > 0 then
    player.invuln = player.invuln - 1
  end
end

-- -- colisiones contra plataformas ----------------------------------------

function mover_jugador_x()
  player.x = player.x + player.dx

  for i = 1, #plataformas do
    local p = plataformas[i]
    -- una plataforma "rota" deja de ser sólida al instante
    if p.estado ~= "rota"
      and solapan(player.x, player.y, player.w, player.h, p.x, p.y, p.w, p.h) then
      if player.dx > 0 then
        -- chocamos con la cara izquierda de la plataforma
        player.x = p.x - player.w
      elseif player.dx < 0 then
        -- chocamos con la cara derecha
        player.x = p.x + p.w
      end
      player.dx = 0
    end
  end

  -- el mundo es angosto: no se sale por los lados
  player.x = mid(0, player.x, mundo_ancho - player.w)
end

function mover_jugador_y()
  player.y = player.y + player.dy
  player.on_ground = false
  player.bajo_pies = nil

  for i = 1, #plataformas do
    local p = plataformas[i]
    if p.estado ~= "rota"
      and solapan(player.x, player.y, player.w, player.h, p.x, p.y, p.w, p.h) then
      if player.dy > 0 then
        -- estábamos cayendo: aterrizamos ENCIMA de la plataforma
        player.y = p.y - player.h
        player.dy = 0
        player.on_ground = true
        -- guardamos QUÉ plataforma pisamos: la necesitan 03 (rompibles)
        -- y el propio update (fricción del musgo)
        player.bajo_pies = p
      elseif player.dy < 0 then
        -- estábamos subiendo: nos golpeamos con el techo de la plataforma
        player.y = p.y + p.h
        player.dy = 0
      end
    end
  end
end

-- -- muerte y reaparición -------------------------------------------------
-- no hay vidas ni game over: morir es solo un retroceso local al último
-- checkpoint, con el estado de la zona reseteado.

function morir()
  -- las plataformas rotas vuelven a su estado inicial (decisión de diseño:
  -- el reto de una zona se re-intenta entero tras cada caída)
  reset_plataformas()
  reset_escombros()
  colocar_en_checkpoint()
  mostrar_mensaje("vuelves al ultimo checkpoint", 72)
end

function colocar_en_checkpoint()
  -- reaparece exactamente donde tocó el último checkpoint
  local cp = checkpoints[player.checkpoint]
  player.x = cp.x
  player.y = cp.y
  player.dx, player.dy = 0, 0
  player.on_ground = false
  player.bajo_pies = nil
  player.invuln = 30
  -- la cámara vuelve con el jugador de golpe (no hay scroll de bajada:
  -- ver actualizar_camara en 10_estados.lua)
  cam_y = mid(0, cp.y - cam_altura_jugador, mundo_alto - 136)
end

-- -- dibujo ---------------------------------------------------------------

function dibujar_jugador()
  -- parpadeo durante la invulnerabilidad: no dibujar en algunos frames
  -- da la sensación de "destello" sin necesidad de transparencias
  if player.invuln > 0 and flr(player.invuln / 4) % 2 == 1 then
    return
  end

  -- selección de frame:
  --   en el aire  -> sprite de salto
  --   en movimiento -> dos frames de corrida alternados con player.anim
  --   quieto -> sprite idle
  local frame = 1
  if not player.on_ground then
    frame = 4
  elseif abs(player.dx) > 0.3 then
    if flr(player.anim / 3) % 2 == 0 then
      frame = 2
    else
      frame = 3
    end
  end

  -- el sprite se dibuja 1px a la izq para centrarlo en la caja (w=6)
  -- y se refleja con flip_x según player.mira
  spr(frame, player.x - 1, player.y, 1, 1, player.mira < 0)
end
