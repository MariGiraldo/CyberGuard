# Asignación de Agentes — CyberGuard: Misión Ciberseguridad

> **Fuente:** derivado de `doc/plan/01-desglose-tareas.md`.
> Define qué tarea va a `constructor` / `probador` / `revisor` y el **orden de invocación**.
> **Alcance vigente (3 días, decisión 7a):** T10, T11, T12, T13, T21, T22, T24, T31, T32 — ver `00-plan-maestro.md` §8.

---

## 1. Matriz de asignación

| Tarea | Título | Agente ejecutor | Revisión / gate posterior |
|---|---|---|---|
| T01 | Resolver preguntas abiertas | `interrogador` | `curador` → Gate C1 (`guardian`) |
| T02 | Modelo de dominio | `analista-dominio` | `arquitecto` |
| T03 | Arquitectura Godot + Supabase | `arquitecto` | Gate C2 (`guardian`) |
| T04 | Diseño de misiones y estilo | `diseñador` | Gate C2 (`guardian`) |
| T05 | Gate C2 | `guardian` | — |
| T10 | Proyecto Supabase + `.env` local + CORS Web | `constructor` (con el usuario) | `guardian` (Gate C4 revisa secretos) |
| T11 | `schema.sql` + migraciones | `constructor` | `revisor` (SQL) → Gate C3 (`guardian`) |
| T12 | `rls.sql` + RPC de puntaje | `constructor` | `revisor` + `guardian` (crítico: RLS) |
| T13 | `seed.sql` | `constructor` | `probador` (inserta seed en pruebas) |
| T14 | Gate verificación seguridad | `guardian` | — |
| T21 | Proyecto Godot base | `constructor` | `revisor` (Godot) |
| T22 | Mapa + jugador + terminales | `constructor` | `probador` (interacción) |
| T23 | HUD + temporizador + resumen | `constructor` | `probador` (expiración del temporizador) |
| T24 | Módulo A phishing | `constructor` | `probador` (casos phishing/legítimo) |
| T25 | Módulo B contraseñas | `constructor` | `probador` (medidor de fortaleza) |
| T26 | Módulo C servidores | `constructor` | `probador` (reparación/propagación) |
| T31 | Cliente Supabase + cola offline | `constructor` | `revisor` (crítico: sin `service_role`, RLS) |
| T32 | Nivel 1 integrado | `constructor` | `probador` (flujo completo) |
| T33 | Pruebas automatizadas | `probador` | `revisor` |
| T34 | Revisión de conformidad + Gate C3/C4 | `revisor` + `guardian` | `liberador` |
| T41 | `views.sql` sin PII | `constructor` | `guardian` (crítico: PII) |
| T42 | Dashboard Looker Studio | `constructor` | `revisor` (solo lectura) |
| T43 | `.env.example` + README + build | `liberador` | `guardian` (crítico: secretos) |
| T44 | Gate C4/C5 final | `guardian` | — |

**Agentes no ejecutores:** `triage` (gestiona bloqueos), `vigia` (monitoriza producción), `planeador` (replanifica cuando `triage`/`revisor` reportan).

---

## 2. Orden de invocación por fase

```
FASE 0:  [interrogador] → [curador] → (Gate C1) [guardian]
         [analista-dominio] → [arquitecto] + [diseñador] → (Gate C2) [guardian] → [planeador]

FASE 1:  [constructor] (T11→T12→T13) → (Gate) [guardian] (T14)

FASE 2:  [constructor] (T21 → T22 → T23/T24/T25/T26)
              │
              ├─(si hay bloqueos)→ [triage] → [planeador] replanifica
              ▼
FASE 3:  [constructor] (T31, T32) → [probador] (T33) → [revisor] (T34) → (Gate C3/C4) [guardian]

FASE 4:  [constructor] (T41, T42) → [liberador] (T43) → (Gate C4/C5) [guardian] → publicación
              │
         [vigia] + [triage] en bucle continuo (Gate C5)
```

### Flujo resumido

```
[constructor] ─► (Gate C3) [guardian] ─► [probador] ─► [revisor] ─► (Gate C4) [guardian] ─► [liberador]
                        ▲                                      │
                        └──────── [triage] (si hay bloqueos) ───┘
```

---

## 3. Reglas de asignación

1. **`constructor`** es el único agente que escribe código en `codigo/` (Godot, backend, SQL).
2. **`probador`** escribe y ejecuta pruebas; no implementa funcionalidad.
3. **`revisor`** solo emite hallazgos con `archivo:línea` y severidad; no corrige.
4. **`guardian`** tiene veto: sin veredicto `APROBADO` vigente, `liberador` no publica.
5. **`planeador`** no ejecuta: asigna y replanifica; el tablero (`tablero.md`) es su fuente de estado.
6. Ninguna tarea se asigna en paralelo a dos agentes que toquen el **mismo archivo**.

---

## 4. Verificación

```bash
grep -nE "constructor|probador|revisor" doc/plan/03-asignacion-agentes.md
```
