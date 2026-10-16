extends Node2D
## Oficina de la empresa ficticia (mapa cenital): punto de partida del analista.
## Desde aquí se accede a las terminales de trabajo (módulos del juego).

const ESCENA_TERMINAL_CORREOS := preload("res://scenes/terminales/terminal_correos.tscn")
const DISTANCIA_INTERACCION := 24.0

var _jugador: Analista
var _hud: Hud
var _panel: TerminalCorreos = null
var _terminal_cercana: Variant = null

func _ready() -> void:
	_jugador = $Jugador as Analista
	_hud = $HUD as Hud
	for hijo in get_children():
		if hijo is TerminalTrabajo:
			(hijo as TerminalTrabajo).activada.connect(_al_activar_terminal)
	Temporizador.actualizado.connect(_hud.set_tiempo)
	Temporizador.expirado.connect(_al_expirar_tiempo)
	GameState.decision_registrada.connect(_al_registrar_decision)
	GameState.partida_finalizada.connect(_al_finalizar_partida)
	# Arrancamos el Nivel 1 (onboarding de phishing) — walking skeleton.
	GameState.iniciar_partida(1)
	_hud.set_marcador(0, 0, 0)


func _process(_delta: float) -> void:
	if _panel != null:
		return
	_actualizar_cercania()
	if Input.is_action_just_pressed("interactuar") and _terminal_cercana != null:
		_al_activar_terminal(_terminal_cercana)


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Point & Click: caminar hacia donde se hace clic.
		_jugador.objetivo = get_global_mouse_position()


# --- Terminales ---------------------------------------------------------------

func _actualizar_cercania() -> void:
	var mas_cercana: Variant = null
	var menor_distancia := DISTANCIA_INTERACCION
	for terminal in get_tree().get_nodes_in_group("terminales"):
		var terminal_ref := terminal as TerminalTrabajo
		if terminal_ref == null:
			continue
		var distancia: float = _jugador.position.distance_to(terminal_ref.position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			mas_cercana = terminal_ref
	_terminal_cercana = mas_cercana
	if _terminal_cercana == null:
		_hud.ocultar_prompt()
	elif _terminal_cercana.activa:
		_hud.mostrar_prompt("E · Abrir %s" % _terminal_cercana.titulo)
	else:
		_hud.mostrar_prompt("%s · módulo no disponible" % _terminal_cercana.titulo)


func _al_activar_terminal(terminal: Variant) -> void:
	if _panel != null:
		return
	if not terminal.activa:
		_hud.mostrar_mensaje("El módulo «%s» estará disponible en una actualización futura." % terminal.titulo)
		return
	if terminal.tipo == "correos":
		_abrir_panel(ESCENA_TERMINAL_CORREOS.instantiate() as TerminalCorreos)


func _abrir_panel(panel: TerminalCorreos) -> void:
	_panel = panel
	_panel.cerrado.connect(_cerrar_panel)
	_hud.add_child(_panel)
	_hud.ocultar_prompt()
	_jugador.controlable = false


func _cerrar_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if GameState.en_partida:
		_jugador.controlable = true


# --- Partida ------------------------------------------------------------------

func _al_registrar_decision(_tipo: String, _correcto: bool, puntaje: int) -> void:
	_hud.set_marcador(GameState.aciertos, GameState.errores, puntaje)


func _al_expirar_tiempo() -> void:
	# El resumen se muestra en _al_finalizar_partida (GameState finaliza al expirar).
	if _panel != null:
		_panel.queue_free()
		_panel = null


func _al_finalizar_partida(puntaje: int) -> void:
	_hud.ocultar_prompt()
	_jugador.controlable = false
	_hud.mostrar_resumen(puntaje, GameState.aciertos, GameState.errores, Temporizador.segundos_restantes() <= 0)


# --- Dibujo del mapa ----------------------------------------------------------

func _draw() -> void:
	# Suelo
	draw_rect(Rect2(0, 0, 320, 180), Color("1b2634"))
	# Zona de trabajo
	draw_rect(Rect2(8, 20, 304, 152), Color("243447"))
	# Alfombra de la sala de servidores
	draw_rect(Rect2(120, 120, 80, 45), Color("20303f"))
	# Puestos de trabajo (bancos)
	draw_rect(Rect2(40, 40, 30, 8), Color("3c4a5a"))
	draw_rect(Rect2(235, 40, 30, 8), Color("3c4a5a"))
	draw_rect(Rect2(145, 145, 30, 8), Color("3c4a5a"))
	# Pared superior con rótulo
	draw_rect(Rect2(0, 0, 320, 18), Color("101820"))
	var fuente := ThemeDB.fallback_font
	draw_string(
		fuente, Vector2(8, 12),
		"CorpSeguro S.A. (empresa ficticia) · Sala de operaciones",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("5b7285")
	)
	# Línea de suelo (píxeles de rejilla discretos)
	for x in range(8, 312, 16):
		draw_rect(Rect2(x, 171, 8, 1), Color("2a3a4d"))
