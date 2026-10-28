-- AllCommerce · 0017 · Modo dual Dueño <-> Cliente y upgrade de Cliente a Dueño
-- 1) create_tenant ahora permite que un usuario existente con rol 'customer'
--    (tenant_id is null) abra su propio local y pase a 'owner' conservando
--    todo su historial de pedidos como cliente.
-- 2) Además completa users.phone con el WhatsApp del local si estaba vacío,
--    para que un dueño también pueda hacer pedidos como cliente sin fricción.

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
  v_existing public.users;
  v_tenant public.tenants;
  v_clean_phone text := regexp_replace(p_whatsapp, '\D', '', 'g');
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;

  select * into v_existing from public.users where id = v_uid;
  if found and v_existing.tenant_id is not null then
    raise exception 'PROFILE_EXISTS' using errcode = 'P0001';
  end if;

  begin
    insert into public.tenants (
      slug, name, whatsapp, address, plan, plan_expires_at, is_active, is_claimed
    )
    values (
      lower(trim(p_slug)),
      trim(p_name),
      v_clean_phone,
      nullif(trim(p_address), ''),
      'free',
      now() + interval '100 years',
      true,
      true
    )
    returning * into v_tenant;
  exception when unique_violation then
    raise exception 'SLUG_TAKEN' using errcode = 'P0001';
  end;

  insert into public.users (id, tenant_id, role, full_name, phone)
  values (v_uid, v_tenant.id, 'owner', trim(p_full_name), nullif(v_clean_phone, ''))
  on conflict (id) do update
    set tenant_id = excluded.tenant_id,
        role = 'owner',
        full_name = coalesce(nullif(excluded.full_name, ''), public.users.full_name),
        phone = coalesce(nullif(public.users.phone, ''), excluded.phone);

  return v_tenant;
end;
$$;

-- Backfill: dueños actuales sin teléfono en users heredan el WhatsApp de su local
-- para poder comprar como clientes sin que place_order pida teléfono de nuevo.
update public.users u
set phone = t.whatsapp
from public.tenants t
where u.tenant_id = t.id
  and (u.phone is null or u.phone = '')
  and t.whatsapp is not null
  and t.whatsapp <> '';
