-- AllCommerce · 0033 · Desglose de descuentos por pedido
-- Hasta ahora orders.discount guardaba solo el total; el detalle, el PDF y
-- "Mis pedidos" no podían mostrar de dónde salía. Se persisten los
-- componentes: cupón (con su código), descuento por forma de pago y
-- descuento por volumen (con el % aplicado en ese momento).
--
-- Los componentes se calculan secuencialmente: cada uno se topea contra lo
-- que queda del subtotal, así coupon_discount + bulk_discount +
-- payment_discount siempre suman exactamente orders.discount.

alter table public.orders
  add column if not exists coupon_code text,
  add column if not exists coupon_discount numeric(12,2) not null default 0,
  add column if not exists bulk_discount numeric(12,2) not null default 0,
  add column if not exists bulk_discount_pct numeric(5,2) not null default 0,
  add column if not exists payment_discount numeric(12,2) not null default 0,
  add column if not exists payment_discount_pct numeric(5,2) not null default 0;

create or replace function public.place_order(
  p_tenant_id uuid,
  p_items jsonb,
  p_coupon_code text default null,
  p_notes text default null,
  p_delivery_method public.delivery_method default 'pickup',
  p_delivery_address text default null,
  p_delivery_cost numeric default 0,
  p_payment_method public.payment_method default 'cash',
  p_payment_notes text default null
)
returns public.orders
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_user public.users;
  v_item jsonb;
  v_product public.products;
  v_qty numeric(10,3);
  v_unit numeric(12,2);
  v_variant text;
  v_subtotal numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_coupon_disc numeric(12,2) := 0;
  v_bulk_disc numeric(12,2) := 0;
  v_pay_disc numeric(12,2) := 0;
  v_pay_pct numeric(6,2) := 0;
  v_delivery numeric(12,2) := 0;
  v_coupon public.coupons;
  v_order public.orders;
  v_tenant public.tenants;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
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

  if p_delivery_method = 'delivery' and coalesce(trim(p_delivery_address), '') = '' then
    raise exception 'ADDRESS_REQUIRED' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'EMPTY_CART' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'CART_TOO_LARGE' using errcode = 'P0001';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := round(coalesce((v_item->>'quantity')::numeric, 0), 3);
    if v_qty <= 0 or v_qty > 100000 then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
    end if;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id and is_active
    for update;
    if not found then
      raise exception 'PRODUCT_UNAVAILABLE' using errcode = 'P0001';
    end if;

    if v_product.unit = 'unidad' and v_qty <> floor(v_qty) then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
    end if;

    if v_product.track_stock then
      if v_product.stock < v_qty then
        raise exception 'OUT_OF_STOCK' using errcode = 'P0001';
      end if;
      update public.products
      set stock = stock - v_qty
      where id = v_product.id and tenant_id = p_tenant_id;
    end if;

    v_unit := v_product.price;
    if v_product.wholesale_price is not null
       and v_product.wholesale_min_qty is not null
       and v_qty >= v_product.wholesale_min_qty then
      v_unit := least(v_product.wholesale_price, v_product.price);
    end if;
    v_subtotal := v_subtotal + v_unit * v_qty;

    v_variant := left(btrim(coalesce(v_item->>'variant', '')), 60);
    v_lines := v_lines || jsonb_build_object(
      'product_id', v_product.id,
      'title', v_product.title,
      'unit_price', v_unit,
      'quantity', v_qty,
      'variant', nullif(v_variant, ''),
      'unit', v_product.unit
    );
  end loop;

  -- Cupón
  if p_coupon_code is not null and trim(p_coupon_code) <> '' then
    select * into v_coupon
    from public.coupons
    where tenant_id = p_tenant_id and code = upper(trim(p_coupon_code)) and is_active;
    if not found then
      raise exception 'INVALID_COUPON' using errcode = 'P0001';
    end if;
    if v_coupon.discount_type = 'fixed' then
      v_coupon_disc := least(round(v_coupon.discount_amount, 2), v_subtotal);
    else
      v_coupon_disc := least(
        round(v_subtotal * least(v_coupon.discount_percent, 100) / 100.0, 2),
        v_subtotal
      );
    end if;
  end if;

  -- Descuento por volumen (topeado contra lo que queda del subtotal)
  if v_tenant.bulk_discount_pct > 0 and v_subtotal >= v_tenant.bulk_discount_min then
    v_bulk_disc := least(
      round(v_subtotal * least(v_tenant.bulk_discount_pct, 100) / 100.0, 2),
      v_subtotal - v_coupon_disc);
  end if;

  -- Descuento por forma de pago (mismo criterio)
  v_pay_pct := case p_payment_method
    when 'cash' then v_tenant.cash_discount_pct
    when 'transfer' then v_tenant.transfer_discount_pct
    else v_tenant.mp_discount_pct
  end;
  if coalesce(v_pay_pct, 0) > 0 then
    v_pay_disc := least(
      round(v_subtotal * least(v_pay_pct, 100) / 100.0, 2),
      v_subtotal - v_coupon_disc - v_bulk_disc);
  else
    v_pay_pct := 0;
  end if;

  v_discount := v_coupon_disc + v_bulk_disc + v_pay_disc;

  insert into public.orders (
    tenant_id, customer_id, customer_name_snapshot, customer_phone_snapshot,
    subtotal, discount, total, coupon_id,
    coupon_code, coupon_discount, bulk_discount, bulk_discount_pct,
    payment_discount, payment_discount_pct,
    notes, delivery_method, delivery_address, delivery_cost,
    payment_method, payment_notes
  ) values (
    p_tenant_id, v_uid, v_user.full_name, v_user.phone,
    v_subtotal, v_discount, v_subtotal - v_discount + v_delivery, v_coupon.id,
    nullif(v_coupon.code, ''), v_coupon_disc, v_bulk_disc,
    case when v_bulk_disc > 0 then least(v_tenant.bulk_discount_pct, 100) else 0 end,
    v_pay_disc, least(coalesce(v_pay_pct, 0), 100),
    left(nullif(trim(p_notes), ''), 500),
    p_delivery_method,
    left(nullif(trim(p_delivery_address), ''), 300),
    v_delivery,
    p_payment_method,
    left(nullif(trim(p_payment_notes), ''), 300)
  )
  returning * into v_order;

  for v_line in select * from jsonb_array_elements(v_lines) loop
    insert into public.order_items (
      order_id, tenant_id, product_id, title_snapshot, unit_price, quantity,
      variant, unit
    ) values (
      v_order.id, p_tenant_id, (v_line->>'product_id')::uuid,
      v_line->>'title', (v_line->>'unit_price')::numeric,
      (v_line->>'quantity')::numeric, v_line->>'variant', v_line->>'unit'
    );
  end loop;

  return v_order;
end;
$function$;
