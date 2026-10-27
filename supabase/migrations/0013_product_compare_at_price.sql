-- AllCommerce · 0013 · Ofertas y descuentos en productos (compare_at_price)

alter table public.products
  add column if not exists compare_at_price numeric(12,2)
  check (compare_at_price is null or compare_at_price > price);
