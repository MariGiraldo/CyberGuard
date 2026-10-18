extends Area2D
class_name TerminalTrabajo
## Terminal de trabajo interactiva de la empresa ficticia.
## Cada terminal abre un módulo: correos (phishing), cifrado (contraseñas)
## o servidores (vulnerabilidades). El sprite usa assets/sprites/computadoras.png.

signal activada(terminal: Node)

@export var titulo: String = "Terminal"
@export var tipo: String = "correos"  # correos | cifrado | servidores
## false = módulo aún no disponible (fuera del alcance actual).
@export var activa: bool = true

var _resaltado: bool = false

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	add_to_group("terminales")
	input_pickable = true
	if _sprite.texture == null:
		_sprite.visible = false
	else:
		# Estado inactivo: atenuamos el sprite (además del texto del prompt).
		_sprite.modulate = Color(1, 1, 1) if activa else Color(0.55, 0.55, 0.6)
	queue_redraw()
	mouse_entered.connect(func() -> void:
		_resaltado = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_resaltado = false
		queue_redraw()
	)
	input_event.connect(_al_recibir_clic)


func _al_recibir_clic(_viewport: Node, event: InputEvent, _indice: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activada.emit(self)


func _draw() -> void:
	# Solo dibujamos el resaltado de interacción; el sprite aporta el aspecto.
	if _sprite == null or _sprite.texture == null:
		# Fallback procedural si falta la textura (monitor dibujado a 30×30 px).
		var color_base := Color("3c4a5a") if activa else Color("4a4a4a")
		var color_pantalla := Color("7ee081") if activa else Color("8a3b3b")
		draw_rect(Rect2(-14, -24, 28, 20), Color("232a33"))
		draw_rect(Rect2(-10, -20, 20, 12), color_pantalla)
		draw_rect(Rect2(-4, -4, 8, 6), color_base)
		draw_rect(Rect2(-12, 2, 24, 4), color_base)
		draw_rect(Rect2(-8, -18, 16, 2), Color("cfe8cf") if activa else Color("666666"))
		draw_rect(Rect2(-8, -14, 10, 2), Color("cfe8cf") if activa else Color("666666"))
	# Resaltado al pasar el ratón (contorno alrededor del sprite de 30×30 px).
	if _resaltado:
		var color_borde := Color("ffd54f") if activa else Color("9e9e9e")
		draw_rect(Rect2(-16, -16, 32, 32), color_borde, false, 1.0)
