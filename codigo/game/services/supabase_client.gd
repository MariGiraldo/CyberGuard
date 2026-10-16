extends HTTPRequest
class_name ClienteSupabase
## Cliente mínimo de Supabase por HTTP REST (sin SDK oficial de Godot).
##
## Contrato:
##   - Headers: `apikey` + `Authorization: Bearer <anon key>`.
##   - El cliente SOLO inserta (append-only): jamás UPDATE/DELETE.
##   - La `service_role` NUNCA llega al cliente.
##   - Si la petición falla, el evento se encola en `cola_offline.gd`.

signal insertado(tabla: String)
signal fallido(tabla: String, payload: Dictionary, codigo: int)
signal rpc_completada(funcion: String, exito: bool, cuerpo: String)

var _tabla_actual: String = ""
var _payload_actual: Dictionary = {}

func _ready() -> void:
	request_completed.connect(_on_peticion_completada)
	timeout = 10.0


## Inserta un registro en una tabla (solo INSERT, política append-only).
func insertar(tabla: String, payload: Dictionary) -> void:
	if not Config.listo_para_red():
		fallido.emit(tabla, payload, 0)
		return
	_tabla_actual = tabla
	_payload_actual = payload
	var headers := _headers()
	var url := "%s/rest/v1/%s" % [Config.supabase_url.rstrip("/"), tabla]
	var error := request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		fallido.emit(tabla, payload, 0)


## Llama a una RPC (por ejemplo `fn_finalizar_partida`).
func llamar_rpc(funcion: String, parametros: Dictionary) -> void:
	if not Config.listo_para_red():
		rpc_completada.emit(funcion, false, "")
		return
	_tabla_actual = "rpc/" + funcion
	_payload_actual = {}
	var headers := _headers()
	var url := "%s/rest/v1/rpc/%s" % [Config.supabase_url.rstrip("/"), funcion]
	var error := request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(parametros))
	if error != OK:
		rpc_completada.emit(funcion, false, "")


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + Config.supabase_anon_key,
		"Authorization: Bearer " + Config.supabase_anon_key,
		"Content-Type: application/json",
		"Prefer: return=minimal",
	])


func _on_peticion_completada(result: int, codigo: int, _headers: PackedStringArray, cuerpo: PackedByteArray) -> void:
	var exito := result == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300
	if _tabla_actual.begins_with("rpc/"):
		rpc_completada.emit(_tabla_actual.trim_prefix("rpc/"), exito, cuerpo.get_string_from_utf8())
	elif exito:
		insertado.emit(_tabla_actual)
	else:
		push_warning("[SupabaseClient] Fallo insertando en %s (código %d)" % [_tabla_actual, codigo])
		fallido.emit(_tabla_actual, _payload_actual, codigo)
