begin;

    -- 1) Single-column UUID PK should be used directly as record_id
    create table public.uuid_pk(
        id uuid primary key,
        val int
    );

    select audit.enable_tracking('public.uuid_pk');

    insert into public.uuid_pk(id, val)
    values
        ('01939b2c-8f4a-7009-b123-456789abcdef', 1),
        ('aee67fc2-a1e6-46f8-9e8e-fb2ebb363069', 2);

    -- Expect record_id to equal the inserted UUID values exactly
    select
        op,
        record->>'id' as pk,
        record_id
    from
        audit.record_version
    where
        table_schema = 'public'
        and table_name = 'uuid_pk'
    order by id;


    -- 2) Text PK that is not a UUID should not be used directly
    create table public.text_pk(
        id text primary key,
        val int
    );

    select audit.enable_tracking('public.text_pk');

    insert into public.text_pk(id, val) values ('not-a-uuid', 1);
    update public.text_pk set val = 2 where id = 'not-a-uuid';

    -- Expect direct string equality to be false, but derived id to match audit.to_record_id
    select
        op,
        (record_id::text = record->>'id') as direct_match,
        (record_id = audit.to_record_id(table_oid, audit.primary_key_columns(table_oid), record)) as derived_match
    from
        audit.record_version
    where
        table_schema = 'public'
        and table_name = 'text_pk'
    order by id;

    -- And the same derived record_id must remain stable across operations
    select
        count(distinct record_id) as distinct_record_ids
    from
        audit.record_version
    where
        table_schema = 'public'
        and table_name = 'text_pk';


    -- 3) Non-UUID PKs (e.g., composite) should derive a stable record_id
    create table public.multi_pk(
        id int,
        code text,
        val int,
        primary key(id, code)
    );

    select audit.enable_tracking('public.multi_pk');

    insert into public.multi_pk(id, code, val) values (42, 'X', 1);
    update public.multi_pk set val = 2 where id = 42 and code = 'X';
    delete from public.multi_pk where id = 42 and code = 'X';

    -- Expect derived id to match audit.to_record_id across all ops
    select
        op,
        (record_id = audit.to_record_id(table_oid, audit.primary_key_columns(table_oid), coalesce(record, old_record))) as derived_match
    from
        audit.record_version
    where
        table_schema = 'public'
        and table_name = 'multi_pk'
    order by id;

    -- And expect a single stable identifier across the lifecycle
    select
        count(distinct coalesce(record_id, old_record_id)) as distinct_ids
    from
        audit.record_version
    where
        table_schema = 'public'
        and table_name = 'multi_pk';

rollback;
