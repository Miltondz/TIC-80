-- title: cumbre santa ana
-- author: miltondz
-- desc: una subida en familia por el cerro santa ana (paraguaná)
-- site: https://github.com/Miltondz/TIC-80
-- license: MIT
-- version: 1.0
-- script: lua

-- ===========================================================================
-- cumbre santa ana - versión tic-80
-- ===========================================================================
-- este es el mismo juego que la versión pico-8 del proyecto, portado a
-- tic-80: un plataformero de ascenso vertical corto por el cerro santa ana
-- (paraguaná, venezuela), con la subida en familia como capa narrativa.
--
-- es un proyecto de aprendizaje: el código está comentado para leerse como
-- una guía. se prioriza la claridad sobre el golf de código.
--
-- -- mapa del código ------------------------------------------------------
--   01_config.lua       compatibilidad tic-80/pico-8 + constantes
--   02_jugador.lua      tabla player: input, física y colisiones
--   03_plataformas.lua  tipos de plataforma + temporizador de rotura
--   04_hazards.lua      cardones (knockback) y muerte por caída
--   05_viento.lua       ráfagas en el aire + hojas indicadoras
--   06_niebla.lua       el círculo de visión de la cima
--   07_siluetas.lua     las siluetas de la familia
--   08_fondo.lua        cielo, colinas con parallax, panorama final
--   09_datos_nivel.lua  el nivel entero como lista legible
--   10_estados.lua      máquina de estados: menu/zonas/final
--   11_main.lua         TIC()/BOOT y utilidades
--
-- -- diferencias con la versión pico-8 ------------------------------------
--   * pantalla: 240x136 (pico-8: 128x128) -> el nivel es más ancho, con
--     zigzag de 3 columnas en lugar de 2 (¡mismo tipo de saltos!)
--   * api: tic-80 no tiene camera() ni pal(); hay una capa de
--     compatibilidad en 01_config.lua para que el resto se lea igual
--   * controles: izqder mover, y A/B (botones 4/5) para saltar y confirmar
-- ===========================================================================

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

-- ===========================================================================
-- 08_fondo.lua - cielo, colinas con parallax y el panorama de la cima
-- ===========================================================================
-- el fondo cambia solo al subir: cada zona del cerro tiene su paleta.
-- no hay un "mapa de fondo" dibujado: las colinas se generan con senos
-- y las bandas de cielo se eligen por la altura de la cámara.
--
-- paletas (usamos la paleta clásica de 16 colores; ver build_cart.py,
-- que graba estos mismos índices en la paleta del cartucho):
--   zona 1 base (matorral desértico): cielo azul, dunas naranjas, arena
--   zona 2 bosque seco:               cielo calido-gris, verdes apagados
--   zona 3 bosque nublado:            azules y grises, roca gris
-- ===========================================================================

paletas = {
  -- zona 1: matorral desértico (arena, ocre, cielo azul)
  {
    cielo      = 12,   -- azul del cielo
    sol        = 10,   -- sol amarillo
    colina_lej = 9,    -- dunas lejanas (naranja)
    colina_cer = 4,    -- ladera cercana (marrón)
    plata_cuerpo = 4,  -- roca: marrón
    plata_borde  = 15, -- canto: arena/piel (como la arena iluminada)
    silueta = 1,       -- azul marino: silueta a contraluz
    hoja = 10,         -- hoja seca amarilla
    niebla = 6,
  },
  -- zona 2: bosque seco (verdes apagados, más vegetación)
  {
    cielo      = 6,    -- cielo lavado (gris claro)
    sol        = 9,
    colina_lej = 3,    -- arboleda lejana (verde oscuro apagado)
    colina_cer = 11,   -- matorral cercano (verde)
    plata_cuerpo = 4,  -- tierra
    plata_borde  = 3,  -- canto: hierba seca oscura
    silueta = 1,
    hoja = 9,          -- hoja otoñal naranja
    niebla = 6,
  },
  -- zona 3: bosque nublado (grises y azulados, bruma)
  {
    cielo      = 1,    -- azul pizarra
    sol        = 7,
    colina_lej = 5,    -- picos entre la niebla (gris oscuro)
    colina_cer = 6,    -- roca húmeda (gris claro)
    plata_cuerpo = 5,  -- roca gris
    plata_borde  = 6,  -- canto claro (humedad)
    silueta = 5,       -- silueta gris sobre gris: casi se pierde en la bruma
    hoja = 11,
    niebla = 6,
  },
}

-- ¿a qué zona pertenece una y del mundo? (usado por casi todo el dibujo)
function zona_de_y(y)
  if y > limite_zona2 then
    return 1
  elseif y > limite_zona3 then
    return 2
  end
  return 3
end

-- -- cielo en bandas ------------------------------------------------------
-- bandas de 16px (9 bandas para los 136px de alto). cada banda elige su
-- color según la ALTURA del mundo que representa (cam_y + su posición en
-- pantalla): así el cielo va pasando de la calidez de la base al gris de
-- la cima sin cortes.

function dibujar_cielo()
  for y = 0, 135, 16 do
    local z = zona_de_y(cam_y + y)
    rectfill(0, y, 239, y + 15, paletas[z].cielo)
  end

  -- el sol / la luna: un círculo fijo en el cielo, más alto al subir
  local z = zona_de_y(cam_y)
  local sol_y = 18 + cam_y * 0.02
  circfill(180, sol_y - cam_y, 7, paletas[z].sol)
end

-- -- colinas con parallax -------------------------------------------------
-- dos capas de colinas senoidales. el parallax es vertical: la capa
-- lejana se mueve más lento que la cámara (factor 0.35 vs 0.65), lo que
-- da profundidad sin necesidad de un mapa de fondo.

function dibujar_colinas(color, amplitud, base_pantalla, factor, fase)
  -- base_pantalla: altura media de la cresta en la pantalla
  -- factor: 0 = fija en pantalla, 1 = se mueve con el mundo
  local desplaza = cam_y * factor
  for x = 0, 240, 4 do
    -- la cresta ondula con dos senos de distinta frecuencia (más orgánico
    -- que un solo seno) y se desplaza con la cámara
    local cresta = base_pantalla
        + sin(x * 0.012 + fase + desplaza * 0.004) * amplitud
        + sin(x * 0.031 + fase * 1.7) * amplitud * 0.35
    -- se rellena desde la cresta hasta el borde inferior de la pantalla
    rectfill(x, cresta, x + 3, 135, color)
  end
end

function dibujar_fondo()
  dibujar_cielo()
  -- capa lejana primero (más clara/lejana) y la cercana encima
  local z = zona_de_y(cam_y)
  dibujar_colinas(paletas[z].colina_lej, 10, 80, 0.35, 0)
  dibujar_colinas(paletas[z].colina_cer, 16, 104, 0.65, 0.7)
end

-- -- panorama de la cima: el "mar de dunas" de la península ---------------
-- se revela al disiparse la niebla de la secuencia final: dunas suaves
-- vistas desde arriba, con el sol alto y un cielo amplio.

function dibujar_panorama()
  -- cielo amplio: de azul a arena cálido en el horizonte
  rectfill(0, 0, 239, 51, 12)
  rectfill(0, 52, 239, 69, 13)
  rectfill(0, 70, 239, 85, 15)

  -- sol grande de la península
  circfill(188, 30, 12, 10)
  circfill(188, 30, 8, 7)

  -- mar de dunas: 4 crestas senoidales suaves, de lejos a cerca.
  -- la fase se mueve con t(): las dunas "respiran" muy lentamente.
  -- colores: dunas lejanas tostadas por el sol, arena blanca/piel en
  -- las medianas (como los médanos de la península) y sombra marrón cerca.
  dibujar_duna(62, 8, 9,  0.8)
  dibujar_duna(76, 10, 14, 2.1)
  dibujar_duna(92, 12, 7, 4.4)
  dibujar_duna(110, 14, 4, 5.9)
end

function dibujar_duna(base, amplitud, color, fase)
  -- una duna es una franja de crestas suaves rellena hacia abajo
  local lento = t() * 0.05   -- deriva casi imperceptible
  for x = 0, 240, 4 do
    local cresta = base + sin(x * 0.015 + fase + lento) * amplitud
    rectfill(x, cresta, x + 3, 135, color)
  end
end

-- ===========================================================================
-- 09_datos_nivel.lua - el diseño del cerro en forma de datos
-- ===========================================================================
-- este archivo es "el diseño del cerro" en forma de datos. se lee de
-- abajo hacia arriba (como se sube). no hay lógica aquí: solo llamadas a
-- los constructores de 03/04/05/07 con posiciones.
--
-- geometría del puerto a 240x136: el zigzag usa 3 columnas (izquierda
-- x~20-60, centro x~84-128, derecha x~148-188) con huecos de 20-36px
-- entre plataformas consecutivas - el mismo rango de saltos validado en
-- la versión pico-8, pero aprovechando el ancho de tic-80.
--
-- reglas del terreno (las mismas en todo el nivel):
--   * los escalones suben 26px: el límite real es la altura del salto (~34)
--   * los huecos horizontales van de 20 a 36px: saltables siempre que se
--     haya ganado altura antes de cruzar (la "regla de la esquina")
--   * cada rompible se puede LEER antes de pisarla (grietas visibles)
-- ===========================================================================

plataformas = {}  -- terreno jugable (las llena este archivo)
checkpoints = {}  -- los 3 checkpoints: inicio, zona 2 y zona 3

function checkpoint(x, y)
  -- (x, y) es donde aparecen los PIES del jugador al reaparecer
  checkpoints[#checkpoints + 1] = { x = x, y = y }
end

-- -- zona 1: base (matorral desértico) -----------------------------------
-- de y=2120 (suelo) a y=1522 (repisa de la zona 2).
-- mecánica nueva: plataformas rompibles + cardones.

suelo(0, 2120, 240)            -- el arranque de la subida (anchísimo)
checkpoint(24, 2112)           -- checkpoint 1: el spawn inicial
cardon(48, 2104)               -- obstáculos del suelo: se saltan o se rodean
cardon(88, 2104)
cardon(188, 2104)
decorado(8, 2104)              -- vegetación de fondo...
decorado(120, 2104)
decorado(224, 2104)
silueta(200, 2104, "mirando")  -- alguien mira el cerro desde la base

plataforma(0, 2094, 48)        -- primeros saltos: el terreno enseña a saltar
plataforma(76, 2068, 40)
rompible(140, 2042, 36)        -- ¡la primera roca frágil! (grietas visibles)
plataforma(80, 2016, 40)
rompible(16, 1990, 36)
plataforma(84, 1964, 40)
plataforma(152, 1938, 36)
cardon(160, 1922)              -- cardón encima de la plataforma: aterriza con cuidado
rompible(96, 1912, 32)
rompible(24, 1886, 36)         -- tramo central: rompibles alternadas con roca fija
plataforma(88, 1860, 40)
cardon(104, 1844)              -- segundo cardón sobre plataforma
rompible(152, 1834, 32)
plataforma(96, 1808, 32)
plataforma(28, 1782, 32)
rompible(92, 1756, 32)
rompible(24, 1730, 36)
plataforma(88, 1704, 40)
plataforma(152, 1678, 36)
plataforma(92, 1652, 36)
rompible(24, 1626, 36)
plataforma(88, 1600, 40)
plataforma(20, 1574, 36)
plataforma(84, 1548, 40)
plataforma(0, 1522, 64)        -- repisa de entrada a la zona 2 (descanso)
checkpoint(8, 1514)

-- -- zona 2: transición (bosque seco) ------------------------------------
-- de y=1522 a y=872 (repisa de la zona 3).
-- mecánica nueva: ráfagas de viento horizontales SOLO en el aire.
-- las hojas que vuelan por cada tramo avisan hacia dónde sopla.

decorado(40, 1506)
decorado(216, 1506)
silueta(32, 1506, "saludando")   -- alguien saluda desde la repisa

-- tramo 1: el viento empuja a la derecha; la ruta zigzaguea
-- (fase 0.2: el ciclo arranca ya con brisa media)
viento(0, 1336, 240, 164, 1, 0.06, 0.2)
plataforma(88, 1496, 40)
rompible(152, 1470, 36)          -- saltar EN CONTRA del viento
plataforma(88, 1444, 40)
plataforma(20, 1418, 36)
rompible(84, 1392, 32)           -- y a favor: no te dejes llevar demasiado
plataforma(148, 1366, 36)
plataforma(88, 1340, 36)

-- tramo 2: el viento empuja a la izquierda (fase distinta: otro ritmo de ráfagas)
viento(0, 1128, 240, 190, -1, 0.07, 0.55)
rompible(20, 1314, 36)
plataforma(84, 1288, 40)
plataforma(148, 1262, 36)
rompible(88, 1236, 32)
plataforma(20, 1210, 36)
plataforma(84, 1184, 36)
cardon(96, 1168)                 -- cardón entre el viento: paciencia y puntería
rompible(144, 1158, 32)
plataforma(84, 1132, 40)

-- tramo 3: ráfagas a la derecha, más suaves (casi al final de la zona)
viento(0, 894, 240, 216, 1, 0.05, 0.8)
plataforma(16, 1106, 36)
rompible(80, 1080, 32)
plataforma(144, 1054, 32)
rompible(84, 1028, 36)
plataforma(16, 1002, 36)
plataforma(80, 976, 40)
rompible(148, 950, 32)
plataforma(88, 924, 36)
plataforma(20, 898, 36)
plataforma(80, 872, 96)          -- repisa de entrada a la zona 3 (descanso)
checkpoint(88, 864)

-- -- zona 3: cima (bosque nublado) ---------------------------------------
-- de y=872 a y=196 (plataforma de la cima).
-- mecánica nueva: niebla (poca visibilidad) + musgo (poca fricción).
-- el viento suave de la zona 2 se mantiene: la dificultad se acumula.

viento(0, 192, 240, 658, -1, 0.045, 0.35)   -- brisa constante de altura
decorado(224, 856)
silueta(152, 856, "mirando")

musgo(24, 846, 32)               -- desde aquí empieza el suelo resbaladizo
plataforma(84, 820, 40)
musgo(148, 794, 32)
rompible(88, 768, 36)
musgo(20, 742, 36)
plataforma(84, 716, 36)
musgo(148, 690, 32)
plataforma(88, 664, 40)
rompible(24, 638, 36)
musgo(88, 612, 32)
plataforma(152, 586, 36)
musgo(92, 560, 36)
plataforma(24, 534, 36)
musgo(88, 508, 32)
rompible(152, 482, 32)
plataforma(92, 456, 40)
musgo(24, 430, 36)
silueta(28, 414, "sentado")      -- alguien descansó aquí a medio camino
plataforma(88, 404, 36)
musgo(152, 378, 32)
rompible(92, 352, 36)
plataforma(24, 326, 36)
musgo(88, 300, 32)
plataforma(152, 274, 36)
musgo(92, 248, 36)
plataforma(24, 222, 36)

plataforma(80, 196, 112)         -- la plataforma de la cima
silueta(168, 180, "saludando")   -- aquí espera la familia: el final del camino

-- ===========================================================================
-- 10_estados.lua - máquina de estados del juego
-- ===========================================================================
-- estados: "menu" -> "zona1" -> "zona2" -> "zona3" -> "final"
--
-- cada estado es una pareja (update, draw). TIC y _draw (11_main)
-- delegan en el estado actual: así cada pantalla se lee por separado.
--
-- las zonas comparten el 95% de su lógica (el juego base), y cada una
-- añade lo suyo:
--   zona1: transición hacia zona2
--   zona2: viento + transición hacia zona3
--   zona3: viento + niebla + comprobación de llegada a la cima
-- ===========================================================================

estado = "menu"   -- estado actual (cambia con asignaciones simples)

-- -- cámara ---------------------------------------------------------------
-- la cámara SOLO sube: si el jugador cae, no lo sigue hacia abajo y
-- termina saliendo por el borde inferior (precipicio -> checkpoint).
-- esto da la sensación clásica de "escalada": lo ganado se gana mirando
-- hacia arriba, y caer mucho duele de verdad (aunque sea un retroceso suave).

cam_y = 0

function actualizar_camara()
  local objetivo = player.y - cam_altura_jugador
  if objetivo < cam_y then
    -- seguimiento suave hacia arriba (interpolación exponencial simple)
    cam_y = cam_y + (objetivo - cam_y) * 0.12
  end
  cam_y = mid(0, cam_y, mundo_alto - 136)
end

-- -- mensajes flotantes (feedback breve) ----------------------------------

mensaje_texto = ""
mensaje_frames = 0

function mostrar_mensaje(txt, frames)
  mensaje_texto = txt
  mensaje_frames = frames
end

function actualizar_mensaje()
  if mensaje_frames > 0 then
    mensaje_frames = mensaje_frames - 1
  end
end

function dibujar_mensaje()
  -- centrado en la parte baja de la pantalla, con sombra para que se
  -- lea sobre cualquier fondo
  if mensaje_frames > 0 then
    texto_centro(mensaje_texto, 124, 7)
  end
end

-- -- checkpoints ----------------------------------------------------------
-- el checkpoint es una zona generosa alrededor de su posición: basta
-- rozarlo para "guardarlo". al tocar uno nuevo se avisa con mensaje.

function comprobar_checkpoints()
  for i = player.checkpoint + 1, #checkpoints do
    local cp = checkpoints[i]
    -- caja de contacto amplia (24x24) centrada sobre el punto del checkpoint
    if solapan(player.x, player.y, player.w, player.h, cp.x - 8, cp.y - 16, 24, 24) then
      player.checkpoint = i
      mostrar_mensaje("checkpoint!", 60)
    end
  end
end

function dibujar_checkpoints()
  -- un poste con bandera: brillo pulsante para que se vea entre la bruma
  for i = 1, #checkpoints do
    local cp = checkpoints[i]
    local brillo = 7
    if i == player.checkpoint then
      brillo = 10   -- el checkpoint activo brilla en amarillo
    end
    line(cp.x + 3, cp.y - 14, cp.x + 3, cp.y - 1, 5)
    -- bandera triangular (dos líneas)
    line(cp.x + 3, cp.y - 14, cp.x + 12, cp.y - 10, brillo)
    line(cp.x + 3, cp.y - 10, cp.x + 12, cp.y - 10, brillo)
  end
end

-- -- el juego base compartido por las tres zonas --------------------------

function update_juego_comun()
  update_jugador()          -- input, física y colisiones (02)
  update_plataformas()      -- temporizador de las rompibles (03)
  update_hazards()          -- knockback de los cardones (04)
  update_escombros()        -- trozos de roca (03)
  update_hojas()            -- hojas del viento (05)
  actualizar_camara()       -- la cámara solo sube (arriba de este archivo)
  comprobar_checkpoints()
  comprobar_caida()         -- salir por abajo = precipicio (04)
  actualizar_mensaje()
end

function draw_juego_comun()
  -- orden de capas: fondo -> siluetas -> terreno -> detalles -> jugador
  dibujar_fondo()           -- cielo + colinas (08), en coordenadas de pantalla
  camera(0, flr(cam_y))     -- de aquí en adelante: coordenadas de MUNDO
  dibujar_siluetas()        -- la familia, detrás del terreno (07)
  dibujar_decorados()       -- cardones de fondo (04)
  dibujar_plataformas()     -- terreno jugable (03)
  dibujar_hazards()         -- cardones con colisión (04)
  dibujar_escombros()
  dibujar_checkpoints()
  dibujar_hojas()
  dibujar_jugador()         -- el jugador encima de todo lo jugable (02)
  camera(0, 0)              -- vuelta a coordenadas de pantalla (ui / niebla)
end

-- -- transiciones entre zonas ---------------------------------------------
-- el estado avanza solo hacia delante: caer de nuevo a la zona anterior
-- no cambia el estado (los efectos activos dependen de la posición del
-- jugador, no del nombre del estado, así que no hay efectos "fantasma").

function comprobar_transiciones()
  if estado == "zona1" and player.y < limite_zona2 then
    estado = "zona2"
    mostrar_mensaje("zona 2: bosque seco", 90)

  elseif estado == "zona2" and player.y < limite_zona3 then
    estado = "zona3"
    mostrar_mensaje("zona 3: la cima", 90)

  elseif estado == "zona3" and player.y < y_cima and player.on_ground then
    -- llegó a la cima: arranca la secuencia final
    comenzar_final()
  end
end

-- -- estado: zona1 --------------------------------------------------------

function update_zona1()
  update_juego_comun()
  comprobar_transiciones()
end

function draw_zona1()
  draw_juego_comun()
end

-- -- estado: zona2 --------------------------------------------------------

function update_zona2()
  update_juego_comun()
  update_viento()           -- novedad de la zona: ráfagas en el aire (05)
  comprobar_transiciones()
end

function draw_zona2()
  draw_juego_comun()
end

-- -- estado: zona3 --------------------------------------------------------

function update_zona3()
  update_juego_comun()
  update_viento()           -- la brisa de altura se mantiene
  update_niebla()           -- novedad de la zona: el radio de visión (06)
  comprobar_transiciones()
end

function draw_zona3()
  draw_juego_comun()
  draw_niebla()             -- la niebla se dibuja SOBRE toda la escena
end

-- -- secuencia final ------------------------------------------------------
-- 1) la niebla se disipa progresivamente (el radio crece frame a frame)
-- 2) se revela el panorama: el mar de dunas de la península
-- 3) texto de cierre (escrito letra a letra)

final_fase = 1     -- 1 = niebla disipándose, 2 = panorama, 3 = texto
final_timer = 0

function comenzar_final()
  estado = "final"
  final_fase = 1
  final_timer = 0
  mostrar_mensaje("", 0)
end

function update_final()
  final_timer = final_timer + 1

  if final_fase <= 2 then
    -- la niebla se disipa DE FORMA GRADUAL: crecemos el radio cada
    -- frame en lugar de apagar el efecto de golpe (decisión de diseño).
    -- sigue creciendo durante la fase 2: en la pantalla de 240px de
    -- tic-80 hacen falta radios de ~250 para que no queden restos de
    -- niebla en las esquinas (en 128px no se notaba).
    niebla_radio = niebla_radio + 0.7

    if final_fase == 1 and niebla_radio > 130 then
      -- la panorámica ya se ve: deja respirar el paisaje un momento
      final_fase = 2
      final_timer = 0

    elseif final_fase == 2 and final_timer > 150 then
      final_fase = 3
      final_timer = 0
    end

  elseif final_fase == 3 then
    -- con un botón se vuelve al menú (el juego es corto: se anima a
    -- intentarlo de nuevo, quizá con más calma)
    if btnp(BTN_A) or btnp(BTN_B) then
      estado = "menu"
      reiniciar_partidas()
    end
  end

  -- la escena sigue viva durante el final: las hojas y escombros caen
  update_hojas()
  update_escombros()
end

function draw_final()
  -- el panorama sustituye al fondo normal: es lo que revela la niebla
  dibujar_panorama()
  camera(0, flr(cam_y))
  dibujar_siluetas()
  dibujar_plataformas()
  dibujar_jugador()
  camera(0, 0)

  if final_fase <= 2 then
    -- la niebla va abriéndose hasta desaparecer (fase 1) y no vuelve
    draw_niebla()
  end

  if final_fase == 3 then
    dibujar_texto_final()
  end
end

lineas_final = {
  "esta subida esta inspirada",
  "en una caminata real",
  "que hicimos en familia",
  "por el cerro santa ana.",
  "",
  "gracias por subir con nosotros",
}

function dibujar_texto_final()
  -- el texto se escribe letra a letra (efecto máquina de escribir):
  -- cuántos caracteres mostrar lleva el timer final
  local visibles = flr(final_timer * 0.9)

  local y = 36
  for i = 1, #lineas_final do
    local linea = lineas_final[i]
    -- sub(cadena, desde, hasta) recorta el trozo ya "escrito"
    local mostrado = sub(linea, 1, max(0, visibles))
    texto_centro(mostrado, y, 7)
    y = y + 9
    visibles = visibles - #linea
    if visibles <= 0 then
      break
    end
  end

  -- aviso de continuar (parpadea) una vez escrito todo el texto
  if final_timer > 220 and (flr(t() * 2) % 2 == 0) then
    texto_centro("pulsa a/b", 112, 6)
  end
end

-- -- estado: menu ---------------------------------------------------------

function update_menu()
  if btnp(BTN_A) or btnp(BTN_B) then
    iniciar_partida()
  end
end

function draw_menu()
  cls(1)

  -- el cerro como silueta de fondo: dos colinas y el sol
  circfill(180, 30, 10, 10)
  dibujar_colinas(5, 14, 76, 0, 0)
  dibujar_colinas(0, 20, 100, 0, 1.2)

  texto_centro("cumbre", 16, 7)
  texto_centro("santa ana", 26, 10)
  texto_centro("una subida en familia", 42, 6)

  -- animación de muestra: el jugador quieto + una silueta saludando
  spr(1, 100, 88)
  spr(11, 136, 80, 1, 2)

  texto_centro("pulsa a/b para subir", 108, 7)
  texto_centro("< > mover   a/b saltar", 122, 5)
end

-- -- empezar / reiniciar --------------------------------------------------

function iniciar_partida()
  -- reset completo del mundo y vuelta al spawn (checkpoint 1)
  reset_plataformas()
  reset_escombros()
  crear_hojas()
  player.checkpoint = 1
  colocar_en_checkpoint()
  player.invuln = 0
  niebla_radio = radio_niebla_base
  final_fase = 1
  final_timer = 0
  estado = "zona1"
  mostrar_mensaje("zona 1: la base", 90)
end

function reiniciar_partidas()
  -- vuelta al menú: el mundo queda listo para la próxima partida
  reset_plataformas()
  reset_escombros()
  crear_hojas()
  niebla_radio = radio_niebla_base
end

-- -- la tabla de estados: el corazón de la máquina ------------------------
-- TIC y _draw miran esta tabla: añadir una pantalla nueva es
-- añadir una entrada aquí con sus dos funciones.

estados = {
  menu  = { update = update_menu,  draw = draw_menu  },
  zona1 = { update = update_zona1, draw = draw_zona1 },
  zona2 = { update = update_zona2, draw = draw_zona2 },
  zona3 = { update = update_zona3, draw = draw_zona3 },
  final = { update = update_final, draw = draw_final },
}

-- ===========================================================================
-- 11_main.lua - arranque, bucle principal y utilidades
-- ===========================================================================
-- tic-80 llama a estas funciones:
--
--   BOOT()  una vez, al arrancar el cartucho (el equivalente a _init)
--   TIC()   60 veces por segundo: lógica y dibujo juntos
--
-- en pico-8 la lógica y el dibujo van separados (_update60 / _draw);
-- tic-80 tiene un solo punto de entrada, así que aquí los llamamos en
-- orden: primero update, después draw. el juego conserva la separación
-- interna (las funciones siguen estando aparte en 10_estados.lua).
-- ===========================================================================

arrancado = false

function arrancar()
  -- el juego arranca en el menú; el mundo ya está cargado por los datos
  -- de 09_datos_nivel.lua (todo el código de nivel corre al cargar el
  -- cartucho, antes de la primera llamada a TIC)
  srand(42)              -- semilla fija: las hojas y escombros son reproducibles
  crear_hojas()
  reiniciar_partidas()
  estado = "menu"
  arrancado = true
end

function BOOT()
  arrancar()
end

function TIC()
  -- por si alguna versión no llamara a BOOT: primer frame = arranque
  if not arrancado then
    arrancar()
  end

  frames_juego = frames_juego + 1   -- el reloj del juego (t() en 01_config)

  -- máquina de estados: cada estado tiene su update y su draw (10_estados)
  estados[estado].update()
  estados[estado].draw()

  -- los mensajes flotantes se dibujan al final: siempre por encima
  dibujar_mensaje()
end

-- -- utilidades -----------------------------------------------------------

function texto(txt, x, y, c)
  -- print con sombra: 1px de negro detrás hace el texto legible sobre
  -- cualquier fondo (cielo, niebla, dunas...) sin cajas ni paneles
  print(txt, x + 1, y + 1, 0)
  print(txt, x, y, c)
end

function texto_centro(txt, y, c)
  -- texto centrado en los 240px de pantalla. print() devuelve el ancho
  -- real dibujado, así que medimos dibujando fuera de pantalla primero
  -- (truco estándar en tic-80: la fuente es de ancho variable).
  local w = print(txt, -1000, -1000, 0)
  texto(txt, flr((240 - w) / 2), y, c)
end

-- <TILES>
-- 001:0123456789abcdef0123456789abcdef44440123456789abcdef0123456789abcdef0123456789abcdef4444440123456789abcdef0123456789abcdef0123456789abcdefe11e0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdefeeee0123456789abcdef0123456789abcdef0123456789abcdef8cccc80123456789abcdef0123456789abcdef0123456789abcdefcccc0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef22220123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef20123456789abcdef0123456789abcdef20123456789abcdef0123456789abcdef
-- 002:0123456789abcdef0123456789abcdef44440123456789abcdef0123456789abcdef0123456789abcdef4444440123456789abcdef0123456789abcdef0123456789abcdefe11e0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdefeeee0123456789abcdef0123456789abcdef0123456789abcdef8cccc80123456789abcdef0123456789abcdef0123456789abcdefcccc0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef22220123456789abcdef0123456789abcdef0123456789abcdef220123456789abcdef0123456789abcdef220123456789abcdef
-- 003:0123456789abcdef0123456789abcdef44440123456789abcdef0123456789abcdef0123456789abcdef4444440123456789abcdef0123456789abcdef0123456789abcdefe11e0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdefeeee0123456789abcdef0123456789abcdef0123456789abcdef8cccc80123456789abcdef0123456789abcdef0123456789abcdefcccc0123456789abcdef0123456789abcdef0123456789abcdef22220123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef2220123456789abcdef0123456789abcdef
-- 004:0123456789abcdef0123456789abcdef44440123456789abcdef0123456789abcdef0123456789abcdef4444440123456789abcdef0123456789abcdef0123456789abcdefe11e0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdefeeee0123456789abcdef0123456789abcdef88cccc880123456789abcdef0123456789abcdefcccc0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef22220123456789abcdef0123456789abcdef0123456789abcdef20123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef20123456789abcdef
-- 006:0123456789abcdef330123456789abcdef0123456789abcdef330123456789abcdef0123456789abcdef330123456789abcdef0123456789abcdef330123456789abcdef0123456789abcdef3333330123456789abcdef0123456789abcdef33b3330123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 008:0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef
-- 010:0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11111110123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef
-- 011:0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef111110123456789abcdef11111110123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef
-- 012:0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 038:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef33b3330123456789abcdef0123456789abcdef33b3330123456789abcdef0123456789abcdef3333330123456789abcdef0123456789abcdef0123456789abcdef33330123456789abcdef0123456789abcdef
-- 040:0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 042:0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 043:0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef10123456789abcdef0123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 044:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef11111110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 048:0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef
-- 050:0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55555550123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef
-- 051:0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef555550123456789abcdef55555550123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef
-- 052:0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 054:0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef1151110123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 080:0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 082:0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 083:0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef55550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef50123456789abcdef0123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 084:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef55555550123456789abcdef0123456789abcdef5555550123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
-- 086:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef1151110123456789abcdef0123456789abcdef1151110123456789abcdef0123456789abcdef1111110123456789abcdef0123456789abcdef0123456789abcdef11110123456789abcdef0123456789abcdef
-- </TILES>

-- <PALETTE>
-- 000:0000001d2b537e2553008751ab52365f574fc2c3c7fff1e8ff004dffa300ffec2700e43629adff83769cffccaaff77a8
-- </PALETTE>
