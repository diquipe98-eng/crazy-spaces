extends Node
## Preferencias del jugador, guardadas en user://ajustes.cfg.

signal cambiados

const RUTA := "user://ajustes.cfg"

## "joystick": joystick flotante donde toques en la mitad izquierda.
## "arrastre": arrastra el dedo en cualquier parte y la nave copia el movimiento.
var modo_control := "joystick"
var sensibilidad_arrastre := 1.25
var tamano_joystick := 1.0
var opacidad_controles := 0.7
var vibracion := true
var vol_musica := 0.8
var vol_efectos := 0.9
var mostrar_danos := true
## Muestra los controles táctiles también en PC (pantallas táctiles de portátil o pruebas).
var tactil_siempre := false
## Intensidad de la sacudida de pantalla (0 = desactivada).
var sacudida := 1.0

func _ready() -> void:
	cargar()

func es_tactil() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or _forzar_tactil or tactil_siempre

var _forzar_tactil := false
## Permite probar los controles táctiles en PC (ajuste oculto / pruebas).
func forzar_tactil(valor: bool) -> void:
	_forzar_tactil = valor

func cargar() -> void:
	var c := ConfigFile.new()
	if c.load(RUTA) != OK:
		return
	modo_control = c.get_value("controles", "modo", modo_control)
	sensibilidad_arrastre = c.get_value("controles", "sensibilidad", sensibilidad_arrastre)
	tamano_joystick = c.get_value("controles", "tamano_joystick", tamano_joystick)
	opacidad_controles = c.get_value("controles", "opacidad", opacidad_controles)
	vibracion = c.get_value("controles", "vibracion", vibracion)
	vol_musica = c.get_value("audio", "musica", vol_musica)
	vol_efectos = c.get_value("audio", "efectos", vol_efectos)
	mostrar_danos = c.get_value("pantalla", "danos", mostrar_danos)
	tactil_siempre = c.get_value("controles", "tactil_siempre", tactil_siempre)
	sacudida = c.get_value("pantalla", "sacudida", sacudida)

func guardar() -> void:
	var c := ConfigFile.new()
	c.set_value("controles", "modo", modo_control)
	c.set_value("controles", "sensibilidad", sensibilidad_arrastre)
	c.set_value("controles", "tamano_joystick", tamano_joystick)
	c.set_value("controles", "opacidad", opacidad_controles)
	c.set_value("controles", "vibracion", vibracion)
	c.set_value("audio", "musica", vol_musica)
	c.set_value("audio", "efectos", vol_efectos)
	c.set_value("pantalla", "danos", mostrar_danos)
	c.set_value("controles", "tactil_siempre", tactil_siempre)
	c.set_value("pantalla", "sacudida", sacudida)
	c.save(RUTA)
	cambiados.emit()

## Vibración corta en teléfonos (no hace nada en PC).
func vibrar(ms: int) -> void:
	if vibracion and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
