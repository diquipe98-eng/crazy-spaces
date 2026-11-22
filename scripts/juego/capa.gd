extends Node2D
## Capa de dibujo del mundo. "nombre" decide qué dibuja Juego en ella.
@export var nombre := "base"

func _draw() -> void:
	var j = get_parent().get_parent()
	if j and j.has_method("dibujar") and j.N:
		j.dibujar(nombre, self)
