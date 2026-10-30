-- 0025_variants_gallery_card.sql
-- 1) Variantes del producto (talles/colores, texto libre por local).
alter table public.products
  add column if not exists variants text[] not null default '{}';

-- 2) Variante elegida en cada ítem del pedido (snapshot de texto).
alter table public.order_items
  add column if not exists variant text;

-- 3) Galería de fotos: image_url queda como foto principal (compat),
--    image_urls lleva todas (la primera es la principal).
alter table public.products
  add column if not exists image_urls text[] not null default '{}';
update public.products
set image_urls = array[image_url]
where image_url is not null and image_url <> '' and image_urls = '{}';

-- 4) El local declara si acepta tarjetas (filtro del directorio).
alter table public.tenants
  add column if not exists accepts_card boolean not null default false;

-- 5) place_order: guarda la variante elegida en cada ítem.
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
  v_unit numeric(12,2);
  v_variant text;
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

    v_unit := v_product.price;
    if v_product.wholesale_price is not null
       and v_product.wholesale_min_qty is not null
       and v_qty >= v_product.wholesale_min_qty then
      v_unit := least(v_product.wholesale_price, v_product.price);
    end if;
    v_subtotal := v_subtotal + v_unit * v_qty;
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
    v_variant := left(btrim(coalesce(v_item->>'variant', '')), 60);
    if v_variant = '' then
      v_variant := null;
    end if;

    select * into v_product
    from public.products
    where id = (v_item->>'product_id')::uuid and tenant_id = p_tenant_id;

    v_unit := v_product.price;
    if v_product.wholesale_price is not null
       and v_product.wholesale_min_qty is not null
       and v_qty >= v_product.wholesale_min_qty then
      v_unit := least(v_product.wholesale_price, v_product.price);
    end if;

    insert into public.order_items (
      order_id, tenant_id, product_id, title_snapshot, unit_price, quantity,
      variant
    ) values (
      v_order.id, p_tenant_id, v_product.id, v_product.title, v_unit,
      v_qty, v_variant
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
