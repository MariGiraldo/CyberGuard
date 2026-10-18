extends Control
## Menú principal de CyberGuard: Misión Ciberseguridad.

const TEMA_CIBER := preload("res://resources/temas/tema_ciberseguridad.tres")

## Verde neón corporativo
const VERDE_NEON := Color("#00FF66")
## Tamaño del botón: amplio respecto al texto para lucir como cápsula/cajoncito
const TAMANO_BOTON := Vector2(150, 28)

func _ready() -> void:
	# Aseguramos que la raíz ocupe todo el viewport
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	theme = TEMA_CIBER
	_construir()
	AudioManager.reproducir_musica()


func _obtener_textura_fondo() -> Texture2D:
	if EstilosUI.TEXTURA_FONDO_INICIO != null:
		return EstilosUI.TEXTURA_FONDO_INICIO
	
	var rutas := [
		"res://assets/imagenes/fondo_inicio.jpg",
		"res://assets/fondo_inicio.jpg",
		"res://codigo/game/assets/imagenes/fondo_inicio.jpg"
	]
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			return load(ruta) as Texture2D
	return null


func _construir() -> void:
	# 1) CAPA DE FONDO: TextureRect a pantalla completa
	var tex_fondo := _obtener_textura_fondo()
	if tex_fondo != null:
		var fondo := TextureRect.new()
		fondo.name = "Fondo"
		fondo.texture = tex_fondo
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(fondo)

	# Velo oscuro para contraste
	var velo := ColorRect.new()
	velo.name = "Velo"
	velo.color = Color(0.05, 0.08, 0.1, 0.45)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)

	# 2) CONTENEDOR CENTRADOR A PANTALLA COMPLETA
	var centro_pantalla := CenterContainer.new()
	centro_pantalla.name = "CentroPantalla"
	centro_pantalla.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro_pantalla)

	# 3) COLUMNA DE CONTENIDO CENTRADA
	var caja := VBoxContainer.new()
	caja.name = "ColumnaContenido"
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 3)
	centro_pantalla.add_child(caja)

	# Icono de bienvenida (welcome.png)
	var icono_bienvenida := EstilosUI.icono(EstilosUI.ICONO_WELCOME, Vector2(50, 26))
	icono_bienvenida.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(icono_bienvenida)

	var titulo := Label.new()
	titulo.text = "CyberGuard\nMisión Ciberseguridad"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", VERDE_NEON)
	titulo.add_theme_font_size_override("font_size", 9)
	caja.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Analiza, descifra y repara contra el reloj"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.add_theme_color_override("font_color", VERDE_NEON)
	subtitulo.add_theme_font_size_override("font_size", 6)
	caja.add_child(subtitulo)

	var separador := Control.new()
	separador.custom_minimum_size = Vector2(0, 3)
	caja.add_child(separador)

	# BOTÓN INICIAR MISIÓN
	var boton := Button.new()
	boton.text = "Iniciar misión"
	boton.custom_minimum_size = TAMANO_BOTON
	boton.add_theme_color_override("font_color", VERDE_NEON)
	boton.add_theme_font_size_override("font_size", 6)
	EstilosUI.aplicar_boton(boton)
	boton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/mapa/oficina.tscn")
	)
	caja.add_child(boton)

	# BOTÓN SALIR
	var boton_salir := Button.new()
	boton_salir.text = "Salir"
	boton_salir.custom_minimum_size = TAMANO_BOTON
	boton_salir.add_theme_color_override("font_color", VERDE_NEON)
	boton_salir.add_theme_font_size_override("font_size", 6)
	EstilosUI.aplicar_boton(boton_salir)
	boton_salir.pressed.connect(func() -> void: get_tree().quit())
	caja.add_child(boton_salir)

	# PIE INFORMATIVO CENTRADO ABAJO
	var aviso := Label.new()
	aviso.text = "Contenido 100% simulado con fines educativos.\nWASD/flechas para moverte · clic para caminar · E para interactuar."
	aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	aviso.offset_left = -150
	aviso.offset_right = 150
	aviso.offset_top = -22
	aviso.offset_bottom = -4
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_color_override("font_color", VERDE_NEON)
	aviso.add_theme_font_size_override("font_size", 5)
	add_child(aviso)

	if not Config.listo_para_red():
		var fila_aviso := HBoxContainer.new()
		fila_aviso.set_anchors_preset(Control.PRESET_TOP_WIDE)
		fila_aviso.offset_left = 4
		fila_aviso.offset_right = -4
		fila_aviso.offset_top = 2
		fila_aviso.offset_bottom = 10
		fila_aviso.alignment = BoxContainer.ALIGNMENT_CENTER
		fila_aviso.add_theme_constant_override("separation", 2)
		fila_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fila_aviso)

		var icono_aviso := EstilosUI.icono(EstilosUI.ICONO_WARNING, Vector2(8, 8))
		fila_aviso.add_child(icono_aviso)

		var aviso_red := Label.new()
		aviso_red.text = "Sin conexión a Supabase: la telemetría se guardará localmente."
		aviso_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso_red.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		aviso_red.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aviso_red.add_theme_color_override("font_color", VERDE_NEON)
		aviso_red.add_theme_font_size_override("font_size", 5)
		fila_aviso.add_child(aviso_red)