-- Helpers de los tests SQL. run.sh lo antepone a cada *.test.sql; todo corre en una
-- transacción que el test termina con rollback, así no queda nada en la base.
\set ON_ERROR_STOP 1
\pset tuples_only on
\pset format unaligned
begin;

create schema tests;
grant usage on schema tests to anon, authenticated;

-- Función (no procedimiento) para poder pasarle subconsultas: select tests.ok(...).
create function tests.ok(p_cond boolean, p_label text) returns text
language plpgsql as $$
begin
  if p_cond is distinct from true then
    raise exception 'FAIL - %', p_label;
  end if;
  return 'ok - ' || p_label;
end
$$;

-- Actúa como un usuario autenticado de Supabase (rol + claims del JWT).
create procedure tests.act_as(p_sub uuid)
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_sub::text, true);
  perform set_config('role', 'authenticated', true);
end
$$;

create procedure tests.act_as_anon()
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('role', 'anon', true);
end
$$;

create procedure tests.expect_rows(p_sql text, p_expected bigint, p_label text)
language plpgsql as $$
declare
  v_count bigint;
begin
  execute p_sql;
  get diagnostics v_count = row_count;
  if v_count <> p_expected then
    raise exception 'FAIL - % (filas: %, esperadas: %)', p_label, v_count, p_expected;
  end if;
  raise notice 'ok - %', p_label;
end
$$;

create procedure tests.expect_error(p_sql text, p_sqlstate text, p_label text)
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlstate = p_sqlstate then
      raise notice 'ok - % (%: %)', p_label, sqlstate, sqlerrm;
      return;
    end if;
    raise exception 'FAIL - % (error inesperado %: %)', p_label, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL - % (no falló; se esperaba %)', p_label, p_sqlstate;
end
$$;

grant execute on all functions in schema tests to anon, authenticated;
grant execute on all procedures in schema tests to anon, authenticated;
