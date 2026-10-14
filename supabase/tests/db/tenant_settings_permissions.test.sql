-- Configuración del local: el dueño guarda los datos de pago de SU local, sin tocar otros
-- locales ni campos de plan/administración.

\set owner_a '''aaaaaaaa-0000-4000-8000-00000000000a'''
\set owner_b '''bbbbbbbb-0000-4000-8000-00000000000b'''
\set customer '''cccccccc-0000-4000-8000-00000000000c'''
\set admin '''dddddddd-0000-4000-8000-00000000000d'''

insert into auth.users (id, email) values
  (:owner_a, 'owner-a@test.local'),
  (:owner_b, 'owner-b@test.local'),
  (:customer, 'customer@test.local'),
  (:admin, 'admin@test.local');

-- Dos dueños creados con el mismo RPC que usa la app (AuthRepository.createTenant).
call tests.act_as(:owner_a);
do $$ begin
  perform public.create_tenant('tienda-a', 'Tienda A', '5491100000001', 'Calle 1', 'Owner A');
end $$;
call tests.act_as(:owner_b);
do $$ begin
  perform public.create_tenant('tienda-b', 'Tienda B', '5491100000002', 'Calle 2', 'Owner B');
end $$;
call tests.act_as(:customer);
insert into public.users (id, role, full_name) values (:customer, 'customer', 'Cliente C');
reset role;

insert into public.users (id, role, full_name, is_admin) values (:admin, 'customer', 'Admin', true);
update public.tenants
   set transfer_alias = 'alias.b', mercado_pago_link = 'https://mpago.la/b', accepts_cash = true
 where slug = 'tienda-b';

-- 1. El dueño guarda su configuración (mismo payload que TenantSettingsRepository.update) ------
call tests.act_as(:owner_a);
call tests.expect_rows($sql$
  update public.tenants
     set name = 'Tienda A Nueva', description = 'Bazar', address = 'Calle 10',
         whatsapp = '5491100000099', primary_color = '#112233',
         transfer_alias = 'alias.tienda.a', mercado_pago_link = 'https://mpago.la/abc',
         accepts_cash = false
   where id = (select id from public.tenants where slug = 'tienda-a')
  returning *
$sql$, 1, 'dueño A guarda datos del local y los 3 campos de pago');
call tests.expect_rows($sql$
  update public.tenants set logo_url = 'https://cdn.test/logo.jpg' where slug = 'tienda-a'
$sql$, 1, 'dueño A sigue pudiendo guardar logo_url');
reset role;
select tests.ok(
  (select transfer_alias = 'alias.tienda.a' and mercado_pago_link = 'https://mpago.la/abc'
          and accepts_cash = false and name = 'Tienda A Nueva'
     from public.tenants where slug = 'tienda-a'),
  'los valores de pago quedaron guardados');

-- 2. Aislamiento: no puede modificar otro local ------------------------------------------------
call tests.act_as(:owner_a);
call tests.expect_rows($sql$
  update public.tenants
     set transfer_alias = 'robado', mercado_pago_link = 'https://evil.test', accepts_cash = false
   where slug = 'tienda-b'
$sql$, 0, 'dueño A no modifica los datos de pago de tienda B');
call tests.expect_rows($sql$
  update public.tenants set name = 'Hackeado' where slug = 'tienda-b'
$sql$, 0, 'dueño A no modifica el nombre de tienda B');
call tests.expect_rows($sql$
  update public.tenants set accepts_cash = true
$sql$, 1, 'un UPDATE sin filtro solo alcanza al local propio');
reset role;
select tests.ok(
  (select transfer_alias = 'alias.b' and mercado_pago_link = 'https://mpago.la/b'
          and accepts_cash = true and name = 'Tienda B'
     from public.tenants where slug = 'tienda-b'),
  'tienda B quedó sin cambios');
select tests.ok(
  (select transfer_alias is null and accepts_cash = true from public.tenants where slug = 'demo'),
  'el local demo quedó sin cambios');

-- 3. Campos de plan/administración: sin permiso, ni siquiera en el local propio ----------------
call tests.act_as(:owner_a);
do $$
declare
  v_set text;
begin
  foreach v_set in array array[
    'plan = ''pro''',
    'plan_expires_at = now() + interval ''10 years''',
    'trial_started_at = now()',
    'is_active = false',
    'is_claimed = false',
    'slug = ''otro-slug''',
    'zone = ''Palermo''',
    'lat = 1',
    'lng = 1',
    'created_at = now()'
  ] loop
    call tests.expect_error(
      format('update public.tenants set %s where slug = ''tienda-a''', v_set),
      '42501', format('dueño A no puede cambiar %s', v_set));
  end loop;
end
$$;
call tests.expect_error($sql$
  update public.users set is_admin = true where id = auth.uid()
$sql$, '42501', 'dueño A no puede darse is_admin');
call tests.expect_error($sql$
  select public.admin_update_tenant_location(
    (select id from public.tenants where slug = 'tienda-a'), 'Palermo', null, null, null, false)
$sql$, 'P0001', 'dueño A no puede usar admin_update_tenant_location');
call tests.expect_error($sql$
  select public.admin_set_tenant_plan(
    (select id from public.tenants where slug = 'tienda-a'), 'pro', now() + interval '1 year', true)
$sql$, 'P0001', 'dueño A no puede usar admin_set_tenant_plan');
reset role;
select tests.ok(
  (select plan = 'free' and is_active and is_claimed and zone is null and slug = 'tienda-a'
     from public.tenants where slug = 'tienda-a'),
  'plan, estado, zona y slug de tienda A quedaron sin cambios');

-- 4. El admin sigue gestionando ubicación/reclamo por RPC ---------------------------------------
call tests.act_as(:admin);
call tests.expect_rows($sql$
  select public.admin_update_tenant_location(
    (select id from public.tenants where slug = 'tienda-a'), 'Palermo', 'Calle 10', -34.5, -58.4, false)
$sql$, 1, 'admin actualiza zona y is_claimed vía admin_update_tenant_location');
reset role;
select tests.ok(
  (select zone = 'Palermo' and is_claimed = false from public.tenants where slug = 'tienda-a'),
  'cambios del admin guardados');

-- 5. Cliente y anónimo -------------------------------------------------------------------------
call tests.act_as(:customer);
call tests.expect_rows($sql$
  update public.tenants set transfer_alias = 'x', mercado_pago_link = 'x', accepts_cash = true
   where slug = 'tienda-a'
$sql$, 0, 'un cliente no modifica datos de pago de ningún local');
call tests.act_as_anon();
call tests.expect_error($sql$
  update public.tenants set transfer_alias = 'x' where slug = 'tienda-a'
$sql$, '42501', 'anon no tiene permiso de UPDATE sobre tenants');
reset role;
select tests.ok(
  (select transfer_alias = 'alias.tienda.a' and accepts_cash = true from public.tenants where slug = 'tienda-a'),
  'datos de pago de tienda A intactos tras intentos de cliente y anon');

rollback;
