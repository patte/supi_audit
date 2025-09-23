begin;
    -- disable logging to avoid cluttering the test output
    \set ECHO none
    set client_min_messages = warning;

    -- begin before audit is created
    drop schema if exists audit cascade;

    create schema auth;

    create function auth.uid()
        returns uuid
        language sql
    as $$ select '76f99606-1b3f-41d1-806d-358b34db3b32'::uuid $$;

    create function auth.role()
        returns text
        language sql
    as $$ select 'anon' $$;

    -- load the audit migration
    \i test/fixtures.sql

    -- re-enable logging
    set client_min_messages = notice;
    \set ECHO all

    -- Check that the auth_uid and auth_role columns are present
    select * from audit.record_version;

    create table public.xyz(id int primary key);

    select audit.enable_tracking('public.xyz'::regclass);

    insert into public.xyz(id) values(1);

    -- Check that defaults populate
    select
        op,
        auth_uid,
        auth_role
    from
        audit.record_version;

rollback;
