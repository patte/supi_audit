create schema if not exists auth;

-- Returns the current user's UUID from a transaction-local GUC
create or replace function auth.uid()
returns uuid
stable
language sql
as $$
  select nullif(current_setting('app.user_id', true), '')::uuid
$$;

-- Returns the current user's role (arbitrary text) from a transaction-local GUC
create or replace function auth.role()
returns text
stable
language sql
as $$
  select nullif(current_setting('app.role', true), '')
$$;

-- Sets the current user's UUID and role in transaction-local GUCs
-- Usage:
--   call auth.set_context('0198c2f8-8da2-7ce4-962a-27bd5bcd379d'::uuid, 'admin');
create or replace procedure auth.set_context(p_uid uuid, p_role text)
language plpgsql
as $$
begin
  perform set_config('app.user_id', coalesce(p_uid::text, ''), true);
  perform set_config('app.role',    coalesce(p_role, ''),      true);
end;
$$;