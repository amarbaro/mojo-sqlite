#!/usr/bin/env bash
# CI entry point, same on a GitHub runner and a local Ubuntu VM: install, then the gate.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v uv >/dev/null || { echo "FAIL setup: uv not installed"; exit 1; }
libs=$(ldconfig -p 2>/dev/null || true)
[[ "$libs" == *"libsqlite3.so.0 "* ]] || { echo "FAIL setup: libsqlite3.so.0 not found"; exit 1; }
uv sync || { echo "FAIL setup: uv sync"; exit 1; }
python3 -c 'import sqlite3; print("oracle sqlite", sqlite3.sqlite_version)'
scripts/check.sh
