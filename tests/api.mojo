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
    # bound BLOBs: bytes with zeros survive, an empty BLOB is a BLOB, not NULL
    db.exec("CREATE TABLE bl(b)")
    var bi = db.prepare("INSERT INTO bl VALUES (?)")
    var raw: List[UInt8] = [0, 255, 0, 7]
    bi.bind(1, raw^)
    bi.run()
    bi.reset()
    bi.bind(1, List[UInt8]())
    bi.run()
    bi.reset()
    bi.bind(1, "")
    bi.run()
    var br = db.prepare("SELECT b, typeof(b), length(b) FROM bl ORDER BY rowid")
    assert_true(br.step())
    var got = br.blob(0)
    assert_equal(len(got), 4)
    assert_equal(got[0], 0)
    assert_equal(got[1], 255)
    assert_equal(got[3], 7)
    assert_equal(br.text(1), "blob")
    assert_true(br.step())
    assert_equal(br.text(1), "blob")
    assert_equal(br.int(2), 0)
    assert_equal(len(br.blob_view(0)), 0)
    assert_true(br.step())
    assert_equal(br.text(1), "text")
    assert_false(br.is_null(0))

    # named parameters: every type, a name used twice, unknown names raise
    db.exec("CREATE TABLE np(a, b, c, d, e)")
    var nb = db.prepare("INSERT INTO np VALUES (:i, :f, :s, :b, :n)")
    nb.bind(":i", 5)
    nb.bind(":f", 2.5)
    nb.bind(":s", "named")
    var two: List[UInt8] = [1, 2]
    nb.bind(":b", two^)
    nb.bind_null(":n")
    nb.run()
    assert_equal(nb.index(":s"), 3)
    with assert_raises(contains="no parameter named ':missing'"):
        nb.bind(":missing", 1)
    var twice = db.prepare("SELECT :v + :v, @w, $x")
    twice.bind(":v", 21)
    twice.bind("@w", "at")
    twice.bind("$x", Int64(-1))
    assert_true(twice.step())
    assert_equal(twice.int(0), 42)
    assert_equal(twice.text(1), "at")
    assert_equal(twice.int(2), -1)
    var nr = db.prepare("SELECT a, b, c, length(d), e IS NULL FROM np")
    assert_true(nr.step())
    assert_equal(nr.int(0), 5)
    assert_equal(nr.float(1), 2.5)
    assert_equal(nr.text(2), "named")
    assert_equal(nr.int(3), 2)
    assert_equal(nr.int(4), 1)
    print("api: ok")
