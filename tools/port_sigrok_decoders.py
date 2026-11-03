#!/usr/bin/env python3
"""Translate DSView sigrok decoders into LogicView session-API Lua scripts.

The script is a development tool. It is not shipped in the application.
Run it from the repository root:

    python tools/port_sigrok_decoders.py
"""

from __future__ import annotations

import ast
import enum
import importlib.util
import math
import os
import re
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "DSView-master" / "libsigrokdecode4DSL" / "decoders"
OUTPUT = ROOT / "examples" / "decoders"

LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
}
HELPERS = {
    "bitpack": "logicview.bitpack",
    "bitpack_lsb": "logicview.bitpack_lsb",
    "bitpack_msb": "logicview.bitpack_msb",
    "bitunpack": "logicview.bitunpack",
    "bits2int": "logicview.bits2int",
    "bcd2int": "logicview.bcd2int",
    "bin2int": "logicview.bin2int",
}
TYPE_NAMES = {
    "int": "int", "float": "float", "str": "str", "bytes": "bytes",
    "bytearray": "bytearray", "bool": "bool", "list": "list", "tuple": "tuple",
    "dict": "dict", "set": "set",
}
METHOD_META = {
    "__eq__": "__eq", "__lt__": "__lt", "__le__": "__le", "__gt__": "__gt",
    "__ge__": "__ge", "__str__": "__tostring", "__repr__": "__tostring",
    "__len__": "__len", "__add__": "__add", "__sub__": "__sub", "__mul__": "__mul",
}
SKIP_OUTPUT = {"high_pulses.lua", "session_edges.lua"}


class Unsupported(Exception):
    pass


def lua_string(value) -> str:
    if isinstance(value, bytes):
        return '"' + "".join(f"\\x{byte:02x}" for byte in value) + '"'
    text = str(value)
    out = ['"']
    for char in text:
        code = ord(char)
        if char == "\\":
            out.append("\\\\")
        elif char == '"':
            out.append('\\"')
        elif char == "\n":
            out.append("\\n")
        elif char == "\r":
            out.append("\\r")
        elif char == "\t":
            out.append("\\t")
        elif code < 32 or code == 127:
            out.append(f"\\x{code:02x}")
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


def lua_number(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if -2**63 <= value <= 2**63 - 1:
            return str(value)
        return repr(float(value))
    if isinstance(value, float):
        if math.isnan(value):
            return "(0/0)"
        if math.isinf(value):
            return "math.huge" if value > 0 else "(-math.huge)"
        return repr(value)
    raise Unsupported(f"not a number: {value!r}")


def is_ident(name: str) -> bool:
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", name)) and name not in LUA_KEYWORDS


def ident(name: str) -> str:
    if name in LUA_KEYWORDS:
        name = name + "_"
    if is_ident(name):
        return name
    return "n_" + re.sub(r"[^A-Za-z0-9_]", "_", name)


def attr_ref(obj: str, name: str) -> str:
    if is_ident(name):
        return f"{obj}.{name}"
    return f"{obj}[{lua_string(name)}]"


def literal(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return lua_number(value)
    if isinstance(value, float):
        return lua_number(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, bytes):
        return lua_string(value)
    if isinstance(value, range):
        value = list(value)
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(literal(item) for item in value) + " }"
    if isinstance(value, dict):
        return "logicview.dict({ " + ", ".join(_dict_field(key, item) for key, item in value.items()) + " })"
    if isinstance(value, enum.Enum):
        return literal(value.value)
    raise Unsupported(f"cannot literal {type(value).__name__}")


def _dict_field(key, value) -> str:
    if isinstance(key, str) and is_ident(key):
        return f"{key} = {literal(value)}"
    return f"[{literal(key)}] = {literal(value)}"


def install_sigrok():
    module = types.ModuleType("sigrokdecode")

    class Decoder:
        pass

    module.Decoder = Decoder
    module.OUTPUT_ANN = 0
    module.OUTPUT_PYTHON = 1
    module.OUTPUT_BINARY = 2
    module.OUTPUT_META = 3
    module.SRD_CONF_SAMPLERATE = "samplerate"

    def missing(name):
        def dummy(*_args, **_kwargs):
            return 0
        setattr(module, name, dummy)
        return dummy

    module.__getattr__ = missing
    sys.modules["sigrokdecode"] = module


def load_decoder(folder: Path):
    safe = "d_" + "".join(char if char.isalnum() else "_" for char in folder.name)
    package = "dsviewdec_" + safe
    for key in list(sys.modules):
        if key == package or key.startswith(package + "."):
            del sys.modules[key]
    pkg = types.ModuleType(package)
    pkg.__path__ = [str(folder)]
    pkg.__package__ = package
    sys.modules[package] = pkg
    full = package + ".pd"
    spec = importlib.util.spec_from_file_location(full, folder / "pd.py")
    module = importlib.util.module_from_spec(spec)
    module.__package__ = package
    sys.modules[full] = module
    spec.loader.exec_module(module)
    return module.Decoder


def metadata_table(cls) -> str:
    fields = [
        "api_version = 3",
        f"id = {lua_string(cls.id)}",
        f"name = {lua_string(cls.name)}",
        f"longname = {lua_string(getattr(cls, 'longname', '') or '')}",
        f"desc = {lua_string(getattr(cls, 'desc', '') or '')}",
        f"license = {lua_string(getattr(cls, 'license', '') or '')}",
        f"inputs = {literal(list(getattr(cls, 'inputs', None) or []))}",
        f"outputs = {literal(list(getattr(cls, 'outputs', None) or []))}",
        f"tags = {literal(list(getattr(cls, 'tags', None) or []))}",
        f"channels = {literal([_channel(item) for item in (getattr(cls, 'channels', None) or [])])}",
        f"optional_channels = {literal([_channel(item) for item in (getattr(cls, 'optional_channels', None) or [])])}",
        f"options = {literal([_option(item) for item in (getattr(cls, 'options', None) or [])])}",
        f"annotations = {literal([_text_row(item) for item in (getattr(cls, 'annotations', None) or [])])}",
        f"annotation_rows = {literal([_row(item) for item in (getattr(cls, 'annotation_rows', None) or [])])}",
        f"binary = {literal([_text_row(item) for item in (getattr(cls, 'binary', None) or [])])}",
    ]
    if cls.id in ("0:spi", "1:spi"):
        lanes = [
            {"id": "mosi", "name": "MOSI", "channel": "mosi", "channels": ["mosi", "clk", "cs"], "classes": ["mosi-data"], "value_field": "value"},
            {"id": "miso", "name": "MISO", "channel": "miso", "channels": ["clk", "miso", "cs"], "classes": ["miso-data"], "value_field": "value"},
        ]
        fields.append(f"lanes = {literal(lanes)}")
    if cls.id == "1:uart":
        # The translated decoder emits binary formats 0 and 1 for each byte.
        fields[-1] = 'binary = ' + literal([_text_row(item) for item in (getattr(cls, 'binary', None) or [])] + [["rxtx-all", "RX/TX combined dump"]])
        lanes = [{"id": "rxtx", "name": "RX/TX", "channel": "rxtx", "channels": ["rxtx"], "classes": ["data"], "value_field": "value"}]
        fields.append(f"lanes = {literal(lanes)}")
    if cls.id == "rgb_led_ws281x":
        for i, field in enumerate(fields):
            if field.startswith("annotations = "):
                annotations = [_text_row(item) for item in (getattr(cls, "annotations", None) or [])]
                fields[i] = "annotations = " + literal(annotations + [["byte", "Byte"]])
            elif field.startswith("annotation_rows = "):
                rows = [_row(item) for item in (getattr(cls, "annotation_rows", None) or [])]
                fields[i] = "annotation_rows = " + literal(rows + [["byte", "Bytes", [3]]])
        lanes = [{"id": "color", "name": "RGB LED", "channel": "din", "channels": ["din"], "classes": ["byte"], "value_field": "value"}]
        fields.append(f"lanes = {literal(lanes)}")
    if cls.id in ("0:i2c", "1:i2c"):
        lanes = [{"id": "i2c", "name": "I2C", "channel": "sda", "channels": ["sda", "scl"], "classes": ["start", "repeat-start", "stop", "ack", "nack", "address-read", "address-write", "data-read", "data-write", "warnings"]}]
        fields.append(f"lanes = {literal(lanes)}")
    return "{\n  " + ",\n  ".join(fields) + "\n}"


def _channel(item) -> dict:
    if isinstance(item, str):
        return {"id": item, "name": item, "desc": ""}
    return {"id": item.get("id", ""), "name": item.get("name", item.get("id", "")), "desc": item.get("desc", "")}


def _option(item) -> dict:
    values = item.get("values", ())
    if isinstance(values, range):
        values = list(values)
    return {
        "id": item.get("id", ""),
        "desc": item.get("desc", ""),
        "default": item.get("default", ""),
        "values": list(values) if values is not None else [],
    }


def _text_row(item):
    if isinstance(item, str):
        return [item, ""]
    return list(item)


def _row(item):
    return list(item)


class Gen:
    def __init__(self, folder: Path, decoder):
        self.folder = folder
        self.decoder = decoder
        self.lines: list[str] = []
        self.indent = 0
        self.filename = str(folder / "pd.py")
        self.fresh_id = 0
        self.loop_id = 0
        self.continues: list[str] = []
        self.break_flags: list[str | None] = []
        self.try_depth = 0
        self.class_name = None
        self.class_assigned = None
        self.classes: set[str] = set()
        self.exceptions: set[str] = set()
        self.statics: set[tuple[str, str]] = set()
        self.fn_locals: set[str] = set()
        self.chunk_locals: set[str] = set()
        self.included: set[Path] = set()
        self.pending: list[Path] = []

    def fresh(self) -> str:
        self.fresh_id += 1
        return str(self.fresh_id)

    def emit(self, text: str = ""):
        if text:
            self.lines.append(("  " * self.indent) + text)
        else:
            self.lines.append("")

    def fail(self, node, message):
        raise Unsupported(f"{self.filename}:{getattr(node, 'lineno', '?')}: {message}: {type(node).__name__}")

    def translate(self) -> str:
        pd = self.folder / "pd.py"
        files = []
        self.collect(pd, files)
        names = []
        for path in files:
            names.extend(self.assigned_names(ast.parse(path.read_text(encoding="utf-8")).body))
        ordered = []
        seen = set()
        for name in names:
            if name not in seen and name not in ("srd", "math"):
                seen.add(name)
                ordered.append(ident(name))
        self.chunk_locals = set(ordered)
        header = self.header(pd)
        self.emit("local _type = type")
        self.emit("local _error = error")
        self.emit("local _pcall = pcall")
        self.emit("local _tostring = tostring")
        self.emit("local _tonumber = tonumber")
        self.emit("local _string = string")
        self.emit("local _table = table")
        self.emit("local _math = math")
        self.emit("local _pairs = pairs")
        self.emit("local _setmetatable = setmetatable")
        self.emit("local _select = select")
        self.emit("local _rawequal = rawequal")
        self.emit("local _coroutine = coroutine")
        if ordered:
            for start in range(0, len(ordered), 80):
                self.emit("local " + ", ".join(ordered[start:start + 80]))
        self.emit("local _decoder")
        self.emit()
        self.emitted_files = set()
        self.emit_file(pd, main=True)
        self.emit("return _decoder")
        return header + "\n".join(self.lines) + "\n"

    def emit_file(self, path: Path, main: bool):
        path = path.resolve()
        if path in self.emitted_files:
            return
        self.emitted_files.add(path)
        previous = self.filename, getattr(self, "main_file", False)
        self.filename = str(path)
        self.main_file = main
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for stmt in tree.body:
            self.emit_stmt(stmt)
        self.emit()
        self.filename, self.main_file = previous

    def header(self, pd: Path) -> str:
        lines = [
            "-- Translated from DSView libsigrokdecode for the LogicView session API.",
            f"-- License: {getattr(self.decoder, 'license', '')}",
        ]
        for line in pd.read_text(encoding="utf-8").splitlines():
            if line.startswith("##") and "Copyright" in line:
                lines.append("-- " + line[2:].strip())
        return "\n".join(lines) + "\n\n"

    def collect(self, path: Path, files: list[Path]):
        path = path.resolve()
        if path in self.included or path.name == "irmp_library.py":
            return
        if not path.exists():
            return
        self.included.add(path)
        files.append(path)
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in tree.body:
            if isinstance(node, ast.ImportFrom):
                for extra in self.import_paths(path, node):
                    self.collect(extra, files)

    def import_paths(self, current: Path, node: ast.ImportFrom) -> list[Path]:
        module = node.module or ""
        if module in ("sigrokdecode", "common.srdhelper") or module.startswith("sigrokdecode"):
            return []
        if node.level:
            base = current.parent
            for _ in range(node.level - 1):
                base = base.parent
            if module:
                found = self.find_module(base / module)
                return [found] if found else []
            found = []
            for alias in node.names:
                if alias.name == "irmp_library":
                    continue
                path = self.find_module(base / alias.name)
                if path:
                    found.append(path)
            return found
        if module.startswith("common."):
            found = self.find_module(SOURCE / Path(*module.split(".")))
            return [found] if found else []
        return []

    def find_module(self, base: Path) -> Path | None:
        if base.with_suffix(".py").exists():
            return base.with_suffix(".py")
        if (base / "mod.py").exists():
            return base / "mod.py"
        if (base / "__init__.py").exists():
            text = (base / "__init__.py").read_text(encoding="utf-8")
            if "from .mod import" in text and (base / "mod.py").exists():
                return base / "mod.py"
        return None

    def assigned_names(self, body) -> list[str]:
        names = []

        def add(target):
            if isinstance(target, ast.Name):
                names.append(target.id)
            elif isinstance(target, (ast.Tuple, ast.List)):
                for elt in target.elts:
                    add(elt)
            elif isinstance(target, ast.Starred):
                add(target.value)

        def walk(stmts):
            for stmt in stmts:
                if isinstance(stmt, (ast.FunctionDef, ast.ClassDef)):
                    names.append(stmt.name)
                    continue
                if isinstance(stmt, ast.Assign):
                    for target in stmt.targets:
                        add(target)
                elif isinstance(stmt, ast.AnnAssign) and stmt.target:
                    add(stmt.target)
                elif isinstance(stmt, ast.AugAssign):
                    add(stmt.target)
                elif isinstance(stmt, ast.For):
                    add(stmt.target)
                    walk(stmt.body)
                    walk(stmt.orelse)
                elif isinstance(stmt, ast.While):
                    walk(stmt.body)
                    walk(stmt.orelse)
                elif isinstance(stmt, ast.If):
                    walk(stmt.body)
                    walk(stmt.orelse)
                elif isinstance(stmt, ast.With):
                    for item in stmt.items:
                        if item.optional_vars:
                            add(item.optional_vars)
                    walk(stmt.body)
                elif isinstance(stmt, ast.Try):
                    walk(stmt.body)
                    walk(stmt.orelse)
                    walk(stmt.finalbody)
                    for handler in stmt.handlers:
                        if handler.name:
                            names.append(handler.name)
                        walk(handler.body)
                elif isinstance(stmt, (ast.Import, ast.ImportFrom)):
                    for alias in stmt.names:
                        if alias.name != "*":
                            names.append(alias.asname or alias.name.split(".")[0])

        walk(body)
        return names

    def emit_block(self, stmts):
        for stmt in stmts:
            self.emit_stmt(stmt)

    def emit_stmt(self, node):
        if isinstance(node, ast.FunctionDef):
            self.emit_function(node)
        elif isinstance(node, ast.ClassDef):
            self.emit_class(node)
        elif isinstance(node, ast.Assign):
            self.emit_assign(node.targets, node.value)
        elif isinstance(node, ast.AnnAssign):
            if node.value is not None:
                self.emit_assign([node.target], node.value)
        elif isinstance(node, ast.AugAssign):
            self.emit_aug(node)
        elif isinstance(node, ast.If):
            self.emit(f"if logicview.truth({self.expr(node.test)}) then")
            self.indent += 1
            self.emit_block(node.body)
            self.indent -= 1
            orelse = node.orelse
            while len(orelse) == 1 and isinstance(orelse[0], ast.If):
                nxt = orelse[0]
                self.emit(f"elseif logicview.truth({self.expr(nxt.test)}) then")
                self.indent += 1
                self.emit_block(nxt.body)
                self.indent -= 1
                orelse = nxt.orelse
            if orelse:
                self.emit("else")
                self.indent += 1
                self.emit_block(orelse)
                self.indent -= 1
            self.emit("end")
        elif isinstance(node, ast.For):
            self.emit_for(node)
        elif isinstance(node, ast.While):
            self.emit_while(node)
        elif isinstance(node, ast.Return):
            self.emit_return(self.expr(node.value) if node.value else None)
        elif isinstance(node, ast.Break):
            if self.break_flags and self.break_flags[-1]:
                self.emit(f"{self.break_flags[-1]} = false")
            self.emit("break")
        elif isinstance(node, ast.Continue):
            if not self.continues:
                self.fail(node, "continue outside a loop")
            self.emit(f"goto {self.continues[-1]}")
        elif isinstance(node, ast.Pass):
            pass
        elif isinstance(node, ast.Expr):
            if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                return
            self.emit(self.expr(node.value))
        elif isinstance(node, ast.Raise):
            self.emit_raise(node)
        elif isinstance(node, ast.Try):
            self.emit_try(node)
        elif isinstance(node, ast.Delete):
            self.emit_delete(node)
        elif isinstance(node, ast.With):
            self.emit_with(node)
        elif isinstance(node, ast.Assert):
            message = self.expr(node.msg) if node.msg else lua_string("assertion failed")
            self.emit(f"if not logicview.truth({self.expr(node.test)}) then _error({message}) end")
        elif isinstance(node, ast.Import):
            for alias in node.names:
                self.emit_import(alias.name, alias.asname or alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            self.emit_import_from(node)
        elif isinstance(node, ast.Global):
            pass
        else:
            self.fail(node, "unsupported statement")

    def emit_import(self, module, name):
        snippets = {
            "struct": "logicview.struct",
            "re": "logicview.re",
            "json": "logicview.json",
            "zlib": "{ crc32 = logicview.crc32 }",
            "binascii": "{ crc_hqx = logicview.crc_hqx }",
            "subprocess": "{ CalledProcessError = 'CalledProcessError', check_output = function() _error({ _exc = 'CalledProcessError', args = { 'disassembler is not available' } }, 0) end, check_call = function() _error('external programs are not available') end }",
            "os": "{ path = { join = function(...) return _table.concat({...}, '/') end, exists = function() return false end, dirname = function(p) return p end } }",
            "platform": "{ uname = function() return { 'Windows' } end }",
            "calendar": "{}",
            "decimal": "{ getcontext = function() return {} end, ROUND_HALF_UP = 0, Decimal = function(v) return _tonumber(v) or 0 end }",
            "operator": "{ itemgetter = function(i) return function(row) return logicview.idx(row, i) end end }",
            "ctypes": "{ sizeof = function() _error('ctypes is not available') end }",
            "string": "logicview.dict({ hexdigits = '0123456789abcdefABCDEF', digits = '0123456789', ascii_lowercase = 'abcdefghijklmnopqrstuvwxyz', ascii_uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ascii_letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', whitespace = ' \\t\\n\\r\\v\\f' })",
            "collections": "{ namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }",
        }
        if module in ("math", "sigrokdecode", "sys", "enum"):
            if module == "enum":
                self.emit(f"{ident(name)} = {{}}")
            return
        if module in snippets:
            self.emit(f"{ident(name)} = {snippets[module]}")
            return
        self.emit(f"{ident(name)} = {{}}")

    def emit_import_from(self, node: ast.ImportFrom):
        module = node.module or ""
        if module in ("sigrokdecode",) or node.names[0].name == "Decoder" and module.endswith("pd"):
            return
        if module == "common.srdhelper":
            for alias in node.names:
                target = ident(alias.asname or alias.name)
                if alias.name in HELPERS:
                    self.emit(f"{target} = {HELPERS[alias.name]}")
            return
        paths = self.import_paths(Path(self.filename), node)
        if paths:
            for path in paths:
                self.emit_file(path, main=False)
            for alias in node.names:
                if alias.asname and alias.name != "*":
                    self.emit(f"{ident(alias.asname)} = {ident(alias.name)}")
            return
        if module == "math":
            for alias in node.names:
                self.emit(f"{ident(alias.asname or alias.name)} = _math.{alias.name}")
            return
        if module == "functools" and any(alias.name == "reduce" for alias in node.names):
            self.emit("reduce = function(fn, seq, init)")
            self.emit("  local acc, start_at = init, 1")
            self.emit("  if acc == nil then acc = seq[1]; start_at = 2 end")
            self.emit("  for _i = start_at, #seq do acc = fn(acc, seq[_i]) end")
            self.emit("  return acc")
            self.emit("end")
            return
        if module == "itertools":
            self.emit("chain = function(...)")
            self.emit("  local _out = {}")
            self.emit("  for _i = 1, _select('#', ...) do")
            self.emit("    for _, _v in logicview.iter(_select(_i, ...)) do _out[#_out + 1] = _v end")
            self.emit("  end")
            self.emit("  return _out")
            self.emit("end")
            return
        if module == "collections":
            for alias in node.names:
                self.emit_import("collections", "collections")
                self.emit(f"{ident(alias.asname or alias.name)} = collections.{alias.name}")
            return
        if module == "binascii":
            for alias in node.names:
                if alias.name == "crc_hqx":
                    self.emit(f"{ident(alias.asname or alias.name)} = logicview.crc_hqx")
            return
        if module == "enum":
            return
        if any(alias.name == "irmp_library" for alias in node.names):
            self.emit("irmp_library = { IrmpLibrary = function() _error({ _exc = 'Exception', args = { 'IRMP native library is not available' } }, 0) end }")
            return
        for alias in node.names:
            if alias.name == "*":
                continue
            self.emit(f"{ident(alias.asname or alias.name)} = nil")

    def emit_class(self, node: ast.ClassDef):
        if node.name == "Decoder" and self.main_file and any(self._is_srd_decoder(base) for base in node.bases):
            self.emit_decoder(node)
            return
        name = ident(node.name)
        if self._is_exception(node):
            self.exceptions.add(node.name)
            self.emit(f"{name} = function(msg)")
            self.emit(f"  local text = _tostring(msg or {lua_string(node.name)})")
            self.emit(f"  return _setmetatable({{ _exc = {lua_string(node.name)}, args = {{ text }} }}, {{ __tostring = function() return text end }})")
            self.emit("end")
            return
        self.classes.add(node.name)
        self.emit(f"{name} = {{}}")
        self.emit(f"{name}.__index = {name}")
        bases = [base for base in node.bases if not (isinstance(base, ast.Name) and base.id in ("Enum", "IntEnum", "object"))]
        if len(bases) == 1 and isinstance(bases[0], ast.Name) and bases[0].id not in ("Exception", "BaseException"):
            self.emit(f"_setmetatable({name}, {{ __index = {ident(bases[0].id)} }})")
        saved_name, saved_assigned = self.class_name, self.class_assigned
        self.class_name = node.name
        assigned = set()
        for stmt in node.body:
            if isinstance(stmt, ast.FunctionDef):
                continue
            assigned.update(self.assigned_names([stmt]))
        self.class_assigned = assigned
        methods = []
        for stmt in node.body:
            if isinstance(stmt, ast.FunctionDef):
                if any(isinstance(dec, ast.Name) and dec.id == "staticmethod" for dec in stmt.decorator_list):
                    self.statics.add((node.name, stmt.name))
                methods.append(stmt)
            else:
                self.emit_stmt(stmt)
        self.class_assigned = None
        has_init = False
        for method in methods:
            if method.name == "__init__":
                has_init = True
            self.emit_function(method, owner=name)
        if methods:
            self.emit(f"function {name}.new(...)")
            self.emit(f"  local self = _setmetatable({{}}, {name})")
            if has_init:
                self.emit(f"  {name}.__init__(self, ...)")
            self.emit("  return self")
            self.emit("end")
        self.class_name = saved_name
        self.class_assigned = saved_assigned

    def _is_srd_decoder(self, base) -> bool:
        return isinstance(base, ast.Attribute) and base.attr == "Decoder"

    def _is_exception(self, node: ast.ClassDef) -> bool:
        if any(isinstance(base, ast.Name) and base.id in ("Exception", "BaseException") for base in node.bases):
            return True
        return node.name.endswith("Error") and not any(isinstance(stmt, ast.FunctionDef) for stmt in node.body)

    def emit_decoder(self, node: ast.ClassDef):
        self.emit(f"_decoder = {metadata_table(self.decoder)}")
        stacked = None
        for stmt in node.body:
            if isinstance(stmt, ast.FunctionDef) and stmt.name == "decode":
                args = [arg.arg for arg in stmt.args.args]
                stacked = stmt if args == ["self", "ss", "es", "data"] else None
        for stmt in node.body:
            if isinstance(stmt, ast.FunctionDef):
                if stmt is stacked:
                    self.emit_stacked(stmt)
                else:
                    self.emit_function(stmt, owner="_decoder")

    def emit_stacked(self, node: ast.FunctionDef):
        self.emit("function _decoder.decode(self, start_sample, end_sample, packets)")
        self.indent += 1
        self.emit("local function _lv_packet(self, ss, es, data)")
        self.indent += 1
        self.emit_function_body(node)
        self.indent -= 1
        self.emit("end")
        self.emit("if _type(packets) ~= 'table' then return _lv_packet(self, start_sample, end_sample, packets) end")
        self.emit("for _, _item in ipairs(packets) do")
        self.indent += 1
        self.emit("local payload = _item.data")
        self.emit("if payload == nil then payload = _item end")
        self.emit("local ss = _item.start_sample or start_sample")
        self.emit("local es = _item.end_sample")
        self.emit("if es ~= nil then es = es - 1 end")
        self.emit("_lv_packet(self, ss, es, payload)")
        self.indent -= 1
        self.emit("end")
        self.indent -= 1
        self.emit("end")

    def emit_function(self, node: ast.FunctionDef, owner=None):
        params = [arg.arg for arg in node.args.posonlyargs + node.args.args]
        lua_params = ", ".join(ident(name) for name in params)
        lua_name = METHOD_META.get(node.name, node.name)
        saved = self.fn_locals
        self.fn_locals = set(ident(name) for name in params)
        yields = any(isinstance(child, ast.Yield) for child in ast.walk(node))
        if owner:
            if is_ident(lua_name if lua_name != node.name else ident(node.name) if node.name not in METHOD_META else lua_name):
                shown = lua_name if node.name in METHOD_META else ident(node.name)
                if is_ident(shown):
                    self.emit(f"function {owner}.{shown}({lua_params})")
                else:
                    self.emit(f"{owner}[{lua_string(shown)}] = function({lua_params})")
            else:
                self.emit(f"{owner}[{lua_string(lua_name)}] = function({lua_params})")
        else:
            self.emit(f"{ident(node.name)} = function({lua_params})")
        self.indent += 1
        defaults = node.args.defaults
        if defaults:
            tail = params[-len(defaults):]
            for param, default in zip(tail, defaults):
                self.emit(f"if {ident(param)} == nil then {ident(param)} = {self.expr(default)} end")
        if yields:
            self.emit("return logicview.generator(function()")
            self.indent += 1
            self.emit_function_body(node)
            self.indent -= 1
            self.emit("end)")
        else:
            self.emit_function_body(node)
        self.indent -= 1
        self.emit("end")
        self.fn_locals = saved

    def emit_function_body(self, node: ast.FunctionDef):
        params = {arg.arg for arg in node.args.posonlyargs + node.args.args}
        locals_ = []
        for name in self.assigned_names(node.body):
            if name not in params and name not in locals_:
                locals_.append(name)
        if locals_:
            shown = ", ".join(ident(name) for name in locals_)
            self.fn_locals.update(ident(name) for name in locals_)
            self.emit(f"local {shown}")
        self.emit_block(node.body)

    def emit_for(self, node: ast.For):
        self.loop_id += 1
        label = f"continue_{self.loop_id}"
        flag = f"_nobreak_{self.loop_id}" if node.orelse else None
        if flag:
            self.emit(f"local {flag} = true")
        self.continues.append(label)
        self.break_flags.append(flag)
        targets = self._targets(node.target)
        header, unpack = self.iter_loop(node.iter, targets)
        self.emit(header)
        self.indent += 1
        for line in unpack:
            self.emit(line)
        self.emit_block(node.body)
        self.emit(f"::{label}::")
        self.indent -= 1
        self.emit("end")
        self.continues.pop()
        self.break_flags.pop()
        if node.orelse:
            self.emit(f"if {flag} then")
            self.indent += 1
            self.emit_block(node.orelse)
            self.indent -= 1
            self.emit("end")

    def emit_while(self, node: ast.While):
        self.loop_id += 1
        label = f"continue_{self.loop_id}"
        flag = f"_nobreak_{self.loop_id}" if node.orelse else None
        if flag:
            self.emit(f"local {flag} = true")
        self.continues.append(label)
        self.break_flags.append(flag)
        if isinstance(node.test, ast.Constant) and node.test.value is True:
            self.emit("while true do")
        else:
            self.emit(f"while logicview.truth({self.expr(node.test)}) do")
        self.indent += 1
        self.emit_block(node.body)
        self.emit(f"::{label}::")
        self.indent -= 1
        self.emit("end")
        self.continues.pop()
        self.break_flags.pop()
        if node.orelse:
            self.emit(f"if {flag} then")
            self.indent += 1
            self.emit_block(node.orelse)
            self.indent -= 1
            self.emit("end")

    def iter_loop(self, iter_node, targets):
        stores = []

        def store_lines(prefix_values):
            lines = []
            for target, value in zip(targets, prefix_values):
                lines.extend(self.store_lines(target, value))
            return lines

        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "range":
            args = ", ".join(self.expr(arg) for arg in iter_node.args)
            return f"for _lv_i in logicview.range({args}) do", store_lines(["_lv_i"])
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "enumerate":
            arg = self.expr(iter_node.args[0])
            if len(targets) >= 2:
                return f"for _lv_i, _lv_v in logicview.enumerate({arg}) do", store_lines(["_lv_i", "_lv_v"])
            return f"for _lv_i, _lv_v in logicview.enumerate({arg}) do", store_lines(["{_lv_i, _lv_v}"])
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Name) and iter_node.func.id == "zip":
            args = ", ".join(self.expr(arg) for arg in iter_node.args)
            temps = [f"_lv_z{i}" for i in range(max(1, len(targets)))]
            return f"for {', '.join(temps)} in logicview.zip({args}) do", store_lines(temps)
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Attribute) and iter_node.func.attr in ("items", "iteritems"):
            recv = self.expr(iter_node.func.value)
            if len(targets) >= 2:
                return f"for _lv_k, _lv_v in _pairs({recv}) do", store_lines(["_lv_k", "_lv_v"])
            return f"for _lv_k, _lv_v in _pairs({recv}) do", store_lines(["{_lv_k, _lv_v}"])
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Attribute) and iter_node.func.attr == "keys":
            recv = self.expr(iter_node.func.value)
            return f"for _lv_k, _ in _pairs({recv}) do", store_lines(["_lv_k"])
        if isinstance(iter_node, ast.Call) and isinstance(iter_node.func, ast.Attribute) and iter_node.func.attr == "values":
            recv = self.expr(iter_node.func.value)
            return f"for _, _lv_v in _pairs({recv}) do", store_lines(["_lv_v"])
        src = self.expr(iter_node)
        if len(targets) <= 1:
            return f"for _lv_item in logicview.iter({src}) do", store_lines(["_lv_item"])
        values = [f"logicview.idx(_lv_item, {index})" for index in range(len(targets))]
        return f"for _lv_item in logicview.iter({src}) do", store_lines(values)

    def emit_assign(self, targets, value):
        # `a = b = value` stores one object in every target. `a, b = value` unpacks.
        if len(targets) > 1:
            self.emit("do")
            self.indent += 1
            self.emit(f"local _lv_chain = {self.expr(value)}")
            for target in targets:
                for line in self.store_lines(target, "_lv_chain"):
                    self.emit(line)
            self.indent -= 1
            self.emit("end")
            return
        unpack = isinstance(targets[0], (ast.Tuple, ast.List))
        targets = self._flatten_targets(targets)
        if len(targets) == 1 and not unpack:
            for line in self.store_lines(targets[0], self.expr(value)):
                self.emit(line)
            return
        if isinstance(value, (ast.Tuple, ast.List)) and len(value.elts) == len(targets):
            temps = [f"_lv_a{index}" for index in range(len(targets))]
            self.emit("do")
            self.indent += 1
            self.emit("local " + ", ".join(temps) + " = " + ", ".join(self.expr(elt) for elt in value.elts))
            for target, temp in zip(targets, temps):
                for line in self.store_lines(target, temp):
                    self.emit(line)
            self.indent -= 1
            self.emit("end")
            return
        self.emit("do")
        self.indent += 1
        self.emit(f"local _lv_seq = {self.expr(value)}")
        self.emit("if _type(_lv_seq) == 'function' then")
        self.emit("  local _lv_built = {}")
        self.emit("  for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end")
        self.emit("  _lv_seq = _lv_built")
        self.emit("end")
        for index, target in enumerate(targets):
            for line in self.store_lines(target, f"logicview.idx(_lv_seq, {index})"):
                self.emit(line)
        self.indent -= 1
        self.emit("end")

    def store_lines(self, target, src) -> list[str]:
        if isinstance(target, ast.Name):
            return [f"{self._load_name(target.id, store=True)} = {src}"]
        if isinstance(target, ast.Attribute):
            return [f"{attr_ref(self.expr(target.value), target.attr)} = {src}"]
        if isinstance(target, ast.Subscript) and isinstance(target.slice, ast.Slice):
            lower = self.expr(target.slice.lower) if target.slice.lower else "0"
            upper = self.expr(target.slice.upper) if target.slice.upper else "nil"
            rebuilt = (
                "(function() local _t, _mid = {container}, {src}; "
                "local _head = logicview.slice(_t, 0, {lower}, 1); "
                "local _tail = logicview.slice(_t, {upper}, nil, 1); "
                "if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; "
                "return _head .. _mid .. _tail end; "
                "logicview.list_clear(_t); logicview.extend(_t, _head); "
                "if _type(_mid) == 'string' then local _bytes = {{}}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) "
                "else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()"
            ).format(container=self.expr(target.value), src=src, lower=lower, upper=upper)
            return self.store_lines(target.value, rebuilt)
        if isinstance(target, ast.Subscript):
            return [f"logicview.setidx({self.expr(target.value)}, {self.key_expr(target.slice)}, {src})"]
        if isinstance(target, (ast.Tuple, ast.List)):
            lines = [f"do", f"  local _lv_sub = {src}"]
            for index, elt in enumerate(target.elts):
                for line in self.store_lines(elt, f"logicview.idx(_lv_sub, {index})"):
                    lines.append("  " + line)
            lines.append("end")
            return lines
        self.fail(target, "unsupported assignment target")

    def emit_aug(self, node: ast.AugAssign):
        op = self.binop(node.op, self._target_read(node.target), self.expr(node.value))
        for line in self.store_lines(node.target, op):
            self.emit(line)

    def _target_read(self, target) -> str:
        if isinstance(target, ast.Name):
            return self._load_name(target.id)
        if isinstance(target, ast.Attribute):
            return attr_ref(self.expr(target.value), target.attr)
        if isinstance(target, ast.Subscript):
            return f"logicview.idx({self.expr(target.value)}, {self.key_expr(target.slice)})"
        self.fail(target, "unsupported augmented target")

    def emit_return(self, value):
        if self.try_depth:
            self.emit("_lv_return = true")
            self.emit(f"_lv_value = {value if value is not None else 'nil'}")
            self.emit("return")
            return
        if value is None:
            self.emit("return")
        else:
            self.emit(f"return {value}")

    def emit_raise(self, node: ast.Raise):
        if node.exc is None:
            self.emit("_error(_err or 'error', 0)")
            return
        if isinstance(node.exc, ast.Call):
            self.emit(f"_error({self.expr(node.exc)}, 0)")
            return
        self.emit(f"_error({self.expr(node.exc)}, 0)")

    def emit_try(self, node: ast.Try):
        self.try_depth += 1
        self.emit("do")
        self.indent += 1
        self.emit("local _lv_return = false")
        self.emit("local _lv_value = nil")
        self.emit("local _ok, _err = _pcall(function()")
        self.indent += 1
        self.emit_block(node.body)
        self.indent -= 1
        self.emit("end)")
        self.try_depth -= 1
        self.emit("if _lv_return then return _lv_value end")
        if not node.handlers:
            self.emit("if not _ok then _error(_err, 0) end")
        else:
            self.emit("if not _ok then")
            self.indent += 1
            first = True
            for handler in node.handlers:
                names = self._except_names(handler.type)
                if names is None:
                    test = "true"
                else:
                    checks = " or ".join(
                        f"(_type(_err) == 'table' and _err._exc == {lua_string(name)})" for name in names
                    )
                    test = checks or "false"
                prefix = "if" if first else "elseif"
                self.emit(f"{prefix} {test} then")
                self.indent += 1
                if handler.name:
                    self.emit(f"{ident(handler.name)} = _err")
                self.emit_block(handler.body)
                self.indent -= 1
                first = False
            if any(self._except_names(handler.type) is not None for handler in node.handlers):
                self.emit("else")
                self.indent += 1
                self.emit("_error(_err, 0)")
                self.indent -= 1
            self.emit("end")
            self.indent -= 1
            self.emit("end")
        if node.orelse:
            self.emit("if _ok then")
            self.indent += 1
            self.emit_block(node.orelse)
            self.indent -= 1
            self.emit("end")
        if node.finalbody:
            self.emit_block(node.finalbody)
        self.indent -= 1
        self.emit("end")

    def _except_names(self, typ):
        if typ is None:
            return None
        if isinstance(typ, ast.Name):
            if typ.id in ("Exception", "BaseException"):
                return None
            return [typ.id]
        if isinstance(typ, ast.Attribute):
            return [typ.attr]
        if isinstance(typ, ast.Tuple):
            names = []
            for elt in typ.elts:
                part = self._except_names(elt)
                if part is None:
                    return None
                names.extend(part)
            return names
        return None

    def emit_delete(self, node: ast.Delete):
        for target in node.targets:
            if isinstance(target, ast.Name):
                self.emit(f"{ident(target.id)} = nil")
            elif isinstance(target, ast.Attribute):
                self.emit(f"{attr_ref(self.expr(target.value), target.attr)} = nil")
            elif isinstance(target, ast.Subscript) and isinstance(target.slice, ast.Slice):
                lower = self.expr(target.slice.lower) if target.slice.lower else "0"
                upper = self.expr(target.slice.upper) if target.slice.upper else "nil"
                self.emit("do")
                self.indent += 1
                self.emit(f"local _lv_t = {self.expr(target.value)}")
                self.emit(f"local _lv_head = logicview.slice(_lv_t, 0, {lower}, 1)")
                self.emit(f"local _lv_tail = logicview.slice(_lv_t, {upper}, nil, 1)")
                self.emit("logicview.list_clear(_lv_t)")
                self.emit("logicview.extend(_lv_t, _lv_head)")
                self.emit("logicview.extend(_lv_t, _lv_tail)")
                self.indent -= 1
                self.emit("end")
            elif isinstance(target, ast.Subscript):
                self.emit(f"logicview.setidx({self.expr(target.value)}, {self.key_expr(target.slice)}, nil)")
            else:
                self.fail(target, "unsupported delete")

    def emit_with(self, node: ast.With):
        item = node.items[0]
        expr = item.context_expr
        if isinstance(expr, ast.Call) and isinstance(expr.func, ast.Name) and expr.func.id == "open":
            self.emit("_error('file access is not available')")
            return
        if item.optional_vars:
            for line in self.store_lines(item.optional_vars, self.expr(expr)):
                self.emit(line)
        self.emit_block(node.body)

    def _flatten_targets(self, targets):
        if len(targets) == 1 and isinstance(targets[0], (ast.Tuple, ast.List)):
            return list(targets[0].elts)
        return list(targets)

    def _targets(self, target):
        if isinstance(target, (ast.Tuple, ast.List)):
            return list(target.elts)
        return [target]

    def expr(self, node) -> str:
        if isinstance(node, ast.Constant):
            value = node.value
            if value is None:
                return "nil"
            if isinstance(value, bool):
                return "true" if value else "false"
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                return lua_number(value)
            if isinstance(value, (str, bytes)):
                return lua_string(value)
            if value is Ellipsis:
                return "nil"
            self.fail(node, "unsupported constant")
        if isinstance(node, ast.Name):
            return self._load_name(node.id)
        if isinstance(node, ast.Attribute):
            if isinstance(node.value, ast.Name) and node.value.id == "srd":
                return f"logicview.{node.attr}"
            return attr_ref(self.expr(node.value), node.attr)
        if isinstance(node, ast.Call):
            return self.call_expr(node)
        if isinstance(node, ast.BinOp):
            return self.binop(node.op, self.expr(node.left), self.expr(node.right))
        if isinstance(node, ast.UnaryOp):
            operand = self.expr(node.operand)
            if isinstance(node.op, ast.Not):
                return f"(not logicview.truth({operand}))"
            if isinstance(node.op, ast.USub):
                return f"(-{operand})"
            if isinstance(node.op, ast.UAdd):
                return operand
            if isinstance(node.op, ast.Invert):
                return f"(~{operand})"
            self.fail(node, "unsupported unary operator")
        if isinstance(node, ast.BoolOp):
            # Python and/or return an operand and skip the rest. A function call
            # would evaluate every operand, including shifts of an absent pin.
            keep = "logicview.truth(_v)" if isinstance(node.op, ast.Or) else "not logicview.truth(_v)"
            lines = ["(function()", "  local _v"]
            for index, value in enumerate(node.values):
                lines.append(f"  _v = {self.expr(value)}")
                if index + 1 < len(node.values):
                    lines.append(f"  if {keep} then return _v end")
            lines.append("  return _v")
            lines.append("end)()")
            return "\n".join(lines)
        if isinstance(node, ast.Compare):
            return self.compare(node)
        if isinstance(node, ast.IfExp):
            return f"(function() if logicview.truth({self.expr(node.test)}) then return {self.expr(node.body)} else return {self.expr(node.orelse)} end end)()"
        if isinstance(node, ast.List) or isinstance(node, ast.Tuple):
            return self.sequence(node.elts)
        if isinstance(node, ast.Set):
            return self.sequence(list(node.elts))
        if isinstance(node, ast.Dict):
            return self.dict_expr(node)
        if isinstance(node, ast.Subscript):
            if isinstance(node.slice, ast.Slice):
                return self.slice_expr(self.expr(node.value), node.slice)
            if isinstance(node.slice, ast.Tuple):
                parts = ", ".join(self.expr(elt) for elt in node.slice.elts)
                return f"logicview.idx({self.expr(node.value)}, logicview.tkey({parts}))"
            return f"logicview.idx({self.expr(node.value)}, {self.expr(node.slice)})"
        if isinstance(node, ast.ListComp):
            return self.comprehension(node.generators, f"_lv_out[#_lv_out + 1] = {self.expr(node.elt)}", False)
        if isinstance(node, ast.GeneratorExp):
            return self.comprehension(node.generators, f"_lv_out[#_lv_out + 1] = {self.expr(node.elt)}", False)
        if isinstance(node, ast.DictComp):
            return self.comprehension(
                node.generators,
                f"logicview.setidx(_lv_out, {self.expr(node.key)}, {self.expr(node.value)})",
                True,
            )
        if isinstance(node, ast.Lambda):
            params = ", ".join(ident(arg.arg) for arg in node.args.args)
            return f"(function({params}) return {self.expr(node.body)} end)"
        if isinstance(node, ast.Yield):
            value = self.expr(node.value) if node.value else "nil"
            return f"_coroutine.yield({value})"
        if isinstance(node, ast.JoinedStr):
            return self.joined(node)
        if isinstance(node, ast.FormattedValue):
            value = self.expr(node.value)
            if node.format_spec and isinstance(node.format_spec, ast.JoinedStr):
                spec = "".join(part.value for part in node.format_spec.values if isinstance(part, ast.Constant))
                return f"logicview.format({value}, {lua_string(spec)})"
            return f"_tostring({value})"
        if isinstance(node, ast.Starred):
            return f"table.unpack({self.expr(node.value)})"
        self.fail(node, "unsupported expression")

    def _load_name(self, name, store=False) -> str:
        if self.class_assigned and name in self.class_assigned:
            return f"{ident(self.class_name)}.{ident(name)}"
        if name == "srd":
            return "logicview"
        return ident(name)

    def sequence(self, elts) -> str:
        if any(isinstance(elt, ast.Starred) for elt in elts):
            acc = "{}"
            for elt in elts:
                if isinstance(elt, ast.Starred):
                    acc = f"logicview.extend({acc}, {self.expr(elt.value)})"
                else:
                    acc = f"logicview.extend({acc}, {{ {self.expr(elt)} }})"
            return acc
        return "{ " + ", ".join(self.expr(elt) for elt in elts) + " }"

    def dict_expr(self, node: ast.Dict) -> str:
        fields = []
        for key, value in zip(node.keys, node.values):
            if key is None:
                fields.append(f"[table.unpack({self.expr(value)})]")
                continue
            rendered = self.expr(value)
            if isinstance(key, ast.Constant) and isinstance(key.value, str) and is_ident(key.value):
                fields.append(f"{key.value} = {rendered}")
            elif isinstance(key, ast.Constant) and key.value is None:
                fields.append(f"[logicview.NIL] = {rendered}")
            elif isinstance(key, ast.Tuple):
                parts = ", ".join(self.expr(elt) for elt in key.elts)
                fields.append(f"[logicview.tkey({parts})] = {rendered}")
            else:
                fields.append(f"[{self.expr(key)}] = {rendered}")
        return "logicview.dict({ " + ", ".join(fields) + " })"

    def slice_expr(self, value, slc: ast.Slice) -> str:
        lower = self.expr(slc.lower) if slc.lower else "nil"
        upper = self.expr(slc.upper) if slc.upper else "nil"
        step = self.expr(slc.step) if slc.step else "nil"
        return f"logicview.slice({value}, {lower}, {upper}, {step})"

    def key_expr(self, slc) -> str:
        if isinstance(slc, ast.Tuple):
            return "logicview.tkey(" + ", ".join(self.expr(elt) for elt in slc.elts) + ")"
        return self.expr(slc)

    def binop(self, op, left, right) -> str:
        if isinstance(op, ast.Add):
            return f"logicview.add({left}, {right})"
        if isinstance(op, ast.Sub):
            return f"({left} - {right})"
        if isinstance(op, ast.Mult):
            return f"logicview.mul({left}, {right})"
        if isinstance(op, ast.Div):
            return f"({left} / {right})"
        if isinstance(op, ast.FloorDiv):
            return f"logicview.floordiv({left}, {right})"
        if isinstance(op, ast.Mod):
            return f"logicview.pymod({left}, {right})"
        if isinstance(op, ast.Pow):
            return f"({left} ^ {right})"
        if isinstance(op, ast.LShift):
            return f"({left} << {right})"
        if isinstance(op, ast.RShift):
            return f"({right} and {left} >> {right})" if False else f"({left} >> {right})"
        if isinstance(op, ast.BitOr):
            return f"({left} | {right})"
        if isinstance(op, ast.BitAnd):
            return f"({left} & {right})"
        if isinstance(op, ast.BitXor):
            return f"({left} ~ {right})"
        raise Unsupported(f"operator {type(op).__name__}")

    def compare(self, node: ast.Compare) -> str:
        left = self.expr(node.left)
        parts = []
        for op, comp in zip(node.ops, node.comparators):
            right = self.expr(comp)
            parts.append(self.cmp(op, left, right))
            left = right
        if len(parts) == 1:
            return parts[0]
        return "(" + " and ".join(parts) + ")"

    def cmp(self, op, left, right) -> str:
        if isinstance(op, ast.Eq):
            return f"logicview.eq({left}, {right})"
        if isinstance(op, ast.NotEq):
            return f"(not logicview.eq({left}, {right}))"
        if isinstance(op, ast.Is):
            if right == "nil":
                return f"({left} == nil)"
            return f"_rawequal({left}, {right})"
        if isinstance(op, ast.IsNot):
            if right == "nil":
                return f"({left} ~= nil)"
            return f"(not _rawequal({left}, {right}))"
        if isinstance(op, ast.In):
            return f"logicview.contains({right}, {left})"
        if isinstance(op, ast.NotIn):
            return f"(not logicview.contains({right}, {left}))"
        symbol = {ast.Lt: "<", ast.LtE: "<=", ast.Gt: ">", ast.GtE: ">="}[type(op)]
        return f"({left} {symbol} {right})"

    def call_expr(self, node: ast.Call) -> str:
        func = node.func
        if isinstance(func, ast.Attribute) and isinstance(func.value, ast.Name) and func.value.id in ("SrdIntEnum", "SrdStrEnum"):
            kind = "int_enum" if func.value.id == "SrdIntEnum" else "str_enum"
            if func.attr == "from_str":
                return f"logicview.{kind}(logicview.split({self.expr(node.args[1])}, ' '))"
            if func.attr == "from_list":
                return f"logicview.{kind}({self.expr(node.args[1])})"
        if isinstance(func, ast.Name) and func.id == "super":
            return "nil"
        args, kwargs, star = self.call_args(node)
        if isinstance(func, ast.Name) and func.id == "isinstance":
            return self.isinstance_from(node)
        if isinstance(func, ast.Name):
            return self.builtin_call(func.id, args, kwargs, star, node)
        if isinstance(func, ast.Attribute):
            return self.method_call(func, args, kwargs, star, node)
        rendered = ", ".join(args)
        if star:
            rendered = (rendered + ", " if rendered else "") + f"table.unpack({star})"
        return f"{self.expr(func)}({rendered})"

    def call_args(self, node: ast.Call):
        args = []
        star = None
        for arg in node.args:
            if isinstance(arg, ast.Starred):
                star = self.expr(arg.value)
            else:
                args.append(self.expr(arg))
        kwargs = []
        kw_star = None
        for kw in node.keywords:
            if kw.arg is None:
                kw_star = self.expr(kw.value)
            elif kw.arg == "meta" and isinstance(kw.value, ast.Tuple) and len(kw.value.elts) >= 2:
                args.append(self.expr(kw.value.elts[1]))
            else:
                kwargs.append((kw.arg, self.expr(kw.value)))
        if kw_star and not kwargs:
            kwargs = kw_star
        return args, kwargs, star

    def builtin_call(self, name, args, kwargs, star, node) -> str:
        joined = ", ".join(args)
        if star:
            joined = (joined + ", " if joined else "") + f"table.unpack({star})"
        if name in self.classes and name not in self.exceptions:
            return f"{ident(name)}.new({joined})"
        if name in ("min", "max"):
            return self.minmax(name, args)
        if name == "namedtuple":
            fields = args[1] if len(args) > 1 else "{}"
            return f"(function() local _f = {fields}; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()"
        if name == "round":
            return self.round_call(args)
        if name == "sorted":
            return self.sorted_call(args, kwargs)
        if name in ("list", "tuple", "set"):
            return self.copy_call(args)
        if name == "dict":
            return "logicview.dict({})" if not args else f"logicview.dict({args[0]})"
        if name == "range":
            return self.range_list(args)
        if name == "enumerate":
            return self.enum_list(args)
        if name == "zip":
            return self.zip_list(args)
        if name == "map":
            return self.map_list(args)
        if name == "filter":
            return self.filter_list(args)
        if name == "getattr":
            return self.getattr_call(args)
        if name == "hasattr":
            return f"({args[0]}[{args[1]}] ~= nil)" if len(args) >= 2 else "false"
        if name == "setattr":
            return f"(function() {args[0]}[{args[1]}] = {args[2]}; return nil end)()" if len(args) >= 3 else "nil"
        if name == "divmod":
            return self.divmod_call(args)
        if name == "pow":
            return f"({args[0]} ^ {args[1]})" if len(args) >= 2 else "0"
        if name == "next":
            return f"(function() local _f = logicview.iter({args[0]}); return _f() end)()" if args else "nil"
        mapping = {
            "len": f"logicview.len({joined})",
            "int": f"logicview.tointeger({joined})",
            "str": f"_tostring({joined})",
            "float": f"(_tonumber({joined}) or 0)",
            "ord": f"_string.byte({joined})",
            "chr": f"_string.char({joined})",
            "hex": f"logicview.hex({joined})",
            "bin": f"logicview.bin({joined})",
            "abs": f"_math.abs({joined})",
            "sum": f"logicview.sum({joined})",
            "any": f"logicview.any({joined})",
            "all": f"logicview.all({joined})",
            "reversed": f"logicview.reversed({joined})",
            "repr": f"_tostring({joined})",
            "format": f"logicview.format({joined})",
            "bytes": f"logicview.bytes({joined or 'nil'})",
            "bytearray": f"logicview.bytes({joined or 'nil'})",
            "bool": f"logicview.truth({joined})",
            "print": f"(function() end)({joined})",
            "locals": "logicview.dict({})",
            "callable": f"(_type({joined}) == 'function')",
            "exec": "_error('exec is not available')",
            "open": "_error('file access is not available')",
            "type": f"logicview.pytype({joined})",
        }
        if name in mapping:
            return mapping[name]
        return f"{ident(name)}({joined})"

    def method_call(self, func: ast.Attribute, args, kwargs, star, node) -> str:
        recv = self.expr(func.value)
        name = func.attr
        joined = ", ".join(args)
        if star:
            joined = (joined + ", " if joined else "") + f"table.unpack({star})"
        if isinstance(func.value, ast.Name) and func.value.id == "srd":
            return f"logicview.{name}({joined})"
        if isinstance(func.value, ast.Name) and (func.value.id, name) in self.statics:
            return f"{recv}.{name}({joined})"
        if isinstance(func.value, ast.Name) and func.value.id in self.classes:
            return f"{recv}.{name}({joined})"
        if name == "format":
            return self.format_call(func.value, args, kwargs)
        if isinstance(func.value, ast.Name) and func.value.id in ("struct", "re", "json", "zlib", "math", "string", "collections", "subprocess", "os", "decimal", "operator", "ctypes", "platform", "calendar", "irmp_library"):
            return f"{recv}.{name}({joined})"
        mapped = self.mapped_method(recv, name, args, kwargs, func)
        if mapped:
            return mapped
        if is_ident(name):
            return f"{recv}:{name}({joined})"
        return f"{recv}[{lua_string(name)}]({recv}{', ' + joined if joined else ''})"

    def mapped_method(self, recv, name, args, kwargs, func):
        joined = ", ".join(args)
        if name == "append" and args:
            return f"_table.insert({recv}, {args[0]})"
        if name == "extend" and args:
            return f"logicview.extend({recv}, {args[0]})"
        if name == "insert" and len(args) >= 2:
            return f"logicview.list_insert({recv}, {args[0]}, {args[1]})"
        if name == "pop":
            return f"logicview.list_pop({recv}{', ' + args[0] if args else ''})"
        if name == "clear":
            return f"logicview.list_clear({recv})"
        if name == "reverse":
            return f"logicview.list_reverse({recv})"
        if name == "sort":
            key = None
            if isinstance(kwargs, list):
                for key_name, value in kwargs:
                    if key_name == "key":
                        key = value
            if key:
                return f"(function() _table.sort({recv}, function(a, b) return {key}(a) < {key}(b) end end)() end)()"
            return f"(function() _table.sort({recv}) end)()"
        if name == "remove" and args:
            return f"(function() local _i = logicview.list_index({recv}, {args[0]}); _table.remove({recv}, _i + 1) end)()"
        if name == "copy":
            return f"logicview.copy({recv})"
        if name == "count" and args:
            return f"logicview.count({recv}, {args[0]})"
        if name == "index" and args:
            return f"(function() if _type({recv}) == 'string' then local _n = logicview.find({recv}, {args[0]}); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index({recv}, {args[0]}) end)()"
        if name == "get":
            if isinstance(func.value, ast.Name) and func.value.id == "self":
                return None
            default = args[1] if len(args) > 1 else "nil"
            key = args[0] if args else "nil"
            return f"logicview.dget({recv}, {key}, {default})"
        if name == "keys":
            return f"(function() local _t = {{}}; for _k in _pairs({recv}) do _t[#_t + 1] = _k end; return _t end)()"
        if name == "values":
            return f"(function() local _t = {{}}; for _, _v in _pairs({recv}) do _t[#_t + 1] = _v end; return _t end)()"
        if name == "items":
            return f"(function() local _t = {{}}; for _k, _v in _pairs({recv}) do _t[#_t + 1] = {{_k, _v}} end; return _t end)()"
        if name == "update" and args:
            return f"logicview.dict_update({recv}, {args[0]})"
        if name == "lower":
            return f"_string.lower({recv})"
        if name == "upper":
            return f"_string.upper({recv})"
        if name in ("strip", "lstrip", "rstrip"):
            return f"logicview.strip({recv}{', ' + args[0] if args else ''})"
        if name == "startswith" and args:
            return f"logicview.startswith({recv}, {args[0]})"
        if name == "endswith" and args:
            return f"logicview.endswith({recv}, {args[0]})"
        if name == "split":
            sep = args[0] if args else "nil"
            count = args[1] if len(args) > 1 else "nil"
            return f"logicview.split({recv}, {sep}, {count})"
        if name == "join" and args:
            return f"logicview.join({recv}, {args[0]})"
        if name == "replace" and len(args) >= 2:
            count = args[2] if len(args) > 2 else "nil"
            return f"logicview.replace({recv}, {args[0]}, {args[1]}, {count})"
        if name == "find" and args:
            return f"logicview.find({recv}, {args[0]})"
        if name == "zfill" and args:
            return f"logicview.zfill({recv}, {args[0]})"
        if name == "to_bytes":
            length = args[0] if args else "1"
            order = args[1] if len(args) > 1 else "'big'"
            return f"logicview.to_bytes({recv}, {length}, {order})"
        if name == "from_bytes" and args:
            order = args[1] if len(args) > 1 else "'big'"
            return f"logicview.from_bytes({args[0]}, {order})"
        if name in ("decode", "encode") and not (isinstance(func.value, ast.Name) and func.value.id == "self"):
            return recv
        if name == "hex":
            return f"(function() if _type({recv}) == 'number' then return logicview.hex({recv}) end; return (_tostring({recv}):gsub('.', function(c) return _string.format('%02x', c:byte()) end)) end)()"
        if name == "group":
            return None
        return None

    def format_call(self, value, args, kwargs) -> str:
        if isinstance(value, ast.Constant) and isinstance(value.value, str) and isinstance(kwargs, str):
            expanded = expand_format(value.value)
            if expanded:
                return expanded
        positional = "{ " + ", ".join(args) + " }"
        if isinstance(kwargs, str):
            kw = kwargs
        elif isinstance(kwargs, list) and kwargs:
            kw = "logicview.dict({ " + ", ".join(f"{key} = {val}" for key, val in kwargs) + " })"
        else:
            kw = "logicview.dict({})"
        return f"logicview.pyformat({self.expr(value)}, {positional}, {kw})"

    def isinstance_from(self, node: ast.Call) -> str:
        if len(node.args) < 2:
            return "false"
        return f"logicview.is_a({self.expr(node.args[0])}, {self.type_kind(node.args[1])})"

    def type_kind(self, node) -> str:
        if isinstance(node, ast.Name) and node.id in TYPE_NAMES:
            return lua_string(TYPE_NAMES[node.id])
        if isinstance(node, (ast.Tuple, ast.List)):
            return "{ " + ", ".join(self.type_kind(elt) for elt in node.elts) + " }"
        return self.expr(node)

    def round_call(self, args) -> str:
        if not args:
            return "0"
        if len(args) == 1:
            return f"(function() local _n = {args[0]}; if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)()"
        return f"(function() local _n, _p = {args[0]}, 10 ^ {args[1]}; if _n >= 0 then return _math.floor(_n * _p + 0.5) / _p end; return _math.ceil(_n * _p - 0.5) / _p end)()"

    def sorted_call(self, args, kwargs) -> str:
        key = "nil"
        if isinstance(kwargs, list):
            for name, value in kwargs:
                if name == "key":
                    key = value
        src = args[0] if args else "{}"
        return f"logicview.sorted({src}, {key})"

    def copy_call(self, args) -> str:
        if not args:
            return "{}"
        return f"logicview.copy({args[0]})"

    def range_list(self, args) -> str:
        return f"(function() local _t = {{}}; for _v in logicview.range({', '.join(args)}) do _t[#_t + 1] = _v end; return _t end)()"

    def enum_list(self, args) -> str:
        src = args[0] if args else "{}"
        return f"(function() local _t = {{}}; for _i, _v in logicview.enumerate({src}) do _t[#_t + 1] = {{_i, _v}} end; return _t end)()"

    def zip_list(self, args) -> str:
        return f"(function() local _t = {{}}; for _item in logicview.iter({{ {', '.join(args)} }}) do end; local _n = 0; for _i = 1, math.huge do local _row = {{}}; local _stop = false; for _k = 1, {max(1, len(args))} do local _src = ({{ {', '.join(args)} }})[_k]; local _v = logicview.idx(_src, _i - 1); if _v == nil then _stop = true; break end; _row[_k] = _v end; if _stop then break end; _t[#_t + 1] = _row end; return _t end)()"

    def map_list(self, args) -> str:
        if len(args) < 2:
            return "{}"
        return f"(function() local _t = {{}}; for _, _v in logicview.iter({args[1]}) do _t[#_t + 1] = {args[0]}(_v) end; return _t end)()"

    def filter_list(self, args) -> str:
        if len(args) < 2:
            return "{}"
        return f"(function() local _t = {{}}; for _, _v in logicview.iter({args[1]}) do if logicview.truth({args[0]}(_v)) then _t[#_t + 1] = _v end end; return _t end)()"

    def minmax(self, name, args) -> str:
        fn = "_math.min" if name == "min" else "_math.max"
        op = "<" if name == "min" else ">"
        if len(args) == 1:
            return f"(function() local _m; for _, _v in logicview.iter({args[0]}) do if _m == nil or _v {op} _m then _m = _v end end; return _m end)()"
        return f"{fn}({', '.join(args)})"

    def getattr_call(self, args) -> str:
        default = args[2] if len(args) > 2 else "nil"
        return f"(function() local _v = {args[0]}[{args[1]}]; if _v == nil then return {default} end; return _v end)()"

    def divmod_call(self, args) -> str:
        return f"(function() local _q = logicview.floordiv({args[0]}, {args[1]}); return {{_q, {args[0]} - _q * {args[1]}}} end)()"

    def comprehension(self, generators, store: str, as_dict: bool) -> str:
        lines = ["(function()", "  local _lv_out = " + ("logicview.dict({})" if as_dict else "{}")]
        closing = []
        for comp in generators:
            targets = self._targets(comp.target)
            header, unpack = self.iter_loop(comp.iter, targets)
            lines.append("  " + header)
            for line in unpack:
                lines.append("    " + line)
            for test in comp.ifs:
                lines.append(f"    if logicview.truth({self.expr(test)}) then")
                closing.append("    end")
            closing.append("  end")
        lines.append("    " + store)
        lines.extend(reversed(closing))
        lines.append("  return _lv_out")
        lines.append("end)()")
        return "\n".join(lines)

    def joined(self, node: ast.JoinedStr) -> str:
        parts = []
        for value in node.values:
            if isinstance(value, ast.Constant):
                parts.append(lua_string(value.value))
            else:
                parts.append(self.expr(value))
        if not parts:
            return '""'
        return " .. ".join(f"({part})" for part in parts)


def expand_format(fmt: str):
    parts = []
    buf = []
    index = 0

    def flush():
        if buf:
            parts.append(lua_string("".join(buf)))
            buf.clear()

    while index < len(fmt):
        if fmt.startswith("{{", index):
            buf.append("{")
            index += 2
            continue
        if fmt.startswith("}}", index):
            buf.append("}")
            index += 2
            continue
        if fmt[index] == "{":
            end = fmt.find("}", index)
            if end < 0:
                return None
            body = fmt[index + 1:end]
            field, _, spec = body.partition(":")
            expr = field_expr(field.strip())
            if expr is None:
                return None
            flush()
            if spec:
                parts.append(f"logicview.format({expr}, {lua_string(spec)})")
            else:
                parts.append(f"_tostring({expr})")
            index = end + 1
            continue
        buf.append(fmt[index])
        index += 1
    flush()
    if not parts:
        return '""'
    return " .. ".join(f"({part})" for part in parts)


def field_expr(field: str):
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", field):
        return ident(field)
    match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)((?:\[-?\d+\])+)$", field)
    if not match:
        return None
    expr = ident(match.group(1))
    for number in re.findall(r"\[(-?\d+)\]", match.group(2)):
        expr = f"logicview.idx({expr}, {number})"
    return expr


def output_name(folder: Path) -> str:
    return folder.name.replace(" ", "_") + ".lua"


def port_folder(folder: Path) -> str:
    cls = load_decoder(folder)
    text = Gen(folder, cls).translate()
    if cls.id == "rgb_led_ws281x":
        # Python booleans are integers; Lua needs explicit bit values. Emit
        # the RGB annotation after all components have been assembled.
        old_header = "  local elems, default_val, view_val, i, default_index\n"
        byte_code = """  local count = #self.bits
  if count % 8 == 1 then self.byte_start = self.ss end
  if count > 0 and count % 8 == 0 then
    local byte = 0
    for index = count - 7, count do byte = (byte << 1) | self.bits[index] end
    self:put(self.byte_start, samplenum - 1, self.out_ann, { 3, { logicview.pymod("@%02X", byte) } })
  end
"""
        if old_header not in text:
            raise ValueError("WS281x translated bit handler changed")
        text = text.replace(old_header, old_header + byte_code, 1)
        text = text.replace("  self.bit_ = nil\n  self.colorsize = nil", "  self.bit_ = nil\n  self.last_bit_period = nil\n  self.colorsize = nil", 1)
        text = text.replace("function _decoder.check_bit_(self, samplenum)", "function _decoder.check_bit_(self, samplenum, terminal)")
        old_period = "  tH_samples = (self.es - self.ss)\n  tH ="
        new_period = """  tH_samples = (self.es - self.ss)
  if not terminal then
    self.last_bit_period = period
  elseif self.last_bit_period then
    period = self.last_bit_period
  end
  tH ="""
        if old_period not in text:
            raise ValueError("WS281x translated bit timing changed")
        text = text.replace(old_period, new_period, 1)
        start = text.index("function _decoder.end_(self)")
        end = text.index("function _decoder.decode(self)", start)
        text = text[:start] + """function _decoder.finish_last_bit(self, limit)
  if self.state ~= "BIT FALLING" or not self.es or self.es <= self.ss then return end
  self:check_bit_(limit, true)
  local bit_end = _math.min(limit, self.ss + (self.last_bit_period or (self.es - self.ss)))
  bit_end = _math.max(self.es, bit_end)
  self:put(self.ss, bit_end - 1, self.out_ann, { 0, { logicview.pymod("%d", self.bit_) } })
  _table.insert(self.bits, self.bit_)
  self:handle_bits(bit_end)
end
function _decoder.end_(self)
  self:finish_last_bit(self.last_samplenum + 1)
end
""" + text[end:]
        old_reset = """        self:check_bit_(self.samplenum)
        self:put(self.ss, self.es, self.out_ann, { 0, { logicview.pymod("%d", self.bit_) } })
        _table.insert(self.bits, self.bit_)
        self:handle_bits(self.es)
        self.ss = self.es"""
        if old_reset not in text:
            raise ValueError("WS281x translated reset handling changed")
        text = text.replace(old_reset, "        self:finish_last_bit(self.samplenum)\n        self.ss = self.es", 1)
        text = text.replace("self.bit_ = true", "self.bit_ = 1")
        text = text.replace("self.bit_ = ((tH_samples / period) > 0.5)", "self.bit_ = (tH_samples / period) > 0.5 and 1 or 0")
        for fmt, label in (("06x", "1"), ("08x", "2")):
            line = f'        self:put(self.ss_packet, samplenum, self.out_ann, {{ 2, {{ logicview.pymod("%s#%{fmt}", {{ logicview.idx(self.options, "view_color_order"), view_val }}) }} }})\n'
            old = line + f"        ::continue_{label}::\n      end"
            if old not in text:
                raise ValueError("WS281x translated color loop changed")
            text = text.replace(old, f"        ::continue_{label}::\n      end\n" + line.replace("        self:put", "      self:put").rstrip("\n"))
            old_value = f'logicview.pymod("%s#%{fmt}", {{ logicview.idx(self.options, "view_color_order"), view_val }}) }} }})'
            new_value = f'logicview.pymod("%s#%{fmt}", {{ logicview.idx(self.options, "view_color_order"), view_val }}), logicview.pymod("@%{fmt}", view_val) }} }})'
            if old_value not in text:
                raise ValueError("WS281x translated color output changed")
            text = text.replace(old_value, new_value)
        text = text.replace("self:put(self.ss_packet, samplenum, self.out_ann, { 2,", "self:put(self.ss_packet, samplenum - 1, self.out_ann, { 2,")
    return text


def main(argv):
    sys.dont_write_bytecode = True
    if str(SOURCE) not in sys.path:
        sys.path.insert(0, str(SOURCE))
    install_sigrok()
    only = set(argv[1:])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    folders = sorted(path for path in SOURCE.iterdir() if path.is_dir() and (path / "pd.py").exists())
    failures = []
    written = 0
    for folder in folders:
        if only and folder.name not in only and output_name(folder) not in only:
            continue
        name = output_name(folder)
        if name in SKIP_OUTPUT:
            continue
        try:
            text = port_folder(folder)
            (OUTPUT / name).write_text(text, encoding="utf-8")
            written += 1
        except Exception as exc:
            failures.append(f"{folder.name}: {exc}")
            print(f"FAIL {folder.name}: {exc}", file=sys.stderr)
    print(f"wrote {written} decoders")
    if failures:
        print(f"{len(failures)} failures", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
