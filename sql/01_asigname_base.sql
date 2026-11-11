-- ============================================================
-- Asígname · tareas, comunicados y chat del equipo
-- Misma base que VerifyCredit y Mi Planilla (mismas cuentas).
-- Tablas con prefijo as_. Funciones internas en el esquema private.
-- ============================================================

create schema if not exists private;

-- ---------- Áreas y miembros ----------
create table if not exists as_areas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references pl_empresas(id) on delete cascade,
  nombre text not null,
  color text not null default '#1877F2',
  orden int not null default 0,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  unique (empresa_id, nombre)
);

create table if not exists as_miembros (
  user_id uuid primary key references auth.users(id) on delete cascade,
  empresa_id uuid not null references pl_empresas(id) on delete cascade,
  nombre text not null,
  alias text,
  cargo text,
  area_id uuid references as_areas(id) on delete set null,
  rol text not null default 'miembro' check (rol in ('gerente','jefe','miembro')),
  areas_jefe uuid[] not null default '{}',
  foto text,
  estado_texto text,
  telefono text,
  activo boolean not null default true,
  ultimo_visto timestamptz,
  creado_en timestamptz not null default now()
);
create index if not exists as_miembros_emp on as_miembros(empresa_id);

-- ---------- Tareas ----------
create table if not exists as_tareas (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references pl_empresas(id) on delete cascade,
  numero int not null,
  titulo text not null,
  descripcion text,
  prioridad text not null default 'normal' check (prioridad in ('baja','normal','alta','urgente')),
  estado text not null default 'pendiente' check (estado in ('pendiente','en_proceso','en_revision','bloqueada','completada','cancelada')),
  estado_nota text,
  area_id uuid references as_areas(id) on delete set null,
  responsable_id uuid references auth.users(id),
  colaboradores uuid[] not null default '{}',
  creado_por uuid not null references auth.users(id),
  fecha_limite timestamptz,
  requiere_aprobacion boolean not null default false,
  checklist jsonb not null default '[]',
  recurrencia text check (recurrencia in ('diaria','semanal','quincenal','mensual')),
  recurrente_de bigint references as_tareas(id) on delete set null,
  siguiente_creada boolean not null default false,
  cliente text,
  origen jsonb,
  adjuntos jsonb not null default '[]',
  iniciada_en timestamptz,
  completada_en timestamptz,
  aprobada_por uuid,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (empresa_id, numero)
);
create index if not exists as_tareas_resp on as_tareas(responsable_id);
create index if not exists as_tareas_emp on as_tareas(empresa_id, estado);

create table if not exists as_tarea_eventos (
  id bigint generated always as identity primary key,
  tarea_id bigint not null references as_tareas(id) on delete cascade,
  user_id uuid references auth.users(id),
  tipo text not null,
  texto text,
  datos jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists as_tarea_eventos_t on as_tarea_eventos(tarea_id, id);

-- ---------- Comunicados ----------
create table if not exists as_comunicados (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references pl_empresas(id) on delete cascade,
  titulo text not null,
  cuerpo text,
  importancia text not null default 'normal' check (importancia in ('normal','importante','urgente')),
  destino text not null default 'todos' check (destino in ('todos','areas','personas')),
  areas uuid[] not null default '{}',
  usuarios uuid[] not null default '{}',
  requiere_confirmacion boolean not null default false,
  fijado boolean not null default false,
  adjuntos jsonb not null default '[]',
  creado_por uuid not null references auth.users(id),
  creado_en timestamptz not null default now(),
  archivado boolean not null default false
);
create table if not exists as_comunicado_lecturas (
  comunicado_id bigint not null references as_comunicados(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  visto_en timestamptz not null default now(),
  confirmado_en timestamptz,
  primary key (comunicado_id, user_id)
);

-- ---------- Chat ----------
create table if not exists as_chats (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references pl_empresas(id) on delete cascade,
  tipo text not null check (tipo in ('directo','grupo','area','general')),
  nombre text,
  descripcion text,
  foto text,
  area_id uuid references as_areas(id) on delete cascade,
  clave text unique,
  solo_admins boolean not null default false,
  creado_por uuid references auth.users(id),
  creado_en timestamptz not null default now(),
  ultimo_id bigint,
  ultimo_en timestamptz,
  ultimo_texto text,
  ultimo_user uuid,
  ultimo_tipo text
);
create table if not exists as_chat_miembros (
  chat_id bigint not null references as_chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  admin boolean not null default false,
  silenciado boolean not null default false,
  fijado boolean not null default false,
  archivado boolean not null default false,
  leido_id bigint not null default 0,
  leido_en timestamptz,
  recibido_id bigint not null default 0,
  unido_en timestamptz not null default now(),
  primary key (chat_id, user_id)
);
create index if not exists as_chat_miembros_u on as_chat_miembros(user_id);

create table if not exists as_mensajes (
  id bigint generated always as identity primary key,
  chat_id bigint not null references as_chats(id) on delete cascade,
  user_id uuid references auth.users(id),
  tipo text not null default 'texto' check (tipo in ('texto','imagen','archivo','audio','ubicacion','tarea','gestion','encuesta','sistema')),
  texto text,
  archivo jsonb,
  datos jsonb,
  responde_a bigint references as_mensajes(id) on delete set null,
  reenviado boolean not null default false,
  editado_en timestamptz,
  borrado boolean not null default false,
  local_id text unique,
  creado_en timestamptz not null default now()
);
create index if not exists as_mensajes_chat on as_mensajes(chat_id, id desc);
create index if not exists as_mensajes_gestion on as_mensajes(tipo, creado_en) where tipo = 'gestion';

create table if not exists as_reacciones (
  mensaje_id bigint not null references as_mensajes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id bigint not null references as_chats(id) on delete cascade,
  emoji text,
  creado_en timestamptz not null default now(),
  primary key (mensaje_id, user_id)
);
create table if not exists as_votos (
  mensaje_id bigint not null references as_mensajes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  chat_id bigint not null references as_chats(id) on delete cascade,
  opciones int[] not null default '{}',
  creado_en timestamptz not null default now(),
  primary key (mensaje_id, user_id)
);

create table if not exists as_push_subs (
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  p256dh text not null,
  auth text not null,
  agente text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

-- ============================================================
-- Funciones de permisos
-- ============================================================
create or replace function private.as_norm(t text) returns text language sql immutable as $$
  select translate(lower(trim(coalesce(t,''))), 'áéíóúüñ', 'aeiouun')
$$;

create or replace function as_empresa() returns uuid language sql stable security definer set search_path = public as $$
  select empresa_id from as_miembros where user_id = auth.uid() and activo
$$;

create or replace function as_es_gerente() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from as_miembros where user_id = auth.uid() and rol = 'gerente' and activo)
$$;

create or replace function as_mi_area() returns uuid language sql stable security definer set search_path = public as $$
  select area_id from as_miembros where user_id = auth.uid() and activo
$$;

-- Áreas que dirige un jefe (por defecto su propia área)
create or replace function as_areas_jefe() returns uuid[] language sql stable security definer set search_path = public as $$
  select coalesce((select case when rol = 'jefe' then
           case when cardinality(areas_jefe) > 0 then areas_jefe else array_remove(array[area_id], null) end
         else '{}'::uuid[] end
    from as_miembros where user_id = auth.uid() and activo), '{}'::uuid[])
$$;

create or replace function as_area_de(p_uid uuid) returns uuid language sql stable security definer set search_path = public as $$
  select area_id from as_miembros where user_id = p_uid
$$;

create or replace function as_puede_asignar_a(p_uid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select p_uid = auth.uid()
      or (exists (select 1 from as_miembros m where m.user_id = p_uid and m.empresa_id = as_empresa() and m.activo)
          and (as_es_gerente() or as_area_de(p_uid) = any(as_areas_jefe())))
$$;

create or replace function as_soy_miembro(p_chat bigint) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from as_chat_miembros where chat_id = p_chat and user_id = auth.uid())
$$;

create or replace function as_ve_tarea(p_id bigint) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from as_tareas t where t.id = p_id and t.empresa_id = as_empresa() and (
       as_es_gerente()
    or t.creado_por = auth.uid()
    or t.responsable_id = auth.uid()
    or auth.uid() = any(t.colaboradores)
    or (t.responsable_id is null and t.area_id = as_mi_area())
    or t.area_id = any(as_areas_jefe())
    or as_area_de(t.responsable_id) = any(as_areas_jefe())))
$$;

-- ¿Puede administrar la tarea? (creador, gerente o jefe del área)
create or replace function private.as_gestiona_tarea(t as_tareas) returns boolean language sql stable security definer set search_path = public as $$
  select t.creado_por = auth.uid() or as_es_gerente()
      or t.area_id = any(as_areas_jefe()) or as_area_de(t.responsable_id) = any(as_areas_jefe())
$$;

create or replace function private.as_es_dest(c as_comunicados, p_uid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from as_miembros m where m.user_id = p_uid and m.empresa_id = c.empresa_id and m.activo and (
      c.destino = 'todos' or (c.destino = 'areas' and m.area_id = any(c.areas)) or (c.destino = 'personas' and m.user_id = any(c.usuarios))))
$$;

create or replace function as_ve_comunicado(p_id bigint) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from as_comunicados c where c.id = p_id and c.empresa_id = as_empresa()
    and (c.creado_por = auth.uid() or as_es_gerente() or private.as_es_dest(c, auth.uid())))
$$;

-- ============================================================
-- Notificaciones push (misma clave VAPID del proyecto)
-- ============================================================
create or replace function private.as_push(p_ids uuid[], p_titulo text, p_cuerpo text, p_url text, p_tag text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_ids uuid[]; sec text;
begin
  v_ids := array(select distinct x from unnest(p_ids) x where x is not null and x is distinct from auth.uid());
  if coalesce(array_length(v_ids, 1), 0) = 0 or not exists (select 1 from as_push_subs where user_id = any(v_ids)) then return; end if;
  select v into sec from private.push_config where k = 'secreto';
  perform net.http_post(
    url := 'https://edmvfqelxsxevpmxgbav.supabase.co/functions/v1/asigname-push',
    body := jsonb_build_object('ids', to_jsonb(v_ids), 'title', p_titulo, 'body', left(coalesce(p_cuerpo, ''), 240), 'url', p_url, 'tag', p_tag),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-as-secreto', sec),
    timeout_milliseconds := 10000);
exception when others then
  raise warning 'as_push: %', sqlerrm;
end $$;

create or replace function as_guardar_push(p_endpoint text, p_p256dh text, p_auth text, p_agente text default null)
returns void language sql security definer set search_path = public as $$
  insert into as_push_subs(endpoint, user_id, p256dh, auth, agente) values (p_endpoint, auth.uid(), p_p256dh, p_auth, p_agente)
  on conflict (endpoint) do update set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth, agente = excluded.agente, actualizado_en = now()
$$;
create or replace function as_borrar_push(p_endpoint text) returns void language sql security definer set search_path = public as $$
  delete from as_push_subs where endpoint = p_endpoint and user_id = auth.uid()
$$;

create or replace function private.as_nombre(p_uid uuid) returns text language sql stable security definer set search_path = public as $$
  select coalesce(alias, case
           when array_length(regexp_split_to_array(trim(nombre), '\s+'), 1) >= 4 then split_part(trim(nombre), ' ', 1) || ' ' || split_part(regexp_replace(trim(nombre), '\s+', ' ', 'g'), ' ', 3)
           else nombre end)
  from as_miembros where user_id = p_uid
$$;

-- ============================================================
-- Sincronización con VerifyCredit (perfiles) y Mi Planilla (pl_empleados)
-- ============================================================
create or replace function private.as_sync(p_empresa uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  -- Áreas nuevas que aparezcan en Mi Planilla
  insert into as_areas(empresa_id, nombre)
  select distinct on (private.as_norm(e.area)) p_empresa, trim(e.area)
  from pl_empleados e
  where e.empresa_id = p_empresa and coalesce(trim(e.area), '') <> ''
    and not exists (select 1 from as_areas a where a.empresa_id = p_empresa and private.as_norm(a.nombre) = private.as_norm(e.area))
  on conflict do nothing;

  with emp as (
    select e.user_id uid, e.nombre, e.cargo, e.area, e.telefono, e.activo
    from pl_empleados e where e.user_id is not null and e.empresa_id = p_empresa
  ), per as (
    select p.id uid, p.nombre, p.rol, p.activo from perfiles p where pl_empresa_de(p.id) = p_empresa
  ), src as (
    select coalesce(emp.uid, per.uid) uid,
           coalesce(emp.nombre, per.nombre) nombre,
           coalesce(nullif(emp.cargo, ''), case per.rol when 'asesor' then 'Asesor de crédito' when 'analista' then 'Analista de crédito'
             when 'verificador' then 'Verificador' when 'admin' then 'Administrador' when 'cajero' then 'Cajero' end) cargo,
           coalesce(nullif(emp.area, ''), case when per.rol in ('asesor','analista','verificador') then 'Créditos'
             when per.rol in ('admin','cajero') then 'Administración' end) area,
           emp.telefono,
           (coalesce(emp.activo, false) or coalesce(per.activo, false)) activo,
           ((per.rol = 'admin' and per.activo) or exists (select 1 from pl_admins a where a.user_id = coalesce(emp.uid, per.uid))) es_ger
    from emp full join per on per.uid = emp.uid
  )
  insert into as_miembros(user_id, empresa_id, nombre, cargo, area_id, telefono, activo, rol)
  select s.uid, p_empresa, s.nombre, s.cargo,
         (select a.id from as_areas a where a.empresa_id = p_empresa and private.as_norm(a.nombre) = private.as_norm(s.area) limit 1),
         s.telefono, s.activo, case when s.es_ger then 'gerente' else 'miembro' end
  from src s where s.uid is not null
  on conflict (user_id) do update set
    nombre = excluded.nombre,
    cargo = coalesce(excluded.cargo, as_miembros.cargo),
    telefono = coalesce(excluded.telefono, as_miembros.telefono),
    activo = excluded.activo,
    area_id = coalesce(as_miembros.area_id, excluded.area_id),
    empresa_id = excluded.empresa_id;

  -- Grupo de toda la empresa y uno por área
  insert into as_chats(empresa_id, tipo, nombre, descripcion, clave, solo_admins)
  values (p_empresa, 'general', 'Toda la empresa', 'Grupo de todo el equipo', 'general:' || p_empresa, false)
  on conflict (clave) do nothing;

  insert into as_chats(empresa_id, tipo, nombre, descripcion, area_id, clave)
  select p_empresa, 'area', a.nombre, 'Grupo del área ' || a.nombre, a.id, 'area:' || a.id
  from as_areas a where a.empresa_id = p_empresa and a.activo
    and exists (select 1 from as_miembros m where m.area_id = a.id and m.activo)
  on conflict (clave) do update set nombre = excluded.nombre;

  -- Miembros de los grupos automáticos
  insert into as_chat_miembros(chat_id, user_id, admin)
  select c.id, m.user_id, m.rol = 'gerente'
  from as_chats c join as_miembros m on m.empresa_id = c.empresa_id and m.activo
  where c.empresa_id = p_empresa and (
        c.tipo = 'general'
     or (c.tipo = 'area' and (m.area_id = c.area_id or m.rol = 'gerente' or (m.rol = 'jefe' and c.area_id = any(m.areas_jefe)))))
  on conflict (chat_id, user_id) do update set admin = excluded.admin or as_chat_miembros.admin;

  delete from as_chat_miembros cm using as_chats c
  where cm.chat_id = c.id and c.empresa_id = p_empresa and c.tipo in ('general','area')
    and not exists (select 1 from as_miembros m where m.user_id = cm.user_id and m.activo and m.empresa_id = c.empresa_id and (
          c.tipo = 'general'
       or m.area_id = c.area_id or m.rol = 'gerente' or (m.rol = 'jefe' and c.area_id = any(m.areas_jefe))));
end $$;

-- Al abrir la app: sincroniza y devuelve el usuario
create or replace function as_yo() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_emp uuid := pl_empresa_de(auth.uid()); r jsonb;
begin
  if auth.uid() is null or v_emp is null then return null; end if;
  perform private.as_sync(v_emp);
  update as_miembros set ultimo_visto = now() where user_id = auth.uid();
  select jsonb_build_object('user_id', m.user_id, 'nombre', m.nombre, 'alias', m.alias, 'cargo', m.cargo, 'area_id', m.area_id,
           'rol', m.rol, 'areas_jefe', as_areas_jefe(), 'activo', m.activo, 'foto', m.foto, 'estado_texto', m.estado_texto,
           'empresa', jsonb_build_object('id', e.id, 'nombre', e.nombre))
    into r from as_miembros m join pl_empresas e on e.id = m.empresa_id where m.user_id = auth.uid();
  return r;
end $$;

create or replace function as_ping() returns void language sql security definer set search_path = public as $$
  update as_miembros set ultimo_visto = now() where user_id = auth.uid()
$$;

create or replace function as_mi_perfil(p_alias text, p_estado text, p_foto text) returns void language plpgsql security definer set search_path = public as $$
begin
  update as_miembros set alias = nullif(trim(p_alias), ''), estado_texto = nullif(trim(p_estado), ''),
         foto = case when p_foto = '-' then null else coalesce(p_foto, foto) end
  where user_id = auth.uid();
end $$;

-- Gerente: rol, área y áreas a cargo
create or replace function as_admin_miembro(p_uid uuid, p_rol text, p_area uuid, p_areas_jefe uuid[], p_alias text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not as_es_gerente() then raise exception 'Solo el gerente puede cambiar esto'; end if;
  if p_uid = auth.uid() and p_rol <> 'gerente' and (select count(*) from as_miembros where empresa_id = as_empresa() and rol = 'gerente' and activo) <= 1 then
    raise exception 'Debe quedar al menos un gerente';
  end if;
  update as_miembros set rol = p_rol, area_id = p_area, areas_jefe = coalesce(p_areas_jefe, '{}'), alias = nullif(trim(p_alias), '')
  where user_id = p_uid and empresa_id = as_empresa();
  perform private.as_sync(as_empresa());
end $$;

create or replace function as_guardar_area(p_id uuid, p_nombre text, p_color text, p_activo boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if not as_es_gerente() then raise exception 'Solo el gerente puede cambiar las áreas'; end if;
  if p_id is null then
    insert into as_areas(empresa_id, nombre, color) values (as_empresa(), trim(p_nombre), coalesce(p_color, '#1877F2')) returning id into v;
  else
    update as_areas set nombre = trim(p_nombre), color = coalesce(p_color, color), activo = coalesce(p_activo, true)
    where id = p_id and empresa_id = as_empresa() returning id into v;
  end if;
  perform private.as_sync(as_empresa());
  return v;
end $$;

-- ============================================================
-- Tareas
-- ============================================================
create or replace function private.as_tarea_evento(p_tarea bigint, p_tipo text, p_texto text, p_datos jsonb default null, p_avisar boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare t as_tareas; v_ids uuid[]; v_quien text := coalesce(private.as_nombre(auth.uid()), 'Alguien');
begin
  insert into as_tarea_eventos(tarea_id, user_id, tipo, texto, datos) values (p_tarea, auth.uid(), p_tipo, p_texto, p_datos);
  update as_tareas set actualizado_en = now() where id = p_tarea returning * into t;
  if p_avisar then
    v_ids := array_remove(array[t.creado_por, t.responsable_id], null) || t.colaboradores;
    perform private.as_push(v_ids,
      '📋 T-' || t.numero || ' · ' || left(t.titulo, 60),
      v_quien || ': ' || coalesce(p_texto, p_tipo),
      '#/tarea/' || t.id, 'tarea-' || t.id);
  end if;
end $$;

create or replace function as_crear_tarea(p jsonb) returns bigint[] language plpgsql security definer set search_path = public as $$
declare
  v_emp uuid := as_empresa();
  v_resp uuid[] := coalesce(array(select (x)::uuid from jsonb_array_elements_text(coalesce(p->'responsables', '[]')) x), '{}');
  v_col uuid[] := coalesce(array(select (x)::uuid from jsonb_array_elements_text(coalesce(p->'colaboradores', '[]')) x), '{}');
  v_area uuid := nullif(p->>'area_id', '')::uuid;
  v_indiv boolean := coalesce((p->>'individual')::boolean, true);
  v_ids bigint[] := '{}';
  v_num int; v_id bigint; u uuid; v_lista uuid[];
begin
  if v_emp is null then raise exception 'Sin acceso'; end if;
  if coalesce(trim(p->>'titulo'), '') = '' then raise exception 'Escriba el título de la tarea'; end if;
  foreach u in array (v_resp || v_col) loop
    if not as_puede_asignar_a(u) then raise exception 'No puede asignar tareas a %', coalesce(private.as_nombre(u), 'esa persona'); end if;
  end loop;
  if v_area is not null and not (as_es_gerente() or v_area = any(as_areas_jefe()) or (cardinality(v_resp) > 0)) then
    raise exception 'No puede asignar tareas a esa área';
  end if;
  if cardinality(v_resp) = 0 and v_area is null then v_resp := array[auth.uid()]; end if;

  perform pg_advisory_xact_lock(hashtext('as_tareas:' || v_emp));
  if v_indiv and cardinality(v_resp) > 1 then
    v_lista := v_resp;
  else
    v_lista := array[case when cardinality(v_resp) > 0 then v_resp[1] else null end];
    if cardinality(v_resp) > 1 then v_col := (v_col || v_resp[2:]); end if;
  end if;

  foreach u in array v_lista loop
    select coalesce(max(numero), 0) + 1 into v_num from as_tareas where empresa_id = v_emp;
    insert into as_tareas(empresa_id, numero, titulo, descripcion, prioridad, area_id, responsable_id, colaboradores, creado_por,
      fecha_limite, requiere_aprobacion, checklist, recurrencia, cliente, origen, adjuntos)
    values (v_emp, v_num, trim(p->>'titulo'), nullif(trim(p->>'descripcion'), ''), coalesce(p->>'prioridad', 'normal'),
      coalesce(v_area, as_area_de(u)), u, array(select distinct x from unnest(v_col) x where x is distinct from u), auth.uid(),
      nullif(p->>'fecha_limite', '')::timestamptz, coalesce((p->>'requiere_aprobacion')::boolean, false),
      coalesce(p->'checklist', '[]'), nullif(p->>'recurrencia', ''), nullif(trim(p->>'cliente'), ''), p->'origen', coalesce(p->'adjuntos', '[]'))
    returning id into v_id;
    v_ids := v_ids || v_id;
    insert into as_tarea_eventos(tarea_id, user_id, tipo, texto) values (v_id, auth.uid(), 'creada',
      case when u is null then 'Tarea para el área' when u = auth.uid() then 'Tarea personal' else 'Asignada a ' || private.as_nombre(u) end);
    if u is null then
      perform private.as_push(array(select user_id from as_miembros where area_id = v_area and activo),
        '📋 Nueva tarea para su área', trim(p->>'titulo'), '#/tarea/' || v_id, 'tarea-' || v_id);
    else
      perform private.as_push(array[u] || array(select distinct x from unnest(v_col) x),
        case when p->>'prioridad' = 'urgente' then '🔴 Tarea urgente' else '📋 Nueva tarea' end,
        private.as_nombre(auth.uid()) || ': ' || trim(p->>'titulo'), '#/tarea/' || v_id, 'tarea-' || v_id);
    end if;
  end loop;
  return v_ids;
end $$;

create or replace function as_tarea_editar(p_id bigint, p jsonb) returns void language plpgsql security definer set search_path = public as $$
declare t as_tareas; v_resp uuid; v_col uuid[]; cambios text[] := '{}';
begin
  select * into t from as_tareas where id = p_id for update;
  if t.id is null or not as_ve_tarea(p_id) then raise exception 'Tarea no encontrada'; end if;
  if not private.as_gestiona_tarea(t) then raise exception 'Solo quien asignó la tarea, el jefe del área o el gerente pueden editarla'; end if;
  if p ? 'responsable_id' then
    v_resp := nullif(p->>'responsable_id', '')::uuid;
    if v_resp is not null and not as_puede_asignar_a(v_resp) then raise exception 'No puede asignar a esa persona'; end if;
    if v_resp is distinct from t.responsable_id then
      cambios := cambios || ('Responsable: ' || coalesce(private.as_nombre(v_resp), 'el área'));
      perform private.as_push(array[v_resp], '📋 Le asignaron una tarea', private.as_nombre(auth.uid()) || ': ' || t.titulo, '#/tarea/' || t.id, 'tarea-' || t.id);
    end if;
  else v_resp := t.responsable_id; end if;
  if p ? 'colaboradores' then
    v_col := array(select (x)::uuid from jsonb_array_elements_text(p->'colaboradores') x);
    perform 1 from unnest(v_col) x where not as_puede_asignar_a(x) and not x = any(t.colaboradores);
    if found then raise exception 'No puede agregar a esa persona'; end if;
  else v_col := t.colaboradores; end if;
  if p ? 'fecha_limite' and (nullif(p->>'fecha_limite', '')::timestamptz) is distinct from t.fecha_limite then
    cambios := cambios || ('Fecha límite: ' || coalesce(to_char((p->>'fecha_limite')::timestamptz at time zone 'America/Tegucigalpa', 'DD/MM HH24:MI'), 'sin fecha'));
  end if;
  if p ? 'prioridad' and p->>'prioridad' is distinct from t.prioridad then cambios := cambios || ('Prioridad: ' || (p->>'prioridad')); end if;
  if p ? 'titulo' and trim(p->>'titulo') is distinct from t.titulo then cambios := cambios || 'Título'::text; end if;
  if p ? 'descripcion' and nullif(trim(p->>'descripcion'), '') is distinct from t.descripcion then cambios := cambios || 'Descripción'::text; end if;

  update as_tareas set
    titulo = coalesce(nullif(trim(p->>'titulo'), ''), titulo),
    descripcion = case when p ? 'descripcion' then nullif(trim(p->>'descripcion'), '') else descripcion end,
    prioridad = coalesce(p->>'prioridad', prioridad),
    fecha_limite = case when p ? 'fecha_limite' then nullif(p->>'fecha_limite', '')::timestamptz else fecha_limite end,
    responsable_id = v_resp,
    colaboradores = array(select distinct x from unnest(v_col) x where x is distinct from v_resp),
    area_id = case when p ? 'area_id' then nullif(p->>'area_id', '')::uuid else coalesce(area_id, as_area_de(v_resp)) end,
    requiere_aprobacion = coalesce((p->>'requiere_aprobacion')::boolean, requiere_aprobacion),
    checklist = coalesce(p->'checklist', checklist),
    recurrencia = case when p ? 'recurrencia' then nullif(p->>'recurrencia', '') else recurrencia end,
    cliente = case when p ? 'cliente' then nullif(trim(p->>'cliente'), '') else cliente end
  where id = p_id;
  if cardinality(cambios) > 0 then
    perform private.as_tarea_evento(p_id, 'editada', array_to_string(cambios, ' · '), null, false);
  end if;
end $$;

create or replace function as_tarea_tomar(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare t as_tareas;
begin
  select * into t from as_tareas where id = p_id for update;
  if t.id is null or not as_ve_tarea(p_id) then raise exception 'Tarea no encontrada'; end if;
  if t.responsable_id is not null then raise exception 'Esta tarea ya tiene responsable'; end if;
  update as_tareas set responsable_id = auth.uid() where id = p_id;
  perform private.as_tarea_evento(p_id, 'tomada', 'Tomó la tarea');
end $$;

create or replace function private.as_siguiente_fecha(f timestamptz, r text) returns timestamptz language sql immutable as $$
  select case r when 'diaria' then f + interval '1 day' when 'semanal' then f + interval '7 days'
                when 'quincenal' then f + interval '15 days' when 'mensual' then f + interval '1 month' end
$$;

create or replace function as_tarea_estado(p_id bigint, p_estado text, p_nota text default null) returns text language plpgsql security definer set search_path = public as $$
declare
  t as_tareas; v_dest text := p_estado; v_gestiona boolean; v_participa boolean; v_txt text; v_num int; v_nueva bigint;
begin
  select * into t from as_tareas where id = p_id for update;
  if t.id is null or not as_ve_tarea(p_id) then raise exception 'Tarea no encontrada'; end if;
  v_gestiona := private.as_gestiona_tarea(t);
  v_participa := t.responsable_id = auth.uid() or auth.uid() = any(t.colaboradores);
  if p_estado not in ('pendiente','en_proceso','en_revision','bloqueada','completada','cancelada') then raise exception 'Estado no válido'; end if;
  if p_estado in ('bloqueada','cancelada') and coalesce(trim(p_nota), '') = '' then raise exception 'Escriba el motivo'; end if;

  if p_estado = 'completada' and t.estado = 'en_revision' then
    if not v_gestiona then raise exception 'Solo quien asignó la tarea puede aprobarla'; end if;
    v_txt := 'Aprobó la tarea';
  elsif p_estado = 'completada' then
    if not (v_participa or v_gestiona) then raise exception 'No es responsable de esta tarea'; end if;
    if t.requiere_aprobacion and not (v_gestiona and t.creado_por = auth.uid()) and not as_es_gerente() then
      v_dest := 'en_revision'; v_txt := 'Envió la tarea a revisión';
    else v_txt := 'Completó la tarea'; end if;
  elsif p_estado = 'en_revision' then
    if not (v_participa or v_gestiona) then raise exception 'No es responsable de esta tarea'; end if;
    v_txt := 'Envió la tarea a revisión';
  elsif p_estado = 'en_proceso' then
    if t.estado = 'en_revision' then
      if not v_gestiona then raise exception 'Solo quien asignó la tarea puede devolverla'; end if;
      v_txt := 'Devolvió la tarea';
    elsif t.estado in ('completada','cancelada') then
      if not v_gestiona then raise exception 'Solo quien asignó la tarea puede reabrirla'; end if;
      v_txt := 'Reabrió la tarea';
    else
      if not (v_participa or v_gestiona) then raise exception 'No es responsable de esta tarea'; end if;
      v_txt := case when t.estado = 'bloqueada' then 'Reanudó la tarea' else 'Inició la tarea' end;
    end if;
  elsif p_estado = 'pendiente' then
    if not (v_gestiona or v_participa) then raise exception 'Sin permiso'; end if;
    v_txt := case when t.estado in ('completada','cancelada') then 'Reabrió la tarea' else 'Regresó la tarea a pendiente' end;
    if t.estado in ('completada','cancelada') and not v_gestiona then raise exception 'Solo quien asignó la tarea puede reabrirla'; end if;
  elsif p_estado = 'bloqueada' then
    if not (v_participa or v_gestiona) then raise exception 'No es responsable de esta tarea'; end if;
    v_txt := 'Marcó la tarea como bloqueada';
  elsif p_estado = 'cancelada' then
    if not v_gestiona then raise exception 'Solo quien asignó la tarea puede cancelarla'; end if;
    v_txt := 'Canceló la tarea';
  end if;

  update as_tareas set estado = v_dest, estado_nota = nullif(trim(p_nota), ''),
    iniciada_en = case when v_dest = 'en_proceso' then coalesce(iniciada_en, now()) else iniciada_en end,
    completada_en = case when v_dest = 'completada' then now() when v_dest in ('pendiente','en_proceso') then null else completada_en end,
    aprobada_por = case when v_dest = 'completada' and t.estado = 'en_revision' then auth.uid() else aprobada_por end
  where id = p_id;
  perform private.as_tarea_evento(p_id, 'estado', v_txt || case when coalesce(trim(p_nota), '') <> '' then ': ' || trim(p_nota) else '' end,
    jsonb_build_object('de', t.estado, 'a', v_dest));

  -- Tarea recurrente: al completarla se crea la siguiente
  if v_dest = 'completada' and t.recurrencia is not null and not t.siguiente_creada then
    perform pg_advisory_xact_lock(hashtext('as_tareas:' || t.empresa_id));
    select coalesce(max(numero), 0) + 1 into v_num from as_tareas where empresa_id = t.empresa_id;
    insert into as_tareas(empresa_id, numero, titulo, descripcion, prioridad, area_id, responsable_id, colaboradores, creado_por,
      fecha_limite, requiere_aprobacion, checklist, recurrencia, recurrente_de, cliente, adjuntos)
    values (t.empresa_id, v_num, t.titulo, t.descripcion, t.prioridad, t.area_id, t.responsable_id, t.colaboradores, t.creado_por,
      private.as_siguiente_fecha(coalesce(t.fecha_limite, now()), t.recurrencia), t.requiere_aprobacion,
      (select coalesce(jsonb_agg(jsonb_build_object('t', x->>'t', 'ok', false)), '[]') from jsonb_array_elements(t.checklist) x),
      t.recurrencia, t.id, t.cliente, t.adjuntos)
    returning id into v_nueva;
    update as_tareas set siguiente_creada = true where id = t.id;
    insert into as_tarea_eventos(tarea_id, user_id, tipo, texto) values (v_nueva, auth.uid(), 'creada', 'Tarea recurrente (' || t.recurrencia || ') creada de T-' || t.numero);
  end if;
  return v_dest;
end $$;

create or replace function as_tarea_check(p_id bigint, p_idx int, p_ok boolean) returns void language plpgsql security definer set search_path = public as $$
declare t as_tareas; v_item text;
begin
  select * into t from as_tareas where id = p_id for update;
  if t.id is null or not as_ve_tarea(p_id) then raise exception 'Tarea no encontrada'; end if;
  if not (t.responsable_id = auth.uid() or auth.uid() = any(t.colaboradores) or private.as_gestiona_tarea(t)) then raise exception 'Sin permiso'; end if;
  if p_idx < 0 or p_idx >= jsonb_array_length(t.checklist) then raise exception 'Punto no encontrado'; end if;
  v_item := t.checklist->p_idx->>'t';
  update as_tareas set checklist = jsonb_set(checklist, array[p_idx::text],
      jsonb_build_object('t', v_item, 'ok', p_ok, 'por', case when p_ok then auth.uid() end, 'en', case when p_ok then now() end)),
    estado = case when estado = 'pendiente' and p_ok then 'en_proceso' else estado end,
    iniciada_en = case when p_ok then coalesce(iniciada_en, now()) else iniciada_en end
  where id = p_id;
  perform private.as_tarea_evento(p_id, 'checklist', case when p_ok then '☑ ' else '☐ ' end || v_item, null, false);
end $$;

create or replace function as_tarea_comentar(p_id bigint, p_texto text, p_archivo jsonb default null) returns void language plpgsql security definer set search_path = public as $$
begin
  if not as_ve_tarea(p_id) then raise exception 'Tarea no encontrada'; end if;
  if coalesce(trim(p_texto), '') = '' and p_archivo is null then raise exception 'Escriba un comentario'; end if;
  perform private.as_tarea_evento(p_id, 'comentario', coalesce(nullif(trim(p_texto), ''), '📎 ' || (p_archivo->>'nombre')),
    case when p_archivo is not null then jsonb_build_object('archivo', p_archivo) end);
end $$;

-- Resumen por persona (gerente y jefes)
create or replace function as_resumen(p_desde date, p_hasta date) returns table (
  user_id uuid, nombre text, area_id uuid, abiertas int, pendientes int, en_proceso int, en_revision int, bloqueadas int,
  vencidas int, completadas int, a_tiempo int, asignadas int, gestiones int)
language sql stable security definer set search_path = public as $$
  select m.user_id, private.as_nombre(m.user_id), m.area_id,
    count(*) filter (where t.estado in ('pendiente','en_proceso','en_revision','bloqueada'))::int,
    count(*) filter (where t.estado = 'pendiente')::int,
    count(*) filter (where t.estado = 'en_proceso')::int,
    count(*) filter (where t.estado = 'en_revision')::int,
    count(*) filter (where t.estado = 'bloqueada')::int,
    count(*) filter (where t.estado in ('pendiente','en_proceso','bloqueada') and t.fecha_limite < now())::int,
    count(*) filter (where t.estado = 'completada' and (t.completada_en at time zone 'America/Tegucigalpa')::date between p_desde and p_hasta)::int,
    count(*) filter (where t.estado = 'completada' and (t.completada_en at time zone 'America/Tegucigalpa')::date between p_desde and p_hasta
                     and (t.fecha_limite is null or t.completada_en <= t.fecha_limite))::int,
    count(*) filter (where (t.creado_en at time zone 'America/Tegucigalpa')::date between p_desde and p_hasta)::int,
    (select count(*) from as_mensajes g where g.tipo = 'gestion' and g.user_id = m.user_id and not g.borrado
       and (g.creado_en at time zone 'America/Tegucigalpa')::date between p_desde and p_hasta)::int
  from as_miembros m
  left join as_tareas t on t.responsable_id = m.user_id
  where m.empresa_id = as_empresa() and m.activo
    and (as_es_gerente() or m.area_id = any(as_areas_jefe()) or m.user_id = auth.uid())
  group by m.user_id, m.area_id
$$;

-- Gestiones de cobro reportadas en los chats
create or replace function as_gestiones(p_desde date, p_hasta date) returns table (
  id bigint, chat_id bigint, chat text, user_id uuid, gestor text, creado_en timestamptz, datos jsonb, texto text)
language sql stable security definer set search_path = public as $$
  select g.id, g.chat_id, coalesce(c.nombre, 'Chat directo'), g.user_id, private.as_nombre(g.user_id), g.creado_en, g.datos, g.texto
  from as_mensajes g join as_chats c on c.id = g.chat_id
  where g.tipo = 'gestion' and not g.borrado and c.empresa_id = as_empresa()
    and (g.creado_en at time zone 'America/Tegucigalpa')::date between p_desde and p_hasta
    and (as_es_gerente() or g.user_id = auth.uid() or as_area_de(g.user_id) = any(as_areas_jefe()) or as_soy_miembro(g.chat_id))
  order by g.creado_en desc
$$;

-- ============================================================
-- Comunicados
-- ============================================================
create or replace function as_publicar_comunicado(p jsonb) returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint; c as_comunicados; v_areas uuid[]; v_us uuid[]; v_dest text := coalesce(p->>'destino', 'todos');
begin
  if not (as_es_gerente() or cardinality(as_areas_jefe()) > 0) then raise exception 'Solo el gerente y los jefes pueden enviar comunicados'; end if;
  if coalesce(trim(p->>'titulo'), '') = '' then raise exception 'Escriba el título'; end if;
  v_areas := array(select (x)::uuid from jsonb_array_elements_text(coalesce(p->'areas', '[]')) x);
  v_us := array(select (x)::uuid from jsonb_array_elements_text(coalesce(p->'usuarios', '[]')) x);
  if not as_es_gerente() then
    if v_dest = 'todos' then raise exception 'Como jefe puede enviar comunicados solo a sus áreas o personas de ellas'; end if;
    if exists (select 1 from unnest(v_areas) a where not a = any(as_areas_jefe())) then raise exception 'Solo puede enviar a sus áreas'; end if;
    if exists (select 1 from unnest(v_us) u where not as_puede_asignar_a(u)) then raise exception 'Solo puede enviar a personas de sus áreas'; end if;
  end if;
  if v_dest = 'areas' and cardinality(v_areas) = 0 then raise exception 'Elija al menos un área'; end if;
  if v_dest = 'personas' and cardinality(v_us) = 0 then raise exception 'Elija al menos una persona'; end if;
  insert into as_comunicados(empresa_id, titulo, cuerpo, importancia, destino, areas, usuarios, requiere_confirmacion, fijado, adjuntos, creado_por)
  values (as_empresa(), trim(p->>'titulo'), nullif(trim(p->>'cuerpo'), ''), coalesce(p->>'importancia', 'normal'), v_dest, v_areas, v_us,
    coalesce((p->>'requiere_confirmacion')::boolean, false), coalesce((p->>'fijado')::boolean, false), coalesce(p->'adjuntos', '[]'), auth.uid())
  returning * into c;
  insert into as_comunicado_lecturas(comunicado_id, user_id, confirmado_en) values (c.id, auth.uid(), now()) on conflict do nothing;
  perform private.as_push(array(select m.user_id from as_miembros m where m.empresa_id = c.empresa_id and m.activo and private.as_es_dest(c, m.user_id)),
    case c.importancia when 'urgente' then '🚨 Comunicado urgente' when 'importante' then '📢 Comunicado importante' else '📢 Comunicado' end,
    c.titulo, '#/comunicado/' || c.id, 'com-' || c.id);
  return c.id;
end $$;

create or replace function as_comunicado_visto(p_id bigint, p_confirmar boolean default false) returns void language plpgsql security definer set search_path = public as $$
begin
  if not as_ve_comunicado(p_id) then raise exception 'Comunicado no encontrado'; end if;
  insert into as_comunicado_lecturas(comunicado_id, user_id, confirmado_en) values (p_id, auth.uid(), case when p_confirmar then now() end)
  on conflict (comunicado_id, user_id) do update set confirmado_en = coalesce(as_comunicado_lecturas.confirmado_en, excluded.confirmado_en);
end $$;

create or replace function as_comunicado_estado(p_id bigint) returns table (user_id uuid, nombre text, area_id uuid, visto_en timestamptz, confirmado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select m.user_id, private.as_nombre(m.user_id), m.area_id, l.visto_en, l.confirmado_en
  from as_comunicados c join as_miembros m on m.empresa_id = c.empresa_id and m.activo and private.as_es_dest(c, m.user_id)
  left join as_comunicado_lecturas l on l.comunicado_id = c.id and l.user_id = m.user_id
  where c.id = p_id and (c.creado_por = auth.uid() or as_es_gerente()) and m.user_id <> c.creado_por
  order by l.confirmado_en nulls first, l.visto_en nulls first, 2
$$;

create or replace function as_comunicado_recordar(p_id bigint) returns int language plpgsql security definer set search_path = public as $$
declare c as_comunicados; v_ids uuid[];
begin
  select * into c from as_comunicados where id = p_id;
  if c.id is null or not (c.creado_por = auth.uid() or as_es_gerente()) then raise exception 'Sin permiso'; end if;
  v_ids := array(select m.user_id from as_miembros m where m.empresa_id = c.empresa_id and m.activo and private.as_es_dest(c, m.user_id)
     and not exists (select 1 from as_comunicado_lecturas l where l.comunicado_id = c.id and l.user_id = m.user_id
                     and (l.confirmado_en is not null or not c.requiere_confirmacion)));
  perform private.as_push(v_ids, '⏰ Recordatorio de comunicado', c.titulo, '#/comunicado/' || c.id, 'com-' || c.id);
  return coalesce(array_length(v_ids, 1), 0);
end $$;

create or replace function as_comunicado_archivar(p_id bigint, p_archivar boolean, p_fijado boolean default null) returns void language plpgsql security definer set search_path = public as $$
begin
  update as_comunicados set archivado = coalesce(p_archivar, archivado), fijado = coalesce(p_fijado, fijado)
  where id = p_id and empresa_id = as_empresa() and (creado_por = auth.uid() or as_es_gerente());
  if not found then raise exception 'Sin permiso'; end if;
end $$;

-- ============================================================
-- Chat
-- ============================================================
create or replace function as_mis_chats() returns table (
  id bigint, tipo text, nombre text, descripcion text, foto text, area_id uuid, otro uuid, solo_admins boolean,
  ultimo_id bigint, ultimo_en timestamptz, ultimo_texto text, ultimo_user uuid, ultimo_tipo text,
  no_leidos int, silenciado boolean, fijado boolean, archivado boolean, admin boolean, miembros int, creado_en timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.tipo, c.nombre, c.descripcion, c.foto, c.area_id,
    case when c.tipo = 'directo' then (select o.user_id from as_chat_miembros o where o.chat_id = c.id and o.user_id <> auth.uid() limit 1) end,
    c.solo_admins, c.ultimo_id, c.ultimo_en, c.ultimo_texto, c.ultimo_user, c.ultimo_tipo,
    (select count(*) from as_mensajes x where x.chat_id = c.id and x.id > cm.leido_id and x.user_id is distinct from auth.uid() and not x.borrado and x.tipo <> 'sistema')::int,
    cm.silenciado, cm.fijado, cm.archivado, cm.admin,
    (select count(*) from as_chat_miembros o where o.chat_id = c.id)::int, c.creado_en
  from as_chat_miembros cm join as_chats c on c.id = cm.chat_id
  where cm.user_id = auth.uid() and c.empresa_id = as_empresa()
$$;

create or replace function as_chat_directo(p_uid uuid) returns bigint language plpgsql security definer set search_path = public as $$
declare v_clave text; v_id bigint; v_emp uuid := as_empresa();
begin
  if v_emp is null then raise exception 'Sin acceso'; end if;
  if p_uid = auth.uid() then raise exception 'Elija a otra persona'; end if;
  if not exists (select 1 from as_miembros where user_id = p_uid and empresa_id = v_emp) then raise exception 'Persona no encontrada'; end if;
  v_clave := 'dm:' || least(p_uid::text, auth.uid()::text) || ':' || greatest(p_uid::text, auth.uid()::text);
  select id into v_id from as_chats where clave = v_clave;
  if v_id is null then
    insert into as_chats(empresa_id, tipo, clave, creado_por) values (v_emp, 'directo', v_clave, auth.uid())
    on conflict (clave) do nothing returning id into v_id;
    if v_id is null then select id into v_id from as_chats where clave = v_clave; end if;
    insert into as_chat_miembros(chat_id, user_id) values (v_id, auth.uid()), (v_id, p_uid) on conflict do nothing;
  end if;
  return v_id;
end $$;

create or replace function as_crear_grupo(p_nombre text, p_miembros uuid[], p_descripcion text default null, p_foto text default null)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_emp uuid := as_empresa();
begin
  if v_emp is null then raise exception 'Sin acceso'; end if;
  if coalesce(trim(p_nombre), '') = '' then raise exception 'Escriba el nombre del grupo'; end if;
  insert into as_chats(empresa_id, tipo, nombre, descripcion, foto, creado_por) values (v_emp, 'grupo', trim(p_nombre), nullif(trim(p_descripcion), ''), p_foto, auth.uid())
  returning id into v_id;
  insert into as_chat_miembros(chat_id, user_id, admin) values (v_id, auth.uid(), true);
  insert into as_chat_miembros(chat_id, user_id)
  select v_id, m.user_id from as_miembros m where m.user_id = any(p_miembros) and m.empresa_id = v_emp and m.activo and m.user_id <> auth.uid()
  on conflict do nothing;
  insert into as_mensajes(chat_id, user_id, tipo, texto) values (v_id, auth.uid(), 'sistema', private.as_nombre(auth.uid()) || ' creó el grupo "' || trim(p_nombre) || '"');
  return v_id;
end $$;

create or replace function as_admin_chat(p_chat bigint) returns boolean language sql stable security definer set search_path = public as $$
  select as_es_gerente() and exists (select 1 from as_chats where id = p_chat and empresa_id = as_empresa())
      or exists (select 1 from as_chat_miembros where chat_id = p_chat and user_id = auth.uid() and admin)
$$;

create or replace function as_grupo_editar(p_chat bigint, p_nombre text, p_descripcion text, p_foto text, p_solo_admins boolean)
returns void language plpgsql security definer set search_path = public as $$
declare c as_chats;
begin
  select * into c from as_chats where id = p_chat;
  if c.tipo = 'directo' or not as_admin_chat(p_chat) then raise exception 'Solo los administradores del grupo pueden cambiar esto'; end if;
  update as_chats set nombre = case when c.tipo = 'grupo' then coalesce(nullif(trim(p_nombre), ''), nombre) else nombre end,
    descripcion = coalesce(p_descripcion, descripcion), foto = case when p_foto = '-' then null else coalesce(p_foto, foto) end,
    solo_admins = coalesce(p_solo_admins, solo_admins)
  where id = p_chat;
  if c.tipo = 'grupo' and nullif(trim(p_nombre), '') is distinct from c.nombre and nullif(trim(p_nombre), '') is not null then
    insert into as_mensajes(chat_id, user_id, tipo, texto) values (p_chat, auth.uid(), 'sistema', private.as_nombre(auth.uid()) || ' cambió el nombre a "' || trim(p_nombre) || '"');
  end if;
end $$;

create or replace function as_grupo_miembros(p_chat bigint, p_agregar uuid[], p_quitar uuid[], p_admins uuid[] default null)
returns void language plpgsql security definer set search_path = public as $$
declare c as_chats; u uuid;
begin
  select * into c from as_chats where id = p_chat;
  if c.tipo <> 'grupo' then raise exception 'Los miembros de este grupo se manejan por área'; end if;
  if not as_admin_chat(p_chat) then raise exception 'Solo los administradores del grupo pueden cambiar miembros'; end if;
  foreach u in array coalesce(p_agregar, '{}') loop
    if exists (select 1 from as_miembros where user_id = u and empresa_id = c.empresa_id and activo) then
      insert into as_chat_miembros(chat_id, user_id) values (p_chat, u) on conflict do nothing;
      if found then insert into as_mensajes(chat_id, user_id, tipo, texto) values (p_chat, auth.uid(), 'sistema', private.as_nombre(auth.uid()) || ' agregó a ' || private.as_nombre(u)); end if;
    end if;
  end loop;
  foreach u in array coalesce(p_quitar, '{}') loop
    delete from as_chat_miembros where chat_id = p_chat and user_id = u;
    if found then insert into as_mensajes(chat_id, user_id, tipo, texto) values (p_chat, auth.uid(), 'sistema', private.as_nombre(auth.uid()) || ' eliminó a ' || private.as_nombre(u)); end if;
  end loop;
  if p_admins is not null then
    update as_chat_miembros set admin = (user_id = any(p_admins) or user_id = auth.uid()) where chat_id = p_chat;
  end if;
end $$;

create or replace function as_salir_grupo(p_chat bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  if (select tipo from as_chats where id = p_chat) <> 'grupo' then raise exception 'No puede salir de los grupos de área o de la empresa'; end if;
  insert into as_mensajes(chat_id, user_id, tipo, texto) values (p_chat, auth.uid(), 'sistema', private.as_nombre(auth.uid()) || ' salió del grupo');
  delete from as_chat_miembros where chat_id = p_chat and user_id = auth.uid();
  -- si no quedan administradores, el más antiguo pasa a serlo
  if not exists (select 1 from as_chat_miembros where chat_id = p_chat and admin) then
    update as_chat_miembros set admin = true where chat_id = p_chat and user_id = (select user_id from as_chat_miembros where chat_id = p_chat order by unido_en limit 1);
  end if;
end $$;

create or replace function as_chat_config(p_chat bigint, p_silenciado boolean, p_fijado boolean, p_archivado boolean) returns void language sql security definer set search_path = public as $$
  update as_chat_miembros set silenciado = coalesce(p_silenciado, silenciado), fijado = coalesce(p_fijado, fijado), archivado = coalesce(p_archivado, archivado)
  where chat_id = p_chat and user_id = auth.uid()
$$;

create or replace function as_marcar_leido(p_chat bigint, p_id bigint) returns void language sql security definer set search_path = public as $$
  update as_chat_miembros set leido_id = greatest(leido_id, p_id), leido_en = now(), recibido_id = greatest(recibido_id, p_id)
  where chat_id = p_chat and user_id = auth.uid() and leido_id < p_id
$$;

-- Marca como recibidos (doble palomita gris) los últimos mensajes de todos mis chats
create or replace function as_marcar_recibido() returns void language sql security definer set search_path = public as $$
  update as_chat_miembros cm set recibido_id = c.ultimo_id
  from as_chats c where c.id = cm.chat_id and cm.user_id = auth.uid() and c.ultimo_id is not null and cm.recibido_id < c.ultimo_id
$$;

create or replace function as_editar_mensaje(p_id bigint, p_texto text) returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_texto), '') = '' then raise exception 'El mensaje no puede quedar vacío'; end if;
  update as_mensajes set texto = p_texto, editado_en = now()
  where id = p_id and user_id = auth.uid() and tipo = 'texto' and not borrado and creado_en > now() - interval '15 minutes';
  if not found then raise exception 'Solo puede editar sus mensajes de texto en los primeros 15 minutos'; end if;
end $$;

create or replace function as_borrar_mensaje(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare m as_mensajes;
begin
  select * into m from as_mensajes where id = p_id;
  if m.id is null or not (m.user_id = auth.uid() or as_admin_chat(m.chat_id)) then raise exception 'Solo puede eliminar sus mensajes'; end if;
  update as_mensajes set borrado = true, texto = null, archivo = null, datos = case when tipo = 'gestion' then datos else null end where id = p_id;
  update as_chats set ultimo_texto = '🚫 Mensaje eliminado' where id = m.chat_id and ultimo_id = p_id;
end $$;

create or replace function as_reaccionar(p_id bigint, p_emoji text) returns void language plpgsql security definer set search_path = public as $$
declare v_chat bigint;
begin
  select chat_id into v_chat from as_mensajes where id = p_id;
  if v_chat is null or not as_soy_miembro(v_chat) then raise exception 'Mensaje no encontrado'; end if;
  insert into as_reacciones(mensaje_id, user_id, chat_id, emoji) values (p_id, auth.uid(), v_chat, nullif(p_emoji, ''))
  on conflict (mensaje_id, user_id) do update set emoji = nullif(p_emoji, ''), creado_en = now();
end $$;

create or replace function as_votar(p_id bigint, p_opciones int[]) returns void language plpgsql security definer set search_path = public as $$
declare v_chat bigint;
begin
  select chat_id into v_chat from as_mensajes where id = p_id and tipo = 'encuesta' and not borrado;
  if v_chat is null or not as_soy_miembro(v_chat) then raise exception 'Encuesta no encontrada'; end if;
  insert into as_votos(mensaje_id, user_id, chat_id, opciones) values (p_id, auth.uid(), v_chat, coalesce(p_opciones, '{}'))
  on conflict (mensaje_id, user_id) do update set opciones = excluded.opciones, creado_en = now();
end $$;

-- Al insertar un mensaje: actualiza el chat, mi lectura y avisa
create or replace function private.as_tg_mensaje() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.responde_a is not null and not exists (select 1 from as_mensajes where id = new.responde_a and chat_id = new.chat_id) then
    new.responde_a := null;
  end if;
  return new;
end $$;

create or replace function private.as_tg_mensaje_after() returns trigger language plpgsql security definer set search_path = public as $$
declare c as_chats; v_prev text; v_ids uuid[]; v_quien text;
begin
  v_prev := case new.tipo
    when 'texto' then new.texto
    when 'imagen' then '📷 ' || coalesce(nullif(new.texto, ''), 'Foto')
    when 'audio' then '🎤 Nota de voz'
    when 'archivo' then '📄 ' || coalesce(new.archivo->>'nombre', 'Documento')
    when 'ubicacion' then '📍 ' || coalesce(new.datos->>'etiqueta', 'Ubicación')
    when 'tarea' then '📋 Tarea: ' || coalesce(new.datos->>'titulo', '')
    when 'gestion' then '💰 Gestión: ' || coalesce(new.datos->>'cliente', '') || ' · ' || coalesce(new.datos->>'resultado', '')
    when 'encuesta' then '📊 ' || coalesce(new.datos->>'pregunta', 'Encuesta')
    else new.texto end;
  update as_chats set ultimo_id = new.id, ultimo_en = new.creado_en, ultimo_texto = left(v_prev, 160), ultimo_user = new.user_id, ultimo_tipo = new.tipo
  where id = new.chat_id returning * into c;
  if new.user_id is not null then
    update as_chat_miembros set leido_id = new.id, recibido_id = new.id, leido_en = now(), archivado = false
    where chat_id = new.chat_id and user_id = new.user_id;
  end if;
  -- quien tenía el chat archivado lo vuelve a ver (como WhatsApp)
  update as_chat_miembros set archivado = false where chat_id = new.chat_id and archivado and not silenciado;
  if new.tipo <> 'sistema' then
    v_quien := private.as_nombre(new.user_id);
    v_ids := array(select user_id from as_chat_miembros where chat_id = new.chat_id and user_id <> new.user_id
                   and (not silenciado or (new.texto ilike '%@' || coalesce(private.as_nombre(user_id), '¬') || '%')));
    perform private.as_push(v_ids,
      case when c.tipo = 'directo' then v_quien else coalesce(c.nombre, 'Grupo') end,
      case when c.tipo = 'directo' then v_prev else v_quien || ': ' || v_prev end,
      '#/chat/' || new.chat_id, 'chat-' || new.chat_id);
  end if;
  return new;
end $$;

drop trigger if exists as_mensajes_bi on as_mensajes;
create trigger as_mensajes_bi before insert on as_mensajes for each row execute function private.as_tg_mensaje();
drop trigger if exists as_mensajes_ai on as_mensajes;
create trigger as_mensajes_ai after insert on as_mensajes for each row execute function private.as_tg_mensaje_after();

-- ============================================================
-- RLS
-- ============================================================
alter table as_areas enable row level security;
alter table as_miembros enable row level security;
alter table as_tareas enable row level security;
alter table as_tarea_eventos enable row level security;
alter table as_comunicados enable row level security;
alter table as_comunicado_lecturas enable row level security;
alter table as_chats enable row level security;
alter table as_chat_miembros enable row level security;
alter table as_mensajes enable row level security;
alter table as_reacciones enable row level security;
alter table as_votos enable row level security;
alter table as_push_subs enable row level security;

drop policy if exists as_areas_sel on as_areas;
create policy as_areas_sel on as_areas for select to authenticated using (empresa_id = as_empresa());
drop policy if exists as_miembros_sel on as_miembros;
create policy as_miembros_sel on as_miembros for select to authenticated using (empresa_id = as_empresa());
drop policy if exists as_tareas_sel on as_tareas;
create policy as_tareas_sel on as_tareas for select to authenticated using (as_ve_tarea(id));
drop policy if exists as_tarea_eventos_sel on as_tarea_eventos;
create policy as_tarea_eventos_sel on as_tarea_eventos for select to authenticated using (as_ve_tarea(tarea_id));
drop policy if exists as_comunicados_sel on as_comunicados;
create policy as_comunicados_sel on as_comunicados for select to authenticated using (as_ve_comunicado(id));
drop policy if exists as_com_lect_sel on as_comunicado_lecturas;
create policy as_com_lect_sel on as_comunicado_lecturas for select to authenticated
  using (user_id = auth.uid() or exists (select 1 from as_comunicados c where c.id = comunicado_id and (c.creado_por = auth.uid() or as_es_gerente()) and c.empresa_id = as_empresa()));
drop policy if exists as_chats_sel on as_chats;
create policy as_chats_sel on as_chats for select to authenticated using (as_soy_miembro(id));
drop policy if exists as_chat_miembros_sel on as_chat_miembros;
create policy as_chat_miembros_sel on as_chat_miembros for select to authenticated using (as_soy_miembro(chat_id));
drop policy if exists as_mensajes_sel on as_mensajes;
create policy as_mensajes_sel on as_mensajes for select to authenticated using (as_soy_miembro(chat_id));
drop policy if exists as_mensajes_ins on as_mensajes;
create policy as_mensajes_ins on as_mensajes for insert to authenticated with check (
  user_id = auth.uid() and tipo <> 'sistema' and not borrado and as_soy_miembro(chat_id)
  and (not exists (select 1 from as_chats c where c.id = chat_id and c.solo_admins) or as_admin_chat(chat_id)));
drop policy if exists as_reacciones_sel on as_reacciones;
create policy as_reacciones_sel on as_reacciones for select to authenticated using (as_soy_miembro(chat_id));
drop policy if exists as_votos_sel on as_votos;
create policy as_votos_sel on as_votos for select to authenticated using (as_soy_miembro(chat_id));
drop policy if exists as_push_sel on as_push_subs;
create policy as_push_sel on as_push_subs for select to authenticated using (user_id = auth.uid());

revoke all on function private.as_sync(uuid) from public, anon, authenticated;
revoke all on function private.as_push(uuid[], text, text, text, text) from public, anon, authenticated;

-- ============================================================
-- Tiempo real
-- ============================================================
alter table as_mensajes replica identity full;
alter table as_chat_miembros replica identity full;
do $$ declare t text; begin
  foreach t in array array['as_mensajes','as_chat_miembros','as_chats','as_reacciones','as_votos','as_tareas','as_tarea_eventos','as_comunicados','as_miembros'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ============================================================
-- Archivos (privado): <empresa>/chats/<chat_id>/..., <empresa>/tareas/..., <empresa>/comunicados/..., <empresa>/fotos/...
-- ============================================================
insert into storage.buckets(id, name, public, file_size_limit) values ('asigname', 'asigname', false, 26214400)
on conflict (id) do nothing;

drop policy if exists as_files_sel on storage.objects;
create policy as_files_sel on storage.objects for select to authenticated using (
  bucket_id = 'asigname' and (storage.foldername(name))[1] = as_empresa()::text
  and ((storage.foldername(name))[2] <> 'chats' or as_soy_miembro(((storage.foldername(name))[3])::bigint)));
drop policy if exists as_files_ins on storage.objects;
create policy as_files_ins on storage.objects for insert to authenticated with check (
  bucket_id = 'asigname' and (storage.foldername(name))[1] = as_empresa()::text
  and ((storage.foldername(name))[2] <> 'chats' or as_soy_miembro(((storage.foldername(name))[3])::bigint)));

-- Áreas iniciales
insert into as_areas(empresa_id, nombre, color, orden)
select e.id, a.nombre, a.color, a.orden from pl_empresas e,
  (values ('Administración', '#0B5AD6', 1), ('Créditos', '#7C3AED', 2), ('Cobros', '#F59E0B', 3), ('Recuperación', '#EF4444', 4), ('Incobrables', '#64748B', 5)) a(nombre, color, orden)
where e.principal
on conflict do nothing;

select private.as_sync(id) from pl_empresas where principal;
