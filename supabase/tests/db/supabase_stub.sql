-- Stub mínimo de lo que Supabase provee antes de las migraciones. Idempotente: en un
-- Postgres "pelado" crea todo; en la imagen supabase/postgres solo agrega lo que falta
-- (las tablas de storage las crea storage-api en runtime, no la imagen; ahí hay que
-- correrlo con un rol con permisos sobre el esquema storage, ver STUB_PSQL en run.sh).
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;

create schema if not exists auth;
do $$
begin
  if to_regclass('auth.users') is null then
    create table auth.users (
      id uuid primary key,
      email text,
      last_sign_in_at timestamptz
    );
  end if;
  if to_regprocedure('auth.uid()') is null then
    create function auth.uid() returns uuid
    language sql stable
    as $f$
      select coalesce(
        nullif(current_setting('request.jwt.claim.sub', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
      )::uuid
    $f$;
    grant usage on schema auth to anon, authenticated, service_role;
    grant execute on function auth.uid() to anon, authenticated, service_role;
  end if;
end
$$;

create schema if not exists storage;
grant usage on schema storage to anon, authenticated, service_role;
do $$
begin
  if to_regclass('storage.buckets') is null then
    create table storage.buckets (
      id text primary key,
      name text,
      public boolean,
      file_size_limit bigint,
      allowed_mime_types text[]
    );
    alter table storage.buckets owner to postgres;
  end if;
  if to_regclass('storage.objects') is null then
    create table storage.objects (
      id uuid primary key default gen_random_uuid(),
      bucket_id text,
      name text
    );
    alter table storage.objects enable row level security;
    alter table storage.objects owner to postgres;
  end if;
  if to_regprocedure('storage.foldername(text)') is null then
    create function storage.foldername(name text) returns text[]
    language sql immutable
    as $f$
      select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
    $f$;
    alter function storage.foldername(text) owner to postgres;
  end if;
end
$$;

alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
