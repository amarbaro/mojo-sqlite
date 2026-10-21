from sqlite import Database


def main() raises:
    var db = Database("jobs.db")
    db.exec("CREATE TABLE IF NOT EXISTS jobs(id INTEGER PRIMARY KEY, cmd TEXT, prio INTEGER)")

    # prepare once, bind and run many times
    db.begin()
    var ins = db.prepare("INSERT INTO jobs(cmd, prio) VALUES (?, ?)")
    for i in range(3):
        ins.bind(1, "train --seed " + String(i))
        ins.bind(2, i * 10)
        ins.run()
        ins.reset()
    db.commit()

    var q = db.prepare("SELECT id, cmd, prio FROM jobs WHERE prio >= ? ORDER BY prio DESC")
    q.bind(1, 10)
    while q.step():
        print(q.int(0), q.text(1), q.int(2))
