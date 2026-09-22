-- AllCommerce · 0004 · Storage: buckets públicos de lectura, escritura solo en la carpeta del propio tenant
-- Path: product-images/{tenant_id}/{product_id}.jpg · tenant-logos/{tenant_id}/logo.png

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('product-images', 'product-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  ('tenant-logos', 'tenant-logos', true, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "storage_select_public_buckets" on storage.objects
  for select to anon, authenticated
  using (bucket_id in ('product-images', 'tenant-logos'));

create policy "storage_insert_own_tenant_folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('product-images', 'tenant-logos')
    and (storage.foldername(name))[1] = (select private.current_tenant_id())::text
  );

create policy "storage_update_own_tenant_folder" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('product-images', 'tenant-logos')
    and (storage.foldername(name))[1] = (select private.current_tenant_id())::text
  )
  with check (
    bucket_id in ('product-images', 'tenant-logos')
    and (storage.foldername(name))[1] = (select private.current_tenant_id())::text
  );

create policy "storage_delete_own_tenant_folder" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('product-images', 'tenant-logos')
    and (storage.foldername(name))[1] = (select private.current_tenant_id())::text
  );
