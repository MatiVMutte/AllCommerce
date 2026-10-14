-- AllCommerce · 0013 · Permisos de columna para la configuración del local
-- 0008 agregó los datos de pago sin permiso de UPDATE, por lo que el dueño no podía
-- guardar la configuración (TenantSettingsRepository.update).
-- La RLS (tenants_update_owner) sigue limitando el UPDATE al tenant del propio dueño.
grant update (transfer_alias, mercado_pago_link, accepts_cash) on public.tenants to authenticated;

-- 0006 concedió zone/lat/lng/is_claimed a todo usuario autenticado, lo que permitía al dueño
-- cambiarlos en su local. Son datos que gestiona el admin vía admin_update_tenant_location
-- (security definer), así que no necesitan permiso directo. address se mantiene (0003).
revoke update (zone, lat, lng, is_claimed) on public.tenants from authenticated;
