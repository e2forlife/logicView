-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Anthony Symons <antus@pcmhacking.net>

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
local SamplerateError, timeuf, Ann, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
timeuf = function(t)
  return logicview.tointeger(logicview.mul(logicview.mul(t, 1000.0), 1000.0))
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(5) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.ANN_RAW = logicview.idx(_lv_seq, 0)
  Ann.ANN_SOF = logicview.idx(_lv_seq, 1)
  Ann.ANN_IFS = logicview.idx(_lv_seq, 2)
  Ann.ANN_DATA = logicview.idx(_lv_seq, 3)
  Ann.ANN_PACKET = logicview.idx(_lv_seq, 4)
end
_decoder = {
  api_version = 3,
  id = "sae_j1850_vpw",
  name = "SAE J1850 VPW",
  longname = "SAE J1850 VPW.",
  desc = "SAE J1850 Variable Pulse Width 1x and 4x.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Automotive" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "raw", "Raw" }, { "sof", "SOF" }, { "ifs", "EOF/IFS" }, { "data", "Data" }, { "packet", "Packet" } },
  annotation_rows = { { "raws", "Raws", { 0, 1, 2 } }, { "bytes", "Bytes", { 3 } }, { "packets", "Packets", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.samplerate = nil
  self.byte = 0
  self.mode = 0
  self.data = 0
  self.datastart = 0
  self.csa = 0
  self.csb = 0
  self.count = 0
  self.active = 0
  self.sof = 200
  self.sofl = 164
  self.sofh = 245
  self.long = 128
  self.longl = 97
  self.longh = 170
  self.short = 64
  self.shortl = 24
  self.shorth = 97
  self.ifs = 240
  self.spd = 1
end
function _decoder.handle_bit(self, ss, es, b)
  self.data = (self.data | (b << (7 - self.count)))
  self:put(ss, es, self.out_ann, { Ann.ANN_RAW, { logicview.pymod("%d", b) } })
  if logicview.truth(logicview.eq(self.count, 0)) then
    self.datastart = ss
  end
  if logicview.truth(logicview.eq(self.count, 7)) then
    self.csa = self.datastart
    self.csb = self.samplenum
    self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_DATA, { logicview.pymod("%02X", self.data) } })
    if logicview.truth(logicview.eq(self.byte, 0)) then
      self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_PACKET, { "Priority", "Prio", "P" } })
    elseif logicview.truth(logicview.eq(self.byte, 1)) then
      self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_PACKET, { "Destination", "Dest", "D" } })
    elseif logicview.truth(logicview.eq(self.byte, 2)) then
      self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_PACKET, { "Source", "Src", "S" } })
    elseif logicview.truth(logicview.eq(self.byte, 3)) then
      self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_PACKET, { "Mode", "M" } })
      self.mode = self.data
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.mode, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.byte, 4)
  return _v
end)()) then
      self:put(self.datastart, self.samplenum, self.out_ann, { Ann.ANN_PACKET, { "Pid", "P" } })
    end
    self.count = (-1)
    self.data = 0
    self.byte = logicview.add(self.byte, 1)
  end
  self.count = logicview.add(self.count, 1)
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
  local es, ss, pin, samples, t
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:wait(logicview.dict({ [0] = "e" }))
  es = self.samplenum
  while true do
    ss = es
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      pin = logicview.idx(_lv_seq, 0)
    end
    es = self.samplenum
    samples = (es - ss)
    t = timeuf((samples / self.samplerate))
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(pin, self.active)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains((function() local _t = {}; for _v in logicview.range(self.sofl, self.sofh) do _t[#_t + 1] = _v end; return _t end)(), t)
  return _v
end)()) then
        self:put(ss, es, self.out_ann, { Ann.ANN_RAW, { "1X SOF", "S1", "S" } })
        self.spd = 1
        self.data = 0
        self.count = 0
        self.state = "DATA"
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(pin, self.active)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains((function() local _t = {}; for _v in logicview.range(logicview.tointeger((self.sofl / 4)), logicview.tointeger((self.sofh / 4))) do _t[#_t + 1] = _v end; return _t end)(), t)
  return _v
end)()) then
        self:put(ss, es, self.out_ann, { Ann.ANN_RAW, { "4X SOF", "S4", "4" } })
        self.spd = 4
        self.data = 0
        self.count = 0
        self.state = "DATA"
      end
    elseif logicview.truth(logicview.eq(self.state, "DATA")) then
      if logicview.truth((t >= logicview.tointeger((self.ifs / self.spd)))) then
        self.state = "IDLE"
        self:put(ss, es, self.out_ann, { Ann.ANN_RAW, { "EOF/IFS", "E" } })
        self:put(self.csa, self.csb, self.out_ann, { Ann.ANN_PACKET, { "Checksum", "CS", "C" } })
        self.byte = 0
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(logicview.tointeger((self.shortl / self.spd)), logicview.tointeger((self.shorth / self.spd))) do _t[#_t + 1] = _v end; return _t end)(), t)) then
        if logicview.truth(logicview.eq(pin, self.active)) then
          self:handle_bit(ss, es, 1)
        else
          self:handle_bit(ss, es, 0)
        end
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(logicview.tointeger((self.longl / self.spd)), logicview.tointeger((self.longh / self.spd))) do _t[#_t + 1] = _v end; return _t end)(), t)) then
        if logicview.truth(logicview.eq(pin, self.active)) then
          self:handle_bit(ss, es, 0)
        else
          self:handle_bit(ss, es, 1)
        end
      end
    end
    ::continue_1::
  end
end

return _decoder
