-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Jeremy Swanson <jeremy@rakocontrols.com>

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
  id = "dsi",
  name = "DSI",
  longname = "Digital Serial Interface",
  desc = "Digital Serial Interface (DSI) lighting protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial", "Lighting" },
  channels = { logicview.dict({ id = "dsi", name = "DSI", desc = "DSI data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-high", values = { "active-low", "active-high" } }) },
  annotations = { { "bit", "Bit" }, { "startbit", "Start bit" }, { "level", "Dimmer level" }, { "raw", "Raw data" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "raw", "Raw data", { 3 } }, { "fields", "Fields", { 1, 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.samplenum = nil
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.bits = _lv_a1
    self.ss_es_bits = _lv_a2
  end
  self.state = "IDLE"
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.old_dsi = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return 1 else return 0 end end)()
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.halfbit = logicview.tointeger((logicview.mul(self.samplerate, 0.0016667) / 2.0))
  end
end
function _decoder.putb(self, bit1, bit2, data)
  local ss, es
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.ss_es_bits, bit1), 0), logicview.idx(logicview.idx(self.ss_es_bits, bit2), 1)
    ss = _lv_a0
    es = _lv_a1
  end
  self:put(ss, es, self.out_ann, data)
end
function _decoder.handle_bits(self, length)
  local a, c, f, g, b, i, ss, es, s
  do
    local _lv_a0, _lv_a1, _lv_a2, _lv_a3, _lv_a4 = 0, 0, 0, 0, self.bits
    a = _lv_a0
    c = _lv_a1
    f = _lv_a2
    g = _lv_a3
    b = _lv_a4
  end
  for _lv_i in logicview.range(length) do
    i = _lv_i
    if logicview.truth(logicview.eq(i, 0)) then
      ss = _math.max(0, logicview.idx(logicview.idx(self.bits, 0), 0))
    else
      ss = logicview.idx(logicview.idx(self.ss_es_bits, (i - 1)), 1)
    end
    es = logicview.add(logicview.idx(logicview.idx(self.bits, i), 0), logicview.mul(self.halfbit, 2))
    _table.insert(self.ss_es_bits, { ss, es })
    self:putb(i, i, { 0, { logicview.pymod("%d", logicview.idx(logicview.idx(self.bits, i), 1)) } })
    ::continue_1::
  end
  s = { logicview.pymod("Startbit: %d", logicview.idx(logicview.idx(b, 0), 1)), logicview.pymod("ST: %d", logicview.idx(logicview.idx(b, 0), 1)), "ST", "S", "S" }
  self:putb(0, 0, { 1, s })
  self:putb(0, 0, { 3, s })
  for _lv_i in logicview.range(8) do
    i = _lv_i
    f = (f | (logicview.idx(logicview.idx(b, logicview.add(1, i)), 1) << (7 - i)))
    g = (f / 2.55)
    ::continue_2::
  end
  if logicview.truth(logicview.eq(length, 9)) then
    s = { logicview.pymod("Data: %02X", f), logicview.pymod("Dat: %02X", f), logicview.pymod("Dat: %02X", f), logicview.pymod("D: %02X", f), "D" }
    self:putb(1, 8, { 3, s })
    s = { logicview.pymod("Level: %d%%", g), logicview.pymod("Lev: %d%%", g), logicview.pymod("Lev: %d%%", g), logicview.pymod("L: %d", g), "D" }
    self:putb(1, 8, { 2, s })
    return
  end
end
function _decoder.reset_decoder_state(self)
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.bits = _lv_a1
    self.ss_es_bits = _lv_a2
  end
  self.state = "IDLE"
end
function _decoder.decode(self)
  local bit
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  bit = 0
  while true do
    do
      local _lv_seq = self:wait()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.dsi = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-high")) then
      self.dsi = (self.dsi ~ 1)
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(logicview.eq(self.old_dsi, self.dsi)) then
        goto continue_3
      end
      _table.insert(self.edges, (self.samplenum - logicview.tointeger(self.halfbit)))
      _table.insert(self.edges, self.samplenum)
      self.phase0 = (self.dsi ~ 1)
      self.state = "PHASE1"
      self.old_dsi = self.dsi
      self.old_dsi = self.dsi
      goto continue_3
    end
    if logicview.truth((not logicview.eq(self.old_dsi, self.dsi))) then
      _table.insert(self.edges, self.samplenum)
    elseif logicview.truth(logicview.eq(self.samplenum, logicview.add(logicview.idx(self.edges, (-1)), logicview.tointeger(logicview.mul(self.halfbit, 1.5))))) then
      _table.insert(self.edges, (self.samplenum - logicview.tointeger(logicview.mul(self.halfbit, 0.5))))
    else
      goto continue_3
    end
    bit = self.old_dsi
    if logicview.truth(logicview.eq(self.state, "PHASE0")) then
      self.phase0 = bit
      self.state = "PHASE1"
    elseif logicview.truth(logicview.eq(self.state, "PHASE1")) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(bit, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.phase0, 1)
  return _v
end)()) then
        if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.len(self.bits), 17)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.bits), 9)
  return _v
end)()) then
          self:handle_bits(logicview.len(self.bits))
        end
        self:reset_decoder_state()
        goto continue_3
      else
        _table.insert(self.bits, { logicview.idx(self.edges, (-3)), bit })
        self.state = "PHASE0"
      end
    end
    self.old_dsi = self.dsi
    ::continue_3::
  end
end

return _decoder
