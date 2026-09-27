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
