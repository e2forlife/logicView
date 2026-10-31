-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Steve R <steversig@virginmedia.com>

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
local bcd2int, Decoder
local _decoder

bcd2int = logicview.bcd2int
_decoder = {
  api_version = 3,
  id = "ook_vis",
  name = "OOK visualisation",
  longname = "On-off keying visualisation",
  desc = "OOK visualisation in various formats.",
  license = "gplv2+",
  inputs = { "ook" },
  outputs = { "ook" },
  tags = { "Encoding" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "displayas", desc = "Display as", default = "Nibble - Hex", values = { "Byte - Hex", "Byte - Hex rev", "Byte - BCD", "Byte - BCD rev", "Nibble - Hex", "Nibble - Hex rev", "Nibble - BCD", "Nibble - BCD rev" } }), logicview.dict({ id = "synclen", desc = "Sync length", default = "4", values = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" } }), logicview.dict({ id = "syncoffset", desc = "Sync offset", default = "0", values = { "-4", "-3", "-2", "-1", "0", "1", "2", "3", "4" } }), logicview.dict({ id = "refsample", desc = "Compare", default = "off", values = { "off", "show numbers", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30" } }) },
  annotations = { { "bit", "Bit" }, { "ref", "Reference" }, { "field", "Field" }, { "ref_field", "Ref field" }, { "level2", "L2" }, { "ref_level2", "Ref L2" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "compare", "Compare", { 1 } }, { "fields", "Fields", { 2 } }, { "ref_fields", "Ref fields", { 3 } }, { "level2", "L2", { 4 } }, { "ref_level2", "Ref L2", { 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.decoded = {  }
  self.ookstring = ""
  self.ookcache = {  }
  self.trace_num = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.displayas = logicview.idx(self.options, "displayas")
  self.sync_length = logicview.idx(self.options, "synclen")
  self.sync_offset = logicview.idx(self.options, "syncoffset")
  self.ref = logicview.idx(self.options, "refsample")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putp(self, data)
  self:put(self.ss, self.es, self.out_python, data)
end
function _decoder.display_level2(self, bits, line)
  local ook, preamble_end, char_first, char_second, preamble, char_last, i, ookstring, rem_nibbles
  self.decode_pos = 0
  ook = self.decoded
  if logicview.truth((logicview.len(ook) > 1)) then
    preamble_end = logicview.add(logicview.len(ook), 1)
    char_first = logicview.idx(logicview.idx(ook, 0), 2)
    char_second = logicview.idx(logicview.idx(ook, 1), 2)
    if logicview.truth(logicview.eq(char_first, char_second)) then
      preamble = "1111"
      char_last = char_first
    else
      preamble = "1010"
      char_last = char_second
    end
    for _lv_i in logicview.range(logicview.len(ook)) do
      i = _lv_i
      if logicview.truth(logicview.eq(preamble, "1111")) then
        if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(ook, i), 2), char_last))) then
          preamble_end = i
          break
        else
          char_last = logicview.idx(logicview.idx(ook, i), 2)
        end
      elseif logicview.truth((not logicview.eq(logicview.idx(logicview.idx(ook, i), 2), char_last))) then
        char_last = logicview.idx(logicview.idx(ook, i), 2)
      else
        preamble_end = i
        break
      end
      ::continue_1::
    end
    if logicview.truth((logicview.len(ook) >= preamble_end)) then
      preamble_end = logicview.add(preamble_end, (logicview.tointeger(self.sync_offset) - 1))
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, preamble_end), 1)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putx({ line, { "Preamble", "Pre", "P" } })
      self.decode_pos = logicview.add(self.decode_pos, preamble_end)
      if logicview.truth((logicview.len(ook) > logicview.add(self.decode_pos, logicview.tointeger(self.sync_length)))) then
        self.ss = self.es
        self.es = logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, logicview.tointeger(self.sync_length))), 1)
        self:putx({ line, { "Sync", "Syn", "S" } })
        self.decode_pos = logicview.add(self.decode_pos, logicview.add(logicview.tointeger(self.sync_length), 1))
      end
      ookstring = logicview.slice(self.ookstring, self.decode_pos, nil, nil)
      rem_nibbles = logicview.floordiv(logicview.len(ookstring), bits)
      for _lv_i in logicview.range(rem_nibbles) do
        i = _lv_i
        self.ss = logicview.idx(logicview.idx(ook, self.decode_pos), 0)
        self.es = logicview.idx(logicview.idx(ook, (logicview.add(self.decode_pos, bits) - 1)), 1)
        self:put_field(bits, line)
        ::continue_2::
      end
    end
  end
end
function _decoder.put_field(self, numbits, line)
  local param
  param = logicview.slice(self.ookstring, self.decode_pos, logicview.add(self.decode_pos, numbits), nil)
  if logicview.truth(logicview.contains(self.displayas, "rev")) then
    param = logicview.slice(param, nil, nil, (-1))
  end
  if logicview.truth((not logicview.truth(logicview.contains(param, "E")))) then
    if logicview.truth(logicview.contains(self.displayas, "Hex")) then
      param = logicview.slice(logicview.hex(logicview.tointeger(param, 2)), 2, nil, nil)
    elseif logicview.truth(logicview.contains(self.displayas, "BCD")) then
      param = bcd2int(logicview.tointeger(param, 2))
    end
  end
  self:putx({ line, { _tostring(param) } })
  self.decode_pos = logicview.add(self.decode_pos, numbits)
end
function _decoder.display_all(self)
  local ookstring, ook, i, bits, rem_nibbles, ref, end_sig
  ookstring = ""
  self.decode_pos = 0
  ook = self.decoded
  for _lv_i in logicview.range(logicview.len(ook)) do
    i = _lv_i
    self.ookstring = logicview.add(self.ookstring, logicview.idx(logicview.idx(ook, i), 2))
    ::continue_3::
  end
  bits = (function() if logicview.truth(logicview.contains(self.displayas, "Nibble")) then return 4 else return 8 end end)()
  rem_nibbles = logicview.floordiv(logicview.len(self.ookstring), bits)
  for _lv_i in logicview.range(rem_nibbles) do
    i = _lv_i
    self.ss = logicview.idx(logicview.idx(ook, self.decode_pos), 0)
    self.es = logicview.idx(logicview.idx(ook, (logicview.add(self.decode_pos, bits) - 1)), 1)
    self:put_field(bits, 2)
    ::continue_4::
  end
  self:display_level2(bits, 4)
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.ref, "off"))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.ref, "show numbers"))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.ookcache) >= logicview.tointeger(self.ref))
  return _v
end)()) then
    ref = (logicview.tointeger(self.ref) - 1)
    self:display_ref(self.trace_num, ref)
    if logicview.truth(logicview.eq(logicview.len(self.ookcache), logicview.tointeger(self.ref))) then
      for _lv_i in logicview.range(0, ref) do
        i = _lv_i
        self:display_ref(i, ref)
        ::continue_5::
      end
    end
  elseif logicview.truth(logicview.eq(self.ref, "show numbers")) then
    self.ss = logicview.idx(logicview.idx(logicview.idx(self.ookcache, self.trace_num), 0), 0)
    end_sig = (logicview.len(logicview.idx(self.ookcache, self.trace_num)) - 1)
    self.es = logicview.idx(logicview.idx(logicview.idx(self.ookcache, self.trace_num), end_sig), 1)
    self:putx({ 1, { _tostring(logicview.add(self.trace_num, 1)) } })
  end
end
function _decoder.display_ref(self, t_num, ref)
  local display_len, i
  display_len = logicview.len(logicview.idx(self.ookcache, ref))
  if logicview.truth((logicview.len(logicview.idx(self.ookcache, t_num)) < logicview.len(logicview.idx(self.ookcache, ref)))) then
    display_len = logicview.len(logicview.idx(self.ookcache, t_num))
  end
  for _lv_i in logicview.range(display_len) do
    i = _lv_i
    self.ss = logicview.idx(logicview.idx(logicview.idx(self.ookcache, t_num), i), 0)
    self.es = logicview.idx(logicview.idx(logicview.idx(self.ookcache, t_num), i), 1)
    self:putx({ 1, { logicview.idx(logicview.idx(logicview.idx(self.ookcache, ref), i), 2) } })
    ::continue_6::
  end
end
function _decoder.add_to_cache(self)
  _table.insert(self.ookcache, self.decoded)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    self.decoded = data
    self:add_to_cache()
    self:display_all()
    self.ookstring = ""
    self.trace_num = logicview.add(self.trace_num, 1)
    self.ss = ss
    self.es = es
    self:putp(data)
  end
  if _type(packets) ~= 'table' then return _lv_packet(self, start_sample, end_sample, packets) end
  for _, _item in ipairs(packets) do
    local payload = _item.data
    if payload == nil then payload = _item end
    local ss = _item.start_sample or start_sample
    local es = _item.end_sample
    if es ~= nil then es = es - 1 end
    _lv_packet(self, ss, es, payload)
  end
end

return _decoder
