-- ===========================================================================
-- 03_plataformas.lua - tipos de plataforma y su estado
-- ===========================================================================
-- cada plataforma es un rectángulo sólido con un tipo:
--
--   "normal"      roca estable (nada especial)
--   "rompible"    se rompe poco después de ser PISADA (bloque clave 1)
--   "resbaladiza" cubierta de musgo: fricción reducida (ver 02_jugador.lua)
--
-- el estado solo cambia en las rompibles:
--
--   "entera"    -> intacta, se puede pisar
--   "temblando" -> pisada: cuenta regresiva, tiembla y suena (visualmente)
--   "rota"      -> desaparecida; deja de ser sólida hasta el reset
-- ===========================================================================

plataformas = {}   -- todas las plataformas del nivel (las llena 09_datos_nivel)
escombros  = {}    -- partículas de las plataformas al romperse

-- -- constructores: hacen el nivel legible casi como pseudocódigo ---------
-- (se usan desde 09_datos_nivel.lua)

function plataforma(x, y, w, tipo)
  plataformas[#plataformas + 1] = {
    x = x, y = y,
    w = w, h = 8,                -- 8px de grosor: un sprite de alto
    tipo = tipo or "normal",
    estado = "entera",           -- solo lo usan las rompibles
    temporizador = 0,            -- frames restantes antes de romperse
  }
end

function rompible(x, y, w)  plataforma(x, y, w, "rompible")     end
function musgo(x, y, w)     plataforma(x, y, w, "resbaladiza")   end
function suelo(x, y, w)     plataforma(x, y, w, "normal")        end

-- -- bloque clave 1 de 3: el temporizador de las rompibles ---------------
-- ===========================================================================
-- ¿por qué un temporizador y no romperla al instante?
--   porque el objetivo didáctico de la zona 1 es enseñar a NO quedarse
--   quieto. con unos frames de margen el jugador entiende la causa-efecto
--   ("la pisé, tiembla, se va a caer") en lugar de sentirlo como trampa.
--
-- ¿por qué arranca al PRIMER CONTACTO y no al cargar la zona?
--   porque así el reto es del jugador: la cuenta solo corre mientras él
--   está usando la plataforma. además permite saltar de rompible a
--   rompible sin que se rompan "por sistema" detrás de la cámara.
--
-- la transición es:  entera --(pie encima)--> temblando --(0 frames)--> rota
-- ===========================================================================

function update_plataformas()
  for i = 1, #plataformas do
    local p = plataformas[i]

    if p.tipo == "rompible" then
      if p.estado == "entera" then
        -- ¿el jugador acaba de pisarla? (player.bajo_pies la fija 02_jugador)
        if player.bajo_pies == p then
          -- primer contacto: arranca la cuenta regresiva
          p.estado = "temblando"
          p.temporizador = frames_antes_de_romper
        end

      elseif p.estado == "temblando" then
        p.temporizador = p.temporizador - 1
        if p.temporizador <= 0 then
          -- se rompe: deja de ser sólida y escupe escombros
          p.estado = "rota"
          crear_escombros(p)
        end
      end
    end
  end
end

-- las rompibles vuelven a "entera" al reaparecer (llama morir())
function reset_plataformas()
  for i = 1, #plataformas do
    local p = plataformas[i]
    p.estado = "entera"
    p.temporizador = 0
  end
end

-- -- escombros: feedback visual al romperse (pura jugosidad, sin lógica) --

function crear_escombros(p)
  -- 6 trocitos que salen despedidos y caen: hacen visible la rotura
  for i = 1, 6 do
    escombros[#escombros + 1] = {
      x = p.x + rnd(p.w),
      y = p.y,
      dx = rnd(1.6) - 0.8,
      dy = -rnd(1.6),
      vida = 30,               -- frames hasta desaparecer
    }
  end
end

function reset_escombros()
  escombros = {}
end

function update_escombros()
  for i = #escombros, 1, -1 do
    local e = escombros[i]
    e.x = e.x + e.dx
    e.y = e.y + e.dy
    e.dy = e.dy + gravedad
    e.vida = e.vida - 1
    -- borrar el primero que se agote (recorremos al revés para no saltar)
    if e.vida <= 0 then
      deli(escombros, i)
    end
  end
end

-- -- dibujo ---------------------------------------------------------------
-- los colores de la plataforma cambian según la altura (cada zona tiene
-- su suelo: arena, tierra con musgo, roca gris): ver 08_fondo.lua

function dibujar_plataformas()
  for i = 1, #plataformas do
    local p = plataformas[i]
    if p.estado ~= "rota" then
      local z = zona_de_y(p.y)
      local cuerpo, borde = paletas[z].plata_cuerpo, paletas[z].plata_borde

      if p.tipo == "resbaladiza" then
        -- musgo: cuerpo de roca con borde verde brillante
        cuerpo, borde = paletas[z].plata_cuerpo, 11
      end

      -- temblor: desplazamos 1px el dibujo (no la colisión) mientras
      -- cuenta el temporizador, como señal visual de "esto se va a caer"
      local offset_x = 0
      if p.estado == "temblando" then
        offset_x = sin(t() * 2) * 1.5   -- vaivén rápido de ±1.5px
      end

      -- cuerpo + línea superior más clara (el "canto" que da volumen)
      rectfill(p.x + offset_x, p.y, p.x + p.w - 1 + offset_x, p.y + p.h - 1, cuerpo)
      rectfill(p.x + offset_x, p.y, p.x + p.w - 1 + offset_x, p.y, borde)

      -- las rompibles enseñan sus grietas incluso antes de pisarlas,
      -- para que el jugador pueda LEER qué plataformas son frágiles
      if p.tipo == "rompible" and p.estado ~= "rota" then
        local grieta = p.x + flr(p.w / 2) + offset_x
        line(grieta, p.y + 1, grieta - 2, p.y + p.h - 1, cuerpo)
        line(grieta + 3, p.y + 1, grieta + 1, p.y + p.h - 1, cuerpo)
      end
    end
  end
end

function dibujar_escombros()
  -- trozos de roca del color del cuerpo de la zona
  for i = 1, #escombros do
    local e = escombros[i]
    local z = zona_de_y(e.y)
    rectfill(e.x, e.y, e.x + 1, e.y + 1, paletas[z].plata_cuerpo)
  end
end
