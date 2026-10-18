class_name LogicaPhishing
## Lógica pura del Módulo A: clasificación de correos y señales de phishing.
## Sin dependencias de escena: testeable de forma aislada (tarea T33).
##
## Usa las claves canónicas del JSON de correos (doc/diseno/01-misiones.md §5
## + skill cybersecurity-content-validator): `es_phishing`, `senal_clave`,
## `senal_secundaria`, `feedback_acierto`, `feedback_error`.

## Vocabulario controlado de señales (modelo de dominio §7).
const SENALES_VALIDAS: Array[String] = [
	"dominio_sospechoso", "urgencia", "error_url", "adjunto_inesperado",
	"suplantacion_marca", "saludo_generico", "sin_senales",
]


## Devuelve true si el correo es phishing según su respuesta esperada.
static func es_phishing(correo: Dictionary) -> bool:
	return bool(correo.get("es_phishing", false))


## Devuelve true si la decisión del jugador es correcta.
## `decision` debe ser "PHISHING" o "LEGITIMO".
static func clasificar(correo: Dictionary, decision: String) -> bool:
	if es_phishing(correo):
		return decision == "PHISHING"
	return decision == "LEGITIMO"


## Señal clave del correo (vocabulario §7). Los correos legítimos siempre
## llevan `sin_senales`; nunca se envía una cadena vacía.
static func senal_de(correo: Dictionary) -> String:
	var senal := str(correo.get("senal_clave", "")).strip_edges()
	if senal.is_empty() or not SENALES_VALIDAS.has(senal):
		return "sin_senales"
	return senal


## Texto de retroalimentación para el jugador (feedback educativo del JSON,
## con respaldo genérico si el correo no lo trae).
static func retroalimentacion(correo: Dictionary, decision: String) -> String:
	var correcto := clasificar(correo, decision)
	if correcto:
		var acierto := str(correo.get("feedback_acierto", "")).strip_edges()
		if not acierto.is_empty():
			return acierto
		if es_phishing(correo):
			return "¡Correcto! Era phishing. Señal detectada: %s." % senal_de(correo)
		return "¡Correcto! El correo es legítimo: remitente oficial verificado."
	var error := str(correo.get("feedback_error", "")).strip_edges()
	if not error.is_empty():
		return error
	if es_phishing(correo):
		return "Cuidado: era phishing y pasó desapercibido. Fíjate en el remitente, la URL real y los adjuntos."
	return "Error: ese correo era legítimo. Revisa el remitente y el contexto antes de marcarlo como amenaza."


## Clasifica una lista de correos (para pruebas automáticas).
## Devuelve {"aciertos": int, "errores": int}.
static func evaluar(correos: Array, decisiones: Dictionary) -> Dictionary:
	var aciertos := 0
	var errores := 0
	for correo in correos:
		var id := str(correo.get("id", ""))
		if not decisiones.has(id):
			continue
		if clasificar(correo, str(decisiones[id])):
			aciertos += 1
		else:
			errores += 1
	return {"aciertos": aciertos, "errores": errores}
