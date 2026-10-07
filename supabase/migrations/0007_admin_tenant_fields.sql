-- AllCommerce · 0007 · Expose location + claim status in admin overview

create or replace function public.admin_tenants_overview()
returns table (
  id uuid,
  name text,
  slug text,
  zone text,
  address text,
  lat numeric(10,8),
  lng numeric(11,8),
  plan public.plan_type,
  plan_expires_at timestamptz,
  is_active boolean,
  is_claimed boolean,
  created_at timestamptz,
  owner_name text,
  owner_email text,
  owner_phone text,
  last_sign_in_at timestamptz,
  product_count bigint,
  order_count bigint,
  last_order_at timestamptz,
  ai_used_month int
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    t.id, t.name, t.slug, t.zone, t.address, t.lat, t.lng,
    t.plan, t.plan_expires_at, t.is_active, t.is_claimed, t.created_at,
    u.full_name, a.email, u.phone, a.last_sign_in_at,
    (select count(*) from public.products p where p.tenant_id = t.id),
    (select count(*) from public.orders o where o.tenant_id = t.id),
    (select max(o.created_at) from public.orders o where o.tenant_id = t.id),
    coalesce((select au.used from public.ai_usage au
              where au.tenant_id = t.id and au.period = date_trunc('month', now())::date), 0)
  from public.tenants t
  left join lateral (
    select * from public.users u where u.tenant_id = t.id and u.role = 'owner'
    order by u.created_at limit 1
  ) u on true
  left join auth.users a on a.id = u.id
  where private.is_admin()
  order by t.created_at desc
$$;

-- Allow admin to update location and claim status.
create or replace function public.admin_update_tenant_location(
  p_tenant_id uuid,
  p_zone text,
  p_address text,
  p_lat numeric(10,8),
  p_lng numeric(11,8),
  p_is_claimed boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  update public.tenants
    set zone = p_zone,
        address = p_address,
        lat = p_lat,
        lng = p_lng,
        is_claimed = p_is_claimed
    where id = p_tenant_id;
  if not found then
    raise exception 'TENANT_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.admin_update_tenant_location(uuid, text, text, numeric(10,8), numeric(11,8), boolean) from public, anon;
grant execute on function public.admin_update_tenant_location(uuid, text, text, numeric(10,8), numeric(11,8), boolean) to authenticated;
