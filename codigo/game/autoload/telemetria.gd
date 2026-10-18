extends Node
## Telemetria: envío de eventos a Supabase con cola offline.
##
## Punto único de escritura de telemetría (arquitectura §4.4). Flujo:
## todo registro se encola primero en `user://cola_eventos.json`
## (conserva el orden FIFO) y se drena en serie contra Supabase REST.
## Si falla la red, se reintenta con backoff exponencial (1→2→4→8→16 s;
## tras 5 fallos, 60 s) y NUNCA se descarta un evento.
## Solo INSERT (append-only, política RLS) y solo sobre las tablas
## `eventos_*` (whitelist): cualquier otra tabla lanza `push_error` y se
## descarta. Las altas de `jugadores`/`partidas` (endpoints §6.2 de la
## arquitectura) pasan por `_encolar_alta()`, NO por `registrar_evento`.

signal evento_enviado(tabla: String)
signal evento_encolado(tabla: String)
signal evento_fallido(tabla: String, codigo: int)
signal cola_drenada(pendientes_restantes: int)

const CLIENTE_SUPABASE := preload("res://services/supabase_client.gd")
const COLA_OFFLINE := preload("res://services/cola_offline.gd")

## Whitelist de tablas de telemetría (modelo de dominio §7).
const TABLAS_PERMITIDAS: Array[String] = [
	"eventos_phishing", "eventos_password", "eventos_servidor",
]

const INTERVALO_DRENADO := 0.4    # segundos entre envíos (FIFO estricto)
const BACKOFF_INICIAL := 1.0      # reintento 1: 1 s
const BACKOFF_MAXIMO := 60.0      # tras agotar los 5 reintentos con backoff
const REINTENTOS_BACKOFF := 5     # 1 s → 2 s → 4 s → 8 s → 16 s

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

	# Reintento con backoff: cada N segundos mientras haya fallos y la red
	# vuelva, se vuelve a intentar drenar (disparador nº 3).
	_reintento = Timer.new()
	_reintento.wait_time = BACKOFF_INICIAL
	_reintento.one_shot = true
	add_child(_reintento)
	_reintento.timeout.connect(_drenar)

	# Disparador nº 1: arranque del juego → recargar la cola y drenar.
	_recargar_y_drenar.call_deferred()


## Registra al jugador (uuid + alias seudónimo). Si ya existe (409), el
## evento se marca como fallo definitivo y la cola no se bloquea.
func crear_jugador() -> void:
	_encolar_alta("jugadores", {
		"id": GameState.jugador_id,
		"alias": GameState.jugador_alias,
	})


## Crea la partida en servidor (el id lo genera el cliente para poder
## referenciar los eventos aunque esté offline).
func crear_partida(nivel_id: int) -> void:
	_encolar_alta("partidas", {
		"id": GameState.partida_id,
		"jugador_id": GameState.jugador_id,
		"nivel_id": nivel_id,
	})


## Encola un evento de telemetría. Valida la tabla contra la whitelist:
## cualquier otra tabla lanza `push_error` y se descarta (defensa en
## profundidad junto al RLS; arquitectura §4.4).
func registrar_evento(tabla: String, payload: Dictionary) -> void:
	if not TABLAS_PERMITIDAS.has(tabla):
		push_error("[Telemetria] Tabla fuera de la whitelist («%s»): evento descartado." % tabla)
		return
	_encolar_alta(tabla, payload)


## Pide al servidor recalcular el puntaje (la verdad vive en el servidor).
func finalizar_en_servidor() -> void:
	if not Config.listo_para_red() or GameState.partida_id.is_empty():
		return
	_cliente.llamar_rpc("fn_finalizar_partida", {
		"p_partida_id": GameState.partida_id,
		"p_tiempo_restante": Temporizador.segundos_restantes(),
	})


## Dispara el drenado de la cola (FIFO, con backoff). Lo llama el arranque,
## `GameState.finalizar_partida` y el reintento programado.
func drenar_cola() -> void:
	_programar_drenado()


## Nº de eventos pendientes de enviar (para el HUD/debug).
func pendientes() -> int:
	return _cola.pendientes()


# --- Cola y drenado -----------------------------------------------------------

## Alta de jugadores/partidas (endpoints POST §6.2): fuera de la whitelist
## de eventos, pero con el mismo canal persistente y append-only.
func _encolar_alta(tabla: String, payload: Dictionary) -> void:
	_cola.encolar(tabla, payload)
	evento_encolado.emit(tabla)
	_programar_drenado()


func _recargar_y_drenar() -> void:
	_cola.recargar()
	if not _cola.vacia():
		_programar_drenado()


func _programar_drenado() -> void:
	if _ocupado or not _drenado.is_stopped():
		return
	if not Config.listo_para_red():
		return  # modo offline: todo sigue encolado, nunca se bloquea la partida
	if _cola.siguiente().is_empty():
		return  # no hay eventos enviables (vacía o solo fallos definitivos)
	_drenado.start()


func _drenar() -> void:
	if _ocupado or not Config.listo_para_red():
		return
	var elemento: Dictionary = _cola.siguiente()
	if elemento.is_empty():
		cola_drenada.emit(_cola.pendientes())
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
	_cola.confirmar_enviado()
	evento_enviado.emit(tabla)
	if _cola.vacia():
		_reintento.stop()
		cola_drenada.emit(0)
	else:
		_drenado.start()


func _al_fallar(tabla: String, _payload: Dictionary, codigo: int) -> void:
	_ocupado = false
	evento_fallido.emit(tabla, codigo)
	if codigo >= 400 and codigo < 500:
		# 4xx (400/403/409/422): payload que viola el contrato. NO se
		# reintenta en bucle; se marca `fallo_definitivo` y se conserva el
		# evento en cola para diagnóstico (arquitectura §6.4).
		push_warning("[Telemetria] Fallo definitivo (HTTP %d) en «%s»: evento conservado en cola." % [codigo, tabla])
		_cola.marcar_fallo_definitivo()
		cola_drenada.emit(_cola.pendientes())
		return
	# 5xx / timeout / red caída: reintento con backoff exponencial.
	var reintentos: int = _cola.incrementar_reintentos()
	_reintento.wait_time = _backoff_para(reintentos)
	_reintento.start()


## Backoff exponencial: 1 s → 2 s → 4 s → 8 s → 16 s (5 reintentos) → 60 s.
## Tras 5 fallos el evento NUNCA se descarta: queda en cola y se reintenta
## en el siguiente drenado.
func _backoff_para(reintentos: int) -> float:
	if reintentos <= REINTENTOS_BACKOFF:
		return BACKOFF_INICIAL * pow(2.0, float(reintentos - 1))
	return BACKOFF_MAXIMO
