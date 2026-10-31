//! Helpers the translated DSView decoders call: bit packing, checksums, struct,
//! and Python-style regular expressions. The Lua prelude covers the list, string,
//! and formatting operations those scripts use.

use mlua::{Lua, LuaSerdeExt, Table, Value};

use super::DecodeError;

const PRELUDE: &str = r#"
local lv = logicview

function lv.len(v)
  if type(v) == 'string' or type(v) == 'table' then return #v end
  return 0
end

local function is_dict(t)
  local meta = getmetatable(t)
  return type(meta) == 'table' and meta.__logicview_dict == true
end

lv.NIL = {}

function lv.dict(t)
  return setmetatable(t or {}, { __logicview_dict = true })
end

local function dict_key(key)
  if key == nil then return lv.NIL end
  return key
end

function lv.truth(v)
  if v == nil or v == false or v == 0 or v == '' then return false end
  if type(v) == 'number' and v ~= v then return false end
  if type(v) == 'table' and next(v) == nil then return false end
  return true
end

function lv.band(a, b)
  if not lv.truth(a) then return a end
  return b
end

function lv.bor(a, b)
  if lv.truth(a) then return a end
  return b
end

function lv.eq(a, b)
  if rawequal(a, b) then return true end
  local ma = getmetatable(a)
  local mb = getmetatable(b)
  if type(ma) == 'table' and type(ma.__eq) == 'function' then return ma.__eq(a, b) and true or false end
  if type(mb) == 'table' and type(mb.__eq) == 'function' then return mb.__eq(a, b) and true or false end
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  if is_dict(a) or is_dict(b) then
    for key, value in pairs(a) do
      if not lv.eq(value, b[key]) then return false end
    end
    for key in pairs(b) do
      if a[key] == nil then return false end
    end
    return true
  end
  if #a ~= #b then return false end
  for i = 1, #a do
    if not lv.eq(a[i], b[i]) then return false end
  end
  return true
end

function lv.idx(t, k)
  if type(t) == 'string' and type(k) == 'number' then
    local n = #t
    if k < 0 then k = n + k end
    if k < 0 or k >= n then return nil end
    return t:sub(k + 1, k + 1)
  end
  if type(t) == 'table' and is_dict(t) then return t[dict_key(k)] end
  if type(k) == 'number' and type(t) == 'table' then
    local n = #t
    if k < 0 then k = n + k end
    return t[k + 1]
  end
  if type(t) == 'table' then return t[k] end
  return nil
end

function lv.setidx(t, k, v)
  if type(t) ~= 'table' then return end
  if is_dict(t) then t[dict_key(k)] = v; return end
  if type(k) == 'number' then
    local n = #t
    if k < 0 then k = n + k end
    t[k + 1] = v
  else
    t[k] = v
  end
end

function lv.slice(t, start, stop, step)
  step = step or 1
  if step == 0 then error('slice step cannot be zero') end
  local n = type(t) == 'string' and #t or (type(t) == 'table' and #t or 0)
  local function clamp(value, default)
    if value == nil then return default end
    if value < 0 then value = value + n end
    return value
  end
  local a = clamp(start, step > 0 and 0 or n - 1)
  local b = clamp(stop, step > 0 and n or -1)
  local out = {}
  local i = a
  while (step > 0 and i < b) or (step < 0 and i > b) do
    if i >= 0 and i < n then
      if type(t) == 'string' then out[#out + 1] = t:sub(i + 1, i + 1)
      else out[#out + 1] = t[i + 1] end
    end
    i = i + step
  end
  if type(t) == 'string' then return table.concat(out) end
  return out
end

function lv.tkey(...)
  local parts = {}
  for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
  return table.concat(parts, '\31')
end

function lv.add(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    local t = {}
    for i = 1, #a do t[i] = a[i] end
    for i = 1, #b do t[#t + 1] = b[i] end
    return t
  end
  if type(a) == 'string' or type(b) == 'string' then return tostring(a) .. tostring(b) end
  return (a or 0) + (b or 0)
end

function lv.mul(a, b)
  if type(a) == 'string' and type(b) == 'number' then return string.rep(a, math.floor(b)) end
  if type(b) == 'string' and type(a) == 'number' then return string.rep(b, math.floor(a)) end
  if type(a) == 'table' and type(b) == 'number' then
    local t = {}
    for _ = 1, math.floor(b) do for i = 1, #a do t[#t + 1] = a[i] end end
    return t
  end
  if type(b) == 'table' and type(a) == 'number' then return lv.mul(b, a) end
  return (a or 0) * (b or 0)
end

function lv.floordiv(a, b)
  if b == 0 then error('division by zero') end
  return math.floor(a / b)
end

function lv.py_percent(fmt)
  return (tostring(fmt):gsub('%%r', '%%s'):gsub('%%i', '%%d'):gsub('%%u', '%%d'))
end

function lv.pymod(a, b)
  if type(a) == 'string' then
    local fmt = lv.py_percent(a)
    if type(b) == 'table' then return string.format(fmt, table.unpack(b)) end
    return string.format(fmt, b)
  end
  if b == 0 then error('division by zero') end
  return a - math.floor(a / b) * b
end

function lv.range(a, b, step)
  if b == nil then a, b = 0, a end
  step = step or 1
  if step == 0 then error('range step cannot be zero') end
  local i = a
  return function()
    if step > 0 and i >= b then return nil end
    if step < 0 and i <= b then return nil end
    local value = i
    i = i + step
    return value
  end
end

function lv.enumerate(t)
  local n = 0
  if type(t) == 'string' then n = #t
  elseif type(t) == 'table' then n = #t end
  local i = 0
  return function()
    if i >= n then return nil end
    i = i + 1
    local value = type(t) == 'string' and t:sub(i, i) or t[i]
    return i - 1, value
  end
end

function lv.iter(obj)
  if type(obj) == 'string' then
    local i = 0
    return function()
      i = i + 1
      if i > #obj then return nil end
      return obj:sub(i, i)
    end
  end
  if type(obj) == 'table' and type(obj._next) == 'function' then return obj._next end
  if type(obj) == 'table' and is_dict(obj) then
    return coroutine.wrap(function()
      for key in pairs(obj) do coroutine.yield(key) end
    end)
  end
  if type(obj) == 'table' then
    local i = 0
    return function()
      i = i + 1
      if i > #obj then return nil end
      return obj[i]
    end
  end
  return function() return nil end
end

function lv.zip(...)
  local lists = {...}
  local i = 0
  return function()
    i = i + 1
    local values = {}
    for n = 1, #lists do
      local item = lists[n]
      if type(item) ~= 'table' or item[i] == nil and i > #item then return nil end
      values[n] = item[i]
    end
    return table.unpack(values)
  end
end

function lv.contains(container, item)
  if type(container) == 'string' then
    return string.find(container, tostring(item), 1, true) ~= nil
  end
  if type(container) ~= 'table' then return false end
  for i = 1, #container do
    if container[i] == item then return true end
  end
  return container[dict_key(item)] ~= nil
end

function lv.namedtuple(names)
  return function(...)
    local t = {}
    for i = 1, select('#', ...) do
      t[i] = select(i, ...)
      local name = names[i]
      if name ~= nil then t[name] = t[i] end
    end
    return t
  end
end

function lv.int_enum(list)
  local t = {}
  for i = 1, #list do t[tostring(list[i])] = i - 1 end
  return t
end

function lv.str_enum(list)
  local t = {}
  for i = 1, #list do
    local value = tostring(list[i])
    local key = value:upper():gsub('[^A-Z0-9_]', '_')
    t[key] = value
  end
  return t
end

function lv.generator(fn)
  local co = coroutine.create(fn)
  local function nxt()
    if coroutine.status(co) == 'dead' then return nil end
    local ok, value = coroutine.resume(co)
    if not ok then error(value, 0) end
    if value == nil and coroutine.status(co) == 'dead' then return nil end
    return value
  end
  return { _gen = true, _next = nxt }
end

function lv.bytes(value)
  if type(value) == 'string' then return value end
  if type(value) == 'number' then return string.char(value % 256) end
  if type(value) ~= 'table' then return '' end
  local chars = {}
  for i = 1, #value do chars[i] = string.char((tonumber(value[i]) or 0) % 256) end
  return table.concat(chars)
end

function lv.to_bytes(value, length, order)
  length = length or 1
  local n = math.floor(tonumber(value) or 0)
  local chars = {}
  for i = 1, length do
    chars[i] = string.char(n % 256)
    n = math.floor(n / 256)
  end
  if order == 'big' then
    local rev = {}
    for i = 1, length do rev[i] = chars[length - i + 1] end
    chars = rev
  end
  return table.concat(chars)
end

function lv.from_bytes(value, order)
  local bytes = type(value) == 'string' and {value:byte(1, #value)} or value
  local n = 0
  if order == 'little' then
    for i = #bytes, 1, -1 do n = n * 256 + (bytes[i] or 0) end
  else
    for i = 1, #bytes do n = n * 256 + (bytes[i] or 0) end
  end
  return n
end

function lv.tointeger(value, base)
  if type(value) == 'number' then
    if value < 0 then return math.ceil(value) end
    return math.floor(value)
  end
  if type(value) == 'boolean' then return value and 1 or 0 end
  if value == nil then return nil end
  local text = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
  if base == nil and text:sub(1, 2) == '0b' then return tonumber(text:sub(3), 2) or 0 end
  if base == nil and text:sub(1, 2) == '0x' then return tonumber(text, 16) or 0 end
  return tonumber(text, base) or 0
end

function lv.hex(value)
  return string.format('0x%x', lv.tointeger(value))
end

function lv.pytype(value)
  local kind = type(value)
  if kind == 'number' then return 'int' end
  if kind == 'string' then return 'str' end
  if kind == 'table' then return 'list' end
  if kind == 'boolean' then return 'bool' end
  if kind == 'nil' then return 'nil' end
  return kind
end

function lv.extend(target, extra)
  for _, value in lv.iter(extra) do target[#target + 1] = value end
  return target
end

function lv.bin(value)
  local n = lv.tointeger(value)
  if n == 0 then return '0b0' end
  local bits = {}
  while n > 0 do
    table.insert(bits, 1, tostring(n % 2))
    n = math.floor(n / 2)
  end
  return '0b' .. table.concat(bits)
end

function lv.sum(values, start)
  local total = start or 0
  if type(values) ~= 'table' then return total + (values or 0) end
  for i = 1, #values do total = total + (values[i] or 0) end
  return total
end

function lv.any(values)
  for _, value in lv.iter(values) do if lv.truth(value) then return true end end
  return false
end

function lv.all(values)
  for _, value in lv.iter(values) do if not lv.truth(value) then return false end end
  return true
end

function lv.sorted(values, key)
  local copy = {}
  for i = 1, #values do copy[i] = values[i] end
  table.sort(copy, function(left, right)
    local a = key and key(left) or left
    local b = key and key(right) or right
    return a < b
  end)
  return copy
end

function lv.reversed(values)
  if type(values) == 'string' then return values:reverse() end
  local copy = {}
  for i = #values, 1, -1 do copy[#copy + 1] = values[i] end
  return copy
end

function lv.is_a(value, kind)
  if type(kind) == 'table' then
    for i = 1, #kind do if lv.is_a(value, kind[i]) then return true end end
    return getmetatable(value) == kind
  end
  if kind == 'int' or kind == 'float' or kind == 'number' then return type(value) == 'number' end
  if kind == 'str' or kind == 'bytes' or kind == 'bytearray' then return type(value) == 'string' end
  if kind == 'bool' then return type(value) == 'boolean' end
  if kind == 'list' or kind == 'tuple' or kind == 'dict' or kind == 'set' then return type(value) == 'table' end
  if type(kind) == 'string' then return false end
  return false
end

function lv.split(text, sep, count)
  text = tostring(text)
  if sep == nil or sep == '' then
    local out = {}
    for part in text:gmatch('%S+') do out[#out + 1] = part end
    return out
  end
  local out = {}
  local start = 1
  local found = 0
  while true do
    if count and found >= count then break end
    local from, to = string.find(text, sep, start, true)
    if not from then break end
    out[#out + 1] = text:sub(start, from - 1)
    start = to + 1
    found = found + 1
  end
  out[#out + 1] = text:sub(start)
  return out
end

function lv.join(sep, values)
  local parts = {}
  for i = 1, #values do parts[i] = tostring(values[i]) end
  return table.concat(parts, sep)
end

function lv.strip(text, chars)
  text = tostring(text)
  if chars == nil then return (text:gsub('^%s+', ''):gsub('%s+$', '')) end
  local set = '[' .. chars:gsub('([%%%]%^%-])', '%%%1') .. ']'
  return (text:gsub('^' .. set .. '+', ''):gsub(set .. '+$', ''))
end

function lv.startswith(text, prefix)
  text = tostring(text)
  if type(prefix) == 'table' then
    for i = 1, #prefix do if lv.startswith(text, prefix[i]) then return true end end
    return false
  end
  prefix = tostring(prefix)
  return text:sub(1, #prefix) == prefix
end

function lv.endswith(text, suffix)
  text = tostring(text)
  if type(suffix) == 'table' then
    for i = 1, #suffix do if lv.endswith(text, suffix[i]) then return true end end
    return false
  end
  suffix = tostring(suffix)
  return suffix == '' or text:sub(-#suffix) == suffix
end

function lv.replace(text, old, new, count)
  text, old, new = tostring(text), tostring(old), tostring(new)
  if old == '' then return new .. text:gsub('.', new) .. new end
  local done = 0
  local start = 1
  local parts = {}
  while true do
    if count and done >= count then break end
    local from, to = string.find(text, old, start, true)
    if not from then break end
    parts[#parts + 1] = text:sub(start, from - 1)
    parts[#parts + 1] = new
    start = to + 1
    done = done + 1
  end
  parts[#parts + 1] = text:sub(start)
  return table.concat(parts)
end

function lv.find(text, needle, start)
  text = tostring(text)
  start = (start or 0) + 1
  local from = string.find(text, tostring(needle), start, true)
  if not from then return -1 end
  return from - 1
end

function lv.count(text, needle)
  if type(text) == 'table' then
    local n = 0
    for i = 1, #text do if text[i] == needle then n = n + 1 end end
    return n
  end
  local n, start = 0, 1
  needle = tostring(needle)
  while true do
    local from, to = string.find(tostring(text), needle, start, true)
    if not from then return n end
    n = n + 1
    start = to + 1
  end
end

function lv.zfill(text, width)
  text = tostring(text)
  if #text >= width then return text end
  return string.rep('0', width - #text) .. text
end

function lv.pyformat(fmt, args, kwargs)
  fmt = tostring(fmt)
  args = args or {}
  kwargs = kwargs or {}
  local auto = 0
  local function field_value(field)
    if field == '' then
      auto = auto + 1
      return args[auto]
    elseif tonumber(field) then
      return args[tonumber(field) + 1]
    end
    return kwargs[field]
  end
  fmt = fmt:gsub('{{', '\1'):gsub('}}', '\2')
  -- Python permits replacement fields inside a format specification, e.g.
  -- "{1:0>{0}X}". Resolve those before formatting the enclosing field.
  fmt = fmt:gsub('({[^{}]-:.-){([^{}]+)}([^{}]-})', function(prefix, field, suffix)
    return prefix .. tostring(field_value(field)) .. suffix
  end)
  return (fmt:gsub('{([^{}]*)}', function(body)
    local field, spec = body:match('^([^:]*):(.*)$')
    if not field then field, spec = body, '' end
    return lv.format(field_value(field), spec)
  end):gsub('\1', '{'):gsub('\2', '}'))
end

function lv.bitpack(bits)
  local n = 0
  for i = 1, #bits do
    local v = tonumber(bits[i]) or 0
    if v ~= 0 then n = n + (v << (i - 1)) end
  end
  return n
end

function lv.bitpack_lsb(bits, idx)
  if idx ~= nil then
    local packed = {}
    for i = 1, #bits do packed[i] = lv.idx(bits[i], idx) end
    bits = packed
  end
  return lv.bitpack(bits)
end

function lv.bitpack_msb(bits, idx)
  local copy = {}
  for i = 1, #bits do copy[i] = bits[i] end
  if idx ~= nil then
    for i = 1, #copy do copy[i] = lv.idx(copy[i], idx) end
  end
  local rev = {}
  for i = 1, #copy do rev[i] = copy[#copy - i + 1] end
  return lv.bitpack(rev)
end

function lv.bitunpack(num, minbits)
  minbits = minbits or 0
  local res = {}
  num = math.floor(tonumber(num) or 0)
  while num ~= 0 or minbits > 0 do
    res[#res + 1] = num & 1
    num = num >> 1
    minbits = minbits - 1
  end
  return res
end

function lv.bits2int(bs)
  local n = #bs
  local v = 0
  for i = 1, n do
    local bit = bs[i]
    if bit == 1 or bit == '1' or bit == true then v = v + (1 << (n - i)) end
  end
  return v
end

function lv.bcd2int(b)
  b = math.floor(tonumber(b) or 0)
  return (b & 0x0f) + ((b >> 4) * 10)
end

function lv.bin2int(s)
  return tonumber(tostring(s), 2) or 0
end

function lv.dget(t, key, default)
  if type(t) ~= 'table' then return default end
  local value = t[key]
  if value == nil then return default end
  return value
end

function lv.list_pop(t, index)
  if index == nil then return table.remove(t) end
  local n = #t
  if index < 0 then index = n + index end
  return table.remove(t, index + 1)
end

function lv.list_insert(t, index, value)
  local n = #t
  if index < 0 then index = n + index end
  table.insert(t, index + 1, value)
end

function lv.list_clear(t)
  for i = #t, 1, -1 do t[i] = nil end
end

function lv.list_reverse(t)
  local i, j = 1, #t
  while i < j do
    t[i], t[j] = t[j], t[i]
    i, j = i + 1, j - 1
  end
end

function lv.list_index(t, value)
  for i = 1, #t do if t[i] == value then return i - 1 end end
  error('value is not in list')
end

function lv.dict_update(t, extra)
  for key, value in pairs(extra or {}) do t[key] = value end
  return t
end

function lv.copy(value)
  if type(value) ~= 'table' then return value end
  local out = {}
  for key, item in pairs(value) do out[key] = item end
  local meta = getmetatable(value)
  if meta then setmetatable(out, meta) end
  return out
end

function lv.format(value, spec)
  spec = tostring(spec or '')
  local alt = spec:find('#', 1, true) ~= nil
  spec = spec:gsub('#', '')
  local width = tonumber(spec:match('(%d+)')) or 0
  local typ = spec:match('([a-zA-Z])$') or 's'
  local text
  local number = tonumber(value) or 0
  if typ == 'b' then
    local n = math.floor(number)
    if n < 0 then n = 0 end
    text = ''
    repeat
      text = tostring(n % 2) .. text
      n = math.floor(n / 2)
    until n == 0
    if text == '' then text = '0' end
  elseif typ == 'x' or typ == 'X' or typ == 'd' or typ == 'o' or typ == 'f' or typ == 'F' or typ == 'e' or typ == 'E' or typ == 'g' or typ == 'G' then
    local conv = spec:gsub('[<>=^]', '')
    local ok, formatted = pcall(string.format, '%' .. conv, number)
    text = ok and formatted or tostring(value)
    if alt and (typ == 'x' or typ == 'X') and text:sub(1, 2):lower() ~= '0x' then
      text = (typ == 'X' and '0X' or '0x') .. text
    end
  else
    text = tostring(value)
  end
  if width > #text then
    local pad = spec:find('0', 1, true) and '0' or ' '
    text = string.rep(pad, width - #text) .. text
  end
  return text
end
"#;

pub fn install(lua: &Lua) -> Result<(), DecodeError> {
    lua.load(PRELUDE)
        .set_name("logicview prelude")
        .exec()
        .map_err(lua_err)?;
    install_rust(lua)?;
    Ok(())
}

fn install_rust(lua: &Lua) -> Result<(), DecodeError> {
    let lv: Table = lua.globals().get("logicview").map_err(lua_err)?;
    let crc32 = lua
        .create_function(|_, data: Value| Ok(crc32_ieee(&bytes_of(&data)?)))
        .map_err(lua_err)?;
    lv.set("crc32", crc32).map_err(lua_err)?;
    let crc_hqx = lua
        .create_function(|_, (data, init): (Value, Option<i64>)| {
            Ok(crc_hqx(&bytes_of(&data)?, init.unwrap_or(0) as u16) as i64)
        })
        .map_err(lua_err)?;
    lv.set("crc_hqx", crc_hqx).map_err(lua_err)?;

    let json_decode = lua
        .create_function(|lua, text: String| {
            let value: serde_json::Value =
                serde_json::from_str(&text).map_err(|err| mlua::Error::runtime(err.to_string()))?;
            lua.to_value(&value)
        })
        .map_err(lua_err)?;
    let json = lua.create_table().map_err(lua_err)?;
    json.set("loads", json_decode).map_err(lua_err)?;
    json.set(
        "decode",
        json.get::<mlua::Function>("loads").map_err(lua_err)?,
    )
    .map_err(lua_err)?;
    lv.set("json", json).map_err(lua_err)?;

    let pack = lua
        .create_function(|lua, args: mlua::MultiValue| {
            let mut args = args.into_iter();
            let fmt = args
                .next()
                .and_then(|value| lua_text(&value))
                .ok_or_else(|| mlua::Error::runtime("struct.pack expects a format"))?;
            let values: Vec<Value> = args.collect();
            let bytes = struct_pack(&fmt, &values).map_err(mlua::Error::runtime)?;
            lua.create_string(bytes)
        })
        .map_err(lua_err)?;
    let unpack = lua
        .create_function(|lua, (fmt, data): (String, Value)| {
            let bytes = bytes_of(&data)?;
            let values = struct_unpack(&fmt, &bytes).map_err(mlua::Error::runtime)?;
            let table = lua.create_table()?;
            for (index, value) in values.into_iter().enumerate() {
                table.set(index + 1, rust_to_lua(lua, value)?)?;
            }
            Ok(table)
        })
        .map_err(lua_err)?;
    let calcsize = lua
        .create_function(|_, fmt: String| struct_calcsize(&fmt).map_err(mlua::Error::runtime))
        .map_err(lua_err)?;
    let strukt = lua.create_table().map_err(lua_err)?;
    strukt.set("pack", pack).map_err(lua_err)?;
    strukt.set("unpack", unpack).map_err(lua_err)?;
    strukt.set("calcsize", calcsize).map_err(lua_err)?;
    lv.set("struct", strukt).map_err(lua_err)?;

    install_re(lua, &lv)?;
    Ok(())
}

fn install_re(lua: &Lua, lv: &Table) -> Result<(), DecodeError> {
    let re = lua.create_table().map_err(lua_err)?;
    re.set("I", 2).map_err(lua_err)?;
    re.set("IGNORECASE", 2).map_err(lua_err)?;
    re.set("M", 8).map_err(lua_err)?;
    re.set("MULTILINE", 8).map_err(lua_err)?;
    re.set("S", 16).map_err(lua_err)?;
    re.set("DOTALL", 16).map_err(lua_err)?;
    let search = lua
        .create_function(
            |lua, (pattern, text, flags): (String, String, Option<i64>)| {
                regex_search(lua, &pattern, &text, flags.unwrap_or(0), false)
            },
        )
        .map_err(lua_err)?;
    let match_fn = lua
        .create_function(
            |lua, (pattern, text, flags): (String, String, Option<i64>)| {
                regex_search(lua, &pattern, &text, flags.unwrap_or(0), true)
            },
        )
        .map_err(lua_err)?;
    let findall = lua
        .create_function(
            |lua, (pattern, text, flags): (String, String, Option<i64>)| {
                regex_findall(lua, &pattern, &text, flags.unwrap_or(0))
            },
        )
        .map_err(lua_err)?;
    let sub = lua
        .create_function(|lua, args: mlua::MultiValue| regex_sub(lua, args))
        .map_err(lua_err)?;
    let split = lua
        .create_function(
            |lua, (pattern, text, maxsplit): (String, String, Option<i64>)| {
                regex_split(lua, &pattern, &text, maxsplit.unwrap_or(0))
            },
        )
        .map_err(lua_err)?;
    re.set("search", search).map_err(lua_err)?;
    re.set("match", match_fn).map_err(lua_err)?;
    re.set("findall", findall).map_err(lua_err)?;
    re.set("sub", sub).map_err(lua_err)?;
    re.set("split", split).map_err(lua_err)?;
    let compile = lua
        .create_function(move |lua, (pattern, flags): (String, Option<i64>)| {
            let flags = flags.unwrap_or(0);
            let compiled = lua.create_table()?;
            let pattern_search = pattern.clone();
            let pattern_match = pattern.clone();
            let pattern_all = pattern.clone();
            let pattern_sub = pattern.clone();
            let pattern_split = pattern.clone();
            compiled.set(
                "search",
                lua.create_function(move |lua, text: String| {
                    regex_search(lua, &pattern_search, &text, flags, false)
                })?,
            )?;
            compiled.set(
                "match",
                lua.create_function(move |lua, text: String| {
                    regex_search(lua, &pattern_match, &text, flags, true)
                })?,
            )?;
            compiled.set(
                "findall",
                lua.create_function(move |lua, text: String| {
                    regex_findall(lua, &pattern_all, &text, flags)
                })?,
            )?;
            compiled.set(
                "sub",
                lua.create_function(move |lua, args: mlua::MultiValue| {
                    let mut full = vec![Value::String(lua.create_string(&pattern_sub)?)];
                    full.extend(args);
                    regex_sub(lua, mlua::MultiValue::from_vec(full))
                })?,
            )?;
            compiled.set(
                "split",
                lua.create_function(move |lua, (text, maxsplit): (String, Option<i64>)| {
                    regex_split(lua, &pattern_split, &text, maxsplit.unwrap_or(0))
                })?,
            )?;
            Ok(compiled)
        })
        .map_err(lua_err)?;
    re.set("compile", compile).map_err(lua_err)?;
    lv.set("re", re).map_err(lua_err)?;
    Ok(())
}

fn regex_build(pattern: &str, flags: i64) -> Result<regex::Regex, mlua::Error> {
    let mut wrapped = String::new();
    if flags & 2 != 0 {
        wrapped.push_str("(?i)");
    }
    if flags & 8 != 0 {
        wrapped.push_str("(?m)");
    }
    if flags & 16 != 0 {
        wrapped.push_str("(?s)");
    }
    wrapped.push_str(pattern);
    regex::Regex::new(&wrapped).map_err(|err| mlua::Error::runtime(err.to_string()))
}

fn regex_search(
    lua: &Lua,
    pattern: &str,
    text: &str,
    flags: i64,
    anchored: bool,
) -> Result<Value, mlua::Error> {
    let re = regex_build(pattern, flags)?;
    let found = if anchored {
        re.find(text)
            .filter(|item| item.start() == 0)
            .map(|item| (item.start(), item.end()))
    } else {
        re.find(text).map(|item| (item.start(), item.end()))
    };
    let Some((start, end)) = found else {
        return Ok(Value::Nil);
    };
    let caps = if anchored {
        re.captures(text)
            .filter(|caps| caps.get(0).is_some_and(|item| item.start() == 0))
    } else {
        re.captures(text)
    };
    match_object(lua, text, start, end, caps.as_ref())
}

fn regex_findall(lua: &Lua, pattern: &str, text: &str, flags: i64) -> Result<Table, mlua::Error> {
    let re = regex_build(pattern, flags)?;
    let table = lua.create_table()?;
    let mut slot = 1;
    for caps in re.captures_iter(text) {
        if caps.len() <= 1 {
            table.set(
                slot,
                caps.get(0)
                    .map(|item| item.as_str().to_string())
                    .unwrap_or_default(),
            )?;
        } else if caps.len() == 2 {
            table.set(
                slot,
                caps.get(1)
                    .map(|item| item.as_str().to_string())
                    .unwrap_or_default(),
            )?;
        } else {
            let group = lua.create_table()?;
            for index in 1..caps.len() {
                group.set(
                    index,
                    caps.get(index)
                        .map(|item| item.as_str().to_string())
                        .unwrap_or_default(),
                )?;
            }
            table.set(slot, group)?;
        }
        slot += 1;
    }
    Ok(table)
}

fn regex_split(lua: &Lua, pattern: &str, text: &str, maxsplit: i64) -> Result<Table, mlua::Error> {
    let re = regex_build(pattern, 0)?;
    let table = lua.create_table()?;
    let mut last = 0;
    let mut slot = 1;
    let mut splits = 0i64;
    for item in re.find_iter(text) {
        if maxsplit > 0 && splits >= maxsplit {
            break;
        }
        table.set(slot, text[last..item.start()].to_string())?;
        slot += 1;
        last = item.end();
        splits += 1;
    }
    table.set(slot, text[last..].to_string())?;
    Ok(table)
}

fn regex_sub(lua: &Lua, args: mlua::MultiValue) -> Result<String, mlua::Error> {
    let args: Vec<Value> = args.into_iter().collect();
    if args.len() < 3 {
        return Err(mlua::Error::runtime(
            "re.sub expects pattern, replacement, and text",
        ));
    }
    let pattern = lua_text(&args[0])
        .ok_or_else(|| mlua::Error::runtime("re.sub pattern must be a string"))?;
    let text =
        lua_text(&args[2]).ok_or_else(|| mlua::Error::runtime("re.sub text must be a string"))?;
    let count = args.get(3).and_then(as_i64).unwrap_or(0);
    let re = regex_build(&pattern, 0)?;
    let mut out = String::new();
    let mut last = 0;
    let mut done = 0i64;
    for caps in re.captures_iter(&text) {
        if count > 0 && done >= count {
            break;
        }
        let whole = caps
            .get(0)
            .ok_or_else(|| mlua::Error::runtime("empty match"))?;
        out.push_str(&text[last..whole.start()]);
        let replacement = match &args[1] {
            Value::Function(function) => {
                let object = match_object(lua, &text, whole.start(), whole.end(), Some(&caps))?;
                function.call::<String>(object)?
            }
            other => {
                let template = lua_text(other).unwrap_or_default().replace('\\', "$");
                caps.expand(&template, &mut out);
                last = whole.end();
                done += 1;
                continue;
            }
        };
        out.push_str(&replacement);
        last = whole.end();
        done += 1;
    }
    out.push_str(&text[last..]);
    Ok(out)
}

fn match_object(
    lua: &Lua,
    text: &str,
    start: usize,
    end: usize,
    caps: Option<&regex::Captures<'_>>,
) -> Result<Value, mlua::Error> {
    let groups = lua.create_table()?;
    groups.set(0, text[start..end].to_string())?;
    if let Some(caps) = caps {
        for index in 1..caps.len() {
            if let Some(item) = caps.get(index) {
                groups.set(index, item.as_str().to_string())?;
            }
        }
    }
    let object = lua.create_table()?;
    object.set("_g", groups.clone())?;
    object.set(0, text[start..end].to_string())?;
    let group = lua.create_function(|_, args: mlua::MultiValue| {
        let mut args: Vec<Value> = args.into_iter().collect();
        let this = match args.first() {
            Some(Value::Table(table)) => table.clone(),
            _ => return Err(mlua::Error::runtime("match.group requires the match")),
        };
        if args.len() > 0 {
            args.remove(0);
        }
        let groups: Table = this.get("_g")?;
        let index = args.first().and_then(as_i64).unwrap_or(0);
        Ok(groups.get::<Value>(index)?)
    })?;
    let groups_fn = lua.create_function(|lua, this: Table| {
        let stored: Table = this.get("_g")?;
        let out = lua.create_table()?;
        let mut slot = 1;
        let mut index = 1i64;
        while stored.contains_key(index)? {
            out.set(slot, stored.get::<Value>(index)?)?;
            slot += 1;
            index += 1;
        }
        Ok(out)
    })?;
    object.set("group", group)?;
    object.set("groups", groups_fn)?;
    Ok(Value::Table(object))
}

enum Packed {
    Int(i64),
    Float(f64),
    Text(String),
}

fn struct_calcsize(fmt: &str) -> Result<i64, String> {
    Ok(struct_fields(fmt)?
        .into_iter()
        .map(|(_, width)| width as i64)
        .sum())
}

fn struct_fields(fmt: &str) -> Result<Vec<(char, usize)>, String> {
    let mut chars = fmt.chars().peekable();
    if matches!(chars.peek(), Some('@' | '=' | '<' | '>' | '!')) {
        chars.next();
    }
    let mut fields = Vec::new();
    while let Some(ch) = chars.next() {
        if ch.is_whitespace() {
            continue;
        }
        let mut count_text = String::new();
        let kind = if ch.is_ascii_digit() {
            count_text.push(ch);
            while matches!(chars.peek(), Some(c) if c.is_ascii_digit()) {
                count_text.push(chars.next().unwrap());
            }
            chars
                .next()
                .ok_or_else(|| "struct format ends with a repeat count".to_string())?
        } else {
            ch
        };
        let count: usize = if count_text.is_empty() {
            1
        } else {
            count_text
                .parse()
                .map_err(|_| "struct repeat count is invalid".to_string())?
        };
        if kind == 's' || kind == 'p' {
            fields.push((kind, count));
        } else {
            let width = field_width(kind)?;
            for _ in 0..count {
                fields.push((kind, width));
            }
        }
    }
    Ok(fields)
}

fn field_width(kind: char) -> Result<usize, String> {
    Ok(match kind {
        'x' | 'c' | 'b' | 'B' | '?' => 1,
        'h' | 'H' | 'e' => 2,
        'i' | 'I' | 'l' | 'L' | 'f' => 4,
        'q' | 'Q' | 'd' => 8,
        's' | 'p' => 1,
        other => return Err(format!("unsupported struct format '{other}'")),
    })
}

fn struct_pack(fmt: &str, values: &[Value]) -> Result<Vec<u8>, String> {
    let endian = endian_of(fmt);
    let fields = struct_fields(fmt)?;
    let mut out = Vec::new();
    let mut cursor = 0;
    for (kind, width) in fields {
        if kind == 'x' {
            out.push(0);
            continue;
        }
        let value = values.get(cursor).ok_or("struct.pack is missing a value")?;
        cursor += 1;
        match kind {
            'c' | 's' => out.extend(pack_string(value, width)?),
            'b' | 'B' => out.push(as_i64(value).unwrap_or(0) as u8),
            '?' => out.push(if truthy(value) { 1 } else { 0 }),
            'h' | 'H' => out.extend(pack_int(as_i64(value).unwrap_or(0) as u64, 2, endian)),
            'i' | 'I' | 'l' | 'L' => {
                out.extend(pack_int(as_i64(value).unwrap_or(0) as u64, 4, endian))
            }
            'q' | 'Q' => out.extend(pack_int(as_i64(value).unwrap_or(0) as u64, 8, endian)),
            'e' => out.extend(pack_int(
                f32_to_f16(as_f64(value).unwrap_or(0.0) as f32) as u64,
                2,
                endian,
            )),
            'f' => out.extend(pack_int(
                (as_f64(value).unwrap_or(0.0) as f32).to_bits() as u64,
                4,
                endian,
            )),
            'd' => out.extend(pack_int(as_f64(value).unwrap_or(0.0).to_bits(), 8, endian)),
            'p' => {
                let text = lua_text(value).unwrap_or_default();
                let room = width.saturating_sub(1);
                let len = text.len().min(room.min(255));
                out.push(len as u8);
                out.extend(text.as_bytes().iter().copied().take(len));
                out.resize(out.len() + room - len, 0);
            }
            _ => return Err(format!("unsupported struct format '{kind}'")),
        }
    }
    Ok(out)
}

fn struct_unpack(fmt: &str, data: &[u8]) -> Result<Vec<Packed>, String> {
    let endian = endian_of(fmt);
    let fields = struct_fields(fmt)?;
    let mut out = Vec::new();
    let mut cursor = 0;
    for (kind, width) in fields {
        if kind == 'x' {
            cursor += 1;
            continue;
        }
        if cursor + width > data.len() {
            return Err("struct.unpack buffer is too small".into());
        }
        let chunk = &data[cursor..cursor + width];
        cursor += width;
        let packed = match kind {
            'c' | 's' => Packed::Text(
                String::from_utf8_lossy(chunk)
                    .trim_end_matches('\0')
                    .to_string(),
            ),
            'b' => Packed::Int(chunk[0] as i8 as i64),
            'B' | '?' => Packed::Int(chunk[0] as i64),
            'h' => Packed::Int(unpack_int(chunk, endian) as u16 as i16 as i64),
            'H' => Packed::Int(unpack_int(chunk, endian) as u16 as i64),
            'i' | 'l' => Packed::Int(unpack_int(chunk, endian) as u32 as i32 as i64),
            'I' | 'L' => Packed::Int(unpack_int(chunk, endian) as u32 as i64),
            'q' | 'Q' => Packed::Int(unpack_int(chunk, endian) as i64),
            'e' => Packed::Float(f16_to_f32(unpack_int(chunk, endian) as u16) as f64),
            'f' => Packed::Float(f32::from_bits(unpack_int(chunk, endian) as u32) as f64),
            'd' => Packed::Float(f64::from_bits(unpack_int(chunk, endian))),
            'p' => {
                let len = chunk.first().copied().unwrap_or(0) as usize;
                Packed::Text(
                    String::from_utf8_lossy(&chunk[1..1 + len.min(chunk.len().saturating_sub(1))])
                        .to_string(),
                )
            }
            _ => return Err(format!("unsupported struct format '{kind}'")),
        };
        out.push(packed);
    }
    Ok(out)
}

fn endian_of(fmt: &str) -> bool {
    !matches!(fmt.chars().next(), Some('>' | '!'))
}

fn pack_int(value: u64, width: usize, little: bool) -> Vec<u8> {
    let mut bytes = value.to_le_bytes()[..width].to_vec();
    if !little {
        bytes.reverse();
    }
    bytes
}

fn unpack_int(bytes: &[u8], little: bool) -> u64 {
    let mut wide = [0u8; 8];
    if little {
        wide[..bytes.len()].copy_from_slice(bytes);
        u64::from_le_bytes(wide)
    } else {
        wide[8 - bytes.len()..].copy_from_slice(bytes);
        u64::from_be_bytes(wide)
    }
}

fn pack_string(value: &Value, len: usize) -> Result<Vec<u8>, String> {
    let text = lua_text(value).unwrap_or_default();
    let mut bytes = text.into_bytes();
    bytes.resize(len, 0);
    Ok(bytes)
}

fn rust_to_lua(lua: &Lua, value: Packed) -> Result<Value, mlua::Error> {
    Ok(match value {
        Packed::Int(value) => Value::Integer(value),
        Packed::Float(value) => Value::Number(value),
        Packed::Text(value) => Value::String(lua.create_string(&value)?),
    })
}

fn truthy(value: &Value) -> bool {
    match value {
        Value::Nil | Value::Boolean(false) => false,
        Value::Integer(0) => false,
        Value::String(text) => text.to_str().ok().is_some_and(|text| !text.is_empty()),
        _ => true,
    }
}

fn as_f64(value: &Value) -> Option<f64> {
    match value {
        Value::Integer(number) => Some(*number as f64),
        Value::Number(number) => Some(*number),
        Value::String(text) => text.to_str().ok().and_then(|text| text.parse().ok()),
        _ => None,
    }
}

fn f32_to_f16(value: f32) -> u16 {
    let bits = value.to_bits();
    let sign = ((bits >> 16) & 0x8000) as u16;
    let exp = ((bits >> 23) & 0xff) as i32;
    let frac = bits & 0x7fffff;
    if exp == 255 {
        return sign | 0x7c00 | if frac == 0 { 0 } else { 0x200 };
    }
    let exp = exp - 127 + 15;
    if exp >= 31 {
        return sign | 0x7c00;
    }
    if exp <= 0 {
        if exp < -10 {
            return sign;
        }
        let mut frac = frac | 0x800000;
        let shift = 1 - exp;
        frac >>= shift;
        return sign | ((frac >> 13) as u16);
    }
    sign | ((exp as u16) << 10) | ((frac >> 13) as u16)
}

fn f16_to_f32(value: u16) -> f32 {
    let sign = ((value & 0x8000) as u32) << 16;
    let exp = ((value >> 10) & 0x1f) as i32;
    let frac = (value & 0x3ff) as u32;
    let bits = if exp == 0 {
        if frac == 0 {
            sign
        } else {
            let mut exp = 127 - 15 + 1;
            let mut frac = frac;
            while frac & 0x400 == 0 {
                frac <<= 1;
                exp -= 1;
            }
            sign | ((exp as u32) << 23) | ((frac & 0x3ff) << 13)
        }
    } else if exp == 31 {
        sign | 0x7f800000 | (frac << 13)
    } else {
        sign | (((exp + 127 - 15) as u32) << 23) | (frac << 13)
    };
    f32::from_bits(bits)
}

fn crc32_ieee(data: &[u8]) -> i64 {
    let mut crc = 0xffff_ffffu32;
    for byte in data {
        crc ^= *byte as u32;
        for _ in 0..8 {
            let mask = (crc & 1).wrapping_neg();
            crc = (crc >> 1) ^ (0xedb8_8320 & mask);
        }
    }
    (!crc) as i64
}

fn crc_hqx(data: &[u8], mut crc: u16) -> u16 {
    for byte in data {
        crc ^= (*byte as u16) << 8;
        for _ in 0..8 {
            if crc & 0x8000 != 0 {
                crc = (crc << 1) ^ 0x1021;
            } else {
                crc <<= 1;
            }
        }
    }
    crc
}

fn bytes_of(value: &Value) -> Result<Vec<u8>, mlua::Error> {
    match value {
        Value::String(text) => Ok(text.as_bytes().to_vec()),
        Value::Table(table) => {
            let mut bytes = Vec::new();
            for item in table.sequence_values::<Value>() {
                let byte = as_i64(&item?)
                    .ok_or_else(|| mlua::Error::runtime("byte must be an integer"))?;
                bytes.push(byte as u8);
            }
            Ok(bytes)
        }
        Value::Integer(number) => Ok(vec![*number as u8]),
        _ => Err(mlua::Error::runtime("expected bytes")),
    }
}

fn lua_text(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => text.to_str().ok().map(|text| text.to_string()),
        Value::Integer(number) => Some(number.to_string()),
        Value::Number(number) if number.fract() == 0.0 && number.is_finite() => {
            Some((*number as i64).to_string())
        }
        Value::Number(number) if number.is_finite() => Some(number.to_string()),
        _ => None,
    }
}

fn as_i64(value: &Value) -> Option<i64> {
    match value {
        Value::Integer(number) => Some(*number),
        Value::Number(number) if number.fract() == 0.0 && number.is_finite() => {
            Some(*number as i64)
        }
        Value::String(text) => text.to_str().ok().and_then(|text| text.parse().ok()),
        _ => None,
    }
}

fn lua_err(err: mlua::Error) -> DecodeError {
    DecodeError::Message(err.to_string())
}
