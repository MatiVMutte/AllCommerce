-- AllCommerce · 0001 · Esquema base (UNA sola base de datos, separación por tenant_id)

create schema if not exists private;

-- Tipos -----------------------------------------------------------------------
create type public.user_role as enum ('owner', 'customer');
create type public.order_status as enum ('requested', 'preparing', 'ready', 'delivered', 'rejected');
create type public.plan_type as enum ('trial', 'inicial', 'crecimiento', 'pro');

-- Planes ----------------------------------------------------------------------
create table public.plans (
  id public.plan_type primary key,
  name text not null,
  max_products int not null check (max_products > 0),
  price_ars numeric(12,2) not null default 0 check (price_ars >= 0)
);

insert into public.plans (id, name, max_products, price_ars) values
  ('trial', 'Prueba', 30, 0),
  ('inicial', 'Inicial', 30, 0),
  ('crecimiento', 'Crecimiento', 150, 0),
  ('pro', 'Pro', 1000, 0);

-- Tenants (locales) -----------------------------------------------------------
create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug ~ '^[a-z0-9-]{3,40}$'),
  name text not null check (length(name) between 2 and 80),
  description text,
  address text,
  whatsapp text not null check (whatsapp ~ '^[0-9]{8,15}$'),
  logo_url text,
  primary_color text not null default '#0052FF' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  plan public.plan_type not null default 'trial' references public.plans(id),
  trial_started_at timestamptz not null default now(),
  plan_expires_at timestamptz not null default now() + interval '14 days',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Usuarios (perfil público; la credencial vive en auth.users) -------------------
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid references public.tenants(id) on delete cascade,
  role public.user_role not null,
  full_name text not null check (length(full_name) between 2 and 80),
  phone text check (phone is null or phone ~ '^[0-9]{8,15}$'),
  created_at timestamptz not null default now(),
  constraint users_role_tenant_consistency check (
    (role = 'owner' and tenant_id is not null) or (role = 'customer' and tenant_id is null)
  )
);
create index users_tenant_id_idx on public.users (tenant_id);

-- Productos -------------------------------------------------------------------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  title text not null check (length(title) between 2 and 120),
  description text,
  category text not null check (category in (
    'clothing', 'footwear', 'accessories', 'electronics', 'home',
    'beauty', 'food', 'toys', 'stationery', 'other'
  )),
  tags text[] not null default '{}',
  price numeric(12,2) not null check (price >= 0),
  sku text,
  image_url text,
  stock int not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index products_tenant_active_idx on public.products (tenant_id, is_active);
create index products_search_idx on public.products
  using gin (to_tsvector('spanish', title || ' ' || coalesce(description, '')));

-- Cupones ---------------------------------------------------------------------
create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9]{3,20}$'),
  discount_percent int not null check (discount_percent between 1 and 100),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Pedidos ---------------------------------------------------------------------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number serial,
  tenant_id uuid not null references public.tenants(id),
  customer_id uuid not null references public.users(id),
  customer_name_snapshot text not null,
  customer_phone_snapshot text not null,
  status public.order_status not null default 'requested',
  subtotal numeric(12,2) not null check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null check (total >= 0),
  coupon_id uuid references public.coupons(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index orders_tenant_status_idx on public.orders (tenant_id, status, created_at desc);
create index orders_customer_idx on public.orders (customer_id, created_at desc);
create index orders_coupon_id_idx on public.orders (coupon_id);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  tenant_id uuid not null references public.tenants(id),
  title_snapshot text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity int not null check (quantity > 0)
);
create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_tenant_id_idx on public.order_items (tenant_id);
create index order_items_product_id_idx on public.order_items (product_id);

-- updated_at automático --------------------------------------------------------
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger products_set_updated_at
  before update on public.products
  for each row execute function private.set_updated_at();

create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function private.set_updated_at();
