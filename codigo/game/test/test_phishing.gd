extends SceneTree
## Pruebas headless de la lógica educativa (T33, walking skeleton).
## Ejecutar: godot --headless --path codigo/game --script res://test/test_phishing.gd
## Devuelve código de salida 0 si todo pasa, 1 si algo falla.

func _initialize() -> void:
	var fallos := 0

	var phishing := {"id": "p1", "phishing": true, "senal": "urgencia", "explicacion": "pressing"}
	var legitimo := {"id": "l1", "phishing": false, "senal": "", "explicacion": ""}

	# 1. Clasificación básica
	fallos += _comprobar(LogicaPhishing.clasificar(phishing, "PHISHING"), "phishing marcado como PHISHING")
	fallos += _comprobar(not LogicaPhishing.clasificar(phishing, "LEGITIMO"), "phishing no marcado como LEGITIMO")
	fallos += _comprobar(LogicaPhishing.clasificar(legitimo, "LEGITIMO"), "legítimo marcado como LEGÍTIMO")
	fallos += _comprobar(not LogicaPhishing.clasificar(legitimo, "PHISHING"), "legítimo no marcado como PHISHING")

	# 2. Señal educativa
	fallos += _comprobar(LogicaPhishing.senal_de(phishing) == "urgencia", "señal del correo phishing")
	fallos += _comprobar(LogicaPhishing.senal_de(legitimo) == "", "señal vacía en correo legítimo")

	# 3. Retroalimentación no vacía en los 4 casos
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(phishing, "PHISHING").is_empty(), "feedback acierto phishing")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(phishing, "LEGITIMO").is_empty(), "feedback fallo phishing")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(legitimo, "LEGITIMO").is_empty(), "feedback acierto legítimo")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(legitimo, "PHISHING").is_empty(), "feedback fallo legítimo")

	# 4. Evaluación de una lista completa
	var correos := [
		{"id": "c1", "phishing": true, "senal": "a", "explicacion": ""},
		{"id": "c2", "phishing": false, "senal": "", "explicacion": ""},
		{"id": "c3", "phishing": true, "senal": "b", "explicacion": ""},
	]
	var parcial := LogicaPhishing.evaluar(correos, {"c1": "PHISHING", "c2": "PHISHING"})
	fallos += _comprobar(parcial.get("aciertos") == 1 and parcial.get("errores") == 1, "evaluación parcial (1/1)")
	var perfecto := LogicaPhishing.evaluar(correos, {"c1": "PHISHING", "c2": "LEGITIMO", "c3": "PHISHING"})
	fallos += _comprobar(perfecto.get("aciertos") == 3 and perfecto.get("errores") == 0, "evaluación perfecta (3/0)")

	# 5. Datos del Nivel 1: 6 correos, exactamente 3 phishing
	var datos = JSON.parse_string(FileAccess.get_file_as_string("res://data/correos_nivel1.json"))
	var phishing_reales := 0
	if datos is Array:
		for correo in datos:
			if bool(correo.get("phishing", false)):
				phishing_reales += 1
		fallos += _comprobar(datos.size() == 6, "nivel 1 tiene 6 correos")
		fallos += _comprobar(phishing_reales == 3, "nivel 1 tiene 3 phishing")
		for correo in datos:
			fallos += _comprobar(not str(correo.get("senal", "")).is_empty() or not bool(correo.get("phishing", false)), "todo correo phishing tiene señal")
	else:
		fallos += 1
		_fallo("no se pudo leer res://data/correos_nivel1.json")

	if fallos == 0:
		print("OK — todas las comprobaciones de phishing pasaron")
	quit(1 if fallos > 0 else 0)


func _comprobar(condicion: bool, descripcion: String) -> int:
	if condicion:
		print("  ✓ " + descripcion)
		return 0
	_fallo(descripcion)
	return 1


func _fallo(descripcion: String) -> void:
	printerr("  ✗ FALLO: " + descripcion)
