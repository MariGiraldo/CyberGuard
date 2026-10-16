-- =====================================================================
-- CyberGuard: Misión Ciberseguridad
-- archivo ....... codigo/database/seed.sql   (Tarea T13)
-- motor ......... PostgreSQL 15 (Supabase)
-- idioma ........ comentarios en español
--
-- Descripción:
--   Datos de PRUEBA 100% ficticios para validar el esquema y poder
--   probar las vistas v_* y el dashboard de Looker Studio (T41/T42)
--   antes de tener reales del juego.
--
-- Reglas:
--   * Solo datos ficticios: SIN PII (el único "jugador" es el alias
--     seudónimo 'analista-demo').
--   * Ids uuid fijos y deterministas → ejecución reproducible.
--   * Idempotente: se puede re-ejecutar sin duplicar filas
--     (ON CONFLICT / NOT EXISTS), salvo los eventos si se borran a mano.
--
-- Orden de ejecución: schema.sql → rls.sql → rpc_puntaje.sql → seed.sql
-- (Ejecutar en el SQL Editor de Supabase con el rol `postgres`.)
--
-- Coherencia del puntaje de la partida demo (misma fórmula que
-- fn_finalizar_partida):
--   5 aciertos  x 100  = +500    (3 phishing + 2 password)
--   1 error     x  -50  =  -50
--   bonus tiempo: 45 s x 10      = +450
--   ------------------------------------------------
--   puntaje_total esperado        =  900
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Niveles (catálogo fijo: 4 niveles de 5-8 minutos)
-- ---------------------------------------------------------------------
INSERT INTO niveles (numero, nombre, duracion_seg)
VALUES
  (1, 'Onboarding',           300),   -- 5 min — tutorial de phishing
  (2, 'Bandeja peligrosa',    360),   -- 6 min — 6 correos + 1 contraseña débil
  (3, 'Servidor comprometido', 420),  -- 7 min — reparación + phishing mixto
  (4, 'Tormenta de amenazas', 480)    -- 8 min — todos los módulos
ON CONFLICT (numero) DO NOTHING;


-- ---------------------------------------------------------------------
-- 2) Jugador demo (alias seudónimo — SIN PII)
--    Id determinista: 00000000-0000-4000-8000-000000000001
-- ---------------------------------------------------------------------
INSERT INTO jugadores (id, alias)
VALUES ('00000000-0000-4000-8000-000000000001', 'analista-demo')
ON CONFLICT (id) DO NOTHING;


-- ---------------------------------------------------------------------
-- 3) Partida demo (nivel 2 "Bandeja peligrosa", ya finalizada)
--    Id determinista: 00000000-0000-4000-8000-000000000002
--    puntaje_total = 900 (calcularía fn_finalizar_partida; se fija aquí
--    para que el dashboard tenga datos aunque no se llame la RPC).
-- ---------------------------------------------------------------------
INSERT INTO partidas (
  id, jugador_id, nivel_id,
  iniciado_en, finalizado_en,
  puntaje_total, tiempo_restante_seg, completada
)
VALUES (
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000001',
  2,                                        -- nivel "Bandeja peligrosa"
  now() - interval '7 minutes',
  now() - interval '2 minutes',
  900,
  45,
  true
)
ON CONFLICT (id) DO NOTHING;


-- ---------------------------------------------------------------------
-- 4) Eventos de phishing (4 eventos: 3 correctos, 1 error)
--    Payload exacto de eventos_phishing:
--    partida_id, jugador_id, correo_id, decision, es_correcto,
--    senal_clave, tiempo_respuesta_ms
-- ---------------------------------------------------------------------
INSERT INTO eventos_phishing (
  partida_id, jugador_id, correo_id, decision, es_correcto,
  senal_clave, tiempo_respuesta_ms
)
SELECT
  v.partida_id, v.jugador_id, v.correo_id, v.decision,
  v.es_correcto, v.senal_clave, v.tiempo_respuesta_ms
FROM (
  VALUES
    -- Aciertos (es_correcto = true)
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'correo-001', 'PHISHING', true,  'dominio sospechoso',        4200),
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'correo-002', 'LEGITIMO', true,  'sin senales de alerta',     3100),
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'correo-003', 'PHISHING', true,  'urgencia y amenaza',        5600),
    -- Error (es_correcto = false): el jugador marcó como phishing
    -- un correo que era legítimo (falsa alarma)
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'correo-004', 'PHISHING', false, 'falsa alarma: remitente interno verificado', 7800)
) AS v (partida_id, jugador_id, correo_id, decision, es_correcto,
        senal_clave, tiempo_respuesta_ms)
WHERE NOT EXISTS (
  -- Evita duplicados si el seed se ejecuta más de una vez
  SELECT 1 FROM eventos_phishing
  WHERE partida_id = '00000000-0000-4000-8000-000000000002'
);


-- ---------------------------------------------------------------------
-- 5) Eventos de contraseña (2 eventos, ambos correctos)
--    Payload exacto de eventos_password:
--    partida_id, jugador_id, fase, es_correcto, fortaleza,
--    tiempo_respuesta_ms
--    (fortaleza: 0-4 o NULL; JAMÁS se guarda el texto de la contraseña)
-- ---------------------------------------------------------------------
INSERT INTO eventos_password (
  partida_id, jugador_id, fase, es_correcto, fortaleza,
  tiempo_respuesta_ms
)
SELECT
  v.partida_id, v.jugador_id, v.fase, v.es_correcto,
  v.fortaleza, v.tiempo_respuesta_ms
FROM (
  VALUES
    -- Fase de descifrado: no mide fortaleza → fortaleza NULL
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'descifrado', true, NULL::int, 6500),
    -- Fase de fortaleza: contraseña evaluada como fuerte (4)
    ('00000000-0000-4000-8000-000000000002'::uuid,
     '00000000-0000-4000-8000-000000000001'::uuid,
     'fortaleza',  true, 4,        4900)
) AS v (partida_id, jugador_id, fase, es_correcto, fortaleza,
        tiempo_respuesta_ms)
WHERE NOT EXISTS (
  -- Evita duplicados si el seed se ejecuta más de una vez
  SELECT 1 FROM eventos_password
  WHERE partida_id = '00000000-0000-4000-8000-000000000002'
);


-- ---------------------------------------------------------------------
-- 6) Verificación rápida (resultado esperado tras ejecutar el seed)
-- ---------------------------------------------------------------------
-- Niveles:        4 filas (numero 1..4)
-- Jugadores:      1 fila  ('analista-demo')
-- Partidas:       1 fila  (puntaje_total = 900, completada = true)
-- eventos_phishing: 4 filas (3 aciertos, 1 error)
-- eventos_password: 2 filas (ambas correctas)
-- eventos_servidor: 0 filas (sin eventos de servidor en el seed)
SELECT 'niveles'          AS tabla, count(*) AS filas FROM niveles
UNION ALL SELECT 'jugadores',        count(*) FROM jugadores
UNION ALL SELECT 'partidas',         count(*) FROM partidas
UNION ALL SELECT 'eventos_phishing', count(*) FROM eventos_phishing
UNION ALL SELECT 'eventos_password', count(*) FROM eventos_password
UNION ALL SELECT 'eventos_servidor', count(*) FROM eventos_servidor;

-- Fin de seed.sql
