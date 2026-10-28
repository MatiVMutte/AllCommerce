-- AllCommerce · 0018 · Excluir pedidos propios de las métricas del dueño
-- Un dueño puede comprar en su propio local (modo cliente, para probar el
-- flujo). Esos pedidos son válidos pero no deben contar en "Ventas del mes"
-- ni en el top de productos: se detectan porque el customer_id pertenece a
-- un usuario del mismo tenant.

create or replace function public.owner_sales_metrics(p_tenant_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_month_start timestamptz := date_trunc('month', now());
  v_prev_start timestamptz := v_month_start - interval '1 month';
begin
  -- Solo el dueño del tenant puede leer sus métricas.
  if private.current_tenant_id() is distinct from p_tenant_id then
    raise exception 'FORBIDDEN';
  end if;

  return (
    select jsonb_build_object(
      'month_total', coalesce(sum(o.total) filter (where o.created_at >= v_month_start), 0),
      'month_count', count(*) filter (where o.created_at >= v_month_start),
      'prev_total', coalesce(sum(o.total) filter (where o.created_at < v_month_start), 0),
      'prev_count', count(*) filter (where o.created_at < v_month_start)
    )
    from public.orders o
    where o.tenant_id = p_tenant_id
      and o.status <> 'rejected'
      and o.created_at >= v_prev_start
      and not exists (
        select 1 from public.users u
        where u.id = o.customer_id and u.tenant_id = o.tenant_id
      )
  ) || (
    select jsonb_build_object(
      'top_products', coalesce(jsonb_agg(
        jsonb_build_object(
          'title', t.title,
          'qty', t.qty,
          'revenue', t.revenue
        ) order by t.qty desc, t.revenue desc
      ), '[]'::jsonb)
    )
    from (
      select
        oi.title_snapshot as title,
        sum(oi.quantity)::int as qty,
        sum(oi.unit_price * oi.quantity) as revenue
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where o.tenant_id = p_tenant_id
        and o.status <> 'rejected'
        and o.created_at >= v_month_start
        and not exists (
          select 1 from public.users u
          where u.id = o.customer_id and u.tenant_id = o.tenant_id
        )
      group by oi.title_snapshot
      order by qty desc, revenue desc
      limit 3
    ) t
  );
end;
$$;

grant execute on function public.owner_sales_metrics(uuid) to authenticated;
