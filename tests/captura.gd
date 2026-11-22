extends "res://tests/prueba.gd"
## Igual que la prueba, pero guarda capturas en user://capturas/ en momentos clave.
## godot --path . res://tests/captura.tscn --fixed-fps 30 -- --tactil

var _hechas := {}
var _espera := 0

func _foto(nombre: String) -> void:
	if _hechas.has(nombre):
		return
	_hechas[nombre] = true
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://capturas/%s.png" % nombre)
	print("captura ", nombre, " ", ProjectSettings.globalize_path("user://capturas/%s.png" % nombre))

func _process(delta: float) -> void:
	# deja ver la pantalla de mejora y la de fin un momento antes de seguir
	for k in ["mejora", "fin"]:
		if juego and juego.N and juego.estado == k and not _hechas.has(k):
			_espera += 1
			if _espera < 30:
				return
			_espera = 0
			_foto(k)
	super(delta)
	if juego == null or juego.N == null:
		return
	var t: float = juego.tiempo
	if t > 40.0: _foto("oleada")
	if t > 75.0: _foto("oleada_tarde")
	if juego.jefe and juego.jefe.estado == "carga" and juego.jefe.asentado: _foto("jefe_carga")
	if juego.jefe and juego.jefe.estado == "embestida": _foto("jefe_embestida")
	if juego.jefe and juego.jefe.fase_jefe == 2 and juego.balas_enemigas.size() > 30: _foto("jefe_fase2")
	if t > 250.0: _foto("tarde")
