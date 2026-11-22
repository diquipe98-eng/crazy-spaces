extends SceneTree
## Carga todos los scripts y escenas del proyecto para detectar errores de análisis.

func _init() -> void:
	var fallos := 0
	for r in _buscar("res://scripts") + _buscar("res://tests"):
		if r.ends_with(".gd") and r != "res://tests/compilar.gd":
			var s = load(r)
			if s == null or not s.can_instantiate() and not r.contains("tipos") and not r.contains("generador") and not r.contains("dibujo") and not r.contains("texto.gd"):
				print("FALLO ", r)
				fallos += 1
	for r in _buscar("res://scenes"):
		if r.ends_with(".tscn") and load(r) == null:
			print("FALLO ", r)
			fallos += 1
	print("scripts con fallo: ", fallos)
	quit(1 if fallos else 0)

func _buscar(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for s in d.get_directories():
		out += _buscar(dir + "/" + s)
	return out
