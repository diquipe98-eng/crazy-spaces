extends Node2D
## Fondo con parallax: nebulosas pixeladas y tres capas de estrellas.
## Vive en un CanvasLayer propio; lee la posición de la cámara del Juego.

var _capas := []   ## [{tex, factor, modulado}]
var _t := 0.0

func _ready() -> void:
	_capas = [
		{"tex": Generador.nebulosa(256, 11, Color("1a1040"), Color("6b3fa0")), "factor": 0.05, "escala": 2.0, "color": Color(1, 1, 1, 0.55)},
		{"tex": Generador.nebulosa(256, 37, Color("0c1a3a"), Color("2f6fb0")), "factor": 0.09, "escala": 2.0, "color": Color(1, 1, 1, 0.35)},
		{"tex": Generador.estrellas(256, 140, 3, false), "factor": 0.15, "escala": 1.0, "color": Color(1, 1, 1, 0.6)},
		{"tex": Generador.estrellas(256, 70, 5, true), "factor": 0.3, "escala": 1.0, "color": Color(1, 1, 1, 0.85)},
		{"tex": Generador.estrellas(320, 26, 9, true), "factor": 0.55, "escala": 2.0, "color": Color(1, 1, 1, 1)},
	]

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var tam := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, tam), Color("070814"))
	var cam := Vector2.ZERO
	var j = get_parent().get_parent()
	if j and j.get("camara"):
		cam = j.camara.position
	for c in _capas:
		var tex: Texture2D = c.tex
		var s: float = c.escala
		var lado := tex.get_size() * s
		var off := Vector2(fposmod(-cam.x * c.factor, lado.x), fposmod(-cam.y * c.factor + _t * 4.0 * c.factor, lado.y)) - lado
		var y := off.y
		while y < tam.y:
			var x := off.x
			while x < tam.x:
				draw_texture_rect(tex, Rect2(Vector2(x, y), lado), false, c.color)
				x += lado.x
			y += lado.y
