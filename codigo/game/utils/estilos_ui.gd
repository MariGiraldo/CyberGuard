class_name EstilosUI
extends RefCounted
## Estilos visuales compartidos basados en los assets multimedia de `assets/ui/`.
## Centraliza las texturas y la construcción de StyleBoxTexture para botones,
## de modo que toda la UI use la botonera `botones.png` y los cuadros de fondo
## `cuadro_fondo_tareas.jpg` de forma consistente (resolución 320×180, filtro Nearest).

const TEXTURA_BOTONES := preload("res://assets/ui/botones.png")
const TEXTURA_CUADRO := preload("res://assets/ui/cuadro_fondo_tareas.jpg")
const TEXTURA_FONDO_INICIO := preload("res://assets/ui/fondo_inicio.jpg")
const TEXTURA_FONDO_MAPA := preload("res://assets/ui/fondo_mapa.jpg")
const ICONO_WARNING := preload("res://assets/ui/warning.png")
const ICONO_WELCOME := preload("res://assets/ui/welcome.png")


## StyleBoxTexture que estira `botones.png` al rectángulo del botón,
## con content margins para que el texto quede centrado y legible.
## `margen_vertical` permite compactar botones secundarios (p. ej. la lista de
## la bandeja) reduciendo la altura total sin perder la botonera.
static func estilo_boton(margen_vertical: float = 2.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEXTURA_BOTONES
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# Márgenes de textura: dejan el borde pintado de la imagen fuera del contenido.
	sb.texture_margin_left = 10.0
	sb.texture_margin_right = 10.0
	sb.texture_margin_top = 6.0
	sb.texture_margin_bottom = 6.0
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = margen_vertical
	sb.content_margin_bottom = margen_vertical
	return sb


## Aplica la botonera a un Button con sus estados (normal, hover, pressed,
## disabled y focus) derivados de la misma textura.
static func aplicar_boton(boton: Button, margen_vertical: float = 2.0) -> void:
	boton.add_theme_stylebox_override("normal", estilo_boton(margen_vertical))
	var hover := estilo_boton(margen_vertical)
	hover.modulate_color = Color(1.1, 1.15, 1.25)  # realce sutil al pasar el ratón
	boton.add_theme_stylebox_override("hover", hover)
	var pulsado := estilo_boton(margen_vertical)
	pulsado.modulate_color = Color(0.8, 0.82, 0.9)  # se oscurece 1px de efecto
	boton.add_theme_stylebox_override("pressed", pulsado)
	boton.add_theme_stylebox_override("focus", estilo_boton(margen_vertical))
	var deshabilitado := estilo_boton(margen_vertical)
	deshabilitado.modulate_color = Color(0.55, 0.58, 0.62)  # gris tema #8B949E
	boton.add_theme_stylebox_override("disabled", deshabilitado)


## TextureRect a pantalla completa con la textura escalada (fondos de escena).
static func textura_a_pantalla(textura: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = textura
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Cuadro de fondo de tarjetas/tareas escalado al tamaño del contenedor.
## `velo` (0–1) añade un velo oscuro encima para asegurar contraste del texto.
static func cuadro_fondo(ancho: float, alto: float, velo: float = 0.35) -> Control:
	var contenedor := Control.new()
	contenedor.custom_minimum_size = Vector2(ancho, alto)
	var fondo := textura_a_pantalla(TEXTURA_CUADRO)
	contenedor.add_child(fondo)
	if velo > 0.0:
		var oscurecedor := ColorRect.new()
		oscurecedor.color = Color(0, 0, 0, velo)
		oscurecedor.set_anchors_preset(Control.PRESET_FULL_RECT)
		oscurecedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_child(oscurecedor)
	return contenedor


## Icono/imagen decorativo escalado manteniendo el aspecto (para warning/welcome).
static func icono(textura: Texture2D, tamano: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = textura
	rect.custom_minimum_size = tamano
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
