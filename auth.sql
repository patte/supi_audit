create schema if not exists auth;

-- Returns the current user's UUID from a transaction-local GUC app.user_id
-- raises with a custom message if not set
create or replace function auth.uid()
  returns uuid
  stable
  language plpgsql
as $$
declare
  _uid uuid := nullif(current_setting('auth.user_id', true), '')::uuid;
begin
  if _uid is null then
    raise exception 'auth.uid(): current_setting(''auth.user_id'') must not be empty. Call auth.set_context(user_id, role) to set it.';
  end if;
  return _uid;
end;
$$;

-- Returns the current user's role (arbitrary text) from a transaction-local GUC
create or replace function auth.role()
returns text
stable
language sql
as $$
  select nullif(current_setting('auth.role', true), '')
$$;

-- Sets the current user's UUID and role in transaction-local GUCs
-- Usage:
--   call auth.set_context('0198c2f8-8da2-7ce4-962a-27bd5bcd379d'::uuid, 'admin');
create or replace procedure auth.set_context(p_uid uuid, p_role text)
language plpgsql
as $$
begin
  perform set_config('auth.user_id', coalesce(p_uid::text, ''), true);
  perform set_config('auth.role',    coalesce(p_role, ''),      true);
end;
$$;