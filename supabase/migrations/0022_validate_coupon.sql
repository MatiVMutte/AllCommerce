-- 0022_validate_coupon.sql
-- Lets a customer preview a coupon's discount before placing the order.
-- coupons is owner-only via RLS, so the check needs a SECURITY DEFINER
-- function that returns only the percent (never the row).

create or replace function public.validate_coupon(
  p_tenant_id uuid,
  p_code text
)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_pct int;
begin
  select discount_percent into v_pct
  from public.coupons
  where tenant_id = p_tenant_id
    and code = upper(trim(p_code))
    and is_active;
  return v_pct;
end;
$$;

revoke execute on function public.validate_coupon(uuid, text) from public, anon;
grant execute on function public.validate_coupon(uuid, text) to authenticated;
