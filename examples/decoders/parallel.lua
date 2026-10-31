-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2013-2016 Uwe Hermann <uwe@hermann-uwe.de>

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
local bitpack, channel_list, ChannelError, NUM_CHANNELS, Decoder
local _decoder

bitpack = logicview.bitpack
channel_list = function(num_channels)
  local l, i, d
  l = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock line" }) }
  for _lv_i in logicview.range(num_channels) do
    i = _lv_i
    d = logicview.dict({ id = logicview.pymod("d%d", i), name = logicview.pymod("D%d", i), desc = logicview.pymod("Data line %d", i) })
    _table.insert(l, d)
    ::continue_1::
  end
  return logicview.copy(l)
end
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
NUM_CHANNELS = 32
_decoder = {
  api_version = 3,
  id = "parallel",
  name = "Parallel",
  longname = "Parallel sync bus",
  desc = "Generic parallel synchronous bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "parallel" },
  tags = { "Util" },
  channels = {  },
  optional_channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock line" }), logicview.dict({ id = "d0", name = "D0", desc = "Data line 0" }), logicview.dict({ id = "d1", name = "D1", desc = "Data line 1" }), logicview.dict({ id = "d2", name = "D2", desc = "Data line 2" }), logicview.dict({ id = "d3", name = "D3", desc = "Data line 3" }), logicview.dict({ id = "d4", name = "D4", desc = "Data line 4" }), logicview.dict({ id = "d5", name = "D5", desc = "Data line 5" }), logicview.dict({ id = "d6", name = "D6", desc = "Data line 6" }), logicview.dict({ id = "d7", name = "D7", desc = "Data line 7" }), logicview.dict({ id = "d8", name = "D8", desc = "Data line 8" }), logicview.dict({ id = "d9", name = "D9", desc = "Data line 9" }), logicview.dict({ id = "d10", name = "D10", desc = "Data line 10" }), logicview.dict({ id = "d11", name = "D11", desc = "Data line 11" }), logicview.dict({ id = "d12", name = "D12", desc = "Data line 12" }), logicview.dict({ id = "d13", name = "D13", desc = "Data line 13" }), logicview.dict({ id = "d14", name = "D14", desc = "Data line 14" }), logicview.dict({ id = "d15", name = "D15", desc = "Data line 15" }), logicview.dict({ id = "d16", name = "D16", desc = "Data line 16" }), logicview.dict({ id = "d17", name = "D17", desc = "Data line 17" }), logicview.dict({ id = "d18", name = "D18", desc = "Data line 18" }), logicview.dict({ id = "d19", name = "D19", desc = "Data line 19" }), logicview.dict({ id = "d20", name = "D20", desc = "Data line 20" }), logicview.dict({ id = "d21", name = "D21", desc = "Data line 21" }), logicview.dict({ id = "d22", name = "D22", desc = "Data line 22" }), logicview.dict({ id = "d23", name = "D23", desc = "Data line 23" }), logicview.dict({ id = "d24", name = "D24", desc = "Data line 24" }), logicview.dict({ id = "d25", name = "D25", desc = "Data line 25" }), logicview.dict({ id = "d26", name = "D26", desc = "Data line 26" }), logicview.dict({ id = "d27", name = "D27", desc = "Data line 27" }), logicview.dict({ id = "d28", name = "D28", desc = "Data line 28" }), logicview.dict({ id = "d29", name = "D29", desc = "Data line 29" }), logicview.dict({ id = "d30", name = "D30", desc = "Data line 30" }), logicview.dict({ id = "d31", name = "D31", desc = "Data line 31" }) },
  options = { logicview.dict({ id = "clock_edge", desc = "Clock edge to sample on", default = "rising", values = { "rising", "falling" } }), logicview.dict({ id = "wordsize", desc = "Data wordsize (# bus cycles)", default = 0, values = {  } }), logicview.dict({ id = "endianness", desc = "Data endianness", default = "little", values = { "little", "big" } }) },
  annotations = { { "items", "Items" }, { "words", "Words" } },
  annotation_rows = { { "items", "Items", { 0 } }, { "words", "Words", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.items = {  }
  self.saved_item = nil
  self.saved_word = nil
  do
    local _lv_chain = nil
    self.ss_word = _lv_chain
    self.es_word = _lv_chain
  end
  self.first = true
  self.have_clock = true
  self.prv_dex = 0
  self.num_item_bits = nil
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putpw(self, data)
  self:put(self.ss_word, self.es_word, self.out_python, data)
end
function _decoder.putw(self, data)
  self:put(self.ss_word, self.es_word, self.out_ann, data)
end
function _decoder.put_ann(self, s, e, data)
  self:put(s, e, self.out_ann, data)
end
function _decoder.put_py(self, s, e, data)
  self:put(s, e, self.out_python, data)
end
function _decoder.handle_bits(self, item)
  local cur_dex
  cur_dex = self.samplenum
  if logicview.truth(self.first) then
    if logicview.truth((not logicview.truth(self.have_clock))) then
      self:put_py(self.prv_dex, cur_dex, { "ITEM", self.saved_item })
      self:put_ann(self.prv_dex, cur_dex, { 0, { logicview.pyformat(self.fmt_item, { self.saved_item }, logicview.dict({})) } })
    end
    self.first = false
    self.saved_item = item
  else
    self:put_py(self.prv_dex, cur_dex, { "ITEM", self.saved_item })
    self:put_ann(self.prv_dex, cur_dex, { 0, { logicview.pyformat(self.fmt_item, { self.saved_item }, logicview.dict({})) } })
    self.saved_item = item
  end
  self.prv_dex = cur_dex
  self:handel_word(item, cur_dex)
end
function _decoder.handel_word(self, item, cur_dex)
  local ws, endian, word
  if logicview.truth((self.saved_word ~= nil)) then
    if logicview.truth((logicview.idx(self.options, "wordsize") > 0)) then
      self.es_word = cur_dex
      self:putw({ 1, { logicview.pyformat(self.fmt_word, { self.saved_word }, logicview.dict({})) } })
      self:putpw({ "WORD", self.saved_word })
    end
    self.saved_word = nil
  end
  if logicview.truth((item == nil)) then
    return
  end
  if logicview.truth((not logicview.truth(self.items))) then
    self.ss_word = cur_dex
  end
  _table.insert(self.items, item)
  ws = logicview.idx(self.options, "wordsize")
  if logicview.truth((logicview.len(self.items) < ws)) then
    return
  end
  endian = logicview.idx(self.options, "endianness")
  if logicview.truth(logicview.eq(endian, "big")) then
    logicview.list_reverse(self.items)
  end
  word = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(ws) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(self.items, i) << logicview.mul(i, self.num_item_bits))
  end
  return _lv_out
end)())
  self.saved_word = word
  self.items = {  }
end
function _decoder.end_(self)
  local cur_dex
  cur_dex = self.last_samplenum
  if logicview.truth((not logicview.eq(self.saved_item, nil))) then
    self:put_py(self.prv_dex, cur_dex, { "ITEM", self.saved_item })
    self:put_ann(self.prv_dex, cur_dex, { 0, { logicview.pyformat(self.fmt_item, { self.saved_item }, logicview.dict({})) } })
    self:handel_word(nil, cur_dex)
  end
end
function _decoder.decode(self)
  local max_possible, idx_channels, has_channels, max_connected, have_clock, edge, conds, idx_strip, num_item_bits, num_word_items, num_word_bits, num_digits, is_first, the_conds, clk, d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31, pins, bits, item
  max_possible = logicview.len(self.optional_channels)
  idx_channels = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(max_possible) do
    idx = _lv_i
    _lv_out[#_lv_out + 1] = (function() if logicview.truth(self:has_channel(idx)) then return idx else return nil end end)()
  end
  return _lv_out
end)()
  has_channels = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(idx_channels) do
    idx = _lv_item
    if logicview.truth((idx ~= nil)) then
    _lv_out[#_lv_out + 1] = idx
  end
    end
  return _lv_out
end)()
  if logicview.truth((not logicview.truth(has_channels))) then
    _error(ChannelError("At least one channel has to be supplied."), 0)
  end
  max_connected = (function() local _m; for _, _v in logicview.iter(has_channels) do if _m == nil or _v > _m then _m = _v end end; return _m end)()
  self.have_clock = self:has_channel(0)
  self.prv_dex = self.samplenum
  have_clock = self.have_clock
  if logicview.truth(have_clock) then
    edge = logicview.idx(logicview.idx(self.options, "clock_edge"), 0)
    conds = logicview.dict({ [0] = edge })
  else
    conds = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(has_channels) do
    idx = _lv_item
    _lv_out[#_lv_out + 1] = logicview.dict({ [idx] = "e" })
  end
  return _lv_out
end)()
  end
  idx_strip = logicview.add(max_connected, 1)
  num_item_bits = (idx_strip - 1)
  num_word_items = logicview.idx(self.options, "wordsize")
  num_word_bits = logicview.mul(num_item_bits, num_word_items)
  num_digits = logicview.floordiv(logicview.add(num_item_bits, 3), 4)
  self.fmt_item = logicview.pyformat("@{{:0{}X}}", { num_digits }, logicview.dict({}))
  num_digits = logicview.floordiv(logicview.add(num_word_bits, 3), 4)
  self.fmt_word = logicview.pyformat("@{{:0{}X}}", { num_digits }, logicview.dict({}))
  self.num_item_bits = num_item_bits
  is_first = true
  the_conds = conds
  while true do
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(have_clock))
  if not logicview.truth(_v) then return _v end
  _v = is_first
  return _v
end)()) then
      conds = nil
    else
      conds = the_conds
    end
    do
      local _lv_seq = self:wait(conds)
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
      d16 = logicview.idx(_lv_seq, 17)
      d17 = logicview.idx(_lv_seq, 18)
      d18 = logicview.idx(_lv_seq, 19)
      d19 = logicview.idx(_lv_seq, 20)
      d20 = logicview.idx(_lv_seq, 21)
      d21 = logicview.idx(_lv_seq, 22)
      d22 = logicview.idx(_lv_seq, 23)
      d23 = logicview.idx(_lv_seq, 24)
      d24 = logicview.idx(_lv_seq, 25)
      d25 = logicview.idx(_lv_seq, 26)
      d26 = logicview.idx(_lv_seq, 27)
      d27 = logicview.idx(_lv_seq, 28)
      d28 = logicview.idx(_lv_seq, 29)
      d29 = logicview.idx(_lv_seq, 30)
      d30 = logicview.idx(_lv_seq, 31)
      d31 = logicview.idx(_lv_seq, 32)
    end
    pins = { clk, d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31 }
    bits = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(idx_channels) do
    idx = _lv_item
    _lv_out[#_lv_out + 1] = (function() if logicview.truth((idx == nil)) then return 0 else return logicview.idx(pins, idx) end end)()
  end
  return _lv_out
end)()
    item = bitpack(logicview.slice(bits, 1, idx_strip, nil))
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(have_clock))
  if not logicview.truth(_v) then return _v end
  _v = is_first
  return _v
end)()) then
      is_first = false
      self.saved_item = item
      goto continue_2
    end
    self:handle_bits(item)
    ::continue_2::
  end
end

return _decoder
