-- AllCommerce · 0009 · place_order con entrega/pago

-- Drop the old signature and recreate with the new optional parameters.
drop function if exists public.place_order(uuid, jsonb, text, text);

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

  -- Cash is always accepted; transfer/MP require the owner to have configured them.
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
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id and is_active;
    if not found then
      raise exception 'PRODUCT_UNAVAILABLE' using errcode = 'P0001';
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
    v_discount := round(v_subtotal * v_coupon.discount_percent / 100.0, 2);
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
    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id;

    insert into public.order_items (
      order_id, tenant_id, product_id, title_snapshot, unit_price, quantity
    ) values (
      v_order.id, p_tenant_id, v_product.id, v_product.title, v_product.price,
      (v_item->>'quantity')::int
    );
  end loop;

  return v_order;
end;
$$;

-- Edge Function will call this with raw RPC, so keep execute for authenticated.
grant execute on function public.place_order(uuid, jsonb, text, text, public.delivery_method, text, numeric(12,2), public.payment_method, text) to authenticated;
