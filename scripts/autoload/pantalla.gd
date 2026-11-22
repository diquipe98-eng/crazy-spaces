extends CanvasLayer
## Pantalla completa y orientación.
##  - Web: entra en pantalla completa con el primer toque/clic/tecla y en teléfonos fija
##    la orientación horizontal (gira sola entre las dos horizontales).
##    El navegador solo permite pedirla dentro de un gesto real, así que la petición
##    la hace un pequeño script JS en el propio evento (pointerup / touchend / keydown).
##  - Escritorio exportado: arranca en pantalla completa. F11 alterna en todas partes.
##  - Botón pequeño y discreto para entrar/salir (web y teléfonos). Esc sale (lo hace
##    el navegador solo; en escritorio Esc sigue siendo pausa/atrás y F11 alterna).

const JS_INSTALAR := """
(function () {
  if (window.__csPantalla) return;
  var cs = window.__csPantalla = { pedir: false, auto: true };
  function horizontal() {
    try { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function () {}); } catch (e) {}
  }
  function intento() {
    if (!(cs.pedir || cs.auto)) return;
    cs.pedir = false; cs.auto = false;
    if (document.fullscreenElement || document.webkitFullscreenElement) return;
    var el = document.documentElement;
    var pedir = el.requestFullscreen || el.webkitRequestFullscreen;
    if (!pedir) return;
    try {
      var p = pedir.call(el, { navigationUI: 'hide' });
      if (p && p.then) p.then(horizontal).catch(function () {}); else horizontal();
    } catch (e) {}
  }
  ['pointerup', 'touchend', 'keydown'].forEach(function (t) { document.addEventListener(t, intento, true); });
})();
"""

var _web := OS.has_feature("web")
var _boton: Control
var _ultimo_estado := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _web:
		JavaScriptBridge.eval(JS_INSTALAR, true)
	elif OS.has_feature("pc") and OS.has_feature("template") and not ("--ventana" in OS.get_cmdline_user_args()):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_boton = BotonPantalla.new()
	_boton.visible = disponible() and (_web or OS.has_feature("mobile"))
	add_child(_boton)
	get_tree().node_added.connect(func(_n): _colocar.call_deferred())
	get_viewport().size_changed.connect(_colocar)
	_colocar()

## El iPhone no tiene pantalla completa para páginas web: ahí no sale el botón.
func disponible() -> bool:
	if _web:
		return bool(JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true))
	return not OS.has_feature("mobile")   # en apps móviles ya es pantalla completa

func es_completa() -> bool:
	if _web:
		return bool(JavaScriptBridge.eval("!!(document.fullscreenElement || document.webkitFullscreenElement)", true))
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func alternar() -> void:
	if _web:
		if es_completa():
			JavaScriptBridge.eval("(document.exitFullscreen || document.webkitExitFullscreen).call(document)", true)
		else:
			# se cumple en el pointerup/touchend de este mismo toque (gesto real)
			JavaScriptBridge.eval("window.__csPantalla && (window.__csPantalla.pedir = true)", true)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if es_completa() else DisplayServer.WINDOW_MODE_FULLSCREEN)

## Para que los controles táctiles del juego no usen el toque del botón.
func en_boton(p: Vector2) -> bool:
	return _boton.visible and _boton.get_global_rect().grow(4).has_point(p)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F11 and not _web:
		alternar()   # en la web F11 ya lo hace el navegador
		get_viewport().set_input_as_handled()

func _process(_d: float) -> void:
	var c := es_completa() if _boton.visible else false
	if c != _ultimo_estado:
		_ultimo_estado = c
		_boton.queue_redraw()

## Menú: esquina inferior izquierda (libre). Partida: bajo el botón de pausa.
func _colocar() -> void:
	if not is_instance_valid(_boton):
		return
	var t := get_viewport().get_visible_rect().size
	var escena := get_tree().current_scene
	var en_juego := escena != null and String(escena.scene_file_path).ends_with("juego.tscn")
	_boton.size = Vector2(18, 18)
	_boton.position = Vector2(t.x - 27, 70) if en_juego else Vector2(6, t.y - 24)


class BotonPantalla extends Control:
	var _encima := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "Pantalla completa (F11)"
		mouse_entered.connect(func(): _encima = true; queue_redraw())
		mouse_exited.connect(func(): _encima = false; queue_redraw())

	func _gui_input(ev: InputEvent) -> void:
		# al presionar (no al soltar): así el soltar del mismo toque es el gesto que usa el navegador
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			Pantalla.alternar()
			accept_event()

	func _draw() -> void:
		var a := 0.75 if _encima else 0.32
		var c := Color(0.85, 0.92, 1.0, a)
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var l := 4.0
		var completa: bool = Pantalla.es_completa()
		# cuatro esquinas: hacia fuera = entrar, hacia dentro = salir
		for esq in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p: Vector2 = r.position + r.size * esq
			var sx := 1.0 if esq.x == 0 else -1.0
			var sy := 1.0 if esq.y == 0 else -1.0
			if completa:
				p += Vector2(sx, sy) * l
				sx = -sx
				sy = -sy
			draw_line(p, p + Vector2(sx * l, 0), c, 2.0)
			draw_line(p, p + Vector2(0, sy * l), c, 2.0)
