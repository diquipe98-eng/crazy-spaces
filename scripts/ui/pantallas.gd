extends Control
## Pantallas superpuestas a la partida: elegir mejora, pausa (con ajustes) y fin.

var juego
var _capa_mejora: Control
var _capa_pausa: Control
var _capa_fin: Control
var _tarjetas: HBoxContainer
var _titulo_mejora := ""
var _boton_reroll: Boton
var _boton_reparar: Boton
var _datos_fin := {}
var _estado := ""
var tutorial: Tutorial
var estado_red := ""   ## línea de la tabla global en la pantalla de fin

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	juego = get_parent().get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_mejora()
	_construir_pausa()
	_construir_fin()
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.cerrado.connect(func(): juego._tutorial_cerrado())
	mostrar("jugando")

func _capa() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	return c

func _columna(c: Control, separacion := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", separacion)
	c.add_child(v)
	return v

func _fila(padre: Control, separacion := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", separacion)
	padre.add_child(h)
	return h

func _boton(padre: Control, texto: String, color: Color, ancho := 150.0, alto := 30.0) -> Boton:
	var b := Boton.new(texto, color, 9)
	b.custom_minimum_size = Vector2(ancho, alto)
	padre.add_child(b)
	return b

func _espacio(padre: Control, alto: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, alto)
	padre.add_child(s)

# ------------------------------------------------------------------ mejora
func _construir_mejora() -> void:
	_capa_mejora = _capa()
	var v := _columna(_capa_mejora, 10)
	_espacio(v, 34)
	_tarjetas = _fila(v, 10)
	var f := _fila(v, 10)
	_boton_reroll = _boton(f, "REROLL", Color("c58cff"), 140, 30)
	_boton_reroll.icono = Datos.tex("res://art/hud/gear.png")
	_boton_reroll.pulsado.connect(func(): juego.reroll(); _refrescar_mejora())
	_boton_reparar = _boton(f, "REPARAR", Color("7dff9b"), 140, 30)
	_boton_reparar.icono = Datos.tex("res://art/hud/heart.png")
	_boton_reparar.pulsado.connect(func(): juego.reparar(); _refrescar_mejora())

func preparar_mejoras(opciones: Array, es_jefe: bool) -> void:
	_titulo_mejora = "¡RECOMPENSA DE JEFE!" if es_jefe else "¡SUBISTE DE NIVEL!"
	for c in _tarjetas.get_children():
		c.queue_free()
	var t := get_viewport_rect().size
	var ancho := clampf((t.x - 60.0) / 3.0, 120.0, 168.0)
	for i in opciones.size():
		var m: Dictionary = opciones[i]
		var tj := Tarjeta.new("", Datos.RAREZAS[int(m.rar)].color)
		tj.mejora = m
		tj.nivel_actual = int(juego.mejoras_tomadas.get(m.id, 0))
		tj.efecto = juego.N.texto_mejora(m.id)
		tj.custom_minimum_size = Vector2(ancho, min(168.0, t.y - 130.0))
		tj.entrada = -i * 0.25
		tj.pulsado.connect(func(): juego.elegir_mejora(m.id))
		_tarjetas.add_child(tj)
	if opciones.is_empty():
		juego.elegir_mejora("overclock")
		return
	_refrescar_mejora()
	await get_tree().process_frame
	enfocar_mejora()

func enfocar_mejora() -> void:
	if _tarjetas.get_child_count() > 0 and not Ajustes.es_tactil() and not tutorial.abierto():
		_tarjetas.get_child(0).grab_focus()

func _refrescar_mejora() -> void:
	_boton_reroll.subtexto = "%d CHATARRA" % juego.costo_reroll
	_boton_reroll.desactivado = juego.chatarra < juego.costo_reroll
	_boton_reparar.subtexto = "+1 VIDA · %d" % juego.costo_reparar if juego.N.vida < juego.N.vida_max else "VIDA LLENA"
	_boton_reparar.desactivado = not juego.puede_reparar()
	_boton_reroll.queue_redraw()
	_boton_reparar.queue_redraw()
	queue_redraw()

# ------------------------------------------------------------------ pausa
func _construir_pausa() -> void:
	_capa_pausa = _capa()
	var v := _columna(_capa_pausa, 10)
	_espacio(v, 30)
	var panel := PanelAjustes.new()
	var centro := CenterContainer.new()
	centro.add_child(panel)
	v.add_child(centro)
	var f := _fila(v, 10)
	_boton(f, "CONTINUAR", Color("5ad1ff")).pulsado.connect(func(): juego.continuar())
	_boton(f, "REINICIAR", Color("ffb65c")).pulsado.connect(func(): juego.nueva_partida())
	_boton(f, "MENÚ", Color("ff7892")).pulsado.connect(func(): juego.ir_al_menu())

# ------------------------------------------------------------------ fin
func _construir_fin() -> void:
	_capa_fin = _capa()
	var v := _columna(_capa_fin, 10)
	_espacio(v, 150)
	var f := _fila(v, 10)
	_boton(f, "OTRA VEZ", Color("5ad1ff"), 160, 34).pulsado.connect(func(): juego.nueva_partida())
	_boton(f, "MENÚ", Color("ff7892"), 160, 34).pulsado.connect(func(): juego.ir_al_menu())
	if Datos.URL_DONACIONES != "":
		var apoyar := _boton(v, "APOYA EL JUEGO", Color("ff7aa8"), 180, 24)
		apoyar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		apoyar.icono = Datos.tex("res://art/hud/heart.png")
		apoyar.pulsado.connect(Datos.abrir_donaciones)

func preparar_fin(record: bool) -> void:
	_datos_fin = {"record": record}
	estado_red = ""

# ------------------------------------------------------------------ común
func mostrar(estado: String) -> void:
	_estado = estado
	_capa_mejora.visible = estado == "mejora"
	_capa_pausa.visible = estado == "pausa"
	_capa_fin.visible = estado == "fin"
	if estado == "pausa" and not Ajustes.es_tactil():
		await get_tree().process_frame
		var bs := _capa_pausa.find_children("*", "Boton", true, false)
		if bs.size() > 0:
			bs[-3].grab_focus()
	queue_redraw()

func _process(_d: float) -> void:
	if _estado != "jugando":
		queue_redraw()

func _draw() -> void:
	if _estado == "jugando" or _estado == "tutorial" or juego == null:
		return
	var t := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.02, 0.02, 0.07, 0.72))
	var cx := t.x * 0.5
	match _estado:
		"mejora":
			Texto.dibujar(self, Vector2(cx, 30), _titulo_mejora, 14, Color("ffe36b"), HORIZONTAL_ALIGNMENT_CENTER)
			Texto.dibujar(self, Vector2(cx, 44), "ELIGE UNA MEJORA · NV %d" % juego.nivel, 7, Color(0.8, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
			Texto.dibujar(self, Vector2(t.x - 12, 20), "%d" % juego.chatarra, 9, Color("ffd34d"), HORIZONTAL_ALIGNMENT_RIGHT)
			draw_texture_rect(Datos.tex("res://art/hud/gear.png"), Rect2(t.x - 16 - Texto.ancho("%d" % juego.chatarra, 9) - 14, 9, 12, 12), false)
		"pausa":
			Texto.dibujar(self, Vector2(cx, 34), "PAUSA", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		"fin":
			var y := t.y * 0.5 - 92
			Texto.dibujar(self, Vector2(cx, y), "NAVE DESTRUIDA", 18, Color("ff647b"), HORIZONTAL_ALIGNMENT_CENTER)
			if _datos_fin.get("record", false):
				Texto.dibujar(self, Vector2(cx, y + 20), "¡NUEVO RÉCORD!", 10, Color("ffe36b").lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)), HORIZONTAL_ALIGNMENT_CENTER)
			var filas := [
				["PUNTAJE", "%d" % juego.puntaje], ["TIEMPO", Progreso.formato_tiempo(juego.tiempo)],
				["NIVEL", "%d" % juego.nivel], ["BAJAS", "%d" % juego.bajas], ["JEFES", "%d" % juego.jefes_derrotados],
				["MEJOR", "%d" % Progreso.mejor_puntaje],
			]
			for i in filas.size():
				var yy := y + 44 + i * 14
				Texto.dibujar(self, Vector2(cx - 8, yy), filas[i][0], 8, Color(0.7, 0.8, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
				Texto.dibujar(self, Vector2(cx + 8, yy), filas[i][1], 8, Color.WHITE)
			if estado_red != "":
				var dorado := "TOP 10" in estado_red or "PUESTO" in estado_red
				Texto.dibujar(self, Vector2(cx, y + 44 + filas.size() * 14 + 4), estado_red, 7, Color("ffd23a") if dorado else Color(0.7, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
