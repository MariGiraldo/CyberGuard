# Guía de Estilo Pixel Art — CyberGuard: Misión Ciberseguridad

> **Tarea:** T04 (`diseñador`) — entregable 2 de 2.
> **Fecha:** 2026-10-16 · **Estado:** Propuesto (pendiente Gate C2 del Guardián, con foco en licencias).
> **Fuentes:** `doc/plan/00-plan-maestro.md` §1 y §8, `agentes/guardian.md` §3.1/§3.6, `agentes/razonamiento/diseñador.md` §3.1/§3.5.
> **Consumidores:** `constructor` (T21–T26: configuración de proyecto y assets), `liberador` (T43: exports), `guardian` (auditoría de licencias).

Esta guía es **obligatoria** para todo asset y ajuste visual del proyecto. Cualquier nuevo asset debe respetarla y estar registrado (§8).

---

## 1. Resolución base y configuración del proyecto

| Parámetro | Valor | Dónde se configura (T21) |
|---|---|---|
| Resolución base | **320×180** px | `display/window/size/viewport_width` = `320`, `viewport_height` = `180` |
| Escalado | `canvas_items`, aspecto `keep` | `display/window/stretch/mode` y `stretch/aspect` |
| Filtro de texturas | **Nearest** (sin suavizado) | `rendering/textures/canvas_textures/default_texture_filter` = `0` |
| Snap 2D a píxel | **On** ("Snap 2D Transforms to Pixel") | `rendering/2d/snap/snap_2d_transforms_to_pixel` = `true` y `snap_2d_vertexes_to_pixel` = `true` |

Reglas derivadas:
- Ningún sprite, textura o fuente debe escalarse con filtrado suave (rompe la estética y lo prohíbe el Contrato CyberGuard §3.1).
- Escalar la ventana es responsabilidad del motor (`canvas_items`); los assets **nunca** se pre-escalan fuera de múltiplos enteros.
- Evitar `position`/`scale` fraccionarios en nodos 2D: el Snap 2D corrige, pero redondear a mano evita "temblor" de bordes.

---

## 2. Retícula y tamaños de assets

| Elemento | Tamaño | Regla |
|---|---|---|
| Tiles del mapa (suelo, muros) | **16×16** | Múltiplo de 16; TileSet con `texture_region_size = 16×16` |
| Sprite del jugador | **16×16** (o 32×32 si se necesita legibilidad) | Múltiplo de 16 |
| Terminales y mobs de oficina | 16×16 | Múltiplo de 16 |
| Iconos (señales, estados, HUD) | **16×16** con 1 px de aire transparente | Múltiplo de 16; la silueta legible vive en el centro 14×14 |
| Paneles/modal (carta_email, panel_servidor) | Múltiplos de 8 dentro de múltiplos de 16 | Bordes de 1 px; proporción cercana a 16:9 para caber en 320×180 |
| Spritesheets | Frames de **tamaño fijo** | Especificar nº de frames y FPS (§6) |

- **Legibilidad a 320×180:** toda silueta debe reconocerse sin zoom. Probar siempre a resolución 1× y a la ventana completa.
- **Fuentes pixel (bitmap):** tamaños **≥ 8 px** de alto de línea (prohibido < 8 px, `diseñador.md` §3.1). Usar fuentes de licencia libre verificada (candidatas: familias tipo "Silkscreen"/"Press Start"-like) — **verificar licencia real y registrar en `doc/assets-licencias.md` antes de usarlas** (§8).

---

## 3. Paleta recomendada

Paleta inicial acotada (tonos **corporativos azul/gris** con **acentos rojo/verde** para estados, más un amarillo de advertencia). Es un punto de partida obligatorio mientras no exista paleta expandida; cualquier nuevo color debe derivarse de ella y documentarse.

### 3.1 Base corporativa (azules y grises)

| Nombre | Hex | Uso |
|---|---|---|
| Azul noche | `#1B2A4A` | Fondo de oficina, fondo de modales, barras |
| Azul corporativo | `#2E5AAC` | Botones, cabeceras de terminal, acentos principales |
| Azul claro | `#4F81C7` | Hover, subrayados, enlaces simulados |
| Gris acero | `#3A4149` | Contornos, bordes oscuros, sombras planas |
| Gris medio | `#8B949E` | Texto secundario, iconos inactivos |
| Gris claro | `#C9D1D9` | Superficies de panel, papel del correo |
| Blanco hueso | `#F5F7FA` | Texto principal, fondos de carta_email |
| Negro tinta | `#0D1117` | Contornos duros, texto sobre claro |

### 3.2 Acentos de estado

| Nombre | Hex | Uso semántico |
|---|---|---|
| Rojo alerta | `#D73A49` | Phishing detectado, error del jugador, servidores críticos, temporizador < 20 % |
| Verde seguro | `#2EA043` | Legítimo confirmado, acierto, servidor sano/reparado, fortaleza fuerte |
| Amarillo aviso | `#D4A72C` | Advertencia media: servidor infectado (no crítico), fortaleza media, tiempo < 40 % |

- Los estados **nunca** se comunican solo con color: siempre acompañados de icono y/o texto (accesibilidad; los iconos de §5 existen para esto).
- Regla de uso: en pantalla nunca > 2 acentos de estado compitiendo; el color dominante es la base azul/gris.

### 3.3 Sombras y profundidad

- Sombras planas (sin degradados): desplazamiento de 1 px en `#1B2A4A` al 100 % o `#0D1117` semitransparente solo en UI.
- Prohibidos: degradados, blur, brillos suavizados y anti-aliasing en bordes de formas.

---

## 4. Estados visuales de UI

| Estado | Transición | Uso |
|---|---|---|
| Normal | — | Base (§3.1) |
| Hover | +1 tono claro (p. ej. `#2E5AAC` → `#4F81C7`) | Cursor sobre botón/terminal (`Point & Click`) |
| Pressed | −1 tono oscuro + offset 1 px hacia abajo/derecha | Clic aplicado |
| Disabled | Gris medio `#8B949E`, sin hover | Opción deshabilitada (p. ej. "investigar enlace" ya usado) |
| Foco teclado | Contorno de 1 px en azul claro | Navegación por teclado (WASD/flechas) |

Botones de decisión del módulo phishing: **"PHISHING"** con acento rojo al hover; **"LEGITIMO"** con acento verde al hover. La decisión correcta/incorrecta se confirma con el popup de feedback (`popup_feedback.tscn`) usando los mismos acentos (§1.4 de `01-misiones.md`).

---

## 5. Iconografía de terminales y señales

### 5.1 Terminales de la oficina (16×16)

| Icono | Motivo | Acento de estado |
|---|---|---|
| `terminal_correos` | Sobre + monitor de escritorio | Azul base; parpadeo verde cuando hay correos nuevos |
| `terminal_cifrado` | Monitor con candado cerrado | Azul base; amarillo cuando hay mensaje pendiente |
| `terminal_servidores` | Rack de servidores (2 U con luces) | Luz por estado: 🟢 sano, 🟡 infectado, 🔴 crítico (§3.2) |

- Cada terminal necesita estado **inactiva / hover / activa** (3 frames o 3 variantes).
- Las luces del rack son píxeles sueltos de acento; usar el parpadeo (2 frames) para "infectado".

### 5.2 Iconos de señales de phishing (para feedback y modo guiado, 16×16)

| Señal (vocabulario T02 §7) | Icono sugerido |
|---|---|
| `dominio_sospechoso` | Globo terráqueo con "¿?" |
| `urgencia` | Reloj de arena |
| `error_url` | Eslabón de cadena roto |
| `adjunto_inesperado` | Clip de papel con exclamación |
| `suplantacion_marca` | Escudo con cara imitadora / máscara |
| `saludo_generico` | Silueta de persona genérica |
| `sin_senales` | Estuche/hucha verde (seguro) |

### 5.3 Iconos de estados de datos

| Estado | Icono | Color |
|---|---|---|
| Acierto | Palomita | Verde seguro (§3.2) |
| Error | Cruz | Rojo alerta |
| Advertencia | Triángulo | Amarillo aviso |
| Fortaleza (medidor) | Barra de 5 segmentos | Rojo → amarillo → verde según escala 0–4 del modelo T02 §6 |

---

## 6. Animaciones (spritesheets)

| Animación | Frames | FPS | Notas |
|---|---|---|---|
| Jugador idle | 2 | 2 | Micro-movimiento; 16×16 (o 32×32) |
| Jugador caminar | 4 | 8 | 2 pasos por lado |
| Terminal hover | 2 | 4 | Brillo sutil de acento |
| Luces servidor infectado | 2 | 2 | Parpadeo rojo/ámbar |
| Popup feedback acierto | 3 | 8 | Escala 1→1.1→1 (por steps, sin tween suave) |
| Popup feedback error | 3 | 8 | Temblor horizontal de 1 px |

- Frames de tamaño fijo; documentar nº de frames y FPS en `doc/assets-licencias.md` o en la hoja del pack de origen.
- Prohibido animar con interpolaciones no enteras (rompe el snap a píxel).

---

## 7. Assets de placeholder (walking skeleton)

- Durante el alcance de 3 días (decisión 7a) **se permiten placeholders**: rectángulos/siluetas con la paleta de §3 y los tamaños de §2. Esto no exime de registrarlos (§8).
- Los placeholders deben respetar ya la retícula 16×16 y los acentos de estado para que la sustitución posterior por arte final no cambie la UX.

---

## 8. Licencias y registro de assets (obligatorio — Contrato CyberGuard §3.6)

### 8.1 Licencias admitidas

| Licencia | Uso | Obligación |
|---|---|---|
| **CC0** (dominio público) | Cualquier asset | Registrar fuente y autor (cortesía) |
| **CC-BY** | Cualquier asset | **Atribución obligatoria** en créditos del juego y en el registro |
| **Propio** (creado por el equipo) | Cualquier asset | Registrar como "propio" |
| Cualquier otra (GPL, CC-BY-NC, "free for personal use" sin redistribución, etc.) | **Prohibida** | Bloqueo ALTA del Guardián |

### 8.2 Registro obligatorio en `doc/assets-licencias.md`

Todo asset — incluidos placeholders, fuentes tipográficas y sonidos — se registra **antes** de usarlo, con este formato mínimo (una fila por asset):

| Asset | Ruta en `codigo/game/` | Fuente (URL) | Autor | Licencia | Fecha de alta | Notas |
|---|---|---|---|---|---|---|
| Ej.: tiles_oficina.png | `res://assets/tiles/…` | `https://opengameart.org/…` | "autorX" | CC0 | 2026-10-16 | Placeholder retocado |

### 8.3 Reglas de verificación (Guardián, Gate C2 y C4)

1. `doc/assets-licencias.md` debe existir y contener una fila por archivo de asset del proyecto.
2. Verificación automatizable: `grep -ciE "licencia" doc/assets-licencias.md` > 0 y cruce de rutas reales del proyecto contra el registro.
3. **No redibujar marcas comerciales registradas** (`diseñador.md` §3.5): en el contenido de phishing solo existen marcas ficticias (Banco Aurora, TiendaNova — ver `01-misiones.md` §3.1).
4. Las fuentes de texto pixel se auditan igual que los sprites: fuente, autor y licencia documentados.

---

## 9. Checklist de conformidad para nuevos assets

- [ ] Tamaño en múltiplos de 16×16 (§2); frames de tamaño fijo si es spritesheet.
- [ ] Paleta derivada de §3 (o nueva color documentado y aprobado).
- [ ] `Texture Filter = Nearest` y Snap 2D a píxel activos en el nodo/proyecto (§1).
- [ ] Legible a 320×180 sin zoom; estados comunicados con icono+color, no solo color (§3.2, §4).
- [ ] Animaciones con FPS y nº de frames documentados (§6).
- [ ] Fila añadida en `doc/assets-licencias.md` con fuente, autor y licencia CC0/CC-BY/propio (§8).
- [ ] Sin marcas comerciales reales dibujadas (§8.3).

---

## 10. Criterios de aceptación (T04 — este documento)

- [x] Resolución base 320×180, Nearest y Snap 2D a píxel especificados con sus claves de `project.godot` (§1).
- [x] Assets en múltiplos de 16×16 con retícula y reglas de legibilidad (§2).
- [x] Paleta recomendada azul/gris corporativa + acentos rojo/verde (y amarillo de advertencia) con usos semánticos (§3).
- [x] Iconografía de terminales y señales definida (§5), alineada con los vocabularios del modelo T02 §7.
- [x] Registro y licencias (CC0/CC-BY/propios) con registro obligatorio en `doc/assets-licencias.md` (§8).
