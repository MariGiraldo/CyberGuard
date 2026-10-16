# Diseño de Misiones — CyberGuard: Misión Ciberseguridad

> **Tarea:** T04 (`diseñador`) — entregable 1 de 2.
> **Fecha:** 2026-10-16 · **Estado:** Propuesto (pendiente Gate C2 del Guardián; revisar seguridad del contenido).
> **Fuentes:** `doc/plan/00-plan-maestro.md` §3.1–§3.4 (base textual), decisiones §8, `doc/dominio/01-modelo-dominio.md` (T02 — vocabularios y payloads).
> **Consumidores:** `constructor` (T22–T26, T32) — este documento es la **fuente única** de `codigo/game/data/correos_nivel1.json` y `data/niveles.json`; `probador` (T33 — casos de prueba).

> ⚠️ **Regla de contenido (Gate C2):** todo el contenido de correos, marcas, dominios y URLs es **100% ficticio**. Se usa exclusivamente el TLD reservado `.invalid` (RFC 2606, nunca resuelve en DNS) y marcas inventadas. Ningún enlace apunta a sitios reales. Tono didáctico, sin contenidos que asusten a menores.

---

## 1. Marco común de las misiones

### 1.1 Bucle de partida (plan §3.1)

```
Menú → briefing del nivel → mapa oficina (top-down) → terminal (clic/WASD)
   ├─ Terminal CORREOS   → analizar bandeja → PHISHING / LEGITIMO (+ "investigar enlace")
   ├─ Terminal CIFRADO   → descifrar mensaje (César) → evaluar fortaleza de contraseña
   └─ Terminal SERVIDORES → identificar vulnerabilidad → parchear
→ Temporizador global en paralelo → al expirar o completar: resumen + feedback educativo
→ Eventos a Supabase (1 evento = 1 decisión) → dashboard Looker
```

### 1.2 Puntuación (plan §3.4, decisión cerrada)

| Concepto | Valor | Notas |
|---|---|---|
| Acierto | **+100** | Por cada evento con `es_correcto = true` |
| Error | **−50** | Por cada evento con `es_correcto = false` |
| Tiempo restante | **+10 por segundo** restante al finalizar | Se aplica una sola vez al cerrar la partida |
| Bonus sin pistas | **+25** por correo clasificado sin usar "investigar enlace" | Detalle en §4 |
| Fuente de verdad | Servidor (RPC `calcular_puntaje`, T12) | El cliente solo muestra `puntaje_provisional` |
| Ranking | **No existe** (decisión 3a) | Solo métricas agregadas en Looker |

### 1.3 Temporizador

- Duración por nivel dentro del rango **5–8 min** (decisión §8), decreciente según dificultad.
- El temporizador se **pausa** mientras un modal está abierto solo en el Nivel 1 (modo tutorial "sin presión"); en Niveles 2–4 corre siempre (presión auténtica).
- Al expirar: la partida finaliza igualmente con el progreso hecho (no hay "game over"; hay **resumen** con feedback, plan §3.2).

### 1.4 Feedback educativo (transversal)

| Momento | Qué se muestra |
|---|---|
| Acierto | ✅ Popup breve confirma la decisión + **una frase** con la regla aprendida (p. ej. "El dominio del remitente no coincide con el oficial: pinta bien la dirección antes de confiar"). |
| Error | ❌ Popup con la respuesta correcta + **explicación de la señal clave** del correo + pista práctica aplicable a la vida real. Nunca solo "fallaste". |
| Fin de nivel | Pantalla `resumen_nivel.tscn`: puntuación, aciertos/errores **por tipo de amenaza**, tiempo medio de decisión y una "lección del nivel" que consolida el objetivo pedagógico. Los datos mostrados derivan de las mismas columnas que alimentan Looker (modelo T02 §9). |

---

## 2. Tabla resumen de los 4 niveles

| Nivel | Nombre | Enfoque (plan §3.3) | Duración | Composición | Dificultad |
|---|---|---|---|---|---|
| 1 | Onboarding | Tutorial de phishing guiado | **8 min** (generoso; sin pausa de temporizador en tutoriales) | 6 correos (3 phishing / 3 legítimos) · 0 contraseñas · 0 servidores | Baja |
| 2 | Bandeja peligrosa | Phishing con señales encubiertas + primera contraseña | **7 min** | 6 correos (4 phishing / 2 legítimos, con 1 "trampa" legítimo) · 1 contraseña (descifrado César → fortaleza) · 0 servidores | Media |
| 3 | Servidor comprometido | Reparación + phishing mixto | **6 min** | 4 correos (2 phishing / 2 legítimos) · 1 contraseña (fortaleza) · 2 servidores infectados | Media-Alta |
| 4 | Tormenta de amenazas | Todos los módulos + propagación activa | **6 min** | 8 correos (5 phishing / 3 legítimos) · 2 contraseñas (1 descifrado + 1 fortaleza) · 3 servidores con propagación | Alta |

> **Reconciliación con el plan (detectada y resuelta):** el §3.3 del plan describe el Nivel 1 como "3 correos, sin presión", mientras que el criterio de aceptación de **T24** exige la terminal con **6 correos clasificables** y el walking skeleton incluye T24 dentro del Nivel 1 (T32). Se resuelve diseñando el Nivel 1 con **6 correos**, de los cuales **los 2 primeros son guiados paso a paso** (tutorial sin presión: temporizador pausado y resaltado de la señal) y los 4 restantes se juegan libremente. Esto satisface a la vez §3.3 y T24. *(Discordancia reportada al planificador para posible aclaración en el §3.3.)*

---

## 3. Detalle por nivel

### 3.1 Nivel 1 — Onboarding (tutorial de phishing)

| Atributo | Valor |
|---|---|
| **Objetivo** | Aprender a analizar un correo: leer remitente, asunto, enlaces y adjuntos antes de actuar. |
| **Duración** | 8 min. El temporizador se pausa durante los correos guiados (1 y 2). |
| **Composición** | 6 correos (3 phishing · 3 legítimos) — detalle completo en §4. Sin contraseñas ni servidores. |
| **Progresión interna** | Correos 1–2 guiados (tutorial con resaltado de la señal y verificación paso a paso) → correos 3–6 sin guía. |
| **Modo pista** | Botón "investigar enlace" expande la URL real. Su uso anula el `bonus_sin_pistas` (+25/correo) de ese correo. |
| **Feedback** | Acierto: regla en una frase. Error: señal explicada con resaltado sobre el propio correo. |
| **Mapeo de eventos** | 1 × `eventos_phishing` por correo → `correo_id` = `n1_c01`…`n1_c06`, `senal_clave` según §4, `decision` ∈ {`PHISHING`,`LEGITIMO`}. |
| **Lección del nivel** | "Antes de hacer clic: mira quién te escribe, a dónde te lleva el enlace y si esperabas ese adjunto." |

**Empresas y marcas ficticias usadas en el Nivel 1:**
- **NexoData** — la empresa donde trabaja el jugador. Dominio oficial: `@nexodata.invalid`. Intranet: `https://intranet.nexodata.invalid`.
- **Banco Aurora** — entidad financiera ficticia (suplantada por un phishing).
- **TiendaNova** — minorista ficticio (aparece en un correo legítimo interno).

### 3.2 Nivel 2 — Bandeja peligrosa

| Atributo | Valor |
|---|---|
| **Objetivo** | Detectar phishing con señales **encubiertas** y pasar de la clasificación a la **verificación** (URL expandida); primer contacto con contraseñas débiles. |
| **Duración** | 7 min (sin pausa). |
| **Composición** | 6 correos: `n2_c01`–`n2_c06` (4 phishing · 2 legítimos). 1 tarea de contraseñas: fase `descifrado` (César) + fase `fortaleza` (evaluar contraseña de una cuenta ficticia de NexoData). |
| **Progresión** | Señales secundarias (2 señales por correo, una prima y otra de apoyo), **1 correo legítimo con apariencia sospechosa** ("trampa" legítimo: asunto con mayúsculas y remitente largo pero legítimo) para enseñar a no acusar sin verificar. La contraseña del ejercicio es deliberadamente débil (`fortaleza` esperada 1). |
| **Feedback** | A error de clasificar el "trampa" legítimo: "La urgencia en el asunto no basta; el dominio es el oficial y el destinatario es personal. Verifica antes de reportar." En fortaleza: el medidor muestra los 5 criterios en vivo (§3.5 del plan). |
| **Mapeo de eventos** | 6 × `eventos_phishing` (`correo_id` = `n2_c0*`); 1 × `eventos_password` (`fase='descifrado'`, `fortaleza=null`); 1 × `eventos_password` (`fase='fortaleza'`, `fortaleza` 0–4). |
| **Lección del nivel** | "Investigar el enlace antes de decidir evita tanto los falsos positivos como los aciertos por casualidad." |

### 3.3 Nivel 3 — Servidor comprometido

| Atributo | Valor |
|---|---|
| **Objetivo** | Localizar y reparar vulnerabilidades de servidores manteniendo la bandeja bajo control. |
| **Duración** | 6 min (sin pausa). |
| **Composición** | 4 correos: `n3_c01`–`n3_c04` (2 phishing · 2 legítimos). 1 tarea de fortaleza (contraseña reutilizada de un empleado ficticio → introducir el concepto de reutilización y 2FA). 2 servidores: `srv_01` (`paquete_desactualizado`), `srv_02` (`puerto_abierto`). |
| **Progresión** | Correos con señales más sutiles (2 señales encubiertas cada uno); servidores con **3 opciones de parche**, una correcta y dos plausibles; el servidor no reparado genera una **penalización de −30 s** al temporizador cuando expira su "ventana" (plan §3.2 Módulo C, sin propagación activa aún). |
| **Feedback** | Al reparar: ficha breve de la vulnerabilidad (qué es, por qué es peligrosa, cómo se previene). Al no reparar a tiempo: explicación de la penalización y del daño real que simula. |
| **Mapeo de eventos** | 4 × `eventos_phishing`; 1 × `eventos_password` (`fase='fortaleza'`, con aviso de reutilización); 2 × `eventos_servidor` (`servidor_id`, `vulnerabilidad`, `reparado`, `tiempo_respuesta_ms`). |
| **Lección del nivel** | "Un puerto abierto sin necesidad y un paquete sin actualizar son puertas abiertas: parchea pronto y cierra lo que no usas." |

### 3.4 Nivel 4 — Tormenta de amenazas

| Atributo | Valor |
|---|---|
| **Objetivo** | Priorizar bajo presión: gestionar los 3 módulos simultáneamente con propagación activa de infección. |
| **Duración** | 6 min (sin pausa). |
| **Composición** | 8 correos: `n4_c01`–`n4_c08` (5 phishing · 3 legítimos, con 2 trampas legítimas). 2 tareas de contraseñas: 1 `descifrado` (César con desplazamiento mayor) + 1 `fortaleza` (contraseña a mejorar). 3 servidores: `srv_01` (`paquete_desactualizado`), `srv_02` (`puerto_abierto`), `srv_03` (`permisos_excesivos`). |
| **Progresión** | **Propagación activa:** cada servidor no reparado infecta a otro servidor cada 60 s (solo si quedan servidores sanos), con penalización de −30 s por propagación y aviso visual en el HUD. Correos con señales encubiertas y al menos 1 correo phishing con **2 señales fuertes combinadas**. La ventana de decisión más corta de todos los niveles. |
| **Feedback** | Igual que Nivel 3 + tarjeta final "tormenta": resumen de cómo se propagó la infección y qué decisión habría cortado la cadena (refuerzo pedagógico, no reproche). |
| **Mapeo de eventos** | 8 × `eventos_phishing`; 2 × `eventos_password`; 3+ × `eventos_servidor` (cada intento/propagación no reparable genera evento con `reparado=false`). |
| **Lección del nivel** | "En una tormenta de amenazas, el orden importa: repara lo crítico primero y no dejes que lo pequeño se propague." |

---

## 4. Nivel 1 detallado — los 6 correos

> Contenido **ficticio** íntegro. Dominios siempre bajo `.invalid`. El campo `senal_clave` del evento de telemetría usa los literales del vocabulario del modelo (§7 del modelo de dominio).

### Correo `n1_c01` — 🎣 PHISHING · guiado · señal: **dominio sospechoso** (+ saludo genérico de apoyo)

| Campo | Contenido |
|---|---|
| Remitente | `soporte@nexodata-verificacion.invalid` |
| Asunto | `Verificación obligatoria de tu cuenta de correo` |
| Cuerpo (breve) | `Estimado usuario: hemos detectado actividad inusual en tu cuenta. Verifica tu identidad en el siguiente enlace antes de 24 horas o tu acceso será suspendido.` |
| Enlace / adjunto | Enlace con texto `https://nexodata.invalid/verificar` pero URL real (visible al "investigar") `https://nexodata-verificacion.invalid/verificar` |
| Respuesta correcta | `PHISHING` |
| Señal principal | `dominio_sospechoso` — el dominio real es `nexodata-verificacion.invalid`, no el oficial `nexodata.invalid` |
| Señal de apoyo | `saludo_generico` — "Estimado usuario" en vez del nombre real |
| Feedback al acertar | ✅ "¡Correcto! El dominio del enlace no coincide con el de la empresa: `nexodata-verificacion` añade un guion que imita al oficial." |
| Feedback al fallar | ❌ "Era phishing. Mira la URL real detrás del texto del enlace: el dominio oficial es `nexodata.invalid`; este usa `nexodata-verificacion.invalid`. Además te saludan de forma genérica." |

### Correo `n1_c02` — ✅ LEGÍTIMO · guiado · **sin señales** (`sin_senales`)

| Campo | Contenido |
|---|---|
| Remitente | `rrhh@nexodata.invalid` |
| Asunto | `Recordatorio: jornada de formación interna el viernes` |
| Cuerpo (breve) | `Hola Marta: te recordamos que el viernes a las 10:00 tienes la formación de seguridad en la sala 2. No necesitas hacer nada por ahora; la sesión es presencial.` |
| Enlace / adjunto | Sin enlaces ni adjuntos |
| Respuesta correcta | `LEGITIMO` |
| Señal | `sin_senales` — dominio oficial, saludo personalizado, sin urgencia, sin enlaces ni adjuntos, sin petición de datos |
| Feedback al acertar | ✅ "¡Correcto! Correos internos legítimos usan el dominio de la empresa, te nombran y no piden clics urgentes." |
| Feedback al fallar | ❌ "Era legítimo. Señales de confianza: dominio oficial `@nexodata.invalid`, saludo con tu nombre y ninguna petición de acción. Desconfiar de todo también cuesta puntos." |

### Correo `n1_c03` — 🎣 PHISHING · señal: **urgencia** (+ error de URL de apoyo)

| Campo | Contenido |
|---|---|
| Remitente | `seguridad@banco-aurora-clientes.invalid` |
| Asunto | `ACCIÓN REQUERIDA: tu cuenta será bloqueada en 12 horas` |
| Cuerpo (breve) | `Estimado cliente: hemos detectado un acceso no autorizado a tu cuenta del Banco Aurora. Confirma tus datos de inmediato en el portal seguro para evitar el bloqueo permanente.` |
| Enlace / adjunto | Texto `Portal seguro del Banco Aurora` con URL real `https://aurora-clientes.banco-aurora.invalid/login` (el sitio "oficial" ficticio sería `https://bancoaurora.invalid`) |
| Respuesta correcta | `PHISHING` |
| Señal principal | `urgencia` — plazo de 12 horas y amenaza de bloqueo para actuar sin pensar |
| Señal de apoyo | `error_url` — el dominio del enlace imita al banco pero no es el oficial ficticio |
| Feedback al acertar | ✅ "¡Correcto! La urgencia artificial es la técnica nº 1 del phishing: presionan para que no verifiques." |
| Feedback al fallar | ❌ "Era phishing. Nadie legítimo te bloquea la cuenta en horas por email: la urgencia existe para que no compruebes la URL, que además no es la del banco." |

### Correo `n1_c04` — ✅ LEGÍTIMO · **sin señales** (`sin_senales`)

| Campo | Contenido |
|---|---|
| Remitente | `notificaciones@nexodata.invalid` |
| Asunto | `Copia de seguridad completada — informe semanal` |
| Cuerpo (breve) | `Hola de nuevo: la copia de seguridad de tu espacio de trabajo finalizó correctamente el domingo a las 03:00. Archivos respaldados: 1.284. No se requiere ninguna acción.` |
| Enlace / adjunto | Adjunto `informe_backup.txt` (esperable: es un sistema que envía informes semanales habituales) |
| Respuesta correcta | `LEGITIMO` |
| Señal | `sin_senales` — dominio oficial, sin peticiones, adjunto de tipo conocido y esperado |
| Feedback al acertar | ✅ "¡Correcto! Un adjunto puede ser legítimo si lo esperas: aquí es un informe rutinario de un sistema conocido." |
| Feedback al fallar | ❌ "Era legítimo. No todo adjunto es malo: el criterio es si lo esperas y de quién viene. Este informe viene del dominio oficial y no te pide nada." |

### Correo `n1_c05` — 🎣 PHISHING · señal: **adjunto inesperado** (+ suplantación de marca de apoyo)

| Campo | Contenido |
|---|---|
| Remitente | `facturacion@tiendanova-facturas.invalid` |
| Asunto | `Factura pendiente de pago — pedido #NX-2041` |
| Cuerpo (breve) | `Hola: tienes una factura pendiente de 148,90 € del pedido #NX-2041. Revisa el detalle en el archivo adjunto y realiza el pago antes de que genere recargos.` |
| Enlace / adjunto | Adjunto `factura_NX-2041.html` (archivo HTML inesperado que simula una página de pago) |
| Respuesta correcta | `PHISHING` |
| Señal principal | `adjunto_inesperado` — nadie envía facturas HTML sin avisar; los adjuntos HTML suelen imitar formularios de pago |
| Señal de apoyo | `suplantacion_marca` — finge ser TiendaNova pero el dominio `tiendanova-facturas.invalid` no es el oficial |
| Feedback al acertar | ✅ "¡Correcto! Un HTML adjunto que pide pago es de las técnicas más peligrosas: se abre como una web falsa dentro de tu equipo." |
| Feedback al fallar | ❌ "Era phishing. Dos señales: el adjunto HTML inesperado y el dominio que imita a la tienda sin ser el oficial. Las facturas reales no llegan como páginas adjuntas." |

### Correo `n1_c06` — ✅ LEGÍTIMO · **sin señales** (`sin_senales`)

| Campo | Contenido |
|---|---|
| Remitente | `it-helpdesk@nexodata.invalid` |
| Asunto | `Mantenimiento programado del sistema de correo — sábado 02:00–04:00` |
| Cuerpo (breve) | `Hola Marta: el sábado de madrugada aplicaremos una actualización de seguridad al correo. Durante esas horas podrás leer mensajes, pero no enviar. No se te pedirá ninguna contraseña por ningún canal. Dudas en replies a este correo.` |
| Enlace / adjunto | Enlace a la intranet `https://intranet.nexodata.invalid/aviso-mantenimiento` (dominio oficial) |
| Respuesta correcta | `LEGITIMO` |
| Señal | `sin_senales` — dominio oficial, aviso proactivo sin urgencia, explícitamente no pide credenciales |
| Feedback al acertar | ✅ "¡Correcto! El TI real avisa con antelación, usa el dominio interno y nunca pide contraseñas por correo." |
| Feedback al fallar | ❌ "Era legítimo. Fíjate en lo que sí hace: anuncia con tiempo, enlaza a la intranet oficial y recuerda que nunca pedirán claves. Ese es el patrón de un aviso real." |

### 4.1 Resumen del Nivel 1

| `correo_id` | Respuesta | `decision` correcto | `senal_clave` del evento | Guiado |
|---|---|---|---|---|
| `n1_c01` | PHISHING | `PHISHING` | `dominio_sospechoso` | Sí |
| `n1_c02` | LEGITIMO | `LEGITIMO` | `sin_senales` | Sí |
| `n1_c03` | PHISHING | `PHISHING` | `urgencia` | No |
| `n1_c04` | LEGITIMO | `LEGITIMO` | `sin_senales` | No |
| `n1_c05` | PHISHING | `PHISHING` | `adjunto_inesperado` | No |
| `n1_c06` | LEGITIMO | `LEGITIMO` | `sin_senales` | No |

Cobertura de las 6 señales pedagógicas del plan §3.2 en el Nivel 1: `dominio_sospechoso` (c01), `urgencia` (c03), `adjunto_inesperado` (c05), `suplantacion_marca` (c05, apoyo), `error_url` (c03, apoyo), `saludo_generico` (c01, apoyo).

---

## 5. Fuente de datos: `codigo/game/data/correos_nivel1.json`

Este documento es la **fuente canónica**. El `constructor` (T24/T32) genera el JSON respetando este esquema; los nombres de campo `es_phishing`, `senal_clave` y `senal_secundaria` alimentan directamente la evaluación (`systems/logica_phishing.gd`) y el payload de `eventos_phishing` (modelo T02 §4.1).

### 5.1 Esquema del JSON

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | string | `correo_id` estable, viaja en el evento |
| `remitente` | string | Dirección mostrada (ficticia, `.invalid`) |
| `asunto` | string | Asunto |
| `cuerpo` | string | Cuerpo breve |
| `enlace_texto` | string \| null | Texto visible del enlace (null si no hay) |
| `enlace_url` | string \| null | URL real que muestra "investigar enlace" |
| `adjunto` | string \| null | Nombre del adjunto (null si no hay) |
| `es_phishing` | bool | Respuesta esperada |
| `senal_clave` | string | Vocabulario del modelo (§7 del modelo de dominio) |
| `senal_secundaria` | string \| null | Señal de apoyo o null |
| `guiado` | bool | Nivel 1: activa el modo tutorial paso a paso |
| `feedback_acierto` | string | Texto al acertar |
| `feedback_error` | string | Texto al fallar (explicación educativa) |

### 5.2 Contenido completo del Nivel 1

```json
{
  "nivel_id": 1,
  "correos": [
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
      "feedback_error": "Era phishing. Mira la URL real detrás del texto del enlace: el dominio oficial es 'nexodata.invalid'; este usa 'nexodata-verificacion.invalid'. Además te saludan de forma genérica."
    },
    {
      "id": "n1_c02",
      "remitente": "rrhh@nexodata.invalid",
      "asunto": "Recordatorio: jornada de formación interna el viernes",
      "cuerpo": "Hola Marta: te recordamos que el viernes a las 10:00 tienes la formación de seguridad en la sala 2. No necesitas hacer nada por ahora; la sesión es presencial.",
      "enlace_texto": null,
      "enlace_url": null,
      "adjunto": null,
      "es_phishing": false,
      "senal_clave": "sin_senales",
      "senal_secundaria": null,
      "guiado": true,
      "feedback_acierto": "¡Correcto! Correos internos legítimos usan el dominio de la empresa, te nombran y no piden clics urgentes.",
      "feedback_error": "Era legítimo. Señales de confianza: dominio oficial '@nexodata.invalid', saludo con tu nombre y ninguna petición de acción. Desconfiar de todo también cuesta puntos."
    },
    {
      "id": "n1_c03",
      "remitente": "seguridad@banco-aurora-clientes.invalid",
      "asunto": "ACCIÓN REQUERIDA: tu cuenta será bloqueada en 12 horas",
      "cuerpo": "Estimado cliente: hemos detectado un acceso no autorizado a tu cuenta del Banco Aurora. Confirma tus datos de inmediato en el portal seguro para evitar el bloqueo permanente.",
      "enlace_texto": "Portal seguro del Banco Aurora",
      "enlace_url": "https://aurora-clientes.banco-aurora.invalid/login",
      "adjunto": null,
      "es_phishing": true,
      "senal_clave": "urgencia",
      "senal_secundaria": "error_url",
      "guiado": false,
      "feedback_acierto": "¡Correcto! La urgencia artificial es la técnica nº 1 del phishing: presionan para que no verifiques.",
      "feedback_error": "Era phishing. Nadie legítimo te bloquea la cuenta en horas por email: la urgencia existe para que no compruebes la URL, que además no es la del banco."
    },
    {
      "id": "n1_c04",
      "remitente": "notificaciones@nexodata.invalid",
      "asunto": "Copia de seguridad completada — informe semanal",
      "cuerpo": "Hola de nuevo: la copia de seguridad de tu espacio de trabajo finalizó correctamente el domingo a las 03:00. Archivos respaldados: 1.284. No se requiere ninguna acción.",
      "enlace_texto": null,
      "enlace_url": null,
      "adjunto": "informe_backup.txt",
      "es_phishing": false,
      "senal_clave": "sin_senales",
      "senal_secundaria": null,
      "guiado": false,
      "feedback_acierto": "¡Correcto! Un adjunto puede ser legítimo si lo esperas: aquí es un informe rutinario de un sistema conocido.",
      "feedback_error": "Era legítimo. No todo adjunto es malo: el criterio es si lo esperas y de quién viene. Este informe viene del dominio oficial y no te pide nada."
    },
    {
      "id": "n1_c05",
      "remitente": "facturacion@tiendanova-facturas.invalid",
      "asunto": "Factura pendiente de pago — pedido #NX-2041",
      "cuerpo": "Hola: tienes una factura pendiente de 148,90 € del pedido #NX-2041. Revisa el detalle en el archivo adjunto y realiza el pago antes de que genere recargos.",
      "enlace_texto": null,
      "enlace_url": null,
      "adjunto": "factura_NX-2041.html",
      "es_phishing": true,
      "senal_clave": "adjunto_inesperado",
      "senal_secundaria": "suplantacion_marca",
      "guiado": false,
      "feedback_acierto": "¡Correcto! Un HTML adjunto que pide pago es de las técnicas más peligrosas: se abre como una web falsa dentro de tu equipo.",
      "feedback_error": "Era phishing. Dos señales: el adjunto HTML inesperado y el dominio que imita a la tienda sin ser el oficial. Las facturas reales no llegan como páginas adjuntas."
    },
    {
      "id": "n1_c06",
      "remitente": "it-helpdesk@nexodata.invalid",
      "asunto": "Mantenimiento programado del sistema de correo — sábado 02:00–04:00",
      "cuerpo": "Hola Marta: el sábado de madrugada aplicaremos una actualización de seguridad al correo. Durante esas horas podrás leer mensajes, pero no enviar. No se te pedirá ninguna contraseña por ningún canal. Dudas en replies a este correo.",
      "enlace_texto": "Aviso de mantenimiento",
      "enlace_url": "https://intranet.nexodata.invalid/aviso-mantenimiento",
      "adjunto": null,
      "es_phishing": false,
      "senal_clave": "sin_senales",
      "senal_secundaria": null,
      "guiado": false,
      "feedback_acierto": "¡Correcto! El TI real avisa con antelación, usa el dominio interno y nunca pide contraseñas. Ese es el patrón de un aviso real.",
      "feedback_error": "Era legítimo. Fíjate en lo que sí hace: anuncia con tiempo, enlaza a la intranet oficial y recuerda que nunca pedirán claves."
    }
  ]
}
```

### 5.3 `data/niveles.json` (catálogo para el HUD y `partidas.nivel_id`)

```json
{
  "niveles": [
    { "id": 1, "nombre": "Onboarding",             "duracion_seg": 480, "modulos": ["correos"],         "pausa_en_guiado": true  },
    { "id": 2, "nombre": "Bandeja peligrosa",      "duracion_seg": 420, "modulos": ["correos", "contrasenas"], "pausa_en_guiado": false },
    { "id": 3, "nombre": "Servidor comprometido",  "duracion_seg": 360, "modulos": ["correos", "contrasenas", "servidores"], "pausa_en_guiado": false },
    { "id": 4, "nombre": "Tormenta de amenazas",   "duracion_seg": 360, "modulos": ["correos", "contrasenas", "servidores"], "propagacion": true, "pausa_en_guiado": false }
  ]
}
```

---

## 6. Progresión de dificultad (síntesis)

| Eje | N1 | N2 | N3 | N4 |
|---|---|---|---|---|
| Señales por correo phishing | 1 principal + apoyo | 1 encubierta + apoyo | 2 encubiertas | 2 encubiertas + combinadas |
| Trampas legítimas (parecen phishing) | 0 | 1 | 1 | 2 |
| Presión temporal | Tutorial pausado | Sin pausa | Sin pausa + penalización servidor | Propagación activa + −30 s |
| Módulos simultáneos | 1 (correos) | 2 (correos + contraseñas) | 3 | 3 |
| Opciones de parche/servidor | — | — | 3 (1 correcta) | 3 con riesgo de cadena |

---

## 7. Criterios de aceptación (T04 — este documento)

- [x] 4 niveles de 5–8 min con objetivo, composición, puntuación y dificultad (§2, §3).
- [x] Nivel 1 detallado con 6 correos (3 phishing / 3 legítimos) con remitente, asunto, cuerpo, enlace/adjunto y señal (§4).
- [x] Contenido 100% ficticio, dominios `.invalid`, sin marcas reales (revisar en Gate C2).
- [x] JSON fuente para `data/correos_nivel1.json` y `data/niveles.json` (§5) — entrada directa de T24/T32.
- [x] Vocabularios `senal_clave` / `vulnerabilidad` alineados con `doc/dominio/01-modelo-dominio.md` §7.
- [x] Feedback educativo especificado por acierto/error y por nivel (§1.4, §4).
