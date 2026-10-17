extends Control
class_name TerminalCorreos
## Módulo A — Terminal de correos: análisis de phishing contra el reloj.
## El jugador lee la bandeja y clasifica cada mensaje como PHISHING o LEGÍTIMO.
## Cada decisión genera un evento de telemetría (eventos_phishing).

signal cerrado()

const RUTA_CORREOS := "res://data/correos_nivel1.json"
const LOGICA := preload("res://systems/phishing/logica_phishing.gd")
const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")
const PANEL_BASE := Vector2(280, 150)  ## Tamaño preferido del panel de la misión.
const PANEL_MARGEN := 12.0            ## Separación mínima respecto al borde.

var _correos: Array = []
var _indice: int = -1
var _respondidos: Dictionary = {}  # id -> true si es correcto
var _inicio_respuesta_ms: int = 0
var _botones_lista: Array = []
var _campo_remitente: Label
var _campo_asunto: Label
var _campo_cuerpo: Label
var _campo_enlace: Label
var _boton_investigar: Button
var _boton_phishing: Button
var _boton_legitimo: Button
var _etiqueta_feedback: Label
var _boton_siguiente: Button
var _etiqueta_progreso: Label
var _panel_mision: Control
var _desplazable: ScrollContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = TEMA_CIBER
	_cargar_correos()
	_construir()
	if _correos.is_empty():
		_etiqueta_feedback.text = "No hay correos disponibles (falta data/correos_nivel1.json)."
		_boton_siguiente.disabled = true
	else:
		_mostrar_correo(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interactuar"):
		_cerrar()
		get_viewport().set_input_as_handled()


func _notification(que: int) -> void:
	# Si cambia el tamaño de la ventana, el panel se reajusta y sigue centrado.
	if que == NOTIFICATION_RESIZED and is_instance_valid(_panel_mision):
		_ajustar_al_ventana()


# --- Contenido ----------------------------------------------------------------

func _cargar_correos() -> void:
	if not FileAccess.file_exists(RUTA_CORREOS):
		push_error("[TerminalCorreos] Falta %s" % RUTA_CORREOS)
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CORREOS))
	if datos is Array:
		_correos = datos


func _correo_actual() -> Dictionary:
	if _indice >= 0 and _indice < _correos.size():
		return _correos[_indice]
	return {}


func _mostrar_correo(indice: int) -> void:
	_indice = indice
	var correo := _correo_actual()
	if correo.is_empty():
		return
	_campo_remitente.text = "De: %s" % str(correo.get("remitente", ""))
	_campo_asunto.text = "Asunto: %s" % str(correo.get("asunto", ""))
	_campo_cuerpo.text = str(correo.get("cuerpo", ""))
	# Cada correo se lee desde arriba: reiniciamos el desplazamiento.
	if _desplazable != null:
		_desplazable.set_deferred("scroll_vertical", 0)
	_campo_enlace.text = "Enlace: (pulsa «Investigar enlace»)"
	_boton_investigar.disabled = false
	_etiqueta_feedback.text = ""
	var ya_respondido := _respondidos.has(str(correo.get("id", "")))
	_boton_phishing.disabled = ya_respondido
	_boton_legitimo.disabled = ya_respondido
	_boton_investigar.disabled = ya_respondido
	_etiqueta_progreso.text = "Correo %d/%d · respondidos: %d" % [
		indice + 1, _correos.size(), _respondidos.size()
	]
	_inicio_respuesta_ms = Time.get_ticks_msec()


func _investigar_enlace() -> void:
	var correo := _correo_actual()
	if correo.is_empty():
		return
	_campo_enlace.text = "URL real: %s" % str(correo.get("investigar_url", correo.get("enlace", "")))
	_boton_investigar.disabled = true


func _tomar_decision(decision: String) -> void:
	var correo := _correo_actual()
	if correo.is_empty():
		return
	var id := str(correo.get("id", ""))
	if _respondidos.has(id):
		return
	var correcto: bool = LOGICA.clasificar(correo, decision)
	var es_phishing := bool(correo.get("phishing", false))

	GameState.registrar_decision("phishing", correcto)
	Telemetria.registrar_evento("eventos_phishing", {
		"partida_id": GameState.partida_id,
		"jugador_id": GameState.jugador_id,
		"correo_id": id,
		"decision": decision,
		"es_correcto": correcto,
		"senal_clave": LOGICA.senal_de(correo) if es_phishing else "",
		"tiempo_respuesta_ms": Time.get_ticks_msec() - _inicio_respuesta_ms,
	})

	_etiqueta_feedback.text = LOGICA.retroalimentacion(correo, decision)
	_etiqueta_feedback.add_theme_color_override(
		"font_color", Color("7ee081") if correcto else Color("ff8a80")
	)
	_respondidos[id] = correcto
	var boton := _botones_lista[_indice] as Button
	var marca := "✓ " if correcto else "✗ "
	boton.text = marca + str(correo.get("asunto", ""))
	boton.disabled = false  # se puede revisar, pero no re-responder
	_boton_phishing.disabled = true
	_boton_legitimo.disabled = true
	_boton_investigar.disabled = true
	_boton_siguiente.disabled = false
	_etiqueta_progreso.text = "Correo %d/%d · respondidos: %d" % [
		_indice + 1, _correos.size(), _respondidos.size()
	]
	if _respondidos.size() >= _correos.size():
		# Bandeja completada: la misión termina y el HUD muestra el resumen.
		_cerrar()
		GameState.finalizar_partida()


func _siguiente() -> void:
	if _respondidos.size() >= _correos.size():
		_cerrar()
		return
	var siguiente := (_indice + 1) % _correos.size()
	while _respondidos.has(str(_correos[siguiente].get("id", ""))):
		siguiente = (siguiente + 1) % _correos.size()
	_mostrar_correo(siguiente)


func _cerrar() -> void:
	cerrado.emit()


# --- Construcción de la UI ----------------------------------------------------

## El panel ocupa su tamaño base como máximo y se encoge si la pantalla
## es más pequeña, de modo que nunca invade el borde y queda siempre centrado.
func _ajustar_al_ventana() -> void:
	var vp := get_viewport_rect().size
	_panel_mision.custom_minimum_size = Vector2(
		minf(PANEL_BASE.x, maxf(vp.x - PANEL_MARGEN * 2.0, 160.0)),
		minf(PANEL_BASE.y, maxf(vp.y - PANEL_MARGEN * 2.0, 100.0))
	)


func _construir() -> void:
	var oscurecido := ColorRect.new()
	oscurecido.color = Color(0, 0, 0, 0.55)
	oscurecido.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(oscurecido)

	# El CenterContainer garantiza que el panel quede en el centro exacto
	# de la pantalla, sea cual sea la resolución o el tamaño de la ventana.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	_panel_mision = Control.new()
	centro.add_child(_panel_mision)

	var fondo := ColorRect.new()
	fondo.color = Color("#1A1D24")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_mision.add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 8)
	margen.add_theme_constant_override("margin_right", 8)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	_panel_mision.add_child(margen)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 4)
	margen.add_child(caja)

	var caja_superior := HBoxContainer.new()
	caja_superior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_superior.add_theme_constant_override("separation", 4)
	caja.add_child(caja_superior)

	var caja_inferior := VBoxContainer.new()
	caja_inferior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_inferior.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja_inferior.add_theme_constant_override("separation", 4)
	caja.add_child(caja_inferior)

	_caja_bandeja(caja_superior)
	_caja_lectura(caja_superior, caja_inferior)

	_ajustar_al_ventana()


func _caja_bandeja(caja: HBoxContainer) -> void:
	var bandeja := VBoxContainer.new()
	bandeja.custom_minimum_size = Vector2(90, 0)
	bandeja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bandeja.add_theme_constant_override("separation", 2)
	caja.add_child(bandeja)

	var titulo := Label.new()
	titulo.text = "Bandeja"
	titulo.add_theme_color_override("font_color", Color("4fc3f7"))
	titulo.add_theme_font_size_override("font_size", 6)
	bandeja.add_child(titulo)

	for correo in _correos:
		var boton := Button.new()
		boton.text = str(correo.get("asunto", "(sin asunto)"))
		boton.clip_text = true
		# Los asuntos largos se recortan con "…" en vez de salirse del botón.
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.disabled = false
		boton.add_theme_font_size_override("font_size", 5)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var indice := _correos.find(correo)
		boton.pressed.connect(func() -> void: _mostrar_correo(indice))
		bandeja.add_child(boton)
		_botones_lista.append(boton)

	_etiqueta_progreso = Label.new()
	_etiqueta_progreso.add_theme_color_override("font_color", Color("9fb3c8"))
	_etiqueta_progreso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_progreso.add_theme_font_size_override("font_size", 6)
	bandeja.add_child(_etiqueta_progreso)

	var espaciador := Control.new()
	espaciador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bandeja.add_child(espaciador)

	_boton_siguiente = Button.new()
	_boton_siguiente.text = "Siguiente"
	_boton_siguiente.disabled = true
	_boton_siguiente.add_theme_font_size_override("font_size", 6)
	_boton_siguiente.pressed.connect(_siguiente)
	bandeja.add_child(_boton_siguiente)

	var boton_cerrar := Button.new()
	boton_cerrar.text = "Cerrar (Esc/E)"
	boton_cerrar.add_theme_font_size_override("font_size", 6)
	boton_cerrar.pressed.connect(_cerrar)
	bandeja.add_child(boton_cerrar)


func _caja_lectura(caja_izq: HBoxContainer, caja_inf: VBoxContainer) -> void:
	var lectura := VBoxContainer.new()
	lectura.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lectura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lectura.add_theme_constant_override("separation", 2)
	caja_izq.add_child(lectura)

	var encabezado := VBoxContainer.new()
	encabezado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_theme_constant_override("separation", 1)
	lectura.add_child(encabezado)

	_campo_remitente = Label.new()
	_campo_remitente.add_theme_color_override("font_color", Color("cfd8dc"))
	_campo_remitente.add_theme_font_size_override("font_size", 6)
	_campo_remitente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encabezado.add_child(_campo_remitente)

	_campo_asunto = Label.new()
	_campo_asunto.add_theme_color_override("font_color", Color("ffffff"))
	_campo_asunto.add_theme_font_size_override("font_size", 6)
	_campo_asunto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encabezado.add_child(_campo_asunto)

	# Área de lectura del cuerpo: un ScrollContainer con relleno de 4px evita
	# que el texto largo desborde el panel; el jugador puede desplazarlo.
	_desplazable = ScrollContainer.new()
	_desplazable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desplazable.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var relleno := MarginContainer.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	relleno.add_theme_constant_override("margin_left", 4)
	relleno.add_theme_constant_override("margin_right", 4)
	relleno.add_theme_constant_override("margin_top", 4)
	relleno.add_theme_constant_override("margin_bottom", 4)
	caja_inf.add_child(relleno)
	relleno.add_child(_desplazable)

	_campo_cuerpo = Label.new()
	_campo_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campo_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_cuerpo.add_theme_color_override("font_color", Color("b0bec5"))
	_campo_cuerpo.add_theme_font_size_override("font_size", 6)
	_desplazable.add_child(_campo_cuerpo)

	var fila_enlace := HBoxContainer.new()
	fila_enlace.add_theme_constant_override("separation", 2)
	fila_enlace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_enlace.alignment = BoxContainer.ALIGNMENT_CENTER
	caja_inf.add_child(fila_enlace)

	_campo_enlace = Label.new()
	_campo_enlace.text = "Enlace: (pulsa «Investigar enlace»)"
	_campo_enlace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_enlace.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campo_enlace.add_theme_color_override("font_color", Color("90caf9"))
	_campo_enlace.add_theme_font_size_override("font_size", 6)
	fila_enlace.add_child(_campo_enlace)

	_boton_investigar = Button.new()
	_boton_investigar.text = "Investigar enlace"
	_boton_investigar.add_theme_font_size_override("font_size", 6)
	_boton_investigar.pressed.connect(_investigar_enlace)
	fila_enlace.add_child(_boton_investigar)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 4)
	acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	caja_inf.add_child(acciones)

	_boton_phishing = Button.new()
	_boton_phishing.text = "PHISHING"
	_boton_phishing.add_theme_color_override("font_color", Color("ff8a80"))
	_boton_phishing.add_theme_font_size_override("font_size", 6)
	_boton_phishing.pressed.connect(func() -> void: _tomar_decision("PHISHING"))
	acciones.add_child(_boton_phishing)

	_boton_legitimo = Button.new()
	_boton_legitimo.text = "LEGÍTIMO"
	_boton_legitimo.add_theme_color_override("font_color", Color("7ee081"))
	_boton_legitimo.add_theme_font_size_override("font_size", 6)
	_boton_legitimo.pressed.connect(func() -> void: _tomar_decision("LEGITIMO"))
	acciones.add_child(_boton_legitimo)

	_etiqueta_feedback = Label.new()
	_etiqueta_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_feedback.add_theme_font_size_override("font_size", 6)
	caja_inf.add_child(_etiqueta_feedback)
