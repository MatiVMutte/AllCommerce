-- AllCommerce · 0015 · Horarios de atención y estado Abierto/Cerrado del local
-- También otorga permisos UPDATE al dueño sobre transfer_alias, mercado_pago_link y accepts_cash.

alter table public.tenants
  add column if not exists is_open boolean not null default true,
  add column if not exists opening_hours text;

grant update (
  name,
  description,
  address,
  whatsapp,
  logo_url,
  primary_color,
  transfer_alias,
  mercado_pago_link,
  accepts_cash,
  is_open,
  opening_hours
) on public.tenants to authenticated;
