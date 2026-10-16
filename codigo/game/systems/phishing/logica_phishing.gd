class_name LogicaPhishing
## Lógica pura del Módulo A: clasificación de correos y señales de phishing.
## Sin dependencias de escena: testeable de forma aislada (tarea T33).


## Devuelve true si la decisión del jugador es correcta.
## `decision` debe ser "PHISHING" o "LEGITIMO".
static func clasificar(correo: Dictionary, decision: String) -> bool:
	var es_phishing := bool(correo.get("phishing", false))
	if es_phishing:
		return decision == "PHISHING"
	return decision == "LEGITIMO"


## Señal educativa asociada al correo (vacío si es legítimo).
static func senal_de(correo: Dictionary) -> String:
	return str(correo.get("senal", ""))


## Texto de retroalimentación para el jugador.
static func retroalimentacion(correo: Dictionary, decision: String) -> String:
	var correcto := clasificar(correo, decision)
	if correcto and bool(correo.get("phishing", false)):
		return "¡Correcto! Era phishing. Señal detectada: %s.\n%s" % [
			senal_de(correo), str(correo.get("explicacion", ""))
		]
	if correcto:
		return "¡Correcto! El correo es legítimo: remitente oficial verificado."
	if bool(correo.get("phishing", false)):
		return "Cuidado: era phishing y pasó desapercibido.\n%s" % str(correo.get("explicacion", ""))
	return "Error: ese correo era legítimo.\nRevisa el remitente y el contexto antes de marcarlo como amenaza."


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
