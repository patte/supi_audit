-- avoid ts, xact_id differences in output
\set VERBOSITY terse
\set SHOW_CONTEXT never

-- Scenario 1: auth functions exist & return NULL -> insert should ERROR
begin;
    \set ECHO none
    set client_min_messages = warning;
    drop schema if exists audit cascade;
    drop schema if exists auth cascade;
    create schema auth;
    create function auth.uid() returns uuid language sql as $$ select null::uuid $$; -- returns null intentionally
    create function auth.role() returns text language sql as $$ select 'anon' $$;
    \i test/fixtures.sql
    create table public.af_members1(id uuid primary key, name text);
    set client_min_messages = notice; -- re-enable human-visible outputs
    \set ECHO all
    select audit.enable_tracking('public.af_members1');
    insert into public.af_members1 values('11111111-1111-1111-1111-111111111111', 'fail'); -- expect ERROR
rollback;

-- Scenario 2: auth functions exist (from auth.sql), no GUCs set -> insert should ERROR with custom message
begin;
    \set ECHO none
    set client_min_messages = warning;
    drop schema if exists audit cascade;
    drop schema if exists auth cascade;
    create schema auth;
    \i auth.sql
    \i test/fixtures.sql
    create table public.af_members2(id uuid primary key, name text);
    set client_min_messages = notice; \set ECHO all
    select audit.enable_tracking('public.af_members2');
    insert into public.af_members2 values('22222222-2222-2222-2222-222222222222', 'fail'); -- expect error
rollback;

-- Scenario 3: No auth functions at migration time -> no auth columns -> no enforcement
begin;
    \set ECHO none
    set client_min_messages = warning;
    drop schema if exists audit cascade;
    drop schema if exists auth cascade;
    \i test/fixtures.sql
    create table public.af2(id int primary key);
    set client_min_messages = notice; \set ECHO all
    select audit.enable_tracking('public.af2');
    insert into public.af2 values(1);
    -- Show that no auth_* columns exist
    select column_name from information_schema.columns where table_schema='audit' and table_name='record_version' and column_name like 'auth_%' order by 1;
    select op, (record->>'id') as id from audit.record_version;
rollback;

\set VERBOSITY default
\set SHOW_CONTEXT errors