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
