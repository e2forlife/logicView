-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Torsten Duwe <duwe@suse.de>
-- Copyright (C) 2014 Sebastien Bourdelin <sebastien.bourdelin@savoirfairelinux.com>

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
  id = "pwm",
  name = "PWM",
  longname = "Pulse-width modulation",
  desc = "Analog level encoded in duty cycle percentage.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Encoding" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-high", values = { "active-low", "active-high" } }) },
  annotations = { { "duty-cycle", "Duty cycle" }, { "period", "Period" } },
  annotation_rows = { { "duty-cycle", "Duty cycle", { 0 } }, { "period", "Period", { 1 } } },
  binary = { { "raw", "RAW file" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_chain = nil
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_average = self:register(logicview.OUTPUT_META, "Average")
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.putp(self, period_t)
  local period_s
  if logicview.truth((function()
  local _v
  _v = logicview.eq(period_t, 0)
  if logicview.truth(_v) then return _v end
  _v = (period_t >= 1)
  return _v
end)()) then
    period_s = logicview.pymod("%.1f s", period_t)
  elseif logicview.truth((period_t <= 1e-12)) then
    period_s = logicview.pymod("%.1f fs", logicview.mul(period_t, 1000000000000000.0))
  elseif logicview.truth((period_t <= 1e-09)) then
    period_s = logicview.pymod("%.1f ps", logicview.mul(period_t, 1000000000000.0))
  elseif logicview.truth((period_t <= 1e-06)) then
    period_s = logicview.pymod("%.1f ns", logicview.mul(period_t, 1000000000.0))
  elseif logicview.truth((period_t <= 0.001)) then
    period_s = logicview.pymod("%.1f μs", logicview.mul(period_t, 1000000.0))
  else
    period_s = logicview.pymod("%.1f ms", logicview.mul(period_t, 1000.0))
  end
  self:put(self.ss_block, self.es_block, self.out_ann, { 1, { period_s } })
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_binary, data)
end
function _decoder.decode(self)
  local num_cycles, average, start_samplenum, end_samplenum, period, duty, ratio, percent, period_t
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  num_cycles = 0
  average = 0
  self:wait(logicview.dict({ [0] = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return "f" else return "r" end end)() }))
  self.first_samplenum = self.samplenum
  while true do
    start_samplenum = self.samplenum
    self:wait(logicview.dict({ [0] = "e" }))
    end_samplenum = self.samplenum
    self:wait(logicview.dict({ [0] = "e" }))
    self.ss_block = start_samplenum
    self.es_block = self.samplenum
    period = (self.samplenum - start_samplenum)
    duty = (end_samplenum - start_samplenum)
    ratio = (_tonumber((duty / period)) or 0)
    percent = (_tonumber(logicview.mul(ratio, 100)) or 0)
    self:putx({ 0, { logicview.pymod("%f%%", percent) } })
    self:putb({ 0, logicview.bytes({ logicview.tointeger(logicview.mul(ratio, 256)) }) })
    period_t = (_tonumber((period / self.samplerate)) or 0)
    self:putp(period_t)
    num_cycles = logicview.add(num_cycles, 1)
    average = logicview.add(average, percent)
    self:put(self.first_samplenum, self.es_block, self.out_average, (_tonumber((average / num_cycles)) or 0))
    ::continue_1::
  end
end

return _decoder
