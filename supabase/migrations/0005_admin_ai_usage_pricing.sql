-- AllCommerce · 0005 · Admin de la plataforma, límite de análisis de IA por plan y precios de planes

-- 1. Planes: precio, límite de IA y destacados --------------------------------------
alter table public.plans
  add column ai_analyses_per_month int
    check (ai_analyses_per_month is null or ai_analyses_per_month > 0), -- null = ilimitado
  add column sort_order int not null default 0,
  add column highlights text[] not null default '{}';

update public.plans set price_ars = 0,     ai_analyses_per_month = 30,   sort_order = 0,
  highlights = array['Hasta 30 productos', '30 análisis con IA por mes', '14 días gratis']
  where id = 'trial';
update public.plans set price_ars = 9900,  ai_analyses_per_month = 60,   sort_order = 1,
  highlights = array['Hasta 30 productos', '60 análisis con IA por mes', 'Pedidos por WhatsApp', 'Logo y color propios']
  where id = 'inicial';
update public.plans set price_ars = 19900, ai_analyses_per_month = 300,  sort_order = 2,
  highlights = array['Hasta 150 productos', '300 análisis con IA por mes', 'Pedidos por WhatsApp', 'Logo y color propios', 'Cupones de descuento']
  where id = 'crecimiento';
update public.plans set price_ars = 39900, ai_analyses_per_month = null, sort_order = 3,
  highlights = array['Hasta 1000 productos', 'Análisis con IA ilimitados', 'Pedidos por WhatsApp', 'Logo y color propios', 'Cupones de descuento', 'Soporte prioritario']
  where id = 'pro';

-- 2. Admin de la plataforma ------------------------------------------------------------
alter table public.users add column is_admin boolean not null default false;

-- El insert de perfil (cliente) no puede tocar is_admin: privilegio por columna.
revoke insert on public.users from authenticated;
grant insert (id, tenant_id, role, full_name, phone) on public.users to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select is_admin from public.users where id = (select auth.uid())), false)
$$;
grant execute on function private.is_admin() to authenticated;

-- El admin ve todo (solo lectura directa; los cambios van por RPC).
create policy "tenants_select_admin" on public.tenants
  for select to authenticated using ((select private.is_admin()));
create policy "users_select_admin" on public.users
  for select to authenticated using ((select private.is_admin()));
create policy "products_select_admin" on public.products
  for select to authenticated using ((select private.is_admin()));
create policy "orders_select_admin" on public.orders
  for select to authenticated using ((select private.is_admin()));
create policy "order_items_select_admin" on public.order_items
  for select to authenticated using ((select private.is_admin()));

-- Precios y destacados de planes: solo el admin, solo esas columnas.
grant update (price_ars, highlights, ai_analyses_per_month) on public.plans to authenticated;
create policy "plans_update_admin" on public.plans
  for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- 3. Uso de IA por local y mes ---------------------------------------------------------
create table public.ai_usage (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  period date not null, -- primer día del mes
  used int not null default 0 check (used >= 0),
  updated_at timestamptz not null default now(),
  primary key (tenant_id, period)
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;
grant select on public.ai_usage to authenticated;
create policy "ai_usage_select_owner_or_admin" on public.ai_usage
  for select to authenticated
  using (tenant_id = (select private.current_tenant_id()) or (select private.is_admin()));

-- Reserva un análisis para el local del dueño logueado. Lanza AI_LIMIT_REACHED si se agotó.
create or replace function public.consume_ai_analysis()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid := private.current_tenant_id();
  v_period date := date_trunc('month', now())::date;
  v_limit int;
  v_used int;
begin
  if v_tenant is null then
    raise exception 'OWNER_REQUIRED';
  end if;
  if not private.tenant_can_publish(v_tenant) then
    raise exception 'PLAN_EXPIRED';
  end if;
  select p.ai_analyses_per_month into v_limit
    from public.tenants t join public.plans p on p.id = t.plan
    where t.id = v_tenant;

  insert into public.ai_usage (tenant_id, period) values (v_tenant, v_period)
    on conflict do nothing;
  select used into v_used from public.ai_usage
    where tenant_id = v_tenant and period = v_period for update;

  if v_limit is not null and v_used >= v_limit then
    raise exception 'AI_LIMIT_REACHED';
  end if;
  update public.ai_usage set used = used + 1, updated_at = now()
    where tenant_id = v_tenant and period = v_period;
  return jsonb_build_object('used', v_used + 1, 'limit', v_limit);
end;
$$;

-- Devuelve un análisis reservado cuando la IA falló (no se cobra lo que no se usó).
create or replace function public.refund_ai_analysis()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.ai_usage set used = greatest(used - 1, 0), updated_at = now()
    where tenant_id = private.current_tenant_id()
      and period = date_trunc('month', now())::date
$$;

-- Uso actual del dueño logueado para mostrar en la app: {used, limit}.
create or replace function public.ai_usage_current()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'used', coalesce((
      select used from public.ai_usage
      where tenant_id = private.current_tenant_id()
        and period = date_trunc('month', now())::date), 0),
    'limit', (
      select p.ai_analyses_per_month
      from public.tenants t join public.plans p on p.id = t.plan
      where t.id = private.current_tenant_id())
  )
$$;

revoke all on function public.consume_ai_analysis() from public, anon;
revoke all on function public.refund_ai_analysis() from public, anon;
revoke all on function public.ai_usage_current() from public, anon;
grant execute on function public.consume_ai_analysis() to authenticated;
grant execute on function public.refund_ai_analysis() to authenticated;
grant execute on function public.ai_usage_current() to authenticated;

-- 4. RPCs de administración --------------------------------------------------------------
create or replace function public.admin_set_tenant_plan(
  p_tenant_id uuid,
  p_plan public.plan_type,
  p_expires_at timestamptz,
  p_is_active boolean
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
    set plan = p_plan, plan_expires_at = p_expires_at, is_active = p_is_active
    where id = p_tenant_id;
  if not found then
    raise exception 'TENANT_NOT_FOUND';
  end if;
end;
$$;

create or replace function public.admin_tenants_overview()
returns table (
  id uuid,
  name text,
  slug text,
  plan public.plan_type,
  plan_expires_at timestamptz,
  is_active boolean,
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
    t.id, t.name, t.slug, t.plan, t.plan_expires_at, t.is_active, t.created_at,
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
                        where plan <> 'trial' and is_active and plan_expires_at > now()),
    'tenants_trial', (select count(*) from public.tenants
                       where plan = 'trial' and is_active and plan_expires_at > now()),
    'tenants_expired', (select count(*) from public.tenants
                         where not is_active or plan_expires_at <= now()),
    'mrr_ars', (select coalesce(sum(p.price_ars), 0) from public.tenants t
                 join public.plans p on p.id = t.plan
                 where t.plan <> 'trial' and t.is_active and t.plan_expires_at > now()),
    'customers_total', (select count(*) from public.users where role = 'customer'),
    'orders_month', (select count(*) from public.orders
                      where created_at >= date_trunc('month', now())),
    'orders_total', (select count(*) from public.orders),
    'ai_month', (select coalesce(sum(used), 0) from public.ai_usage
                  where period = date_trunc('month', now())::date)
  ) else null end
$$;

revoke all on function public.admin_set_tenant_plan(uuid, public.plan_type, timestamptz, boolean) from public, anon;
revoke all on function public.admin_tenants_overview() from public, anon;
revoke all on function public.admin_metrics() from public, anon;
grant execute on function public.admin_set_tenant_plan(uuid, public.plan_type, timestamptz, boolean) to authenticated;
grant execute on function public.admin_tenants_overview() to authenticated;
grant execute on function public.admin_metrics() to authenticated;

-- Valor 'free' del plan gratis (lo usa 0006). Se agrega acá, en una transacción anterior,
-- porque Postgres no permite usar un valor de enum en la misma transacción que lo crea.
-- Idempotente: en bases que ya tienen 'free' no hace nada.
alter type public.plan_type add value if not exists 'free';
