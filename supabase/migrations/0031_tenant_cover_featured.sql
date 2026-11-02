-- AllCommerce · 0031 · Portada del local + productos destacados
-- cover_url: banner ancho que se muestra en el catálogo y en la tarjeta del
-- directorio (fallback: gradiente del color del local). La imagen se sube al
-- bucket tenant-logos como {tenant_id}/cover.jpg — las políticas de 0004 ya
-- limitan la escritura a la carpeta del propio tenant.
-- is_featured: el dueño fija productos en la repisa "Destacados" del catálogo.

alter table public.tenants add column if not exists cover_url text;
alter table public.products add column if not exists is_featured boolean not null default false;
