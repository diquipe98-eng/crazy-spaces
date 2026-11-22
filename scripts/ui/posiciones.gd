class_name Posiciones
extends Control
## MARCADORES (vista del menú):
##   izquierda: TODOS LOS PILOTOS registrados, por páginas de 10 (tocar uno abre su
##              perfil; < > o la rueda / deslizar cambian de página; MI PUESTO salta a tu página).
##              Pestaña MIS RÉCORDS: las mejores partidas de este equipo.
##   derecha:   tarjeta de cuenta (crear piloto / entrar / mi perfil / cerrar sesión).

signal volver

const POR_PAGINA := 10

var _pestana := "global"        ## global | local
var _pagina := 0
var _filas_datos: Array = []    ## filas de la página actual
var _total := 0                 ## pilotos registrados
var _cargando := false
var _error := ""
var _pedido := 0
var _filas: Array = []          ## FilaTabla (10)
var _t := 0.0
var _arrastre_x := 0.0
# botones
var _b_global: Boton
var _b_local: Boton
var _b_ant: Boton
var _b_sig: Boton
var _b_mio: Boton
var _b_volver: Boton
var _b_cuenta1: Boton
var _b_cuenta2: Boton
# capas
var _perfil: PerfilPiloto
var _form: Control
var _form_modo := "registro"    ## registro | entrar | recuperar | nueva_clave
var _form_error := ""
var _form_aviso := ""           ## mensaje bueno (p. ej. "revisa tu correo")
var _form_ocupado := false
var _campo_correo: LineEdit
var _campo_nombre: LineEdit
var _campo_clave: LineEdit
var _form_ok: Boton
var _form_cambiar: Boton
var _form_cancelar: Boton
var _form_olvide: Boton

class Capa extends Control:
	var dibujar: Callable
	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
	func _draw() -> void:
		if dibujar.is_valid():
			dibujar.call(self)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_b_global = _boton("TODOS LOS PILOTOS", Neon.CIAN, 8, func(): _cambiar_pestana("global"))
	_b_local = _boton("MIS RÉCORDS", Neon.VIOLETA, 8, func(): _cambiar_pestana("local"))
	_b_ant = _boton("<", Neon.CIAN, 10, func(): _ir_pagina(_pagina - 1))
	_b_sig = _boton(">", Neon.CIAN, 10, func(): _ir_pagina(_pagina + 1))
	_b_mio = _boton("MI PUESTO", Neon.AMARILLO, 7, _ir_a_mi_puesto)
	_b_volver = _boton("VOLVER", Neon.ROSA, 9, func(): volver.emit())
	_b_cuenta1 = _boton("", Neon.AMARILLO, 8, _accion_cuenta1)
	_b_cuenta2 = _boton("", Neon.CIAN, 8, _accion_cuenta2)
	for i in POR_PAGINA:
		var f := FilaTabla.new()
		f.indice = i
		f.dibujar = _dibujar_fila
		f.pulsado.connect(_pulsar_fila.bind(i))
		add_child(f)
		_filas.append(f)
	_perfil = PerfilPiloto.new()
	add_child(_perfil)
	_perfil.cerrado.connect(_enfocar)
	_form = Capa.new()
	_form.set_meta("modal", true)
	_form.dibujar = _dibujar_form
	add_child(_form)
	_campo_correo = _campo("TU@CORREO.COM", "correo")
	_campo_nombre = _campo("NOMBRE DE PILOTO", "nombre")
	_campo_clave = _campo("CONTRASEÑA", "clave")
	_campo_correo.text_submitted.connect(func(_t2): _siguiente_campo(_campo_correo))
	_campo_nombre.text_submitted.connect(func(_t2): _siguiente_campo(_campo_nombre))
	_campo_clave.text_submitted.connect(func(_t2): _enviar_form())
	_form_ok = _boton("", Neon.AMARILLO, 9, _enviar_form, _form)
	_form_cambiar = _boton("", Neon.CIAN, 7, func(): _abrir_form("registro" if _form_modo == "entrar" else "entrar"), _form)
	_form_cancelar = _boton("CANCELAR", Neon.ROSA, 7, func(): _form.visible = false; _enfocar(), _form)
	_form_olvide = _boton("OLVIDÉ MI CONTRASEÑA", Neon.GRIS, 6, func(): _abrir_form("recuperar"), _form)
	Red.sesion_cambiada.connect(_actualizar_cuenta)
	resized.connect(_colocar)
	_colocar()
	_actualizar_cuenta()

func _boton(texto: String, color: Color, tam: int, accion: Callable, padre: Control = null) -> Boton:
	var b := Boton.new(texto, color, tam)
	b.pulsado.connect(accion)
	(padre if padre else self).add_child(b)
	return b

func _campo(placeholder: String, tipo: String) -> LineEdit:
	var c := LineEdit.new()
	var secreto := tipo == "clave"
	c.placeholder_text = placeholder
	c.secret = secreto
	c.max_length = {"nombre": 14, "clave": 64, "correo": 100}[tipo]
	c.virtual_keyboard_type = {"nombre": LineEdit.KEYBOARD_TYPE_DEFAULT, "clave": LineEdit.KEYBOARD_TYPE_PASSWORD, "correo": LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS}[tipo]
	c.add_theme_font_override("font", Datos.fuente)
	c.add_theme_font_size_override("font_size", 10)
	c.add_theme_color_override("font_color", Neon.BLANCO)
	c.add_theme_color_override("font_placeholder_color", Color(0.5, 0.55, 0.75))
	c.add_theme_color_override("caret_color", Neon.CIAN)
	for estado in ["normal", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.04, 0.12, 0.95)
		sb.border_color = Neon.CIAN if estado == "focus" else Color(0.3, 0.45, 0.7)
		sb.set_border_width_all(2 if estado == "focus" else 1)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		c.add_theme_stylebox_override(estado, sb)
	if tipo == "nombre":
		c.text_changed.connect(func(t2: String):
			var col := c.caret_column
			c.text = Progreso.limpiar_nombre(t2)
			c.caret_column = mini(col, c.text.length()))
	_form.add_child(c)
	return c

# ---------------------------------------------------------------- API
func abrir() -> void:
	_perfil.visible = false
	_form.visible = false
	_pestana = "global"
	_colocar()
	_ir_pagina(0)

func ocupado() -> bool:
	return _perfil.visible or _form.visible

func refrescar() -> void:
	_ir_pagina(_pagina)

func _paginas() -> int:
	return maxi(1, ceili(_total / float(POR_PAGINA)))

func _ir_pagina(p: int) -> void:
	if not Red.configurado():
		_colocar()
		return
	p = clampi(p, 0, _paginas() - 1) if _total > 0 else 0
	_pagina = p
	_cargando = true
	_error = ""
	_pedido += 1
	var mio := _pedido
	_colocar()
	var r: Dictionary = await Red.cargar_ranking(p * POR_PAGINA, POR_PAGINA)
	if mio != _pedido:
		return
	_cargando = false
	if r.ok:
		_filas_datos = r.datos.filas
		_total = int(r.datos.total)
	else:
		_error = String(r.error)
	_colocar()

func _ir_a_mi_puesto() -> void:
	if not Red.conectado():
		return
	var n := await Red.posicion_de(Red.uid)
	if n > 0:
		if _total < n:
			_total = n
		_ir_pagina((n - 1) / POR_PAGINA)

func _cambiar_pestana(p: String) -> void:
	_pestana = p
	_colocar()
	if p == "global":
		_ir_pagina(_pagina)

func _gui_input(ev: InputEvent) -> void:
	# rueda del ratón y deslizar el dedo cambian de página
	if _pestana != "global" or ocupado():
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_ir_pagina(_pagina + 1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_ir_pagina(_pagina - 1)
	elif ev is InputEventScreenDrag:
		_arrastre_x += ev.relative.x
		if absf(_arrastre_x) > 70.0:
			_ir_pagina(_pagina + (1 if _arrastre_x < 0.0 else -1))
			_arrastre_x = 0.0
	elif ev is InputEventScreenTouch and not ev.pressed:
		_arrastre_x = 0.0

func _unhandled_input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or _perfil.visible:
		return
	if ev.is_action_pressed("ui_cancel"):
		if _form.visible:
			_form.visible = false
		else:
			volver.emit()
		Audio.sfx("ui_atras")
		get_viewport().set_input_as_handled()
		_enfocar()

func _enfocar() -> void:
	if not Ajustes.es_tactil() and is_visible_in_tree():
		_b_global.grab_focus.call_deferred()

func _process(d: float) -> void:
	if not is_visible_in_tree():
		return
	_t += d
	if _cargando or _form_ocupado:
		queue_redraw()
		_form.queue_redraw()

# ---------------------------------------------------------------- geometría
func _zona() -> Rect2:
	var t := get_viewport_rect().size
	var w := minf(t.x - 16.0, 640.0)
	return Rect2((t.x - w) * 0.5, 0, w, t.y)

func _tabla() -> Rect2:
	var z := _zona()
	return Rect2(z.position.x + 8, 64, z.size.x * 0.64 - 8, z.size.y - 64 - 42)

func _cuenta() -> Rect2:
	var z := _zona()
	var ta := _tabla()
	return Rect2(ta.end.x + 10, 64, z.end.x - 8 - ta.end.x - 10, ta.size.y)

func _colocar() -> void:
	var z := _zona()
	var ta := _tabla()
	var cu := _cuenta()
	_b_global.size = Vector2(140, 20)
	_b_global.position = Vector2(z.get_center().x - 145, 34)
	_b_local.size = Vector2(120, 20)
	_b_local.position = Vector2(z.get_center().x + 5, 34)
	_b_volver.size = Vector2(100, 26)
	_b_volver.position = Vector2(z.position.x + 8, z.size.y - 34)
	var global := _pestana == "global" and Red.configurado()
	_b_ant.size = Vector2(30, 22)
	_b_sig.size = Vector2(30, 22)
	_b_ant.position = Vector2(ta.get_center().x - 70, z.size.y - 32)
	_b_sig.position = Vector2(ta.get_center().x + 10, z.size.y - 32)
	_b_ant.visible = global
	_b_sig.visible = global
	_b_ant.desactivado = _pagina <= 0
	_b_sig.desactivado = _pagina >= _paginas() - 1
	_b_mio.size = Vector2(80, 22)
	_b_mio.position = Vector2(ta.end.x - 80, z.size.y - 32)
	_b_mio.visible = global and Red.conectado()
	var alto := (ta.size.y - 22) / POR_PAGINA
	for i in POR_PAGINA:
		var f: FilaTabla = _filas[i]
		f.position = Vector2(ta.position.x + 4, ta.position.y + 20 + i * alto)
		f.size = Vector2(ta.size.x - 8, alto - 1)
		f.visible = i < _cantidad_filas()
		f.tocable = _pestana == "global"
		f.focus_mode = Control.FOCUS_ALL if _pestana == "global" else Control.FOCUS_NONE
		f.queue_redraw()
	_b_cuenta1.size = Vector2(cu.size.x - 20, 24)
	_b_cuenta1.position = Vector2(cu.position.x + 10, cu.end.y - 62)
	_b_cuenta2.size = Vector2(cu.size.x - 20, 22)
	_b_cuenta2.position = Vector2(cu.position.x + 10, cu.end.y - 32)
	var fr := _rect_form()
	for c in [_campo_correo, _campo_nombre, _campo_clave]:
		c.visible = false
	var campos := _campos_form()
	for k in campos.size():
		var c: LineEdit = campos[k]
		c.visible = true
		c.position = Vector2(fr.position.x + 20, fr.position.y + 66 + k * 44)
		c.size = Vector2(fr.size.x - 40, 24)
	_form_ok.size = Vector2(fr.size.x - 40, 26)
	_form_ok.position = Vector2(fr.position.x + 20, fr.end.y - 64)
	var dos := _form_modo != "nueva_clave"
	_form_cambiar.visible = dos
	_form_cambiar.size = Vector2(fr.size.x * 0.5 - 24, 20)
	_form_cambiar.position = Vector2(fr.position.x + 20, fr.end.y - 32)
	_form_cancelar.size = Vector2(fr.size.x * 0.5 - 24, 20) if dos else Vector2(fr.size.x - 40, 20)
	_form_cancelar.position = Vector2(fr.get_center().x + 4, fr.end.y - 32) if dos else Vector2(fr.position.x + 20, fr.end.y - 32)
	_form_olvide.visible = _form_modo == "entrar"
	_form_olvide.size = Vector2(150, 16)
	_form_olvide.position = Vector2(fr.end.x - 170, fr.position.y + 50 + campos.size() * 44)
	for b in [_form_ok, _form_cambiar, _form_cancelar, _form_olvide]:
		b.queue_redraw()
	for b in [_b_ant, _b_sig, _b_mio]:
		b.queue_redraw()
	queue_redraw()

func _cantidad_filas() -> int:
	if _pestana == "global":
		return mini(POR_PAGINA, _filas_datos.size()) if Red.configurado() else 0
	return mini(POR_PAGINA, Progreso.registros.size())

func _campos_form() -> Array:
	match _form_modo:
		"registro": return [_campo_correo, _campo_nombre, _campo_clave]
		"entrar": return [_campo_correo, _campo_clave]
		"recuperar": return [_campo_correo]
	return [_campo_clave]

func _siguiente_campo(c: LineEdit) -> void:
	var campos := _campos_form()
	var k := campos.find(c)
	if k >= 0 and k < campos.size() - 1:
		campos[k + 1].grab_focus()
	else:
		_enviar_form()

func _rect_form() -> Rect2:
	var t := get_viewport_rect().size
	var s := Vector2(320, 150 + _campos_form().size() * 44 + (30 if _form_modo == "entrar" else 0))
	s.y = minf(s.y, t.y - 8)
	return Rect2((t - s) * 0.5 - Vector2(0, 30 if Ajustes.es_tactil() else 0), s)   # deja sitio al teclado

# ---------------------------------------------------------------- cuenta
func _actualizar_cuenta() -> void:
	_b_cuenta1.visible = Red.configurado()
	_b_cuenta2.visible = Red.configurado()
	if Red.conectado():
		_b_cuenta1.texto = "MI PERFIL"
		_b_cuenta2.texto = "CERRAR SESIÓN"
		_b_cuenta2.color = Neon.GRIS
	else:
		_b_cuenta1.texto = "CREAR PILOTO"
		_b_cuenta2.texto = "YA TENGO CUENTA"
		_b_cuenta2.color = Neon.CIAN
	_b_cuenta1.queue_redraw()
	_b_cuenta2.queue_redraw()
	_colocar()

func _accion_cuenta1() -> void:
	if Red.conectado():
		_perfil.abrir(Red.uid)
	else:
		_abrir_form("registro")

func _accion_cuenta2() -> void:
	if Red.conectado():
		Red.salir()
		refrescar()
	else:
		_abrir_form("entrar")

func _abrir_form(modo: String, aviso := "") -> void:
	_form_modo = modo
	_form_error = ""
	_form_aviso = aviso
	_form.visible = true
	_form_ok.texto = {"registro": "CREAR CUENTA", "entrar": "ENTRAR", "recuperar": "ENVIAR CORREO", "nueva_clave": "GUARDAR CONTRASEÑA"}[modo]
	_form_cambiar.texto = {"registro": "YA TENGO CUENTA", "entrar": "CREAR CUENTA", "recuperar": "VOLVER"}.get(modo, "")
	_campo_clave.text = ""
	_campo_clave.placeholder_text = "NUEVA CONTRASEÑA" if modo == "nueva_clave" else "CONTRASEÑA"
	if _campo_nombre.text == "":
		_campo_nombre.text = Progreso.piloto
	_colocar()
	var primero: LineEdit = _campos_form()[0]
	if primero == _campo_correo and _campo_correo.text != "" and modo == "entrar":
		primero = _campo_clave
	primero.grab_focus.call_deferred()
	_form.queue_redraw()

func _enviar_form() -> void:
	if _form_ocupado:
		return
	_form_ocupado = true
	_form_error = ""
	_form_aviso = ""
	_form.queue_redraw()
	var modo := _form_modo
	var r: Dictionary
	match modo:
		"registro": r = await Red.registrar(_campo_correo.text, _campo_nombre.text, _campo_clave.text)
		"entrar": r = await Red.entrar(_campo_correo.text, _campo_clave.text)
		"recuperar": r = await Red.recuperar(_campo_correo.text)
		_: r = await Red.cambiar_clave(_campo_clave.text)
	_form_ocupado = false
	if not r.ok:
		_form_error = String(r.error)
		Audio.sfx("ui_error")
		_form.queue_redraw()
		return
	Audio.sfx("mejora")
	if modo == "registro" and r.datos.confirmar:
		_abrir_form("entrar", "¡CUENTA CREADA! TE ENVIAMOS UN CORREO A %s. ÁBRELO PARA ACTIVARLA (MIRA EN SPAM) Y LUEGO ENTRA AQUÍ." % _campo_correo.text.strip_edges().to_upper())
		return
	if modo == "recuperar":
		_abrir_form("entrar", "SI ESE CORREO TIENE CUENTA, TE LLEGARÁ UN ENLACE PARA CAMBIAR LA CONTRASEÑA.")
		return
	_form.visible = false
	_campo_clave.text = ""
	DisplayServer.virtual_keyboard_hide()
	Red.cargar_top()
	_ir_a_mi_puesto()
	_enfocar()
	_form.queue_redraw()

func _pulsar_fila(i: int) -> void:
	if _pestana == "global" and i < _filas_datos.size():
		_perfil.abrir(String(_filas_datos[i].jugador))

# ---------------------------------------------------------------- dibujo
func _draw() -> void:
	var z := _zona()
	var cx := z.get_center().x
	Texto.dibujar(self, Vector2(cx, 24), "MARCADORES", 14, Neon.BLANCO, HORIZONTAL_ALIGNMENT_CENTER)
	var activa := _b_global if _pestana == "global" else _b_local
	draw_rect(Rect2(activa.position + Vector2(6, activa.size.y + 3), Vector2(activa.size.x - 12, 2)), activa.color)
	var ta := _tabla()
	Neon.marco(self, ta, Neon.CIAN if _pestana == "global" else Neon.VIOLETA, 10.0, Color(0.03, 0.04, 0.12, 0.92))
	var cols := _columnas(ta.size.x - 8)
	for k in cols:
		Texto.dibujar(self, Vector2(ta.position.x + 4 + k[1], ta.position.y + 13), k[0], 6, Neon.GRIS, HORIZONTAL_ALIGNMENT_RIGHT if k[2] else HORIZONTAL_ALIGNMENT_LEFT)
	var centro := ta.get_center() + Vector2(0, 8)
	if _pestana == "global":
		if not Red.configurado():
			Texto.parrafo(self, centro - Vector2(0, 10), "LOS MARCADORES GLOBALES AÚN NO ESTÁN CONFIGURADOS. TUS RÉCORDS SE GUARDAN EN ESTE DISPOSITIVO.", 7, Neon.GRIS, ta.size.x - 60)
		elif _filas_datos.is_empty():
			if _cargando:
				Neon.rueda(self, centro, Neon.CIAN, _t)
			elif _error != "":
				Texto.parrafo(self, centro - Vector2(0, 8), _error.to_upper(), 7, Neon.ROSA, ta.size.x - 60)
			else:
				Texto.dibujar(self, centro, "AÚN NO HAY PILOTOS. ¡SÉ EL PRIMERO!", 8, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			# página entre las flechas; total de pilotos junto a la flecha derecha
			var pagina := "%d / %d" % [_pagina + 1, _paginas()]
			if _cargando:
				Neon.rueda(self, Vector2(ta.get_center().x - 15, z.size.y - 21), Neon.CIAN, _t, 6.0)
			else:
				Texto.dibujar(self, Vector2(ta.get_center().x - 15, z.size.y - 17), pagina, 8, Neon.BLANCO, HORIZONTAL_ALIGNMENT_CENTER)
			var total := "%d PILOTOS" % _total
			Texto.dibujar(self, Vector2(_b_sig.position.x + _b_sig.size.x + 6, z.size.y - 18), total, 5, Neon.GRIS)
			if _error != "":
				Texto.dibujar(self, Vector2(ta.get_center().x, ta.end.y - 6), _error.to_upper(), 6, Neon.ROSA, HORIZONTAL_ALIGNMENT_CENTER)
	elif Progreso.registros.is_empty():
		Texto.dibujar(self, centro, "JUEGA UNA PARTIDA PARA ESTRENAR TU TABLA", 7, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	# cuenta
	var cu := _cuenta()
	Neon.marco(self, cu, Neon.AMARILLO, 10.0, Color(0.03, 0.04, 0.12, 0.92))
	var x := cu.get_center().x
	var y := cu.position.y + 20
	if not Red.configurado():
		Texto.dibujar(self, Vector2(x, y), Progreso.piloto if Progreso.piloto != "" else "MODO SIN CONEXIÓN", 8, Neon.AMARILLO if Progreso.piloto != "" else Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.dibujar(self, Vector2(x, y + 30), "RÉCORD LOCAL", 6, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.dibujar(self, Vector2(x, y + 46), "%d" % Progreso.mejor_puntaje, 12, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
	elif Red.conectado():
		Texto.dibujar(self, Vector2(x, y), "PILOTO", 6, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.dibujar(self, Vector2(x, y + 18), Red.nombre, 11, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
		Neon.sprite(self, "res://art/naves/%s.png" % Progreso.nave_equipada, Vector2(x, y + 52), 34)
		var puesto := 0
		for f in Red.top:
			if String(f.jugador) == Red.uid:
				puesto = int(f.puesto)
		if puesto == 0:
			puesto = Red.ultimo_puesto
		Texto.dibujar(self, Vector2(x, y + 86), "PUESTO #%d GLOBAL" % puesto if puesto > 0 else "AÚN SIN PARTIDAS EN LÍNEA", 7, Neon.CIAN if puesto > 0 else Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.dibujar(self, Vector2(x, y + 100), "TUS PARTIDAS CUENTAN AL TERMINAR", 5, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		Texto.dibujar(self, Vector2(x, y + 2), "ÚNETE AL RANKING", 9, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
		Texto.parrafo(self, Vector2(x, y + 24), "CREA TU CUENTA CON TU CORREO. TUS PARTIDAS COMPETIRÁN CON LAS DE TODOS LOS PILOTOS.", 6, Neon.BLANCO, cu.size.x - 24)

## [titulo, x, alinear_derecha]
func _columnas(w: float) -> Array:
	return [["#", 20.0, true], ["", 28.0, false], ["PILOTO", 52.0, false], ["PUNTAJE", w * 0.66, true], ["TIEMPO", w * 0.83, true], ["JEFES", w - 4.0, true]]

func _dibujar_fila(f: FilaTabla) -> void:
	var i := f.indice
	var r := Rect2(Vector2.ZERO, f.size)
	var cols := _columnas(f.size.x)
	var y := r.size.y * 0.5 + 4
	if _pestana == "global":
		if i >= _filas_datos.size():
			return
		var d: Dictionary = _filas_datos[i]
		var mio: bool = String(d.jugador) == Red.uid
		var fondo := Color(0.1, 0.2, 0.35, 0.55) if f.resaltada() else (Color(0.05, 0.25, 0.3, 0.45) if mio else Color(1, 1, 1, 0.03 if i % 2 == 0 else 0.0))
		f.draw_rect(r, fondo)
		if f.resaltada():
			f.draw_rect(r, Neon.CIAN, false, 1.0)
		var jugo: bool = d.get("puntaje") != null
		var puesto := int(d.puesto) if d.get("puesto") != null else 0
		Texto.dibujar(f, Vector2(cols[0][1], y), "%d" % puesto if jugo else "—", 9 if puesto > 0 and puesto <= 3 else 8, Neon.color_puesto(puesto) if jugo else Neon.GRIS, HORIZONTAL_ALIGNMENT_RIGHT)
		Neon.sprite(f, Neon.ruta_nave(String(d.get("nave", "drift"))), Vector2(cols[1][1] + 8, r.size.y * 0.5), r.size.y - 5, 1.0 if jugo else 0.5)
		var nombre := String(d.get("nombre", "?"))
		Texto.dibujar(f, Vector2(cols[2][1], y), nombre, 8, Neon.CIAN if mio else Neon.BLANCO)
		if jugo:
			Texto.dibujar(f, Vector2(cols[3][1], y), "%d" % int(d.puntaje), 8, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_RIGHT)
			Texto.dibujar(f, Vector2(cols[4][1], y), Progreso.formato_tiempo(float(d.get("tiempo", 0))), 7, Neon.BLANCO, HORIZONTAL_ALIGNMENT_RIGHT)
			Texto.dibujar(f, Vector2(cols[5][1], y), "%d" % int(d.get("jefes", 0)), 7, Neon.ROSA, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			Texto.dibujar(f, Vector2(cols[3][1], y), "SIN PARTIDAS", 6, Neon.GRIS, HORIZONTAL_ALIGNMENT_RIGHT)
		if f.resaltada():
			Texto.dibujar(f, Vector2(cols[2][1] + Texto.ancho(nombre, 8) + 6, y), "› PERFIL", 6, Neon.CIAN)
	else:
		if i >= Progreso.registros.size():
			return
		var d: Dictionary = Progreso.registros[i]
		f.draw_rect(r, Color(1, 1, 1, 0.03 if i % 2 == 0 else 0.0))
		Texto.dibujar(f, Vector2(cols[0][1], y), "%d" % (i + 1), 8, Neon.color_puesto(i + 1), HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(f, Vector2(cols[2][1], y), "NIVEL %d" % int(d.get("nivel", 1)), 8, Neon.BLANCO)
		Texto.dibujar(f, Vector2(cols[3][1], y), "%d" % int(d.get("puntaje", 0)), 8, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(f, Vector2(cols[4][1], y), Progreso.formato_tiempo(float(d.get("tiempo", 0))), 7, Neon.BLANCO, HORIZONTAL_ALIGNMENT_RIGHT)
		Texto.dibujar(f, Vector2(cols[5][1], y), "%d" % int(d.get("jefes", 0)), 7, Neon.ROSA, HORIZONTAL_ALIGNMENT_RIGHT)

func _dibujar_form(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.01, 0.01, 0.05, 0.82))
	var r := _rect_form()
	Neon.marco(c, r, Neon.AMARILLO, 12.0, Color(0.03, 0.04, 0.13, 0.98))
	var cx := r.get_center().x
	var titulo: String = {"registro": "CREA TU PILOTO", "entrar": "ENTRA CON TU CUENTA", "recuperar": "RECUPERAR CONTRASEÑA", "nueva_clave": "NUEVA CONTRASEÑA"}[_form_modo]
	var sub: String = {"registro": "CON TU CORREO PODRÁS ENTRAR DESDE CUALQUIER EQUIPO", "entrar": "TU CORREO Y TU CONTRASEÑA", "recuperar": "TE ENVIAREMOS UN ENLACE A TU CORREO", "nueva_clave": "ELIGE UNA CONTRASEÑA NUEVA"}[_form_modo]
	Texto.dibujar(c, Vector2(cx, r.position.y + 26), titulo, 11, Neon.AMARILLO, HORIZONTAL_ALIGNMENT_CENTER)
	Texto.dibujar(c, Vector2(cx, r.position.y + 40), sub, 5, Neon.GRIS, HORIZONTAL_ALIGNMENT_CENTER)
	var etiquetas := {_campo_correo: "CORREO", _campo_nombre: "NOMBRE DE PILOTO (3-14 LETRAS, NÚMEROS O _)", _campo_clave: "CONTRASEÑA (MÍNIMO 6)"}
	var campos := _campos_form()
	for k in campos.size():
		Texto.dibujar(c, Vector2(r.position.x + 20, r.position.y + 61 + k * 44), etiquetas[campos[k]], 6, Neon.CIAN)
	var y_msj := r.end.y - 84
	if _form_ocupado:
		Neon.rueda(c, Vector2(cx, y_msj), Neon.AMARILLO, _t, 7.0)
	elif _form_error != "":
		Texto.parrafo(c, Vector2(cx, y_msj - 6), _form_error.to_upper(), 6, Neon.ROSA, r.size.x - 30)
	elif _form_aviso != "":
		Texto.parrafo(c, Vector2(cx, y_msj - 10), _form_aviso, 5, Color("7dff9b"), r.size.x - 30)
