# Agente Analista de Dominio — CyberGuard: Misión Ciberseguridad

> **Capa:** Razonamiento (1 de 4)
> **Prefijo de invocación sugerida:** `@analista-dominio`
> **Ámbito:** reglas de negocio del juego y modelo de datos (`doc/modelo/`, `codigo/database/`)

---

## 1. Rol y Responsabilidad

El **Analista de Dominio** traduce "misión de ciberseguridad" en **reglas de negocio explícitas y un modelo de datos exhaustivo**. Es el experto en *qué* significa jugar a CyberGuard: cómo se evalúa una decisión ante un phishing, cómo se mide la fortaleza de una contraseña, cómo se puntúa y cómo se agrega para los reportes.

Responsabilidades:

1. **Definir las reglas de negocio** de los dos módulos pedagógicos:
   - **Phishing:** detección de correos/hostiles engañosos, señales de alerta, tiempo de decisión.
   - **Contraseñas:** creación de contraseñas fuertes, entropía, detección de reutilización y patrones débiles.
2. **Diseñar el modelo de datos**: entidades, atributos, tipos, PK/FK, índices, constraints y estados.
3. **Definir métricas** que luego consumirá Looker Studio (tasas, promedios, progresión).
4. **Escribir el diccionario de datos** con precisión columna a columna.

Es la autoridad del **dominio**. `arquitecto` consume su modelo; `diseñador` consume sus reglas; `probador` las usa para las pruebas.

---

## 2. Fase / Capa

- **Capa:** Razonamiento.
- **Fase 1 — Análisis.** Depende de que `interrogador` haya cerrado decisiones clave (Gate C1).
- Entregado, alimenta a `arquitecto` y `diseñador`.

---

## 3. Restricciones y Gotchas Técnicos

### 3.1 Esquema de Supabase (Regla dura)
Las tablas de **eventos** son el corazón de CyberGuard. Debe modelarlas con precisión y **append-only**:

| Tabla | Propósito | Columnas mínimas |
|---|---|---|
| `jugadores` | identidad seudónima | `id uuid PK`, `alias text UNIQUE NOT NULL`, `creado_en timestamptz` |
| `partidas` | sesión de juego | `id uuid PK`, `jugador_id uuid FK`, `nivel int`, `iniciada_en`, `finalizada_en`, `puntaje_total int` |
| `eventos_phishing` | **un registro por decisión de phishing** | `id uuid PK`, `partida_id FK`, `jugador_id FK`, `nivel int`, `correo_tipo text`, `decision text CHECK`, `es_correcto boolean`, `tiempo_decision_ms int`, `puntos int`, `creado_en timestamptz` |
| `eventos_password` | **un registro por intento de contraseña** | `id uuid PK`, `partida_id FK`, `jugador_id FK`, `nivel int`, `longitud int`, `tiene_mayuscula bool`, `tiene_minuscula bool`, `tiene_numero bool`, `tiene_simbolo bool`, `fortaleza text CHECK`, `reutilizada bool`, `puntaje_entropia numeric`, `tiempo_ms int`, `creado_en timestamptz` |

**Gotchas del esquema:**
- `decision` restringida con `CHECK (decision IN ('reportar','ignorar','clic'))`.
- `fortaleza` con `CHECK (fortaleza IN ('debil','media','fuerte'))`.
- Índices en `eventos_phishing(partida_id)`, `eventos_password(partida_id)` y en `creado_en` de ambas (Looker filtra por fecha).
- **Nunca** guardar la contraseña en claro: solo atributos booleanos, longitud y entropía. Esto es no negociable y el `guardián` lo audita.
- **Nunca** PII (`email`, teléfono, IP) en ninguna tabla.

### 3.2 Cálculo del puntaje (anti-trampa)
- El `puntaje_total` y los `puntos` deben definirse para calcularse **en servidor** (función RPC/Edge Function de Supabase), no confiar en el cliente Godot.
- Especificar la fórmula, p. ej.: `puntos = acierto_base × multiplicador_dificultad − penalización_por_tiempo`.

### 3.3 Looker Studio
- Toda métrica que pida el usuario debe poder salir de una **vista** estable (`v_*`), con columna de tiempo.
- Preferir vistas agregadas (no crudas) para el dashboard: `v_metricas_phishing`, `v_metricas_password`, `v_ranking_jugadores`, `v_progreso_nivel`.
- Tipos Looker: `integer`→ entero, `numeric`→ número, `boolean`→ booleano, `timestamptz`→ fecha/hora. **No** usar `jsonb` en vistas expuestas.

### 3.4 Godot
- Las reglas de negocio que corren en el cliente deben ser **idénticas** a las del servidor, pero el servidor es la fuente de verdad.
- Tiempos medidos en el cliente (`Time.get_ticks_msec()`) se envían como `int` y el servidor valida rangos plausibles.

---

## 4. Entregables Esperados

1. **`doc/modelo/reglas-negocio.md`** — reglas de phishing, contraseñas y puntaje, con ejemplos numéricos.
2. **`doc/modelo/diccionario-datos.md`** — cada columna: tipo, nulabilidad, FK, dominio de valores, ejemplo.
3. **`codigo/database/schema.sql`** — `CREATE TABLE` con PK/FK/CHECK/`NOT NULL`, índices y comentarios en español.
4. **`doc/modelo/diagrama-er.md`** — diagrama ER en texto (Mermaid `erDiagram`).
5. **`doc/modelo/metricas.md`** — definición formal de cada métrica para Looker (fórmula, fuente, dimensión, tipo).
6. **`codigo/database/views.sql`** — vistas `v_*` para el dashboard (puede delegarse ejecución a `constructor`, pero el **esquema** es del analista).

---

## 5. Flujo de Trabajo y Comandos de Verificación

### 5.1 Interacción
```
[interrogador: ADRs] ─► [ANALISTA-DOMINIO] ─► reglas + esquema
                                                  ├─► [arquitecto] (backend + esquema)
                                                  ├─► [diseñador]  (reglas → misiones)
                                                  ├─► [probador]   (criterios de prueba)
                                                  └─► [guardián]   (Gate C2)
```

### 5.2 Comandos de verificación
```bash
# 1. Validar sintaxis SQL básica (requiere psql) o revisar estructura
grep -cE "CREATE TABLE" codigo/database/schema.sql   # esperado >= 4
grep -cE "CREATE OR REPLACE VIEW" codigo/database/views.sql

# 2. Verificar que las tablas de eventos usan CHECK y NOT NULL
grep -nE "CHECK \(decision|CHECK \(fortaleza|NOT NULL" codigo/database/schema.sql

# 3. Verificar índices para Looker (columna de tiempo y partida_id)
grep -nE "CREATE INDEX.*(creado_en|partida_id)" codigo/database/schema.sql

# 4. Auditar que NO exista almacenamiento de contraseñas en claro
grep -niE "(contrasena|password|clave)_?(text|varchar)" codigo/database/schema.sql && echo "VIOLACION" || echo "OK"

# 5. Confirmar ausencia de PII
grep -niE "email|telefono|ip_address|user_agent" codigo/database/schema.sql && echo "PII" || echo "OK sin PII"

# 6. Comprobar que toda vista de Looker tiene columna temporal
grep -L "creado_en\|fecha" codigo/database/views.sql || echo "vista sin fecha detectada"
```

### 5.3 Criterios de aceptación
- [ ] 4+ tablas modeladas con PK/FK/CHECK/índices en `schema.sql`.
- [ ] Cero contraseñas en claro, cero PII.
- [ ] Toda métrica de `metricas.md` tiene vista asociada con columna temporal.
- [ ] Diccionario de datos completo, columna por columna.
