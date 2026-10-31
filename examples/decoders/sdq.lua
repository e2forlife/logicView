-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019-2020 Philip Åkesson <philip.akesson@gmail.com>

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
local bitpack, SamplerateError, Pin, Ann, Decoder
local _decoder

bitpack = logicview.bitpack
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
Pin = {}
Pin.__index = Pin
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(1) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pin.SDQ = logicview.idx(_lv_seq, 0)
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(3) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIT = logicview.idx(_lv_seq, 0)
  Ann.BYTE = logicview.idx(_lv_seq, 1)
  Ann.BREAK = logicview.idx(_lv_seq, 2)
end
_decoder = {
  api_version = 3,
  id = "sdq",
  name = "SDQ",
  longname = "Texas Instruments SDQ",
  desc = "Texas Instruments SDQ. The SDQ protocol is also used by Apple.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "sdq", name = "SDQ", desc = "Single wire SDQ data line." }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "bitrate", desc = "Bit rate", default = 98425, values = {  } }) },
  annotations = { { "bit", "Bit" }, { "byte", "Byte" }, { "break", "Break" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "bytes", "Bytes", { 1 } }, { "breaks", "Breaks", { 2 } } },
  binary = {  }
}
function _decoder.puts(self, data)
  self:put(self.startsample, self.samplenum, self.out_ann, data)
end
function _decoder.putetu(self, data)
  self:put(self.startsample, logicview.add(self.startsample, logicview.tointeger(self.bit_width)), self.out_ann, data)
end
function _decoder.putbetu(self, data)
  self:put(self.bytepos, logicview.add(self.startsample, logicview.tointeger(self.bit_width)), self.out_ann, data)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.startsample = 0
  self.bits = {  }
  self.bytepos = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.handle_bit(self, bit)
  local byte
  _table.insert(self.bits, bit)
  self:putetu({ Ann.BIT, { logicview.pyformat("Bit: {:d}", { bit }, logicview.dict({})), logicview.pyformat("{:d}", { bit }, logicview.dict({})) } })
  if logicview.truth(logicview.eq(logicview.len(self.bits), 8)) then
    byte = bitpack(self.bits)
    self:putbetu({ Ann.BYTE, { logicview.pyformat("Byte: 0x{:02x}", { byte }, logicview.dict({})), logicview.pyformat("0x{:02x}", { byte }, logicview.dict({})) } })
    self.bits = {  }
    self.bytepos = 0
  end
end
function _decoder.handle_break(self)
  self:puts({ Ann.BREAK, { "Break", "BR" } })
  self.bits = {  }
  self.startsample = self.samplenum
  self.bytepos = 0
end
function _decoder.decode(self)
  local break_threshold, sdq, delta
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self.bit_width = ((_tonumber(self.samplerate) or 0) / (_tonumber(logicview.idx(self.options, "bitrate")) or 0))
  self.half_bit_width = (self.bit_width / 2.0)
  break_threshold = logicview.mul(self.bit_width, 1.2)
  do
    local _lv_seq = self:wait(logicview.dict({ [Pin.SDQ] = "h" }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    sdq = logicview.idx(_lv_seq, 0)
  end
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [Pin.SDQ] = "f" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sdq = logicview.idx(_lv_seq, 0)
    end
    self.startsample = self.samplenum
    if logicview.truth(logicview.eq(self.bytepos, 0)) then
      self.bytepos = self.samplenum
    end
    do
      local _lv_seq = self:wait(logicview.dict({ [Pin.SDQ] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sdq = logicview.idx(_lv_seq, 0)
    end
    delta = (self.samplenum - self.startsample)
    if logicview.truth((delta > break_threshold)) then
      self:handle_break()
    elseif logicview.truth((delta > self.half_bit_width)) then
      self:handle_bit(0)
    else
      self:handle_bit(1)
    end
    ::continue_1::
  end
end

return _decoder
