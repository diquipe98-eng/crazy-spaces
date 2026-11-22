class_name Generador
## Texturas procedurales que se crean una vez al cargar: asteroides pixel art
## iluminados y capas de estrellas/nebulosa del fondo.

const RAMPA_ROCA := [Color("140f14"), Color("2c2124"), Color("4a3830"), Color("6e5442"), Color("95775a"), Color("c0a07c")]
const RAMPA_HIELO := [Color("0e1422"), Color("1f2c44"), Color("36506e"), Color("56789a"), Color("86a9c4"), Color("c4dcec")]

## Asteroide de radio r píxeles (se dibuja escalado x2). solido: borde ámbar (bloquea la nave).
static func asteroide(r: int, semilla: int, hielo: bool, solido: bool) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var n := 2 * r + 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	var picos := []
	for i in 10:
		picos.append(rng.randf_range(0.78, 1.0))
	var crateres := []
	for i in rng.randi_range(2, 4):
		crateres.append([Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * r, rng.randf_range(0.14, 0.26) * r])
	var rampa: Array = RAMPA_HIELO if hielo else RAMPA_ROCA
	var luz := Vector2(-0.6, -0.75).normalized()
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var a := fposmod(d.angle(), TAU) / TAU * 10.0
			var i0 := int(a) % 10
			var f := a - int(a)
			var rr: float = r * lerp(float(picos[i0]), float(picos[(i0 + 1) % 10]), f)
			if d.length() > rr:
				continue
			var nz := sqrt(max(0.0, 1.0 - pow(d.length() / rr, 2.0)))
			var normal := Vector3(d.x / rr, d.y / rr, nz).normalized()
			var l: float = clampf(normal.dot(Vector3(luz.x, luz.y, 0.55).normalized()), 0.0, 1.0)
			var v := 0.15 + l * 0.85
			for cr in crateres:
				var dc: float = (d - cr[0]).length()
				if dc < cr[1]:
					v -= 0.28 * (1.0 - dc / cr[1])
				elif dc < cr[1] + 1.2:
					v += 0.12
			v += rng.randf_range(-0.05, 0.05)
			var idx := clampi(int(round(v * (rampa.size() - 1))), 0, rampa.size() - 1)
			var col: Color = rampa[idx]
			if solido and d.length() > rr - 1.3:
				col = Color("ff9d42").lerp(col, 0.35)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## Capa de estrellas repetible (tile) para el parallax.
static func estrellas(tam: int, cantidad: int, semilla: int, brillantes: bool) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var tonos := [Color("ffffff"), Color("b9d6ff"), Color("ffe9b0"), Color("d8b8ff")]
	for i in cantidad:
		var x := rng.randi_range(0, tam - 1)
		var y := rng.randi_range(0, tam - 1)
		var c: Color = tonos[rng.randi_range(0, tonos.size() - 1)]
		c.a = rng.randf_range(0.35, 1.0)
		img.set_pixel(x, y, c)
		if brillantes and rng.randf() < 0.22:
			var c2 := c
			c2.a *= 0.45
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(posmod(x + o.x, tam), posmod(y + o.y, tam), c2)
	return ImageTexture.create_from_image(img)

## Nebulosa repetible a partir de ruido, con paleta violeta/azul como la referencia.
static func nebulosa(tam: int, semilla: int, color_a: Color, color_b: Color) -> ImageTexture:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.012
	ruido.fractal_octaves = 5
	var img := ruido.get_seamless_image(tam, tam, false, false, 0.15)
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	# cuantizado con tramado ordenado para que se vea pixelado
	var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	for y in tam:
		for x in tam:
			var v := img.get_pixel(x, y).r
			var m := clampf((v - 0.45) / 0.45, 0.0, 1.0)
			var umbral: float = bayer[(y % 4) * 4 + (x % 4)] / 16.0 - 0.47
			var q := clampf(round(m * 5.0 + umbral * 0.9) / 5.0, 0.0, 1.0)
			var c := color_a.lerp(color_b, q)
			c.a = q * 0.85
			out.set_pixel(x, y, c)
	return ImageTexture.create_from_image(out)

## Texturas de proyectiles (blancas; se tiñen al dibujar con mezcla aditiva).
##  "halo": cápsula suave ancha · "nucleo": cápsula nítida delgada · "estela": cola que se desvanece
static func proyectil(tipo: String) -> ImageTexture:
	var w := 64
	var h := 16 if tipo == "halo" else 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cy := h / 2.0
	for y in h:
		for x in w:
			var px := x + 0.5
			var py := y + 0.5
			var a := 0.0
			match tipo:
				"halo":
					var d := Vector2(px - clampf(px, 9.0, 55.0), py - cy).length()
					a = pow(clampf(1.0 - d / 8.0, 0.0, 1.0), 2.0)
				"nucleo":
					var d := Vector2(px - clampf(px, 5.0, 59.0), py - cy).length()
					a = clampf((3.6 - d) / 1.4, 0.0, 1.0)
				"estela":
					var f := pow(px / w, 1.6)
					a = f * clampf(1.0 - absf(py - cy) / (cy * (0.4 + 0.6 * px / w)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
