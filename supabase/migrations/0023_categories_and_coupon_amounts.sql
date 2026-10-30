-- 0023_categories_and_coupon_amounts.sql
-- 1) Product categories become free-form so each store defines its own
--    sections ("Bebidas", "Limpieza"...). The old enum ids keep working —
--    the app still maps them to Spanish labels.
alter table public.products drop constraint if exists products_category_check;
alter table public.products add constraint products_category_check
  check (length(btrim(category)) between 1 and 60);

-- 2) Coupons: percent OR fixed amount.
alter table public.coupons
  add column if not exists discount_type text not null default 'percent';
alter table public.coupons
  add column if not exists discount_amount numeric(12,2);
alter table public.coupons alter column discount_percent drop not null;
alter table public.coupons drop constraint if exists coupons_discount_percent_check;
alter table public.coupons add constraint coupons_discount_check check (
  discount_type in ('percent', 'fixed')
  and (
    (discount_type = 'percent'
      and discount_percent between 1 and 100
      and discount_amount is null)
    or
    (discount_type = 'fixed'
      and discount_amount > 0
      and discount_amount <= 100000000
      and discount_percent is null)
  )
);

-- 3) place_order applies whichever discount kind the coupon has.
create or replace function public.place_order(
  p_tenant_id uuid,
  p_items jsonb,
  p_coupon_code text default null,
  p_notes text default null,
  p_delivery_method public.delivery_method default 'pickup',
  p_delivery_address text default null,
  p_delivery_cost numeric(12,2) default 0,
  p_payment_method public.payment_method default 'cash',
  p_payment_notes text default null
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
  v_tenant public.tenants;
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

  select * into v_tenant from public.tenants where id = p_tenant_id and is_active;
  if not found then
    raise exception 'TENANT_INACTIVE' using errcode = 'P0001';
  end if;

  if p_payment_method = 'transfer' and coalesce(trim(v_tenant.transfer_alias), '') = '' then
    raise exception 'PAYMENT_NOT_CONFIGURED' using errcode = 'P0001';
  end if;
  if p_payment_method = 'mercado_pago' and coalesce(trim(v_tenant.mercado_pago_link), '') = '' then
    raise exception 'PAYMENT_NOT_CONFIGURED' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART' using errcode = 'P0001';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty <= 0 then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
    end if;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id and is_active
    for update;
    if not found then
      raise exception 'PRODUCT_UNAVAILABLE' using errcode = 'P0001';
    end if;

    if v_product.track_stock and v_product.stock < v_qty then
      raise exception 'OUT_OF_STOCK' using errcode = 'P0001';
    end if;

    v_subtotal := v_subtotal + v_product.price * v_qty;
  end loop;

  if p_coupon_code is not null and trim(p_coupon_code) <> '' then
    select * into v_coupon
    from public.coupons
    where tenant_id = p_tenant_id and code = upper(trim(p_coupon_code)) and is_active;
    if not found then
      raise exception 'INVALID_COUPON' using errcode = 'P0001';
    end if;
    if v_coupon.discount_type = 'fixed' then
      v_discount := least(round(v_coupon.discount_amount, 2), v_subtotal);
    else
      v_discount := round(v_subtotal * v_coupon.discount_percent / 100.0, 2);
    end if;
  end if;

  insert into public.orders (
    tenant_id, customer_id, customer_name_snapshot, customer_phone_snapshot,
    subtotal, discount, total, coupon_id, notes,
    delivery_method, delivery_address, delivery_cost, payment_method, payment_notes
  ) values (
    p_tenant_id, v_uid, v_user.full_name, v_user.phone,
    v_subtotal, v_discount, v_subtotal - v_discount + p_delivery_cost, v_coupon.id,
    nullif(trim(p_notes), ''),
    p_delivery_method,
    nullif(trim(p_delivery_address), ''),
    p_delivery_cost,
    p_payment_method,
    nullif(trim(p_payment_notes), '')
  )
  returning * into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::int;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id;

    insert into public.order_items (
      order_id, tenant_id, product_id, title_snapshot, unit_price, quantity
    ) values (
      v_order.id, p_tenant_id, v_product.id, v_product.title, v_product.price,
      v_qty
    );

    if v_product.track_stock then
      update public.products
      set stock = greatest(0, stock - v_qty)
      where id = v_product.id and tenant_id = p_tenant_id;
    end if;
  end loop;

  return v_order;
end;
$$;

grant execute on function public.place_order(uuid, jsonb, text, text, public.delivery_method, text, numeric(12,2), public.payment_method, text) to authenticated;

-- 4) validate_coupon now returns the kind + value so the cart can preview
--    fixed-amount discounts too.
drop function if exists public.validate_coupon(uuid, text);
create function public.validate_coupon(
  p_tenant_id uuid,
  p_code text
)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v json;
begin
  select json_build_object(
    'type', discount_type,
    'value', coalesce(discount_amount, discount_percent)
  ) into v
  from public.coupons
  where tenant_id = p_tenant_id
    and code = upper(trim(p_code))
    and is_active;
  return v;
end;
$$;

revoke execute on function public.validate_coupon(uuid, text) from public, anon;
grant execute on function public.validate_coupon(uuid, text) to authenticated;

-- 5) Public list of active coupons so the catalog can advertise them.
--    Coupons are promotional — the owner wants customers to see the codes.
create or replace function public.list_active_coupons(p_tenant_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(json_agg(s.coupon order by s.created_at), '[]'::json)
  from (
    select
      json_build_object(
        'code', code,
        'type', discount_type,
        'value', coalesce(discount_amount, discount_percent)
      ) as coupon,
      created_at
    from public.coupons
    where tenant_id = p_tenant_id and is_active
  ) s;
$$;

grant execute on function public.list_active_coupons(uuid) to authenticated, anon;
