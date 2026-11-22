class_name Texto
## Texto pixel con contorno y sombra corta, sin cajas detrás (como pidió el diseño).

static func dibujar(ci: CanvasItem, pos: Vector2, s: String, tam: int, color: Color, alineado := HORIZONTAL_ALIGNMENT_LEFT, ancho := -1.0) -> void:
	var f := Datos.fuente
	var p := pos
	if alineado != HORIZONTAL_ALIGNMENT_LEFT and ancho < 0.0:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		p.x -= w * (0.5 if alineado == HORIZONTAL_ALIGNMENT_CENTER else 1.0)
		alineado = HORIZONTAL_ALIGNMENT_LEFT
	var borde := maxi(2, tam / 4)
	var sombra := Color(0.02, 0.01, 0.06, color.a * 0.9)
	ci.draw_string_outline(f, p + Vector2(0, 1), s, alineado, ancho, tam, borde + 1, sombra)
	ci.draw_string_outline(f, p, s, alineado, ancho, tam, borde, Color(0.05, 0.03, 0.12, color.a))
	ci.draw_string(f, p, s, alineado, ancho, tam, color)

static func ancho(s: String, tam: int) -> float:
	return Datos.fuente.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x

## Párrafo con saltos automáticos centrado en "ancho".
static func parrafo(ci: CanvasItem, pos: Vector2, s: String, tam: int, color: Color, ancho_max: float, interlinea := 1.5) -> float:
	var palabras := s.split(" ")
	var lineas: Array[String] = []
	var actual := ""
	for w in palabras:
		var prueba := w if actual == "" else actual + " " + w
		if ancho(prueba, tam) > ancho_max and actual != "":
			lineas.append(actual)
			actual = w
		else:
			actual = prueba
	if actual != "":
		lineas.append(actual)
	var y := pos.y
	for l in lineas:
		dibujar(ci, Vector2(pos.x, y), l, tam, color, HORIZONTAL_ALIGNMENT_CENTER)
		y += tam * interlinea
	return y - pos.y
