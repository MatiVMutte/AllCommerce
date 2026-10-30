-- Fix missing table-level grants. RLS policies for owner updates exist on
-- tenants and orders, but the `authenticated` role was never granted the
-- UPDATE/INSERT privileges — every PostgREST write failed with
-- "permission denied for table ..." (42501).
--
-- Symptoms this fixes: payment switches (cash/card), "Guardar cambios",
-- logo upload, is_open toggle, and owner order-status changes.

grant insert, update on public.tenants to authenticated;
grant update on public.orders to authenticated;
