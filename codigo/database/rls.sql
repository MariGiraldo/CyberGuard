-- =====================================================================
-- CyberGuard: Misión Ciberseguridad
-- archivo ....... codigo/database/rls.sql   (Tarea T12)
-- motor ......... PostgreSQL 15 (Supabase)
-- idioma ........ comentarios en español
--
-- Descripción:
--   Row Level Security (RLS) append-only sobre las 5 tablas de datos
--   + preparación del rol de solo lectura para Looker Studio.
--
-- Por qué RLS (regla dura del Guardián §3.4):
--   El cliente Godot autentica con la clave PÚBLICA `anon` (que conoce
--   cualquiera que use el juego). Sin RLS, cualquiera podría borrar o
--   reescribir la telemetría. Por eso:
--     * Se HABILITA RLS en todas las tablas.
--     * El rol `anon` solo tiene política de INSERT (append-only).
--     * Se REVOCAN explícitamente UPDATE y DELETE del rol `anon`.
--   Sin política SELECT, `anon` tampoco lee: las lecturas del juego y
--   de Looker pasan por RPC (SECURITY DEFINER) o por las vistas v_*
--   con el rol dedicado `looker_lectura` (vistas = T41, no aquí).
--
-- Orden de ejecución: schema.sql → rls.sql → rpc_puntaje.sql → seed.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Habilitar Row Level Security en todas las tablas
--    Con RLS activo, a un rol sin política aplicable se le DENIEGA todo
--    por defecto (principio de mínimo privilegio).
-- ---------------------------------------------------------------------
ALTER TABLE jugadores        ENABLE ROW LEVEL SECURITY;
ALTER TABLE partidas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos_phishing ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos_password ENABLE ROW LEVEL SECURITY;
ALTER TABLE eventos_servidor ENABLE ROW LEVEL SECURITY;


-- ---------------------------------------------------------------------
-- 2) Revocar escrituras destructivas del rol `anon`
--    El cliente (Godot, clave anon) SOLO inserta. Explícito además de
--    las políticas, para que el intento de UPDATE/DELETE falle aunque
--    alguien agregue una política por error.
--    (El dueño de las tablas — service_role / postgres — mantiene
--    acceso administrativo para migraciones y correcciones.)
-- ---------------------------------------------------------------------
REVOKE UPDATE, DELETE ON TABLE jugadores        FROM anon;
REVOKE UPDATE, DELETE ON TABLE partidas         FROM anon;
REVOKE UPDATE, DELETE ON TABLE eventos_phishing FROM anon;
REVOKE UPDATE, DELETE ON TABLE eventos_password FROM anon;
REVOKE UPDATE, DELETE ON TABLE eventos_servidor FROM anon;


-- ---------------------------------------------------------------------
-- 3) Políticas append-only para el rol `anon`
--    Solo INSERT con WITH CHECK (las filas nuevas cumplen las reglas).
--    NO se crean políticas de SELECT/UPDATE/DELETE para `anon`:
--    su ausencia + RLS activo = denegado por defecto.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "anon_solo_insert_jugadores" ON jugadores;
CREATE POLICY "anon_solo_insert_jugadores"
  ON jugadores
  FOR INSERT
  TO anon
  WITH CHECK (true);
-- El cliente solo inserta: crea su fila de alias seudónimo una vez.

DROP POLICY IF EXISTS "anon_solo_insert_partidas" ON partidas;
CREATE POLICY "anon_solo_insert_partidas"
  ON partidas
  FOR INSERT
  TO anon
  WITH CHECK (
    -- El cliente solo puede ABRIR una partida en blanco: nada de
    -- inyectar un puntaje ni marcarla como completada (el puntaje es
    -- exclusivo del servidor, Contrato CyberGuard §3.4).
    puntaje_total = 0
    AND completada = false
    AND finalizado_en IS NULL
  );
-- El cliente inserta la partida (con su uuid) para poder encolar
-- eventos aunque esté offline. La escritura de puntaje_total /
-- finalizado_en la hace la RPC fn_finalizar_partida() (SECURITY DEFINER).

DROP POLICY IF EXISTS "anon_solo_insert_eventos_phishing" ON eventos_phishing;
CREATE POLICY "anon_solo_insert_eventos_phishing"
  ON eventos_phishing
  FOR INSERT
  TO anon
  WITH CHECK (true);
-- Append-only puro: cada decisión de phishing se registra una vez y
-- jamás se modifica ni se borra (integridad de la telemetría §3.4).

DROP POLICY IF EXISTS "anon_solo_insert_eventos_password" ON eventos_password;
CREATE POLICY "anon_solo_insert_eventos_password"
  ON eventos_password
  FOR INSERT
  TO anon
  WITH CHECK (true);
-- Append-only puro: igual que eventos_phishing.

DROP POLICY IF EXISTS "anon_solo_insert_eventos_servidor" ON eventos_servidor;
CREATE POLICY "anon_solo_insert_eventos_servidor"
  ON eventos_servidor
  FOR INSERT
  TO anon
  WITH CHECK (true);
-- Append-only puro: igual que eventos_phishing.


-- ---------------------------------------------------------------------
-- 4) Rol dedicado de solo lectura para Looker Studio
--    Looker Studio se conecta SIEMPRE en lectura, a través de las
--    vistas v_* (T41) y con este rol — nunca con `anon` ni con
--    `service_role` (Contrato CyberGuard §3.5).
--
--    NOTA: las vistas v_* todavía no existen (son la T41). Este archivo
--    solo crea y prepara el rol; cuando views.sql se ejecute, hay que
--    concederle SELECT sobre las vistas nuevas, p. ej.:
--      GRANT SELECT ON ALL TABLES IN SCHEMA public TO looker_lectura;
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'looker_lectura') THEN
    CREATE ROLE looker_lectura;
    RAISE NOTICE 'Rol looker_lectura creado.';
  ELSE
    RAISE NOTICE 'Rol looker_lectura ya existía; se reutiliza.';
  END IF;
END
$$;

-- Acceso al esquema y SELECT sobre lo que exista hoy (tablas base);
-- las vistas v_* se concederán en T41.
GRANT USAGE ON SCHEMA public TO looker_lectura;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO looker_lectura;

-- looker_lectura NO escribe: sin privilegios de escritura y sin
-- políticas de INSERT, no puede alterar la telemetría.
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM looker_lectura;

-- Fin de rls.sql — continuar con ../backend/rpc_puntaje.sql
