extends Control
class_name TerminalCorreos
## Módulo A — Terminal de correos: análisis de phishing contra el reloj.
## El jugador lee la bandeja y clasifica cada mensaje como PHISHING o LEGÍTIMO.
## Cada decisión genera un evento de telemetría (eventos_phishing).

signal cerrado()

const RUTA_CORREOS := "res://data/correos_nivel1.json"
const LOGICA := preload("res://systems/phishing/logica_phishing.gd")
const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")

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
	if event.is_action_pressed("ui_cancel"):
		_cerrar()


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

func _construir() -> void:
	var oscurecido := ColorRect.new()
	oscurecido.color = Color(0, 0, 0, 0.55)
	oscurecido.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(oscurecido)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var w := 300
	var h := 170
	panel.offset_left = -w / 2.0
	panel.offset_right = w / 2.0
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0
	add_child(panel)

	var fondo := ColorRect.new()
	fondo.color = Color("#1A1D24")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 4)
	margen.add_theme_constant_override("margin_right", 4)
	margen.add_theme_constant_override("margin_top", 4)
	margen.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margen)

	var caja := HBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 4)
	margen.add_child(caja)

	_caja_bandeja(caja)
	_caja_lectura(caja)


func _caja_bandeja(caja: HBoxContainer) -> void:
	var bandeja := VBoxContainer.new()
	bandeja.custom_minimum_size = Vector2(90, 0)
	bandeja.add_theme_constant_override("separation", 2)
	caja.add_child(bandeja)

	var titulo := Label.new()
	titulo.text = "Bandeja"
	titulo.add_theme_color_override("font_color", Color("4fc3f7"))
	titulo.add_theme_font_size_override("font_size", 7)
	bandeja.add_child(titulo)

	for correo in _correos:
		var boton := Button.new()
		boton.text = str(correo.get("asunto", "(sin asunto)"))
		boton.clip_text = true
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.disabled = false
		boton.add_theme_font_size_override("font_size", 6)
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
	_boton_siguiente.text = "Siguiente correo ▸"
	_boton_siguiente.disabled = true
	_boton_siguiente.add_theme_font_size_override("font_size", 6)
	_boton_siguiente.pressed.connect(_siguiente)
	bandeja.add_child(_boton_siguiente)

	var boton_cerrar := Button.new()
	boton_cerrar.text = "Cerrar (Esc)"
	boton_cerrar.add_theme_font_size_override("font_size", 6)
	boton_cerrar.pressed.connect(_cerrar)
	bandeja.add_child(boton_cerrar)


func _caja_lectura(caja: HBoxContainer) -> void:
	var lectura := VBoxContainer.new()
	lectura.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lectura.add_theme_constant_override("separation", 2)
	caja.add_child(lectura)

	_campo_remitente = Label.new()
	_campo_remitente.add_theme_color_override("font_color", Color("cfd8dc"))
	_campo_remitente.add_theme_font_size_override("font_size", 6)
	_campo_remitente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campo_remitente.clip_text = true
	lectura.add_child(_campo_remitente)

	_campo_asunto = Label.new()
	_campo_asunto.add_theme_color_override("font_color", Color("ffffff"))
	_campo_asunto.add_theme_font_size_override("font_size", 6)
	_campo_asunto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campo_asunto.clip_text = true
	lectura.add_child(_campo_asunto)

	_campo_cuerpo = Label.new()
	_campo_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campo_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_campo_cuerpo.add_theme_color_override("font_color", Color("b0bec5"))
	_campo_cuerpo.add_theme_font_size_override("font_size", 6)
	lectura.add_child(_campo_cuerpo)

	var fila_enlace := HBoxContainer.new()
	fila_enlace.add_theme_constant_override("separation", 2)
	lectura.add_child(fila_enlace)

	_campo_enlace = Label.new()
	_campo_enlace.text = "Enlace: (pulsa «Investigar enlace»)"
	_campo_enlace.clip_text = true
	_campo_enlace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_enlace.add_theme_color_override("font_color", Color("90caf9"))
	_campo_enlace.add_theme_font_size_override("font_size", 6)
	fila_enlace.add_child(_campo_enlace)

	_boton_investigar = Button.new()
	_boton_investigar.text = "Investigar enlace"
	_boton_investigar.add_theme_font_size_override("font_size", 6)
	_boton_investigar.pressed.connect(_investigar_enlace)
	fila_enlace.add_child(_boton_investigar)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 2)
	lectura.add_child(acciones)

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
	_etiqueta_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_etiqueta_feedback.add_theme_font_size_override("font_size", 6)
	lectura.add_child(_etiqueta_feedback)
