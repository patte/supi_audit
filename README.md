# supi_audit

<p>
<a href=""><img src="https://img.shields.io/badge/postgresql-17+-blue.svg" alt="PostgreSQL version" height="18"></a>
<a href="https://github.com/patte/supi_audit/actions"><img src="https://github.com/patte/supi_audit/actions/workflows/test.yaml/badge.svg" alt="Tests" height="18"></a>

</p>

---

**Fork**: This is a fork of [supa_audit](https://github.com/supabase/supa_audit) with the following changes:
  
- [x] Simple migration instead of a postgres extension for easier "installation".
- [x] Test setup with docker-compose instead of nix
- [ ] Includes the transaction id in the audit log

---

The `supi_audit` PostgreSQL code is a generic solution for tracking changes to tables' data over time.

The audit table, `audit.record_version`, leverages each records primary key values to produce a stable `record_id::uuid`, enabling efficient (linear time) history queries.


## Usage

Apply the content of [`supi_audit.sql`](supi_audit.sql) to your database.

```sql
create table public.account(
    id int primary key,
    name text not null
);

-- Enable auditing
select audit.enable_tracking('public.account'::regclass);

-- Insert a record
insert into public.account(id, name)
values (1, 'Foo Barsworth');

-- Update a record
update public.account
set name = 'Foo Barsworht III'
where id = 1;

-- Delete a record
delete from public.account
where id = 1;

-- Truncate the table
truncate table public.account;

-- Review the history
select
    *
from
    audit.record_version;

/*
 id |              record_id               |            old_record_id             |    op    |               ts                | table_oid | table_schema | table_name |                 record                 |             old_record
----+--------------------------------------+--------------------------------------+----------+---------------------------------+-----------+--------------+------------+----------------------------------------+------------------------------------
  1 | 57ca384e-f24c-5af5-b361-a057aeac506c |                                      | INSERT   | Thu Feb 10 17:02:25.621095 2022 |     16439 | public       | account    | {"id": 1, "name": "Foo Barsworth"}     |
  2 | 57ca384e-f24c-5af5-b361-a057aeac506c | 57ca384e-f24c-5af5-b361-a057aeac506c | UPDATE   | Thu Feb 10 17:02:25.622151 2022 |     16439 | public       | account    | {"id": 1, "name": "Foo Barsworht III"} | {"id": 1, "name": "Foo Barsworth"}
  3 |                                      | 57ca384e-f24c-5af5-b361-a057aeac506c | DELETE   | Thu Feb 10 17:02:25.622495 2022 |     16439 | public       | account    |                                        | {"id": 1, "name": "Foo Barsworth III"}
  4 |                                      |                                      | TRUNCATE | Thu Feb 10 17:02:25.622779 2022 |     16439 | public       | account    |                                        |
(4 rows)
*/

-- Disable auditing
select audit.disable_tracking('public.account'::regclass);
```

## Auth

If a function `auth.uid()` and `auth.role()` exists at the time of running the migration, the `audit.record_version` table will have the columns `auth_uid` and `auth_role` which will be populated with the result of calling these functions at the time of the data change.

See [auth.sql test](test/sql/auth.sql).

## Test

### Run the Tests

```sh
./scripts/run-sql-tests.sh
```

### Adding Tests

Tests are located in `test/sql/` and the expected output is in `test/expected/`

The output of the most recent test run is stored in `results/`.

When the output for a test in `results/` is correct, copy it to `test/expected/` and the test will pass.


## Performance


### Write Throughput
Auditing tables reduces throughput of inserts, updates, and deletes.

It is not recommended to enable tracking on tables with a peak write throughput over 3k ops/second.


### Querying

When querying a table's history, filter on the indexed `table_oid` rather than the `table_name` and `schema_name` columns.

```sql
select
    *
from
    audit.record_version
where
    table_oid = 'public.account'::regclass::oid;
```
