-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Christoph Rackwitz <christoph.rackwitz@rwth-aachen.de>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>

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
local deque, bitpack, bitunpack, gray_encode, gray_decode, prefix_fmt, ChannelMapError, Value, MAX_CHANNELS, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
deque = collections.deque
bitpack = logicview.bitpack
bitunpack = logicview.bitunpack
gray_encode = function(plain)
  return (plain & (plain >> 1))
end
gray_decode = function(gray)
  local temp
  temp = gray
  temp = (temp ~ (temp >> 8))
  temp = (temp ~ (temp >> 4))
  temp = (temp ~ (temp >> 2))
  temp = (temp ~ (temp >> 1))
  return temp
end
prefix_fmt = function(value, emin)
  if emin == nil then emin = nil end
  local sgn, p, e, decimals, prefixes
  sgn = ((value > 0) - (value < 0))
  value = _math.abs(value)
  p = (function() if logicview.truth(value) then return math.log10(value) else return 0 end end)()
  value = logicview.mul(logicview.mul(sgn, math.floor(logicview.mul(value, (10 ^ logicview.tointeger((3 - p)))))), (10 ^ (-logicview.tointeger((3 - p)))))
  e = logicview.mul(logicview.floordiv(p, 3), 3)
  if logicview.truth((function()
  local _v
  _v = (emin ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (e < emin)
  return _v
end)()) then
    e = emin
  end
  value = logicview.mul(value, (10 ^ (-e)))
  p = (p - e)
  decimals = (2 - logicview.tointeger(p))
  prefixes = logicview.dict({ [(-9)] = "n", [(-6)] = "µ", [(-3)] = "m", [0] = "", [3] = "k", [6] = "M", [9] = "G" })
  return logicview.pyformat("{0:.{1}f} {2}", { value, decimals, logicview.idx(prefixes, e) }, logicview.dict({}))
end
ChannelMapError = function(msg)
  local text = _tostring(msg or "ChannelMapError")
  return _setmetatable({ _exc = "ChannelMapError", args = { text } }, { __tostring = function() return text end })
end
Value = {}
Value.__index = Value
function Value.__init__(self, onchange)
  self.onchange = onchange
  self.timestamp = nil
  self.value = nil
end
function Value.get(self)
  return self.value
end
function Value.set(self, timestamp, newval)
  if logicview.truth((not logicview.eq(newval, self.value))) then
    if logicview.truth((self.value ~= nil)) then
      self:onchange(self.timestamp, self.value, timestamp, newval)
    end
    self.value = newval
    self.timestamp = timestamp
  elseif logicview.truth(false) then
    if logicview.truth((self.value ~= nil)) then
      self:onchange(self.timestamp, self.value, timestamp, newval)
    end
  end
end
function Value.new(...)
  local self = _setmetatable({}, Value)
  Value.__init__(self, ...)
  return self
end
MAX_CHANNELS = 8
_decoder = {
  api_version = 3,
  id = "graycode",
  name = "Gray code",
  longname = "Gray code and rotary encoder",
  desc = "Accumulate rotary encoder increments, provide statistics.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Encoding" },
  channels = {  },
  optional_channels = { logicview.dict({ id = "d0", name = "D0", desc = "Data line 0" }), logicview.dict({ id = "d1", name = "D1", desc = "Data line 1" }), logicview.dict({ id = "d2", name = "D2", desc = "Data line 2" }), logicview.dict({ id = "d3", name = "D3", desc = "Data line 3" }), logicview.dict({ id = "d4", name = "D4", desc = "Data line 4" }), logicview.dict({ id = "d5", name = "D5", desc = "Data line 5" }), logicview.dict({ id = "d6", name = "D6", desc = "Data line 6" }), logicview.dict({ id = "d7", name = "D7", desc = "Data line 7" }) },
  options = { logicview.dict({ id = "edges", desc = "Edges per rotation", default = 0, values = {  } }), logicview.dict({ id = "avg_period", desc = "Averaging period", default = 10, values = {  } }) },
  annotations = { { "phase", "Phase" }, { "increment", "Increment" }, { "count", "Count" }, { "turns", "Turns" }, { "interval", "Interval" }, { "average", "Average" }, { "rpm", "Rate" } },
  annotation_rows = { { "phase", "Phase", { 0 } }, { "increment", "Increment", { 1 } }, { "count", "Count", { 2 } }, { "turns", "Turns", { 3 } }, { "interval", "Interval", { 4 } }, { "average", "Average", { 5 } }, { "rpm", "Rate", { 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.num_channels = 0
  self.samplerate = nil
  self.last_n = deque()
  self.phase = Value.new(self.on_phase)
  self.increment = Value.new(self.on_increment)
  self.count = Value.new(self.on_count)
  self.turns = Value.new(self.on_turns)
end
function _decoder.on_phase(self, told, vold, tnew, vnew)
  self:put(told, tnew, self.out_ann, { 0, { logicview.pyformat("{}", { vold }, logicview.dict({})) } })
end
function _decoder.on_increment(self, told, vold, tnew, vnew)
  local message
  if logicview.truth(logicview.eq(vold, 0)) then
    message = "0"
  elseif logicview.truth(logicview.eq(_math.abs(vold), logicview.floordiv(self.ENCODER_STEPS, 2))) then
    message = "±π"
  else
    message = logicview.pyformat("{:+d}", { vold }, logicview.dict({}))
  end
  self:put(told, tnew, self.out_ann, { 1, { message } })
end
function _decoder.on_count(self, told, vold, tnew, vnew)
  self:put(told, tnew, self.out_ann, { 2, { logicview.pyformat("{}", { vold }, logicview.dict({})) } })
end
function _decoder.on_turns(self, told, vold, tnew, vnew)
  self:put(told, tnew, self.out_ann, { 3, { logicview.pyformat("{:+d}", { vold }, logicview.dict({})) } })
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
  local chmask, d0, d1, d2, d3, d4, d5, d6, d7, startbits, curtime, prevtime, bits, oldcount, oldphase, newphase, phasedelta_raw, phasedelta, period, freq, avg_period
  chmask = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(MAX_CHANNELS) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = self:has_channel(i)
  end
  return _lv_out
end)()
  self.num_channels = logicview.sum(chmask)
  if logicview.truth((not logicview.eq(chmask, (function()
  local _lv_out = {}
  for _lv_i in logicview.range(MAX_CHANNELS) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (i < self.num_channels)
  end
  return _lv_out
end)()))) then
    _error(ChannelMapError("Assigned channels need to be contiguous"), 0)
  end
  self.ENCODER_STEPS = (1 << self.num_channels)
  do
    local _lv_seq = self:wait()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    d0 = logicview.idx(_lv_seq, 0)
    d1 = logicview.idx(_lv_seq, 1)
    d2 = logicview.idx(_lv_seq, 2)
    d3 = logicview.idx(_lv_seq, 3)
    d4 = logicview.idx(_lv_seq, 4)
    d5 = logicview.idx(_lv_seq, 5)
    d6 = logicview.idx(_lv_seq, 6)
    d7 = logicview.idx(_lv_seq, 7)
  end
  startbits = { d0, d1, d2, d3, d4, d5, d6, d7 }
  curtime = self.samplenum
  self.turns:set(self.samplenum, 0)
  self.count:set(self.samplenum, 0)
  self.phase:set(self.samplenum, gray_decode(bitpack(logicview.slice(startbits, nil, self.num_channels, nil))))
  while true do
    prevtime = curtime
    do
      local _lv_seq = self:wait((function()
  local _lv_out = {}
  for _lv_i in logicview.range(self.num_channels) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.dict({ [i] = "e" })
  end
  return _lv_out
end)())
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d0 = logicview.idx(_lv_seq, 0)
      d1 = logicview.idx(_lv_seq, 1)
      d2 = logicview.idx(_lv_seq, 2)
      d3 = logicview.idx(_lv_seq, 3)
      d4 = logicview.idx(_lv_seq, 4)
      d5 = logicview.idx(_lv_seq, 5)
      d6 = logicview.idx(_lv_seq, 6)
      d7 = logicview.idx(_lv_seq, 7)
    end
    bits = { d0, d1, d2, d3, d4, d5, d6, d7 }
    curtime = self.samplenum
    oldcount = logicview.dget(self.count, nil, nil)
    oldphase = logicview.dget(self.phase, nil, nil)
    newphase = gray_decode(bitpack(logicview.slice(bits, nil, self.num_channels, nil)))
    self.phase:set(self.samplenum, newphase)
    phasedelta_raw = (logicview.pymod(logicview.add((newphase - oldphase), (logicview.floordiv(self.ENCODER_STEPS, 2) - 1)), self.ENCODER_STEPS) - (logicview.floordiv(self.ENCODER_STEPS, 2) - 1))
    phasedelta = phasedelta_raw
    self.increment:set(self.samplenum, phasedelta)
    if logicview.truth(logicview.eq(_math.abs(phasedelta), logicview.floordiv(self.ENCODER_STEPS, 2))) then
      phasedelta = 0
    end
    self.count:set(self.samplenum, logicview.add(logicview.dget(self.count, nil, nil), phasedelta))
    if logicview.truth(logicview.idx(self.options, "edges")) then
      self.turns:set(self.samplenum, logicview.floordiv(logicview.dget(self.count, nil, nil), logicview.idx(self.options, "edges")))
    end
    if logicview.truth(self.samplerate) then
      period = ((curtime - prevtime) / self.samplerate)
      freq = (_math.abs(phasedelta_raw) / period)
      self:put(prevtime, curtime, self.out_ann, { 4, { logicview.pyformat("{}s, {}Hz", { prefix_fmt(period), prefix_fmt(freq) }, logicview.dict({})) } })
      if logicview.truth(logicview.idx(self.options, "avg_period")) then
        _table.insert(self.last_n, { _math.abs(phasedelta_raw), period })
        if logicview.truth((logicview.len(self.last_n) > logicview.idx(self.options, "avg_period"))) then
          self.last_n:popleft()
        end
        avg_period = (logicview.sum((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.last_n) do
    u = logicview.idx(_lv_item, 0)
    v = logicview.idx(_lv_item, 1)
    _lv_out[#_lv_out + 1] = v
  end
  return _lv_out
end)()) / (function()
  local _v
  _v = logicview.sum((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.last_n) do
    u = logicview.idx(_lv_item, 0)
    v = logicview.idx(_lv_item, 1)
    _lv_out[#_lv_out + 1] = u
  end
  return _lv_out
end)())
  if logicview.truth(_v) then return _v end
  _v = 1
  return _v
end)())
        self:put(prevtime, curtime, self.out_ann, { 5, { logicview.pyformat("{}s, {}Hz", { prefix_fmt(avg_period), prefix_fmt((1 / avg_period)) }, logicview.dict({})) } })
      end
      if logicview.truth(logicview.idx(self.options, "edges")) then
        self:put(prevtime, curtime, self.out_ann, { 6, { logicview.pyformat("{}rpm", { prefix_fmt((logicview.mul(60, freq) / logicview.idx(self.options, "edges"))) }, logicview.dict({})) } })
      end
    end
    ::continue_1::
  end
end

return _decoder
