#!/usr/bin/env bash
# Instalación limpia + tests SQL de AllCommerce.
# Aplica supabase/migrations/*.sql (cada archivo en su propia transacción, como Supabase CLI)
# y supabase/seed.sql sobre una base NUEVA, y después corre supabase/tests/db/*.test.sql.
#
# SOLO para Postgres locales y descartables. Nunca apuntarlo a un proyecto Supabase real.
#
# Variables:
#   PSQL      comando psql (default: psql). Ej.: PSQL="docker exec -i mi-pg psql -U postgres"
#   TEST_DB   base existente y vacía a usar (ej. 'postgres' de un contenedor supabase/postgres
#             recién creado). Si no se define, se crea allcommerce_test_<ts> y se borra al final.
#   STUB_PSQL comando psql para el stub (default: $PSQL). Con supabase/postgres usar
#             supabase_admin, porque postgres no puede crear tablas en el esquema storage.
#   KEEP_DB=1 no borrar la base creada por el script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TESTS_DIR="$ROOT/supabase/tests/db"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-$ROOT/supabase/migrations}"
read -r -a PSQL_CMD <<< "${PSQL:-psql}"
read -r -a STUB_PSQL_CMD <<< "${STUB_PSQL:-${PSQL:-psql}}"

case "${PGHOST:-localhost}" in
  localhost | 127.0.0.1 | ::1 | /*) ;;
  *) echo "PGHOST=$PGHOST no es local; abortado." >&2; exit 2 ;;
esac

psql_db() {
  local db="$1"
  shift
  "${PSQL_CMD[@]}" -X -q -v ON_ERROR_STOP=1 -d "$db" "$@"
}

created=""
cleanup() {
  if [[ -n "$created" && "${KEEP_DB:-0}" != 1 ]]; then
    psql_db postgres -c "drop database if exists \"$created\""
  fi
}
trap cleanup EXIT

if [[ -z "${TEST_DB:-}" ]]; then
  TEST_DB="allcommerce_test_$(date +%s)_$$"
  psql_db postgres -c "create database \"$TEST_DB\""
  created="$TEST_DB"
fi
echo "== base de prueba: $TEST_DB"

if [[ "$(psql_db "$TEST_DB" -Atc "select to_regclass('public.tenants') is not null")" == t ]]; then
  echo "La base $TEST_DB ya tiene el esquema de AllCommerce; usá una base nueva." >&2
  exit 2
fi

echo "== stub mínimo de Supabase (roles, auth, storage; solo lo que falte)"
"${STUB_PSQL_CMD[@]}" -X -q -v ON_ERROR_STOP=1 -d "$TEST_DB" -1 -f - < "$TESTS_DIR/supabase_stub.sql"

for f in "$MIGRATIONS_DIR"/*.sql; do
  echo "== migración $(basename "$f")"
  psql_db "$TEST_DB" -1 -f - < "$f"
done

echo "== seed.sql"
psql_db "$TEST_DB" -1 -f - < "$ROOT/supabase/seed.sql"

for t in "$TESTS_DIR"/*.test.sql; do
  echo "== test $(basename "$t")"
  cat "$TESTS_DIR/_helpers.sql" "$t" | psql_db "$TEST_DB" -f -
done

echo "OK: migraciones, seed y tests SQL pasaron en $TEST_DB"
