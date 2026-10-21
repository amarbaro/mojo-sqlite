"""Oracle: run a ;;-separated SQL script with Python sqlite3, print rows typed and exact."""
import sqlite3, struct, sys

def cell(v):
    if v is None: return "n"
    if isinstance(v, int): return f"i:{v}"
    if isinstance(v, float): return "f:%d" % struct.unpack("<q", struct.pack("<d", v))[0]
    return "t:" + v.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")

db = sqlite3.connect(":memory:", isolation_level=None)
parts = [p.strip() for p in open(sys.argv[1]).read().split("\n;;\n") if p.strip()]
for k, sql in enumerate(parts):
    print("#", k)
    try:
        for row in db.execute(sql):
            print("\t".join(cell(v) for v in row))
        print("changes", db.execute("select changes()").fetchone()[0])
    except sqlite3.Error:
        print("error")
