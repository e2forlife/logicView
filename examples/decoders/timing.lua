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
local deque, SamplerateError, normalize_time, terse_times, Pin, Ann, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
deque = collections.deque
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
normalize_time = function(t)
  if logicview.truth((_math.abs(t) >= 1.0)) then
    return logicview.pymod("%.3f s  (%.3f Hz)", { t, (1 / t) })
  elseif logicview.truth((_math.abs(t) >= 0.001)) then
    if logicview.truth((((1 / t) / 1000) < 1)) then
      return logicview.pymod("%.3f ms (%.3f Hz)", { logicview.mul(t, 1000.0), (1 / t) })
    else
      return logicview.pymod("%.3f ms (%.3f kHz)", { logicview.mul(t, 1000.0), ((1 / t) / 1000) })
    end
  elseif logicview.truth((_math.abs(t) >= 1e-06)) then
    if logicview.truth(((((1 / t) / 1000) / 1000) < 1)) then
      return logicview.pymod("%.3f μs (%.3f kHz)", { logicview.mul(logicview.mul(t, 1000.0), 1000.0), ((1 / t) / 1000) })
    else
      return logicview.pymod("%.3f μs (%.3f MHz)", { logicview.mul(logicview.mul(t, 1000.0), 1000.0), (((1 / t) / 1000) / 1000) })
    end
  elseif logicview.truth((_math.abs(t) >= 1e-09)) then
    if logicview.truth(((((1 / t) / 1000) / 1000) / 1000)) then
      return logicview.pymod("%.3f ns (%.3f MHz)", { logicview.mul(logicview.mul(logicview.mul(t, 1000.0), 1000.0), 1000.0), (((1 / t) / 1000) / 1000) })
    else
      return logicview.pymod("%.3f ns (%.3f GHz)", { logicview.mul(logicview.mul(logicview.mul(t, 1000.0), 1000.0), 1000.0), ((((1 / t) / 1000) / 1000) / 1000) })
    end
  else
    return logicview.pymod("%f", t)
  end
end
terse_times = function(t, fmt)
  local scale, unit
  if logicview.truth(logicview.eq(fmt, "full")) then
    return { normalize_time(t) }
  end
  if logicview.truth(logicview.eq(fmt, "samples")) then
    return { logicview.pyformat("{:d}", { t }, logicview.dict({})) }
  end
  do
    local _lv_a0, _lv_a1 = nil, nil
    scale = _lv_a0
    unit = _lv_a1
  end
  if logicview.truth(logicview.eq(fmt, "terse-auto")) then
    if logicview.truth((_math.abs(t) >= 1.0)) then
      do
        local _lv_a0, _lv_a1 = 1.0, "s"
        scale = _lv_a0
        unit = _lv_a1
      end
    elseif logicview.truth((_math.abs(t) >= 0.001)) then
      do
        local _lv_a0, _lv_a1 = 1000.0, "ms"
        scale = _lv_a0
        unit = _lv_a1
      end
    elseif logicview.truth((_math.abs(t) >= 1e-06)) then
      do
        local _lv_a0, _lv_a1 = 1000000.0, "us"
        scale = _lv_a0
        unit = _lv_a1
      end
    elseif logicview.truth((_math.abs(t) >= 1e-09)) then
      do
        local _lv_a0, _lv_a1 = 1000000000.0, "ns"
        scale = _lv_a0
        unit = _lv_a1
      end
    elseif logicview.truth((_math.abs(t) >= 1e-12)) then
      do
        local _lv_a0, _lv_a1 = 1000000000000.0, "ps"
        scale = _lv_a0
        unit = _lv_a1
      end
    end
  elseif logicview.truth(logicview.eq(fmt, "terse-s")) then
    do
      local _lv_a0, _lv_a1 = 1.0, ""
      scale = _lv_a0
      unit = _lv_a1
    end
  elseif logicview.truth(logicview.eq(fmt, "terse-ms")) then
    do
      local _lv_a0, _lv_a1 = 1000.0, ""
      scale = _lv_a0
      unit = _lv_a1
    end
  elseif logicview.truth(logicview.eq(fmt, "terse-us")) then
    do
      local _lv_a0, _lv_a1 = 1000000.0, ""
      scale = _lv_a0
      unit = _lv_a1
    end
  elseif logicview.truth(logicview.eq(fmt, "terse-ns")) then
    do
      local _lv_a0, _lv_a1 = 1000000000.0, ""
      scale = _lv_a0
      unit = _lv_a1
    end
  elseif logicview.truth(logicview.eq(fmt, "terse-ps")) then
    do
      local _lv_a0, _lv_a1 = 1000000000000.0, ""
      scale = _lv_a0
      unit = _lv_a1
    end
  end
  if logicview.truth(scale) then
    t = logicview.mul(t, scale)
    return { logicview.pyformat("{:.0f}{}", { t, unit }, logicview.dict({})), logicview.pyformat("{:.0f}", { t }, logicview.dict({})) }
  end
  return { logicview.pyformat("{:f}", { t }, logicview.dict({})) }
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
  Pin.DATA = logicview.idx(_lv_seq, 0)
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.TIME = logicview.idx(_lv_seq, 0)
  Ann.TERSE = logicview.idx(_lv_seq, 1)
  Ann.AVG = logicview.idx(_lv_seq, 2)
  Ann.DELTA = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "timing",
  name = "Timing",
  longname = "Timing calculation with frequency and averaging",
  desc = "Calculate time between edges.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Clock/timing", "Util" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "avg_period", desc = "Averaging period", default = 100, values = {  } }), logicview.dict({ id = "edge", desc = "Edges to check", default = "any", values = { "any", "rising", "falling" } }), logicview.dict({ id = "delta", desc = "Show delta from last", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "format", desc = "Format of 'time' annotation", default = "full", values = { "full", "terse-auto", "terse-s", "terse-ms", "terse-us", "terse-ns", "terse-ps", "samples" } }) },
  annotations = { { "time", "Time" }, { "terse", "Terse" }, { "average", "Average" }, { "delta", "Delta" } },
  annotation_rows = { { "times", "Times", { 0, 1 } }, { "averages", "Averages", { 2 } }, { "deltas", "Deltas", { 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self)
  local edge, avg_period, delta, fmt, ss, last_n, last_t, es, sa, t, cls, txt, average
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  edge = logicview.idx(self.options, "edge")
  avg_period = logicview.idx(self.options, "avg_period")
  delta = logicview.eq(logicview.idx(self.options, "delta"), "yes")
  fmt = logicview.idx(self.options, "format")
  ss = nil
  last_n = deque()
  last_t = nil
  while true do
    if logicview.truth(logicview.eq(edge, "rising")) then
      self:wait(logicview.dict({ [0] = "r" }))
    elseif logicview.truth(logicview.eq(edge, "falling")) then
      self:wait(logicview.dict({ [0] = "f" }))
    else
      self:wait(logicview.dict({ [0] = "e" }))
    end
    if logicview.truth((not logicview.truth(ss))) then
      ss = self.samplenum
      goto continue_1
    end
    es = self.samplenum
    sa = (es - ss)
    t = (sa / self.samplerate)
    if logicview.truth(logicview.eq(fmt, "full")) then
      do
        local _lv_a0, _lv_a1 = Ann.TIME, { normalize_time(t) }
        cls = _lv_a0
        txt = _lv_a1
      end
    elseif logicview.truth(logicview.eq(fmt, "samples")) then
      do
        local _lv_a0, _lv_a1 = Ann.TERSE, terse_times(sa, fmt)
        cls = _lv_a0
        txt = _lv_a1
      end
    else
      do
        local _lv_a0, _lv_a1 = Ann.TERSE, terse_times(t, fmt)
        cls = _lv_a0
        txt = _lv_a1
      end
    end
    if logicview.truth(txt) then
      self:put(ss, es, self.out_ann, { cls, txt })
    end
    if logicview.truth((avg_period > 0)) then
      if logicview.truth((t > 0)) then
        _table.insert(last_n, t)
      end
      if logicview.truth((logicview.len(last_n) > avg_period)) then
        last_n:popleft()
      end
      average = (logicview.sum(last_n) / logicview.len(last_n))
      do
        local _lv_a0, _lv_a1 = Ann.AVG, normalize_time(average)
        cls = _lv_a0
        txt = _lv_a1
      end
      self:put(ss, es, self.out_ann, { cls, { txt } })
    end
    if logicview.truth((function()
  local _v
  _v = last_t
  if not logicview.truth(_v) then return _v end
  _v = delta
  return _v
end)()) then
      do
        local _lv_a0, _lv_a1 = Ann.DELTA, normalize_time((t - last_t))
        cls = _lv_a0
        txt = _lv_a1
      end
      self:put(ss, es, self.out_ann, { cls, { txt } })
    end
    last_t = t
    ss = es
    ::continue_1::
  end
end

return _decoder
