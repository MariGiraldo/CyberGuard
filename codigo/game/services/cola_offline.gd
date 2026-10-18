extends RefCounted
class_name ColaOffline
## Cola offline de telemetría (contrato congelado: arquitectura §5.2).
##
## Si la red falla (o Supabase no está configurado), los eventos se guardan en
## `user://cola_eventos.json` y se drenan en FIFO estricto cuando vuelve la
## conexión. Ningún evento se descarta jamás: tras 5 fallos sigue en cola.
##
## Cada elemento persistido es:
##   { tabla, payload, creado_localmente_ms, reintentos, fallo_definitivo }
## La marca `creado_localmente_ms` es solo de diagnóstico: NUNCA se envía al
## servidor (el servidor pone su propio `creado_en`).

const RUTA := "user://cola_eventos.json"
const MAX_REINTENTOS := 5

var cola: Array = []
var _indice_actual: int = -1  # evento que está siendo enviado ahora mismo

func _init() -> void:
	recargar()


## Añade un evento al final de la cola y persiste a disco inmediatamente.
func encolar(tabla: String, payload: Dictionary) -> void:
	cola.append({
		"tabla": tabla,
		"payload": payload.duplicate(),
		"creado_localmente_ms": Time.get_ticks_msec(),
		"reintentos": 0,
		"fallo_definitivo": false,
	})
	guardar()


## Evento más antiguo pendiente (FIFO). Salta los marcados como
## `fallo_definitivo` (4xx: se conservan en cola pero no se reintentan en
## bucle, para no envenenar el backoff). Devuelve {} si no hay enviables.
func siguiente() -> Dictionary:
	_indice_actual = -1
	for i in range(cola.size()):
		if not bool(cola[i].get("fallo_definitivo", false)):
			_indice_actual = i
			return cola[i]
	return {}


## Retira el evento actual (el devuelto por `siguiente()`) tras un 2xx.
func confirmar_enviado() -> void:
	if _indice_actual >= 0 and _indice_actual < cola.size():
		cola.remove_at(_indice_actual)
		guardar()
	_indice_actual = -1


## Registra un fallo transitorio (5xx / timeout / red caída) sobre el evento
## actual. Devuelve el nº de reintentos acumulados del evento.
func incrementar_reintentos() -> int:
	var reintentos := 0
	if _indice_actual >= 0 and _indice_actual < cola.size():
		reintentos = int(cola[_indice_actual].get("reintentos", 0)) + 1
		cola[_indice_actual]["reintentos"] = reintentos
		guardar()
	_indice_actual = -1
	return reintentos


## Marca el evento actual como `fallo_definitivo` (4xx: payload que viola el
## contrato). NO se reintenta en bucle, pero SE CONSERVA en la cola para
## diagnóstico (nunca se descarta silenciosamente).
func marcar_fallo_definitivo() -> void:
	if _indice_actual >= 0 and _indice_actual < cola.size():
		cola[_indice_actual]["fallo_definitivo"] = true
		guardar()
	_indice_actual = -1


## Nº de eventos aún no enviados (excluye los fallos definitivos de
## diagnóstico, que quedan en cola sin bloquear el drenado).
func pendientes() -> int:
	var cuenta := 0
	for elemento in cola:
		if not bool(elemento.get("fallo_definitivo", false)):
			cuenta += 1
	return cuenta


func vacia() -> bool:
	return pendientes() == 0


## Carga la cola desde disco (arranque del juego). Normaliza los elementos
## de versiones antiguas del fichero (sin reintentos/marcas).
func recargar() -> void:
	cargar()


## Solo para tests: vacía la cola en memoria y en disco.
func limpiar() -> void:
	cola.clear()
	_indice_actual = -1
	guardar()


func guardar() -> void:
	var fichero := FileAccess.open(RUTA, FileAccess.WRITE)
	if fichero == null:
		push_warning("[ColaOffline] No se pudo escribir %s" % RUTA)
		return
	fichero.store_string(JSON.stringify(cola))


func cargar() -> void:
	cola.clear()
	_indice_actual = -1
	if not FileAccess.file_exists(RUTA):
		return
	var texto := FileAccess.get_file_as_string(RUTA)
	var datos = JSON.parse_string(texto)
	if not datos is Array:
		return
	for elemento in datos:
		if not elemento is Dictionary:
			continue
		# Normalización: los elementos guardados por versiones anteriores
		# pueden no traer las claves nuevas.
		if not elemento.has("tabla"):
			elemento["tabla"] = ""
		if not elemento.has("payload"):
			elemento["payload"] = {}
		if not elemento.has("creado_localmente_ms"):
			elemento["creado_localmente_ms"] = 0
		if not elemento.has("reintentos"):
			elemento["reintentos"] = 0
		if not elemento.has("fallo_definitivo"):
			elemento["fallo_definitivo"] = false
		cola.append(elemento)
