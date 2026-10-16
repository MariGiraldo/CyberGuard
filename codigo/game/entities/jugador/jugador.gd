extends CharacterBody2D
class_name Analista
## Analista de seguridad: personaje controlado por el jugador (vista cenital).
## Movimiento con WASD/flechas + "clic para caminar" (Point & Click).

const VELOCIDAD := 60.0
const LIMITE_MIN := Vector2(10, 20)
const LIMITE_MAX := Vector2(310, 170)

## Punto al que camina el jugador con el ratón (null = control con teclado).
var objetivo: Variant = null
## false mientras el jugador tiene una terminal abierta.
var controlable: bool = true

func _ready() -> void:
	add_to_group("jugador")

func _physics_process(_delta: float) -> void:
	var direccion := Vector2.ZERO
	if controlable:
		direccion = Input.get_vector(
			"mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo"
		)
		if direccion == Vector2.ZERO and objetivo != null:
			var desplazamiento: Vector2 = (objetivo as Vector2) - position
			if desplazamiento.length() < 3.0:
				objetivo = null
			else:
				direccion = desplazamiento.normalized()
	velocity = direccion * VELOCIDAD
	move_and_slide()
	# Pixel-perfect: redondeamos la posición y respetamos los límites de la oficina.
	position = position.round().clamp(LIMITE_MIN, LIMITE_MAX)
	queue_redraw()

func _draw() -> void:
	# Cuerpo (azul corporativo)
	draw_rect(Rect2(-5, -5, 10, 11), Color("2f6fb2"))
	# Cabeza
	draw_rect(Rect2(-3, -10, 6, 5), Color("e8c39e"))
	# Acento de chaleco reflectante (verde = "activo")
	draw_rect(Rect2(-5, 0, 10, 2), Color("4caf50"))
	# Ojos
	draw_rect(Rect2(-2, -8, 1, 1), Color("222222"))
	draw_rect(Rect2(1, -8, 1, 1), Color("222222"))
