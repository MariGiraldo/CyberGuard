---
name: cybersecurity-content-validator
description: >-
  Validador de contenido de ciberseguridad de CyberGuard: regla estricta de
  NO PII (cero nombres reales, correos reales o teléfonos reales) y estructura
  de datos de los correos ficticios de phishing (remitente, asunto, cuerpo,
  senales_clave, es_phishing). Usar al generar o revisar data/*.json, seeds
  o textos de misiones.
---

# Skill: Cybersecurity Content Validator (NO PII)

> **Fuentes:** Contrato CyberGuard §3.3/§3.6, `doc/dominio/01-modelo-dominio.md` §1/§7,
> `doc/diseno/01-misiones.md` §5 (esquema canónico de correos) ·
> **Consumidores:** `constructor` (T24/T32, `seed.sql`), `guardián` (auditoría), `revisor`.

---

## 1. Regla estricta NO PII

**Cero PII real en cualquier artefacto del proyecto** (JSON de contenido, SQL,
escenas, textos de UI, documentación, commits). Esto es auditado en cada Gate.

### 1.1 Prohibido (bloqueo inmediato)

| Tipo | Ejemplo prohibido | Por qué |
|---|---|---|
| Nombre real de persona | `Juan Pérez García`, `María López` | PII de personas reales |
| Correo real | `ana@gmail.com`, `director@empresa-real.com` | PII + dominio real |
| Teléfono real | `+34 612 345 678`, formato real creíble | PII |
| IP real / host real | `192.168.1.1`, `google.com` | Dirección identificable |
| Marca comercial real | `PayPal`, `Santander`, `Google` (dibujada o en texto) | §3.6: solo marcas ficticias |
| Fecha de nacimiento, DNI, curso, edad | cualquier valor | perfil de usuario prohibido (§11 del modelo) |
| `user_agent`, cookies, geo | cualquier valor | fuera de alcance y riesgo de PII |

### 1.2 Permitido (sustituciones obligatorias)

| En lugar de | Usar |
|---|---|
| Persona real | **Alias seudónimo**: `agente-azul-42`, `jugador-rojo-07` |
| Saludo personalizado | Genérico: `Estimado usuario`, `Hola:` — o un **personaje ficticio registrado** (p. ej. la empleada ficticia `Marta` de Nexodata, sin ningún dato real asociado) |
| Correo real | Dirección bajo dominio **`.invalid`** (RFC 2606/6761): `soporte@nexodata-verificacion.invalid` |
| URL real | Solo `*.invalid`: `https://aurora-clientes.banco-aurora.invalid/login` |
| Teléfono | **No aparecer nunca** en el contenido; si una escena lo pide, usar texto marcado como ficticio sin formato real (`ext. 0000`) |
| Empresa real | Marcas ficticias del proyecto: **Nexodata** (empresa), **Banco Aurora**, **TiendaNova** |

### 1.3 Comandos de detección (obligatorios en cada entrega)

```bash
# 1. Correos que no terminen en .invalid (en contenido y seeds)
grep -rnoE "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}" codigo/game/data codigo/database \
  | grep -v "\.invalid" && echo "PII: correo real" || echo OK

# 2. Teléfonos con formato real
grep -rnE "\+?[0-9]{2,3}[ -]?[0-9]{3}[ -]?[0-9]{3}[ -]?[0-9]{3}" codigo/game/data codigo/database \
  && echo "PII: telefono" || echo OK

# 3. IPs
grep -rnE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" codigo/game/data && echo "PII: ip" || echo OK

# 4. Marcas comerciales prohibidas en contenido de phishing
grep -rniE "paypal|santander|google|microsoft|apple|whatsapp" codigo/game/data \
  && echo "MARCA REAL" || echo OK

# 5. Vocabulario de señales coherente con el modelo §7
grep -rhoE '"senal_clave": "[a-z_]+"' codigo/game/data | sort -u
```

## 2. Estructura de datos: correos ficticios de phishing

Fuente canónica: `doc/diseno/01-misiones.md` §5 · Archivo:
`codigo/game/data/correos_nivel<N>.json`.

### 2.1 Esquema (obligatorio campo a campo)

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `id` | string | ✅ | `correo_id` estable: `n1_c01`… viaja en `eventos_phishing.correo_id` |
| `remitente` | string | ✅ | Dirección **ficticia** bajo `.invalid`; si `es_phishing=true` debe imitar un dominio oficial (`nexodata-verificacion.invalid`) |
| `asunto` | string | ✅ | Sin PII; si `es_phishing=true` puede usar urgencia/suplantación |
| `cuerpo` | string | ✅ | Texto breve (~2–4 frases), sin nombres reales ni datos reales |
| `enlace_texto` | string \| null | ✅ | Texto visible; `null` si no hay enlace |
| `enlace_url` | string \| null | ✅ | URL real `*.invalid` que revela la investigación; `null` si no hay |
| `adjunto` | string \| null | ✅ | Nombre de archivo ficticio; `null` si no hay |
| `es_phishing` | bool | ✅ | Respuesta esperada (define la `decision` correcta) |
| `senal_clave` | string | ✅ | **Vocabulario controlado §7** (ver 2.2) |
| `senal_secundaria` | string \| null | ✅ | Segunda señal de apoyo o `null` |
| `guiado` | bool | ✅ | Modo tutorial paso a paso (Nivel 1) |
| `feedback_acierto` | string | ✅ | Frase educativa al acertar |
| `feedback_error` | string | ✅ | Explicación educativa al fallar (nunca culpa al jugador) |

### 2.2 Vocabulario controlado de señales (CHECK del dominio §7)

```
senal_clave ∈ { dominio_sospechoso, urgencia, error_url, adjunto_inesperado,
                suplantacion_marca, saludo_generico, sin_senales }
```

**Invariantes:**
1. `es_phishing = false` ⇒ `senal_clave = "sin_senales"` (y `senal_secundaria = null`).
2. `es_phishing = true` ⇒ `senal_clave` ∈ las 6 señales pedagógicas (nunca `sin_senales`).
3. Si `enlace_texto ≠ null` ⇒ `enlace_url ≠ null` (y viceversa).
4. Todo `enlace_url` y `remitente` terminan en `.invalid`.
5. `id` único dentro del archivo; formato `n<N>_c<NN>`.

### 2.3 Ejemplo válido — PHISHING

```json
{
  "id": "n1_c01",
  "remitente": "soporte@nexodata-verificacion.invalid",
  "asunto": "Verificación obligatoria de tu cuenta de correo",
  "cuerpo": "Estimado usuario: hemos detectado actividad inusual en tu cuenta. Verifica tu identidad en el siguiente enlace antes de 24 horas o tu acceso será suspendido.",
  "enlace_texto": "https://nexodata.invalid/verificar",
  "enlace_url": "https://nexodata-verificacion.invalid/verificar",
  "adjunto": null,
  "es_phishing": true,
  "senal_clave": "dominio_sospechoso",
  "senal_secundaria": "saludo_generico",
  "guiado": true,
  "feedback_acierto": "¡Correcto! El dominio del enlace no coincide con el de la empresa: 'nexodata-verificacion' añade un guion que imita al oficial.",
  "feedback_error": "Era phishing. Mira la URL real detrás del texto del enlace: el dominio oficial es 'nexodata.invalid'. Además te saludan de forma genérica."
}
```

### 2.4 Ejemplo válido — LEGÍTIMO

```json
{
  "id": "n1_c06",
  "remitente": "it-helpdesk@nexodata.invalid",
  "asunto": "Mantenimiento programado del sistema de correo — sábado 02:00–04:00",
  "cuerpo": "Hola: el sábado de madrugada aplicaremos una actualización de seguridad al correo. Durante esas horas podrás leer mensajes, pero no enviar. No se te pedirá ninguna contraseña por ningún canal.",
  "enlace_texto": "Aviso de mantenimiento",
  "enlace_url": "https://intranet.nexodata.invalid/aviso-mantenimiento",
  "adjunto": null,
  "es_phishing": false,
  "senal_clave": "sin_senales",
  "senal_secundaria": null,
  "guiado": true,
  "feedback_acierto": "¡Correcto! El TI real avisa con antelación, usa el dominio interno y nunca pide contraseñas por correo.",
  "feedback_error": "Era legítimo. Anuncia con tiempo, enlaza a la intranet oficial y recuerda que nunca pedirán claves: ese es el patrón de un aviso real."
}
```

### 2.5 Ejemplo inválido (rechazar)

```json
{
  "id": "c01",
  "remitente": "seguridad@paypal.com",          // ✗ dominio real + marca real
  "asunto": "Ana, tu factura",                  // ✗ nombre de persona real
  "cuerpo": "Llámanos al +34 612 345 678",      // ✗ teléfono real
  "es_phishing": true,
  "senal_clave": "prueba"                       // ✗ fuera del vocabulario §7
}
```

## 3. Reglas de redacción de los textos

1. **Urgencia permitida solo en phishing** y debe ser detectable (`urgencia`, plazos artificiales).
2. **Los legítimos nunca piden credenciales, clics urgentes ni adjuntos inesperados.**
3. `feedback_*`: siempre explican **la regla aprendida**, en español, sin culpar.
4. No redibujar ni mencionar marcas comerciales reales (§8.3 de la guía de estilo).
5. Extensión: `cuerpo` ≈ 150–350 caracteres (cabe en el modal 320×180 con autowrap).
6. `seed.sql` con datos **solo ficticios** y el mismo vocabulario §7.

## 4. Criterios de aceptación

- [ ] Cero correos/teléfonos/IPs/nombres reales (comandos §1.3 en verde).
- [ ] Todo dominio de contenido bajo `.invalid`.
- [ ] Esquema completo campo a campo e invariantes §2.2 cumplidos.
- [ ] `senal_clave`/`senal_secundaria` ∈ vocabulario §7; `es_phishing=false` ⇒ `sin_senales`.
- [ ] Marcas solo ficticias: Nexodata, Banco Aurora, TiendaNova.
- [ ] Feedback educativo en español, sin PII y dentro del límite de caracteres.
