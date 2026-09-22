-- AllCommerce · Seed de desarrollo: un local demo con 5 productos (idempotente)

insert into public.tenants (id, slug, name, description, address, whatsapp, primary_color)
values (
  '11111111-1111-4111-8111-111111111111',
  'demo',
  'Bazar Don Pepe',
  'Bazar y regalería mayorista en Once. Envíos a todo el país.',
  'Av. Pueyrredón 1234, CABA',
  '5491122334455',
  '#0052FF'
)
on conflict (slug) do nothing;

insert into public.products (tenant_id, title, description, category, tags, price, sku, stock)
select '11111111-1111-4111-8111-111111111111', p.title, p.description, p.category, p.tags, p.price, p.sku, p.stock
from (values
  ('Vaso térmico acero 500ml', 'Doble pared, mantiene frío 12 h y calor 6 h. Tapa a rosca.', 'home', array['térmico','acero','bebidas'], 8500.00, 'VT-500', 40),
  ('Set 6 tazas cerámica blanca', 'Tazas de 300 ml aptas para microondas y lavavajillas.', 'home', array['tazas','cerámica','set'], 12900.00, 'TZ-6B', 25),
  ('Repasador algodón', 'Repasador 100% algodón 45x70 cm, alta absorción.', 'home', array['cocina','algodón'], 1200.00, 'RP-ALG', 200),
  ('Auriculares inalámbricos', 'Bluetooth 5.3, estuche de carga, 20 h de autonomía.', 'electronics', array['bluetooth','audio'], 15900.00, 'AU-BT53', 30),
  ('Mochila urbana 20L', 'Mochila impermeable con bolsillo para notebook 15".', 'accessories', array['mochila','urbana'], 22500.00, 'MC-URB20', 15)
) as p(title, description, category, tags, price, sku, stock)
where not exists (
  select 1 from public.products where tenant_id = '11111111-1111-4111-8111-111111111111' and sku = p.sku
);
