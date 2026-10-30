-- users: missing INSERT/UPDATE grants for `authenticated`.
-- The app writes profiles directly (createCustomerProfile, updatePhone,
-- updateProfile) and policies users_insert_self_customer /
-- users_update_self already cover ownership — but without the privilege
-- every write failed with "permission denied" (42501): new customer
-- signups and profile edits were broken.

grant insert, update on public.users to authenticated;
