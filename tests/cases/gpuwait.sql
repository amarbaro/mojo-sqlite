CREATE TABLE IF NOT EXISTS jobs (id TEXT PRIMARY KEY, kind TEXT NOT NULL, spec TEXT NOT NULL, priority INTEGER NOT NULL, state TEXT NOT NULL, submitted_at REAL NOT NULL, started_at REAL, ended_at REAL, pid INTEGER, exit_code INTEGER, error TEXT, fingerprint TEXT)
;;
CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, job_id TEXT NOT NULL, ts REAL NOT NULL, state TEXT NOT NULL, msg TEXT NOT NULL)
;;
CREATE INDEX IF NOT EXISTS jobs_queue ON jobs(state, priority, submitted_at)
;;
CREATE TABLE IF NOT EXISTS holds (room TEXT PRIMARY KEY, reason TEXT NOT NULL, held_at REAL NOT NULL)
;;
PRAGMA table_info(jobs)
;;
INSERT INTO jobs (id, kind, spec, priority, state, submitted_at, fingerprint) VALUES ('j1', 'gpu', '{"cmd": ["python", "train.py"], "vram": 12.5}', 0, 'waiting', 1761030000.125, 'fp-a'), ('j2', 'gpu', '{"cmd": ["bench"]}', 90, 'waiting', 1761030001.5, 'fp-b'), ('j3', 'cpu', '{}', 0, 'running', 1761029999.0, 'fp-a')
;;
SELECT id, priority FROM jobs WHERE state = 'waiting' ORDER BY priority DESC, submitted_at ASC
;;
UPDATE jobs SET state = 'running', started_at = 1761030002.75, pid = 4242 WHERE id = 'j2' AND state = 'waiting'
;;
INSERT INTO events (job_id, ts, state, msg) VALUES ('j2', 1761030002.75, 'running', 'admitted: 12.5 GB free')
;;
UPDATE jobs SET state = 'done', ended_at = 1761030100.0, exit_code = 0 WHERE id = 'j2'
;;
SELECT id, state, ended_at - started_at, exit_code, error FROM jobs ORDER BY id
;;
SELECT json_extract(spec, '$.vram'), json_array_length(spec, '$.cmd') FROM jobs WHERE id = 'j1'
;;
INSERT OR IGNORE INTO holds (room, reason, held_at) VALUES ('gpu', 'driver update', 1761030200.0)
;;
INSERT OR IGNORE INTO holds (room, reason, held_at) VALUES ('gpu', 'second hold ignored', 1761030300.0)
;;
SELECT room, reason FROM holds
;;
SELECT fingerprint, count(*), max(submitted_at) FROM jobs GROUP BY fingerprint ORDER BY fingerprint
;;
DELETE FROM holds WHERE room = 'gpu'
;;
INSERT INTO jobs (id, kind) VALUES ('bad', 'gpu')
