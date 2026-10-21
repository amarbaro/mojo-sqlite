# Edge cases a binding gets wrong: lifetimes, bind slots, errors, reuse.
from std.testing import assert_equal, assert_true, assert_false, assert_raises
from sqlite import Database, Statement


def outlive() raises -> Statement:
    # the Database is dropped here; close_v2 must wait for the statement
    var db = Database(":memory:")
    db.exec("CREATE TABLE t(x); INSERT INTO t VALUES (7)")
    return db.prepare("SELECT x FROM t")


def main() raises:
    var q = outlive()
    assert_true(q.step())
    assert_equal(q.int(0), 7)

    var db = Database(":memory:")
    db.exec("CREATE TABLE t(a TEXT, b TEXT)")
    var ins = db.prepare("INSERT INTO t VALUES (?, ?)")
    # short strings are stored inline in their slot: rebinding one slot must not move the other
    ins.bind(1, "a")
    ins.bind(2, "b")
    ins.bind(1, "a much longer string that lives on the heap instead")
    ins.run()
    ins.reset()
    var r = db.prepare("SELECT a, b FROM t")
    assert_true(r.step())
    assert_equal(r.text(0), "a much longer string that lives on the heap instead")
    assert_equal(r.text(1), "b")
    assert_false(r.step())
    # bindings survive reset
    ins.run()
    ins.reset()
    assert_equal(db.changes(), 1)

    with assert_raises(contains="out of range"):
        ins.bind(3, "x")
    with assert_raises(contains="column index out of range"):
        ins.bind(3, 1)
    with assert_raises(contains="syntax error"):
        _ = db.prepare("SELEC 1")
    with assert_raises(contains="no such table"):
        db.exec("SELECT * FROM missing")

    # a constraint error raises from step, and the statement is reusable after reset
    db.exec("CREATE TABLE u(k INTEGER PRIMARY KEY)")
    var u = db.prepare("INSERT INTO u VALUES (?)")
    u.bind(1, 1)
    u.run()
    u.reset()
    with assert_raises(contains="UNIQUE constraint failed"):
        u.run()
    u.reset()
    u.bind(1, 2)
    u.run()
    assert_equal(db.last_insert_rowid(), 2)

    # rollback undoes, commit keeps
    db.begin()
    db.exec("INSERT INTO u VALUES (3)")
    db.rollback()
    var c = db.prepare("SELECT count(*) FROM u")
    assert_true(c.step())
    assert_equal(c.int(0), 2)

    # empty string is TEXT, not NULL; a view equals its copy
    var e = db.prepare("SELECT '', NULL, 'view'")
    assert_true(e.step())
    assert_false(e.is_null(0))
    assert_true(e.is_null(1))
    assert_equal(e.text(0), "")
    assert_equal(String(e.text_view(2)), e.text(2))
    assert_equal(e.name(2), "'view'")
    assert_equal(e.columns(), 3)
    # conversions docs/api.md promises
    var n = db.prepare("SELECT NULL, '42abc'")
    assert_true(n.step())
    assert_equal(n.text(0), "")
    assert_equal(n.int(0), 0)
    assert_equal(n.int(1), 42)
    # reset() after a failed step does not raise, any number of times, and the statement runs again
    var u2 = db.prepare("INSERT INTO u VALUES (?)")
    u2.bind(1, 1)
    with assert_raises(contains="UNIQUE"):
        u2.run()
    u2.reset()
    u2.reset()
    u2.bind(1, 9)
    u2.run()
    assert_equal(db.last_insert_rowid(), 9)
    print("api: ok")
