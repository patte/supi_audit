begin;

    create table public.snaptest(
        id int primary key,
        name text not null
    );

    insert into public.snaptest(id, name) values (1, 'a'), (2, 'b');

    -- Enable with snapshot
    select audit.enable_tracking('public.snaptest', true);

    -- Collect audit rows
    select
        id,
        op,
        table_schema,
        table_name,
        record,
        old_record
    from
        audit.record_version;

    -- Change one row after snapshot
    update public.snaptest set name = 'b2' where id = 2;

    -- Disable and re-enable without snapshot (should NOT create more snapshot rows)
    select audit.disable_tracking('public.snaptest');
    select audit.enable_tracking('public.snaptest');

    -- Insert another row
    insert into public.snaptest(id, name) values (3, 'c');

    -- Disable and re-enable with snapshot (should create snapshot rows for current state)
    select audit.disable_tracking('public.snaptest');
    select audit.enable_tracking('public.snaptest', true);

    -- Collect audit rows
     select
        id,
        op,
        table_schema,
        table_name,
        record,
        old_record
    from
        audit.record_version;

    -- test complicated table
    create table public.snaptest2(
        id uuid primary key,
        a text not null,
        b int,
        c timestamp with time zone,
        d bytea
    );

    insert into public.snaptest2(id, a, b, c, d) values
        ('00000000-0000-0000-0000-000000000001', 'x', 1, '2025-01-01T00:00:00Z', decode('DEADBEEF', 'hex'));

    -- take snapshot
    select audit.enable_tracking('public.snaptest2', true);

    -- no-op update
    update public.snaptest2 set a = a where id = '00000000-0000-0000-0000-000000000001';

    select
        id,
        op,
        table_schema,
        table_name,
        record,
        old_record
    from
        audit.record_version
    where
        table_name = 'snaptest2'
    order by id;
rollback;
