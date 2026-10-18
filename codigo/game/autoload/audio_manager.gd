extends Node
## AudioManager (autoload): música de fondo en bucle y efectos de sonido.
##
## - `sonido_fondo.mp3` se reproduce en loop desde el menú principal y la Oficina
##   (el nodo es autoload, así que la música persiste entre escenas).
## - `correcto.mp3` / `incorrecto.mp3` se disparan al clasificar amenazas/correos.
## Los efectos usan un pequeño pool de AudioStreamPlayer para poder solaparse.

const RUTA_MUSICA := "res://assets/sonidos/sonido_fondo.mp3"
const RUTA_CORRECTO := "res://assets/sonidos/correcto.mp3"
const RUTA_INCORRECTO := "res://assets/sonidos/incorrecto.mp3"

## Número de reproductores simultáneos para efectos de sonido.
const POOL_EFECTOS := 3

var _musica: AudioStreamPlayer
var _efectos: Array[AudioStreamPlayer] = []

func _ready() -> void:
	# La música y los efectos suenan aunque se pause el árbol (menús, modales).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_musica = AudioStreamPlayer.new()
	_musica.name = "MusicaFondo"
	_musica.volume_db = -8.0
	add_child(_musica)
	var stream_musica := load(RUTA_MUSICA)
	if stream_musica is AudioStreamMP3:
		# Loop en runtime (refuerza el import; el editor lo deja en bool).
		(stream_musica as AudioStreamMP3).loop = true
	_musica.stream = stream_musica

	for i in POOL_EFECTOS:
		var reproductor := AudioStreamPlayer.new()
		reproductor.name = "Efecto%d" % i
		reproductor.volume_db = -2.0
		add_child(reproductor)
		_efectos.append(reproductor)


## Inicia la música de fondo si no está sonando (idempotente entre escenas).
func reproducir_musica() -> void:
	if _musica == null or _musica.stream == null or _musica.playing:
		return
	_musica.play()


## Detiene la música de fondo (por si una escena la silencia).
func detener_musica() -> void:
	if _musica != null:
		_musica.stop()


## Efecto de acierto: suena al clasificar correctamente una amenaza/correo.
func reproducir_correcto() -> void:
	_reproducir_efecto(RUTA_CORRECTO)


## Efecto de error: suena al clasificar incorrectamente.
func reproducir_incorrecto() -> void:
	_reproducir_efecto(RUTA_INCORRECTO)


func _reproducir_efecto(ruta: String) -> void:
	var stream := load(ruta)
	if stream == null:
		push_warning("[AudioManager] No se pudo cargar %s" % ruta)
		return
	for reproductor in _efectos:
		if not reproductor.playing:
			reproductor.stream = stream
			reproductor.play()
			return
	# Pool ocupado: reutilizamos el primero (el efecto se solapa, no se acumula).
	_efectos[0].stream = stream
	_efectos[0].play()
