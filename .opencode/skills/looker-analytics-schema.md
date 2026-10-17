---
name: looker-analytics-schema
description: >-
  Consultas SQL de las vistas de Looker Studio para CyberGuard
  (v_resumen_vulnerabilidades, v_efectividad_nivel) y sus métricas clave:
  caída en phishing vs contraseñas débiles, tiempo medio de respuesta por nivel
  y ranking de jugadores. Usar al escribir views.sql o montar dashboards.
---

# Skill: Looker Analytics Schema (vistas `v_*`)

> **Fuentes:** `doc/dominio/01-modelo-dominio.md` §9 (trazabilidad de métricas),
> `agentes/razonamiento/arquitecto.md` §3.3, `agentes/ejecucion/constructor.md` §3.4 ·
> **Base de datos:** Supabase (PostgreSQL) · **Consumidor final:** Looker Studio.

---

## 1. Reglas de todas las vistas

1. **Solo lectura**: Looker se conecta con el rol `looker_lectura` sobre vistas `v_*`
   **nunca** sobre tablas crudas. Concesión mínima:
   `GRANT SELECT ON <vista> TO looker_lectura;`
2. **Sin PII**: prohibido `email`, `ip`, `user_agent`, teléfono, nombre real.
   Los datos por `jugador_id` solo se exponen como **alias seudónimo** (ver §5).
3. **Columna temporal obligatoria** en todas las vistas (`creado_en timestamptz`)
   para los filtros de fecha de Looker.
4. **Tipos estables** compatibles con Looker: `integer`, `numeric`, `boolean`,
   `timestamptz`, `text`. Prohibido `jsonb`.
5. **Tipos de porcentaje**: entregar como `numeric(5,2)` en escala 0–100
   (Looker formatea mejor `%` que `double precision`).
6. Toda métrica es **trazable** a `tabla.columna`; la vista es solo agregación.

## 2. Vista `v_resumen_vulnerabilidades`

Resumen por tipo de amenaza: vulnerabilidades de servidor más frecuentes y
señales de phishing más falladas (alimenta el bloque "¿Qué falla más?").

```sql
-- codigo/database/views.sql
CREATE OR REPLACE VIEW v_resumen_vulnerabilidades AS
-- 2a. Vulnerabilidades de servidor (Módulo C)
SELECT
  'servidor'::text                       AS modulo,
  e.vulnerabilidad                       AS categoria,
  COUNT(*)::integer                      AS total_eventos,
  COUNT(*) FILTER (WHERE NOT e.reparado)::integer AS total_fallos,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT e.reparado) / NULLIF(COUNT(*), 0), 2)
                                         AS pct_fallo,
  ROUND(AVG(e.tiempo_respuesta_ms)::numeric, 0)    AS tiempo_medio_respuesta_ms,
  MIN(e.creado_en)                       AS creado_en
FROM eventos_servidor e
GROUP BY e.vulnerabilidad

UNION ALL

-- 2b. Señales de phishing más falladas (Módulo A)
SELECT
  'phishing'::text,
  p.senal_clave,
  COUNT(*)::integer,
  COUNT(*) FILTER (WHERE NOT p.es_correcto)::integer,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT p.es_correcto) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(p.tiempo_respuesta_ms)::numeric, 0),
  MIN(p.creado_en)
FROM eventos_phishing p
GROUP BY p.senal_clave

UNION ALL

-- 2c. Fases de contraseñas por fortaleza esperada (Módulo B)
SELECT
  'password'::text,
  'fortaleza_' || COALESCE(w.fortaleza::text, 'na'),
  COUNT(*)::integer,
  COUNT(*) FILTER (WHERE NOT w.es_correcto)::integer,
  ROUND(100.0 * COUNT(*) FILTER (WHERE NOT w.es_correcto) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(w.tiempo_respuesta_ms)::numeric, 0),
  MIN(w.creado_en)
FROM eventos_password w
WHERE w.fase = 'fortaleza'
GROUP BY w.fortaleza;

GRANT SELECT ON v_resumen_vulnerabilidades TO looker_lectura;
```

| Columna | Tipo | Uso en Looker |
|---|---|---|
| `modulo` | text | Filtro/faceta: `servidor` \| `phishing` \| `password` |
| `categoria` | text | Eje: `vulnerabilidad`, `senal_clave` o `fortaleza_N` |
| `total_eventos` | integer | barras |
| `total_fallos` | integer | barras apiladas |
| `pct_fallo` | numeric(5,2) | score / mapa de calor |
| `tiempo_medio_respuesta_ms` | numeric | gauge |
| `creado_en` | timestamptz | filtro de fechas (obligatorio) |

## 3. Vista `v_efectividad_nivel`

Métrica principal T42: efectividad (acierto) por nivel y módulo, con tiempo medio.

```sql
CREATE OR REPLACE VIEW v_efectividad_nivel AS
SELECT
  pa.nivel_id::integer                          AS nivel_id,
  'phishing'::text                              AS modulo,
  COUNT(*)::integer                             AS total_eventos,
  ROUND(100.0 * SUM(p.es_correcto::int) / NULLIF(COUNT(*), 0), 2) AS pct_efectividad,
  ROUND(100.0 * SUM((NOT p.es_correcto)::int) / NULLIF(COUNT(*), 0), 2) AS pct_caida,
  ROUND(AVG(p.tiempo_respuesta_ms)::numeric, 0) AS tiempo_medio_respuesta_ms,
  MIN(p.creado_en)                              AS creado_en
FROM eventos_phishing p
JOIN partidas pa ON pa.id = p.partida_id
GROUP BY pa.nivel_id

UNION ALL

SELECT
  pa.nivel_id,
  'password',
  COUNT(*),
  ROUND(100.0 * SUM(w.es_correcto::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(100.0 * SUM((NOT w.es_correcto)::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(w.tiempo_respuesta_ms)::numeric, 0),
  MIN(w.creado_en)
FROM eventos_password w
JOIN partidas pa ON pa.id = w.partida_id
GROUP BY pa.nivel_id

UNION ALL

SELECT
  pa.nivel_id,
  'servidor',
  COUNT(*),
  ROUND(100.0 * SUM(e.reparado::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(100.0 * SUM((NOT e.reparado)::int) / NULLIF(COUNT(*), 0), 2),
  ROUND(AVG(e.tiempo_respuesta_ms)::numeric, 0),
  MIN(e.creado_en)
FROM eventos_servidor e
JOIN partidas pa ON pa.id = e.partida_id
GROUP BY pa.nivel_id;

GRANT SELECT ON v_efectividad_nivel TO looker_lectura;
```

## 4. Métricas clave (fórmulas exactas)

### 4.1 Porcentaje de caída: phishing vs contraseñas débiles

*Caída* = % de decisiones **incorrectas**. Ya está embebido en
`v_efectividad_nivel.pct_caida`; si se necesita suelto:

```sql
-- Caída en phishing (todo el módulo)
SELECT ROUND(100.0 * SUM((NOT es_correcto)::int) / COUNT(*), 2) AS pct_caida_phishing
FROM eventos_phishing;

-- Caída en contraseñas débiles (fase fortaleza con fortaleza esperada <= 1)
SELECT ROUND(100.0 * SUM((NOT es_correcto)::int) / COUNT(*), 2) AS pct_caida_contrasenas_debiles
FROM eventos_password
WHERE fase = 'fortaleza' AND fortaleza <= 1;
```

**Comparativa en Looker:** usar los dos scorecards en el mismo bloque para que el
contraste visual (rojo `#D73A49` / verde `#2EA043`) refleje qué módulo "cae" más.

### 4.2 Tiempo medio de respuesta por nivel

```sql
SELECT nivel_id, modulo, tiempo_medio_respuesta_ms
FROM v_efectividad_nivel
ORDER BY nivel_id, modulo;
```

`tiempo_medio_respuesta_ms = AVG(tiempo_respuesta_ms)` agrupado por
`partidas.nivel_id` (join por `partida_id`) y módulo. Para ver el detalle por
señal, añadir `GROUP BY senal_clave` sobre `eventos_phishing`.

### 4.3 Ranking de jugadores

> ⚠️ **Conflicto conocido:** la decisión 3a de `doc/dominio/01-modelo-dominio.md` §9/§11
> prohíbe vistas `v_ranking_*`. El usuario ordenó **incluir el ranking**; esta vista
> queda **pendiente de aprobación explícita del `guardián` en el Gate** antes de
> aplicarla en `views.sql` de producción. Sin PII: solo alias seudónimo.

```sql
CREATE OR REPLACE VIEW v_ranking_jugadores AS
SELECT
  j.alias::text                                AS alias_jugador,   -- seudónimo, sin PII
  COUNT(DISTINCT p.id)::integer                AS total_partidas,
  SUM(CASE WHEN ep.es_correcto THEN 1 ELSE 0 END)::integer
    + SUM(CASE WHEN ew.es_correcto THEN 1 ELSE 0 END)::integer
    + SUM(CASE WHEN es.reparado  THEN 1 ELSE 0 END)::integer      AS total_aciertos,
  ROUND(100.0 * (
      SUM(CASE WHEN ep.es_correcto THEN 1 ELSE 0 END)
    + SUM(CASE WHEN ew.es_correcto THEN 1 ELSE 0 END)
    + SUM(CASE WHEN es.reparado  THEN 1 ELSE 0 END)
  ) / NULLIF(
      COUNT(ep.id) + COUNT(ew.id) + COUNT(es.id), 0), 2)          AS pct_efectividad,
  MIN(ep.creado_en)                            AS creado_en
FROM jugadores j
JOIN partidas pa        ON pa.jugador_id = j.id
LEFT JOIN eventos_phishing ep ON ep.partida_id = pa.id
LEFT JOIN eventos_password  ew ON ew.partida_id = pa.id
LEFT JOIN eventos_servidor  es ON es.partida_id = pa.id
GROUP BY j.alias;

GRANT SELECT ON v_ranking_jugadores TO looker_lectura;
```

**Orden en Looker:** `ORDER BY pct_efectividad DESC, total_partidas DESC` en la tabla
de ranking. Si el `guardián` rechaza la vista, se retira y las métricas agregadas de
§2–§4 siguen siendo suficientes para el dashboard.

## 5. Correspondencia con las demás vistas del `constructor`

| Vista | Origen | Estado |
|---|---|---|
| `v_resumen_vulnerabilidades` | este skill (§2) | ✅ requerida |
| `v_efectividad_nivel` | este skill (§3) | ✅ requerida |
| `v_metricas_phishing`, `v_metricas_password`, `v_metricas_servidor`, `v_resumen_partidas` | `constructor.md` §3.4 / modelo §9 | compatibles: mismas columnas y tipos |
| `v_ranking_jugadores` | este skill (§4.3) | ⚠️ bloqueada hasta Gate del `guardián` |

## 6. Comandos de verificación

```bash
# 1. Vistas creadas y concedidas al rol de solo lectura
grep -n "CREATE OR REPLACE VIEW v_resumen_vulnerabilidades\|v_efectividad_nivel" codigo/database/views.sql
grep -n "GRANT SELECT.*looker_lectura" codigo/database/views.sql

# 2. Sin PII en las vistas
grep -niE "email|ip_address|telefono|user_agent|date_of_birth" codigo/database/views.sql && echo PII || echo OK

# 3. Toda vista con columna temporal y sin jsonb
grep -c "creado_en" codigo/database/views.sql
grep -ni "jsonb" codigo/database/views.sql && echo TIPO_INVALIDO || echo OK

# 4. Sin SELECT de tablas crudas desde Looker: solo vistas v_* con GRANT
grep -n "GRANT SELECT ON [^v]" codigo/database/views.sql && echo REVISAR || echo OK
```

## 7. Criterios de aceptación

- [ ] `v_resumen_vulnerabilidades` y `v_efectividad_nivel` creadas con tipos estables y `creado_en`.
- [ ] `pct_caida` calculable por módulo y para contraseñas débiles (`fortaleza <= 1`).
- [ ] Tiempo medio de respuesta disponible por `nivel_id` × módulo.
- [ ] Ranking incluido, sin PII (solo alias) y con la advertencia de decisión 3a visible.
- [ ] Solo `GRANT SELECT … TO looker_lectura`; ningún acceso a tablas crudas.
