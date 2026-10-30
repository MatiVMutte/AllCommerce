-- Venta por unidad fraccionada (kg, g, lt, ml, m, docena).
-- 'unidad' mantiene el comportamiento actual: cantidades enteras.

alter table public.products
  add column if not exists unit text not null default 'unidad'
    constraint products_unit_values check (
      unit in ('unidad','kg','g','lt','ml','m','docena')
    );

alter table public.products
  alter column stock type numeric(12,3),
  alter column wholesale_min_qty type numeric(10,3);

alter table public.order_items
  alter column quantity type numeric(10,3);

-- Snapshot de la unidad al momento del pedido: el producto puede
-- cambiar de unidad o borrarse después y el pedido debe seguir leyéndose.
alter table public.order_items
  add column if not exists unit text not null default 'unidad';

create or replace function public.place_order(
  p_tenant_id uuid,
  p_items jsonb,
  p_coupon_code text default null,
  p_notes text default null,
  p_delivery_method delivery_method default 'pickup',
  p_delivery_address text default null,
  p_delivery_cost numeric default 0,
  p_payment_method payment_method default 'cash',
  p_payment_notes text default null
)
returns orders
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
    v_qty := round(coalesce((v_item->>'quantity')::numeric, 0), 3);
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

    -- Solo los productos fraccionados (kg, lt, ...) aceptan decimales.
    if v_product.unit = 'unidad' and v_qty <> floor(v_qty) then
      raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
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
    v_qty := round((v_item->>'quantity')::numeric, 3);
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
      variant, unit
    ) values (
      v_order.id, p_tenant_id, v_product.id, v_product.title, v_unit,
      v_qty, v_variant, v_product.unit
    );

    if v_product.track_stock then
      update public.products
      set stock = greatest(0, stock - v_qty)
      where id = v_product.id and tenant_id = p_tenant_id;
    end if;
  end loop;

  return v_order;
end;
$function$;

-- stock y wholesale_min_qty ahora son numeric; además devolvemos la unidad.
drop function if exists public.search_public_products(text, integer);

create function public.search_public_products(
  p_query text,
  p_limit integer default 16
)
returns table(
  product_id uuid, tenant_id uuid, title text, description text,
  category text, price numeric, compare_at_price numeric,
  wholesale_price numeric, wholesale_min_qty numeric, image_url text,
  stock numeric, track_stock boolean, unit text,
  tenant_slug text, tenant_name text, tenant_logo_url text,
  tenant_primary_color text, tenant_is_open boolean
)
language sql
stable
set search_path to ''
as $function$
  select
    p.id as product_id,
    p.tenant_id,
    p.title,
    p.description,
    p.category,
    p.price,
    p.compare_at_price,
    p.wholesale_price,
    p.wholesale_min_qty,
    p.image_url,
    p.stock,
    p.track_stock,
    p.unit,
    t.slug as tenant_slug,
    t.name as tenant_name,
    t.logo_url as tenant_logo_url,
    t.primary_color as tenant_primary_color,
    t.is_open as tenant_is_open
  from public.products p
  join public.tenants t on t.id = p.tenant_id
  where p.is_active = true
    and t.is_active = true
    and t.is_claimed = true
    and t.plan_expires_at > now()
    and length(trim(coalesce(p_query, ''))) >= 2
    and (
      p.title ilike '%' || trim(p_query) || '%'
      or coalesce(p.description, '') ilike '%' || trim(p_query) || '%'
      or exists (
        select 1
        from unnest(p.tags) as tag
        where tag ilike '%' || trim(p_query) || '%'
      )
    )
  order by
    case when lower(p.title) like lower(trim(p_query)) || '%' then 0 else 1 end,
    p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 16), 40));
$function$;

grant execute on function public.search_public_products(text, integer)
  to anon, authenticated;

-- top_products: qty pasa a numeric y sumamos la unidad del producto.
create or replace function public.owner_sales_metrics(p_tenant_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  v_month_start timestamptz := date_trunc('month', now());
  v_prev_start timestamptz := v_month_start - interval '1 month';
begin
  if private.current_tenant_id() is distinct from p_tenant_id then
    raise exception 'FORBIDDEN';
  end if;

  return (
    select jsonb_build_object(
      'month_total', coalesce(sum(o.total) filter (where o.created_at >= v_month_start), 0),
      'month_count', count(*) filter (where o.created_at >= v_month_start),
      'prev_total', coalesce(sum(o.total) filter (where o.created_at < v_month_start), 0),
      'prev_count', count(*) filter (where o.created_at < v_month_start)
    )
    from public.orders o
    where o.tenant_id = p_tenant_id
      and o.status <> 'rejected'
      and o.created_at >= v_prev_start
      and not exists (
        select 1 from public.users u
        where u.id = o.customer_id and u.tenant_id = o.tenant_id
      )
  ) || (
    select jsonb_build_object(
      'top_products', coalesce(jsonb_agg(
        jsonb_build_object(
          'title', t.title,
          'qty', t.qty,
          'unit', t.unit,
          'revenue', t.revenue
        ) order by t.qty desc, t.revenue desc
      ), '[]'::jsonb)
    )
    from (
      select
        oi.title_snapshot as title,
        sum(oi.quantity)::numeric as qty,
        max(oi.unit) as unit,
        sum(oi.unit_price * oi.quantity) as revenue
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where o.tenant_id = p_tenant_id
        and o.status <> 'rejected'
        and o.created_at >= v_month_start
        and not exists (
          select 1 from public.users u
          where u.id = o.customer_id and u.tenant_id = o.tenant_id
        )
      group by oi.title_snapshot
      order by qty desc, revenue desc
      limit 3
    ) t
  );
end;
$function$;
