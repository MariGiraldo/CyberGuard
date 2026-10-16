# Estrategia de Ramas (GitFlow) — CyberGuard: Misión Ciberseguridad

> **Fuente:** derivado de `doc/plan/01-desglose-tareas.md`.
> Flujo: `feature/*` → `develop` → `release/*` → `main`, con revisión del `revisor` y `APROBADO` del `guardian` antes de `release`.

---

## 1. Ramas permanentes

| Rama | Propósito | Protegida |
|---|---|---|
| `main` | Producción; builds exportados de Godot | Sí (solo merge desde `release/*`) |
| `develop` | Integración continua del trabajo en curso | No |
| `release/x.y` | Candidato a publicación (código congelado) | Sí |

## 2. Ramas de tarea (`feature/`)

| Rama | Tareas | Responsable | Merge destino |
|---|---|---|---|
| `feature/fase0-contexto` | T01–T04 (documentación `doc/contexto`, `doc/dominio`, `doc/arquitectura`, `doc/diseno`) | `interrogador`, `analista-dominio`, `arquitecto`, `diseñador` | `develop` |
| `feature/fase1-schema` | T10–T13 (proyecto Supabase + `.env.example`, `codigo/database/schema.sql`, `rls.sql`, `seed.sql`) | `constructor` | `develop` |
| `feature/fase1-backend` | T12 (RPC de puntaje en `codigo/backend/`) | `constructor` | `develop` |
| `feature/godot-base` | T21–T23 (`project.godot`, autoloads, mapa, HUD, temporizador) | `constructor` | `develop` |
| `feature/modulo-phishing` | T24 (`terminal_correos.tscn`) | `constructor` | `develop` |
| `feature/modulo-contrasenas` | T25 (`terminal_cifrado.tscn`, medidor de fortaleza) | `constructor` | `develop` |
| `feature/modulo-servidores` | T26 (`terminal_servidores.tscn`) | `constructor` | `develop` |
| `feature/telemetria-supabase` | T31–T32 (servicios de red + integración del nivel 1) | `constructor` | `develop` |
| `feature/pruebas` | T33 (`codigo/game/test/`) | `probador` | `develop` |
| `feature/vistas-looker` | T41–T42 (`views.sql` + dashboard) | `constructor` | `develop` |
| `feature/docs-release` | T43 (`.env.example`, README, presets de export) | `liberador` | `develop` |

**Regla de paralelismo:** no abrir dos ramas `feature/` simultáneas que modifiquen el mismo archivo (p. ej. `feature/modulo-phishing` y `feature/modulo-contrasenas` no comparten archivos; `feature/fase1-schema` y `feature/fase1-backend` sí tocan la Fase 1 → secuenciar si comparten `rls.sql`).

## 3. Ciclo de vida

```
1. git checkout develop
2. git checkout -b feature/<nombre>        # una tarea de 01-desglose-tareas.md
3. Commit con formato: <id-tarea>: <descripción corta>   ej. "T24: clasificación de correos con feedback"
4. Push + Pull Request → develop
5. [probador] ejecuta pruebas  →  [revisor] emite checklist  →  (Gate C3) [guardian]
6. Merge a develop (squash o merge commit)
7. Al cerrar la fase: develop → release/x.y → tag → main  (previo Gate C4 [guardian] + [liberador])
8. Actualizar doc/plan/tablero.md a HECHO
```

## 4. Convenciones

- Nombre de rama en minúsculas y guiones: `feature/modulo-phishing`.
- **Nunca** commitear: `.env`, claves reales, `SUPABASE_SERVICE_ROLE_KEY`, assets sin licencia.
- Commits y mensajes en **español**, referenciando el `id` de tarea.
- Si una rama queda `BLOQUEADO` más de 1 ciclo → `triage` abre incidente y `planeador` replanifica.

## 5. Verificación

```bash
grep -nE "feature/" doc/plan/04-estrategia-ramas.md || echo "FALTAN ramas feature"
```
