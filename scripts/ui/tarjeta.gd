class_name Tarjeta
extends Boton
## Tarjeta de mejora: rareza, nombre, descripción y nivel actual.

var mejora: Dictionary = {}
var nivel_actual := 0
var efecto := ""        ## "DAÑO 18 → 21": lo que cambia de verdad
var entrada := 0.0     ## animación de aparición

func _process(delta: float) -> void:
	if entrada < 1.0:
		entrada = min(1.0, entrada + delta * 4.0)
		queue_redraw()

func _draw() -> void:
	var rar: Dictionary = Datos.RAREZAS[int(mejora.get("rar", 0))]
	var c: Color = rar.color
	var e := 1.0 - pow(1.0 - entrada, 3.0)
	var off := Vector2(0, (1.0 - e) * 30.0 + (2.0 if _presionado else 0.0))
	var r := Rect2(off, size)
	var foco := _encima or has_focus()
	draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.5 * e))
	draw_rect(r, Color(c.r * 0.12, c.g * 0.12, c.b * 0.2 + 0.04, 0.94 * e))
	draw_rect(r, Color(c, e), false, 3.0 if foco else 2.0)
	draw_rect(r.grow(-4), Color(c, 0.3 * e), false, 1.0)
	if int(mejora.get("rar", 0)) == 2:
		var brillo := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(r.grow(2), Color(c, 0.25 * brillo * e), false, 2.0)
	var cx := size.x * 0.5
	Texto.dibujar(self, off + Vector2(cx, 16), rar.nombre, 6, Color(c, e), HORIZONTAL_ALIGNMENT_CENTER)
	var y := 34.0
	if mejora.has("arma"):
		for a in Datos.ARSENAL:
			if a.id == mejora.arma:
				var ic := Datos.tex(a.icono)
				var h := 20.0
				var w := ic.get_width() * h / ic.get_height()
				draw_texture_rect(ic, Rect2(off + Vector2(cx - w * 0.5, y - 6), Vector2(w, h)), false, Color(1, 1, 1, e))
				y += 22
	var alto_nombre := Texto.parrafo(self, off + Vector2(cx, y), String(mejora.n).to_upper(), 8, Color(1, 1, 1, e), size.x - 16)
	y += alto_nombre + 6
	Texto.parrafo(self, off + Vector2(cx, y), mejora.d, 6, Color(0.78, 0.85, 1.0, e), size.x - 18, 1.7)
	var maxi := int(mejora.max)
	if efecto != "":
		Texto.parrafo(self, off + Vector2(cx, size.y - 30), efecto, 6, Color(1, 0.9, 0.45, e), size.x - 14, 1.6)
	var nv := "NV %d → %d / %d" % [nivel_actual, nivel_actual + 1, maxi] if maxi < 99 else "SIEMPRE DISPONIBLE"
	Texto.dibujar(self, off + Vector2(cx, size.y - 8), nv, 6, Color(c, e), HORIZONTAL_ALIGNMENT_CENTER)
