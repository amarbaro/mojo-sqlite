#!/usr/bin/env bash
# The gate: oracle diff against Python sqlite3, edge-case API test, example.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
M=.venv/bin/mojo
command -v python3 >/dev/null || { echo "FAIL setup: python3 (the oracle) not found"; exit 1; }
for sql in tests/cases/*.sql; do
  $M run -I src tests/run_sql.mojo "$sql" > .work/mojo.out || { echo "FAIL run: $sql"; exit 1; }
  python3 -I tools/oracle.py "$sql" > .work/python.out
  diff .work/python.out .work/mojo.out > .work/oracle.diff || { echo "FAIL oracle: $sql differs from Python sqlite3"; cat .work/oracle.diff; exit 1; }
  echo "oracle: $sql identical ($(grep -c '^#' .work/python.out) statements)"
done
$M run -I src tests/api.mojo || { echo "FAIL api: tests/api.mojo"; exit 1; }
$M run -I src examples/quickstart.mojo > /dev/null || { echo "FAIL example: examples/quickstart.mojo"; exit 1; }
echo "PASS all"
