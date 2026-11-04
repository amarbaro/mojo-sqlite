from sqlite import Database


def main() raises:
    var db = Database(":memory:")
    db.exec("CREATE TABLE jobs(cmd TEXT, prio INTEGER); INSERT INTO jobs VALUES ('train', 10), ('eval', 20)")
    var q = db.prepare("SELECT cmd, prio FROM jobs WHERE prio >= ?")  # prepare once, bind and run many times
    q.bind(1, 15)
    while q.step():
        print(q.text(0), q.int(1))
