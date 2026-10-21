# Design

Three rules decide the layout: nothing per row is allocated unless the caller asks for a
copy, nothing sqlite already holds is copied, and nothing is looked up twice.

## Calls into sqlite cost 1 ns, not 42 ns

The library is loaded at run time with `OwnedDLHandle`, so no linker flags are needed.
`OwnedDLHandle.call` looks the symbol up with `dlsym` on every call: 42 ns measured. A
bound-and-stepped row makes about six calls, so on the insert benchmark the lookups
alone were 50 of 128 ms.

The eleven functions used per row (bind, step, reset, column reads) are resolved once
when a `Database` opens. Their addresses live in the same struct as the library handle,
shared through an `ArcPointer` by the `Database` and its statements, so the addresses
are valid for as long as anything can call them. A cached call costs 1 ns. Cold calls
(open, exec, prepare, error messages) still go by name.

| | insert 200k | scan |
|---|---|---|
| lookup on every call | 140 ms | 69 ms |
| addresses resolved once | 80 ms | 25 ms |

## Text is bound without a copy

`bind(i, String)` takes the string by value and moves it into a slot the statement owns,
then binds it with `SQLITE_STATIC`, so sqlite reads it in place.

The slots are a `List[String]` sized to the parameter count once, at `prepare`, and never
resized. That matters: Mojo stores a short string inline in the `String` itself, so its
bytes live inside the list's buffer. If the list grew, the buffer would move and sqlite
would read freed memory. `tests/api.mojo` rebinds one slot with a long string while a
short one sits in the next slot, and checks both read back.

## Rows are not objects

There is no row type. `step()` positions the statement and the caller reads the columns
it needs. A scan of 200,000 rows allocates nothing per row with `text_view()`, and one
string per text column with `text()`.

## Correctness: Python `sqlite3` is the oracle

Python's `sqlite3` uses the same system libsqlite3, so for the same SQL it must return
exactly the same values. `tests/run_sql.mojo` and `tools/oracle.py` run every file in
`tests/cases/` and print each value typed and exact (floats as their 64-bit pattern),
and `scripts/check.sh` diffs the two. `tests/cases/gpuwait.sql` is the schema and the
queries of a real job queue.
