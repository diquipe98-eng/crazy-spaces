extends Node
## Conexión con la tabla de posiciones global (Supabase: Auth + funciones SQL de
## supabase/esquema.sql). Todas las llamadas son asíncronas y devuelven
## {"ok": bool, "datos": ..., "error": "texto para el jugador"}.
## Si Datos.SUPABASE_URL está vacío el juego funciona igual, sin tabla global.

signal sesion_cambiada
signal top_actualizado
signal pide_clave_nueva        ## abrió el enlace de "olvidé mi contraseña"

## Adonde vuelven los enlaces de los correos (confirmar cuenta / cambiar contraseña).
const URL_JUEGO := "https://diquipe98-eng.github.io/crazy-spaces/"
const RUTA_SESION := "user://sesion.cfg"

var url := ""
var clave := ""
# sesión
var token := ""
var refresco := ""
var expira := 0.0
var uid := ""
var nombre := ""
# caché para mostrar algo sin conexión
var top: Array = []
var top_hora := 0.0
var ultimo_puesto := 0         ## puesto global tras la última partida enviada
var pendientes: Array = []     ## partidas que no se pudieron enviar
var recuperando := false       ## entró con el enlace de recuperar: falta poner clave nueva

func _ready() -> void:
	url = Datos.SUPABASE_URL.trim_suffix("/")
	clave = Datos.SUPABASE_CLAVE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--servidor="):
			url = a.trim_prefix("--servidor=").trim_suffix("/")
		elif a.begins_with("--clave="):
			clave = a.trim_prefix("--clave=")
	_cargar()
	if conectado() and not pendientes.is_empty():
		_enviar_pendientes.call_deferred()
	if conectado():
		sincronizar_locales.call_deferred()
	if OS.has_feature("web"):
		_leer_enlace_correo.call_deferred()

func configurado() -> bool:
	return url != "" and clave != ""

func conectado() -> bool:
	return uid != ""

static func nombre_valido(n: String) -> String:
	var limpio := n.strip_edges().to_upper()
	if limpio.length() < 3 or limpio.length() > 14:
		return "El nombre debe tener entre 3 y 14 letras"
	var re := RegEx.create_from_string("^[A-Z0-9_]+$")
	if re.search(limpio) == null:
		return "Solo letras sin tilde, números y _"
	return ""

# ---------------------------------------------------------------- cuentas
static func correo_valido(c: String) -> bool:
	return RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$").search(c.strip_edges()) != null

## Crea la cuenta. datos = {"confirmar": true} si el servidor pide confirmar el correo
## (entonces no queda la sesión abierta hasta que el jugador abra el enlace).
func registrar(correo: String, n: String, clave_jugador: String) -> Dictionary:
	var mail := correo.strip_edges().to_lower()
	if not correo_valido(mail):
		return _fallo("Escribe un correo válido")
	var nom := n.strip_edges().to_upper()
	var falla := nombre_valido(nom)
	if falla != "":
		return _fallo(falla)
	if clave_jugador.length() < 6:
		return _fallo("La contraseña necesita al menos 6 caracteres")
	var libre := await _rpc("nombre_disponible", {"p_nombre": nom})
	if libre.ok and libre.datos == false:
		return _fallo("Ese nombre de piloto ya está en uso")
	var r := await _peticion(HTTPClient.METHOD_POST, "/auth/v1/signup?redirect_to=" + URL_JUEGO.uri_encode(),
		{"email": mail, "password": clave_jugador, "data": {"nombre": nom}})
	if not r.ok:
		return r
	if typeof(r.datos) != TYPE_DICTIONARY or not r.datos.has("access_token"):
		return {"ok": true, "datos": {"confirmar": true, "nombre": nom}}
	_guardar_sesion(r.datos, nom)
	await sincronizar_locales()
	return {"ok": true, "datos": {"confirmar": false, "nombre": nom}}

func entrar(correo: String, clave_jugador: String) -> Dictionary:
	var mail := correo.strip_edges().to_lower()
	if mail == "" or clave_jugador == "":
		return _fallo("Escribe tu correo y tu contraseña")
	if not correo_valido(mail):
		return _fallo("Escribe un correo válido")
	var r := await _peticion(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": mail, "password": clave_jugador})
	if not r.ok:
		return r
	var meta: Dictionary = r.datos.get("user", {}).get("user_metadata", {})
	_guardar_sesion(r.datos, String(meta.get("nombre", "")))
	await sincronizar_locales()
	return {"ok": true, "datos": nombre}

## Envía el correo para cambiar la contraseña.
func recuperar(correo: String) -> Dictionary:
	var mail := correo.strip_edges().to_lower()
	if not correo_valido(mail):
		return _fallo("Escribe un correo válido")
	return await _peticion(HTTPClient.METHOD_POST, "/auth/v1/recover?redirect_to=" + URL_JUEGO.uri_encode(), {"email": mail})

## Pone la contraseña nueva (tras abrir el enlace de recuperar).
func cambiar_clave(nueva: String) -> Dictionary:
	if nueva.length() < 6:
		return _fallo("La contraseña necesita al menos 6 caracteres")
	if not await _asegurar_token():
		return _fallo("El enlace caducó: pide otro correo", 401)
	var r := await _peticion(HTTPClient.METHOD_PUT, "/auth/v1/user", {"password": nueva}, true)
	if r.ok:
		recuperando = false
	return r

## Los enlaces de los correos vuelven al juego con la sesión en la dirección
## (#access_token=...&type=signup|recovery). Se usa y se borra de la barra.
func _leer_enlace_correo() -> void:
	var frag := String(JavaScriptBridge.eval("window.location.hash", true))
	if frag.length() < 2:
		return
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)", true)
	var p := {}
	for par in frag.substr(1).split("&"):
		var kv := par.split("=", true, 1)
		if kv.size() == 2:
			p[kv[0]] = kv[1].uri_decode()
	await aplicar_enlace(p)

## Separado para poder probarlo sin navegador.
func aplicar_enlace(p: Dictionary) -> void:
	if not p.has("access_token"):
		return
	token = String(p.access_token)
	refresco = String(p.get("refresh_token", ""))
	expira = Time.get_unix_time_from_system() + float(p.get("expires_in", 3600))
	var u := await _peticion(HTTPClient.METHOD_GET, "/auth/v1/user", null, true)
	if not u.ok or typeof(u.datos) != TYPE_DICTIONARY:
		token = ""; refresco = ""
		return
	var d := {"access_token": token, "refresh_token": refresco, "expires_in": float(p.get("expires_in", 3600)), "user": u.datos}
	_guardar_sesion(d, String(u.datos.get("user_metadata", {}).get("nombre", "")))
	sincronizar_locales()
	if String(p.get("type", "")) == "recovery":
		recuperando = true
		pide_clave_nueva.emit()

func salir() -> void:
	if conectado() and configurado():
		_peticion(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)   # sin esperar
	token = ""; refresco = ""; uid = ""; nombre = ""; expira = 0.0; ultimo_puesto = 0
	_guardar()
	sesion_cambiada.emit()

func _guardar_sesion(d: Dictionary, nom: String) -> void:
	token = String(d.get("access_token", ""))
	refresco = String(d.get("refresh_token", ""))
	expira = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	uid = String(d.get("user", {}).get("id", ""))
	nombre = nom.to_upper()
	if nombre != "" and Progreso.piloto != nombre:
		Progreso.cambiar_piloto(nombre)   # el nombre local sigue al de la cuenta
	_guardar()
	sesion_cambiada.emit()

## Renueva el token si está por vencer. Si el servidor lo rechaza, cierra la sesión.
func _asegurar_token() -> bool:
	if not conectado():
		return false
	if Time.get_unix_time_from_system() < expira - 60.0:
		return true
	var r := await _peticion(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresco})
	if r.ok:
		_guardar_sesion(r.datos, nombre)
		return true
	if r.get("codigo", 0) >= 400 and r.get("codigo", 0) < 500:
		salir()
	return false

# ---------------------------------------------------------------- tabla
func cargar_top() -> Dictionary:
	var r := await _rpc("top10", {})
	if r.ok and typeof(r.datos) == TYPE_ARRAY:
		top = r.datos
		top_hora = Time.get_unix_time_from_system()
		_guardar()
		top_actualizado.emit()
	return r

## Página de los marcadores (todos los pilotos). datos = {"filas": [...], "total": int}
func cargar_ranking(desde: int, cantidad := 10) -> Dictionary:
	var r := await _rpc("ranking", {"p_desde": desde, "p_cantidad": cantidad})
	if r.ok and typeof(r.datos) == TYPE_ARRAY:
		var total := int(r.datos[0].total) if r.datos.size() > 0 else 0
		if r.datos.is_empty() and desde == 0:
			total = 0
		return {"ok": true, "datos": {"filas": r.datos, "total": total}}
	return r

func posicion_de(id: String) -> int:
	var r := await _rpc("posicion_de", {"p_id": id})
	return int(r.datos) if r.ok and r.datos != null else 0

func perfil(id: String) -> Dictionary:
	return await _rpc("perfil", {"p_id": id})

## Envía la partida si hay sesión. Sin conexión la guarda para más tarde.
func enviar_partida(puntaje: int, tiempo: float, nivel: int, jefes: int, nave: String) -> Dictionary:
	if not conectado():
		return _fallo("sin sesión")
	var p := {"p_puntaje": puntaje, "p_tiempo": snappedf(tiempo, 0.1), "p_nivel": nivel, "p_jefes": jefes, "p_nave": nave}
	var r := await _rpc("registrar_partida", p, true)
	if r.ok:
		ultimo_puesto = int(r.datos.get("puesto", 0))
		cargar_top()
	elif r.get("codigo", 0) == 0:
		pendientes.append(p)
		_guardar()
	return r

## Sube el mejor récord jugado sin sesión en este dispositivo (solo el mejor: la tabla
## cuenta la mejor partida de cada piloto y el servidor no acepta envíos seguidos).
func sincronizar_locales() -> Dictionary:
	var rec := Progreso.record_sin_subir()
	if rec.is_empty() or not conectado():
		return _fallo("nada que subir")
	var r := await enviar_partida(int(rec.puntaje), float(rec.tiempo), int(rec.nivel), int(rec.jefes),
		String(rec.get("nave", Progreso.nave_equipada)))
	# sin conexión queda en "pendientes"; si el servidor la rechaza por inválida no se reintenta
	if r.ok or r.get("codigo", 0) == 0 or "verificación" in String(r.get("error", "")):
		Progreso.marcar_subidos()
	return r

func _enviar_pendientes() -> void:
	var lista := pendientes.duplicate()
	pendientes.clear()
	_guardar()
	for p in lista:
		var r := await _rpc("registrar_partida", p, true)
		if not r.ok and r.get("codigo", 0) == 0:
			pendientes.append(p)
	_guardar()

# ---------------------------------------------------------------- HTTP
func _rpc(funcion: String, args: Dictionary, con_sesion := false) -> Dictionary:
	return await _peticion(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + funcion, args, con_sesion)

func _peticion(metodo: int, ruta: String, cuerpo = null, con_sesion := false) -> Dictionary:
	if not configurado():
		return _fallo("La tabla global aún no está configurada")
	if con_sesion and ruta.begins_with("/rest/") and not await _asegurar_token():
		return _fallo("Tu sesión expiró: vuelve a entrar", 401)
	var h := HTTPRequest.new()
	h.timeout = 12.0
	add_child(h)
	var cab := PackedStringArray([
		"apikey: " + clave,
		"Content-Type: application/json",
		"Authorization: Bearer " + (token if con_sesion and token != "" else clave),
	])
	var err := h.request(url + ruta, cab, metodo, JSON.stringify(cuerpo) if cuerpo != null else "")
	if err != OK:
		h.queue_free()
		return _fallo("Sin conexión")
	var r: Array = await h.request_completed
	h.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return _fallo("Sin conexión")
	var codigo: int = r[1]
	var texto: String = (r[3] as PackedByteArray).get_string_from_utf8()
	var datos = JSON.parse_string(texto) if texto.strip_edges() != "" else null
	if codigo >= 200 and codigo < 300:
		return {"ok": true, "datos": datos}
	return _fallo(_mensaje(codigo, datos), codigo)

func _fallo(texto: String, codigo := 0) -> Dictionary:
	return {"ok": false, "error": texto, "codigo": codigo}

## Traduce los errores de Supabase a algo que entienda el jugador.
func _mensaje(codigo: int, d) -> String:
	var c := ""
	var m := ""
	if typeof(d) == TYPE_DICTIONARY:
		c = String(d.get("error_code", d.get("code", "")))
		m = String(d.get("msg", d.get("message", d.get("error_description", ""))))
	match c:
		"invalid_credentials", "invalid_grant":
			return "Correo o contraseña incorrectos"
		"user_already_exists", "email_exists":
			return "Ya hay una cuenta con ese correo: usa YA TENGO CUENTA"
		"weak_password":
			return "La contraseña es muy débil (mínimo 6 caracteres)"
		"email_not_confirmed":
			return "Primero confirma tu correo: abre el enlace que te enviamos (mira también en spam)"
		"email_address_invalid", "validation_failed":
			return "Ese correo no es válido"
		"over_email_send_rate_limit":
			return "Se enviaron demasiados correos: espera un rato y vuelve a intentarlo"
		"same_password":
			return "La contraseña nueva debe ser distinta a la anterior"
		"signup_disabled":
			return "El registro está cerrado por ahora"
		"over_request_rate_limit":
			return "Demasiados intentos: espera un momento"
	if codigo == 429:
		return "Demasiados intentos: espera un momento"
	if "partida no valida" in m:
		return "La partida no pasó la verificación"
	if "demasiado rapido" in m:
		return "Espera unos segundos entre partidas"
	if "Database error saving new user" in m:
		return "Ese nombre de piloto ya está en uso"
	return "Error del servidor (%d)" % codigo

# ---------------------------------------------------------------- disco
func _guardar() -> void:
	if not Progreso.guardado_activo:
		return
	var c := ConfigFile.new()
	c.set_value("sesion", "token", token)
	c.set_value("sesion", "refresco", refresco)
	c.set_value("sesion", "expira", expira)
	c.set_value("sesion", "uid", uid)
	c.set_value("sesion", "nombre", nombre)
	c.set_value("cache", "top", top)
	c.set_value("cache", "hora", top_hora)
	c.set_value("cache", "pendientes", pendientes)
	c.save(RUTA_SESION)

func _cargar() -> void:
	var c := ConfigFile.new()
	if c.load(RUTA_SESION) != OK:
		return
	token = c.get_value("sesion", "token", "")
	refresco = c.get_value("sesion", "refresco", "")
	expira = c.get_value("sesion", "expira", 0.0)
	uid = c.get_value("sesion", "uid", "")
	nombre = c.get_value("sesion", "nombre", "")
	top = c.get_value("cache", "top", [])
	top_hora = c.get_value("cache", "hora", 0.0)
	pendientes = c.get_value("cache", "pendientes", [])
