# AllCommerce

Catálogo y pedidos multi-tenant.

Stack: Flutter + Supabase + Gemini.

Para correr: `cp .env.example .env`, completar los valores, luego `flutter run -d chrome`.

Las migraciones de base de datos viven en `supabase/migrations/`.

Tests de base de datos (solo contra un Postgres local descartable, nunca contra Supabase real):
`supabase/tests/db/run.sh` aplica todas las migraciones y el seed en una base nueva y corre `supabase/tests/db/*.test.sql`. Ver variables al inicio del script.
