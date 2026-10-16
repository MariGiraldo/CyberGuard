-- =====================================================================
-- CyberGuard: Misión Ciberseguridad
-- archivo ....... codigo/backend/rpc_puntaje.sql   (Tarea T12)
-- motor ......... PostgreSQL 15 (Supabase)
-- idioma ........ comentarios en español
--
-- Descripción:
--   Funciones RPC invocables desde el cliente Godot vía PostgREST
--   (POST /rest/v1/rpc/<nombre_funcion>) con la clave `anon`.
--
-- Seguridad (Contrato CyberGuard §3.4):
--   * SECURITY DEFINER + search_path fijado → la función ejecuta con
--     los privilegios de su dueña y no es vulnerable a ataques de
--     manipulación del search_path.
--   * El PUNTAJE SE CALCULA EN SERVIDOR: el cliente NUNCA envía
--     `puntaje_total` como verdad; solo lo recibe de la RPC.
--   * EXECUTE concedido solo al rol `anon` (el `service_role` no se
--     usa desde el cliente jamás).
--   * Las políticas RLS de escritura siguen siendo solo INSERT: la RPC
--     (definer) es la única vía autorizada a modificar `partidas`.
--
-- Orden de ejecución: schema.sql → rls.sql → rpc_puntaje.sql → seed.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- fn_crear_partida
--   Crea una fila en `partidas` y devuelve su uuid.
--   El cliente llama a esta RPC en lugar de INSERTar partidas "a mano"
--   con cualquier estado, para que la creación quede validada
--   (jugador y nivel deben existir) en servidor.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_crear_partida(
  p_jugador_id uuid,
  p_nivel_id   int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_partida_id uuid;
BEGIN
  -- Validaciones con mensajes claros (las FK también lo harían,
  -- pero así el cliente recibe un error comprensible).
  IF p_jugador_id IS NULL OR p_nivel_id IS NULL THEN
    RAISE EXCEPTION 'fn_crear_partida: p_jugador_id y p_nivel_id no pueden ser NULL';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jugadores WHERE id = p_jugador_id) THEN
    RAISE EXCEPTION 'fn_crear_partida: el jugador % no existe', p_jugador_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM niveles WHERE id = p_nivel_id) THEN
    RAISE EXCEPTION 'fn_crear_partida: el nivel % no existe', p_nivel_id;
  END IF;

  -- Inicio de partida: puntaje 0, sin finalizar (lo hará la otra RPC).
  INSERT INTO partidas (jugador_id, nivel_id)
  VALUES (p_jugador_id, p_nivel_id)
  RETURNING id INTO v_partida_id;

  RETURN v_partida_id;
END;
$$;

COMMENT ON FUNCTION public.fn_crear_partida(uuid, int)
  IS 'RPC (cliente anon): crea una partida y devuelve su uuid. Valida jugador y nivel en servidor.';


-- ---------------------------------------------------------------------
-- fn_finalizar_partida
--   Calcula el puntaje TOTAL EN SERVIDOR a partir de los eventos
--   persistidos de esa partida y cierra la partida.
--
--   Fórmula (plan maestro §3.4):
--     acierto .............. +100   (eventos_* con es_correcto = true)
--     error ................  -50   (eventos_* con es_correcto = false)
--     bonus tiempo ......... +10 por segundo restante
--                            (solo si partidas.tiempo_restante_seg > 0)
--
--   El cliente NUNCA envía ni calcula el puntaje como verdad: solo
--   recibe el resultado devuelto por esta función y lo muestra.
--
--   Idempotente: si la partida ya estaba finalizada, se recalcula y se
--   conserva la primera fecha `finalizado_en`.
--
--   Parámetros:
--     p_partida_id      (obligatorio) uuid de la partida a cerrar.
--     p_tiempo_restante (OPCIONAL) segundos que quedaban al terminar.
--       - Si se envía, el SERVIDOR lo persiste en
--         partidas.tiempo_restante_seg y calcula el bonus con él.
--       - Si se omite (NULL), se usa el valor ya guardado en la tabla
--         (comportamiento de la firma original con un solo parámetro).
--       El cliente NUNCA envía el puntaje: solo el tiempo, que el
--       servidor valida y convierte en bonus.
--
--   NOTA DE SEGURIDAD: cualquiera con la anon key podría invocar la
--   RPC si conoce el uuid de una partida; los uuid son inadivinables
--   y, cuando exista sesión anónima, convendrá añadir aquí la
--   comprobación de pertenencia (partida.jugador_id = auth.uid()...).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_finalizar_partida(
  p_partida_id      uuid,
  p_tiempo_restante int DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_puntaje_eventos  integer;
  v_tiempo_restante  integer;
  v_finalizado_previo timestamptz;
  v_bonus            integer;
  v_puntaje_total    integer;
BEGIN
  IF p_partida_id IS NULL THEN
    RAISE EXCEPTION 'fn_finalizar_partida: p_partida_id no puede ser NULL';
  END IF;

  -- Validación defensiva del tiempo (nunca negativo).
  IF p_tiempo_restante IS NOT NULL AND p_tiempo_restante < 0 THEN
    RAISE EXCEPTION 'fn_finalizar_partida: p_tiempo_restante no puede ser negativo (recibido %)', p_tiempo_restante;
  END IF;

  -- La partida debe existir. Se recupera el estado previo y el tiempo
  -- efectivo: el enviado por el cliente si existe, si no el guardado.
  SELECT finalizado_en,
         COALESCE(p_tiempo_restante, tiempo_restante_seg)
    INTO v_finalizado_previo, v_tiempo_restante
    FROM partidas
   WHERE id = p_partida_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_finalizar_partida: la partida % no existe', p_partida_id;
  END IF;

  -- 1) Puntaje base a partir de los eventos de ESTA partida.
  --    Se unifican los tres módulos con la misma regla +100 / -50.
  SELECT COALESCE(SUM(CASE WHEN e.es_correcto THEN 100 ELSE -50 END), 0)
    INTO v_puntaje_eventos
    FROM (
      SELECT es_correcto FROM eventos_phishing WHERE partida_id = p_partida_id
      UNION ALL
      SELECT es_correcto FROM eventos_password WHERE partida_id = p_partida_id
      UNION ALL
      SELECT es_correcto FROM eventos_servidor  WHERE partida_id = p_partida_id
    ) AS e;

  -- 2) Bonus de tiempo: +10 por segundo restante, solo si es positivo.
  v_bonus := CASE
               WHEN COALESCE(v_tiempo_restante, 0) > 0
                 THEN v_tiempo_restante * 10
               ELSE 0
             END;

  v_puntaje_total := v_puntaje_eventos + v_bonus;

  -- 3) Cierre de la partida (única escritura autorizada en `partidas`
  --    más allá del INSERT inicial). Se persiste el tiempo recibido y,
  --    si ya estaba finalizada, se conserva su primera fecha.
  UPDATE partidas
     SET puntaje_total      = v_puntaje_total,
         tiempo_restante_seg = COALESCE(p_tiempo_restante, tiempo_restante_seg),
         finalizado_en      = COALESCE(v_finalizado_previo, now()),
         completada         = true
   WHERE id = p_partida_id;

  RETURN v_puntaje_total;
END;
$$;

COMMENT ON FUNCTION public.fn_finalizar_partida(uuid, int)
  IS 'RPC (cliente anon): calcula el puntaje EN SERVIDOR (acierto +100, error -50, bonus tiempo restante x10), cierra la partida y devuelve el puntaje. p_tiempo_restante es opcional y el servidor lo valida/persiste.';


-- ---------------------------------------------------------------------
-- Permisos de ejecución
--   Solo el rol `anon` (cliente Godot) puede invocar las RPC.
--   Se revoca el acceso público por defecto para dejar el mínimo
--   privilegio explícito. `service_role` no necesita grant especial
--   (es dueño/rol administrativo) y JAMÁS se envía al cliente.
-- ---------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.fn_crear_partida(uuid, int)    FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_finalizar_partida(uuid, int) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_crear_partida(uuid, int) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_finalizar_partida(uuid, int) TO anon;

-- Fin de rpc_puntaje.sql — continuar con ../database/seed.sql (solo pruebas)
