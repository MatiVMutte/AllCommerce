-- AllCommerce · 0008 · Forma de entrega, forma de pago y datos de pago del local

-- How the customer receives the order.
create type public.delivery_method as enum ('pickup', 'delivery');

-- How the customer pays.
create type public.payment_method as enum ('cash', 'transfer', 'mercado_pago');

alter table public.orders
  add column delivery_method public.delivery_method not null default 'pickup',
  add column delivery_address text,
  add column delivery_cost numeric(12,2) not null default 0 check (delivery_cost >= 0),
  add column payment_method public.payment_method not null default 'cash',
  add column payment_notes text;

-- Payment details configured by the owner in store settings.
alter table public.tenants
  add column transfer_alias text,
  add column mercado_pago_link text,
  add column accepts_cash boolean not null default true;

-- Default values for existing tenants.
update public.tenants
  set accepts_cash = true
  where accepts_cash is null;
