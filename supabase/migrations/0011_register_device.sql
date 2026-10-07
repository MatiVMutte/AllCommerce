-- AllCommerce · 0011 · Register a push token for the current user.
-- A device token belongs to whoever is logged in on that phone right now,
-- so re-assign it when another account signs in on the same device.

create or replace function public.register_device(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    return;
  end if;

  insert into public.user_devices (fcm_token, user_id, platform, updated_at)
  values (p_token, (select auth.uid()), coalesce(p_platform, 'unknown'), now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke execute on function public.register_device(text, text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;
