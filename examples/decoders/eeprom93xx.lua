-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Kevin Redon <kingkevin@cuvoodoo.info>

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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "eeprom93xx",
  name = "93xx EEPROM",
  longname = "93xx Microwire EEPROM",
  desc = "93xx series Microwire EEPROM protocol.",
  license = "gplv2+",
  inputs = { "microwire" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "addresssize", desc = "Address size", default = 8, values = {  } }), logicview.dict({ id = "wordsize", desc = "Word size", default = 16, values = {  } }), logicview.dict({ id = "format", desc = "Data format", default = "hex", values = { "ascii", "hex" } }) },
  annotations = { { "si-data", "SI data" }, { "so-data", "SO data" }, { "warning", "Warning" } },
  annotation_rows = { { "data", "Data", { 0, 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = { { "address", "Address" }, { "data", "Data" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.frame = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.addresssize = logicview.idx(self.options, "addresssize")
  self.wordsize = logicview.idx(self.options, "wordsize")
end
function _decoder.put_address(self, data)
  local a, b
  a = 0
  for _lv_i in logicview.range(logicview.len(data)) do
    b = _lv_i
    a = logicview.add(a, (logicview.idx(data, b).si << ((logicview.len(data) - b) - 1)))
    ::continue_1::
  end
  self:put(logicview.idx(data, 0).ss, logicview.idx(data, (-1)).es, self.out_ann, { 0, { logicview.pymod("Address: 0x%04x", a), logicview.pymod("Addr: 0x%04x", a), logicview.pymod("0x%04x", a) } })
  self:put(logicview.idx(data, 0).ss, logicview.idx(data, (-1)).es, self.out_binary, { 0, logicview.bytes({ a }) })
end
function _decoder.put_word(self, si, data)
  local word, b, d, idx, word_str, s, c
  word = 0
  for _lv_i in logicview.range(logicview.len(data)) do
    b = _lv_i
    d = (function() if logicview.truth(si) then return logicview.idx(data, b).si else return logicview.idx(data, b).so end end)()
    word = logicview.add(word, (d << ((logicview.len(data) - b) - 1)))
    ::continue_2::
  end
  idx = (function() if logicview.truth(si) then return 0 else return 1 end end)()
  if logicview.truth(logicview.eq(logicview.idx(self.options, "format"), "ascii")) then
    word_str = ""
    for _lv_i in logicview.range(0, logicview.len(data), 8) do
      s = _lv_i
      c = (255 & (word >> s))
      if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(32, logicview.add(126, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
        word_str = logicview.add(_string.char(c), word_str)
      else
        word_str = logicview.add(logicview.pyformat("[{:02X}]", { c }, logicview.dict({})), word_str)
      end
      ::continue_3::
    end
    self:put(logicview.idx(data, 0).ss, logicview.idx(data, (-1)).es, self.out_ann, { idx, { logicview.pymod("Data: %s", word_str), logicview.pymod("%s", word_str) } })
  else
    self:put(logicview.idx(data, 0).ss, logicview.idx(data, (-1)).es, self.out_ann, { idx, { logicview.pymod("Data: 0x%04x", word), logicview.pymod("0x%04x", word) } })
    self:put(logicview.idx(data, 0).ss, logicview.idx(data, (-1)).es, self.out_binary, { 1, logicview.bytes({ ((word & 65280) >> 8), (word & 255) }) })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local opcode, word_start
    if logicview.truth((logicview.len(data) < logicview.add(2, self.addresssize))) then
      self:put(ss, es, self.out_ann, { 2, { "Not enough packet bits" } })
      return
    end
    opcode = logicview.add((logicview.idx(data, 0).si << 1), (logicview.idx(data, 1).si << 0))
    if logicview.truth(logicview.eq(opcode, 2)) then
      self:put(logicview.idx(data, 0).ss, logicview.idx(data, 1).es, self.out_ann, { 0, { "Read word", "READ" } })
      self:put_address(logicview.slice(data, 2, logicview.add(2, self.addresssize), nil))
      word_start = logicview.add(2, self.addresssize)
      while logicview.truth(((logicview.len(data) - word_start) > 0)) do
        if logicview.truth(((logicview.len(data) - word_start) < self.wordsize)) then
          self:put(logicview.idx(data, word_start).ss, logicview.idx(data, (logicview.len(data) - 1)).es, self.out_ann, { 2, { "Not enough word bits" } })
          break
        end
        self:put_word(false, logicview.slice(data, word_start, logicview.add(word_start, self.wordsize), nil))
        word_start = logicview.add(word_start, self.wordsize)
        ::continue_4::
      end
    elseif logicview.truth(logicview.eq(opcode, 1)) then
      self:put(logicview.idx(data, 0).ss, logicview.idx(data, 1).es, self.out_ann, { 0, { "Write word", "WRITE" } })
      self:put_address(logicview.slice(data, 2, logicview.add(2, self.addresssize), nil))
      if logicview.truth((logicview.len(data) < logicview.add(logicview.add(2, self.addresssize), self.wordsize))) then
        self:put(logicview.idx(data, logicview.add(2, self.addresssize)).ss, logicview.idx(data, (logicview.len(data) - 1)).ss, self.out_ann, { 2, { "Not enough word bits" } })
      else
        self:put_word(true, logicview.slice(data, logicview.add(2, self.addresssize), logicview.add(logicview.add(2, self.addresssize), self.wordsize), nil))
      end
    elseif logicview.truth(logicview.eq(opcode, 3)) then
      self:put(logicview.idx(data, 0).ss, logicview.idx(data, 1).es, self.out_ann, { 0, { "Erase word", "ERASE" } })
      self:put_address(logicview.slice(data, 2, logicview.add(2, self.addresssize), nil))
    elseif logicview.truth(logicview.eq(opcode, 0)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(data, 2).si, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(data, 3).si, 1)
  return _v
end)()) then
        self:put(logicview.idx(data, 0).ss, logicview.idx(data, (logicview.add(2, self.addresssize) - 1)).es, self.out_ann, { 0, { "Write enable", "WEN" } })
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(data, 2).si, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(data, 3).si, 0)
  return _v
end)()) then
        self:put(logicview.idx(data, 0).ss, logicview.idx(data, (logicview.add(2, self.addresssize) - 1)).es, self.out_ann, { 0, { "Write disable", "WDS" } })
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(data, 2).si, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(data, 3).si, 0)
  return _v
end)()) then
        self:put(logicview.idx(data, 0).ss, logicview.idx(data, (logicview.add(2, self.addresssize) - 1)).es, self.out_ann, { 0, { "Erase all memory", "Erase all", "ERAL" } })
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(data, 2).si, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(data, 3).si, 1)
  return _v
end)()) then
        self:put(logicview.idx(data, 0).ss, logicview.idx(data, (logicview.add(2, self.addresssize) - 1)).es, self.out_ann, { 0, { "Write all memory", "Write all", "WRAL" } })
        if logicview.truth((logicview.len(data) < logicview.add(logicview.add(2, self.addresssize), self.wordsize))) then
          self:put(logicview.idx(data, logicview.add(2, self.addresssize)).ss, logicview.idx(data, (logicview.len(data) - 1)).ss, self.out_ann, { 2, { "Not enough word bits" } })
        else
          self:put_word(true, logicview.slice(data, logicview.add(2, self.addresssize), logicview.add(logicview.add(2, self.addresssize), self.wordsize), nil))
        end
      end
    end
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
