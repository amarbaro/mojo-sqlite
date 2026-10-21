---
name: mojo-sqlite
description: "Use SQLite from Mojo with the mojo-sqlite library: open, prepare, bind, step, read, transactions, errors. Use when Mojo code needs a database file or a SQL query."
---

# mojo-sqlite

SQLite for Mojo 1.1 on Linux. It loads the system `libsqlite3.so.0` at run time: no
linker flags. Its results are checked byte for byte against Python's `sqlite3`.

## Install

`mojo run -I <repo>/src app.mojo`, or `mojo precompile <repo>/src/sqlite -o sqlite.mojoc`,
or copy `src/sqlite/`.

## Use

```mojo
from sqlite import Database

def main() raises:
    var db = Database("app.db")
    db.exec("CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v INTEGER)")
    db.begin()
    var put = db.prepare("INSERT OR REPLACE INTO kv VALUES (?, ?)")
    for i in range(1000):
        put.bind(1, "key" + String(i))
        put.bind(2, i)
        put.run()
        put.reset()
    db.commit()
    var get = db.prepare("SELECT v FROM kv WHERE k = ?")
    get.bind(1, "key7")
    if get.step():
        print(get.int(0))
```

## Rules

- **Prepare once, `reset()` between runs.** Do not call `prepare` inside a loop.
- **Wrap many writes in `begin()`/`commit()`.** Without it every insert is its own
  transaction and a disk sync.
- Parameters are numbered from **1**, columns from **0**.
- Never build SQL with string concatenation from user input: bind it.
- `text()` returns a copy. `text_view()` does not, but the view dies at the next `step()`
  or `reset()`: never store it, copy with `String(...)` if you keep it.
- Check `is_null(c)` before reading a column that can be NULL: `text()` of NULL is `""`
  and `int()` of NULL is `0`.
- After a failed `step()`, call `reset()` (it never raises), then bind and run again.

## Errors

`Error("sqlite: <sqlite's message> (rc N)")`. Show it as it is; it names the table,
column or constraint.

## Not supported

BLOB values, named parameters (`:name`), sharing one `Database` across threads.

## Check a change to the library

`scripts/check.sh` must end with `PASS all`.
