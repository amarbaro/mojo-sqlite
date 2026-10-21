# Oracle runner: statements separated by a line ";;", each row printed typed and exact.
# Same format as tools/oracle.py (Python sqlite3); scripts/check.sh diffs the two.
from std.memory import bitcast
from std.sys import argv
from sqlite import Database, Statement, INTEGER, FLOAT, NULL


def cell(q: Statement, c: Int) -> String:
    var t = q.type(c)
    if t == INTEGER:
        return "i:" + String(q.int(c))
    if t == FLOAT:
        return "f:" + String(bitcast[DType.int64](q.float(c)))
    if t == NULL:
        return "n"
    return "t:" + q.text(c).replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def main() raises:
    var db = Database(":memory:")
    var k = 0
    for part in open(argv()[1], "r").read().split("\n;;\n"):
        var sql = String(String(part).strip())
        if sql.byte_length() == 0:
            continue
        print("#", k)
        k += 1
        try:
            var q = db.prepare(sql)
            while q.step():
                var line = String()
                for c in range(q.columns()):
                    if c > 0:
                        line += "\t"
                    line += cell(q, c)
                print(line)
            print("changes", db.changes())
        except:
            print("error")
