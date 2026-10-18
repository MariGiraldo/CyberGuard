-- =====================================================================
-- CyberGuard: Misión Ciberseguridad
-- archivo ....... codigo/database/schema.sql   (Tarea T11)
-- motor ......... PostgreSQL 15 (Supabase)
-- idioma ........ comentarios en español
--
-- Descripción:
--   Esquema completo de datos del juego: niveles, jugadores, partidas
--   y las tres tablas de eventos de telemetría (append-only).
--
-- Reglas del Contrato CyberGuard que respeta este archivo:
--   * SIN PII: el jugador se identifica por `alias` seudónimo + uuid.
--   * Toda tabla de eventos lleva FK NOT NULL a partida y jugador,
--     y columna `creado_en timestamptz NOT NULL DEFAULT now()`.
--   * Los valores de negocio con dominio limitado usan CHECK.
--   * Aquí NO se crean vistas (v_*, T41) ni funciones (RPC, backend).
--
-- Orden de ejecución recomendado:
--   1) schema.sql
--   2) rls.sql
--   3) ../backend/rpc_puntaje.sql
--   4) ../database/views.sql     (vistas v_* para Looker, T41)
--   5) seed.sql   (solo entornos de prueba)
-- =====================================================================


-- ---------------------------------------------------------------------
-- Tabla: niveles
-- Catálogo fijo de los 4 niveles del juego (una fila por nivel).
-- El cliente solo lectura; las filas se crean con seed/migración.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS niveles (
  id            serial PRIMARY KEY,
  numero        int    NOT NULL UNIQUE,   -- 1..4, identificador lógico
  nombre        text   NOT NULL,          -- "Onboarding", "Bandeja peligrosa", ...
  duracion_seg  int    NOT NULL,          -- duración del temporizador global (5-8 min)
  CONSTRAINT niveles_duracion_positiva CHECK (duracion_seg > 0),
  CONSTRAINT niveles_numero_positivo   CHECK (numero > 0)
);

COMMENT ON TABLE  niveles                  IS 'Catálogo de niveles/misiones del juego. Datos maestros, no los escribe el cliente.';
COMMENT ON COLUMN niveles.duracion_seg     IS 'Duración del temporizador global del nivel en segundos (300-480 s = 5-8 min).';


-- ---------------------------------------------------------------------
-- Tabla: jugadores
-- Seudónimo del jugador. SIN PII: prohibido nombre real, correo,
-- teléfono, dirección o fecha de nacimiento (Contrato CyberGuard §3.3).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jugadores (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alias       text NOT NULL UNIQUE,       -- seudónimo público, único
  creado_en   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT jugadores_alias_no_vacio CHECK (length(btrim(alias)) > 0)
);

COMMENT ON TABLE  jugadores          IS 'Jugadores identificados solo por alias seudónimo + uuid. SIN PII (regla dura del Guardián).';
COMMENT ON COLUMN jugadores.alias    IS 'Seudónimo elegido por el jugador. Prohibido guardar aquí nombre real, correo o cualquier dato personal.';


-- ---------------------------------------------------------------------
-- Tabla: partidas
-- Una fila por intento de un jugador en un nivel.
-- `puntaje_total` es una COLUMNA DE ESCRITURA EXCLUSIVA DEL SERVIDOR:
-- solo la calcula/modifica la RPC fn_finalizar_partida() (backend).
-- El cliente NUNCA envía el puntaje como verdad (§3.4 del contrato).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partidas (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  jugador_id           uuid NOT NULL REFERENCES jugadores (id),
  nivel_id             int  NOT NULL REFERENCES niveles (id),
  iniciado_en          timestamptz NOT NULL DEFAULT now(),
  finalizado_en        timestamptz,                       -- lo fija la RPC al finalizar
  puntaje_total        int  NOT NULL DEFAULT 0,           -- calculado EN SERVIDOR (RPC)
  tiempo_restante_seg  int,                               -- tiempo que quedaba al final (bonus)
  completada           boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE  partidas                     IS 'Una fila por intento (partida) de un jugador en un nivel.';
COMMENT ON COLUMN partidas.puntaje_total       IS 'Calculado exclusivamente en servidor por fn_finalizar_partida(). El cliente jamás lo envía como verdad.';
COMMENT ON COLUMN partidas.tiempo_restante_seg IS 'Segundos restantes al finalizar; base del bonus de tiempo (x10) en la RPC.';
COMMENT ON COLUMN partidas.completada          IS 'true cuando la RPC de finalización ha cerrado la partida.';


-- ---------------------------------------------------------------------
-- Tabla: eventos_phishing  (telemetría del Módulo A)
-- Append-only desde el cliente: el rol anon solo puede INSERT.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eventos_phishing (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  partida_id          uuid NOT NULL REFERENCES partidas (id),
  jugador_id          uuid NOT NULL REFERENCES jugadores (id),
  correo_id           text NOT NULL,                       -- id lógico del correo evaluado (p. ej. "correo-003")
  decision            text NOT NULL,
  es_correcto         boolean NOT NULL,
  senal_clave         text NOT NULL DEFAULT 'sin_senales', -- vocabulario del modelo §7 (ver CHECK)
  tiempo_respuesta_ms int  NOT NULL,
  creado_en           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT eventos_phishing_decision_ck
    CHECK (decision IN ('PHISHING', 'LEGITIMO')),
  CONSTRAINT eventos_phishing_senal_ck
    CHECK (senal_clave IN ('dominio_sospechoso', 'urgencia', 'error_url',
                           'adjunto_inesperado', 'suplantacion_marca',
                           'saludo_generico', 'sin_senales')),
  CONSTRAINT eventos_phishing_tiempo_ck
    CHECK (tiempo_respuesta_ms >= 0)
);

COMMENT ON TABLE  eventos_phishing              IS 'Telemetría del módulo de análisis de phishing. Append-only: cliente solo INSERT.';
COMMENT ON COLUMN eventos_phishing.correo_id    IS 'Identificador lógico/ficticio del correo evaluado. NO es una dirección de email real (sin PII).';
COMMENT ON COLUMN eventos_phishing.decision     IS 'Clasificación elegida por el jugador: PHISHING o LEGITIMO.';
COMMENT ON COLUMN eventos_phishing.senal_clave  IS 'Señal del vocabulario controlado (modelo §7): dominio_sospechoso, urgencia, error_url, adjunto_inesperado, suplantacion_marca, saludo_generico. ''sin_senales'' si el correo es legítimo.';
COMMENT ON COLUMN eventos_phishing.tiempo_respuesta_ms IS 'Milisegundos entre ver el correo y decidir (>= 0).';


-- ---------------------------------------------------------------------
-- Tabla: eventos_password  (telemetría del Módulo B)
-- Append-only desde el cliente: el rol anon solo puede INSERT.
-- IMPORTANTE: jamás se guarda el texto de la contraseña — solo la
-- fortaleza numérica evaluada 0-4 (Contrato CyberGuard / constructor §3.3).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eventos_password (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  partida_id          uuid NOT NULL REFERENCES partidas (id),
  jugador_id          uuid NOT NULL REFERENCES jugadores (id),
  fase                text NOT NULL,
  es_correcto         boolean NOT NULL,
  fortaleza           int,                                 -- 0..4; NULL en fase 'descifrado'
  tiempo_respuesta_ms int  NOT NULL,
  creado_en           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT eventos_password_fase_ck
    CHECK (fase IN ('descifrado', 'fortaleza')),
  CONSTRAINT eventos_password_fortaleza_ck
    CHECK (fortaleza IS NULL OR fortaleza BETWEEN 0 AND 4),
  CONSTRAINT eventos_password_tiempo_ck
    CHECK (tiempo_respuesta_ms >= 0)
);

COMMENT ON TABLE  eventos_password           IS 'Telemetría del módulo de contraseñas/descifrado. Append-only: cliente solo INSERT. Nunca se almacena el texto de la contraseña.';
COMMENT ON COLUMN eventos_password.fase      IS 'Fase del mini-juego: ''descifrado'' (César/sustitución) o ''fortaleza'' (medidor de contraseña).';
COMMENT ON COLUMN eventos_password.fortaleza IS 'Fortaleza evaluada 0-4 (0=muy débil, 4=muy fuerte). NULL cuando la fase no mide fortaleza.';


-- ---------------------------------------------------------------------
-- Tabla: eventos_servidor  (telemetría del Módulo C)
-- Append-only desde el cliente: el rol anon solo puede INSERT.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eventos_servidor (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  partida_id          uuid NOT NULL REFERENCES partidas (id),
  jugador_id          uuid NOT NULL REFERENCES jugadores (id),
  servidor_id         text NOT NULL,                       -- id lógico del servidor (p. ej. "srv_01")
  vulnerabilidad      text NOT NULL,                       -- vocabulario del modelo §7 (ver CHECK)
  reparado            boolean NOT NULL,
  tiempo_respuesta_ms int  NOT NULL,
  creado_en           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT eventos_servidor_vulnerabilidad_ck
    CHECK (vulnerabilidad IN ('paquete_desactualizado', 'puerto_abierto', 'permisos_excesivos')),
  CONSTRAINT eventos_servidor_tiempo_ck
    CHECK (tiempo_respuesta_ms >= 0)
);

COMMENT ON TABLE  eventos_servidor             IS 'Telemetría del módulo de reparación de servidores. Append-only: cliente solo INSERT.';
COMMENT ON COLUMN eventos_servidor.vulnerabilidad IS 'Vocabulario controlado (modelo §7): paquete_desactualizado, puerto_abierto, permisos_excesivos.';


-- ---------------------------------------------------------------------
-- Índices
-- Looker Studio y las vistas v_* (T41) consultan masivamente por
-- partida, jugador y rango temporal: sin estos índices el dashboard
-- se degrada con volumen (constructor §3.3).
-- ---------------------------------------------------------------------
-- partidas
CREATE INDEX IF NOT EXISTS idx_partidas_jugador_id ON partidas (jugador_id);
CREATE INDEX IF NOT EXISTS idx_partidas_nivel_id   ON partidas (nivel_id);
CREATE INDEX IF NOT EXISTS idx_partidas_creado_en  ON partidas (iniciado_en);

-- eventos_phishing
CREATE INDEX IF NOT EXISTS idx_eventos_phishing_partida_id ON eventos_phishing (partida_id);
CREATE INDEX IF NOT EXISTS idx_eventos_phishing_jugador_id ON eventos_phishing (jugador_id);
CREATE INDEX IF NOT EXISTS idx_eventos_phishing_creado_en   ON eventos_phishing (creado_en);

-- eventos_password
CREATE INDEX IF NOT EXISTS idx_eventos_password_partida_id ON eventos_password (partida_id);
CREATE INDEX IF NOT EXISTS idx_eventos_password_jugador_id ON eventos_password (jugador_id);
CREATE INDEX IF NOT EXISTS idx_eventos_password_creado_en   ON eventos_password (creado_en);

-- eventos_servidor
CREATE INDEX IF NOT EXISTS idx_eventos_servidor_partida_id ON eventos_servidor (partida_id);
CREATE INDEX IF NOT EXISTS idx_eventos_servidor_jugador_id ON eventos_servidor (jugador_id);
CREATE INDEX IF NOT EXISTS idx_eventos_servidor_creado_en   ON eventos_servidor (creado_en);

-- jugadores
CREATE INDEX IF NOT EXISTS idx_jugadores_creado_en ON jugadores (creado_en);

-- Fin de schema.sql — continuar con rls.sql
