extends CharacterBody2D
class_name Analista
## Analista de seguridad: personaje controlado por el jugador (vista cenital).
## Movimiento con WASD/flechas + "clic para caminar" (Point & Click).
## El aspecto visual lo aporta el Sprite2D `Sprite` (assets/sprites/principal.png),
## escalado a 30×30 px para que resalte sobre `fondo_mapa.jpg` (≈1.9× su tamaño base).

const VELOCIDAD := 60.0
## Límites de la oficina ajustados al sprite de 30×30 px (medio sprite = 15 px):
## el personaje permanece siempre completo dentro del Viewport de 320×180 y por
## debajo de la barra del rótulo (0–18 px).
const LIMITE_MIN := Vector2(16, 33)
const LIMITE_MAX := Vector2(304, 165)

## Punto al que camina el jugador con el ratón (null = control con teclado).
var objetivo: Variant = null
## false mientras el jugador tiene una terminal abierta.
var controlable: bool = true

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("jugador")
	if _sprite.texture == null:
		# Fallback de seguridad si el asset no está disponible.
		_sprite.visible = false
		queue_redraw()

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
	# Volteamos el sprite según el sentido del desplazamiento horizontal.
	if direccion.x != 0.0:
		_sprite.flip_h = direccion.x < 0.0

func _draw() -> void:
	# Solo se dibuja el cuerpo de respaldo si falta la textura del sprite.
	if _sprite != null and _sprite.texture != null:
		return
	# Cuerpo (azul corporativo) — respaldo a la escala del sprite (30×30 px).
	draw_rect(Rect2(-10, -10, 20, 22), Color("2f6fb2"))
	# Cabeza
	draw_rect(Rect2(-6, -20, 12, 10), Color("e8c39e"))
	# Acento de chaleco reflectante (verde = "activo")
	draw_rect(Rect2(-10, 0, 20, 4), Color("4caf50"))
	# Ojos
	draw_rect(Rect2(-4, -16, 2, 2), Color("222222"))
	draw_rect(Rect2(2, -16, 2, 2), Color("222222"))
