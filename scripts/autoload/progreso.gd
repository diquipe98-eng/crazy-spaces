extends Node
## Progreso persistente: récords y nave equipada (user://progreso.cfg).

const RUTA := "user://progreso.cfg"

var mejor_puntaje := 0
var mejor_tiempo := 0.0
var nave_equipada := "drift"
var registros: Array = []   ## [{puntaje, tiempo, nivel, jefes}] ordenados, máximo 5
var tutorial: Dictionary = {}   ## ventanas de tutorial ya vistas (id -> true)

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(RUTA) == OK:
		mejor_puntaje = c.get_value("records", "puntaje", 0)
		mejor_tiempo = c.get_value("records", "tiempo", 0.0)
		registros = c.get_value("records", "lista", [])
		nave_equipada = c.get_value("hangar", "nave", "drift")
		tutorial = c.get_value("tutorial", "visto", {})
	if not nave_desbloqueada(nave_equipada):
		nave_equipada = "drift"

## "Repetir tutorial" del menú: la próxima partida vuelve a ser de aprendizaje.
func reiniciar_tutorial() -> void:
	tutorial = {}
	guardar()

## Las pruebas automáticas lo desactivan para no tocar los récords reales.
var guardado_activo := true

func guardar() -> void:
	if not guardado_activo:
		return
	var c := ConfigFile.new()
	c.set_value("records", "puntaje", mejor_puntaje)
	c.set_value("records", "tiempo", mejor_tiempo)
	c.set_value("records", "lista", registros)
	c.set_value("hangar", "nave", nave_equipada)
	c.set_value("tutorial", "visto", tutorial)
	c.save(RUTA)

func tutorial_visto(id: String) -> bool:
	return tutorial.has(id)

func marcar_tutorial(id: String) -> void:
	tutorial[id] = true
	guardar()

## Las pruebas automáticas lo usan para que no salgan las ventanas.
func saltar_tutorial() -> void:
	for id in ["controles", "mecanicas", "nivel", "jefe"]:
		tutorial[id] = true

func nave_desbloqueada(id: String) -> bool:
	return mejor_puntaje >= int(Datos.nave(id).puntaje)

## Registra una partida. Devuelve true si es nuevo récord de puntaje.
func registrar(puntaje: int, tiempo: float, nivel: int, jefes: int) -> bool:
	var nuevo := puntaje > mejor_puntaje
	mejor_puntaje = max(mejor_puntaje, puntaje)
	mejor_tiempo = max(mejor_tiempo, tiempo)
	registros.append({"puntaje": puntaje, "tiempo": tiempo, "nivel": nivel, "jefes": jefes})
	registros.sort_custom(func(a, b): return a.puntaje > b.puntaje)
	registros = registros.slice(0, 5)
	guardar()
	return nuevo

static func formato_tiempo(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]
