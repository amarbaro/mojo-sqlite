# 200k inserts through one prepared statement in a transaction, then a full scan.
# Same work as tools/bench_oracle.py. argv[2] = "view" reads text without copying.
from std.sys import argv
from std.time import perf_counter_ns
from sqlite import Database


def main() raises:
    comptime N = 200000
    var db = Database(argv()[1])
    db.exec("PRAGMA journal_mode=WAL; CREATE TABLE jobs(id INTEGER PRIMARY KEY, cmd TEXT, prio INTEGER, vram REAL)")
    var t0 = perf_counter_ns()
    db.begin()
    var ins = db.prepare("INSERT INTO jobs(cmd, prio, vram) VALUES (?, ?, ?)")
    for i in range(N):
        ins.bind(1, "python train.py --seed " + String(i))
        ins.bind(2, i % 100)
        ins.bind(3, Float64(i % 24))
        ins.run()
        ins.reset()
    db.commit()
    var t1 = perf_counter_ns()
    var view = len(argv()) > 2 and argv()[2] == "view"
    var q = db.prepare("SELECT id, cmd, prio, vram FROM jobs")
    var total = 0
    var bytes = 0
    while q.step():
        total += Int(q.int(0)) + Int(q.int(2))
        if view:
            bytes += q.text_view(1).byte_length()
        else:
            bytes += q.text(1).byte_length()
    var t2 = perf_counter_ns()
    print("insert_ms", (t1 - t0) // 1000000, "scan_ms", (t2 - t1) // 1000000, "check", total, bytes)
