# Tablero de Tareas — CyberGuard: Misión Ciberseguridad

> **Estado vivo.** Actualizar al cambiar el estado de cualquier tarea.
> Estados: `PENDIENTE` · `EN CURSO` · `BLOQUEADO` · `HECHO`
> Fuentes: `00-plan-maestro.md`, `01-desglose-tareas.md`, `03-asignacion-agentes.md`.

**Última actualización:** 2026-10-16
**Alcance vigente:** walking skeleton de 3 días → tareas **T10, T11, T12, T13, T21, T22, T24, T31, T32** (resto: hoja de ruta).

---

## Resumen

| Estado | Nº tareas |
|---|---|
| PENDIENTE | 9 |
| EN CURSO | 2 (T10, T33) |
| BLOQUEADO | 0 |
| HECHO | 13 (T01–T04, T11–T13, T21–T24, T31, T32) |

---

## FASE 0 — Contexto y diseño

| ID | Tarea | Responsable | Estado | Notas |
|---|---|---|---|---|
| T01 | Resolver preguntas abiertas con el usuario | `interrogador` | **`HECHO`** | 2026-10-16: decisiones 1a, 2a, 3a, Godot 4.6, 5a, 6a, 7a registradas en `00-plan-maestro.md` §8 |
| T02 | Modelo de dominio | `analista-dominio` | **`HECHO`** | 2026-10-16: `doc/dominio/01-modelo-dominio.md` — payloads exactos, granularidad, trazabilidad a Looker |
| T03 | Arquitectura Godot 4.6 + Supabase | `arquitecto` | **`HECHO`** | 2026-10-16: `doc/arquitectura/01-arquitectura-godot.md` — autoloads, services, contrato REST/CORS |
| T04 | Diseño de misiones y guía pixel art | `diseñador` | **`HECHO`** | 2026-10-16: `doc/diseno/01-misiones.md` (4 niveles + nivel 1 con 6 correos) y `03-guia-estilo-pixelart.md` |
| T05 | Gate C2 — veredicto Guardián | `guardian` | `PENDIENTE` | Depende de T03 + T04 |

## FASE 1 — Walking skeleton de datos

| ID | Tarea | Responsable | Estado | Notas |
|---|---|---|---|---|
| T10 | Crear proyecto Supabase + `.env` local + CORS Web | `constructor`, usuario | **`EN CURSO`** | **En alcance** · Listo: `.env.example`, `.gitignore` y guía `doc/contexto/05-supabase-crear-proyecto.md`. **Falta al usuario**: crear proyecto, rellenar `.env` y activar CORS/origen Web |
| T11 | `schema.sql` + migraciones | `constructor` | **`HECHO`** | **En alcance** · 2026-10-16: `codigo/database/schema.sql` (6 tablas, validado con parser). Pendiente ejecutarlo en Supabase tras T10 |
| T12 | `rls.sql` + RPC de puntaje | `constructor` | **`HECHO`** | **En alcance** · `rls.sql` (append-only, rol `looker_lectura`) + `codigo/backend/rpc_puntaje.sql` (`fn_finalizar_partida` con bonus). Pendiente ejecutar tras T11 |
| T13 | `seed.sql` de prueba | `constructor` | **`HECHO`** | **En alcance** · Seed idempotente con 4 niveles, 1 partida y 6 eventos ficticios. Pendiente ejecutar tras T12 |
| T14 | Gate verificación seguridad | `guardian` | `PENDIENTE` | Hoja de ruta (fuera del walking skeleton) |

## FASE 2 — Proyecto Godot + terminales

| ID | Tarea | Responsable | Estado | Notas |
|---|---|---|---|---|
| T21 | Proyecto Godot base (4.6) | `constructor` | **`HECHO`** | **En alcance** · 2026-10-16: `project.godot` (320×180, Nearest, Snap, 4 autoloads). Validado con Godot 4.6.1 headless: import + ejecución sin errores |
| T22 | Mapa + jugador + terminales | `constructor` | **`HECHO`** | **En alcance** · WASD/flechas + clic-para-caminar + `Area2D`; 3 terminales (1 activa, 2 bloqueadas). Validado headless |
| T23 | HUD + temporizador + resumen | `constructor` | **`HECHO`** | Mínimo integrado en T32: HUD, reloj con aviso <30 s, resumen final con mensaje educativo |
| T24 | Módulo A: phishing | `constructor` | **`HECHO`** | **En alcance** · Prioridad 1 · 6 correos (3 phishing/3 legítimos) con feedback por señal, botón "investigar enlace" y evento `eventos_phishing` |
| T25 | Módulo B: contraseñas + descifrado | `constructor` | `PENDIENTE` | Hoja de ruta · Prioridad 2 |
| T26 | Módulo C: servidores infectados | `constructor` | `PENDIENTE` | Hoja de ruta · Prioridad 3 |

## FASE 3 — Telemetría + pruebas

| ID | Tarea | Responsable | Estado | Notas |
|---|---|---|---|---|
| T31 | Cliente Supabase + cola offline | `constructor` | **`HECHO`** | **En alcance** · `supabase_client.gd` + `cola_offline.gd` + drenado con reintento; cola offline verificada en headless (retiene eventos sin red). Falta prueba con red real → requiere T10 |
| T32 | Nivel 1 integrado | `constructor` | **`HECHO`** | **En alcance** · Flujo completo validado headless: menú → oficina → partida → terminales → resumen. Pendiente playtest manual en el editor |
| T33 | Pruebas automatizadas | `probador` | **`EN CURSO`** | `codigo/game/test/test_phishing.gd` en verde (20 comprobaciones headless). Faltan tests de T25/T26 (aún no existen) |
| T34 | Revisión conformidad + Gate C3/C4 | `revisor`, `guardian` | `PENDIENTE` | Hoja de ruta |

## FASE 4 — Analítica y publicación

| ID | Tarea | Responsable | Estado | Notas |
|---|---|---|---|---|
| T41 | `views.sql` sin PII | `constructor` | `PENDIENTE` | Hoja de ruta |
| T42 | Dashboard Looker Studio | `constructor` | `PENDIENTE` | Hoja de ruta · Propenso a fallos de permisos |
| T43 | `.env.example` + README + export Web/Windows | `liberador` | `PENDIENTE` | Hoja de ruta · Crítico: secretos |
| T44 | Gate C4/C5 final | `guardian` | `PENDIENTE` | Hoja de ruta · Requisito para publicar |

---

## Bloqueos activos

Ninguno. Cuando `triage` o `revisor` reporten un bloqueo:

1. Cambiar el estado de la tarea a `BLOQUEADO` en su fila.
2. Añadir incidencia con severidad en la tabla siguiente.
3. Notificar a `planeador` para replanificación.

| ID | Tarea bloqueada | Severidad (ALTA/MEDIA/BAJA) | Causa | Incidencia `triage` |
|---|---|---|---|---|
| — | — | — | — | — |

---

## Historial de cambios

| Fecha | Tarea | Cambio | Responsable |
|---|---|---|---|
| 2026-10-16 | — | Creación del tablero (tareas en `PENDIENTE`) | `planeador` |
| 2026-10-16 | T01 | `PENDIENTE` → **`HECHO`**: 7 preguntas respondidas por el usuario (decisiones en `00-plan-maestro.md` §8) | `planeador` |
| 2026-10-16 | T10 | Nueva tarea añadida (crear proyecto Supabase, decisión 5a) | `planeador` |
| 2026-10-16 | Alcance | Fijado walking skeleton de 3 días (decisión 7a); tareas fuera de alcance marcadas "Hoja de ruta" | `planeador` |
| 2026-10-16 | T02, T03, T04 | `PENDIENTE` → **`HECHO`**: documentación de Fase 0 creada en `doc/dominio/`, `doc/arquitectura/` y `doc/diseno/` | `ejecutor` |
| 2026-10-16 | T10 | `PENDIENTE` → **`EN CURSO`**: `.env.example`, `.gitignore` y guía creados; pendiente acción del usuario (proyecto Supabase + `.env` + CORS) | `ejecutor` |
| 2026-10-16 | T11, T12, T13 | `PENDIENTE` → **`HECHO`**: `schema.sql`, `rls.sql`, `rpc_puntaje.sql` y `seed.sql` creados y validados con parser (pendientes de ejecución en el servidor tras T10) | `ejecutor` |
| 2026-10-16 | T21, T22, T23, T24 | `PENDIENTE` → **`HECHO`**: proyecto Godot 4.6 completo (mapa, jugador, HUD, módulo de phishing) validado headless sin errores | `ejecutor` |
| 2026-10-16 | T31, T32 | `PENDIENTE` → **`HECHO`**: cliente Supabase + cola offline y Nivel 1 integrado de punta a punta (validado headless) | `ejecutor` |
| 2026-10-16 | T33 | `PENDIENTE` → **`EN CURSO`**: `test_phishing.gd` con 20 comprobaciones en verde | `ejecutor` |
| 2026-10-16 | 00-plan-maestro | §3.3 Nivel 1 aclarado: 6 correos (2 guiados con reloj pausado + 4 con reloj), resolviendo la discrepancia 3 vs 6 | `ejecutor` |

---

## Verificación

```bash
# Detectar tareas bloqueadas sin replanificar
grep -n "BLOQUEADO" doc/plan/tablero.md
```
