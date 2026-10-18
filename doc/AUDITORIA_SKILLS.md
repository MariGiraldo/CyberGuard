# Auditoría de skills · cumplimiento en `codigo/`

**Fecha:** 2026-10-17  
**Alcance:** verificación e implementación del cumplimiento de las 4 skills del proyecto (`.opencode/skills/`) sobre el código de `codigo/`.  
**Método:** regla por regla de cada skill → búsqueda del estado actual en el código → corrección de los desvíos → verificación final con greps automáticos.

---

## 1. Skill `supabase-telemetry`

**Estado global: IMPLEMENTADA AHORA** (antes solo parcialmente cumplida; los contratos del payload ya existían, faltaba el resto).

| Regla de la skill | Estado | Evidencia / cambio |
|---|---|---|
| Payload exacto: `evento`, `partida_id`, `nivel_id`, `datos`, `ts_cliente`, `ts_servidor` (server) | ✔ Ya cumplida | `telemetria.gd` construye `obtener_payload()` con esas 6 claves exactas |
| `service_role` NUNCA en el cliente | ✔ Verificado | 0 coincidencias de `service_role` en `codigo/game/` (solo un comentario que lo prohíbe, en `supabase_client.gd:8`) |
| Endpoints `/rest/v1/eventos_{phishing,password,servidor}` | ✔ Ya cumplida | `SUPABASE_EVENTOS` en `telemetria.gd` |
| `Prefer: return=minimal` | ✔ Ya cumplida | `cabeceras_post()` |
| Cola offline: API congelada + versión `COLA_VERSION` + migración por cambio de versión | ✔ Ya cumplida | `cola_offline.gd` |
| Reintentos con backoff exponencial 1→2→4→8→16 s, luego 60 s | ✔ **Implementada ahora** | `telemetria.gd`: constantes `BACKOFF_BASE_MS`/`BACKOFF_MAX_MS`, `calcular_backoff_ms()`, aplicado al evento en cabeza |
| 3 disparadores de drenaje (arranque, fin de partida, periódico) | ✔ **Implementada ahora** | `iniciar_drenaje_periodico()`, `drenar_cola()` invocado desde `game_state.gd` al finalizar partida |
| Manejo de errores: 400/403/404 → descartar; 409 → tratar como éxito; 5xx/timeout → reintentar con backoff | ✔ **Implementada ahora** | `gestionar_respuesta_insert()` en `telemetria.gd` |
| `cola_drenada` al vaciarse la cola | ✔ **Implementada ahora** | `signal cola_drenada` emitida tras vaciado |
| Whitelist de tablas al encolar | ✔ **Implementada ahora** | `TABLAS_PERMITIDAS` + `_tabla_evento()` en `telemetria.gd` (solo `registrar_evento` público; los altas internas `_encolar_alta` siguen el flujo del doc arquitectura §4.4/§6.2) |
| `eventos_servidor` documentado en el skill | ✔ **Implementada ahora** | Ver sección 5: endpoint y payload añadidos a `supabase_client`/`telemetria` |

**Nota de diseño (decisión registrada):** el skill menciona `insertar_lote` como opción. Se mantiene el **drenaje FIFO de un evento por tanda** (máx. 10 por disparo) para conservar la atribución exacta del evento fallido y el backoff individual; el ahorro de round-trips se cubre con las 3 tandas por disparo. No se rompe ningún contrato congelado.

---

## 2. Skill `godot-ui-scaler`

**Estado global: IMPLEMENTADA AHORA** (los tamaños de panel ya eran correctos; faltaban anchors, fuentes y stretch).

| Regla de la skill | Estado | Evidencia / cambio |
|---|---|---|
| Resolución base 320×180, assets pixel art a escala 1×, sin filtro bilineal | ✔ Ya cumplida | `window/size viewport=320x180`, `default_texture_filter=0` |
| `snap/snap_2d_vertexes_to_pixel=true` | ✔ **Implementada ahora** | `project.godot` |
| `window/stretch/aspect="keep"` (letterbox en 16:9) | ✔ **Implementada ahora** | `project.godot` (`allow_resize=false` ya existía) |
| Fuentes: `font_size` 6–10 px en escenas Control | ✔ Verificado | 0 coincidencias de `font_size` fuera de [6,10] en `codigo/game/` |
| `autowrap_mode` en textos largos (≥ 15 usos) | ✔ Verificado | 17 usos de `AUTOWRAP_WORD_SMART` (menú, HUD, terminal de correos) |
| Tamaños múltiplos de 8 | ✔ Verificado | HUD 256×56 / 240×112, clamps 312/168; correos 288×160 |
| Anchos de columna: 120 px por correo | ✔ Ya cumplida | `terminal_correos.gd` |
| Un solo `anchor` por control | ✔ **Implementada ahora** | `menu_principal.gd`: `aviso_red` tenía un preset duplicado y contradictorio (`TOP_LEFT` + `TOP_WIDE`) → unificado en `PRESET_TOP_WIDE` |
| Tema `tema_ciberseguridad.tres` con estilos por tipo de widget | ✔ Ya cumplida | Referenciado en `project.godot` |

---

## 3. Skill `looker-analytics-schema`

**Estado global: IMPLEMENTADA AHORA** (antes: 0 de 4 vistas existían).

| Regla de la skill | Estado | Evidencia / cambio |
|---|---|---|
| `codigo/database/views.sql` con las 4 vistas (`v_resumen_vulnerabilidades`, `v_efectividad_nivel`, `v_ranking_jugadores`, `v_tendencia_diaria`) | ✔ **Implementada ahora (parcial)** | **Creado** `codigo/database/views.sql`: `v_resumen_vulnerabilidades` y `v_efectividad_nivel` completamente escritas, con `GRANT SELECT` a `looker_lectura` |
| Métricas de `v_resumen_vulnerabilidades` (caída phishing vs contraseñas) | ✔ Implementada ahora | `tasa_fallo_phishing_pct`, `tasa_fallo_password_pct`, `delta_caida_pct` con `NULLIF` |
| Métricas de `v_efectividad_nivel` (tiempo medio por nivel) | ✔ Implementada ahora | `avg(tiempo_respuesta_ms)/1000` + tramos |
| Orden de ejecución 1..4 | ✔ Implementada ahora | `ORDER BY orden_ejecucion, id` + comentario de cabecera |
| Privilegio mínimo a `looker_lectura` | ✔ **Implementada ahora** | `rls.sql`: eliminado `GRANT SELECT ON ALL TABLES` → solo `GRANT SELECT` a las vistas con alias público |
| `seed.sql` idempotente | ✔ **Implementada ahora** | `ON CONFLICT (partida_id)` y `(numero) DO NOTHING` en `puntuaciones`/`niveles` |

### ⚠️ Pendiente de decisión del guardian (Gate): `v_ranking_jugadores`

La vista de ranking **no se activa en producción**. El diseño (doc dominio §4.4) la describe como pendiente de aprobación del guardian y no puede filtrarse por `centro_educativo`/`nivel_inicial` con la política actual. En `views.sql` está **incluida pero bloqueada**: el bloque completo de SQL está comentado con una advertencia prominente, de modo que la decisión (activar / cambiar diseño / eliminarla del doc) queda visible y sin efectos sobre la base. El `seed.sql` no genera datos de ranking hasta que exista la vista.

`v_tendencia_diaria` queda fuera de este alcance: su doc (`doc/dominio/04-looker-studio.md`) aún no existe; cuando se escriba, se añadirá aquí siguiendo el mismo patrón.

---

## 4. Skill `cybersecurity-content-validator`

**Estado global: CUMPLIDA** (los datos ya eran ficticios; se endurecieron vocabulario e IDs).

| Regla de la skill | Estado | Evidencia / cambio |
|---|---|---|
| Cero PII real en `data/*.json`, seeds y textos de misiones | ✔ Verificado | 0 correos con TLD real (`.com/.es/.org/.net`) en `codigo/game/data/`; todo usa `.invalid` (RFC 2606); empresas ficticias en `oficina.gd` |
| Estructura de correos: `remitente`, `asunto`, `cuerpo`, `senales_clave`, `es_phishing` | ✔ **Implementada ahora** | `correos_nivel1.json` reescrito al esquema canónico del doc de diseño §5 (antes usaba claves propias: `tipo`, `remitente_dominio`, `senales`, `feedback_ok`…) |
| IDs `n1_c01…n1_c06` | ✔ **Implementada ahora** | Antes `correo-001…correo-006`; migrados en JSON, `logica_phishing.gd` y `test_phishing.gd` |
| Vocabulario de señales (7 valores) | ✔ **Implementada ahora** | `SENALES_VALIDAS` en `logica_phishing.gd`; `senal_de()` devuelve `'sin_senales'` por defecto en lugar de cadena vacía; `terminal_correos.gd` siempre envía `senal_clave` válida; `schema.sql` añade `CHECK` con `NOT NULL DEFAULT 'sin_senales'` y el seed usa el vocabulario |
| Contraseñas/credenciales ficticias | ✔ Verificado | Solo hashes de ejemplo y contraseñas de demostración marcadas como tales |
| Sin IPs reales | ✔ Verificado | Ningún patrón de IP en datos de juego; IPs de infra solo en comentarios de SQL de backend con nota "reemplazar" |
| Vocabulario `vulnerabilidad` (nuevo) | ✔ **Implementada ahora** | `schema.sql`: `CHECK` con los 6 valores; `seed.sql`: sección 7 de `eventos_servidor` coherente |

---

## 5. Verificaciones automáticas finales

| Comando | Resultado |
|---|---|
| `grep -rn "service_role" codigo/game/` | 0 en código (1 solo comentario que lo prohíbe) |
| `grep -rEn "font_size\s*=\s*(1[1-9]\|[2-9][0-9])" codigo/game/` | 0 |
| `grep -rEn "font_size\s*=\s*[0-5]\b" codigo/game/` | 0 |
| `grep -rn "GRANT SELECT ON ALL TABLES\|GRANT SELECT ON TABLE " codigo/database/` | 0 (solo `GRANT SELECT` sobre vistas) |
| `grep -rE "@[a-z0-9.-]+\.(com\|es\|org\|net)" codigo/game/data/` | 0 |
| `grep -rn "autowrap_mode" codigo/game/` | 17 usos |

---

## 6. Resumen de ficheros tocados en esta auditoría

| Ficha | Cambio |
|---|---|
| `codigo/database/views.sql` | **Nuevo**: 2 vistas + GRANTs + bloque de ranking comentado con advertencia |
| `codigo/database/schema.sql` | `CHECK` de `senal_clave` y `vulnerabilidad`; cabecera actualizada |
| `codigo/database/rls.sql` | Revoke de `GRANT SELECT ON ALL TABLES`; orden de ejecución actualizado |
| `codigo/database/seed.sql` | IDs `n1_c0N`, vocabulario completo, `eventos_servidor`, duraciones por nivel, idempotencia |
| `codigo/game/autoload/telemetria.gd` | Backoff exponencial, 3 disparadores de drenaje, whitelist, `cola_drenada` |
| `codigo/game/services/cola_offline.gd` | `fallo_definitivo` (4xx), `reintentos`, `creado_localmente_ms`; API congelada intacta |
| `codigo/game/autoload/game_state.gd` | Drenaje al finalizar partida |
| `codigo/game/systems/phishing/logica_phishing.gd` | Esquema canónico + vocabulario de señales |
| `codigo/game/data/correos_nivel1.json` | Reescrito al esquema canónico (dominios `.invalid`, IDs `n1_c0N`) |
| `codigo/game/data/niveles.json` | Reescrito (formato objeto con `id`/`numero`) |
| `codigo/game/scenes/terminales/terminal_correos.gd` | Campos canónicos, `senal_clave` siempre válida, panel 288×160 |
| `codigo/game/test/test_phishing.gd` | Adaptado + invariantes del validador |
| `codigo/game/project.godot` | `stretch/aspect=keep`, `snap_2d_vertexes_to_pixel` |
| `codigo/game/scenes/ui/hud.gd` | Tamaños/clamps a múltiplos de 8 |
| `codigo/game/scenes/main/menu_principal.gd` | Anchor duplicado de `aviso_red` unificado |
| `codigo/game/scenes/mapa/oficina.gd` | Rótulo "NexoData (empresa ficticia)" |
