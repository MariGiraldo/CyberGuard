extends Area2D
class_name TerminalTrabajo
## Terminal de trabajo interactiva de la empresa ficticia.
## Cada terminal abre un módulo: correos (phishing), cifrado (contraseñas)
## o servidores (vulnerabilidades).

signal activada(terminal: Node)

@export var titulo: String = "Terminal"
@export var tipo: String = "correos"  # correos | cifrado | servidores
## false = módulo aún no disponible (fuera del alcance actual).
@export var activa: bool = true

var _resaltado: bool = false

func _ready() -> void:
	add_to_group("terminales")
	input_pickable = true
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
	var color_base := Color("3c4a5a") if activa else Color("4a4a4a")
	var color_pantalla := Color("7ee081") if activa else Color("8a3b3b")
	# Monitor
	draw_rect(Rect2(-7, -12, 14, 10), Color("232a33"))
	draw_rect(Rect2(-5, -10, 10, 6), color_pantalla)
	# Base
	draw_rect(Rect2(-2, -2, 4, 3), color_base)
	draw_rect(Rect2(-6, 1, 12, 2), color_base)
	# Contenido simulado en pantalla
	draw_rect(Rect2(-4, -9, 8, 1), Color("cfe8cf") if activa else Color("666666"))
	draw_rect(Rect2(-4, -7, 5, 1), Color("cfe8cf") if activa else Color("666666"))
	# Resaltado al pasar el ratón (solo terminales activas)
	if _resaltado:
		var color_borde := Color("ffd54f") if activa else Color("9e9e9e")
		draw_rect(Rect2(-8, -13, 16, 16), color_borde, false, 1.0)
