class_name FilaTabla
extends Control
## Fila tocable de una tabla (ratón, toque o mando). Se dibuja con "dibujar".

signal pulsado

var indice := 0
var dibujar: Callable
var tocable := true
var _encima := false

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _encima = true; queue_redraw())
	mouse_exited.connect(func(): _encima = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func resaltada() -> bool:
	return tocable and (_encima or has_focus())

func _gui_input(ev: InputEvent) -> void:
	if not tocable:
		return
	if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) or ev.is_action_pressed("ui_accept"):
		Audio.sfx("ui_click")
		pulsado.emit()
		accept_event()

func _draw() -> void:
	if dibujar.is_valid():
		dibujar.call(self)
