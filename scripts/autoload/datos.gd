extends Node
## Datos de diseño y balance de Crazy Space's.
## Todo lo que se ajusta "a ojo" vive aquí: dificultad, enemigos, mejoras,
## potenciadores, jefes y naves. La lógica lee estos valores; no los repite.

# ---------------------------------------------------------------------------
# Dificultad (curva de la v26 del HTML, validada en simulación)
# ---------------------------------------------------------------------------
## Segundos que tarda la amenaza en subir 1 punto. Más bajo = más difícil.
const SEGUNDOS_POR_AMENAZA := 55.0
## Tope de enemigos vivos a la vez (rendimiento en teléfonos).
const MAX_ENEMIGOS := 48
const MAX_BALAS_ENEMIGAS := 320
const MAX_PARTICULAS := 700

## Zoom de la cámara: menor que 1 muestra más espacio alrededor de la nave.
const ZOOM_CAMARA := 0.68

# ---------------------------------------------------------------------------
# Jefes
# ---------------------------------------------------------------------------
const PRIMER_JEFE_SEG := 90.0
const JEFE_CADA_SEG := 120.0          ## tras derrotar al anterior
const JEFE_ESPERA_MAX_SEG := 20.0     ## si el jugador no cumple requisitos, sale igual tras esta espera
const JEFE_SEGUNDOS_OBJETIVO := 40.0  ## duración aproximada del duelo con el daño real del jugador
const JEFE_VIDA_MIN := 2600.0
const JEFE_VIDA_MAX := 280000.0
const JEFE_FASE2_UMBRAL := 0.55       ## fracción de vida donde entra la fase 2

## Cinco jefes en orden de dificultad; después del quinto el ciclo se repite
## más rápido y agresivo (+8% por vuelta).
## movimiento:
##   barrido  – vaivén lento y amplio (fácil de leer)
##   ocho     – recorre un ocho y se cruza con el jugador
##   orbita   – rodea la mitad alta de la arena y cambia de sentido
##   acecho   – sigue tu posición horizontal y embiste a menudo
##   salto    – se desvanece y reaparece en otro punto (avisa con un brillo)
## Bocas de fuego en píxeles de la textura, relativas a su centro.
const JEFES := [
	{
		"id": "centinela", "nombre": "CENTINELA", "textura": "res://art/jefes/centinela.png",
		"escala": 0.3, "radio": 56.0, "color": Color("ff9a3c"), "dificultad": 1,
		"movimiento": "barrido", "vel_mov": 0.8, "vida_mult": 0.85, "bala_mult": 0.85, "pausa_mult": 1.25,
		"nucleo": Vector2(2, 14), "canones": [Vector2(-202, 178), Vector2(202, 178)], "alas": [Vector2(-250, 18), Vector2(250, 18)],
		"patrones_f1": ["abanico", "anillo", "rafaga"],
		"patrones_f2": ["abanico", "barrera", "anillo", "rafaga", "cruz"],
	},
	{
		"id": "mecanico", "nombre": "JEFE MECÁNICO", "textura": "res://art/jefes/mecanico.png",
		"escala": 0.29, "radio": 60.0, "color": Color("ff5c79"), "dificultad": 2,
		"movimiento": "ocho", "vel_mov": 1.0, "vida_mult": 1.0, "bala_mult": 0.95, "pausa_mult": 1.1,
		"nucleo": Vector2(0, 10), "canones": [Vector2(-100, -27), Vector2(100, -27)], "alas": [Vector2(-294, 5), Vector2(294, 5)],
		"patrones_f1": ["misiles", "abanico", "embestida", "anillo", "rafaga"],
		"patrones_f2": ["misiles", "espiral", "embestida", "abanico", "nova", "misiles", "embestida"],
	},
	{
		"id": "colmena", "nombre": "REINA COLMENA", "textura": "res://art/jefes/colmena.png",
		"escala": 0.31, "radio": 60.0, "color": Color("7dff6a"), "dificultad": 3,
		"movimiento": "orbita", "vel_mov": 1.0, "vida_mult": 1.1, "bala_mult": 1.0, "pausa_mult": 1.0,
		"nucleo": Vector2(2, -26), "canones": [Vector2(-78, 214), Vector2(78, 214)], "alas": [Vector2(-318, -110), Vector2(318, -110)],
		"patrones_f1": ["invocar", "lluvia", "anillo", "abanico"],
		"patrones_f2": ["invocar", "espiral", "lluvia", "barrera", "nova", "abanico"],
	},
	{
		"id": "overlord", "nombre": "OVERLORD", "textura": "res://art/jefes/overlord.png",
		"escala": 0.235, "radio": 62.0, "color": Color("ff3d5a"), "dificultad": 4,
		"movimiento": "acecho", "vel_mov": 1.1, "vida_mult": 1.2, "bala_mult": 1.05, "pausa_mult": 0.9,
		"nucleo": Vector2(0, 2), "canones": [Vector2(-118, 111), Vector2(118, 111)], "alas": [Vector2(-368, -2), Vector2(368, -2)],
		"patrones_f1": ["anillo", "rafaga", "embestida", "cruz", "nova"],
		"patrones_f2": ["rafaga", "espiral", "embestida", "anillo", "cruz", "nova", "embestida"],
	},
	{
		"id": "vacio", "nombre": "NÚCLEO DEL VACÍO", "textura": "res://art/jefes/vacio.png",
		"escala": 0.32, "radio": 64.0, "color": Color("ff4ab8"), "dificultad": 5,
		"movimiento": "salto", "vel_mov": 1.2, "vida_mult": 1.35, "bala_mult": 1.12, "pausa_mult": 0.8,
		"nucleo": Vector2(-2, -2), "canones": [Vector2(-222, 128), Vector2(222, 128)], "alas": [Vector2(-230, -2), Vector2(230, -2)],
		"patrones_f1": ["salto", "espiral", "nova", "barrera", "cruz"],
		"patrones_f2": ["salto", "espiral", "barrera", "nova", "salto", "cruz", "anillo"],
	},
]

# ---------------------------------------------------------------------------
# Jugador
# ---------------------------------------------------------------------------
const JUGADOR_BASE := {
	"vida": 5, "dano": 18.0, "cadencia": 2.0, "disparos": 1, "dispersion": 0.16,
	"perforacion": 0, "vel_bala": 510.0, "vel_max": 218.0, "iman": 105.0,
	"escudo_recarga": 8.5, "dash_recarga": 5.0,
}
const VELOCIDAD_A_MUNDO := 1.0 / 0.68   ## la velocidad base está pensada para el zoom del HTML
const DASH_DURACION := 0.19
const DASH_MULT := 3.65
const XP_INICIAL := 40
const REPARAR_COSTO_INICIAL := 18
const REPARAR_COSTO_SUBE := 6
const REROLL_COSTO_INICIAL := 10
const REROLL_COSTO_SUBE := 5

static func xp_para_nivel(nivel: int) -> int:
	return roundi(36 + nivel * 10 + pow(nivel, 1.22) * 1.7)

# ---------------------------------------------------------------------------
# Enemigos (sprites mirando hacia abajo, 5 variantes por tipo)
# ---------------------------------------------------------------------------
const ENEMIGOS := {
	"grunt":  {"nombre": "Saqueador", "vida": 30.0,  "vel": 180.0, "xp": 1, "pts": 10, "escala": 0.44, "color": Color("ff8b9a"), "amenaza": 1.0, "peso": 34},
	"weaver": {"nombre": "Tejedora",  "vida": 28.0,  "vel": 195.0, "xp": 1, "pts": 14, "escala": 0.48, "color": Color("ee9cff"), "amenaza": 1.0, "peso": 24},
	"gunner": {"nombre": "Artillero", "vida": 62.0,  "vel": 115.0, "xp": 2, "pts": 24, "escala": 0.50, "color": Color("ffb65c"), "amenaza": 1.5, "peso": 19},
	"diver":  {"nombre": "Picador",   "vida": 38.0,  "vel": 145.0, "xp": 2, "pts": 20, "escala": 0.46, "color": Color("b4ef75"), "amenaza": 2.2, "peso": 14},
	"tank":   {"nombre": "Coloso",    "vida": 180.0, "vel": 92.0,  "xp": 4, "pts": 60, "escala": 0.53, "color": Color("a99bff"), "amenaza": 3.0, "peso": 9},
}

# ---------------------------------------------------------------------------
# Mejoras permanentes (pantalla de nivel). rar: 0 común, 1 rara, 2 épica.
# "arma": true las muestra en el arsenal del HUD con su nivel.
# ---------------------------------------------------------------------------
const RAREZAS := [
	{"nombre": "COMÚN", "color": Color("9fb0d8")},
	{"nombre": "RARA", "color": Color("55a7ff")},
	{"nombre": "ÉPICA", "color": Color("d178ff")},
]
const PROB_RAREZA_NORMAL := [64.0, 28.0, 8.0]
const PROB_RAREZA_JEFE := [20.0, 50.0, 30.0]

const MEJORAS := [
	{"id": "dmg", "n": "Núcleo de impacto", "d": "+18% de daño de todos tus proyectiles", "rar": 0, "max": 8},
	{"id": "rate", "n": "Disparador acelerado", "d": "+16% de velocidad de ataque", "rar": 0, "max": 8},
	{"id": "speed", "n": "Propulsores ligeros", "d": "+12% de velocidad de movimiento", "rar": 0, "max": 5},
	{"id": "hp", "n": "Blindaje reforzado", "d": "+1 vida máxima y recuperas 1 vida", "rar": 0, "max": 5},
	{"id": "heal", "n": "Nanorreparación", "d": "Recuperas 2 vidas", "rar": 0, "max": 99, "cond": "herido2"},
	{"id": "magnet", "n": "Campo magnético", "d": "+55 de alcance para atraer experiencia y chatarra", "rar": 0, "max": 4},
	{"id": "xp", "n": "Matriz de aprendizaje", "d": "+15% de experiencia obtenida", "rar": 0, "max": 5},
	{"id": "crit", "n": "Mira de precisión", "d": "+10% de crítico y +25% de daño crítico", "rar": 1, "max": 5},
	{"id": "multi", "n": "Cañón múltiple", "d": "+1 cañón paralelo. Todos los proyectiles dan en el blanco", "rar": 1, "max": 4, "arma": "laser"},
	{"id": "pierce", "n": "Munición perforante", "d": "Cada proyectil atraviesa +1 enemigo sin perder daño", "rar": 1, "max": 3},
	{"id": "shield", "n": "Escudo de plasma", "d": "+1 carga de escudo. Bloquea un impacto y se recarga sola", "rar": 1, "max": 3},
	{"id": "drone", "n": "Dron de apoyo", "d": "+1 dron. Cada dron elige su propio blanco y dispara más rápido", "rar": 1, "max": 3, "arma": "dron"},
	{"id": "orbit", "n": "Satélite de defensa", "d": "+1 orbe que golpea, empuja y destruye balas enemigas", "rar": 1, "max": 3, "arma": "orbita"},
	{"id": "nova", "n": "Pulso expansivo", "d": "Onda periódica que daña, empuja y borra balas. Más grande por nivel", "rar": 1, "max": 3, "arma": "nova"},
	{"id": "missile", "n": "Misiles rastreadores", "d": "Salva de misiles guiados a blancos distintos (+1 misil por nivel)", "rar": 2, "max": 3, "arma": "misil"},
	{"id": "bomb", "n": "Bomba de fragmentación", "d": "Lanza una bomba al grupo más denso de enemigos", "rar": 2, "max": 3, "arma": "bomba"},
	{"id": "explode", "n": "Núcleo inestable", "d": "Los enemigos destruidos explotan y encadenan explosiones", "rar": 2, "max": 3},
	{"id": "leech", "n": "Recuperación de emergencia", "d": "+3% de probabilidad de recuperar 1 vida por baja", "rar": 2, "max": 4},
	{"id": "glass", "n": "Cañón de cristal", "d": "+70% de daño, pero −1 vida máxima", "rar": 2, "max": 1, "cond": "vida_mayor_1"},
	{"id": "overclock", "n": "Sobrecarga del núcleo", "d": "+8% de daño. Siempre disponible", "rar": 0, "max": 99},
]

## Orden y arte de las ranuras del arsenal (armas permanentes).
const ARSENAL := [
	{"id": "laser", "icono": "res://art/hud/laser.png", "color": Color("4fb6ff")},
	{"id": "misil", "icono": "res://art/hud/rocket.png", "color": Color("4f7fd8")},
	{"id": "bomba", "icono": "res://art/hud/bomb.png", "color": Color("4f7fd8")},
	{"id": "nova", "icono": "res://art/hud/nova.png", "color": Color("8f6bff")},
	{"id": "dron", "icono": "res://art/hud/plus.png", "color": Color("3fe08a")},
	{"id": "orbita", "icono": "res://art/hud/nova.png", "color": Color("d78cff")},
]

# ---------------------------------------------------------------------------
# Potenciadores del campo
#  tipo "instantaneo": se aplica al tocarlo, no se acumula.
#  tipo "temporal": dura "dur" segundos; recoger otro SUMA "dur" hasta "tope".
#  tipo "carga": suma cargas hasta un límite.
# El HUD muestra los temporales con su cuenta atrás; las cargas en la barra de escudo.
# ---------------------------------------------------------------------------
const POTENCIADORES := {
	"reparacion": {"nombre": "REPARACIÓN", "tipo": "instantaneo", "color": Color("7dff9b"), "icono": "res://art/potenciadores/reparacion.png",
		"desc": "+1 vida. Con la vida llena: +1 escudo o +15 chatarra"},
	"escudo": {"nombre": "ESCUDO", "tipo": "carga", "color": Color("70dfff"), "icono": "res://art/potenciadores/escudo.png",
		"desc": "+1 carga de escudo (la capacidad sube hasta 3 por potenciadores)", "tope_capacidad": 3},
	"sobrecarga": {"nombre": "SOBRECARGA", "tipo": "temporal", "color": Color("ffe36b"), "icono": "res://art/potenciadores/sobrecarga.png",
		"desc": "Cadencia x1.75", "dur": 8.0, "tope": 20.0, "mult": 1.75},
	"impulso": {"nombre": "IMPULSO", "tipo": "temporal", "color": Color("ff9b5e"), "icono": "res://art/potenciadores/impulso.png",
		"desc": "Velocidad x1.4", "dur": 8.0, "tope": 20.0, "mult": 1.4},
	"iman": {"nombre": "IMÁN", "tipo": "temporal", "color": Color("72eaff"), "icono": "res://art/potenciadores/iman.png",
		"desc": "Atrae toda la XP, chatarra y potenciadores", "dur": 6.0, "tope": 15.0},
	"nova": {"nombre": "PULSO NOVA", "tipo": "instantaneo", "color": Color("d99aff"), "icono": "res://art/potenciadores/nova.png",
		"desc": "Onda de daño que borra balas enemigas"},
}
## Aparición: primero a los 15 s; luego cada INTERVALO segundos (se acorta con la amenaza).
const POT_PRIMERO_SEG := 15.0
const POT_INTERVALO_INICIAL := Vector2(18.0, 26.0)
const POT_INTERVALO_FINAL := Vector2(12.0, 18.0)
const POT_MAX_EN_CAMPO := 2
const POT_VIDA_SEG := 15.0
const POT_EN_JEFE_CADA_SEG := 20.0     ## durante el jefe solo salen de supervivencia
const POT_EN_JEFE := ["reparacion", "escudo", "sobrecarga"]

# ---------------------------------------------------------------------------
# Naves del hangar (se desbloquean por récord de puntaje)
# ---------------------------------------------------------------------------
## Cada nave desbloqueada es una mejora real: mejores estadísticas base y un rasgo.
## "mod": multiplicadores (1.0 = igual que la NOVA MK.I) y sumas sobre la base.
## "inicio": mejoras con las que empieza la partida (cuentan para su nivel).
const NAVES := [
	{"id": "drift", "nombre": "NOVA MK.I", "puntaje": 0, "color": Color("5ad1ff"),
		"mod": {}, "inicio": [], "rasgo": "Equilibrada. Sin rasgo especial."},
	{"id": "comet", "nombre": "COMETA", "puntaje": 700, "color": Color("ff9d59"),
		"mod": {"vel": 1.12, "dash": 0.7, "dano": 1.05}, "inicio": [], "rasgo": "Dash cada 3.5 s y más velocidad."},
	{"id": "spectra", "nombre": "SPECTRA", "puntaje": 1500, "color": Color("c58cff"),
		"mod": {"dano": 1.1, "crit": 0.12, "cadencia": 1.05}, "inicio": [], "rasgo": "+12% de crítico desde el inicio."},
	{"id": "vortex", "nombre": "VÓRTICE", "puntaje": 2600, "color": Color("70e9cf"),
		"mod": {"dano": 1.1, "cadencia": 1.08, "vida": 1}, "inicio": ["drone"], "rasgo": "Empieza con un dron de apoyo."},
	{"id": "manta", "nombre": "MANTA-7", "puntaje": 4100, "color": Color("50e5ec"),
		"mod": {"dano": 1.18, "vel": 1.08, "perfora": 1, "vel_bala": 1.2, "vida": 1}, "inicio": [], "rasgo": "Sus disparos atraviesan 1 enemigo."},
	{"id": "bastion", "nombre": "BASTIÓN", "puntaje": 6000, "color": Color("e6bd61"),
		"mod": {"dano": 1.2, "vida": 3, "escudo": 1, "vel": 0.95}, "inicio": [], "rasgo": "+3 vidas y 1 escudo que se recarga."},
	{"id": "wraith", "nombre": "ESPECTRO", "puntaje": 8200, "color": Color("aaa0dd"),
		"mod": {"dano": 1.25, "cadencia": 1.15, "vel": 1.15, "dash": 0.75, "vida": 1}, "inicio": ["orbit"], "rasgo": "Rápida, con un satélite orbital."},
	{"id": "phoenix", "nombre": "FÉNIX", "puntaje": 10800, "color": Color("ff806d"),
		"mod": {"dano": 1.3, "cadencia": 1.1, "vida": 2, "revivir": 1}, "inicio": [], "rasgo": "Renace una vez con 3 vidas y un pulso nova."},
	{"id": "leviathan", "nombre": "LEVIATÁN", "puntaje": 14200, "color": Color("79b5e7"),
		"mod": {"dano": 1.38, "cadencia": 1.12, "vida": 2, "escudo": 1}, "inicio": ["missile"], "rasgo": "Empieza con misiles rastreadores."},
	{"id": "eclipse", "nombre": "ECLIPSE", "puntaje": 18500, "color": Color("de7bff"),
		"mod": {"dano": 1.45, "cadencia": 1.2, "vel": 1.1, "vida": 2, "escudo": 1, "crit": 0.08}, "inicio": ["multi", "nova"], "rasgo": "Cañón doble y pulso nova desde el inicio."},
]
## Hojas de giro 3D del hangar: 24 cuadros en 6 columnas.
const GIRO_CUADROS := 24
const GIRO_COLUMNAS := 6
const GIRO_TAM := {
	"drift": Vector2i(135, 103), "comet": Vector2i(126, 97), "spectra": Vector2i(132, 102),
	"vortex": Vector2i(130, 100), "manta": Vector2i(131, 100), "bastion": Vector2i(127, 98),
	"wraith": Vector2i(136, 105), "phoenix": Vector2i(127, 97), "leviathan": Vector2i(127, 97),
	"eclipse": Vector2i(129, 99),
}

# ---------------------------------------------------------------------------
# Donaciones: enlace de Ko-fi, PayPal.me, Buy Me a Coffee, etc.
# Mientras esté vacío, el botón APOYAR no aparece.
# ---------------------------------------------------------------------------
const URL_DONACIONES := ""

static func abrir_donaciones() -> void:
	if URL_DONACIONES != "":
		OS.shell_open(URL_DONACIONES)

# ---------------------------------------------------------------------------
# Recursos compartidos
# ---------------------------------------------------------------------------
var fuente: FontFile
var tex_brillo: Texture2D       ## halo radial blanco para luces aditivas
var _cache_tex := {}
var _cache_silueta := {}

func _ready() -> void:
	# Fuente pixel nítida (sin antialias) para toda la interfaz.
	fuente = load("res://art/fuente/CrazyPixel-Regular.ttf")
	fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fuente.hinting = TextServer.HINTING_NONE
	fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ThemeDB.fallback_font = fuente
	ThemeDB.fallback_font_size = 8
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	tex_brillo = gt

func tex(ruta: String) -> Texture2D:
	if not _cache_tex.has(ruta):
		_cache_tex[ruta] = load(ruta)
	return _cache_tex[ruta]

## Silueta blanca de una textura (destello de impacto). Se calcula una vez.
func silueta(ruta: String) -> Texture2D:
	if _cache_silueta.has(ruta):
		return _cache_silueta[ruta]
	var img: Image = tex(ruta).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var datos := img.get_data()
	for i in range(0, datos.size(), 4):
		if datos[i + 3] > 0:
			datos[i] = 255
			datos[i + 1] = 255
			datos[i + 2] = 255
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, datos)
	var t := ImageTexture.create_from_image(out)
	_cache_silueta[ruta] = t
	return t

func mejora(id: String) -> Dictionary:
	for m in MEJORAS:
		if m.id == id:
			return m
	return {}

func nave(id: String) -> Dictionary:
	for n in NAVES:
		if n.id == id:
			return n
	return NAVES[0]
