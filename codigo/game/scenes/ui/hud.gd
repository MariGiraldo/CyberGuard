class_name Hud
extends CanvasLayer
## HUD de la partida: temporizador, marcador, avisos y resumen final.
## Construido por código para mantener los .tscn mínimos y robustos.

signal continuar_pulsado

var _etiqueta_tiempo: Label
var _etiqueta_marcador: Label
var _etiqueta_prompt: Label
var _panel_mensaje: Control
var _etiqueta_mensaje: Label
var _panel_resumen: Control
var _etiquetas_resumen: Dictionary = {}
var _paneles: Array = []  # paneles centrados y su tamaño base ({panel, base})

const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")

## Verde neón: color base de todos los textos del HUD y de los paneles emergentes.
const VERDE_NEON := Color("#00FF66")

func _ready() -> void:
	layer = 10
	_construir()
	get_viewport().size_changed.connect(_ajustar_paneles)


## Actualiza el temporizador (formato mm:ss; rojo con menos de 30 s).
func set_tiempo(restante_seg: int) -> void:
	_etiqueta_tiempo.text = "Tiempo %02d:%02d" % [restante_seg / 60, restante_seg % 60]
	_etiqueta_tiempo.add_theme_color_override(
		"font_color", Color("ff6b6b") if restante_seg <= 30 else VERDE_NEON
	)


## Actualiza marcador (aciertos, errores y puntaje).
func set_marcador(aciertos: int, errores: int, puntaje: int) -> void:
	_etiqueta_marcador.text = "Aciertos: %d  Errores: %d  Puntos: %d" % [aciertos, errores, puntaje]


func mostrar_prompt(texto: String) -> void:
	_etiqueta_prompt.text = texto
	_etiqueta_prompt.visible = true


func ocultar_prompt() -> void:
	_etiqueta_prompt.visible = false


## Aviso breve en el centro de la pantalla (retroalimentación educativa).
func mostrar_mensaje(texto: String, duracion: float = 3.0) -> void:
	_etiqueta_mensaje.text = texto
	_panel_mensaje.visible = true
	var reloj := get_tree().create_timer(duracion)
	reloj.timeout.connect(func() -> void: _panel_mensaje.visible = false)


## Pantalla final: aciertos, errores, puntaje y mensaje educativo.
func mostrar_resumen(puntaje: int, aciertos: int, errores: int, tiempo_agotado: bool) -> void:
	_etiquetas_resumen["titulo"].text = "¡Tiempo agotado!" if tiempo_agotado else "¡Misión completada!"
	_etiquetas_resumen["detalle"].text = "Aciertos: %d\nErrores: %d\nPuntaje: %d" % [aciertos, errores, puntaje]
	_etiquetas_resumen["ensenanza"].text = _mensaje_ensenanza(errores)
	_panel_resumen.visible = true


func _mensaje_ensenanza(errores: int) -> String:
	if errores == 0:
		return "¡Excelente! Identificaste todas las amenazas. Recuerda: verifica siempre el dominio del remitente antes de hacer clic."
	if errores <= 2:
		return "Buena intervención. Repasa las señales: urgencia excesiva, dominios que imitan al oficial y adjuntos inesperados."
	return "Revisa las señales de phishing: remitente real, enlaces expandidos y adjuntos no solicitados. Vuelve a intentarlo."


# --- Construcción de la UI ---------------------------------------------------

func _construir() -> void:
	_etiqueta_marcador = Label.new()
	_etiqueta_marcador.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_etiqueta_marcador.offset_left = 4
	_etiqueta_marcador.offset_right = 120
	_etiqueta_marcador.offset_top = 2
	_etiqueta_marcador.offset_bottom = 10
	_etiqueta_marcador.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_marcador.add_theme_color_override("font_color", VERDE_NEON)
	_etiqueta_marcador.add_theme_font_size_override("font_size", 6)
	add_child(_etiqueta_marcador)

	_etiqueta_tiempo = Label.new()
	_etiqueta_tiempo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_etiqueta_tiempo.offset_left = -90
	_etiqueta_tiempo.offset_right = -4
	_etiqueta_tiempo.offset_top = 2
	_etiqueta_tiempo.offset_bottom = 10
	_etiqueta_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_etiqueta_tiempo.add_theme_font_size_override("font_size", 6)
	add_child(_etiqueta_tiempo)

	_etiqueta_prompt = Label.new()
	_etiqueta_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_etiqueta_prompt.offset_left = 10
	_etiqueta_prompt.offset_right = -10
	_etiqueta_prompt.offset_top = -14
	_etiqueta_prompt.offset_bottom = -2
	_etiqueta_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_prompt.visible = false
	_etiqueta_prompt.add_theme_color_override("font_color", VERDE_NEON)
	_etiqueta_prompt.add_theme_font_size_override("font_size", 6)
	add_child(_etiqueta_prompt)

	_panel_mensaje = _crear_panel_centro(Vector2(256, 56))
	_etiqueta_mensaje = _panel_mensaje.get_child(2) as Label
	_etiqueta_mensaje.text = ""
	(_panel_mensaje.get_child(2) as Control).visible = false  # los avisos no usan el contenido del resumen
	_panel_mensaje.visible = false

	_panel_resumen = _crear_panel_centro(Vector2(240, 112))
	var contenido: VBoxContainer = _panel_resumen.get_child(3) as VBoxContainer
	var titulo := contenido.get_child(0) as Label
	var detalle := contenido.get_child(1) as Label
	var ensenanza := contenido.get_child(2) as Label
	var boton := contenido.get_child(3) as Button
	_etiquetas_resumen = {"titulo": titulo, "detalle": detalle, "ensenanza": ensenanza}
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ensenanza.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ensenanza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.text = "Volver al menú"
	boton.add_theme_font_size_override("font_size", 6)
	EstilosUI.aplicar_boton(boton)
	boton.pressed.connect(func() -> void:
		continuar_pulsado.emit()
		get_tree().change_scene_to_file("res://scenes/main/menu_principal.tscn")
	)
	(_panel_resumen.get_child(1) as Control).visible = false  # el resumen usa el contenido, no el aviso
	_panel_resumen.visible = false

	_ajustar_paneles()


## Panel centrado con fondo oscuro; se adapta al tamaño de la pantalla.
## Hijos: [0] ColorRect de fondo, [1] Label mensaje (opcional), [2] VBox contenido.
func _crear_panel_centro(tamano: Vector2) -> Control:
	# El CenterContainer garantiza el centrado en cualquier resolución.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := Control.new()
	centro.add_child(panel)
	_paneles.append({"panel": panel, "base": tamano})

	panel.add_child(EstilosUI.textura_a_pantalla(EstilosUI.TEXTURA_CUADRO))
	var velo := ColorRect.new()
	velo.color = Color(0.102, 0.114, 0.141, 0.72)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(velo)

	var mensaje := Label.new()
	mensaje.set_anchors_preset(Control.PRESET_FULL_RECT)
	mensaje.offset_left = 6
	mensaje.offset_right = -6
	mensaje.offset_top = 6
	mensaje.offset_bottom = -6
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.add_theme_color_override("font_color", VERDE_NEON)
	mensaje.add_theme_font_size_override("font_size", 6)
	panel.add_child(mensaje)

	var contenido := VBoxContainer.new()
	contenido.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenido.offset_left = 6
	contenido.offset_right = -6
	contenido.offset_top = 6
	contenido.offset_bottom = -6
	contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_theme_constant_override("separation", 2)
	panel.add_child(contenido)
	var lbl1 := Label.new()
	lbl1.add_theme_font_size_override("font_size", 8)
	lbl1.add_theme_color_override("font_color", VERDE_NEON)
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(lbl1)
	var lbl2 := Label.new()
	lbl2.add_theme_font_size_override("font_size", 6)
	lbl2.add_theme_color_override("font_color", VERDE_NEON)
	lbl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(lbl2)
	var ensenanza := Label.new()
	ensenanza.name = "Ensenanza"
	ensenanza.add_theme_font_size_override("font_size", 6)
	ensenanza.add_theme_color_override("font_color", VERDE_NEON)
	ensenanza.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ensenanza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ensenanza.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contenido.add_child(ensenanza)
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(90, 14)
	boton.add_theme_color_override("font_color", VERDE_NEON)
	boton.add_theme_font_size_override("font_size", 6)
	contenido.add_child(boton)

	return panel


## Los paneles usan su tamaño base como máximo y se encogen si la
## pantalla es más pequeña; el CenterContainer los mantiene centrados.
func _ajustar_paneles() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for entrada in _paneles:
		var base: Vector2 = entrada["base"]
		(entrada["panel"] as Control).custom_minimum_size = Vector2(
			minf(base.x, maxf(vp.x - 24.0, 140.0)),
			minf(base.y, maxf(vp.y - 24.0, 80.0))
		)
