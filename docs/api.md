# API

```mojo
from sqlite import Database, Statement, INTEGER, FLOAT, TEXT, BLOB, NULL
```

Every method that talks to sqlite raises `Error("sqlite: <sqlite's message> (rc N)")` on
failure.

## `Database`

| Method | Does |
|---|---|
| `Database(path, busy_timeout_ms=5000, read_only=False)` | open or create; `":memory:"` for an in-memory database; `read_only=True` opens an existing file with SQLITE_OPEN_READONLY (a write raises, nothing is created) |
| `exec(sql)` | run one or more `;`-separated statements that take no parameters |
| `prepare(sql) -> Statement` | compile one statement |
| `begin()`, `commit()`, `rollback()` | transactions |
| `changes() -> Int` | rows changed by the last INSERT, UPDATE or DELETE |
| `last_insert_rowid() -> Int64` | rowid of the last insert |

The connection closes when the `Database` is destroyed. It is safe to destroy it while a
`Statement` from it is still alive: the close waits until that statement is gone.

## `Statement`

### Bind (parameters are numbered from 1, as in SQL)

| Method | |
|---|---|
| `bind(i, Int)`, `bind(i, Int64)`, `bind(i, Float64)` | number |
| `bind(i, String)` | text; the string moves into the statement, sqlite does not copy it |
| `bind(i, List[UInt8])` | BLOB; the bytes move in the same way. An empty list binds an empty BLOB, not NULL |
| `bind_null(i)` | NULL |

A binding stays until it is bound again, including across `reset()`.

### Named parameters

`:name`, `@name` and `$name` in the SQL can be bound by name with every `bind`
overload above and `bind_null(name)`: `q.bind(":prio", 90)`. A name used twice in the
SQL is one parameter. An unknown name raises `no parameter named ':x'`.

`index(name)` returns the position. Each named bind looks the name up, so in a loop
call `index` once and bind by position.

### Run

| Method | |
|---|---|
| `step() -> Bool` | `True` when a row is ready, `False` when finished |
| `run()` | step to the end; for statements that return no rows |
| `reset()` | make the statement runnable again |

`reset()` never raises. After `step()` raises (for example on a constraint), call
`reset()`, bind and run again.

### Read the current row (columns are numbered from 0)

| Method | Returns |
|---|---|
| `int(c)` | `Int64` |
| `float(c)` | `Float64` |
| `text(c)` | `String`, a copy |
| `text_view(c)` | `StringSlice` into sqlite's buffer, valid only until the next `step()` or `reset()` |
| `blob(c)` | `List[UInt8]`, a copy |
| `blob_view(c)` | `Span[UInt8]` into sqlite's buffer, same lifetime as `text_view` |
| `is_null(c)` | `Bool` |
| `type(c)` | `INTEGER`, `FLOAT`, `TEXT`, `BLOB` or `NULL` |
| `name(c)` | column name |
| `columns()` | column count |

Reads follow sqlite's conversion rules: `int()` on a TEXT column returns its numeric
prefix, `text()` on a NULL returns `""`. Use `is_null()` to tell NULL from empty text.
