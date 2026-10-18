extends SceneTree
## Pruebas headless de la lógica educativa (T33, walking skeleton).
## Ejecutar: godot --headless --path codigo/game --script res://test/test_phishing.gd
## Devuelve código de salida 0 si todo pasa, 1 si algo falla.
##
## Además de la lógica, valida el contenido de data/correos_nivel1.json contra
## el esquema canónico y las invariantes del skill cybersecurity-content-validator.

const RUTA_CORREOS := "res://data/correos_nivel1.json"
const SENALES_FISICAS := [
	"dominio_sospechoso", "urgencia", "error_url", "adjunto_inesperado",
	"suplantacion_marca", "saludo_generico",
]

func _initialize() -> void:
	var fallos := 0

	var phishing := {"id": "p1", "es_phishing": true, "senal_clave": "urgencia", "feedback_acierto": "ok", "feedback_error": "no"}
	var legitimo := {"id": "l1", "es_phishing": false, "senal_clave": "sin_senales"}

	# 1. Clasificación básica
	fallos += _comprobar(LogicaPhishing.clasificar(phishing, "PHISHING"), "phishing marcado como PHISHING")
	fallos += _comprobar(not LogicaPhishing.clasificar(phishing, "LEGITIMO"), "phishing no marcado como LEGITIMO")
	fallos += _comprobar(LogicaPhishing.clasificar(legitimo, "LEGITIMO"), "legítimo marcado como LEGÍTIMO")
	fallos += _comprobar(not LogicaPhishing.clasificar(legitimo, "PHISHING"), "legítimo no marcado como PHISHING")

	# 2. Señal educativa (vocabulario §7; legítimo ⇒ sin_senales)
	fallos += _comprobar(LogicaPhishing.senal_de(phishing) == "urgencia", "señal del correo phishing")
	fallos += _comprobar(LogicaPhishing.senal_de(legitimo) == "sin_senales", "señal sin_senales en correo legítimo")
	fallos += _comprobar(LogicaPhishing.senal_de({}) == "sin_senales", "señal por defecto sin_senales")

	# 3. Retroalimentación no vacía en los 4 casos
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(phishing, "PHISHING").is_empty(), "feedback acierto phishing")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(phishing, "LEGITIMO").is_empty(), "feedback fallo phishing")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(legitimo, "LEGITIMO").is_empty(), "feedback acierto legítimo")
	fallos += _comprobar(not LogicaPhishing.retroalimentacion(legitimo, "PHISHING").is_empty(), "feedback fallo legítimo")

	# 4. Evaluación de una lista completa
	var correos := [
		{"id": "c1", "es_phishing": true, "senal_clave": "urgencia"},
		{"id": "c2", "es_phishing": false, "senal_clave": "sin_senales"},
		{"id": "c3", "es_phishing": true, "senal_clave": "error_url"},
	]
	var parcial := LogicaPhishing.evaluar(correos, {"c1": "PHISHING", "c2": "PHISHING"})
	fallos += _comprobar(parcial.get("aciertos") == 1 and parcial.get("errores") == 1, "evaluación parcial (1/1)")
	var perfecto := LogicaPhishing.evaluar(correos, {"c1": "PHISHING", "c2": "LEGITIMO", "c3": "PHISHING"})
	fallos += _comprobar(perfecto.get("aciertos") == 3 and perfecto.get("errores") == 0, "evaluación perfecta (3/0)")

	# 5. Contenido del Nivel 1: esquema canónico + invariantes NO PII
	fallos += _validar_correos()

	if fallos == 0:
		print("OK — todas las comprobaciones de phishing pasaron")
	quit(1 if fallos > 0 else 0)


## Valida el JSON canónico contra doc/diseno/01-misiones.md §5 y el skill
## cybersecurity-content-validator (esquema, invariantes y dominios .invalid).
func _validar_correos() -> int:
	var fallos := 0
	if not FileAccess.file_exists(RUTA_CORREOS):
		_fallo("no se pudo leer %s" % RUTA_CORREOS)
		return 1
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CORREOS))
	var lista: Array = []
	if datos is Dictionary and datos.get("correos") is Array:
		lista = datos.get("correos")
	elif datos is Array:
		lista = datos
	else:
		_fallo("estructura de correos_nivel1.json no reconocida")
		return 1

	fallos += _comprobar(lista.size() == 6, "nivel 1 tiene 6 correos")
	var phishing_reales := 0
	var ids_vistos := {}
	for correo in lista:
		var id := str(correo.get("id", ""))
		var esperado := bool(correo.get("es_phishing", false))
		var senal := str(correo.get("senal_clave", ""))
		if esperado:
			phishing_reales += 1
			fallos += _comprobar(
				SENALES_FISICAS.has(senal),
				"correo %s phishing con señal del vocabulario §7" % id)
		else:
			fallos += _comprobar(senal == "sin_senales",
				"correo %s legítimo ⇒ senal_clave=sin_senales" % id)
		# Invariante 3: enlace_texto y enlace_url son ambos null o ambos no-null.
		var tiene_texto: bool = correo.get("enlace_texto", null) != null
		var tiene_url: bool = correo.get("enlace_url", null) != null
		fallos += _comprobar(tiene_texto == tiene_url, "correo %s: enlace_texto y enlace_url coherentes" % id)
		# Invariante 4: remitente y enlace bajo `.invalid` (sin PII ni dominios reales).
		fallos += _comprobar(str(correo.get("remitente", "")).ends_with(".invalid"),
			"correo %s: remitente .invalid" % id)
		if tiene_url:
			fallos += _comprobar(str(correo.get("enlace_url", "")).find(".invalid") >= 0,
				"correo %s: enlace_url .invalid" % id)
		ids_vistos[id] = true
		fallos += _comprobar(
			correo.get("feedback_acierto", "") != "" and correo.get("feedback_error", "") != "",
			"correo %s: feedback educativo presente" % id)
	fallos += _comprobar(phishing_reales == 3, "nivel 1 tiene 3 phishing")
	fallos += _comprobar(ids_vistos.size() == lista.size(), "ids de correo únicos")
	return fallos


func _comprobar(condicion: bool, descripcion: String) -> int:
	if condicion:
		print("  ✓ " + descripcion)
		return 0
	_fallo(descripcion)
	return 1


func _fallo(descripcion: String) -> void:
	printerr("  ✗ FALLO: " + descripcion)
