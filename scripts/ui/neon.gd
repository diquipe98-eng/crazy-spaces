class_name Neon
## Piezas de dibujo compartidas por las pantallas estilo "guía neón"
## (marcadores, panel del top 10, perfil de piloto).

const CIAN := Color("19e6ff")
const VIOLETA := Color("9b4dff")
const NARANJA := Color("ff8a1a")
const AMARILLO := Color("ffd23a")
const ROSA := Color("ff5c8a")
const BLANCO := Color("eef0ff")
const GRIS := Color(0.62, 0.68, 0.85)
const MEDALLAS := [Color("ffd23a"), Color("d6e2ff"), Color("ff9a5a")]

## Marco con esquinas cortadas (arriba-izquierda y abajo-derecha) y brillo.
static func marco(ci: CanvasItem, r: Rect2, c: Color, corte: float, fondo: Color) -> void:
	var pts := PackedVector2Array([
		r.position + Vector2(corte, 0), Vector2(r.end.x, r.position.y),
		r.end - Vector2(0, corte), r.end - Vector2(corte, 0),
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, corte),
	])
	ci.draw_colored_polygon(pts, fondo)
	var cerrado := pts.duplicate()
	cerrado.append(pts[0])
	ci.draw_polyline(cerrado, Color(c, 0.12), 6.0)
	ci.draw_polyline(cerrado, Color(c, 0.3), 3.0)
	ci.draw_polyline(cerrado, Color(c.lerp(Color.WHITE, 0.35), 0.95), 1.2)

static func sprite(ci: CanvasItem, ruta: String, centro: Vector2, alto: float, alfa := 1.0) -> void:
	var tex := Datos.tex(ruta)
	var w := tex.get_width() * alto / tex.get_height()
	ci.draw_texture_rect(tex, Rect2(centro - Vector2(w, alto) * 0.5, Vector2(w, alto)), false, Color(1, 1, 1, alfa))

static func rueda(ci: CanvasItem, c: Vector2, color: Color, t: float, r := 10.0) -> void:
	ci.draw_arc(c, r, t * 6.0, t * 6.0 + PI * 1.4, 24, color, 2.0, true)
	ci.draw_arc(c, r, 0, TAU, 24, Color(color, 0.2), 2.0, true)

static func ruta_nave(id: String) -> String:
	var ruta := "res://art/naves/%s.png" % id
	return ruta if ResourceLoader.exists(ruta) else "res://art/naves/drift.png"

static func fecha(iso: String) -> String:
	if iso.length() < 10:
		return "—"
	return "%s/%s/%s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(0, 4)]

static func color_puesto(puesto: int) -> Color:
	return MEDALLAS[puesto - 1] if puesto >= 1 and puesto <= 3 else BLANCO
