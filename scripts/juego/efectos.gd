class_name Efectos
extends RefCounted
## Partículas, ondas, destellos, fragmentos y textos cómic. Se dibujan en dos capas:
## la base (humo, escombros, fragmentos) con mezcla normal y la de brillo con mezcla aditiva.
## Cada explosión pide sacudida de pantalla en "sacudida_pedida"; Juego la consume.

class Particula:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var vida := 0.5
	var maxv := 0.5
	var color := Color.WHITE
	var tam := 2.0
	var tipo := 0
	var arrastre := 0.92
	var crece := 0.0
	var rot := 0.0
	var giro := 0.0
	var tex: Texture2D
	var region := Rect2()
	var escala := 1.0

class Anillo:
	var pos := Vector2.ZERO
	var radio_max := 40.0
	var vida := 0.5
	var maxv := 0.5
	var color := Color.WHITE
	var ancho := 3.0
	var relleno := false

class TextoFlotante:
	var pos := Vector2.ZERO
	var texto := ""
	var color := Color.WHITE
	var tam := 14
	var vida := 0.8
	var maxv := 0.8
	var gira := 0.0
	var numero := false

const CHISPA := 0
const FUEGO := 1
const HUMO := 2
const PIXEL := 3
const DESTELLO := 4
const BRASA := 5       ## chispa lenta que flota y parpadea
const FRAGMENTO := 6   ## trozo del sprite del enemigo destruido
const ESCOMBRO := 7    ## trozo de metal oscuro girando

const RAMPA_FUEGO := [Color(1, 1, 0.92), Color(1, 0.86, 0.35), Color(1, 0.52, 0.16), Color(0.85, 0.18, 0.12), Color(0.35, 0.08, 0.1)]

var particulas: Array[Particula] = []
var anillos: Array[Anillo] = []
var textos: Array[TextoFlotante] = []
var retardadas: Array = []          ## explosiones secundarias programadas
var sacudida_pedida := 0.0
var destello_pantalla := 0.0        ## fogonazo blanco a pantalla completa (lo dibuja el HUD)

func _particula(pos: Vector2, vel: Vector2, vida: float, color: Color, tam: float, tipo: int, arrastre := 0.92, crece := 0.0) -> Particula:
	if particulas.size() >= Datos.MAX_PARTICULAS:
		# las chispas viejas ceden lugar a lo nuevo
		particulas.pop_front()
	var p := Particula.new()
	p.pos = pos
	p.vel = vel
	p.vida = vida
	p.maxv = vida
	p.color = color
	p.tam = tam
	p.tipo = tipo
	p.arrastre = arrastre
	p.crece = crece
	particulas.append(p)
	return p

func chispas(pos: Vector2, n: int, color: Color, rapidez := 160.0, vida := 0.35, dir := Vector2.ZERO, apertura := PI) -> void:
	for i in n:
		var a := randf() * TAU
		if dir != Vector2.ZERO:
			a = dir.angle() + randf_range(-apertura, apertura)
		var v := Vector2.from_angle(a) * rapidez * sqrt(randf()) * randf_range(0.6, 1.25)
		_particula(pos, v, vida * randf_range(0.6, 1.2), color, randf_range(1.2, 2.2), CHISPA, 0.9)

func pixeles(pos: Vector2, n: int, color: Color, rapidez := 120.0, vida := 0.6) -> void:
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * rapidez * sqrt(randf())
		_particula(pos, v, vida * randf_range(0.6, 1.3), color, float(randi_range(2, 3)), PIXEL, 0.93)

func brasas(pos: Vector2, n: int, rapidez := 70.0) -> void:
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * rapidez * randf_range(0.3, 1.0)
		_particula(pos, v, randf_range(0.7, 1.4), Color(1, randf_range(0.5, 0.8), 0.2), randf_range(1.0, 1.8), BRASA, 0.95)

func escombros(pos: Vector2, n: int, rapidez := 150.0) -> void:
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * rapidez * randf_range(0.4, 1.1)
		var p := _particula(pos, v, randf_range(0.6, 1.1), Color(0.22, 0.2, 0.28).lerp(Color(0.45, 0.4, 0.45), randf()), randf_range(2.0, 4.0), ESCOMBRO, 0.95)
		p.rot = randf() * TAU
		p.giro = randf_range(-12, 12)

## Rompe el sprite en 4 trozos que salen girando.
func fragmentos(ruta_tex: String, pos: Vector2, rot: float, escala: float, fuerza := 120.0) -> void:
	var tex := Datos.tex(ruta_tex)
	var m := tex.get_size() * 0.5
	for k in 4:
		var q := Vector2(k % 2, int(k / 2.0))
		var region := Rect2(q * m, m)
		var local := (q - Vector2(0.5, 0.5)) * m * escala
		var dir := local.rotated(rot).normalized()
		var p := _particula(pos + local.rotated(rot), dir * fuerza * randf_range(0.6, 1.3) + Vector2(randf_range(-30, 30), randf_range(-30, 30)), randf_range(0.45, 0.7), Color.WHITE, 1.0, FRAGMENTO, 0.94)
		p.tex = tex
		p.region = region
		p.escala = escala
		p.rot = rot
		p.giro = randf_range(-9, 9)

func anillo(pos: Vector2, radio_max: float, color: Color, vida := 0.45, ancho := 3.0, relleno := false) -> void:
	var r := Anillo.new()
	r.pos = pos
	r.radio_max = radio_max
	r.vida = vida
	r.maxv = vida
	r.color = color
	r.ancho = ancho
	r.relleno = relleno
	anillos.append(r)

func destello(pos: Vector2, radio: float, color: Color, vida := 0.18) -> void:
	_particula(pos, Vector2.ZERO, vida, color, radio, DESTELLO, 1.0)

## Estela del motor de la nave o de un misil (fuego corto).
func estela(pos: Vector2, dir: Vector2, color: Color, fuerza := 1.0) -> void:
	var v := -dir.normalized() * randf_range(40, 90) * fuerza + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	_particula(pos, v, randf_range(0.12, 0.22), color, randf_range(2.0, 3.4) * fuerza, FUEGO, 0.9, -6.0)

func humo(pos: Vector2, tam := 5.0, vida := 0.6) -> void:
	_particula(pos, Vector2(randf_range(-10, 10), randf_range(-10, 10)), vida, Color(0.2, 0.18, 0.24, 0.55), tam, HUMO, 0.9, tam * 0.8)

## Explosión por capas: fogonazo, bola de fuego, onda de calor, humo, chispas,
## brasas, escombros y, si es grande, explosiones secundarias alrededor.
func explosion(pos: Vector2, tam: float, color: Color, grande := false) -> void:
	destello(pos, tam * (2.8 if grande else 2.2), Color(1, 0.95, 0.85), 0.2 if not grande else 0.32)
	var n_fuego := int(clampf(tam * 0.8, 8, 30))
	for i in n_fuego:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(10, tam * 3.4)
		_particula(pos + v * 0.05, v, randf_range(0.3, 0.6) * (1.4 if grande else 1.0), Color.WHITE, randf_range(tam * 0.2, tam * 0.4), FUEGO, 0.87, tam * 0.3)
	for i in int(n_fuego * 0.7):
		var v := Vector2.from_angle(randf() * TAU) * randf_range(8, tam * 1.8)
		_particula(pos, v, randf_range(0.6, 1.1) * (1.5 if grande else 1.0), Color(0.16, 0.13, 0.2, 0.75), randf_range(tam * 0.2, tam * 0.32), HUMO, 0.9, tam * 0.4)
	chispas(pos, int(clampf(tam * 0.8, 8, 36)), color.lerp(Color.WHITE, 0.35), tam * 8.0, 0.45)
	pixeles(pos, int(clampf(tam * 0.4, 4, 18)), color, tam * 4.5, 0.75)
	brasas(pos, int(clampf(tam * 0.35, 3, 16)), tam * 3.0)
	escombros(pos, int(clampf(tam * 0.2, 2, 10)), tam * 6.0)
	anillo(pos, tam * (3.4 if grande else 2.4), color.lerp(Color.WHITE, 0.4), 0.45 if not grande else 0.7, 4.0 if grande else 2.5)
	anillo(pos, tam * (2.2 if grande else 1.6), Color(1, 0.75, 0.45), 0.25, 0.0, true)
	if grande:
		for i in randi_range(2, 4):
			retardadas.append({"t": randf_range(0.08, 0.3), "pos": pos + Vector2.from_angle(randf() * TAU) * tam * randf_range(0.6, 1.3), "tam": tam * randf_range(0.35, 0.55), "color": color})
		destello_pantalla = maxf(destello_pantalla, clampf(tam / 160.0, 0.05, 0.35))
	sacudida_pedida += tam * (0.45 if grande else 0.3)

func comic(pos: Vector2, texto: String, color: Color, tam := 14, vida := 0.8) -> void:
	if textos.size() > 26:
		textos.pop_front()
	var t := TextoFlotante.new()
	t.pos = pos
	t.texto = texto
	t.color = color
	t.tam = tam
	t.vida = vida
	t.maxv = vida
	t.gira = randf_range(-0.22, 0.22)
	textos.append(t)

func numero(pos: Vector2, valor: float, critico := false) -> void:
	if not Ajustes.mostrar_danos:
		return
	if textos.size() > 60:
		return
	var t := TextoFlotante.new()
	t.pos = pos + Vector2(randf_range(-6, 6), 0)
	t.texto = str(roundi(valor))
	t.color = Color("fff078") if critico else Color("e8f4ff")
	t.tam = 9 if critico else 6
	t.vida = 0.55
	t.maxv = 0.55
	t.numero = true
	textos.append(t)

func actualizar(dt: float) -> void:
	for p in particulas:
		p.vida -= dt
		p.pos += p.vel * dt
		p.vel *= pow(p.arrastre, dt * 60.0)
		p.tam = maxf(0.2, p.tam + p.crece * dt)
		p.rot += p.giro * dt
		if p.tipo == HUMO:
			p.vel.y -= 6.0 * dt
		elif p.tipo == BRASA:
			p.vel += Vector2(randf_range(-40, 40), randf_range(-40, 40)) * dt
	particulas = particulas.filter(func(p): return p.vida > 0.0)
	for r in anillos:
		r.vida -= dt
	anillos = anillos.filter(func(r): return r.vida > 0.0)
	for t in textos:
		t.vida -= dt
		t.pos.y -= (26.0 if t.numero else 9.0) * dt
	textos = textos.filter(func(t): return t.vida > 0.0)
	if not retardadas.is_empty():
		var listas := []
		for x in retardadas:
			x.t -= dt
			if x.t <= 0.0:
				listas.append(x)
		retardadas = retardadas.filter(func(x): return x.t > 0.0)
		for x in listas:
			explosion(x.pos, x.tam, x.color, false)
			Audio.sfx("explosion", -5.0)
	destello_pantalla = maxf(0.0, destello_pantalla - dt * 2.5)

func limpiar() -> void:
	particulas.clear()
	anillos.clear()
	textos.clear()
	retardadas.clear()
	sacudida_pedida = 0.0
	destello_pantalla = 0.0

# ---------------------------------------------------------------- dibujo
func dibujar_base(ci: CanvasItem) -> void:
	for p in particulas:
		var a := clampf(p.vida / p.maxv, 0.0, 1.0)
		match p.tipo:
			HUMO:
				var c := p.color
				c.a *= a * 0.8
				ci.draw_circle(p.pos, p.tam, c)
			PIXEL:
				var c := p.color
				c.a = a
				ci.draw_rect(Rect2(p.pos - Vector2(p.tam, p.tam) * 0.5, Vector2(p.tam, p.tam)), c)
			ESCOMBRO:
				var c := p.color
				c.a = minf(1.0, a * 1.5)
				ci.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				ci.draw_rect(Rect2(-p.tam, -p.tam * 0.5, p.tam * 2.0, p.tam), c)
				ci.draw_rect(Rect2(-p.tam, -p.tam * 0.5, p.tam * 2.0, 1.0), Color(0.7, 0.65, 0.7, c.a))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			FRAGMENTO:
				ci.draw_set_transform(p.pos, p.rot, Vector2(p.escala, p.escala))
				# se va quemando: pasa de su color a rojo oscuro y se desvanece
				var c := Color(1, 0.55 + 0.45 * a, 0.45 + 0.55 * a, minf(1.0, a * 1.6))
				ci.draw_texture_rect_region(p.tex, Rect2(-p.region.size * 0.5, p.region.size), p.region, c)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func dibujar_brillo(ci: CanvasItem) -> void:
	var brillo := Datos.tex_brillo
	for p in particulas:
		var a := clampf(p.vida / p.maxv, 0.0, 1.0)
		match p.tipo:
			CHISPA:
				var c := p.color
				c.a = a
				var largo := p.vel * 0.035
				ci.draw_line(p.pos - largo, p.pos, c, p.tam)
			FUEGO:
				var idx := clampf((1.0 - a) * (RAMPA_FUEGO.size() - 1), 0, RAMPA_FUEGO.size() - 1.001)
				var c: Color = RAMPA_FUEGO[int(idx)].lerp(RAMPA_FUEGO[int(idx) + 1], idx - int(idx))
				c.a = a * 0.9
				var s := p.tam * 2.4
				ci.draw_texture_rect(brillo, Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, c)
			DESTELLO:
				var c := p.color
				c.a = a * a
				var s := p.tam * 2.0 * (1.0 + (1.0 - a) * 0.4)
				ci.draw_texture_rect(brillo, Rect2(p.pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, c)
			BRASA:
				var c := p.color
				c.a = a * (0.6 + 0.4 * sin(p.vida * 40.0))
				ci.draw_rect(Rect2(p.pos - Vector2(p.tam, p.tam) * 0.5, Vector2(p.tam, p.tam)), c)
				ci.draw_texture_rect(brillo, Rect2(p.pos - Vector2(4, 4), Vector2(8, 8)), false, Color(c, c.a * 0.5))
			FRAGMENTO:
				# borde incandescente del trozo
				ci.draw_texture_rect(brillo, Rect2(p.pos - Vector2(10, 10), Vector2(20, 20)), false, Color(1, 0.5, 0.2, a * 0.5))
	for r in anillos:
		var a := clampf(r.vida / r.maxv, 0.0, 1.0)
		var e := 1.0 - pow(a, 2.2)
		var c := r.color
		if r.relleno:
			c.a = a * 0.35
			var s := maxf(2.0, r.radio_max * e) * 2.0
			ci.draw_texture_rect(brillo, Rect2(r.pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, c)
			continue
		c.a = a
		ci.draw_arc(r.pos, maxf(2.0, r.radio_max * e), 0, TAU, 48, c, maxf(1.0, r.ancho * a), true)

func dibujar_textos(ci: CanvasItem) -> void:
	var f := Datos.fuente
	for t in textos:
		var a := clampf(t.vida / t.maxv, 0.0, 1.0)
		var edad := 1.0 - a
		var esc := 1.0
		if not t.numero:
			# entra con un "pop" y se encoge un poco al final
			esc = 0.6 + minf(1.0, edad / 0.12) * 0.55 - maxf(0.0, edad - 0.12) * 0.25
		var ancho := f.get_string_size(t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t.tam).x
		ci.draw_set_transform(t.pos, t.gira, Vector2(esc, esc))
		var o := Vector2(-ancho * 0.5, t.tam * 0.5)
		var sombra := Color(0.02, 0.02, 0.06, a)
		ci.draw_string_outline(f, o + Vector2(1, 2), t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t.tam, maxi(2, t.tam / 4) + 2, sombra)
		ci.draw_string_outline(f, o, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t.tam, maxi(2, t.tam / 4), Color(0.06, 0.03, 0.1, a))
		var c := t.color
		c.a = a
		ci.draw_string(f, o, t.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t.tam, c)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
