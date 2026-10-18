extends Node
## GameState: estado global de la partida.
##
## Sesión 100% seudónima (uuid + alias): el juego NO almacena PII
## (ni nombre real, correo, teléfono, dirección ni fecha de nacimiento).
## El puntaje se calcula aquí para la retroalimentación inmediata, pero la
## verdad definitiva la valida el servidor (RPC `fn_finalizar_partida`).

signal partida_iniciada(nivel_id: int)
signal partida_finalizada(puntaje: int)
signal decision_registrada(tipo: String, correcto: bool, puntaje_actual: int)

const RUTA_JUGADOR := "user://jugador.cfg"
const RUTA_NIVELES := "res://data/niveles.json"

const PUNTO_ACIERTO := 100
const PUNTO_ERROR := -50
const PUNTO_TIEMPO := 10  # bonus por segundo restante

var jugador_id: String = ""
var jugador_alias: String = ""
var partida_id: String = ""
var nivel_actual: int = 0
var aciertos: int = 0
var errores: int = 0
var puntaje: int = 0
var en_partida: bool = false
var _niveles: Array = []

func _ready() -> void:
	_registrar_acciones()
	_cargar_niveles()
	_cargar_o_crear_jugador()
	Temporizador.expirado.connect(_al_expirar_tiempo)


## Inicia una partida de un nivel concreto (1..4).
func iniciar_partida(nivel_id: int) -> void:
	nivel_actual = nivel_id
	aciertos = 0
	errores = 0
	puntaje = 0
	partida_id = _uuid_aleatorio()
	en_partida = true
	Temporizador.iniciar(duracion_nivel(nivel_id))
	Telemetria.crear_partida(nivel_id)
	partida_iniciada.emit(nivel_id)


## Registra una decisión del jugador y actualiza el marcador.
func registrar_decision(tipo: String, correcto: bool) -> void:
	if not en_partida:
		return
	if correcto:
		aciertos += 1
		puntaje += PUNTO_ACIERTO
	else:
		errores += 1
		puntaje += PUNTO_ERROR
	decision_registrada.emit(tipo, correcto, puntaje)


## Finaliza la partida sumando el bonus de tiempo restante (+10/s).
## Devuelve el puntaje final local; el servidor lo recalcula con la RPC.
func finalizar_partida() -> int:
	if not en_partida:
		return puntaje
	en_partida = false
	var bonus: int = Temporizador.segundos_restantes() * PUNTO_TIEMPO
	if bonus > 0:
		puntaje += bonus
	Temporizador.detener()
	Telemetria.finalizar_en_servidor()
	Telemetria.drenar_cola()  # disparador nº 2 del drenado (arquitectura §4.4)
	partida_finalizada.emit(puntaje)
	return puntaje


## Duración en segundos de un nivel (desde data/niveles.json; por defecto 300).
func duracion_nivel(nivel_id: int) -> int:
	for nivel in _niveles:
		if _numero_nivel(nivel) == nivel_id:
			return int(nivel.get("duracion_seg", 300))
	return 300


## Nombre del nivel para el HUD.
func nombre_nivel(nivel_id: int) -> String:
	for nivel in _niveles:
		if _numero_nivel(nivel) == nivel_id:
			return str(nivel.get("nombre", ""))
	return ""


## El JSON canónico (doc/diseno/01-misiones.md §5.3) usa la clave `id`;
## se acepta también `numero` por compatibilidad con el formato anterior.
func _numero_nivel(nivel: Dictionary) -> int:
	return int(nivel.get("id", nivel.get("numero", 0)))


func _al_expirar_tiempo() -> void:
	if en_partida:
		finalizar_partida()


# --- Sesión seudónima -------------------------------------------------------

func _cargar_o_crear_jugador() -> void:
	var configuracion := ConfigFile.new()
	if configuracion.load(RUTA_JUGADOR) == OK:
		jugador_id = str(configuracion.get_value("jugador", "id", ""))
		jugador_alias = str(configuracion.get_value("jugador", "alias", ""))
	if jugador_id.is_empty():
		jugador_id = _uuid_aleatorio()
		jugador_alias = "analista-%s" % _uuid_aleatorio().substr(0, 4)
		configuracion.set_value("jugador", "id", jugador_id)
		configuracion.set_value("jugador", "alias", jugador_alias)
		configuracion.save(RUTA_JUGADOR)
	Telemetria.crear_jugador()


# --- Contenido ---------------------------------------------------------------

func _cargar_niveles() -> void:
	if not FileAccess.file_exists(RUTA_NIVELES):
		push_error("[GameState] Falta %s" % RUTA_NIVELES)
		return
	var texto := FileAccess.get_file_as_string(RUTA_NIVELES)
	var datos = JSON.parse_string(texto)
	# Formato canónico: {"niveles": [...]}. Se acepta también un array
	# raíz por compatibilidad con versiones anteriores del fichero.
	if datos is Dictionary and datos.get("niveles") is Array:
		_niveles = datos.get("niveles")
	elif datos is Array:
		_niveles = datos


# --- Utilidades --------------------------------------------------------------

func _registrar_acciones() -> void:
	var acciones: Dictionary = {
		"mover_arriba": [KEY_W, KEY_UP],
		"mover_abajo": [KEY_S, KEY_DOWN],
		"mover_izquierda": [KEY_A, KEY_LEFT],
		"mover_derecha": [KEY_D, KEY_RIGHT],
		"interactuar": [KEY_E, KEY_ENTER],
	}
	for accion in acciones:
		if InputMap.has_action(accion):
			continue
		InputMap.add_action(accion)
		for tecla in acciones[accion]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(accion, evento)


func _uuid_aleatorio() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in range(16):
		bytes[i] = rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0f) | 0x40  # versión 4
	bytes[8] = (bytes[8] & 0x3f) | 0x80  # variante RFC 4122
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]
