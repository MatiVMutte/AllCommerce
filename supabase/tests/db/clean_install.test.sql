-- Instalación limpia: run.sh ya aplicó 0001..N y el seed sin errores; acá se verifica el estado final.

select tests.ok(
  (select array_agg(e.enumlabel order by e.enumsortorder)::text
     from pg_enum e
     join pg_type t on t.oid = e.enumtypid
     join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'plan_type') = '{trial,inicial,crecimiento,pro,free}',
  'plan_type incluye free, en el mismo orden que una base que aplicó la 0006 original');

select tests.ok(exists (select 1 from public.plans where id = 'free' and max_products = 5),
  'plan free sembrado por 0006');

select tests.ok(
  (select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'tenants' and column_name = 'plan') like '''free''%',
  'tenants.plan tiene default free');

select tests.ok(
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'tenants'
      and column_name in ('zone', 'address', 'lat', 'lng', 'is_claimed',
                          'transfer_alias', 'mercado_pago_link', 'accepts_cash')) = 8,
  'tenants tiene columnas de ubicación (0006) y de pago (0008)');

select tests.ok(to_regclass('public.tenants_zone_idx') is not null, 'índice tenants_zone_idx creado');

select tests.ok(has_function_privilege('anon', 'public.public_zones()', 'execute'),
  'public_zones() existe y anon puede ejecutarla');

select tests.ok(
  pg_get_function_result('public.admin_tenants_overview()'::regprocedure) like '%zone text%is_claimed boolean%',
  'admin_tenants_overview() devuelve las columnas de 0007');

select tests.ok(
  not exists (
    select 1
      from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     where p.oid = 'public.admin_tenants_overview()'::regprocedure
       and a.privilege_type = 'EXECUTE'
       and (a.grantee = 0 or a.grantee = 'anon'::regrole)),
  'admin_tenants_overview(): ni PUBLIC ni anon pueden ejecutarla');

select tests.ok(has_function_privilege('authenticated', 'public.admin_tenants_overview()', 'execute'),
  'admin_tenants_overview(): authenticated puede ejecutarla');

select tests.ok(
  exists (select 1 from public.tenants where slug = 'demo' and plan = 'free')
  and (select count(*) from public.products p join public.tenants t on t.id = p.tenant_id
        where t.slug = 'demo') = 5,
  'seed: local demo con 5 productos');

select tests.ok(private.tenant_can_publish('11111111-1111-4111-8111-111111111111'),
  'local demo (plan free) puede publicar');

rollback;
