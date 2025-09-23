-- Anything that needs to be executed prior to every test goes here
drop schema if exists audit cascade;

-- Ensure the uuid-ossp extension is available for generating UUIDs
create extension if not exists "uuid-ossp";

\i supi_audit.sql
