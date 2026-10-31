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
local SamplerateError, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "guess_bitrate",
  name = "Guess bitrate",
  longname = "Guess bitrate/baudrate",
  desc = "Guess the bitrate/baudrate of a UART (or other) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Clock/timing", "Util" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bitrate", "Bitrate / baudrate" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.putx(self, data)
  self:put(self.ss_edge, self.samplenum, self.out_ann, data)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.ss_edge = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.decode(self)
  local bitwidth, b, bitrate
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:wait(logicview.dict({ [0] = "e" }))
  self.ss_edge = self.samplenum
  bitwidth = nil
  while true do
    self:wait(logicview.dict({ [0] = "e" }))
    b = (self.samplenum - self.ss_edge)
    if logicview.truth((function()
  local _v
  _v = (bitwidth == nil)
  if logicview.truth(_v) then return _v end
  _v = (b < bitwidth)
  return _v
end)()) then
      bitwidth = b
      bitrate = logicview.tointeger(((_tonumber(self.samplerate) or 0) / (_tonumber(b) or 0)))
      self:putx({ 0, { logicview.pymod("%d", bitrate) } })
    end
    self.ss_edge = self.samplenum
    ::continue_1::
  end
end

return _decoder
