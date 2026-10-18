extends SceneTree
## Pruebas headless de la integración de assets multimedia (audio + imágenes).
## Ejecutar:
##   godot --headless --path codigo/game --script res://test/test_integracion_assets.gd
## Devuelve código de salida 0 si todo pasa, 1 si algo falla.
##
## Verifica:
##   1. Los ficheros de assets existen en sus rutas `res://`.
##   2. Las texturas y los streams de audio cargan correctamente.
##   3. AudioManager (autoload) reproduce la música en bucle y los efectos.
##   4. Las escenas integradas exponen los sprites/fondos esperados.

const RUTAS_TEXTURA := [
	"res://assets/sprites/principal.png",
	"res://assets/sprites/computadoras.png",
	"res://assets/ui/fondo_inicio.jpg",
	"res://assets/ui/fondo_mapa.jpg",
	"res://assets/ui/cuadro_fondo_tareas.jpg",
	"res://assets/ui/botones.png",
	"res://assets/ui/warning.png",
	"res://assets/ui/welcome.png",
]

const RUTAS_AUDIO := [
	"res://assets/sonidos/sonido_fondo.mp3",
	"res://assets/sonidos/correcto.mp3",
	"res://assets/sonidos/incorrecto.mp3",
]

var _fallos := 0

func _initialize() -> void:
	_ejecutar.call_deferred()


func _ejecutar() -> void:
	await process_frame
	await process_frame

	_comprobar_ficheros()
	_comprobar_texturas()
	_comprobar_audio()
	await _comprobar_audio_manager()
	await _comprobar_escenas()

	if _fallos == 0:
		print("OK — integración de assets multimedia validada")
	quit(1 if _fallos > 0 else 0)


func _comprobar_ficheros() -> void:
	print("— Ficheros de assets —")
	for ruta in RUTAS_TEXTURA + RUTAS_AUDIO:
		_comprobar(FileAccess.file_exists(ruta), "existe %s" % ruta)


func _comprobar_texturas() -> void:
	print("— Texturas —")
	for ruta in RUTAS_TEXTURA:
		var recurso = load(ruta)
		_comprobar(recurso is Texture2D, "textura carga %s" % ruta)


func _comprobar_audio() -> void:
	print("— Streams de audio —")
	for ruta in RUTAS_AUDIO:
		var recurso = load(ruta)
		_comprobar(recurso is AudioStream, "audio carga %s" % ruta)
	var musica = load("res://assets/sonidos/sonido_fondo.mp3")
	if musica is AudioStreamMP3:
		_componer_loop(musica as AudioStreamMP3)


func _componer_loop(musica: AudioStreamMP3) -> void:
	# El loop puede venir del .import o fijarse en runtime; validamos el import.
	var fichero := FileAccess.get_file_as_string("res://assets/sonidos/sonido_fondo.mp3.import")
	_comprobar(fichero.find("loop=true") >= 0, "sonido_fondo.mp3 importado con loop=true")


func _comprobar_audio_manager() -> void:
	print("— AudioManager (autoload) —")
	var gestor := root.get_node_or_null("AudioManager")
	if gestor == null:
		_fallo("AudioManager no está registrado como autoload")
		return
	gestor.reproducir_musica()
	await process_frame
	var musica: AudioStreamPlayer = gestor.get_node_or_null("MusicaFondo")
	_comprobar(musica != null, "AudioManager tiene MusicaFondo")
	if musica != null:
		_comprobar(musica.playing, "la música de fondo se reproduce al arrancar")
		_comprobar(musica.stream is AudioStreamMP3, "la música usa el MP3 de fondo")

	# Efectos de sonido: se disparan sobre el pool de reproductores.
	gestor.reproducir_correcto()
	await process_frame
	_comprobar(_hay_efecto_sonando(gestor), "efecto de acierto suena")
	gestor.reproducir_incorrecto()
	await process_frame
	_comprobar(_hay_efecto_sonando(gestor), "efecto de error suena")


func _hay_efecto_sonando(gestor: Node) -> bool:
	for hijo in gestor.get_children():
		if hijo is AudioStreamPlayer and hijo.name.begins_with("Efecto") and hijo.playing:
			return true
	return false


func _comprobar_escenas() -> void:
	print("— Escenas integradas —")
	# Jugador: usa principal.png
	var jugador := load("res://entities/jugador/jugador.tscn")
	if jugador is PackedScene:
		var nodo := (jugador as PackedScene).instantiate()
		var sprite := nodo.get_node_or_null("Sprite") as Sprite2D
		_comprobar(sprite != null and sprite.texture != null
			and sprite.texture.resource_path == "res://assets/sprites/principal.png",
			"jugador usa assets/sprites/principal.png")
		nodo.free()

	# Terminal: usa computadoras.png
	var terminal := load("res://entities/terminal/terminal.tscn")
	if terminal is PackedScene:
		var nodo := (terminal as PackedScene).instantiate()
		var sprite := nodo.get_node_or_null("Sprite") as Sprite2D
		_comprobar(sprite != null and sprite.texture != null
			and sprite.texture.resource_path == "res://assets/sprites/computadoras.png",
			"terminal usa assets/sprites/computadoras.png")
		nodo.free()

	# Menú principal: fondo_inicio.jpg presente como TextureRect.
	var menu := load("res://scenes/main/menu_principal.tscn")
	if menu is PackedScene:
		var nodo := (menu as PackedScene).instantiate()
		root.add_child(nodo)  # dispara _ready() y construye la UI
		await process_frame
		_comprobar(_contiene_textura(nodo, "res://assets/ui/fondo_inicio.jpg"),
			"menú principal usa assets/ui/fondo_inicio.jpg")
		_comprobar(_contiene_textura(nodo, "res://assets/ui/welcome.png"),
			"menú principal incluye el icono welcome.png")
		nodo.queue_free()

	# Oficina: fondo_mapa.jpg se añade como Sprite2D en _ready.
	var oficina := load("res://scenes/mapa/oficina.tscn")
	if oficina is PackedScene:
		var nodo := (oficina as PackedScene).instantiate()
		root.add_child(nodo)  # dispara _ready() y añade FondoMapa
		await process_frame
		var fondo := nodo.get_node_or_null("FondoMapa") as Sprite2D
		_comprobar(fondo != null and fondo.texture != null
			and fondo.texture.resource_path == "res://assets/ui/fondo_mapa.jpg",
			"oficina usa assets/ui/fondo_mapa.jpg como fondo")
		nodo.queue_free()
	# Terminal de correos: cuadro_fondo_tareas.jpg + warning.png.
	var correos := load("res://scenes/terminales/terminal_correos.tscn")
	if correos is PackedScene:
		var nodo := (correos as PackedScene).instantiate()
		root.add_child(nodo)  # dispara _ready() y construye la UI
		await process_frame
		_comprobar(_contiene_textura(nodo, "res://assets/ui/cuadro_fondo_tareas.jpg"),
			"terminal de correos usa assets/ui/cuadro_fondo_tareas.jpg")
		_comprobar(_contiene_textura(nodo, "res://assets/ui/warning.png"),
			"terminal de correos incluye el icono warning.png")
		nodo.queue_free()
	await process_frame


## Recorre el árbol buscando una textura con la ruta indicada.
func _contiene_textura(raiz: Node, ruta: String) -> bool:
	var textura: Texture2D = null
	if raiz is TextureRect:
		textura = (raiz as TextureRect).texture
	elif raiz is Sprite2D:
		textura = (raiz as Sprite2D).texture
	if textura != null and textura.resource_path == ruta:
		return true
	for hijo in raiz.get_children():
		if _contiene_textura(hijo, ruta):
			return true
	return false


func _comprobar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("  ✓ " + descripcion)
	else:
		_fallo(descripcion)


func _fallo(descripcion: String) -> void:
	_fallos += 1
	printerr("  ✗ FALLO: " + descripcion)
