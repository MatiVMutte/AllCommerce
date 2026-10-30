-- 0026_catalog_visits.sql
-- Contador de visitas al catalogo publico de cada local.

create table if not exists public.catalog_visits (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists catalog_visits_tenant_created
  on public.catalog_visits (tenant_id, created_at desc);

alter table public.catalog_visits enable row level security;

-- Cualquiera (logueado o no) puede registrar una visita; nadie lee filas
-- ajenas. El dueno solo lee las de su local para las metricas.
drop policy if exists catalog_visits_insert on public.catalog_visits;
create policy catalog_visits_insert
  on public.catalog_visits for insert
  to anon, authenticated
  with check (true);

drop policy if exists catalog_visits_select_owner on public.catalog_visits;
create policy catalog_visits_select_owner
  on public.catalog_visits for select
  to authenticated
  using (tenant_id = (select private.current_tenant_id()));

-- Conteos agregados para el panel del dueno (una sola llamada RPC,
-- evita exponer filas individuales).
create or replace function public.catalog_visit_counts(p_tenant_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'week', (
      select count(*) from public.catalog_visits
      where tenant_id = p_tenant_id
        and created_at >= now() - interval '7 days'
    ),
    'total', (
      select count(*) from public.catalog_visits
      where tenant_id = p_tenant_id
    )
  )
  where p_tenant_id = (select private.current_tenant_id());
$$;

grant execute on function public.catalog_visit_counts(uuid) to authenticated;
