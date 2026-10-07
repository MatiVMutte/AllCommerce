-- AllCommerce · 0006 · Plan gratis permanente, ubicación/zona de locales, locales pre-registrados no reclamados

-- 1. Plan gratis permanente -------------------------------------------------------------
-- New signups will land here. No expiration, 5 products, 30 AI analyses/month.
alter type public.plan_type add value if not exists 'free';

insert into public.plans (id, name, max_products, price_ars, ai_analyses_per_month, sort_order, highlights)
values ('free', 'Gratis', 5, 0, 30, 0,
        array['Hasta 5 productos', '30 análisis con IA por mes', 'Visible en el directorio y mapa', 'Pedidos por WhatsApp'])
on conflict (id) do update set
  name = excluded.name,
  max_products = excluded.max_products,
  price_ars = excluded.price_ars,
  ai_analyses_per_month = excluded.ai_analyses_per_month,
  sort_order = excluded.sort_order,
  highlights = excluded.highlights;

-- Default plan for new tenants becomes free.
alter table public.tenants alter column plan set default 'free';

-- Free-plan tenants don't need a real expiration; far future keeps the column NOT NULL.
update public.tenants
  set plan_expires_at = now() + interval '100 years'
  where plan = 'free' and plan_expires_at < now();

-- 2. Location / zone -------------------------------------------------------------------
alter table public.tenants
  add column zone text,
  add column address text,
  add column lat numeric(10,8),
  add column lng numeric(11,8);

create index tenants_zone_idx on public.tenants (zone);

-- 3. Pre-registered stores (directory leads) ---------------------------------------------
alter table public.tenants
  add column is_claimed boolean not null default true;

-- 4. Publishing rules: free plan is always publishable if the tenant is active.
create or replace function private.tenant_can_publish(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select is_active and (plan = 'free' or plan_expires_at > now())
     from public.tenants where id = p_tenant_id),
    false
  )
$$;

-- 5. create_tenant now creates a free-plan owner store (trial is opt-in via admin).
create or replace function public.create_tenant(
  p_name text,
  p_slug text,
  p_description text,
  p_address text,
  p_whatsapp text,
  p_primary_color text,
  p_owner_full_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant_id uuid;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  insert into public.tenants (
    name, slug, description, address, whatsapp, primary_color,
    plan, plan_expires_at, is_active, is_claimed
  )
  values (
    p_name, p_slug, p_description, p_address, p_whatsapp, p_primary_color,
    'free', now() + interval '100 years', true, true
  )
  returning id into v_tenant_id;

  update public.users
    set tenant_id = v_tenant_id,
        role = 'owner'
    where id = v_user_id;

  return v_tenant_id;
end;
$$;

-- 6. Public directory helpers -----------------------------------------------------------
-- Distinct active zones (nulls last).
create or replace function public.public_zones()
returns table(zone text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct t.zone
  from public.tenants t
  where t.is_active
    and (t.is_claimed or t.plan <> 'free') -- pre-registered leads show up; unclaimed free-only stores do not
  order by t.zone nulls last
$$;

-- 7. Admin helpers ----------------------------------------------------------------------
-- Admin can now update zone, address, lat, lng, is_claimed.
grant update (zone, address, lat, lng, is_claimed) on public.tenants to authenticated;

create policy "tenants_update_admin_location" on public.tenants
  for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- 8. Adjust metrics: free plan is not paying or trial.
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
                        where plan not in ('trial', 'free') and is_active and plan_expires_at > now()),
    'tenants_trial', (select count(*) from public.tenants
                       where plan = 'trial' and is_active and plan_expires_at > now()),
    'tenants_free', (select count(*) from public.tenants
                      where plan = 'free' and is_active),
    'tenants_expired', (select count(*) from public.tenants
                         where not is_active or (plan not in ('free') and plan_expires_at <= now())),
    'tenants_unclaimed', (select count(*) from public.tenants where not is_claimed),
    'mrr_ars', (select coalesce(sum(p.price_ars), 0) from public.tenants t
                 join public.plans p on p.id = t.plan
                 where t.plan not in ('trial', 'free') and t.is_active and t.plan_expires_at > now()),
    'customers_total', (select count(*) from public.users where role = 'customer'),
    'orders_month', (select count(*) from public.orders
                      where created_at >= date_trunc('month', now())),
    'orders_total', (select count(*) from public.orders),
    'ai_month', (select coalesce(sum(used), 0) from public.ai_usage
                  where period = date_trunc('month', now())::date)
  ) else null end
$$;

revoke all on function public.public_zones() from public, anon;
grant execute on function public.public_zones() to anon, authenticated;
