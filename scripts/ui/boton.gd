class_name Boton
extends Control
## Botón dibujado a mano (pixel art) que responde a ratón, toque y mando.

signal pulsado

@export var texto := ""
@export var tam_texto := 10
@export var color := Color("5ad1ff")
var icono: Texture2D
var desactivado := false
var subtexto := ""
var _presionado := false
var _encima := false

func _init(t := "", c := Color("5ad1ff"), tam := 10) -> void:
	texto = t
	color = c
	tam_texto = tam
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	mouse_entered.connect(func(): _encima = true; queue_redraw())
	mouse_exited.connect(func(): _encima = false; _presionado = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_presionado = true
		elif _presionado:
			_presionado = false
			if get_rect().has_point(ev.position + position) or Rect2(Vector2.ZERO, size).has_point(ev.position):
				_activar()
		queue_redraw()
		accept_event()
	elif ev.is_action_pressed("ui_accept"):
		_activar()
		accept_event()

func _activar() -> void:
	if desactivado:
		Audio.sfx("ui_error")
		return
	Audio.sfx("ui_click")
	pulsado.emit()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := color if not desactivado else Color(0.4, 0.42, 0.5)
	var hundido := 2.0 if _presionado else 0.0
	var fondo := Color(0.05, 0.06, 0.14, 0.88)
	if _encima or has_focus():
		fondo = Color(c.r * 0.25, c.g * 0.25, c.b * 0.3, 0.92)
	# sombra pixel, cuerpo y borde doble
	draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.45))
	var cuerpo := Rect2(r.position + Vector2(0, hundido), r.size - Vector2(0, 0))
	draw_rect(cuerpo, fondo)
	draw_rect(cuerpo, c, false, 2.0)
	draw_rect(cuerpo.grow(-3), Color(c, 0.35), false, 1.0)
	var y := cuerpo.position.y + cuerpo.size.y * 0.5 + tam_texto * 0.5
	if subtexto != "":
		y -= 5
	var x := size.x * 0.5
	var x_sub := x
	if icono:
		var h = min(cuerpo.size.y - 10.0, 22.0)
		var w = icono.get_width() * h / icono.get_height()
		var total = w + 6.0 + Texto.ancho(texto, tam_texto)
		var ix = x - total * 0.5
		draw_texture_rect(icono, Rect2(Vector2(ix, cuerpo.position.y + (cuerpo.size.y - h) * 0.5), Vector2(w, h)), false, Color(1, 1, 1, 1.0 if not desactivado else 0.4))
		x = ix + w + 6.0 + Texto.ancho(texto, tam_texto) * 0.5
		x_sub = x
	Texto.dibujar(self, Vector2(x, y), texto, tam_texto, Color.WHITE if not desactivado else Color(0.6, 0.62, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	if subtexto != "":
		Texto.dibujar(self, Vector2(x_sub, y + 11), subtexto, 6, Color(c, 0.95) if not desactivado else Color(0.55, 0.55, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
