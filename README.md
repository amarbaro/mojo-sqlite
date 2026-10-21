# mojo-sqlite

SQLite for Mojo that returns the same rows as Python's `sqlite3`, byte for byte, and
runs 2.7× faster on inserts and 4× to 5.5× faster on scans.

```mojo
from sqlite import Database

def main() raises:
    var db = Database("jobs.db")
    var q = db.prepare("SELECT id, cmd FROM jobs WHERE prio >= ?")
    q.bind(1, 10)
    while q.step():
        print(q.int(0), q.text(1))
```

## Install

Requires Mojo 1.1 and the system `libsqlite3.so.0` (any Linux distribution has it).
The library is loaded at run time, so no linker flags are needed.

| Way | Command |
|---|---|
| Source path | `mojo run -I path/to/mojo-sqlite/src app.mojo` |
| Precompiled | `mojo precompile src/sqlite -o sqlite.mojoc`, then put it next to your code |
| Vendor | copy `src/sqlite/` into your project |

## What you get

- `Database`: open, `exec` for scripts, `prepare`, `begin`/`commit`/`rollback`,
  `changes`, `last_insert_rowid`. Busy timeout 5 s by default.
- `Statement`: `bind` for `Int`, `Int64`, `Float64`, `String`, plus `bind_null`;
  `step`, `run`, `reset`; typed column reads, `is_null`, `type`, `name`.
- `text_view(col)`: a column's text read in place from sqlite's buffer, no copy.
- Errors carry sqlite's own message: `sqlite: UNIQUE constraint failed: u.k (rc 19)`.

The API is in [docs/api.md](docs/api.md). The memory and speed design is in
[docs/design.md](docs/design.md).

## Performance

`tests/bench.mojo` against `tools/bench_oracle.py`: 200,000 inserts through one prepared
statement in a transaction, then a full scan, on an on-disk WAL database. Three runs each.

| | insert | scan | peak RSS |
|---|---|---|---|
| Python `sqlite3` | 216 to 226 ms | 98 to 99 ms | 14.5 MB |
| mojo-sqlite, `text()` | 80 to 82 ms | 25 to 29 ms | 15.4 MB |
| mojo-sqlite, `text_view()` | 79 to 82 ms | 18 to 23 ms | 15.2 MB |

The RSS difference is the Mojo runtime: an empty Mojo program uses 11.6 MB.

## Limits

- No BLOB binding or reading yet, and no named parameters (`:name`).
- One connection per `Database`. Do not share a `Database` or `Statement` across threads.
- Linux only: the library is loaded as `libsqlite3.so.0`.

## Check

```
uv sync
scripts/check.sh
```

Every SQL file in `tests/cases/` runs through this library and through Python
`sqlite3` with the same system libsqlite3, and the outputs must be identical: integers,
the exact bits of every float, text with tabs and newlines, NULL, and which statements
fail. Then `tests/api.mojo` covers lifetimes, bind slots, errors and statement reuse.

## For coding agents

[skills/mojo-sqlite/SKILL.md](skills/mojo-sqlite/SKILL.md) tells an agent how to use the
library and what to avoid.

## Licence

Apache-2.0, see [LICENSE](LICENSE).
