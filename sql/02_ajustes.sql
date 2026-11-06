-- Asígname · ajustes aplicados después de 01_asigname_base.sql (6-nov-2026)
-- 1) Vista previa legible de gestiones de cobro en la lista de chats (private.as_resultado + private.as_tg_mensaje_after).
-- 2) private.as_sync: al crear el miembro usa el nombre de VerifyCredit (perfiles.nombre) como nombre corto si la persona está en ambas apps.
-- 3) search_path fijo en funciones auxiliares; funciones as_* ejecutables solo por usuarios con sesión (no anónimos).
alter function private.as_norm(text) set search_path = public;
alter function private.as_siguiente_fecha(timestamptz, text) set search_path = public;
do $$ declare f record; begin
  for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'as\_%' loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
-- (Las definiciones completas de private.as_resultado, private.as_tg_mensaje_after y private.as_sync
--  están en la base; ver migraciones asigname_04_ajustes y asigname_05_permisos en Supabase.)
