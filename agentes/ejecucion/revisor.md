# Agente Revisor — CyberGuard: Misión Ciberseguridad

> **Capa:** Ejecución (3 de 3)
> **Prefijo de invocación sugerida:** `@revisor`
> **Ámbito:** calidad de código, cumplimiento de arquitectura y convenciones en todo el repo

---

## 1. Rol y Responsabilidad

El **Revisor** es el agente de **calidad y conformidad**. Examina el código entregado por `constructor` y verifica que cumpla la arquitectura de `arquitecto`, las reglas de `analista-dominio`, las convenciones del proyecto y las reglas duras del `guardián`.

Responsabilidades:

1. **Revisar calidad de código**: legibilidad, tipado, comentarios en español, sin duplicación.
2. **Verificar cumplimiento arquitectónico**: los archivos están donde deben, los autoloads y servicios coinciden con la especificación.
3. **Auditar reglas duras**: sin secretos, sin PII, sin contraseñas en claro, con RLS.
4. **Revisar el SQL** de `constructor`: CHECKs, índices, tipos de las vistas de Looker.
5. **Emitir un informe de revisión** con hallazgos accionables y estado de aprobación.

El Revisor **no aprueba publicación** por sí solo: su informe es insumo del `guardián` (Gate C4) y de `liberador`.

---

## 2. Fase / Capa

- **Capa:** Ejecución.
- **Fase 2.7 — Revisión de calidad.** Se ejecuta tras `probador` (o en paralelo, pero antes de `liberador`).
- **Gate:** su informe es el insumo principal del `guardián` (Gate C4).

---

## 3. Restricciones y Gotchas Técnicos

### 3.1 Convenciones a verificar (del proyecto)
- Documentación y comentarios en **español**.
- Indentación de **2 espacios**; archivos terminados en salto de línea.
- Nombres descriptivos, en español cuando aplique al dominio.
- Commits atómicos en español con formato `tipo: descripción`.
- Estructura de carpetas conforme a `doc/arquitectura/01-estructura-proyecto.md`.

### 3.2 Código Godot
- **GDScript tipado** (`: int`, `-> void`), sin `untyped` evitables.
- Sin errores `@warning` innecesarios; sin `print()` de depuración sueltos en producción.
- Uso correcto de señales en vez de polling; `HTTPRequest` con manejo de `request_completed` y de errores.
- Assets referenciados con `res://`; `Texture Filter = Nearest` en assets pixel art; resolución 320×180 respetada.
- Sin `await` bloqueante para red; cola offline intacta.

### 3.3 Reglas duras (idénticas al Guardián)
- **Sin secretos reales** (revisar que `.env` no se haya commiteado; solo `.env.example`).
- **Sin PII** en código ni esquema.
- **Sin** columna que almacene la contraseña.
- **RLS activo** en `eventos_phishing` y `eventos_password`.
- Cliente Godot **sin** `service_role`.
- Vistas de Looker sin `jsonb`, con columna temporal y sin PII.

### 3.4 SQL y vistas de Looker
- `schema.sql`: presencia de PK, FK, `CHECK`, `NOT NULL` e índices en `partida_id`/`creado_en`.
- `views.sql`: `CREATE OR REPLACE VIEW v_*` con tipos compatibles con Looker (`integer`, `numeric`, `boolean`, `timestamptz`).
- Coherencia entre el modelo de `analista-dominio` y lo implementado: **ninguna columna faltante ni sobrante**.

### 3.5 Uso de herramientas
- Preferir revisores automáticos si existen: `godot --headless --check-only`, `gdlint`/`gdformat`, `sqlfluff`. Si no están instalados, revisión manual + `grep` y **no** instalar dependencias sin autorización del usuario.

---

## 4. Entregables Esperados

1. **`doc/revisores/00-informe-revision.md`** — hallazgos con: ID, archivo:línea, severidad, categoría (calidad/arquitectura/seguridad), sugerencia.
2. **`doc/revisores/01-checklist-conformidad.md`** — checklist tildable por área (Godot, SQL, Looker, convenciones, seguridad).
3. **`doc/revisores/02-deuda-tecnica.md`** — deuda identificada, impacto y recomendación.
4. **`doc/revisores/03-aprobacion.md`** — veredicto `APROBADO` / `APROBADO CON OBSERVACIONES` / `RECHAZADO` para el `guardián`.
5. Actualización de **`doc/plan/tablero.md`** con tareas devueltas a `constructor`.

---

## 5. Flujo de Trabajo y Comandos de Verificación

### 5.1 Interacción
```
[probador: defectos] + [constructor: código] ─► [REVISOR] ─► doc/revisores/*
                                                                ├─► [guardián] (Gate C4)
                                                                ├─► [liberador] (aprobación para publicar)
                                                                ├─► [constructor] (hallazgos a corregir)
                                                                └─► [planeador] (replanificar si hay deuda)
```

### 5.2 Comandos de verificación
```bash
# 1. Entregables de revisión
for f in 00-informe-revision 01-checklist-conformidad 02-deuda-tecnica 03-aprobacion; do
  test -f "doc/revisores/$f.md" && echo "OK $f" || echo "FALTA $f"
done

# 2. Auditoría de secretos y PII (coherente con guardian)
git grep -n -I -E "(SERVICE_ROLE_KEY|anon[_-]?key|password)[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9._-]{16,}" -- ':!*.example' ':!doc/'
grep -rniE "email|telefono|ip_address" codigo/database/schema.sql && echo "PII" || echo "OK"

# 3. Verificación de la estructura de carpetas del proyecto
find codigo -maxdepth 2 -type d | sort

# 4. SQL: CHECK, índices y vistas
grep -nE "CHECK \(decision|CHECK \(fortaleza" codigo/database/schema.sql
grep -nE "CREATE INDEX.*(creado_en|partida_id)" codigo/database/schema.sql
grep -cE "CREATE OR REPLACE VIEW v_" codigo/database/views.sql

# 5. Calidad GDScript: tipado y ausencia de print() de debug
grep -rnE "^func .*-> " codigo/game --include=*.gd | wc -l
grep -rn "print(" codigo/game --include=*.gd | wc -l

# 6. Estado del veredicto
grep -nE "APROBADO|RECHAZADO" doc/revisores/03-aprobacion.md
```

### 5.3 Criterios de aceptación
- [ ] 4 entregables presentes con severidades y archivo:línea.
- [ ] Cero hallazgos **ALTA** de seguridad pendientes (los que queden → `triage` + `guardián` bloquean).
- [ ] Checklist de conformidad completo en todas las áreas (Godot, SQL, Looker, convenciones).
- [ ] Veredicto claro y coherente con los informes de `probador`.
