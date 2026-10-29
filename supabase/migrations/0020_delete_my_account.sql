-- AllCommerce · 0020 · Eliminación de cuenta propia (requisito Google Play)
-- 1. Permite que orders.customer_id quede en NULL cuando un cliente elimina
--    su cuenta, preservando el historial de pedidos del comercio (que ya
--    guarda customer_name_snapshot y customer_phone_snapshot).
-- 2. Crea public.delete_my_account() para que cualquier usuario autenticado
--    (no admin) pueda borrar su cuenta y, si tenía un local, también su
--    tenant y sus datos asociados.

alter table public.orders
  alter column customer_id drop not null;

alter table public.orders
  drop constraint if exists orders_customer_id_fkey,
  add constraint orders_customer_id_fkey
    foreign key (customer_id) references public.users(id) on delete set null;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_tenant_id uuid;
  v_is_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select u.tenant_id, coalesce(u.is_admin, false)
    into v_tenant_id, v_is_admin
    from public.users u
   where u.id = v_uid;

  if v_is_admin then
    raise exception 'ADMIN_CANNOT_DELETE';
  end if;

  -- Si era dueño de un local, eliminar primero los pedidos del local
  -- (order_items cae en cascada) y luego el tenant (productos, cupones y
  -- uso de IA caen en cascada).
  if v_tenant_id is not null then
    delete from public.orders where tenant_id = v_tenant_id;
    delete from public.tenants where id = v_tenant_id;
  end if;

  -- Eliminar la credencial en auth.users borra en cascada public.users y
  -- user_devices, y deja en NULL orders.customer_id de compras hechas en
  -- otros locales.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
