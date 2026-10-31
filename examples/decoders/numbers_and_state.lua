-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Comlab AG
-- Copyright (C) 2020 Gerhard Sittig <gerhard.sittig@gmx.net>

local _type = type
local _error = error
local _pcall = pcall
local _tostring = tostring
local _tonumber = tonumber
local _string = string
local _table = table
local _math = math
local _pairs = pairs
local _setmetatable = setmetatable
local _select = select
local _rawequal = rawequal
local _coroutine = coroutine
local bitpack, json, struct, _max_channels, _max_enum_slots, ChannelError, Pin, Ann, _channel_decl, _enum_cls_decl, _enum_rows_decl, Decoder
local _decoder

bitpack = logicview.bitpack
json = logicview.json
struct = logicview.struct
_max_channels = 16
_max_enum_slots = 32
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
Pin = {}
Pin.__index = Pin
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pin.CLK = logicview.idx(_lv_seq, 0)
  Pin.BIT_0 = logicview.idx(_lv_seq, 1)
end
Pin.BIT_N = logicview.add(Pin.BIT_0, _max_channels)
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.RAW = logicview.idx(_lv_seq, 0)
  Ann.NUM = logicview.idx(_lv_seq, 1)
end
Ann.ENUM_0 = logicview.add(Ann.NUM, 1)
Ann.ENUM_OVR = logicview.add(Ann.ENUM_0, _max_enum_slots)
Ann.ENUMS = (function() local _t = {}; for _v in logicview.range(Ann.ENUM_0, Ann.ENUM_OVR) do _t[#_t + 1] = _v end; return _t end)()
Ann.WARN = logicview.add(Ann.ENUM_OVR, 1)
function Ann.enum_indices()
  return (function()
  local _lv_out = {}
  for _lv_i in logicview.range(Ann.ENUMS) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = i
  end
  return _lv_out
end)()
end
function Ann.get_enum_idx(code)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(_max_enum_slots) do _t[#_t + 1] = _v end; return _t end)(), code)) then
    return logicview.add(Ann.ENUM_0, code)
  end
  return Ann.ENUM_OVR
end
function Ann.new(...)
  local self = _setmetatable({}, Ann)
  return self
end
_channel_decl = function(count)
  return logicview.copy((function()
  local _lv_out = {}
  for _lv_i in logicview.range(count) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.dict({ id = logicview.pyformat("bit{}", { i }, logicview.dict({})), name = logicview.pyformat("Bit{}", { i }, logicview.dict({})), desc = logicview.pyformat("Bit position {}", { i }, logicview.dict({})) })
  end
  return _lv_out
end)())
end
_enum_cls_decl = function(count)
  return logicview.copy(logicview.add((function()
  local _lv_out = {}
  for _lv_i in logicview.range(count) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = { logicview.pyformat("enum{}", { i }, logicview.dict({})), logicview.pyformat("Enumeration slot {}", { i }, logicview.dict({})) }
  end
  return _lv_out
end)(), { { "enumovr", "Enumeration overflow" } }))
end
_enum_rows_decl = function(count)
  return logicview.copy(logicview.add((function()
  local _lv_out = {}
  for _lv_i in logicview.range(count) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = { logicview.pyformat("enums{}", { i }, logicview.dict({})), logicview.pyformat("Enumeration slots {}", { i }, logicview.dict({})), { logicview.add(Ann.ENUM_0, i) } }
  end
  return _lv_out
end)(), { { "enumsovr", "Enumeration overflows", { Ann.ENUM_OVR } } }))
end
_decoder = {
  api_version = 3,
  id = "numbers_and_state",
  name = "Numbers and State",
  longname = "Interpret bit patters as numbers or state enums",
  desc = "Interpret bit patterns as different kinds of numbers (integer, float, enum).",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "numbers_and_state" },
  tags = { "Encoding", "Util" },
  channels = {  },
  optional_channels = { logicview.dict({ id = "clk", name = "Clock", desc = "Clock" }), logicview.dict({ id = "bit0", name = "Bit0", desc = "Bit position 0" }), logicview.dict({ id = "bit1", name = "Bit1", desc = "Bit position 1" }), logicview.dict({ id = "bit2", name = "Bit2", desc = "Bit position 2" }), logicview.dict({ id = "bit3", name = "Bit3", desc = "Bit position 3" }), logicview.dict({ id = "bit4", name = "Bit4", desc = "Bit position 4" }), logicview.dict({ id = "bit5", name = "Bit5", desc = "Bit position 5" }), logicview.dict({ id = "bit6", name = "Bit6", desc = "Bit position 6" }), logicview.dict({ id = "bit7", name = "Bit7", desc = "Bit position 7" }), logicview.dict({ id = "bit8", name = "Bit8", desc = "Bit position 8" }), logicview.dict({ id = "bit9", name = "Bit9", desc = "Bit position 9" }), logicview.dict({ id = "bit10", name = "Bit10", desc = "Bit position 10" }), logicview.dict({ id = "bit11", name = "Bit11", desc = "Bit position 11" }), logicview.dict({ id = "bit12", name = "Bit12", desc = "Bit position 12" }), logicview.dict({ id = "bit13", name = "Bit13", desc = "Bit position 13" }), logicview.dict({ id = "bit14", name = "Bit14", desc = "Bit position 14" }), logicview.dict({ id = "bit15", name = "Bit15", desc = "Bit position 15" }) },
  options = { logicview.dict({ id = "clkedge", desc = "Clock edge", default = "rising", values = { "rising", "falling", "either" } }), logicview.dict({ id = "count", desc = "Total bits count", default = 1, values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128 } }), logicview.dict({ id = "interp", desc = "Interpretation", default = "unsigned", values = { "unsigned", "signed", "fixpoint", "fixsigned", "ieee754", "enum" } }), logicview.dict({ id = "fracbits", desc = "Fraction bits count", default = 0, values = {  } }), logicview.dict({ id = "mapping", desc = "Enum to text map file", default = "enumtext.json", values = {  } }), logicview.dict({ id = "format", desc = "Number format", default = "-", values = { "-", "bin", "oct", "dec", "hex" } }) },
  annotations = { { "raw", "Raw pattern" }, { "number", "Number" }, { "enum0", "Enumeration slot 0" }, { "enum1", "Enumeration slot 1" }, { "enum2", "Enumeration slot 2" }, { "enum3", "Enumeration slot 3" }, { "enum4", "Enumeration slot 4" }, { "enum5", "Enumeration slot 5" }, { "enum6", "Enumeration slot 6" }, { "enum7", "Enumeration slot 7" }, { "enum8", "Enumeration slot 8" }, { "enum9", "Enumeration slot 9" }, { "enum10", "Enumeration slot 10" }, { "enum11", "Enumeration slot 11" }, { "enum12", "Enumeration slot 12" }, { "enum13", "Enumeration slot 13" }, { "enum14", "Enumeration slot 14" }, { "enum15", "Enumeration slot 15" }, { "enum16", "Enumeration slot 16" }, { "enum17", "Enumeration slot 17" }, { "enum18", "Enumeration slot 18" }, { "enum19", "Enumeration slot 19" }, { "enum20", "Enumeration slot 20" }, { "enum21", "Enumeration slot 21" }, { "enum22", "Enumeration slot 22" }, { "enum23", "Enumeration slot 23" }, { "enum24", "Enumeration slot 24" }, { "enum25", "Enumeration slot 25" }, { "enum26", "Enumeration slot 26" }, { "enum27", "Enumeration slot 27" }, { "enum28", "Enumeration slot 28" }, { "enum29", "Enumeration slot 29" }, { "enum30", "Enumeration slot 30" }, { "enum31", "Enumeration slot 31" }, { "enumovr", "Enumeration overflow" }, { "warning", "Warning" } },
  annotation_rows = { { "raws", "Raw bits", { 0 } }, { "numbers", "Numbers", { 1 } }, { "enums0", "Enumeration slots 0", { 2 } }, { "enums1", "Enumeration slots 1", { 3 } }, { "enums2", "Enumeration slots 2", { 4 } }, { "enums3", "Enumeration slots 3", { 5 } }, { "enums4", "Enumeration slots 4", { 6 } }, { "enums5", "Enumeration slots 5", { 7 } }, { "enums6", "Enumeration slots 6", { 8 } }, { "enums7", "Enumeration slots 7", { 9 } }, { "enums8", "Enumeration slots 8", { 10 } }, { "enums9", "Enumeration slots 9", { 11 } }, { "enums10", "Enumeration slots 10", { 12 } }, { "enums11", "Enumeration slots 11", { 13 } }, { "enums12", "Enumeration slots 12", { 14 } }, { "enums13", "Enumeration slots 13", { 15 } }, { "enums14", "Enumeration slots 14", { 16 } }, { "enums15", "Enumeration slots 15", { 17 } }, { "enums16", "Enumeration slots 16", { 18 } }, { "enums17", "Enumeration slots 17", { 19 } }, { "enums18", "Enumeration slots 18", { 20 } }, { "enums19", "Enumeration slots 19", { 21 } }, { "enums20", "Enumeration slots 20", { 22 } }, { "enums21", "Enumeration slots 21", { 23 } }, { "enums22", "Enumeration slots 22", { 24 } }, { "enums23", "Enumeration slots 23", { 25 } }, { "enums24", "Enumeration slots 24", { 26 } }, { "enums25", "Enumeration slots 25", { 27 } }, { "enums26", "Enumeration slots 26", { 28 } }, { "enums27", "Enumeration slots 27", { 29 } }, { "enums28", "Enumeration slots 28", { 30 } }, { "enums29", "Enumeration slots 29", { 31 } }, { "enums30", "Enumeration slots 30", { 32 } }, { "enums31", "Enumeration slots 31", { 33 } }, { "enumsovr", "Enumeration overflows", { 34 } }, { "warnings", "Warnings", { 35 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.putg(self, ss, es, cls, data)
  self:put(ss, es, self.out_ann, { cls, data })
end
function _decoder.putpy(self, ss, es, ptype, pdata)
  self:put(ss, es, self.out_python, { ptype, pdata })
end
function _decoder.grab_pattern(self, pins)
  local bits, pattern
  bits = logicview.add(pins, logicview.mul({ nil }, self.bitcount))
  bits = logicview.slice(bits, nil, self.bitcount, nil)
  bits = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(bits) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = (function() if logicview.truth(logicview.contains({ 0, 1 }, b)) then return b else return 0 end end)()
  end
  return _lv_out
end)()
  pattern = bitpack(bits)
  return pattern
end
function _decoder.handle_pattern(self, ss, es, pattern)
  local fmt, txt, value, formatted, cls
  fmt = logicview.pyformat("{{:0{}b}}", { self.bitcount }, logicview.dict({}))
  txt = logicview.pyformat(fmt, { pattern }, logicview.dict({}))
  self:putg(ss, es, Ann.RAW, { txt })
  self:putpy(ss, es, "RAW", { self.bitcount, pattern })
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      value = self:interpreter(ss, es, pattern)
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if true then
        value = nil
      end
    end
  end
  if logicview.truth((value == nil)) then
    return
  end
  self:putpy(ss, es, "NUMBER", value)
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      formatted = self:formatter(ss, es, value)
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if true then
        formatted = nil
      end
    end
  end
  if logicview.truth(formatted) then
    self:putg(ss, es, Ann.NUM, formatted)
    if logicview.truth(logicview.eq(self.interpreter, self.interp_enum)) then
      cls = Ann.get_enum_idx(pattern)
      self:putg(ss, es, cls, formatted)
      self:putpy(ss, es, "ENUM", { value, formatted })
    end
  end
end
function _decoder.interp_unsigned(self, ss, es, pattern)
  local value
  value = pattern
  return value
end
function _decoder.interp_signed(self, ss, es, pattern)
  local is_neg, value
  if logicview.truth((not logicview.truth(logicview.contains(self.interp_state, "signmask")))) then
    logicview.dict_update(self.interp_state, logicview.dict({ signmask = (1 << (self.bitcount - 1)), signfull = (1 << self.bitcount) }))
  end
  is_neg = (pattern & logicview.idx(self.interp_state, "signmask"))
  if logicview.truth(is_neg) then
    value = (-(logicview.idx(self.interp_state, "signfull") - pattern))
  else
    value = pattern
  end
  return value
end
function _decoder.interp_fixpoint(self, ss, es, pattern)
  local value
  if logicview.truth((not logicview.truth(logicview.contains(self.interp_state, "fixdiv")))) then
    logicview.dict_update(self.interp_state, logicview.dict({ fixsign = logicview.eq(logicview.idx(self.options, "interp"), "fixsigned"), fixdiv = (2 ^ logicview.idx(self.options, "fracbits")) }))
  end
  if logicview.truth(logicview.idx(self.interp_state, "fixsign")) then
    value = self:interp_signed(ss, es, pattern)
  else
    value = self:interp_unsigned(ss, es, pattern)
  end
  value = (value / logicview.idx(self.interp_state, "fixdiv"))
  return value
end
function _decoder.interp_ieee754(self, ss, es, pattern)
  local fmt, has_16bit_support, buff, value
  if logicview.truth((not logicview.truth(logicview.contains(self.interp_state, "ieee_has_16bit")))) then
    logicview.dict_update(self.interp_state, logicview.dict({ ieee_fmt_int_16 = "=H", ieee_fmt_flt_16 = "=e", ieee_fmt_int_32 = "=L", ieee_fmt_flt_32 = "=f", ieee_fmt_int_64 = "=Q", ieee_fmt_flt_64 = "=d" }))
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        fmt = logicview.idx(self.interp_state.update, "ieee_fmt_flt_16")
        has_16bit_support = logicview.eq(logicview.mul(8, struct.calcsize(fmt)), 16)
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if true then
          has_16bit_support = false
        end
      end
    end
    logicview.setidx(self.interp_state, "ieee_has_16bit", has_16bit_support)
  end
  if logicview.truth(logicview.eq(self.bitcount, 16)) then
    if logicview.truth((not logicview.truth(logicview.idx(self.interp_state, "ieee_has_16bit")))) then
      return nil
    end
    buff = struct.pack(logicview.idx(self.interp_state, "ieee_fmt_int_16"), pattern)
    do
      local _lv_seq = struct.unpack(logicview.idx(self.interp_state, "ieee_fmt_flt_16"), buff)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      value = logicview.idx(_lv_seq, 0)
    end
    return value
  end
  if logicview.truth(logicview.eq(self.bitcount, 32)) then
    buff = struct.pack(logicview.idx(self.interp_state, "ieee_fmt_int_32"), pattern)
    do
      local _lv_seq = struct.unpack(logicview.idx(self.interp_state, "ieee_fmt_flt_32"), buff)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      value = logicview.idx(_lv_seq, 0)
    end
    return value
  end
  if logicview.truth(logicview.eq(self.bitcount, 64)) then
    buff = struct.pack(logicview.idx(self.interp_state, "ieee_fmt_int_64"), pattern)
    do
      local _lv_seq = struct.unpack(logicview.idx(self.interp_state, "ieee_fmt_flt_64"), buff)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      value = logicview.idx(_lv_seq, 0)
    end
    return value
  end
  return nil
end
function _decoder.interp_enum(self, ss, es, pattern)
  local fn, f, maptext, maptable, js_table, k, v, py_table, value
  if logicview.truth((not logicview.truth(logicview.contains(self.interp_state, "enum_map")))) then
    logicview.dict_update(self.interp_state, logicview.dict({ enum_fn = logicview.idx(self.options, "mapping"), enum_map = logicview.dict({  }), enum_have_map = false }))
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        fn = logicview.idx(self.interp_state, "enum_fn")
        _error('file access is not available')
        maptable = logicview.dict({  })
        if logicview.truth((function()
  local _v
  _v = logicview.endswith(fn, ".js")
  if logicview.truth(_v) then return _v end
  _v = logicview.endswith(fn, ".json")
  return _v
end)()) then
          js_table = json.loads(maptext)
          for _lv_k, _lv_v in _pairs(js_table) do
            k = _lv_k
            v = _lv_v
            logicview.setidx(maptable, v, k)
            ::continue_1::
          end
        elseif logicview.truth(logicview.endswith(fn, ".py")) then
          py_table = logicview.dict({  })
          _error('exec is not available')
          logicview.dict_update(maptable, logicview.idx(py_table, "enumtext"))
        end
        logicview.dict_update(logicview.idx(self.interp_state, "enum_map"), maptable)
        logicview.setidx(self.interp_state, "enum_have_map", true)
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if true then
        end
      end
    end
  end
  value = logicview.dget(logicview.idx(self.interp_state, "enum_map"), pattern, nil)
  if logicview.truth((value == nil)) then
    value = pattern
  end
  return value
end
function _decoder.format_native(self, ss, es, value)
  return { logicview.pyformat("{}", { value }, logicview.dict({})) }
end
function _decoder.format_bin(self, ss, es, value)
  if logicview.truth((not logicview.truth(self.format_string))) then
    self.format_string = logicview.pyformat("{{:0{}b}}", { self.bitcount }, logicview.dict({}))
  end
  return { logicview.pyformat(self.format_string, { value }, logicview.dict({})) }
end
function _decoder.format_oct(self, ss, es, value)
  if logicview.truth((not logicview.truth(self.format_string))) then
    self.format_string = logicview.pyformat("{{:0{}o}}", { logicview.floordiv((logicview.add(self.bitcount, 3) - 1), 3) }, logicview.dict({}))
  end
  return { logicview.pyformat(self.format_string, { value }, logicview.dict({})) }
end
function _decoder.format_dec(self, ss, es, value)
  if logicview.truth((not logicview.truth(self.format_string))) then
    self.format_string = "{:d}"
  end
  return { logicview.pyformat(self.format_string, { value }, logicview.dict({})) }
end
function _decoder.format_hex(self, ss, es, value)
  if logicview.truth((not logicview.truth(self.format_string))) then
    self.format_string = logicview.pyformat("{{:0{}x}}", { logicview.floordiv((logicview.add(self.bitcount, 4) - 1), 4) }, logicview.dict({}))
  end
  return { logicview.pyformat(self.format_string, { value }, logicview.dict({})) }
end
function _decoder.decode(self)
  local channels, ch, have_clk, clk, clkedge, wait_cond, bitcount, interpreter, formatter, bFirst, cur_cond, d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, pins, ss, prev_pattern, es, pattern
  channels = {  }
  for _lv_i in logicview.range(1, logicview.add(_max_channels, 1)) do
    ch = _lv_i
    if logicview.truth(self:has_channel(ch)) then
      _table.insert(channels, ch)
    end
    ::continue_2::
  end
  have_clk = logicview.contains(channels, Pin.CLK)
  if logicview.truth(have_clk) then
    (function() local _i = logicview.list_index(channels, Pin.CLK); _table.remove(channels, _i + 1) end)()
  end
  if logicview.truth((not logicview.truth(channels))) then
    _error(ChannelError("Need at least one bit channel."), 0)
  end
  if logicview.truth(have_clk) then
    clk = logicview.dict({ rising = "r", falling = "f", either = "e" })
    clkedge = logicview.dget(clk, logicview.idx(self.options, "clkedge"), nil)
    wait_cond = logicview.dict({ [Pin.CLK] = clkedge })
  else
    wait_cond = {  }
    for _lv_item in logicview.iter(channels) do
      ch = _lv_item
      _table.insert(wait_cond, logicview.dict({ [ch] = "e" }))
      ::continue_3::
    end
  end
  bitcount = logicview.idx(self.options, "count")
  if logicview.truth((not logicview.truth(bitcount))) then
    bitcount = logicview.len(channels)
  end
  self.bitcount = bitcount
  interpreter = logicview.dict({ unsigned = self.interp_unsigned, signed = self.interp_signed, fixpoint = self.interp_fixpoint, fixsigned = self.interp_fixpoint, ieee754 = self.interp_ieee754, enum = self.interp_enum })
  self.interpreter = logicview.dget(interpreter, logicview.idx(self.options, "interp"), nil)
  self.interp_state = logicview.dict({  })
  formatter = logicview.dict({ ["-"] = self.format_native, bin = self.format_bin, oct = self.format_oct, dec = self.format_dec, hex = self.format_hex })
  self.formatter = logicview.dget(formatter, logicview.idx(self.options, "format"), nil)
  self.format_string = nil
  bFirst = true
  cur_cond = nil
  while true do
    do
      local _lv_seq = self:wait(cur_cond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      d0 = logicview.idx(_lv_seq, 1)
      d1 = logicview.idx(_lv_seq, 2)
      d2 = logicview.idx(_lv_seq, 3)
      d3 = logicview.idx(_lv_seq, 4)
      d4 = logicview.idx(_lv_seq, 5)
      d5 = logicview.idx(_lv_seq, 6)
      d6 = logicview.idx(_lv_seq, 7)
      d7 = logicview.idx(_lv_seq, 8)
      d8 = logicview.idx(_lv_seq, 9)
      d9 = logicview.idx(_lv_seq, 10)
      d10 = logicview.idx(_lv_seq, 11)
      d11 = logicview.idx(_lv_seq, 12)
      d12 = logicview.idx(_lv_seq, 13)
      d13 = logicview.idx(_lv_seq, 14)
      d14 = logicview.idx(_lv_seq, 15)
      d15 = logicview.idx(_lv_seq, 16)
    end
    pins = { clk, d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15 }
    if logicview.truth(bFirst) then
      bFirst = false
      ss = self.samplenum
      prev_pattern = self:grab_pattern(logicview.slice(pins, Pin.BIT_0, nil, nil))
      cur_cond = wait_cond
      goto continue_4
    end
    es = self.samplenum
    pattern = self:grab_pattern(logicview.slice(pins, Pin.BIT_0, nil, nil))
    if logicview.truth(logicview.eq(pattern, prev_pattern)) then
      goto continue_4
    end
    self:handle_pattern(ss, es, prev_pattern)
    ss = es
    prev_pattern = pattern
    ::continue_4::
  end
end

return _decoder
