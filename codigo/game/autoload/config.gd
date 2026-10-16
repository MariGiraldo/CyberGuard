extends Node
## Config: carga la configuración de Supabase en runtime.
##
## Regla dura (Contrato CyberGuard): los secretos NUNCA se versionan.
## Solo existen placeholders en `.env.example`. Los valores reales se leen de:
##   1. Variables de entorno del sistema.
##   2. `res://.env` (útil en editor; NO se versiona).
##   3. `user://.env` (útil en builds exportados).

var supabase_url: String = ""
var supabase_anon_key: String = ""

func _ready() -> void:
	supabase_url = _leer_valor("SUPABASE_URL")
	supabase_anon_key = _leer_valor("SUPABASE_ANON_KEY")
	if not listo_para_red():
		push_warning("[Config] Supabase sin configurar: la telemetría se guardará en cola local.")


## true si la conexión a Supabase está disponible.
func listo_para_red() -> bool:
	return not supabase_url.is_empty() and not supabase_anon_key.is_empty()


func _leer_valor(clave: String) -> String:
	var entorno := OS.get_environment(clave)
	if not entorno.is_empty():
		return entorno.strip_edges()
	for ruta in ["res://.env", "user://.env"]:
		var valor := _buscar_en_archivo(clave, ruta)
		if not valor.is_empty():
			return valor
	return ""


func _buscar_en_archivo(clave: String, ruta: String) -> String:
	if not FileAccess.file_exists(ruta):
		return ""
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return ""
	for linea in fichero.get_as_text().split("\n"):
		var trozo := linea.strip_edges()
		if trozo.is_empty() or trozo.begins_with("#"):
			continue
		if trozo.begins_with(clave + "="):
			return trozo.get_slice("=", 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""
