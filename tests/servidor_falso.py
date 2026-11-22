"""Imitación mínima de Supabase (Auth + las funciones de supabase/esquema.sql)
para probar el juego sin conexión real. Guarda todo en memoria.
Uso: python3 tests/servidor_falso.py 8790"""
import json, sys, time, uuid, re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

CLAVE = "clave-falsa"
usuarios = {}     # email -> {id, password, nombre}
tokens = {}       # access -> (uid, vence)
refrescos = {}    # refresh -> uid
perfiles = {}     # uid -> {...}
partidas = []     # dicts

def sesion(uid, vida=3600):
    acc, ref = uuid.uuid4().hex, uuid.uuid4().hex
    tokens[acc] = (uid, time.time() + vida)
    refrescos[ref] = uid
    u = next(x for x in usuarios.values() if x["id"] == uid)
    return {"access_token": acc, "refresh_token": ref, "expires_in": vida, "token_type": "bearer",
            "user": {"id": uid, "user_metadata": {"nombre": u["nombre"]}}}

def mejor_por_jugador():
    m = {}
    for p in partidas:
        a = m.get(p["jugador"])
        if a is None or p["puntaje"] > a["puntaje"] or (p["puntaje"] == a["puntaje"] and p["creado"] < a["creado"]):
            m[p["jugador"]] = p
    return m

def puesto_de(valor):
    return 1 + sum(1 for p in mejor_por_jugador().values() if p["puntaje"] > valor)

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def responder(self, codigo, datos):
        cuerpo = json.dumps(datos).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.end_headers()
        self.wfile.write(cuerpo)

    def do_POST(self):
        if self.headers.get("apikey") != CLAVE:
            return self.responder(401, {"message": "Invalid API key"})
        n = int(self.headers.get("Content-Length", 0))
        cuerpo = json.loads(self.rfile.read(n) or b"{}")
        u = urlparse(self.path)
        q = parse_qs(u.query)
        aut = self.headers.get("Authorization", "").replace("Bearer ", "")
        uid = None
        if aut in tokens:
            uid, vence = tokens[aut]
            if vence < time.time():
                return self.responder(401, {"code": "PGRST301", "message": "JWT expired"})
        if u.path == "/auth/v1/signup":
            email = cuerpo["email"].lower()
            if email in usuarios:
                return self.responder(422, {"code": 422, "error_code": "user_already_exists", "msg": "User already registered"})
            if len(cuerpo["password"]) < 6:
                return self.responder(422, {"code": 422, "error_code": "weak_password", "msg": "weak"})
            nombre = cuerpo.get("data", {}).get("nombre", "").upper()
            if not re.fullmatch(r"[A-Z0-9_]{3,14}", nombre) or any(p["nombre"] == nombre for p in perfiles.values()):
                return self.responder(500, {"code": 500, "error_code": "unexpected_failure", "msg": "Database error saving new user"})
            nuevo = str(uuid.uuid4())
            usuarios[email] = {"id": nuevo, "password": cuerpo["password"], "nombre": nombre}
            perfiles[nuevo] = {"id": nuevo, "nombre": nombre, "nave_favorita": "drift", "creado": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime())}
            return self.responder(200, sesion(nuevo, int(q.get("vida", ["3600"])[0])))
        if u.path == "/auth/v1/token":
            if q.get("grant_type") == ["password"]:
                x = usuarios.get(cuerpo["email"].lower())
                if not x or x["password"] != cuerpo["password"]:
                    return self.responder(400, {"code": 400, "error_code": "invalid_credentials", "msg": "Invalid login credentials"})
                return self.responder(200, sesion(x["id"]))
            uid2 = refrescos.pop(cuerpo.get("refresh_token", ""), None)
            if not uid2:
                return self.responder(400, {"code": 400, "error_code": "refresh_token_not_found", "msg": "Invalid Refresh Token"})
            return self.responder(200, sesion(uid2))
        if u.path == "/auth/v1/logout":
            tokens.pop(aut, None)
            return self.responder(204, {})
        if u.path.startswith("/rest/v1/rpc/"):
            f = u.path.rsplit("/", 1)[1]
            if f == "nombre_disponible":
                return self.responder(200, not any(p["nombre"] == cuerpo["p_nombre"].upper() for p in perfiles.values()))
            if f == "top10":
                lista = sorted(mejor_por_jugador().values(), key=lambda p: (-p["puntaje"], p["creado"]))[:10]
                return self.responder(200, [dict(puesto=i + 1, jugador=p["jugador"], nombre=perfiles[p["jugador"]]["nombre"],
                    puntaje=p["puntaje"], tiempo=p["tiempo"], nivel=p["nivel"], jefes=p["jefes"], nave=p["nave"], creado=p["creado_txt"]) for i, p in enumerate(lista)])
            if f in ("ranking", "posicion_de"):
                mej = mejor_por_jugador()
                orden = sorted(perfiles.values(), key=lambda f2: (mej.get(f2["id"]) is None, -(mej[f2["id"]]["puntaje"] if f2["id"] in mej else 0), mej[f2["id"]]["creado"] if f2["id"] in mej else 0, f2["creado"]))
                if f == "posicion_de":
                    ids = [x["id"] for x in orden]
                    return self.responder(200, ids.index(cuerpo["p_id"]) + 1 if cuerpo["p_id"] in ids else None)
                desde, cant = max(0, cuerpo.get("p_desde", 0)), min(50, max(1, cuerpo.get("p_cantidad", 10)))
                filas = []
                for i, f2 in enumerate(orden[desde:desde + cant]):
                    m = mej.get(f2["id"])
                    filas.append(dict(n=desde + i + 1, puesto=desde + i + 1 if m else None, jugador=f2["id"], nombre=f2["nombre"],
                        puntaje=m["puntaje"] if m else None, tiempo=m["tiempo"] if m else None, nivel=m["nivel"] if m else None,
                        jefes=m["jefes"] if m else None, nave=m["nave"] if m else f2["nave_favorita"], total=len(orden)))
                return self.responder(200, filas)
            if f == "perfil":
                pid = cuerpo["p_id"]
                if pid not in perfiles:
                    return self.responder(200, None)
                suyas = [p for p in partidas if p["jugador"] == pid]
                mejor = max((p["puntaje"] for p in suyas), default=None)
                ult = sorted(suyas, key=lambda p: -p["creado"])[:5]
                return self.responder(200, dict(perfiles[pid], partidas=len(suyas), mejor_puntaje=mejor or 0,
                    mejor_tiempo=max((p["tiempo"] for p in suyas), default=0), max_jefes=max((p["jefes"] for p in suyas), default=0),
                    max_nivel=max((p["nivel"] for p in suyas), default=0), puesto=None if mejor is None else puesto_de(mejor),
                    ultimas=[dict(puntaje=p["puntaje"], tiempo=p["tiempo"], nivel=p["nivel"], jefes=p["jefes"], nave=p["nave"], creado=p["creado_txt"]) for p in ult]))
            if f == "registrar_partida":
                if not uid:
                    return self.responder(401, {"message": "sin sesion"})
                t = cuerpo["p_tiempo"]
                if t > 14400 or cuerpo["p_puntaje"] > 2000 + t * 400 or cuerpo["p_jefes"] > t // 60 + 1 or not 1 <= cuerpo["p_nivel"] <= 300:
                    return self.responder(400, {"code": "P0001", "message": "partida no valida"})
                ahora = time.time()
                partidas.append(dict(jugador=uid, puntaje=cuerpo["p_puntaje"], tiempo=t, nivel=cuerpo["p_nivel"], jefes=cuerpo["p_jefes"],
                    nave=cuerpo["p_nave"], creado=ahora, creado_txt=time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime(ahora))))
                naves = [p["nave"] for p in partidas if p["jugador"] == uid]
                perfiles[uid]["nave_favorita"] = max(set(naves), key=naves.count)
                mejor = max(p["puntaje"] for p in partidas if p["jugador"] == uid)
                return self.responder(200, {"puesto": puesto_de(mejor), "mejor": mejor})
        self.responder(404, {"message": "no existe"})

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1]) if len(sys.argv) > 1 else 8790), H).serve_forever()
