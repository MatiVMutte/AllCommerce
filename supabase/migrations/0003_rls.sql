-- AllCommerce · 0003 · Row Level Security + privilegios mínimos
-- Regla general: el dueño ve/edita solo su tenant; el cliente ve solo lo suyo; el público ve catálogos activos.

alter table public.plans enable row level security;
alter table public.tenants enable row level security;
alter table public.users enable row level security;
alter table public.products enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Privilegios de tabla (la RLS filtra filas; esto limita operaciones y columnas) ----
revoke all on public.plans from anon, authenticated;
grant select on public.plans to anon, authenticated;

revoke all on public.tenants from anon, authenticated;
grant select on public.tenants to anon, authenticated;
-- El dueño edita datos del negocio, NUNCA plan/vencimiento/estado (eso lo hace el admin de AllCommerce)
grant update (name, description, address, whatsapp, logo_url, primary_color) on public.tenants to authenticated;
-- insert solo vía create_tenant()

revoke all on public.users from anon, authenticated;
grant select, insert on public.users to authenticated;
grant update (full_name, phone) on public.users to authenticated;

revoke all on public.products from anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;

revoke all on public.coupons from anon, authenticated;
grant select, insert, update, delete on public.coupons to authenticated;

revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;
grant update (status) on public.orders to authenticated;
-- insert solo vía place_order()

revoke all on public.order_items from anon, authenticated;
grant select on public.order_items to authenticated;

-- plans -------------------------------------------------------------------------
create policy "plans_select_all" on public.plans
  for select to anon, authenticated using (true);

-- tenants -----------------------------------------------------------------------
create policy "tenants_select_public_or_own" on public.tenants
  for select to anon, authenticated
  using (is_active = true or id = (select private.current_tenant_id()));

create policy "tenants_update_owner" on public.tenants
  for update to authenticated
  using (id = (select private.current_tenant_id()))
  with check (id = (select private.current_tenant_id()));

-- users -------------------------------------------------------------------------
-- Mi perfil, o (si soy dueño) los clientes que me hicieron al menos un pedido.
create policy "users_select_self_or_my_customers" on public.users
  for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.orders o
      where o.customer_id = users.id
        and o.tenant_id = (select private.current_tenant_id())
    )
  );

-- Solo se auto-crea el perfil de cliente; el de dueño lo crea create_tenant()
create policy "users_insert_self_customer" on public.users
  for insert to authenticated
  with check (id = (select auth.uid()) and role = 'customer' and tenant_id is null);

create policy "users_update_self" on public.users
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- products ----------------------------------------------------------------------
-- Público: productos activos de locales activos. Dueño: todos los de su tenant.
create policy "products_select_public_or_owner" on public.products
  for select to anon, authenticated
  using (
    tenant_id = (select private.current_tenant_id())
    or (
      is_active = true
      and exists (select 1 from public.tenants t where t.id = products.tenant_id and t.is_active)
    )
  );

create policy "products_insert_owner" on public.products
  for insert to authenticated
  with check (tenant_id = (select private.current_tenant_id()));

create policy "products_update_owner" on public.products
  for update to authenticated
  using (tenant_id = (select private.current_tenant_id()))
  with check (tenant_id = (select private.current_tenant_id()));

create policy "products_delete_owner" on public.products
  for delete to authenticated
  using (tenant_id = (select private.current_tenant_id()));

-- coupons (solo el dueño; el cliente los valida dentro de place_order) -----------
create policy "coupons_all_owner" on public.coupons
  for all to authenticated
  using (tenant_id = (select private.current_tenant_id()))
  with check (tenant_id = (select private.current_tenant_id()));

-- orders ------------------------------------------------------------------------
create policy "orders_select_customer_or_owner" on public.orders
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or tenant_id = (select private.current_tenant_id())
  );

create policy "orders_update_owner" on public.orders
  for update to authenticated
  using (tenant_id = (select private.current_tenant_id()))
  with check (tenant_id = (select private.current_tenant_id()));

-- order_items -------------------------------------------------------------------
create policy "order_items_select_customer_or_owner" on public.order_items
  for select to authenticated
  using (
    tenant_id = (select private.current_tenant_id())
    or exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.customer_id = (select auth.uid())
    )
  );
