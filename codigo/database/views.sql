-- =====================================================================
-- CyberGuard: Misión Ciberseguridad
-- archivo ....... codigo/database/views.sql   (Tarea T41)
-- motor ......... PostgreSQL 15 (Supabase)
-- idioma ........ comentarios en español
--
-- Descripción:
--   Vistas v_* de SOLO LECTURA para Looker Studio. Son la única puerta
--   de salida de las métricas del dashboard: agregan las tablas de
--   eventos y jamás exponen PII (sin email, IP, user_agent ni nombre
--   real). Los datos por jugador se limitan a agregados por nivel /
--   señal / vulnerabilidad.
--
-- Reglas (skill looker-analytics-schema):
--   * Tipos estables: integer, numeric, boolean, timestamptz, text.
--     Prohibido jsonb. Los porcentajes se entregan como numeric(5,2)
--     en escala 0-100.
--   * Toda vista lleva columna temporal `creado_en` (filtros de fecha
--     de Looker).
--   * Concesión mínima: GRANT SELECT SOLO sobre las vistas al rol
--     `looker_lectura` (creado en rls.sql). Looker NUNCA lee tablas
--     crudas.
--   * Cada métrica es trazable a tabla.columna (modelo §9).
--
-- Orden de ejecución: schema.sql → rls.sql → rpc_puntaje.sql → views.sql → seed.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- Vista: v_resumen_vulnerabilidades
--   Resumen por tipo de amenaza: vulnerabilidades de servidor más
--   frecuentes, señales de phishing más falladas y fases de contraseña
--   por fortaleza esperada. Alimenta el bloque "¿Qué falla más?".
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_resumen_vulnerabilidades AS
-- 2a. Vulnerabilidades de servidor (Módulo C)
SELECT
  'servidor'::text                       AS modulo,
  e.vulnerabilidad                       AS categoria,
  COUNT(*)::integer                      AS total_eventos,
  COUNT(*) FILTER (WHERE NOT e.reparado)::integer AS total_fallos,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT e.reparado) / NULLIF(COUNT(*), 0), 2)
                                         AS pct_fallo,
  ROUND(AVG(e.tiempo_respuesta_ms)::numeric, 0)    AS tiempo_medio_respuesta_ms,
  MIN(e.creado_en)                       AS creado_en
FROM eventos_servidor e
GROUP BY e.vulnerabilidad

UNION ALL

-- 2b. Señales de phishing más falladas (Módulo A)
SELECT
  'phishing'::text,
  p.senal_clave,
  COUNT(*)::integer,
  COUNT(*) FILTER (WHERE NOT p.es_correcto)::integer,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT p.es_correcto) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(p.tiempo_respuesta_ms)::numeric, 0),
  MIN(p.creado_en)
FROM eventos_phishing p
GROUP BY p.senal_clave

UNION ALL

-- 2c. Fases de contraseñas por fortaleza esperada (Módulo B)
SELECT
  'password'::text,
  'fortaleza_' || COALESCE(w.fortaleza::text, 'na'),
  COUNT(*)::integer,
  COUNT(*) FILTER (WHERE NOT w.es_correcto)::integer,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT w.es_correcto) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(w.tiempo_respuesta_ms)::numeric, 0),
  MIN(w.creado_en)
FROM eventos_password w
WHERE w.fase = 'fortaleza'
GROUP BY w.fortaleza;

GRANT SELECT ON v_resumen_vulnerabilidades TO looker_lectura;


-- ---------------------------------------------------------------------
-- Vista: v_efectividad_nivel
--   Efectividad (acierto) y caída por nivel y módulo, con tiempo medio
--   de respuesta. Métrica principal T42.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_efectividad_nivel AS
SELECT
  pa.nivel_id::integer                          AS nivel_id,
  'phishing'::text                              AS modulo,
  COUNT(*)::integer                             AS total_eventos,
  ROUND(100.0 * SUM(p.es_correcto::int) / NULLIF(COUNT(*), 0), 2) AS pct_efectividad,
  ROUND(100.0 * SUM((NOT p.es_correcto)::int) / NULLIF(COUNT(*), 0), 2) AS pct_caida,
  ROUND(AVG(p.tiempo_respuesta_ms)::numeric, 0) AS tiempo_medio_respuesta_ms,
  MIN(p.creado_en)                              AS creado_en
FROM eventos_phishing p
JOIN partidas pa ON pa.id = p.partida_id
GROUP BY pa.nivel_id

UNION ALL

SELECT
  pa.nivel_id,
  'password',
  COUNT(*),
  ROUND(100.0 * SUM(w.es_correcto::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(100.0 * SUM((NOT w.es_correcto)::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(w.tiempo_respuesta_ms)::numeric, 0),
  MIN(w.creado_en)
FROM eventos_password w
JOIN partidas pa ON pa.id = w.partida_id
GROUP BY pa.nivel_id

UNION ALL

SELECT
  pa.nivel_id,
  'servidor',
  COUNT(*),
  ROUND(100.0 * SUM(e.reparado::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(100.0 * SUM((NOT e.reparado)::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(e.tiempo_respuesta_ms)::numeric, 0),
  MIN(e.creado_en)
FROM eventos_servidor e
JOIN partidas pa ON pa.id = e.partida_id
GROUP BY pa.nivel_id;

GRANT SELECT ON v_efectividad_nivel TO looker_lectura;


-- ---------------------------------------------------------------------
-- Consultas de referencia (métricas clave, skill §4)
--   Útiles para validar el dashboard o para scorecards sueltos en
--   Looker Studio. Toda métrica es trazable a tabla.columna.
-- ---------------------------------------------------------------------

-- 4.1 Caída en phishing (todo el módulo):
--     ROUND(100.0 * SUM((NOT es_correcto)::int) / COUNT(*), 2)
--     FROM eventos_phishing;

-- 4.1 Caída en contraseñas débiles (fase fortaleza con fortaleza esperada <= 1):
--     ROUND(100.0 * SUM((NOT es_correcto)::int) / COUNT(*), 2)
--     FROM eventos_password
--     WHERE fase = 'fortaleza' AND fortaleza <= 1;

-- 4.2 Tiempo medio de respuesta por nivel (y módulo):
--     SELECT nivel_id, modulo, tiempo_medio_respuesta_ms
--     FROM v_efectividad_nivel
--     ORDER BY nivel_id, modulo;


-- =====================================================================
-- BLOQUEADA — v_ranking_jugadores  ⚠️ PENDIENTE DE APROBACIÓN DEL GUARDIÁN
--
-- CONFLICTO DE DECISIÓN: la decisión 3a de doc/dominio/01-modelo-dominio.md
-- §9/§11 prohíbe explícitamente las vistas `v_ranking_*` ("solo métricas
-- agregadas en Looker"). El usuario ordenó incluir el ranking, pero queda
-- PENDIENTE de aprobación explícita del `guardián` en el Gate antes de
-- aplicarla en producción. Por eso las sentencias siguientes están
-- COMENTADAS: este bloque documenta la vista lista para activar, pero NO
-- se ejecuta.
--
-- Para activarla (tras el Gate): descomentar y ejecutar.
-- Sin PII: solo alias seudónimo del jugador (nunca nombre, email ni IP).
-- =====================================================================
--
-- CREATE OR REPLACE VIEW v_ranking_jugadores AS
-- SELECT
--   j.alias::text                                AS alias_jugador,   -- seudónimo, sin PII
--   COUNT(DISTINCT p.id)::integer                AS total_partidas,
--   SUM(CASE WHEN ep.es_correcto THEN 1 ELSE 0 END)::integer
--     + SUM(CASE WHEN ew.es_correcto THEN 1 ELSE 0 END)::integer
--     + SUM(CASE WHEN es.reparado  THEN 1 ELSE 0 END)::integer      AS total_aciertos,
--   ROUND(100.0 * (
--       SUM(CASE WHEN ep.es_correcto THEN 1 ELSE 0 END)
--     + SUM(CASE WHEN ew.es_correcto THEN 1 ELSE 0 END)
--     + SUM(CASE WHEN es.reparado  THEN 1 ELSE 0 END)
--   ) / NULLIF(
--       COUNT(ep.id) + COUNT(ew.id) + COUNT(es.id), 0), 2)          AS pct_efectividad,
--   MIN(ep.creado_en)                            AS creado_en
-- FROM jugadores j
-- JOIN partidas pa        ON pa.jugador_id = j.id
-- LEFT JOIN eventos_phishing ep ON ep.partida_id = pa.id
-- LEFT JOIN eventos_password  ew ON ew.partida_id = pa.id
-- LEFT JOIN eventos_servidor  es ON es.partida_id = pa.id
-- GROUP BY j.alias;
--
-- GRANT SELECT ON v_ranking_jugadores TO looker_lectura;
--
-- Orden en Looker: ORDER BY pct_efectividad DESC, total_partidas DESC.
-- Si el `guardián` rechaza la vista, se retira y las métricas agregadas
-- de las vistas anteriores siguen siendo suficientes para el dashboard.

-- Fin de views.sql — continuar con seed.sql (solo entornos de prueba)
