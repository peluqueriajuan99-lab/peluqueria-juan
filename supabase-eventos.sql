-- Agenda de eventos (aniversarios, fechas especiales, etc.)
-- Pegalo en Supabase → SQL Editor → Run. Se puede ejecutar más de una vez.
-- Reutiliza el permiso del panel: solo el equipo puede leer o modificar eventos.

create table if not exists public.eventos (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  fecha date not null,
  tipo text not null default 'especial',
  anual boolean not null default false,
  cliente_id text,
  notas text not null default '',
  creado timestamptz not null default now()
);
alter table public.eventos enable row level security;  -- sin políticas: solo se accede por las funciones

create or replace function public.panel_eventos_listar() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.panel_estado();  -- falla si no sos del equipo
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'titulo', titulo, 'fecha', to_char(fecha, 'YYYY-MM-DD'),
    'tipo', tipo, 'anual', anual, 'clienteId', cliente_id, 'notas', notas) order by fecha) from public.eventos), '[]'::jsonb);
end $$;

create or replace function public.panel_evento_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.panel_estado();
  if coalesce(trim(p->>'titulo'), '') = '' then raise exception 'Falta el título'; end if;
  insert into public.eventos (id, titulo, fecha, tipo, anual, cliente_id, notas)
  values ((p->>'id')::uuid, trim(p->>'titulo'), (p->>'fecha')::date, coalesce(nullif(p->>'tipo', ''), 'especial'),
          coalesce((p->>'anual')::boolean, false), nullif(p->>'clienteId', ''), coalesce(p->>'notas', ''))
  on conflict (id) do update set titulo = excluded.titulo, fecha = excluded.fecha, tipo = excluded.tipo,
    anual = excluded.anual, cliente_id = excluded.cliente_id, notas = excluded.notas;
  return to_jsonb(true);
end $$;

create or replace function public.panel_evento_borrar(p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform public.panel_estado();
  delete from public.eventos where id = p_id::uuid;
  return to_jsonb(true);
end $$;

revoke all on function public.panel_eventos_listar(), public.panel_evento_guardar(jsonb), public.panel_evento_borrar(text) from public, anon;
grant execute on function public.panel_eventos_listar(), public.panel_evento_guardar(jsonb), public.panel_evento_borrar(text) to authenticated;
