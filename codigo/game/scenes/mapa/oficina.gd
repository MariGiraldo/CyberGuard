extends Node2D
## Oficina de la empresa ficticia (mapa cenital): punto de partida del analista.
## Desde aquí se accede a las terminales de trabajo (módulos del juego).

const DISTANCIA_INTERACCION := 24.0

var _jugador: Analista
var _hud: Hud
var _panel: Control = null
var _terminal_cercana: Variant = null
var _iniciado: bool = false
## Escena de la terminal de correos: se carga de forma perezosa (load) SOLO en
## el instante de abrirla con la tecla E. Nunca se precarga ni se instancia al
## cargar la oficina.
var _escena_terminal_correos: PackedScene = null

func _ready() -> void:
	_crear_fondo_mapa()
	_jugador = $Jugador as Analista
	_hud = $HUD as Hud

	if _jugador != null:
		_jugador.controlable = true

	for hijo in get_children():
		if hijo is TerminalTrabajo:
			# El clic sobre la terminal NUNCA abre el módulo: solo emite el aviso.
			(hijo as TerminalTrabajo).activada.connect(_al_hacer_clic_en_terminal)

	Temporizador.actualizado.connect(_hud.set_tiempo)
	Temporizador.expirado.connect(_al_expirar_tiempo)
	GameState.decision_registrada.connect(_al_registrar_decision)
	GameState.partida_finalizada.connect(_al_finalizar_partida)

	# Arrancamos la partida
	GameState.iniciar_partida(1)
	_hud.set_marcador(0, 0, 0)
	AudioManager.reproducir_musica()

	# Garantiza que en el primer segundo de carga NO se abra ninguna terminal automáticamente
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		_iniciado = true
	)


## Coloca fondo_mapa.jpg como fondo del escenario.
func _crear_fondo_mapa() -> void:
	var textura := EstilosUI.TEXTURA_FONDO_MAPA
	if textura == null:
		return
	var fondo := Sprite2D.new()
	fondo.name = "FondoMapa"
	fondo.texture = textura
	fondo.centered = true
	fondo.position = Vector2(160, 90)
	var escala: float = max(320.0 / textura.get_width(), 180.0 / textura.get_height())
	fondo.scale = Vector2(escala, escala)
	fondo.z_index = -1
	add_child(fondo)


func _process(_delta: float) -> void:
	_actualizar_cercania()
	if Input.is_action_just_pressed("interactuar"):
		if _panel != null:
			_cerrar_panel()
			return
		if _terminal_cercana != null and _terminal_cercana.activa:
			_al_activar_terminal(_terminal_cercana)
			return


func _unhandled_input(event: InputEvent) -> void:
	if _panel != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interactuar"):
			_cerrar_panel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Point & Click: caminar hacia donde se hace clic.
		if _jugador.controlable:
			_jugador.objetivo = get_global_mouse_position()


# --- Terminales ---------------------------------------------------------------

func _actualizar_cercania() -> void:
	var mas_cercana: Variant = null
	var menor_distancia := DISTANCIA_INTERACCION

	for terminal in get_tree().get_nodes_in_group("terminales"):
		var terminal_ref := terminal as TerminalTrabajo
		if terminal_ref == null or _jugador == null:
			continue
		var distancia: float = _jugador.position.distance_to(terminal_ref.position)
		if distancia < menor_distancia:
			menor_distancia = distancia
			mas_cercana = terminal_ref

	_terminal_cercana = mas_cercana
	if _panel != null:
		return
	if _terminal_cercana == null:
		_hud.ocultar_prompt()
	elif _terminal_cercana.activa:
		_hud.mostrar_prompt("E · Abrir %s" % _terminal_cercana.titulo)
	else:
		_hud.mostrar_prompt("%s · módulo no disponible" % _terminal_cercana.titulo)


## Clic sobre una terminal: NUNCA abre el módulo (solo la tecla E estando
## cerca puede hacerlo). Aquí únicamente se orienta al jugador.
func _al_hacer_clic_en_terminal(terminal: Variant) -> void:
	if not _iniciado or _panel != null:
		return
	if terminal != _terminal_cercana:
		_hud.mostrar_mensaje("Acércate a la terminal y pulsa E para interactuar.")
	elif not terminal.activa:
		_hud.mostrar_mensaje("El módulo «%s» estará disponible en una actualización futura." % terminal.titulo)


## Único punto de apertura de los módulos. Solo lo invoca la tecla E (ver _process).
func _abrir_terminal(terminal: Variant) -> void:
	if not _iniciado or _panel != null or _jugador == null:
		return
	# Guardia de proximidad: la terminal debe estar al alcance del analista.
	var posicion_terminal: Vector2 = terminal.position
	if _jugador.position.distance_to(posicion_terminal) > DISTANCIA_INTERACCION:
		return
	if not terminal.activa:
		_hud.mostrar_mensaje("El módulo «%s» estará disponible en una actualización futura." % terminal.titulo)
		return
	if terminal.tipo == "correos":
		_abrir_panel(_cargar_escena_correos().instantiate() as Control)


## Carga perezosa de la terminal de correos: jamás al iniciar la escena.
func _cargar_escena_correos() -> PackedScene:
	if _escena_terminal_correos == null:
		_escena_terminal_correos = load("res://scenes/terminales/terminal_correos.tscn") as PackedScene
	return _escena_terminal_correos


func _abrir_panel(panel: Control) -> void:
	_panel = panel
	_panel.connect("cerrado", Callable(self, "_cerrar_panel"))

	var capa_modal := CanvasLayer.new()
	capa_modal.name = "CapaTerminalModal"
	capa_modal.layer = 20

	var contenedor_centro := CenterContainer.new()
	contenedor_centro.name = "ContenedorCentro"
	contenedor_centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	contenedor_centro.add_child(_panel)
	capa_modal.add_child(contenedor_centro)
	add_child(capa_modal)

	_hud.ocultar_prompt()
	if _jugador != null:
		_jugador.controlable = false
		_jugador.objetivo = null
		_jugador.set_physics_process(false)


func _cerrar_panel() -> void:
	if _panel != null:
		var capa := get_node_or_null("CapaTerminalModal")
		if capa != null:
			capa.queue_free()
		else:
			_panel.queue_free()
		_panel = null
	if GameState.en_partida and _jugador != null:
		_jugador.controlable = true
		_jugador.set_physics_process(true)


# --- Partida ------------------------------------------------------------------

func _al_registrar_decision(_tipo: String, correcto: bool, puntaje: int) -> void:
	_hud.set_marcador(GameState.aciertos, GameState.errores, puntaje)
	if correcto:
		AudioManager.reproducir_correcto()
	else:
		AudioManager.reproducir_incorrecto()


func _al_expirar_tiempo() -> void:
	# El resumen se muestra en _al_finalizar_partida (GameState finaliza al expirar).
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if _jugador != null:
		_jugador.controlable = false
		_jugador.set_physics_process(false)


func _al_finalizar_partida(puntaje: int) -> void:
	_hud.ocultar_prompt()
	if _jugador != null:
		_jugador.controlable = false
		_jugador.set_physics_process(false)
	_hud.mostrar_resumen(puntaje, GameState.aciertos, GameState.errores, Temporizador.segundos_restantes() <= 0)


# --- Dibujo del mapa ----------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 18), Color(0.063, 0.094, 0.125, 0.85))
	var fuente := ThemeDB.fallback_font
	draw_string(
		fuente, Vector2(8, 12),
		"NexoData (empresa ficticia) · Sala de operaciones",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("5b7285")
	)