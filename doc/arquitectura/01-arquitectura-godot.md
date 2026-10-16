# Arquitectura Godot 4.6 — CyberGuard: Misión Ciberseguridad

> **Tarea:** T03 (`arquitecto`) — entregable integrado (versión compacta de `doc/arquitectura/01-…` + `02-…` + `03-…` del contrato del agente).
> **Fecha:** 2026-10-16 · **Estado:** Propuesto (pendiente Gate C2 del Guardián).
> **Fuentes:** `doc/plan/00-plan-maestro.md` (§4.1, §4.2, §8), `doc/dominio/01-modelo-dominio.md` (T02 — payloads congelados), `agentes/razonamiento/arquitecto.md`.
> **Consumidores:** `constructor` (T21 proyecto base, T31 servicios, T32 integración), `probador` (T33), `liberador` (T43 exports).

---

## 1. Reglas no negociables

1. **Godot 4.6** con **GDScript tipado** (`var x: int`, `func f() -> bool`, `class_name`). Prohibido Godot 3.x.
2. **Comentarios y documentación en español** en todo el código.
3. **Sin `service_role` en el cliente jamás.** Solo `SUPABASE_URL` + `SUPABASE_ANON_KEY`, cargadas en **runtime** (nunca en `.tscn`/`.tres` versionados).
4. **Append-only:** el cliente solo `INSERT` en `eventos_*` (garantizado además por RLS en servidor, T12).
5. **`HTTPRequest` asincrónico:** nunca bloquear el hilo principal; usar la señal `request_completed`.
6. Delta-based (`_process(delta)`), separando visual (`_process`) de lógica de movimiento (`_physics_process`).
7. Los payloads de telemetría son **literalmente** los de `doc/dominio/01-modelo-dominio.md` §4 (contrato congelado).

---

## 2. Estructura de carpetas EXACTA de `codigo/game/`

> Coincide carácter por carácter con el §4.1 del plan maestro. No añadir carpetas sin revisión del `arquitecto`.

```
codigo/game/
├── project.godot              # 320×180, Nearest, autoloads (Godot 4.6)
├── autoload/                  # GameState, Temporizador, Telemetria, Config
├── scenes/
│   ├── main/menu_principal.tscn
│   ├── mapa/oficina.tscn       # tilemap top-down, navegación, terminales
│   ├── terminales/             # terminal_correos, terminal_cifrado, terminal_servidores
│   ├── ui/hud.tscn, popup_feedback.tscn, resumen_nivel.tscn
│   └── modales/                # carta_email.tscn, medidor_password.tscn, panel_servidor.tscn
├── entities/                   # jugador (CharacterBody2D), terminales (Area2D)
├── systems/                    # lógica phishing, cifrado, servidores, scoring
├── services/                   # supabase_client.gd (HTTPRequest), cola_offline.gd
├── export/                     # presets Web (HTML5) y Windows
└── data/                       # niveles y correos en JSON (no en .tres con secretos)
```

| Carpeta | Contenido | Responsable de llenarla |
|---|---|---|
| `autoload/` | `config.gd`, `game_state.gd`, `temporizador.gd`, `telemetria.gd` (registrados en `project.godot`) | T21 |
| `scenes/main/` | Menú principal | T21/T22 |
| `scenes/mapa/` | Oficina top-down (TileMap, terminales, jugador) | T22 |
| `scenes/terminales/` | `terminal_correos.tscn` (T24), `terminal_cifrado.tscn` (T25), `terminal_servidores.tscn` (T26) | T24–T26 |
| `scenes/ui/` | `hud.tscn`, `popup_feedback.tscn`, `resumen_nivel.tscn` | T23 |
| `scenes/modales/` | `carta_email.tscn`, `medidor_password.tscn`, `panel_servidor.tscn` | T24–T26 |
| `entities/` | `jugador.gd/.tscn` (`CharacterBody2D`), `terminal.gd/.tscn` (`Area2D`) | T22 |
| `systems/` | `logica_phishing.gd`, `logica_cifrado.gd`, `logica_servidores.gd`, `scoring.gd` — **sin dependencia de red** (testables en headless, T33) | T24–T26 |
| `services/` | `supabase_client.gd`, `cola_offline.gd` | T31 |
| `export/` | `web.cfg` y `windows.cfg` (presets de exportación; sin secretos) | T43 |
| `data/` | `correos_nivel1.json` (fuente: `doc/diseno/01-misiones.md` §5), `niveles.json`, etc. | T24/T32 |
| `test/` *(posterior)* | Pruebas GUT headless (fuera del walking skeleton; T33) | T33 |

> **Nota de permisos:** el `project.godot` debe habilitar `FileSystem > Disk > Allow` solo para `res://data/` como máximo; los `.json` de `data/` se leen con `FileAccess` y **no** contienen secretos (regla del plan §4.1: "no en `.tres` con secretos").

---

## 3. `project.godot` (T21) — ajustes mínimos

| Ajuste | Valor | Motivo |
|---|---|---|
| `display/window/size/viewport_width` | `320` | Resolución base (§8, Contrato §3.1) |
| `display/window/size/viewport_height` | `180` | Resolución base |
| `display/window/stretch/mode` | `canvas_items` | Escalado pixel-perfect |
| `display/window/stretch/aspect` | `keep` | Conserva proporción |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (Nearest) | Pixel art sin suavizado |
| `rendering/2d/snap/snap_2d_transforms_to_pixel` | `true` | "Snap 2D to Pixel" (Guardián §3.1) |
| `rendering/2d/snap/snap_2d_vertexes_to_pixel` | `true` | Idem |
| Autoloads (en este orden) | `Config`, `GameState`, `Temporizador`, `Telemetria` | Orden = dependencias: Config primero |

---

## 4. Autoloads y su API pública

> API **congelada** para el walking skeleton. Cambios requieren revisión del `arquitecto` + Gate C2.

### 4.1 `Config` — `autoload/config.gd` (`extends Node`)

Carga `SUPABASE_URL` y `SUPABASE_ANON_KEY` en **runtime**. Prioridad de lectura (primero que encuentre, gana):

1. Variables de entorno del SO: `OS.get_environment("SUPABASE_URL")`.
2. `res://.env` (solo en desarrollo desde el editor; **excluido del export** con "Exclude filter" en T43).
3. `user://.env` (opción recomendada para escritorio/Web empaquetado).

**Nunca** se versiona `.env` (`.gitignore`); `.env.example` solo lleva placeholders (Contrato §3.2).

```gdscript
# autoload/config.gd
extends Node
## Carga de credenciales en runtime. Sin secretos en el repo.

const RUTA_ENV_LOCAL: String = "res://.env"
const RUTA_ENV_USUARIO: String = "user://.env"

var _valores: Dictionary = {}

func cargar_configuracion() -> bool:
    ## Lee variables de entorno y/o archivos .env. Devuelve true si la config es válida.
    ...

func obtener_url_supabase() -> String:
    ## Devuelve SUPABASE_URL (p. ej. "https://xxxx.supabase.co") o "" si falta.
    ...

func obtener_anon_key() -> String:
    ## Devuelve SUPABASE_ANON_KEY o "" si falta.
    ...

func esta_configurado() -> bool:
    ## true si URL y anon_key no están vacías.
    ...
```

### 4.2 `GameState` — `autoload/game_state.gd` (`extends Node`)

Sesión del jugador: `jugador_id` (uuid v4 seudónimo), `alias`, `partida_id`, nivel actual. Persiste `jugador_id`/`alias` en `user://perfil_jugador.json` (sin PII) para continuidad.

```gdscript
# autoload/game_state.gd
extends Node
## Sesión y estado de partida. Genera los uuid que viajan en toda la telemetría.

signal partida_iniciada(nivel_id: int, partida_id: String)
signal partida_finalizada(resumen: Dictionary)  ## resumen: aciertos, errores, puntaje_provisional, por_modulo

var jugador_id: String = ""   ## uuid v4 seudónimo (sin PII)
var alias_jugador: String = ""## seudónimo, p. ej. "agente-azul-42"
var partida_id: String = ""   ## uuid de la partida activa ("" si no hay)
var nivel_actual: int = 0     ## 1..4
var puntaje_provisional: int = 0  ## solo UX; la verdad es la RPC del servidor (T12)

func iniciar_partida(nivel_id: int) -> void:
    ## Crea partida_id (uuid v4), llama a GameState y emite partida_iniciada.
    ## INSERT en partidas vía SupabaseClient (append-only).
    ...

func finalizar_partida() -> void:
    ## Cierra la partida, dispara el drenado de la cola de telemetría
    ## y emite partida_finalizada con el resumen educativo (T23/T32).
    ...

func registrar_acierto(puntos: int = 100) -> void: ...   ## actualiza puntaje_provisional
func registrar_error(puntos: int = -50) -> void: ...
```

### 4.3 `Temporizador` — `autoload/temporizador.gd` (`extends Node`)

Temporizador global del nivel (5–8 min, ver `doc/diseno/01-misiones.md`). Delta-based.

```gdscript
# autoload/temporizador.gd
extends Node
## Temporizador global del nivel. Nunca bloquea; usa _process(delta).

signal expirado                                  ## fin del tiempo
signal actualizado(restante_seg: float)          ## emite ~1 vez/segundo para el HUD

var _duracion_total: float = 0.0
var _restante: float = 0.0
var _corriendo: bool = false

func iniciar(duracion_seg: float) -> void: ...   ## inicia (o reinicia) el temporizador
func pausar() -> void: ...                       ## congela (p. ej. al abrir un modal)
func reanudar() -> void: ...
func restante() -> float: ...                    ## segundos restantes (float)
func esta_corriendo() -> bool: ...
```

### 4.4 `Telemetria` — `autoload/telemetria.gd` (`extends Node`)

Punto único de escritura de eventos. Delega el envío a `services/supabase_client.gd` y la persistencia a `services/cola_offline.gd`.

```gdscript
# autoload/telemetria.gd
extends Node
## Registra eventos con los payloads congelados de doc/dominio/01-modelo-dominio.md §4.
## Cola offline en user://cola_eventos.json con reintentos y backoff exponencial.

signal evento_registrado(tabla: String, enviado_directo: bool)
signal cola_drenada(pendientes_restantes: int)

const TABLAS_PERMITIDAS: Array[String] = ["eventos_phishing", "eventos_password", "eventos_servidor"]
const RUTA_COLA: String = "user://cola_eventos.json"

func registrar_evento(tabla: String, payload: Dictionary) -> void:
    ## Valida tabla (whitelist) y claves del payload contra el contrato (§4 del modelo),
    ## marca la hora local y delega: intento directo → si falla, encola.
    ...

func drenar_cola() -> void:
    ## Intenta enviar los eventos encolados en FIFO con backoff. Llama el autostart
    ## al arrancar, la finalización de partida y cada N segundos mientras hay fallos.
    ...

func pendientes() -> int: ...   ## nº de eventos en cola (para el HUD/debug)
```

**Reglas de `Telemetria`:**
- Whitelist de tablas: cualquier otra tabla lanza `push_error` y se descarta (nadie puede escribir en `jugadores`/`partidas` desde aquí).
- Cada payload se serializa a JSON con la marca `creado_localmente_ms` (`Time.get_ticks_msec()`) para diagnóstico de la cola; **no** se envía al servidor (el servidor pone su `creado_en`).
- Máximo de reintentos por evento: 5 (backoff 1 s → 2 s → 4 s → 8 s → 16 s; luego 60 s). Tras 5 fallos, el evento se conserva en la cola y se reintenta en el drenado posterior (no se descarta silenciosamente).

---

## 5. `services/` — contrato de métodos (T31)

### 5.1 `services/supabase_client.gd`

```gdscript
class_name SupabaseClient
extends Node
## Cliente HTTPREST mínimo para PostgREST. Sin addons de terceros (ADR: HTTPRequest nativo).

signal evento_insertado(tabla: String, exito: bool, codigo_http: int)

var _http: HTTPRequest  ## creado en _ready(); timeout 10 s

func insertar_evento(tabla: String, payload: Dictionary) -> void:
    ## POST {SUPABASE_URL}/rest/v1/{tabla} con headers del §6.
    ## Emite evento_insertado(tabla, exito, codigo_http).
    ...

func insertar_lote(tabla: String, payloads: Array[Dictionary]) -> void:
    ## POST con body Array[Dictionary] (PostgREST acepta lotes). Usado por el drenado
    ## de la cola para reducir round-trips.
    ...

func insertar_partida(jugadores_id: String, nivel_id: int) -> void:
    ## INSERT inicial en `partidas` al iniciar partida (solo columnas de cliente:
    ## jugador_id, nivel_id). El servidor pone id/iniciada_en.
    ...
```

### 5.2 `services/cola_offline.gd`

```gdscript
class_name ColaOffline
extends Node
## Persistencia FIFO de eventos no enviados en user://cola_eventos.json.

func encolar(tabla: String, payload: Dictionary) -> void:
    ## Añade el evento al final de la cola y persiste a disco inmediatamente
    ## (sobrevive a cierre del navegador/SO).
    ...

func siguiente() -> Dictionary: ...      ## evento más antiguo sin descartar (o {})
func confirmar_enviado() -> void: ...    ## retira el evento tras 2xx del servidor
func incrementar_reintentos() -> int: ...## registra fallo; devuelve reintentos del evento
func recargar() -> void: ...             ## carga desde user:// (arranque del juego)
func limpiar() -> void: ...              ## solo para tests
```

**Semántica de reintentos/backoff (compartida con `Telemetria`):**

| Evento | Acción |
|---|---|
| HTTP 2xx | `confirmar_enviado()`; si la cola queda vacía → `cola_drenada(0)` |
| HTTP 4xx (400/403/409/422) | Error de contrato → **no** se reintenta en bucle; se marca el evento como `fallo_definitivo` y se conserva en la cola para diagnóstico (evita envenenar el backoff con payloads inválidos) |
| HTTP 5xx / timeout / error de red | `incrementar_reintentos()`; backoff exponencial (§4.4) |
| Reintento | FIFO estricto; un lote se envía con `insertar_lote` |

---

## 6. Contrato REST con Supabase (T10/T31)

### 6.1 Endpoint y headers

```
POST {SUPABASE_URL}/rest/v1/<tabla>
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=minimal
```

| Header | Valor | Por qué |
|---|---|---|
| `apikey` | anon key | Requerido por PostgREST/Supabase Gateway |
| `Authorization` | `Bearer <anon key>` | Autenticación del cliente (RLS evalúa con `anon`) |
| `Content-Type` | `application/json` | Body JSON |
| `Prefer` | `return=minimal` | Supabase añade `Prefer: return=representation` **por defecto**; sin esto, cada `INSERT` devuelve la fila completa (tráfico inútil en Web) |

### 6.2 Endpoints usados por el walking skeleton

| Método | Ruta | Uso | Quién |
|---|---|---|---|
| `POST` | `/rest/v1/jugadores` | Alta del alias seudónimo (`id`, `alias`) | `GameState` al primer arranque |
| `POST` | `/rest/v1/partidas` | Alta de partida (`jugador_id`, `nivel_id`) | `GameState.iniciar_partida` |
| `POST` | `/rest/v1/eventos_phishing` | Payload §4.1 del modelo | `Telemetria` (T24) |
| `POST` | `/rest/v1/eventos_password` | Payload §4.2 del modelo | `Telemetria` (T25) |
| `POST` | `/rest/v1/eventos_servidor` | Payload §4.3 del modelo | `Telemetria` (T26) |
| `POST` | `/rest/v1/rpc/calcular_puntaje` | RPC servidor (T12): cierra `puntaje_total` validado | `GameState.finalizar_partida` |

- **Solo `POST`.** El cliente jamás hace `SELECT`/`UPDATE`/`DELETE` sobre estas tablas (lo bloquea además el RLS append-only, T12).
- `INSERT` en `jugadores`/`partidas` también limitado por políticas específicas en `rls.sql` (solo columnas de cliente).

### 6.3 CORS / COL — obligatorio para build Web (T10)

1. En el panel de Supabase → **Settings → API → CORS**: añadir el origen del build Web (p. ej. el dominio de publicación y `http://localhost:8080` para pruebas locales). Configuración hecha por el usuario en la **T10** (decisión 5a/1a del §8).
2. PostgREST responde al preflight `OPTIONS`; verificar con el HTML5 exportado, no solo con el editor.
3. **Mitigación doble:** aunque CORS falle en un origen no permitido, la cola offline (`user://cola_eventos.json` en IndexedDB/localStorage del navegador) retiene los eventos y los drena al reconectar o tras permitir el origen (riesgo nº 1 del plan §9).

### 6.4 Manejo de errores

| Situación | Comportamiento |
|---|---|
| `esta_configurado() == false` | El juego entra en **modo offline**: todo funciona, `Telemetria` encola todo, HUD muestra aviso discreto. No se bloquea la partida (resiliencia T31/T32). |
| Timeout (10 s) / red caída | Encolar + backoff (§5.2) |
| HTTP 401/403 | Config/RLS mal configurado → log en español, aviso al `vigia`; no reintentar en bucle |
| HTTP 409/422 | Payload que viola el CHECK del esquema → `push_error` con detalle; conservar para diagnóstico |

---

## 7. Flujo de un evento (secuencia)

```
Jugador decide (terminal) 
   → systems/logica_*.gd evalúa (acierto/error, feedback educativo)
   → Telemetria.registrar_evento("eventos_phishing", payload§4.1)
        ├─ válido → SupabaseClient.insertar_evento → 2xx ⇒ listo
        └─ fallo  → ColaOffline.encolar("user://cola_eventos.json")
   → Temporizador.expirado (o "finalizar") ⇒ GameState.finalizar_partida()
        → drenado de la cola (FIFO, backoff)
        → RPC calcular_puntaje (T12) ⇒ partidas.puntaje_total en servidor
        → pantalla resumen (T23) con métricas = mismas columnas que verá Looker
```

---

## 8. Checklist de conformidad (verificación del Guardián y del `revisor`)

- [ ] GDScript 100% tipado; comentarios en español.
- [ ] `grep -rn "service_role" codigo/game/` → 0 coincidencias.
- [ ] Ningún `.tres`/`.tscn` contiene `SUPABASE_` (claves solo en runtime, §4.1).
- [ ] `.env` en `.gitignore`; `.env.example` solo placeholders (T43/T10).
- [ ] Payloads de `Telemetria` = literalmente modelo §4 (test T33).
- [ ] Cola offline sobrevive a corte de red (criterio T31).
- [ ] Export Web con `Exclude filter` de `res://.env`; presets en `export/` (T43).
- [ ] Estructura de carpetas idéntica al §2 de este documento (§4.1 del plan).

---

## 9. Decisiones y alternativas (mini-ADR)

| Decisión | Alternativa descartada | Motivo |
|---|---|---|
| `HTTPRequest` nativo | addon `godot-supabase` | Menos dependencias externas; el contrato REST es mínimo (solo `POST`); el addon traería superficie de PII/secretos que auditar (plan §4.2 lo permite como "o addon", elegimos HTTPRequest). |
| Cola en `user://cola_eventos.json` | Solo memoria | Persistencia real entre sesiones (cierre de pestaña Web); drenado FIFO al arrancar. |
| `Config` como autoload | Cargar en cada escena | Punto único de verdad de la config en runtime; orden de autoload garantiza disponibilidad. |
| Whitelist de tablas en `Telemetria` | Aceptar cualquier tabla | Un cliente comprometido no debe intentar escribir fuera de `eventos_*` (defensa en profundidad junto al RLS). |
| Sin `id` uuid generado por cliente | UUID por evento (idempotencia total) | El contrato de payloads (T02) es exacto y no lo incluye; se acepta el riesgo menor de duplicado ante timeout (documentado en modelo §5) |

---

## 10. Correspondencia con tareas

| Tarea | Qué entrega este documento |
|---|---|
| **T02** (hecho) | §6 usa los payloads congelados del modelo de dominio |
| **T03** | Este documento es su entregable |
| **T21** | §2 (carpetas), §3 (project.godot), §4 (autoloads) |
| **T31** | §5 (services), §6 (REST/CORS), §7 (flujo), cola offline |
| **T32** | §7 (integración nivel 1 punta a punta) |
| **T43** | §6.1 (headers), §8 (exclusión de `.env` en export, presets) |
| **T10/T11/T12** | §6.2 (endpoints) y §6.3 (CORS) condicionan la config del proyecto Supabase y el `rls.sql` |
