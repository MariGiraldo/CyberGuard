---
name: godot-ui-scaler
description: >-
  Pautas de UI en Godot 4.6 a resolución pixel art 320x180 para CyberGuard:
  reglas de anclaje (Anchors Preset), límites de fuentes (font_size 6-10 px),
  autowrap para textos largos y aplicación del tema tema_ciberseguridad.tres.
  Usar siempre que se cree o modifique una escena Control/HUD/modal.
---

# Skill: Godot UI Scaler (320×180 pixel art)

> **Fuentes:** `doc/diseno/03-guia-estilo-pixelart.md` §1–§4,
> `doc/arquitectura/01-arquitectura-godot.md` §3 · **Godot 4.6** ·
> **Consumidor:** `constructor` (escenas `scenes/ui/`, `scenes/modales/`, `scenes/main/`).

---

## 1. Lienzo base (precondiciones del proyecto)

| Ajuste | Valor |
|---|---|
| Viewport | **320×180** (`display/window/size/viewport_width/height`) |
| Stretch mode | `canvas_items` · aspecto `keep` |
| Texture filter | **Nearest** (`default_texture_filter = 0`) |
| Snap 2D | `snap_2d_transforms_to_pixel = true`, `snap_2d_vertexes_to_pixel = true` |
| Tema global | `theme/custom = res://resources/temas/tema_ciberseguridad.tres` |

**Regla de oro:** toda la UI se diseña **dentro de 320×180 px lógicos**. Nada se
pre-escala fuera de múltiplos enteros; el escalado lo hace el motor.

## 2. Reglas de anclaje (Anchors Preset)

Los `Control` **nunca** se posicionan con `position` fraccionaria fija: se anclan.
Presets permitidos y su uso obligatorio:

| Preset | Código | Uso |
|---|---|---|
| Full Rect | `Control.PRESET_FULL_RECT` | Fondos, capas modales, paneles que cubren todo (oscurecedor, `margen`) |
| Center | `Control.PRESET_CENTER` | Modales (`carta_email`, `panel_servidor`, `medidor_password`, popup feedback) |
| Top Left | `Control.PRESET_TOP_LEFT` | Marcador/HUD de datos, avisos de red |
| Top Right | `Control.PRESET_TOP_RIGHT` | Temporizador, botón de cierre |
| Center Bottom | `Control.PRESET_CENTER_BOTTOM` | Prompt/eyebrow inferior, avisos inferiores |
| Top Wide | `Control.PRESET_CENTER_TOP` / bandas | Cabeceras de terminal |

```gdscript
# Ejemplo: panel modal centrado (scena ui/…)
var panel := PanelContainer.new()
panel.set_anchors_preset(Control.PRESET_CENTER)

var fondo := ColorRect.new()
fondo.set_anchors_preset(Control.PRESET_FULL_RECT)   # cubre 320×180

_etiqueta_tiempo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
_etiqueta_tiempo.offset_left = -80.0                # márgenes en píxeles enteros
_etiqueta_tiempo.offset_top = 4.0
```

**Reglas derivadas:**
- Anclar **primero**, ajustar `offset_*` después (los offsets son en px lógicos enteros).
- Tras `set_anchors_preset(...)`, si el nodo debe crecer con su contenido usar
  `grow_horizontal`/`grow_vertical` o `PRESET_CENTER` + `size` contenido.
- Rectángulos de panel: múltiplos de 8 (dentro de múltiplos de 16); bordes de 1 px.
- Prohibido `scale` fraccionario en `Control`; si hace falta más tamaño, se cambia el
  `offset_*`, no el `scale`.

## 3. Límites de fuentes (`override font_size`)

- Tamaño por defecto del tema: `default_font_size = 6` (definido en
  `tema_ciberseguridad.tres`).
- **Todo `font_size` por nodo debe estar entre 6 y 10 px** (inclusive). Fuera de ese
  rango → revisión obligatoria (rompe la legibilidad a 320×180).
- Fuentes pixel: **nunca < 8 px de alto de línea** para texto que se lee en pantalla
  (guía de estilo §2); el rango 6–10 es para `override`, no para bajar de la fuente base.

| Uso | `font_size` | Ejemplo real |
|---|---|---|
| Texto corrido, botones, campos, HUD | **6** | botones, `_campo_cuerpo`, marcador |
| Títulos de panel/terminal | **7–8** | `titulo` del terminal (7), título de menú (8) |
| Título máximo / cifras destacadas | **9–10** | solo score grande; nunca más de 1 por pantalla |

```gdscript
boton.add_theme_font_size_override("font_size", 6)
titulo.add_theme_font_size_override("font_size", 8)   # máx permitido: 10
```

## 4. Autowrap para textos largos

Cualquier `Label` con texto que pueda superar su ancho **debe** llevar autowrap:

```gdscript
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # corta en palabras respetando signos
label.add_theme_font_size_override("font_size", 6)
```

**Reglas:**
- `TextServer.AUTOWRAP_WORD_SMART` es el único modo admitido (no `ARBITRARY` ni `CHAR`).
- Obligatorio en: cuerpo de correos, feedback educativo, avisos de red, descripciones
  de vulnerabilidad, mensajes de popup y cualquier texto traducible.
- Textos fijos cortos (botones "PHISHING", "LEGITIMO", marcador numérico, temporizador)
  **no** necesitan autowrap; sí necesitan que su panel contenedor tenga ancho suficiente.
- Tras activar autowrap, verificar que el texto **cabe verticalmente** en el panel:
  en 180 px de alto un párrafo de ~4–6 líneas a 6 px es el máximo viable.
- Preferir `fit_content = true` en `Label` dentro de contenedores modales.

## 5. Aplicación del tema `tema_ciberseguridad.tres`

El tema está declarado **a nivel de proyecto** en `project.godot`:

```
[gui]
theme/custom="res://resources/temas/tema_ciberseguridad.tres"
```

Por eso **no hace falta** reasignar `theme` en cada escena raíz; sí se usa el recurso
para overrides puntuales y en nodos creados por código:

```gdscript
const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")

# Nodo creado por código: hereda tema de proyecto, pero se puede forzar:
var panel := PanelContainer.new()
panel.theme = TEMA_CIBER

# Overrides puntuales (siempre dentro del rango 6–10):
_etiqueta_marcador.add_theme_font_size_override("font_size", 6)

# Estados visuales según la guía de estilo §4:
# hover #4F81C7, pressed con offset 1 px, disabled #8B949E, foco contorno 1 px azul claro.
```

**Reglas del tema:**
- Colores **solo** los del tema/paleta (`doc/diseno/03-guia-estilo-pixelart.md` §3);
  prohibidos degradados, blur y anti-aliasing en bordes.
- Los estados (error/acierto) nunca se comunican **solo** con color: icono o texto junto.
- Máximo 2 acentos de estado compitiendo por pantalla (rojo `#D73A49`, verde `#2EA043`,
  amarillo `#D4A72C`).

## 6. Checklist de una escena UI

- [ ] Resolución lógica 320×180; sin `scale` fraccionario ni posiciones fraccionarias.
- [ ] Todo `Control` con `Anchors Preset` de la tabla §2 (nada posicionado "a ojo").
- [ ] Todo `font_size` entre **6 y 10**; texto principal en 6, títulos en 7–8.
- [ ] Textos largos con `AUTOWRAP_WORD_SMART` y caben verticalmente en su panel.
- [ ] Tema global heredado; overrides puntuales con `preload` de `tema_ciberseguridad.tres`.
- [ ] Legible a 1× sin zoom; estados con icono+color, no solo color.

## 7. Comandos de verificación

```bash
# 1. Resolución y tema del proyecto
grep -n "viewport_width\|viewport_height\|stretch_mode\|theme/custom" codigo/game/project.godot

# 2. Ningún font_size fuera del rango 6–10
grep -rn "font_size_override" codigo/game --include=*.gd \
  | grep -oE '"font_size", [0-9]+' | sort -u

# 3. Textos largos con autowrap
grep -rn "AUTOWRAP_WORD_SMART" codigo/game --include=*.gd | wc -l

# 4. Presets de anclaje usados
grep -rn "set_anchors_preset" codigo/game --include=*.gd

# 5. Sin escalado fraccionario de Control
grep -rnE "\.scale = Vector2\(0\.[0-9]" codigo/game --include=*.gd && echo REVISAR || echo OK
```

## 8. Criterios de aceptación

- [ ] Sin posiciones/scales fraccionarias; todos los `Control` anclados con preset.
- [ ] `font_size` estrictamente en rango 6–10 en todo `codigo/game/`.
- [ ] Todo texto dinámico con `AUTOWRAP_WORD_SMART` y contenido dentro del panel.
- [ ] `tema_ciberseguridad.tres` activo como tema global y como fuente de overrides.
- [ ] UI legible a resolución 1× (320×180) sin zoom.
