-- =====================================================================
-- Crazy Space's · Tabla de posiciones global (Supabase)
-- Pegar completo en: Supabase → SQL Editor → New query → Run.
-- Se puede ejecutar varias veces sin romper nada.
--
-- Cuentas: "nombre de piloto + contraseña". El juego convierte el nombre en un
-- correo interno (<nombre>@jugadores.crazyspaces.app), así que en
-- Authentication → Sign In / Providers → Email hay que DESACTIVAR "Confirm email".
--
-- Nadie escribe directo en las tablas: el juego solo llama a las funciones de abajo.
-- =====================================================================

-- ---------------------------------------------------------------- tablas
create table if not exists public.perfiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  nombre        text not null,
  nave_favorita text not null default 'drift',
  creado        timestamptz not null default now(),
  constraint nombre_valido check (nombre ~ '^[A-Z0-9_]{3,14}$')
);
create unique index if not exists perfiles_nombre_unico on public.perfiles (nombre);

create table if not exists public.partidas (
  id      bigint generated always as identity primary key,
  jugador uuid not null references public.perfiles (id) on delete cascade,
  puntaje integer not null check (puntaje >= 0),
  tiempo  real not null check (tiempo >= 0),
  nivel   integer not null check (nivel >= 1),
  jefes   integer not null check (jefes >= 0),
  nave    text not null,
  creado  timestamptz not null default now()
);
create index if not exists partidas_por_puntaje on public.partidas (puntaje desc);
create index if not exists partidas_por_jugador on public.partidas (jugador, creado desc);

-- ---------------------------------------------------------------- seguridad
alter table public.perfiles enable row level security;
alter table public.partidas enable row level security;

drop policy if exists "perfiles visibles" on public.perfiles;
create policy "perfiles visibles" on public.perfiles for select using (true);
drop policy if exists "partidas visibles" on public.partidas;
create policy "partidas visibles" on public.partidas for select using (true);
-- sin políticas de insert/update/delete: solo las funciones (security definer) escriben

-- ---------------------------------------------------------------- perfil al registrarse
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, nombre)
  values (new.id, upper(coalesce(new.raw_user_meta_data ->> 'nombre', '')));
  return new;
end $$;

drop trigger if exists al_registrarse on auth.users;
create trigger al_registrarse after insert on auth.users
  for each row execute function public.crear_perfil();

-- ---------------------------------------------------------------- funciones del juego
create or replace function public.nombre_disponible(p_nombre text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from perfiles where nombre = upper(p_nombre));
$$;

-- Guarda una partida del jugador con sesión. Rechaza puntajes imposibles
-- y envíos seguidos. Devuelve {puesto, mejor}.
create or replace function public.registrar_partida(
  p_puntaje integer, p_tiempo real, p_nivel integer, p_jefes integer, p_nave text
) returns json
language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  ultimo timestamptz;
  mejor  integer;
  puesto integer;
begin
  if uid is null then
    raise exception 'sin sesion';
  end if;
  if p_tiempo > 14400 or p_puntaje > 2000 + p_tiempo * 400
     or p_jefes > floor(p_tiempo / 60) + 1 or p_nivel > 300 or p_nivel < 1 then
    raise exception 'partida no valida';
  end if;
  select max(creado) into ultimo from partidas where jugador = uid;
  if ultimo is not null and ultimo > now() - interval '15 seconds' then
    raise exception 'demasiado rapido';
  end if;

  insert into partidas (jugador, puntaje, tiempo, nivel, jefes, nave)
  values (uid, p_puntaje, p_tiempo, p_nivel, p_jefes, left(p_nave, 20));

  update perfiles set nave_favorita = (
    select nave from partidas where jugador = uid group by nave order by count(*) desc, max(creado) desc limit 1
  ) where id = uid;

  select max(puntaje) into mejor from partidas where jugador = uid;
  select 1 + count(*) into puesto
  from (select max(puntaje) as m from partidas group by jugador) t
  where t.m > mejor;
  return json_build_object('puesto', puesto, 'mejor', mejor);
end $$;

-- Top 10 global: la mejor partida de cada piloto.
create or replace function public.top10()
returns table (puesto integer, jugador uuid, nombre text, puntaje integer, tiempo real,
               nivel integer, jefes integer, nave text, creado timestamptz)
language sql stable security definer set search_path = public as $$
  with mejores as (
    select distinct on (p.jugador) p.*
    from partidas p
    order by p.jugador, p.puntaje desc, p.creado asc
  )
  select (row_number() over (order by m.puntaje desc, m.creado asc))::integer,
         m.jugador, f.nombre, m.puntaje, m.tiempo, m.nivel, m.jefes, m.nave, m.creado
  from mejores m
  join perfiles f on f.id = m.jugador
  order by m.puntaje desc, m.creado asc
  limit 10;
$$;

-- Marcadores: TODOS los pilotos registrados, por páginas. Primero los que tienen
-- partidas (por su mejor puntaje), después los que aún no juegan (por antigüedad).
create or replace function public.ranking(p_desde integer default 0, p_cantidad integer default 10)
returns table (n integer, puesto integer, jugador uuid, nombre text, puntaje integer, tiempo real,
               nivel integer, jefes integer, nave text, total integer)
language sql stable security definer set search_path = public as $$
  with mejores as (
    select distinct on (p.jugador) p.*
    from partidas p
    order by p.jugador, p.puntaje desc, p.creado asc
  ), todos as (
    select f.id, f.nombre, f.creado as alta, f.nave_favorita,
           m.puntaje, m.tiempo, m.nivel, m.jefes, m.nave, m.creado
    from perfiles f left join mejores m on m.jugador = f.id
  ), ordenados as (
    select row_number() over (order by (t.puntaje is null), t.puntaje desc, t.creado asc, t.alta asc)::integer as n, t.*
    from todos t
  )
  select o.n,
         case when o.puntaje is null then null else o.n end,
         o.id, o.nombre, o.puntaje, o.tiempo, o.nivel, o.jefes, coalesce(o.nave, o.nave_favorita),
         (select count(*) from perfiles)::integer
  from ordenados o
  where o.n > greatest(p_desde, 0) and o.n <= greatest(p_desde, 0) + least(greatest(p_cantidad, 1), 50)
  order by o.n;
$$;

-- Posición (1..total) de un piloto en los marcadores, para saltar a su página.
create or replace function public.posicion_de(p_id uuid) returns integer
language sql stable security definer set search_path = public as $$
  with mejores as (select jugador, max(puntaje) as puntaje, min(creado) as creado from partidas group by jugador),
       ordenados as (
         select f.id, row_number() over (order by (m.puntaje is null), m.puntaje desc, m.creado asc, f.creado asc)::integer as n
         from perfiles f left join mejores m on m.jugador = f.id)
  select n from ordenados where id = p_id;
$$;

-- Perfil público de un piloto: estadísticas y sus últimas 5 partidas.
create or replace function public.perfil(p_id uuid) returns json
language sql stable security definer set search_path = public as $$
  with suyas as (select * from partidas where jugador = p_id),
       mejor as (select max(puntaje) as m from suyas)
  select json_build_object(
    'id', f.id,
    'nombre', f.nombre,
    'nave_favorita', f.nave_favorita,
    'creado', f.creado,
    'partidas', (select count(*) from suyas),
    'mejor_puntaje', coalesce((select m from mejor), 0),
    'mejor_tiempo', coalesce((select max(tiempo) from suyas), 0),
    'max_jefes', coalesce((select max(jefes) from suyas), 0),
    'max_nivel', coalesce((select max(nivel) from suyas), 0),
    'puesto', case when (select m from mejor) is null then null else
                (select 1 + count(*) from (select max(puntaje) as m from partidas group by jugador) t
                 where t.m > (select m from mejor)) end,
    'ultimas', coalesce((select json_agg(u) from (
                 select puntaje, tiempo, nivel, jefes, nave, creado from suyas order by creado desc limit 5
               ) u), '[]'::json)
  )
  from perfiles f
  where f.id = p_id;
$$;

revoke all on function public.registrar_partida(integer, real, integer, integer, text) from anon;
grant execute on function public.registrar_partida(integer, real, integer, integer, text) to authenticated;
grant execute on function public.top10() to anon, authenticated;
grant execute on function public.ranking(integer, integer) to anon, authenticated;
grant execute on function public.posicion_de(uuid) to anon, authenticated;
grant execute on function public.perfil(uuid) to anon, authenticated;
grant execute on function public.nombre_disponible(text) to anon, authenticated;
