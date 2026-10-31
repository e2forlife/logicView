-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
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
local edge_detector, SamplerateError, Decoder
local _decoder

edge_detector = logicview.dict({ rising = (function(x, y) return logicview.truth((function()
  local _v
  _v = (not logicview.truth(x))
  if not logicview.truth(_v) then return _v end
  _v = y
  return _v
end)()) end), falling = (function(x, y) return logicview.truth((function()
  local _v
  _v = x
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(y))
  return _v
end)()) end), both = (function(x, y) return logicview.truth((x ~ y)) end) })
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "jitter",
  name = "Jitter",
  longname = "Timing jitter calculation",
  desc = "Retrieves the timing jitter between two digital signals.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Clock/timing", "Util" },
  channels = { logicview.dict({ id = "clk", name = "Clock", desc = "Clock reference channel" }), logicview.dict({ id = "sig", name = "Resulting signal", desc = "Resulting signal controlled by the clock" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "clk_polarity", desc = "Clock edge polarity", default = "rising", values = { "rising", "falling", "both" } }), logicview.dict({ id = "sig_polarity", desc = "Resulting signal edge polarity", default = "rising", values = { "rising", "falling", "both" } }) },
  annotations = { { "jitter", "Jitter value" }, { "clk_missed", "Clock missed" }, { "sig_missed", "Signal missed" } },
  annotation_rows = { { "jitter", "Jitter values", { 0 } }, { "clk_missed", "Clock missed", { 1 } }, { "sig_missed", "Signal missed", { 2 } } },
  binary = { { "ascii-float", "Jitter values as newline-separated ASCII floats" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "CLK"
  self.samplerate = nil
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.oldclk = _lv_a0
    self.oldsig = _lv_a1
  end
  self.clk_start = nil
  self.sig_start = nil
  self.clk_missed = 0
  self.sig_missed = 0
end
function _decoder.start(self)
  self.clk_edge = logicview.idx(edge_detector, logicview.idx(self.options, "clk_polarity"))
  self.sig_edge = logicview.idx(edge_detector, logicview.idx(self.options, "sig_polarity"))
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_clk_missed = self:register(logicview.OUTPUT_META, "Clock missed")
  self.out_sig_missed = self:register(logicview.OUTPUT_META, "Signal missed")
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.putx(self, delta)
  local delta_s
  if logicview.truth((function()
  local _v
  _v = logicview.eq(delta, 0)
  if logicview.truth(_v) then return _v end
  _v = (delta >= 1)
  return _v
end)()) then
    delta_s = logicview.pymod("%.1fs", delta)
  elseif logicview.truth((delta <= 1e-12)) then
    delta_s = logicview.pymod("%.1ffs", logicview.mul(delta, 1000000000000000.0))
  elseif logicview.truth((delta <= 1e-09)) then
    delta_s = logicview.pymod("%.1fps", logicview.mul(delta, 1000000000000.0))
  elseif logicview.truth((delta <= 1e-06)) then
    delta_s = logicview.pymod("%.1fns", logicview.mul(delta, 1000000000.0))
  elseif logicview.truth((delta <= 0.001)) then
    delta_s = logicview.pymod("%.1fμs", logicview.mul(delta, 1000000.0))
  else
    delta_s = logicview.pymod("%.1fms", logicview.mul(delta, 1000.0))
  end
  self:put(self.clk_start, self.sig_start, self.out_ann, { 0, { delta_s } })
end
function _decoder.putb(self, delta)
  local x
  if logicview.truth((delta == nil)) then
    return
  end
  x = logicview.add(_tostring(delta), "\n")
  self:put(self.clk_start, self.sig_start, self.out_binary, { 0, x })
end
function _decoder.putm(self, data)
  self:put(self.samplenum, self.samplenum, self.out_ann, data)
end
function _decoder.handle_clk(self, clk, sig)
  if logicview.truth(logicview.eq(self.clk_start, self.samplenum)) then
    return true
  end
  if logicview.truth(self:clk_edge(self.oldclk, clk)) then
    self.clk_start = self.samplenum
    self.state = "SIG"
    return false
  else
    if logicview.truth((function()
  local _v
  _v = (self.sig_start ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.sig_start, self.samplenum))
  if not logicview.truth(_v) then return _v end
  _v = self:sig_edge(self.oldsig, sig)
  return _v
end)()) then
      self.sig_missed = logicview.add(self.sig_missed, 1)
      self:put(self.samplenum, self.samplenum, self.out_sig_missed, self.sig_missed)
      self:putm({ 2, { "Missed signal", "MS" } })
    end
    return true
  end
end
function _decoder.handle_sig(self, clk, sig)
  local delta
  if logicview.truth(logicview.eq(self.sig_start, self.samplenum)) then
    return true
  end
  if logicview.truth(self:sig_edge(self.oldsig, sig)) then
    self.sig_start = self.samplenum
    self.state = "CLK"
    delta = ((self.sig_start - self.clk_start) / self.samplerate)
    self:putx(delta)
    self:putb(delta)
    return false
  else
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.clk_start, self.samplenum))
  if not logicview.truth(_v) then return _v end
  _v = self:clk_edge(self.oldclk, clk)
  return _v
end)()) then
      self.clk_missed = logicview.add(self.clk_missed, 1)
      self:put(self.samplenum, self.samplenum, self.out_clk_missed, self.clk_missed)
      self:putm({ 1, { "Missed clock", "MC" } })
    end
    return true
  end
end
function _decoder.decode(self)
  local clk, sig
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    do
      local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ [1] = "e" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      sig = logicview.idx(_lv_seq, 1)
    end
    while true do
      if logicview.truth(logicview.eq(self.state, "CLK")) then
        if logicview.truth(self:handle_clk(clk, sig)) then
          break
        end
      end
      if logicview.truth(logicview.eq(self.state, "SIG")) then
        if logicview.truth(self:handle_sig(clk, sig)) then
          break
        end
      end
      ::continue_2::
    end
    do
      local _lv_a0, _lv_a1 = clk, sig
      self.oldclk = _lv_a0
      self.oldsig = _lv_a1
    end
    ::continue_1::
  end
end

return _decoder
