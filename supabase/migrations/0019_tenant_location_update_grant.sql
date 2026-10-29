-- AllCommerce · 0019 · el dueño puede guardar la ubicación de su propio local
-- Al guardar el pin desde settings, PostgREST rechazaba el UPDATE: la lista de
-- columnas actualizables del rol authenticated no incluía lat/lng. La RLS a
-- nivel de fila (solo el dueño de su propia fila) sigue aplicando, así que
-- basta con otorgar permiso de columna.
grant update (lat, lng) on public.tenants to authenticated;
