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
