# Activar la tabla de posiciones global (Supabase, plan gratis)

1. Crea una cuenta en https://supabase.com y un proyecto nuevo (elige la región más cercana a tus jugadores).
2. **Authentication → Sign In / Providers → Email**: desactiva **"Confirm email"**.
   Los jugadores se registran con nombre de piloto + contraseña; el juego usa un correo interno.
3. **SQL Editor → New query**: pega todo `supabase/esquema.sql` y pulsa **Run**.
4. **Project Settings → API**: copia la **Project URL** y la clave **anon / publishable**.
5. Ponlas en `scripts/autoload/datos.gd`:
   ```gdscript
   const SUPABASE_URL := "https://xxxx.supabase.co"
   const SUPABASE_CLAVE := "eyJ..."   # anon/publishable: es pública por diseño
   ```
   **Nunca** pongas la clave `service_role`/`secret`: esa sí da acceso total.

Sin esos dos valores el juego funciona igual, solo con récords locales.

## Qué guarda
- `perfiles`: nombre, nave favorita, fecha de alta.
- `partidas`: puntaje, tiempo, nivel, jefes y nave de cada partida enviada.
- El juego solo escribe a través de `registrar_partida`, que rechaza puntajes imposibles
  y envíos seguidos (menos de 15 s). Como el juego corre en el dispositivo del jugador,
  alguien con conocimientos podría falsear un puntaje creíble; si pasa, se borra la fila
  desde **Table Editor → partidas**.

## Probar sin Supabase
`tests/servidor_falso.py` imita estas funciones:
```
python3 tests/servidor_falso.py 8790 &
flatpak run org.godotengine.Godot --path . res://tests/prueba_red.tscn -- --servidor=http://127.0.0.1:8790 --clave=clave-falsa
```

## Marcadores (todos los pilotos)

El inicio muestra el TOP 10 (`top10()`) y la pantalla MARCADORES lista a **todos** los
pilotos registrados por páginas de 10 (`ranking(p_desde, p_cantidad)`), incluidos los que
aún no juegan, al final y sin puntaje. `posicion_de(p_id)` sirve para el botón MI PUESTO.
Si ya habías ejecutado `esquema.sql` antes, vuelve a ejecutarlo completo: no borra datos.
