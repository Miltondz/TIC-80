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
