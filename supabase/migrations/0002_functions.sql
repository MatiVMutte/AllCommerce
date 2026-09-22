-- AllCommerce · 0002 · Funciones auxiliares (schema private, no expuesto) y RPCs públicas

-- Helpers para RLS -------------------------------------------------------------
-- Tenant del usuario logueado (solo los dueños tienen tenant_id). NULL para clientes y anónimos.
create or replace function private.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select tenant_id from public.users where id = (select auth.uid())
$$;

create or replace function private.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.users where id = (select auth.uid())
$$;

-- ¿El tenant puede publicar? Plan vigente y tenant activo.
create or replace function private.tenant_can_publish(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select is_active and plan_expires_at > now() from public.tenants where id = p_tenant_id),
    false
  )
$$;

grant usage on schema private to anon, authenticated;
grant execute on function private.current_tenant_id() to anon, authenticated;
grant execute on function private.current_user_role() to anon, authenticated;
grant execute on function private.tenant_can_publish(uuid) to anon, authenticated;

-- Límite de productos por plan (fuente de verdad: la DB, no la app) ---------------
create or replace function private.enforce_product_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max int;
  v_count int;
begin
  if not private.tenant_can_publish(new.tenant_id) then
    raise exception 'PLAN_EXPIRED' using errcode = 'P0001';
  end if;

  select p.max_products into v_max
  from public.tenants t join public.plans p on p.id = t.plan
  where t.id = new.tenant_id;

  select count(*) into v_count from public.products where tenant_id = new.tenant_id;

  if v_count >= v_max then
    raise exception 'PRODUCT_LIMIT_REACHED' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger products_enforce_limit
  before insert on public.products
  for each row execute function private.enforce_product_limit();

-- RPC: crear tenant + perfil de dueño en una transacción -------------------------
create or replace function public.create_tenant(
  p_slug text,
  p_name text,
  p_whatsapp text,
  p_address text,
  p_full_name text
)
returns public.tenants
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_tenant public.tenants;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.users where id = v_uid) then
    raise exception 'PROFILE_EXISTS' using errcode = 'P0001';
  end if;

  begin
    insert into public.tenants (slug, name, whatsapp, address)
    values (lower(trim(p_slug)), trim(p_name), regexp_replace(p_whatsapp, '\D', '', 'g'), nullif(trim(p_address), ''))
    returning * into v_tenant;
  exception when unique_violation then
    raise exception 'SLUG_TAKEN' using errcode = 'P0001';
  end;

  insert into public.users (id, tenant_id, role, full_name)
  values (v_uid, v_tenant.id, 'owner', trim(p_full_name));

  return v_tenant;
end;
$$;

-- RPC: confirmar pedido (precios releídos de la DB, snapshots, cupón) -------------
-- p_items: [{"product_id": "<uuid>", "quantity": 2}, ...]
create or replace function public.place_order(
  p_tenant_id uuid,
  p_items jsonb,
  p_coupon_code text default null,
  p_notes text default null
)
returns public.orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_user public.users;
  v_item jsonb;
  v_product public.products;
  v_qty int;
  v_subtotal numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_coupon public.coupons;
  v_order public.orders;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_user from public.users where id = v_uid;
  if not found then
    raise exception 'PROFILE_REQUIRED' using errcode = 'P0001';
  end if;
  if v_user.phone is null or v_user.phone = '' then
    raise exception 'PHONE_REQUIRED' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.tenants where id = p_tenant_id and is_active) then
    raise exception 'TENANT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART' using errcode = 'P0001';
  end if;

  -- Primera pasada: validar y calcular subtotal con precios actuales de la DB
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty <= 0 then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
    end if;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id and is_active;
    if not found then
      raise exception 'PRODUCT_UNAVAILABLE' using errcode = 'P0001';
    end if;

    v_subtotal := v_subtotal + v_product.price * v_qty;
  end loop;

  -- Cupón (opcional)
  if p_coupon_code is not null and trim(p_coupon_code) <> '' then
    select * into v_coupon
    from public.coupons
    where tenant_id = p_tenant_id and code = upper(trim(p_coupon_code)) and is_active;
    if not found then
      raise exception 'INVALID_COUPON' using errcode = 'P0001';
    end if;
    v_discount := round(v_subtotal * v_coupon.discount_percent / 100.0, 2);
  end if;

  insert into public.orders (
    tenant_id, customer_id, customer_name_snapshot, customer_phone_snapshot,
    subtotal, discount, total, coupon_id, notes
  ) values (
    p_tenant_id, v_uid, v_user.full_name, v_user.phone,
    v_subtotal, v_discount, v_subtotal - v_discount, v_coupon.id, nullif(trim(p_notes), '')
  )
  returning * into v_order;

  -- Segunda pasada: items con snapshot de título y precio
  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid;
    insert into public.order_items (order_id, product_id, tenant_id, title_snapshot, unit_price, quantity)
    values (v_order.id, v_product.id, p_tenant_id, v_product.title, v_product.price, (v_item->>'quantity')::int);
  end loop;

  return v_order;
end;
$$;

-- Solo usuarios logueados pueden invocar las RPCs
revoke execute on function public.create_tenant(text, text, text, text, text) from public, anon;
revoke execute on function public.place_order(uuid, jsonb, text, text) from public, anon;
grant execute on function public.create_tenant(text, text, text, text, text) to authenticated;
grant execute on function public.place_order(uuid, jsonb, text, text) to authenticated;
