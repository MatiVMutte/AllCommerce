-- AllCommerce · 0034 · Plan cortesía + archivar pedidos + devolución de stock
--
-- 1. tenants.is_comped: el admin marca locales "de cortesía" (familia, uso
--    propio) — tienen el plan que sea pero NO cuentan como pagos ni en el
--    MRR del dashboard admin.
-- 2. orders.archived_at: el dueño puede archivar pedidos; siguen visibles
--    para el cliente pero salen de la lista principal del dueño.
-- 3. Trigger: al rechazar un pedido se devuelve el stock de los ítems
--    trackeados (place_order lo descuenta al crear el pedido).
-- 4. admin_metrics/admin_tenants_overview actualizados con is_comped.

alter table public.tenants
  add column if not exists is_comped boolean not null default false;

alter table public.orders
  add column if not exists archived_at timestamptz;

create index if not exists orders_tenant_active_idx
  on public.orders (tenant_id, created_at desc)
  where archived_at is null;

-- Archivar/desarchivar pedidos: solo el dueño del tenant del pedido.
create or replace function public.set_order_archived(
  p_order_id uuid,
  p_archived boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
begin
  select tenant_id into v_tenant from public.orders where id = p_order_id;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.users
    where id = auth.uid() and tenant_id = v_tenant and role = 'owner'
  ) then
    raise exception 'NOT_OWNER' using errcode = 'P0001';
  end if;
  update public.orders
    set archived_at = case when p_archived then now() else null end
    where id = p_order_id;
end;
$$;

revoke all on function public.set_order_archived(uuid, boolean) from public, anon;
grant execute on function public.set_order_archived(uuid, boolean) to authenticated;

-- Devolución de stock al rechazar: place_order descuenta al crear el pedido;
-- si el dueño lo rechaza, el stock vuelve (una sola vez: old <> rejected).
create or replace function public.restore_order_stock()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'rejected' and old.status <> 'rejected' then
    update public.products p
      set stock = p.stock + oi.quantity
      from public.order_items oi
      where oi.order_id = new.id
        and oi.product_id = p.id
        and p.track_stock;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_restore_stock on public.orders;
create trigger orders_restore_stock
  after update of status on public.orders
  for each row execute function public.restore_order_stock();

-- Marcar un local como cortesía (no cuenta como pago en las métricas).
create or replace function public.admin_set_comped(
  p_tenant_id uuid,
  p_is_comped boolean
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
  update public.tenants set is_comped = p_is_comped where id = p_tenant_id;
  if not found then
    raise exception 'TENANT_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.admin_set_comped(uuid, boolean) from public, anon;
grant execute on function public.admin_set_comped(uuid, boolean) to authenticated;

-- Métricas: los locales de cortesía no cuentan como pagos ni suman al MRR.
create or replace function public.admin_metrics()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when private.is_admin() then jsonb_build_object(
    'tenants_total', (select count(*) from public.tenants),
    'tenants_paying', (select count(*) from public.tenants
                        where plan not in ('trial', 'free') and is_active and plan_expires_at > now()
                          and not is_comped),
    'tenants_comped', (select count(*) from public.tenants where is_comped),
    'tenants_trial', (select count(*) from public.tenants
                       where plan = 'trial' and is_active and plan_expires_at > now()),
    'tenants_free', (select count(*) from public.tenants
                      where plan = 'free' and is_active),
    'tenants_expired', (select count(*) from public.tenants
                         where not is_active or (plan not in ('free') and plan_expires_at <= now())),
    'tenants_unclaimed', (select count(*) from public.tenants where not is_claimed),
    'mrr_ars', (select coalesce(sum(p.price_ars), 0) from public.tenants t
                 join public.plans p on p.id = t.plan
                 where t.plan not in ('trial', 'free') and t.is_active and t.plan_expires_at > now()
                   and not t.is_comped),
    'customers_total', (select count(*) from public.users where role = 'customer'),
    'orders_month', (select count(*) from public.orders
                      where created_at >= date_trunc('month', now())),
    'orders_total', (select count(*) from public.orders),
    'ai_month', (select coalesce(sum(used), 0) from public.ai_usage
                  where period = date_trunc('month', now())::date)
  ) else null end
$$;

-- Overview con el flag de cortesía (cambia el return type → recrear).
drop function if exists public.admin_tenants_overview();
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
  is_comped boolean,
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
    t.plan, t.plan_expires_at, t.is_active, t.is_claimed, t.is_comped, t.created_at,
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

revoke all on function public.admin_tenants_overview() from public, anon;
grant execute on function public.admin_tenants_overview() to authenticated;
