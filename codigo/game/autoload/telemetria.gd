extends Node
## Telemetria: envío de eventos a Supabase con cola offline.
##
## Flujo: todo registro se encolan primero en `user://cola_eventos.json`
## (conserva el orden: jugadores → partidas → eventos) y se drena en serie
## contra Supabase REST. Si falla la red, se reintenta con backoff.
## Tablas: `jugadores`, `partidas`, `eventos_phishing`, `eventos_password`,
## `eventos_servidor`. Solo INSERT (append-only, política RLS).

signal evento_enviado(tabla: String)
signal evento_encolado(tabla: String)
signal evento_fallido(tabla: String, codigo: int)

const CLIENTE_SUPABASE := preload("res://services/supabase_client.gd")
const COLA_OFFLINE := preload("res://services/cola_offline.gd")

const INTERVALO_DRENADO := 0.4   # segundos entre envíos (respeta el orden)
const INTERVALO_REINTENTO := 15.0  # reintento tras un fallo de red

var _cliente: ClienteSupabase
var _cola: ColaOffline
var _drenado: Timer
var _reintento: Timer
var _ocupado: bool = false

func _ready() -> void:
	_cola = COLA_OFFLINE.new()
	_cliente = CLIENTE_SUPABASE.new()
	add_child(_cliente)
	_cliente.insertado.connect(_al_insertar)
	_cliente.fallido.connect(_al_fallar)

	_drenado = Timer.new()
	_drenado.wait_time = INTERVALO_DRENADO
	_drenado.one_shot = true
	add_child(_drenado)
	_drenado.timeout.connect(_drenar)

	_reintento = Timer.new()
	_reintento.wait_time = INTERVALO_REINTENTO
	_reintento.one_shot = true
	add_child(_reintento)
	_reintento.timeout.connect(_drenar)


## Registra al jugador (uuid + alias seudónimo). Si ya existe, la cola lo omite.
func crear_jugador() -> void:
	registrar_evento("jugadores", {
		"id": GameState.jugador_id,
		"alias": GameState.jugador_alias,
	})


## Crea la partida en servidor (el id lo genera el cliente para poder
## referenciar los eventos aunque esté offline).
func crear_partida(nivel_id: int) -> void:
	registrar_evento("partidas", {
		"id": GameState.partida_id,
		"jugador_id": GameState.jugador_id,
		"nivel_id": nivel_id,
	})


## Encola un registro genérico de telemetría.
func registrar_evento(tabla: String, payload: Dictionary) -> void:
	_cola.encolar(tabla, payload)
	evento_encolado.emit(tabla)
	_programar_drenado()


## Pide al servidor recalcular el puntaje (la verdad vive en el servidor).
func finalizar_en_servidor() -> void:
	if not Config.listo_para_red() or GameState.partida_id.is_empty():
		return
	_cliente.llamar_rpc("fn_finalizar_partida", {
		"p_partida_id": GameState.partida_id,
		"p_tiempo_restante": Temporizador.segundos_restantes(),
	})


# --- Drenado de la cola ------------------------------------------------------

func _programar_drenado() -> void:
	if _ocupado or not _drenado.is_stopped():
		return
	_drenado.start()


func _drenar() -> void:
	if _ocupado or _cola.vacia() or not Config.listo_para_red():
		return
	var elemento: Dictionary = _cola.siguiente()
	if elemento.is_empty():
		return
	_ocupado = true
	_cliente.insertar(str(elemento.get("tabla", "")), _normalizar(elemento.get("payload", {})))


## JSON reconvierte los enteros como floats (1 → 1.0); los enteros exactos
## se devuelven como int para que PostgREST no rechace los tipos.
func _normalizar(payload: Dictionary) -> Dictionary:
	var salida := {}
	for clave in payload:
		var valor = payload[clave]
		if valor is float and is_equal_approx(valor, floor(valor)):
			salida[clave] = int(valor)
		else:
			salida[clave] = valor
	return salida


func _al_insertar(tabla: String) -> void:
	_ocupado = false
	_cola.quitar_primero()
	evento_enviado.emit(tabla)
	if not _cola.vacia():
		_drenado.start()


func _al_fallar(tabla: String, _payload: Dictionary, codigo: int) -> void:
	_ocupado = false
	evento_fallido.emit(tabla, codigo)
	if codigo == 409:
		# Registro ya existente (por ejemplo el jugador en otro dispositivo):
		# se descarta para no bloquear la cabeza de la cola.
		_cola.quitar_primero()
		if not _cola.vacia():
			_drenado.start()
		return
	_reintento.start()
