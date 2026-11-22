class_name PanelAjustes
extends GridContainer
## Ajustes compartidos por el menú y la pausa. Cada botón cicla su valor
## con un toque (cómodo en el teléfono) y se guarda al momento.

const OPCIONES := [
	["modo_control", "CONTROL", ["joystick", "arrastre"], {"joystick": "JOYSTICK", "arrastre": "ARRASTRE"}],
	["sensibilidad_arrastre", "SENSIBILIDAD", [0.8, 1.0, 1.25, 1.5, 1.8], {}],
	["tamano_joystick", "TAMAÑO JOYSTICK", [0.8, 1.0, 1.2, 1.4], {}],
	["opacidad_controles", "OPACIDAD", [0.4, 0.55, 0.7, 0.85, 1.0], {}],
	["vol_musica", "MÚSICA", [0.0, 0.2, 0.4, 0.6, 0.8, 1.0], {}],
	["vol_efectos", "EFECTOS", [0.0, 0.2, 0.4, 0.6, 0.8, 1.0], {}],
	["vibracion", "VIBRACIÓN", [true, false], {}],
	["mostrar_danos", "NÚMEROS DE DAÑO", [true, false], {}],
	["sacudida", "SACUDIDA", [1.0, 1.5, 0.0, 0.5], {}],
	["tactil_siempre", "CONTROLES TÁCTILES", [false, true], {false: "AUTO", true: "SIEMPRE"}],
]

var _botones := {}

func _ready() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	for o in OPCIONES:
		var b := Boton.new("", Color("5ad1ff"), 7)
		b.custom_minimum_size = Vector2(150, 34)
		b.pulsado.connect(_ciclar.bind(o))
		add_child(b)
		_botones[o[0]] = b
	_refrescar()

func _texto_valor(o: Array, v) -> String:
	var etiquetas: Dictionary = o[3]
	if etiquetas.has(v):
		return etiquetas[v]
	if v is bool:
		return "SÍ" if v else "NO"
	if o[0].begins_with("vol_") or o[0] in ["opacidad_controles", "sacudida"]:
		return "%d%%" % roundi(v * 100.0)
	return "x%.2f" % v

func _ciclar(o: Array) -> void:
	var lista: Array = o[2]
	var actual = Ajustes.get(o[0])
	var i := 0
	for k in lista.size():
		if typeof(lista[k]) == typeof(actual) and (lista[k] == actual if not (actual is float) else is_equal_approx(lista[k], actual)):
			i = k
	Ajustes.set(o[0], lista[(i + 1) % lista.size()])
	Ajustes.guardar()
	Audio.aplicar_volumenes()
	_refrescar()

func _refrescar() -> void:
	for o in OPCIONES:
		var b: Boton = _botones[o[0]]
		b.texto = o[1]
		b.subtexto = _texto_valor(o, Ajustes.get(o[0]))
		var es_tactil_opt: bool = o[0] in ["sensibilidad_arrastre"]
		b.desactivado = es_tactil_opt and Ajustes.modo_control != "arrastre"
		if o[0] == "tamano_joystick":
			b.desactivado = Ajustes.modo_control != "joystick"
		b.queue_redraw()
