"""Same work as tests/bench.mojo with Python sqlite3."""
import sqlite3, sys, time
N = 200000
db = sqlite3.connect(sys.argv[1], isolation_level=None)
db.executescript("PRAGMA journal_mode=WAL; CREATE TABLE jobs(id INTEGER PRIMARY KEY, cmd TEXT, prio INTEGER, vram REAL)")
t0 = time.perf_counter()
db.execute("BEGIN")
for i in range(N):
    db.execute("INSERT INTO jobs(cmd, prio, vram) VALUES (?, ?, ?)", (f"python train.py --seed {i}", i % 100, float(i % 24)))
db.execute("COMMIT")
t1 = time.perf_counter()
total = nbytes = 0
for id_, cmd, prio, vram in db.execute("SELECT id, cmd, prio, vram FROM jobs"):
    total += id_ + prio
    nbytes += len(cmd.encode())
t2 = time.perf_counter()
print("insert_ms", int((t1 - t0) * 1000), "scan_ms", int((t2 - t1) * 1000), "check", total, nbytes)
