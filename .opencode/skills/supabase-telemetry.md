---
name: supabase-telemetry
description: >-
  Interfaz de telemetría append-only de CyberGuard hacia Supabase REST
  (eventos_phishing, eventos_password, eventos_servidor): parámetros requeridos,
  payloads JSON de ejemplo y manejo de la cola de reintentos offline (cola_offline.gd).
  Usar siempre que se escriba o revise código de Telemetria/SupabaseClient/ColaOffline.
---

# Skill: Supabase Telemetry (append-only)

> **Fuentes congeladas:** `doc/dominio/01-modelo-dominio.md` §4 (payloads exactos),
> `doc/arquitectura/01-arquitectura-godot.md` §5–§7 (contrato REST y cola),
> `agentes/razonamiento/arquitecto.md` §3.2 · **Consumidor:** `constructor`.

---

## 1. Reglas no negociables

1. **Append-only**: el cliente solo hace `POST` (INSERT) sobre las tres tablas de eventos.
   Cero `SELECT`/`UPDATE`/`DELETE` (lo bloquea además el RLS en servidor).
2. **Whitelist de tablas**: solo `eventos_phishing`, `eventos_password`, `eventos_servidor`.
   Cualquier otra tabla → `push_error` y descarte del evento.
3. **Solo `anon key`**. Prohibido `service_role` en `codigo/game/` (auditado con
   `grep -rn "service_role" codigo/game/` → 0 coincidencias).
4. **Payloads literalmente** = `doc/dominio/01-modelo-dominio.md` §4. Sin `id`,
   sin `creado_en`, sin `puntaje_total` (los genera el servidor).
5. **Nunca** texto de contraseña ni derivada reversible; solo `fortaleza` 0–4.
6. **Nunca PII**: solo `partida_id` + `jugador_id` (uuid seudónimo).

## 2. Interfaz REST

```
POST {SUPABASE_URL}/rest/v1/<tabla>
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=minimal
```

| Endpoint | Uso | Emisor |
|---|---|---|
| `POST /rest/v1/eventos_phishing` | 1 fila por clasificación de correo | `Telemetria.registrar_evento` |
| `POST /rest/v1/eventos_password` | 1 fila por fase (descifrado/fortaleza) | `Telemetria.registrar_evento` |
| `POST /rest/v1/eventos_servidor` | 1 fila por intento de reparación | `Telemetria.registrar_evento` |
| `POST /rest/v1/partidas` | Alta de partida (`jugador_id`, `nivel_id`) | `GameState.iniciar_partida` |
| `POST /rest/v1/rpc/calcular_puntaje` | Cierre de `puntaje_total` en servidor | `GameState.finalizar_partida` |

**Granularidad:** 1 evento = 1 decisión evaluable del jugador (jamás eventos agregados).

## 3. Parámetros requeridos por evento

### 3.1 Comunes a los tres eventos

| Parámetro | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `partida_id` | uuid | ✅ | Partida activa (`GameState.partida_id`) |
| `jugador_id` | uuid | ✅ | uuid seudónimo del jugador en sesión |
| `tiempo_respuesta_ms` | integer ≥ 0 | ✅ | `Time.get_ticks_msec()` desde que abre el elemento hasta decidir |
| `es_correcto` | boolean | ✅ | `true` si coincide con la respuesta esperada del JSON de nivel |

> `senal_clave` es obligatoria **solo** en `eventos_phishing` (ver 3.2).

### 3.2 `eventos_phishing` — parámetros específicos

| Parámetro | Tipo | Valores |
|---|---|---|
| `correo_id` | text | ID estable del JSON (`n1_c01`…) |
| `decision` | text | `PHISHING` \| `LEGITIMO` (literal, sin tilde) |
| `senal_clave` | text | `dominio_sospechoso`, `urgencia`, `error_url`, `adjunto_inesperado`, `suplantacion_marca`, `saludo_generico`, `sin_senales` |

### 3.3 `eventos_password` — parámetros específicos

| Parámetro | Tipo | Valores |
|---|---|---|
| `fase` | text | `descifrado` \| `fortaleza` |
| `fortaleza` | smallint nullable | 0–4; **`null` obligatorio si `fase="descifrado"`** |

### 3.4 `eventos_servidor` — parámetros específicos

| Parámetro | Tipo | Valores |
|---|---|---|
| `servidor_id` | text | ID estable (`srv_01`…) |
| `vulnerabilidad` | text | `paquete_desactualizado`, `puerto_abierto`, `permisos_excesivos` |
| `reparado` | boolean | `true` si aplicó el parche correcto |

## 4. Ejemplos de payloads JSON

### 4.1 Phishing

```json
POST /rest/v1/eventos_phishing
{
  "partida_id": "550e8400-e29b-41d4-a716-446655440000",
  "jugador_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "correo_id": "n1_c01",
  "decision": "PHISHING",
  "es_correcto": true,
  "senal_clave": "dominio_sospechoso",
  "tiempo_respuesta_ms": 12450
}
```

### 4.2 Password (fase fortaleza)

```json
POST /rest/v1/eventos_password
{
  "partida_id": "550e8400-e29b-41d4-a716-446655440000",
  "jugador_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "fase": "fortaleza",
  "es_correcto": true,
  "fortaleza": 3,
  "tiempo_respuesta_ms": 8300
}
```

### 4.3 Servidor

```json
POST /rest/v1/eventos_servidor
{
  "partida_id": "550e8400-e29b-41d4-a716-446655440000",
  "jugador_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "servidor_id": "srv_01",
  "vulnerabilidad": "puerto_abierto",
  "reparado": true,
  "tiempo_respuesta_ms": 15780
}
```

### 4.4 Envío desde Godot (interface esperada)

```gdscript
# autoload/telemetria.gd — punto único de escritura
Telemetria.registrar_evento("eventos_phishing", {
  "partida_id": GameState.partida_id,
  "jugador_id": GameState.jugador_id,
  "correo_id": "n1_c01",
  "decision": "PHISHING",
  "es_correcto": true,
  "senal_clave": "dominio_sospechoso",
  "tiempo_respuesta_ms": 12450
})
# válido → SupabaseClient.insertar_evento(...) → 2xx = listo
# fallo  → ColaOffline.encolar("eventos_phishing", payload)
```

## 5. Cola de reintentos offline (`services/cola_offline.gd`)

**Persistencia:** `user://cola_eventos.json` (sobrevive a cierre de navegador/SO).
Cada evento serializado lleva la marca interna `creado_localmente_ms` para
diagnóstico; **no se envía al servidor** (el servidor pone su `creado_en`).

### 5.1 API

```gdscript
class_name ColaOffline extends Node
func encolar(tabla: String, payload: Dictionary) -> void  # FIFO + persistir a disco
func siguiente() -> Dictionary                            # evento más antiguo (o {})
func confirmar_enviado() -> void                          # retira tras 2xx
func incrementar_reintentos() -> int                      # registra fallo
func recargar() -> void                                   # carga en el arranque
func limpiar() -> void                                    # solo tests
```

### 5.2 Semántica de reintentos

| Resultado HTTP | Acción |
|---|---|
| `2xx` | `confirmar_enviado()`; cola vacía → señal `cola_drenada(0)` |
| `4xx` (400/403/409/422) | **No** reintentar en bucle: marcar `fallo_definitivo`, conservar el evento en cola para diagnóstico (evita envenenar el backoff con payloads inválidos) |
| `5xx` / timeout / red caída | `incrementar_reintentos()` + backoff exponencial |

**Backoff:** 1 s → 2 s → 4 s → 8 s → 16 s → (máx. 5 reintentos) → 60 s.
Tras 5 fallos el evento **nunca se descarta**: queda en cola y se reintenta en el
siguiente drenado.

**Disparadores de drenado (FIFO estricto, con `insertar_lote` para reducir round-trips):**
1. Arranque del juego (`recargar()` + `drenar_cola()`).
2. Finalización de partida (`GameState.finalizar_partida`).
3. Cada N segundos mientras haya fallos y la red vuelva.

**Modo offline:** si `Config.esta_configurado() == false`, todo funciona en local,
`Telemetria` encola todo y el HUD muestra un aviso discreto. Nunca se bloquea la partida.

## 6. Comandos de verificación

```bash
# Sin service_role en el cliente
grep -rn "service_role" codigo/game/ && echo VIOLACION || echo OK

# Headers correctos en el cliente
grep -rn "apikey\|Authorization: Bearer\|Prefer: return=minimal" codigo/game --include=*.gd

# Whitelist de tablas y ruta de la cola
grep -rn "eventos_phishing\|eventos_password\|eventos_servidor" codigo/game/autoload/telemetria.gd
grep -rn "user://cola_eventos.json" codigo/game

# Sin PII ni contraseñas en claro en payloads/SQL
grep -niE "password_texto|email|telefono|ip_address" codigo/database/schema.sql && echo PII || echo OK
```

## 7. Criterios de aceptación

- [ ] Payloads idénticos a los de `doc/dominio/01-modelo-dominio.md` §4.
- [ ] RLS: solo `INSERT` para `anon` en las tres `eventos_*`; sin `UPDATE`/`DELETE`.
- [ ] Cola offline persiste a disco, drena en FIFO y no descarta eventos.
- [ ] Cero apariciones de `service_role` en `codigo/game/`.
- [ ] Ningún evento contiene texto de contraseña ni campos de PII.
