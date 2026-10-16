extends RefCounted
class_name ColaOffline
## Cola offline de telemetría.
##
## Si la red falla (o Supabase no está configurado), los eventos se guardan en
## `user://cola_eventos.json` y se drenan en orden cuando vuelve la conexión.
## Se conserva el orden: primero jugadores → partidas → eventos.

const RUTA := "user://cola_eventos.json"

var cola: Array = []

func _init() -> void:
	cargar()


## Encola un registro pendiente de envío.
func encolar(tabla: String, payload: Dictionary) -> void:
	cola.append({"tabla": tabla, "payload": payload})
	guardar()


## Extrae el primer registro pendiente (null si la cola está vacía).
func siguiente() -> Dictionary:
	if cola.is_empty():
		return {}
	var elemento: Dictionary = cola[0]
	return elemento


## Elimina el primer registro (ya enviado correctamente).
func quitar_primero() -> void:
	if not cola.is_empty():
		cola.remove_at(0)
		guardar()


func vacia() -> bool:
	return cola.is_empty()


func guardar() -> void:
	var fichero := FileAccess.open(RUTA, FileAccess.WRITE)
	if fichero == null:
		push_warning("[ColaOffline] No se pudo escribir %s" % RUTA)
		return
	fichero.store_string(JSON.stringify(cola))


func cargar() -> void:
	cola.clear()
	if not FileAccess.file_exists(RUTA):
		return
	var texto := FileAccess.get_file_as_string(RUTA)
	var datos = JSON.parse_string(texto)
	if datos is Array:
		cola = datos
