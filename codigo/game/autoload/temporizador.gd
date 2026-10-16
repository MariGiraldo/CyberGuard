extends Node
## Temporizador global de la partida: contra el reloj.
## Señales:
##   actualizado(restante_seg) — cada frame con los segundos restantes.
##   expirado() — cuando el tiempo se agota.

signal actualizado(restante_seg: int)
signal expirado()

var restante: float = 0.0
var corriendo: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue corriendo con la UI abierta


func iniciar(duracion_seg: int) -> void:
	restante = float(duracion_seg)
	corriendo = true
	actualizado.emit(duracion_seg)


func pausar() -> void:
	corriendo = false


func reanudar() -> void:
	corriendo = true


func detener() -> void:
	corriendo = false


## Segundos enteros restantes (para el HUD y el bonus de puntuación).
func segundos_restantes() -> int:
	return int(ceil(maxf(restante, 0.0)))


func _process(delta: float) -> void:
	if not corriendo:
		return
	restante -= delta
	actualizado.emit(segundos_restantes())
	if restante <= 0.0:
		restante = 0.0
		corriendo = false
		expirado.emit()
