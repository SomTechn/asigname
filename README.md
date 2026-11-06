# Asígname

Tareas, comunicados y chat del equipo (estilo WhatsApp) para Más Pisto.
Usa la misma base de Supabase (`edmvfqelxsxevpmxgbav`) y las mismas cuentas que VerifyCredit y Mi Planilla.

- `index.html`: toda la app (vanilla JS + supabase-js). La versión está en `APP_VER` y en `version.json` (súbalos juntos; la app se recarga sola al ver una versión nueva).
- `sw.js`: service worker (abre sin conexión y muestra notificaciones). Cambie `CACHE` si cambia los íconos.
- `sql/`: tablas `as_*`, funciones y permisos.
- Notificaciones: Edge Function `asigname-push` (misma clave VAPID del proyecto), tabla `as_push_subs`.

Roles: gerente (todo), jefe de área (asigna y envía comunicados a sus áreas), miembro (tareas propias y chat).
Las personas, cargos y áreas se toman de `perfiles` (VerifyCredit) y `pl_empleados` (Mi Planilla) cada vez que alguien abre la app.
