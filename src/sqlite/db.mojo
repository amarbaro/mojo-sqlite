from std.ffi import OwnedDLHandle, c_int
from std.memory import ArcPointer

comptime OK: c_int = 0
comptime ROW: c_int = 100
comptime DONE: c_int = 101
comptime OPEN_READWRITE_CREATE: c_int = 6
comptime STATIC: Int = 0  # bound bytes outlive the step; sqlite copies nothing

comptime INTEGER: Int = 1
comptime FLOAT: Int = 2
comptime TEXT: Int = 3
comptime BLOB: Int = 4
comptime NULL: Int = 5


struct _Lib(Movable):
    """libsqlite3 plus the addresses of the per-row functions, resolved once.
    OwnedDLHandle.call does a dlsym on every call (42 ns measured); a cached
    address costs 1 ns. The handle lives in the same struct, so the
    addresses stay valid as long as any Database or Statement holds it."""

    var dl: OwnedDLHandle
    var bind_int64: Int
    var bind_double: Int
    var bind_text: Int
    var bind_null: Int
    var step: Int
    var reset: Int
    var column_type: Int
    var column_int64: Int
    var column_double: Int
    var column_text: Int
    var column_bytes: Int
    var bind_blob: Int
    var column_blob: Int

    def __init__(out self) raises:
        self.dl = OwnedDLHandle("libsqlite3.so.0")
        self.bind_int64 = _addr(self.dl, "sqlite3_bind_int64")
        self.bind_double = _addr(self.dl, "sqlite3_bind_double")
        self.bind_text = _addr(self.dl, "sqlite3_bind_text")
        self.bind_null = _addr(self.dl, "sqlite3_bind_null")
        self.step = _addr(self.dl, "sqlite3_step")
        self.reset = _addr(self.dl, "sqlite3_reset")
        self.column_type = _addr(self.dl, "sqlite3_column_type")
        self.column_int64 = _addr(self.dl, "sqlite3_column_int64")
        self.column_double = _addr(self.dl, "sqlite3_column_double")
        self.column_text = _addr(self.dl, "sqlite3_column_text")
        self.column_bytes = _addr(self.dl, "sqlite3_column_bytes")
        self.bind_blob = _addr(self.dl, "sqlite3_bind_blob")
        self.column_blob = _addr(self.dl, "sqlite3_column_blob")

    def call[name: StaticString, R: RegisterPassable = NoneType, *T: AnyType](self, *args: *T) -> R:
        """Cold path: resolve by name on every call."""
        return self.dl.call[name, R](*args)


def _addr(dl: OwnedDLHandle, name: String) raises -> Int:
    return Int(dl.get_function[c_int](name)._opaque)


@always_inline
def _fn[F: TrivialRegisterPassable](a: Int) -> F:
    """Reinterpret a resolved address as a C function pointer of type F."""
    return Pointer(to=a).unsafe_bitcast[F]()[]


comptime _I_I = def(Int) thin abi("C") -> c_int
comptime _I_IC = def(Int, c_int) thin abi("C") -> c_int
comptime _I_ICL = def(Int, c_int, Int64) thin abi("C") -> c_int
comptime _I_ICD = def(Int, c_int, Float64) thin abi("C") -> c_int
comptime _I_ICPCP = def(Int, c_int, Int, c_int, Int) thin abi("C") -> c_int
comptime _L_IC = def(Int, c_int) thin abi("C") -> Int64
comptime _D_IC = def(Int, c_int) thin abi("C") -> Float64
comptime _P_IC = def(Int, c_int) thin abi("C") -> Int


def _view(p: Int, n: c_int) -> StringSlice[ImmUntrackedOrigin]:
    var bytes = Span(unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](unsafe_from_address=p), length=Int(n))
    return StringSlice(unsafe_from_utf8=bytes)


def _cstr(p: Int) -> String:
    """Copy a NUL-terminated C string."""
    var n = 0
    while Pointer[UInt8, ImmUntrackedOrigin](unsafe_from_address=p + n)[] != 0:
        n += 1
    return String(_view(p, c_int(n)))


def _error(lib: ArcPointer[_Lib], db: Int, rc: c_int) -> Error:
    var msg = _cstr(lib[].call["sqlite3_errmsg", Int](db))
    return Error("sqlite: " + msg + " (rc " + String(rc) + ")")


struct Database(Movable):
    """One sqlite3 connection. Closed with sqlite3_close_v2, which waits for
    any statement still alive, so dropping the Database first is safe."""

    var lib: ArcPointer[_Lib]
    var db: Int

    def __init__(out self, path: String, busy_timeout_ms: Int = 5000, read_only: Bool = False) raises:
        self.lib = ArcPointer(_Lib())
        self.db = 0
        var p = path
        var rc = self.lib[].call["sqlite3_open_v2", c_int](
            p.as_c_string_span().ptr(), Pointer(to=self.db), c_int(1) if read_only else OPEN_READWRITE_CREATE, Int(0)
        )
        if rc != OK:
            raise Error("sqlite: cannot open '" + path + "' (rc " + String(rc) + ")")
        _ = self.lib[].call["sqlite3_busy_timeout", c_int](self.db, c_int(busy_timeout_ms))

    def __deinit__(deinit self):
        _ = self.lib[].call["sqlite3_close_v2", c_int](self.db)

    def error(self, rc: c_int) -> Error:
        return _error(self.lib, self.db, rc)

    def exec(self, sql: String) raises:
        """Run one or more statements with no parameters and no result rows."""
        var s = sql
        var rc = self.lib[].call["sqlite3_exec", c_int](self.db, s.as_c_string_span().ptr(), Int(0), Int(0), Int(0))
        if rc != OK:
            raise self.error(rc)

    def prepare(self, sql: String) raises -> Statement:
        var stmt: Int = 0
        var rc = self.lib[].call["sqlite3_prepare_v2", c_int](
            self.db, sql.unsafe_ptr(), c_int(sql.byte_length()), Pointer(to=stmt), Int(0)
        )
        if rc != OK:
            raise self.error(rc)
        return Statement(self.lib, self.db, stmt)

    def changes(self) -> Int:
        return Int(self.lib[].call["sqlite3_changes64", Int64](self.db))

    def last_insert_rowid(self) -> Int64:
        return self.lib[].call["sqlite3_last_insert_rowid", Int64](self.db)

    def begin(self) raises:
        self.exec("BEGIN")

    def commit(self) raises:
        self.exec("COMMIT")

    def rollback(self) raises:
        self.exec("ROLLBACK")


struct Statement(Movable):
    """A prepared statement. Reuse it with reset() instead of preparing again.

    Text is bound with SQLITE_STATIC: the String moves into a slot this
    statement owns. The slot list is sized once to the parameter count and
    never grows, so a short string stored inline in its slot never moves
    while sqlite holds its address."""

    var lib: ArcPointer[_Lib]
    var db: Int
    var stmt: Int
    var texts: List[String]
    var blobs: List[List[UInt8]]

    def __init__(out self, lib: ArcPointer[_Lib], db: Int, stmt: Int):
        self.lib = lib
        self.db = db
        self.stmt = stmt
        var n = Int(lib[].call["sqlite3_bind_parameter_count", c_int](stmt))
        self.texts = List[String](length=n, fill=String())
        self.blobs = List[List[UInt8]](length=n, fill=List[UInt8]())

    def __deinit__(deinit self):
        _ = self.lib[].call["sqlite3_finalize", c_int](self.stmt)

    def _check(self, rc: c_int) raises:
        if rc != OK:
            raise _error(self.lib, self.db, rc)

    # ---- bind (1-based, as in SQL) ----

    def bind(mut self, i: Int, v: Int64) raises:
        self._check(_fn[_I_ICL](self.lib[].bind_int64)(self.stmt, c_int(i), v))

    def bind(mut self, i: Int, v: Int) raises:
        self.bind(i, Int64(v))

    def bind(mut self, i: Int, v: Float64) raises:
        self._check(_fn[_I_ICD](self.lib[].bind_double)(self.stmt, c_int(i), v))

    def bind(mut self, i: Int, var v: String) raises:
        if i < 1 or i > len(self.texts):
            raise Error("sqlite: bind index " + String(i) + " out of range")
        self.texts[i - 1] = v^
        ref s = self.texts[i - 1]
        self._check(
            _fn[_I_ICPCP](self.lib[].bind_text)(
                self.stmt, c_int(i), Int(s.unsafe_ptr()), c_int(s.byte_length()), STATIC
            )
        )

    def bind(mut self, i: Int, var v: List[UInt8]) raises:
        """BLOB. The bytes move into a slot this statement owns, no copy."""
        if i < 1 or i > len(self.blobs):
            raise Error("sqlite: bind index " + String(i) + " out of range")
        if len(v) == 0:
            # a null pointer with length 0 would bind NULL, not an empty BLOB
            self._check(self.lib[].call["sqlite3_bind_zeroblob", c_int](self.stmt, c_int(i), c_int(0)))
            return
        self.blobs[i - 1] = v^
        ref b = self.blobs[i - 1]
        self._check(
            _fn[_I_ICPCP](self.lib[].bind_blob)(self.stmt, c_int(i), Int(b.unsafe_ptr()), c_int(len(b)), STATIC)
        )

    def index(self, name: String) raises -> Int:
        """Position of a named parameter such as ":prio". Look it up once
        outside a loop and bind by position inside it."""
        var n = name
        var i = Int(self.lib[].call["sqlite3_bind_parameter_index", c_int](self.stmt, n.as_c_string_span().ptr()))
        if i == 0:
            raise Error("sqlite: no parameter named '" + name + "'")
        return i

    def bind(mut self, name: String, v: Int) raises:
        self.bind(self.index(name), v)

    def bind(mut self, name: String, v: Int64) raises:
        self.bind(self.index(name), v)

    def bind(mut self, name: String, v: Float64) raises:
        self.bind(self.index(name), v)

    def bind(mut self, name: String, var v: String) raises:
        self.bind(self.index(name), v^)

    def bind(mut self, name: String, var v: List[UInt8]) raises:
        self.bind(self.index(name), v^)

    def bind_null(mut self, name: String) raises:
        self.bind_null(self.index(name))

    def bind_null(mut self, i: Int) raises:
        self._check(_fn[_I_IC](self.lib[].bind_null)(self.stmt, c_int(i)))

    # ---- run ----

    def step(mut self) raises -> Bool:
        """True when a row is ready to read, False when the statement is done."""
        var rc = _fn[_I_I](self.lib[].step)(self.stmt)
        if rc == ROW:
            return True
        if rc == DONE:
            return False
        self._check(rc)
        return False

    def run(mut self) raises:
        """Step a statement that returns no rows (INSERT, UPDATE, DELETE)."""
        while self.step():
            pass

    def reset(mut self):
        """Make the statement runnable again. Bindings stay until rebound.

        Never raises: sqlite3_reset returns the error of the last failed step
        on every call, but the reset itself always succeeds, and step()
        already raised that error."""
        _ = _fn[_I_I](self.lib[].reset)(self.stmt)

    # ---- read the current row (0-based columns) ----

    def columns(self) -> Int:
        return Int(self.lib[].call["sqlite3_column_count", c_int](self.stmt))

    def name(self, col: Int) -> String:
        return _cstr(self.lib[].call["sqlite3_column_name", Int](self.stmt, c_int(col)))

    def type(self, col: Int) -> Int:
        return Int(_fn[_I_IC](self.lib[].column_type)(self.stmt, c_int(col)))

    def is_null(self, col: Int) -> Bool:
        return self.type(col) == NULL

    def int(self, col: Int) -> Int64:
        return _fn[_L_IC](self.lib[].column_int64)(self.stmt, c_int(col))

    def float(self, col: Int) -> Float64:
        return _fn[_D_IC](self.lib[].column_double)(self.stmt, c_int(col))

    def text_view(self, col: Int) -> StringSlice[ImmUntrackedOrigin]:
        """The column's text in sqlite's own buffer, no copy. Valid only until
        the next step(), reset() or the statement's end: copy with String()
        to keep it."""
        var p = _fn[_P_IC](self.lib[].column_text)(self.stmt, c_int(col))
        var n = _fn[_I_IC](self.lib[].column_bytes)(self.stmt, c_int(col))
        return _view(p, n)

    def text(self, col: Int) -> String:
        return String(self.text_view(col))

    def blob_view(self, col: Int) -> Span[UInt8, ImmUntrackedOrigin]:
        """The column's bytes in sqlite's own buffer, no copy. Valid only
        until the next step(), reset() or the statement's end."""
        var p = _fn[_P_IC](self.lib[].column_blob)(self.stmt, c_int(col))
        var n = _fn[_I_IC](self.lib[].column_bytes)(self.stmt, c_int(col))
        return Span(unsafe_ptr=Pointer[UInt8, ImmUntrackedOrigin](unsafe_from_address=p), length=Int(n))

    def blob(self, col: Int) -> List[UInt8]:
        return List[UInt8](self.blob_view(col))
