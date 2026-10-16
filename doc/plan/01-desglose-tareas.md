# Desglose de Tareas — CyberGuard: Misión Ciberseguridad

> **Fuente:** derivado de `doc/plan/00-plan-maestro.md`.
> **Formato por tarea:** `id · título · agente responsable · dependencias · entregable · criterio de aceptación · estimación`.
> **Estados posibles:** `PENDIENTE` · `EN CURSO` · `BLOQUEADO` · `HECHO` (se reflejan en `doc/plan/tablero.md`).
> **Alcance aprobado (2026-10-16):** walking skeleton de 3 días → **T10, T11, T12, T13, T21, T22, T24, T31, T32**. El resto es hoja de ruta. Decisiones en `00-plan-maestro.md` §8.

---

## FASE 0 — Contexto y diseño (Gate C1/C2)

| id | Título | Agente responsable | Dependencias | Entregable | Criterio de aceptación | Estimación |
|---|---|---|---|---|---|---|
| T01 | Resolver preguntas abiertas (sección 8 del plan maestro) con el usuario | `interrogador` | — | ✅ **HECHO 2026-10-16** — decisiones registradas en `00-plan-maestro.md` §8 | Nº de niveles, sistema de puntuación, plataforma, versión de Godot y alcance decididos; sin preguntas abiertas sin respuesta | 0.5 d |
| T02 | Modelo de dominio: entidades, eventos de telemetría y métricas | `analista-dominio` | T01 | `doc/dominio/` | Entidades (`jugador`, `partida`, `nivel`, `evento`) y eventos por tipo de amenaza definidos con granularidad; métricas de Looker trazadas a un evento; sin entidades de ranking (decisión 3a) | 0.5 d |
| T03 | Arquitectura Godot 4.6 + contrato de integración Supabase | `arquitecto` | T02 | `doc/arquitectura/` | Estructura de carpetas de `codigo/game`, autoloads y `services/` definidos; contrato REST (headers, cola offline, RLS, CORS Web) documentado | 0.5 d |
| T04 | Diseño de misiones/niveles y guía de estilo pixel art | `diseñador` | T01 | `doc/diseno/01-misiones.md`, `doc/diseno/03-guia-estilo-pixelart.md` | 4 niveles de 5–8 min con objetivo, amenazas incluidas, dificultad y puntuación; guía 320×180 / assets 16×16 | 1 d |
| T05 | Gate C2 — veredicto del Guardián sobre diseño y arquitectura | `guardian` | T03, T04 | `doc/guardian/veredicto-c2-<fecha>.md` | Resultado `APROBADO` o `APROBADO CON OBSERVACIONES`; ningún hallazgo ALTA activo | 0.25 d |

## FASE 1 — Walking skeleton de datos (crítico)

| id | Título | Agente responsable | Dependencias | Entregable | Criterio de aceptación | Estimación |
|---|---|---|---|---|---|---|
| T10 | **Crear proyecto Supabase + credenciales en `.env` local + CORS Web** | `constructor`, usuario | T03 | Proyecto Supabase activo; `.env` local y `.env.example` | `SUPABASE_URL` y `SUPABASE_ANON_KEY` disponibles en `.env` local (**nunca** en el repo); orígenes Web (HTML5) permitidos en CORS; `.env.example` solo con placeholders | 0.25 d |
| T11 | Esquema SQL: `schema.sql` + migraciones | `constructor` | T10 | `codigo/database/schema.sql` | Tablas `jugadores`, `partidas`, `niveles`, `eventos_phishing`, `eventos_password`, `eventos_servidor` creadas; FK `NOT NULL`; `creado_en timestamptz default now()`; ejecutable limpio en Postgres 15 | 0.5 d |
| T12 | Políticas RLS append-only + RPC de puntaje | `constructor` | T11 | `codigo/database/rls.sql`, `codigo/backend/` | Cliente con `anon` solo puede `INSERT` (sin `UPDATE`/`DELETE`); `puntaje_total` calculado en servidor; sin `service_role` en el cliente | 0.5 d |
| T13 | `seed.sql` de prueba | `constructor` | T11 | `codigo/database/seed.sql` | Seed insertable sin errores; datos ficticios que permiten probar vistas y dashboard | 0.25 d |
| T14 | Gate de verificación de seguridad (secretos + RLS) | `guardian` | T12 | `doc/guardian/veredicto-c1-c3-<fecha>.md` | Escaneo de secretos limpio; `.env` en `.gitignore`; RLS activo en tablas `eventos_%` | 0.25 d |

## FASE 2 — Proyecto Godot + terminales

| id | Título | Agente responsable | Dependencias | Entregable | Criterio de aceptación | Estimación |
|---|---|---|---|---|---|---|
| T21 | Proyecto Godot base: `project.godot`, autoloads, 320×180/Nearest | `constructor` | T03 | `codigo/game/project.godot` | Abre sin errores en **Godot 4.6**; resolución base y filtros configurados; autoloads registrados | 0.5 d |
| T22 | Mapa top-down + jugador + interacción con terminales | `constructor` | T21 | `codigo/game/scenes/mapa/`, `codigo/game/entities/` | Movimiento (WASD/flechas) y `Point & Click` funcionales; el jugador abre una terminal con `Area2D` | 1 d |
| T23 | HUD + temporizador global + pantalla de resumen | `constructor` | T21 | `codigo/game/scenes/ui/hud.tscn`, `resumen_nivel.tscn` | Temporizador corre; al expirar se muestra resumen con aciertos/errores por tipo de amenaza y explicación educativa | 0.5 d |
| T24 | Módulo A — análisis de correos / phishing | `constructor` | T22 | `codigo/game/scenes/terminales/terminal_correos.tscn` | 6 correos clasificables (`PHISHING`/`LEGÍTIMO`); feedback educativo por señal; evento registrado en telemetría | 1.5 d |
| T25 | Módulo B — contraseñas seguras + descifrado | `constructor` | T22 | `codigo/game/scenes/terminales/terminal_cifrado.tscn` | Mini-juego de descifrado completable; medidor de fortaleza con los 5 criterios; feedback educativo | 1 d |
| T26 | Módulo C — servidores infectados | `constructor` | T22 | `codigo/game/scenes/terminales/terminal_servidores.tscn` | Vulnerabilidad identificable y reparable; estado del servidor y penalización por propagación funcionales | 1 d |

## FASE 3 — Telemetría + pruebas

| id | Título | Agente responsable | Dependencias | Entregable | Criterio de aceptación | Estimación |
|---|---|---|---|---|---|---|
| T31 | Cliente Supabase + cola offline | `constructor` | T12, T21 | `codigo/game/services/supabase_client.gd`, `cola_offline.gd` | Evento visible en Supabase tras la partida; con red cortada, la cola retiene y drena los eventos al reconectar | 1 d |
| T32 | Nivel 1 (onboarding) integrado de punta a punta | `constructor` | T23, T24, T25, T26, T31 | Nivel 1 jugable | Partida completa: mapa → terminales → temporizador → resumen → eventos persistidos | 1 d |
| T33 | Pruebas de lógica educativa (GUT / headless) | `probador` | T32 | `codigo/game/test/` | Tests de clasificación de phishing, medidor de fortaleza y reparación de servidores en verde; ejecutables sin GUI | 1 d |
| T34 | Revisión de conformidad + Gate C3/C4 | `revisor`, `guardian` | T33 | `doc/revisores/01-checklist-conformidad.md`, veredicto | Checklist completo en todas las áreas (Godot, SQL, Looker, convenciones, seguridad); ningún hallazgo ALTA | 0.5 d |

## FASE 4 — Analítica y publicación

| id | Título | Agente responsable | Dependencias | Entregable | Criterio de aceptación | Estimación |
|---|---|---|---|---|---|---|
| T41 | Vistas SQL `v_*` sin PII | `constructor` | T31 | `codigo/database/views.sql` | Tipos estables (`timestamptz`, `text`, `boolean`, `integer`, `numeric`); sin `jsonb`; sin `email`/`ip`/PII; siempre con campo temporal | 0.5 d |
| T42 | Dashboard Looker Studio (rol `looker_lectura`) | `constructor` | T41 | Enlace del dashboard + capturas en `doc/` | 3 métricas visibles (vulnerabilidades comunes, tasa de efectividad por nivel, tiempo de respuesta) en solo lectura | 0.5 d |
| T43 | `.env.example`, README de instalación, export Web + escritorio | `liberador` | T42 | `.env.example`, README actualizado, presets Web/Windows | Juego ejecutable en Web y Windows siguiendo el README; solo placeholders en el repo; sin secretos reales | 0.5 d |
| T44 | Gate C4/C5 final — veredicto del Guardián | `guardian` | T43 | `doc/guardian/veredicto-c4-c5-<fecha>.md` | Resultado `APROBADO` antes de publicar; veredicto vigente | 0.25 d |

---

## Resumen de estimaciones

| Fase | Tareas | Estimación |
|---|---|---|
| FASE 0 — Contexto y diseño | 5 (T01 ✅ HECHA) | 2.75 d |
| FASE 1 — Walking skeleton de datos | 5 | 1.75 d |
| FASE 2 — Proyecto Godot + terminales | 6 | 5.5 d |
| FASE 3 — Telemetría + pruebas | 4 | 3 d |
| FASE 4 — Analítica y publicación | 4 | 1.75 d |
| **Total (hoja de ruta)** | **26** | **~14.75 d** |

**Alcance aprobado — walking skeleton de 3 días (decisión 7a):**
`T10 → T11 → T12 → T13 → T21 → T22 → T24 → T31 → T32`
(recorte: T14, T23, T25–T26, T33–T44 quedan como fase posterior)

## Reglas de planificación

1. Orden de dependencias no negociable: **proyecto Supabase (T10)** → `schema.sql` → backend/RLS → estructura Godot → módulo Phishing → Contraseñas → `views.sql` → Looker.
2. Prohibido ejecutar en paralelo dos tareas que tocan el **mismo archivo**.
3. Tareas críticas: T10 (secretos/CORS), T11 (esquema de eventos), T12 (RLS), T42 (Looker), T43 (secretos en build).
4. Todo bloqueo reportado por `triage` o `revisor` se refleja en `tablero.md` y obliga a replanificar.
5. Decisiones de alcance cerradas el 2026-10-16 → ver `00-plan-maestro.md` §8.
