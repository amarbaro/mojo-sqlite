CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT, score REAL, note TEXT)
;;
INSERT INTO t(name, score, note) VALUES ('alice', 9.5, NULL), ('bob', -0.1, ''), ('çé日本', 1e308, 'tab	and
newline\back')
;;
SELECT * FROM t ORDER BY id
;;
SELECT 9223372036854775807, -9223372036854775808, 0.1 + 0.2, 1.0/3, -0.0, 3 / 2, 7 % 3
;;
UPDATE t SET score = score * 2 WHERE name = 'alice'
;;
SELECT name, typeof(score), length(note) FROM t ORDER BY name
;;
DELETE FROM t WHERE score < 0
;;
SELECT count(*), sum(score), group_concat(name, '|') FROM t
;;
SELECT 'x' || 1 || 2.5, CAST('12abc' AS INTEGER), CAST(3.9 AS INTEGER), NULL IS NULL
;;
INSERT INTO t(id, name) VALUES (1, 'dup')
;;
SELEC broken
;;
BEGIN
;;
INSERT INTO t(name) VALUES ('rolled back')
;;
ROLLBACK
;;
SELECT count(*) FROM t
;;
WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n WHERE x < 5) SELECT x, x * x FROM n
;;
SELECT json_extract('{"a": [1, 2, {"b": "c"}]}', '$.a[2].b'), hex(x'00ff'), zeroblob(0) IS NOT NULL
