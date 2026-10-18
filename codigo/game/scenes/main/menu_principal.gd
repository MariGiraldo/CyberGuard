extends Control
## Menú principal de CyberGuard: Misión Ciberseguridad.

const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")
const URL_INFORME := "https://datastudio.google.com/embed/reporting/0b1ae01d-6376-4ac4-ae22-a374cb3afa2e/page/D1WBG"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = TEMA_CIBER
	_construir()


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("#1A1D24")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 6)
	margen.add_theme_constant_override("margin_right", 6)
	margen.add_theme_constant_override("margin_top", 6)
	margen.add_theme_constant_override("margin_bottom", 6)
	add_child(margen)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 2)
	margen.add_child(caja)

	var titulo := Label.new()
	titulo.text = "CyberGuard\nMisión Ciberseguridad"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("4fc3f7"))
	titulo.add_theme_font_size_override("font_size", 8)
	caja.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Analiza, descifra y repara contra el reloj"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.add_theme_color_override("font_color", Color("9fb3c8"))
	subtitulo.add_theme_font_size_override("font_size", 6)
	caja.add_child(subtitulo)

	var separador := Control.new()
	separador.custom_minimum_size = Vector2(0, 2)
	caja.add_child(separador)

	var boton := Button.new()
	boton.text = "Iniciar misión"
	boton.custom_minimum_size = Vector2(110, 14)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/mapa/oficina.tscn")
	)
	caja.add_child(boton)

	var boton_informe := Button.new()
	boton_informe.text = "Ver informe"
	boton_informe.custom_minimum_size = Vector2(110, 14)
	boton_informe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton_informe.pressed.connect(func() -> void: OS.shell_open(URL_INFORME))
	caja.add_child(boton_informe)

	var boton_salir := Button.new()
	boton_salir.text = "Salir"
	boton_salir.custom_minimum_size = Vector2(110, 14)
	boton_salir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton_salir.pressed.connect(func() -> void: get_tree().quit())
	caja.add_child(boton_salir)

	var aviso := Label.new()
	aviso.text = "Contenido 100% simulado con fines educativos.\nWASD/flechas para moverte · clic para caminar · E para interactuar."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_color_override("font_color", Color("6b7c8f"))
	aviso.add_theme_font_size_override("font_size", 6)
	aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	aviso.offset_left = 6
	aviso.offset_right = -6
	aviso.offset_top = -20
	aviso.offset_bottom = -4
	add_child(aviso)

	if not Config.listo_para_red():
		var aviso_red := Label.new()
		aviso_red.text = "Sin conexión a Supabase: la telemetría se guardará localmente."
		aviso_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso_red.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso_red.add_theme_color_override("font_color", Color("ffb74d"))
		aviso_red.add_theme_font_size_override("font_size", 6)
		aviso_red.set_anchors_preset(Control.PRESET_TOP_WIDE)
		aviso_red.offset_left = 4
		aviso_red.offset_right = -4
		aviso_red.offset_top = 2
		aviso_red.offset_bottom = 10
		add_child(aviso_red)
