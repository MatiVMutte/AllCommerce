-- AllCommerce · 0021 · Endurecimiento de DB, coordenadas en create_tenant y buscador global de productos

-- 1) Eliminar overload viejo de create_tenant y reemplazar el actual con soporte de lat/lng opcionales
drop function if exists public.create_tenant(text, text, text, text, text, text, text);
drop function if exists public.create_tenant(text, text, text, text, text);

create or replace function public.create_tenant(
  p_slug text,
  p_name text,
  p_whatsapp text,
  p_address text,
  p_full_name text,
  p_lat numeric default null,
  p_lng numeric default null
)
returns public.tenants
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_existing public.users;
  v_tenant public.tenants;
  v_clean_phone text := regexp_replace(p_whatsapp, '\D', '', 'g');
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_existing from public.users where id = v_uid;
  if found and v_existing.tenant_id is not null then
    raise exception 'PROFILE_EXISTS' using errcode = 'P0001';
  end if;

  begin
    insert into public.tenants (
      slug, name, whatsapp, address, lat, lng, plan, plan_expires_at, is_active, is_claimed
    )
    values (
      lower(trim(p_slug)),
      trim(p_name),
      v_clean_phone,
      nullif(trim(p_address), ''),
      p_lat,
      p_lng,
      'free',
      now() + interval '100 years',
      true,
      true
    )
    returning * into v_tenant;
  exception when unique_violation then
    raise exception 'SLUG_TAKEN' using errcode = 'P0001';
  end;

  insert into public.users (id, tenant_id, role, full_name, phone)
  values (v_uid, v_tenant.id, 'owner', trim(p_full_name), nullif(v_clean_phone, ''))
  on conflict (id) do update
    set tenant_id = excluded.tenant_id,
        role = 'owner',
        full_name = coalesce(nullif(excluded.full_name, ''), public.users.full_name),
        phone = coalesce(nullif(public.users.phone, ''), excluded.phone);

  return v_tenant;
end;
$$;

-- 2) Revocar ejecución anónima en funciones SECURITY DEFINER que exigen sesión
revoke all on function public.create_tenant(text, text, text, text, text, numeric, numeric) from public, anon;
grant execute on function public.create_tenant(text, text, text, text, text, numeric, numeric) to authenticated;

revoke all on function public.admin_tenants_overview() from public, anon;
grant execute on function public.admin_tenants_overview() to authenticated;

revoke all on function public.owner_sales_metrics(uuid) from public, anon;
grant execute on function public.owner_sales_metrics(uuid) to authenticated;

revoke all on function public.place_order(uuid, jsonb, text, text, public.delivery_method, text, numeric, public.payment_method, text) from public, anon;
grant execute on function public.place_order(uuid, jsonb, text, text, public.delivery_method, text, numeric, public.payment_method, text) to authenticated;

-- 3) Optimizar RLS de user_devices con (select auth.uid()) e índice de FK en tenants(plan)
drop policy if exists user_devices_insert_update_own on public.user_devices;
create policy user_devices_insert_update_own on public.user_devices
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create index if not exists tenants_plan_idx on public.tenants (plan);

-- 4) Buscador global de productos activos en locales activos y reclamados
create or replace function public.search_public_products(
  p_query text,
  p_limit int default 16
)
returns table (
  product_id uuid,
  tenant_id uuid,
  title text,
  description text,
  category text,
  price numeric,
  compare_at_price numeric,
  image_url text,
  stock int,
  track_stock boolean,
  tenant_slug text,
  tenant_name text,
  tenant_logo_url text,
  tenant_primary_color text,
  tenant_is_open boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    p.id as product_id,
    p.tenant_id,
    p.title,
    p.description,
    p.category,
    p.price,
    p.compare_at_price,
    p.image_url,
    p.stock,
    p.track_stock,
    t.slug as tenant_slug,
    t.name as tenant_name,
    t.logo_url as tenant_logo_url,
    t.primary_color as tenant_primary_color,
    t.is_open as tenant_is_open
  from public.products p
  join public.tenants t on t.id = p.tenant_id
  where p.is_active = true
    and t.is_active = true
    and t.is_claimed = true
    and t.plan_expires_at > now()
    and length(trim(coalesce(p_query, ''))) >= 2
    and (
      p.title ilike '%' || trim(p_query) || '%'
      or coalesce(p.description, '') ilike '%' || trim(p_query) || '%'
      or exists (
        select 1
        from unnest(p.tags) as tag
        where tag ilike '%' || trim(p_query) || '%'
      )
    )
  order by
    case when lower(p.title) like lower(trim(p_query)) || '%' then 0 else 1 end,
    p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 16), 40));
$$;

grant execute on function public.search_public_products(text, int) to anon, authenticated;
