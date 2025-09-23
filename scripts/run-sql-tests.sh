#!/usr/bin/env bash
set -euo pipefail

# Connection defaults (override via env)
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-54321}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
PGDATABASE="${PGDATABASE:-postgres}"
export PGPASSWORD

# Make results dir
mkdir -p results

# 1) wait for DB
"$(dirname "$0")/wait-for-pg.sh"

# 2) load fixtures (this will run the migration)
echo "Loading fixtures..."
psql -X -q -v ON_ERROR_STOP=1 -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f test/fixtures.sql

# 3) run each test and diff against expected
echo "Running tests..."
fail=0
for f in $(ls -1 test/sql/*.sql | sort); do
  name="$(basename "$f" .sql)"
  out="results/${name}.out"
  exp="test/expected/${name}.out"

  echo "  -> $name"
  # -a echoes input (so output resembles pg_regress expected files)
  # -q suppresses 'CREATE TABLE'/'DROP ...' status noise to match your expected files
  if ! psql -X -a -q -v ON_ERROR_STOP=0 -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -f "$f" >"$out" 2>&1; then
    echo "     psql exited non-zero (allowed if test expects ERRORs); continuing"
  fi

  if ! diff -u "$exp" "$out" >/dev/null 2>&1; then
    echo "  !! DIFF for $name"
    diff -u "$exp" "$out" || true
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "One or more tests failed."
  exit 1
fi

echo "All tests passed."
