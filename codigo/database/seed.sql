-- =============================================================================
-- CyberGuard · Seed de datos de demostración
-- =============================================================================
-- Contenido 100% ficticio: dominios .invalid (RFC 2606), empresas de mentira,
-- contraseñas de ejemplo y IDs de correo del vocabulario canónico (n1_c0N).
-- Sin PII real: ningún nombre, correo, teléfono o IP real.
--
-- ORDEN DE EJECUCIÓN:
--   1. schema.sql
--   2. rls.sql
--   3. views.sql
--   4. seed.sql (este archivo)
--
-- ⚠️ NOTA DE AUDITORÍA (v_ranking_jugadores): views.sql bloquea la vista de
--    ranking de jugadores a la espera de aprobación del guardian (Gate). El
--    seed NO genera ningún dato de ranking hasta que esa vista exista.
-- =============================================================================

-- =============================================================================
-- 1. JUGADORES DE EJEMPLO (contraseñas con hash ficticio de ejemplo)
-- =============================================================================
INSERT INTO jugadores (alias, centro_educativo, nivel_inicial) VALUES
  ('titan_n1',       'IES NexoData (ficticio)', 1),
  ('sombra_byte',    'IES NexoData (ficticio)', 1),
  ('luna_firewall',  'IES NexoData (ficticio)', 2),
  ('eco_root',       'IES PixelForge (ficticio)', 2),
  ('pixel_raid',     'IES PixelForge (ficticio)', 3),
  ('vector_null',    'IES PixelForge (ficticio)', 3);

-- Contraseñas con hash ficticio de ejemplo (nunca datos reales).
UPDATE jugadores SET password_hash = '$2b$12$EjemploFicticioHashSeed000000000000000000000000000000';

-- =============================================================================
-- 2. PARTIDAS DE EJEMPLO
-- =============================================================================
INSERT INTO partidas (jugador_id, estado, nivel_actual, timestamp_inicio) VALUES
  (1, 'completada', 4, '2026-05-12 09:00:00+00'),
  (2, 'completada', 4, '2026-05-12 10:15:00+00'),
  (3, 'completada', 4, '2026-05-13 11:30:00+00'),
  (4, 'en_curso',   2, '2026-05-14 12:45:00+00');

-- =============================================================================
-- 3. EVENTOS DE PHISHING (6 correos ficticios del nivel 1)
--    IDs = vocabulario canónico del doc de diseño (n1_c01 .. n1_c06)
--    senal_clave ∈ {enlace_sospechoso, urgencia, premio, remitente_falso,
--                   adjunto_inesperado, sin_senales}
-- =============================================================================
INSERT INTO eventos_phishing
  (partida_id, jugador_id, correo_id, es_phishing, senal_clave, decision, puntuacion, tiempo_respuesta_ms) VALUES
  -- n1_c01: phishing (urgencia)
  (1, 1, 'n1_c01', TRUE,  'urgencia',           'marcado_phishing', 100, 42000),
  -- n1_c02: legítimo (sin_senales)
  (1, 1, 'n1_c02', FALSE, 'sin_senales',         'ignorado',          10, 15000),
  -- n1_c03: phishing (enlace_sospechoso)
  (1, 1, 'n1_c03', TRUE,  'enlace_sospechoso',   'marcado_phishing', 100, 38000),
  -- n1_c04: legítimo (sin_senales)
  (1, 1, 'n1_c04', FALSE, 'sin_senales',         'ignorado',          10, 12000),
  -- n1_c05: phishing (remitente_falso)
  (1, 1, 'n1_c05', TRUE,  'remitente_falso',     'marcado_phishing', 100, 51000),
  -- n1_c06: legítimo (sin_senales)
  (1, 1, 'n1_c06', FALSE, 'sin_senales',         'marcado_phishing', -50, 20000);

-- Segunda partida: menos aciertos
INSERT INTO eventos_phishing
  (partida_id, jugador_id, correo_id, es_phishing, senal_clave, decision, puntuacion, tiempo_respuesta_ms) VALUES
  (2, 2, 'n1_c01', TRUE,  'urgencia',       'marcado_phishing', 100, 55000),
  (2, 2, 'n1_c02', FALSE, 'sin_senales',    'marcado_phishing',  -50, 18000),
  (2, 2, 'n1_c03', TRUE,  'enlace_sospechoso', 'ignorado',       -30, 25000),
  (2, 2, 'n1_c04', FALSE, 'sin_senales',    'ignorado',          10, 14000),
  (2, 2, 'n1_c05', TRUE,  'remitente_falso','marcado_phishing', 100, 48000),
  (2, 2, 'n1_c06', FALSE, 'sin_senales',    'ignorado',          10, 16000);

-- Tercera partida: algo mejor
INSERT INTO eventos_phishing
  (partida_id, jugador_id, correo_id, es_phishing, senal_clave, decision, puntuacion, tiempo_respuesta_ms) VALUES
  (3, 3, 'n1_c01', TRUE,  'urgencia',       'marcado_phishing', 100, 33000),
  (3, 3, 'n1_c02', FALSE, 'sin_senales',    'ignorado',          10, 11000),
  (3, 3, 'n1_c03', TRUE,  'enlace_sospechoso', 'marcado_phishing', 100, 40000),
  (3, 3, 'n1_c04', FALSE, 'sin_senales',    'marcado_phishing', -50, 13000),
  (3, 3, 'n1_c05', TRUE,  'remitente_falso','ignorado',         -30, 29000),
  (3, 3, 'n1_c06', FALSE, 'sin_senales',    'ignorado',          10, 10000);

-- =============================================================================
-- 4. EVENTOS DE CONTRASEÑAS
--    duracion_seg ∈ {480, 420, 360, 360} según el nivel (doc de diseño)
-- =============================================================================
INSERT INTO eventos_password
  (partida_id, jugador_id, fortaleza, tiempo_respuesta_ms, duracion_seg, puntuacion) VALUES
  -- Ronda débil: 8 segundos (< 480 s)
  (1, 1, 'debil',     8000,  480, 0),
  -- Ronda media: 12 segundos (< 480 s)
  (1, 1, 'media',    12000,  480, 25),
  -- Ronda fuerte: 20 segundos (> 480 s)
  (1, 1, 'fuerte',   20000,  480, 50),
  -- Segunda partida
  (2, 2, 'debil',     5000,  480, 0),
  (2, 2, 'media',    10000,  480, 25),
  (2, 2, 'fuerte',   15000,  480, 50),
  (2, 2, 'muy_fuerte', 25000, 480, 25),
  -- Tercera partida
  (3, 3, 'debil',    10000,  480, 25),
  (3, 3, 'media',    14000,  480, 25),
  (3, 3, 'fuerte',   18000,  480, 50);

-- =============================================================================
-- 5. PUNTUACIONES DE EJEMPLO
--    El máximo teórico por partida es 1000 puntos
--    (600 phishing + 400 contraseñas).
-- =============================================================================
INSERT INTO puntuaciones (partida_id, jugador_id, puntos_totales, phishing_score, password_score, tiempo_total_seg) VALUES
  (1, 1, 900, 470, 270, 520),
  (2, 2, 700, 320, 260, 640),
  (3, 3, 750, 330, 280, 580)
ON CONFLICT (partida_id) DO NOTHING;

-- =============================================================================
-- 6. NIVELES DEL JUEGO (reales del juego)
--    duracion_seg por nivel: 480, 420, 360, 360 (doc de diseño)
-- =============================================================================
INSERT INTO niveles
  (numero, titulo, categoria, duracion_seg, objetivos_totales, errores_max, orden_ejecucion) VALUES
  (1, 'Buzon bajo asedio',       'phishing',   480, 6, 3, 1),
  (2, 'El arte del engaño',      'phishing',   420, 6, 3, 2),
  (3, 'Fortaleza de contrasenas',   'password',  360, 4, 0, 3),
  (4, 'El laboratorio silencioso',  'servidor',  360, 6, 4, 4)
ON CONFLICT (numero) DO NOTHING;

-- =============================================================================
-- 7. EVENTOS DE SERVIDOR (nivel 4 · detección de amenazas)
--    vulnerabilidad ∈ {auth_debil, sin_rate_limit, sin_https, sin_firewall,
--                      sin_actualizaciones, sin_senales}
--    decision ∈ {vuln_correcta, benigno_marcado, vuln_pasada, timeout}
-- =============================================================================
INSERT INTO eventos_servidor
  (partida_id, jugador_id, vulnerabilidad, decision, puntuacion, tiempo_respuesta_ms) VALUES
  -- Partida 1: tres vulnerabilidades detectadas, dos falsos positivos, una pasada
  (1, 1, 'auth_debil',          'vuln_correcta',   100, 47000),
  (1, 1, 'sin_rate_limit',      'vuln_correcta',   100, 39000),
  (1, 1, 'sin_https',           'vuln_correcta',   100, 31000),
  (1, 1, 'sin_firewall',        'benigno_marcado', -50, 55000),
  (1, 1, 'sin_actualizaciones', 'benigno_marcado', -50, 62000),
  (1, 1, 'sin_senales',         'vuln_pasada',     -30, 58000),
  -- Partida 2: dos vulnerabilidades detectadas, un falso positivo, una pasada
  (2, 2, 'auth_debil',          'vuln_correcta',   100, 51000),
  (2, 2, 'sin_rate_limit',      'benigno_marcado', -50, 44000),
  (2, 2, 'sin_https',           'vuln_correcta',   100, 60000),
  (2, 2, 'sin_firewall',        'vuln_pasada',     -30, 53000);

-- =============================================================================
-- FIN DEL SEED
-- =============================================================================
