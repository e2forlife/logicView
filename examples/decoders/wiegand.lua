-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Sean Burford <sburford@google.com>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local bits2int, SamplerateError, Decoder
local _decoder

bits2int = logicview.bits2int
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "wiegand",
  name = "Wiegand",
  longname = "Wiegand interface",
  desc = "Wiegand interface for electronic entry systems.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial", "RFID" },
  channels = { logicview.dict({ id = "d0", name = "D0", desc = "Data 0 line" }), logicview.dict({ id = "d1", name = "D1", desc = "Data 1 line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "active", desc = "Data lines active level", default = "low", values = { "low", "high" } }), logicview.dict({ id = "bitwidth_ms", desc = "Single bit width in milliseconds", default = 4, values = { 1, 2, 4, 8, 16, 32 } }) },
  annotations = { { "bits", "Bits" }, { "state", "State" } },
  annotation_rows = { { "bits", "Binary value", { 0 } }, { "state", "Stream state", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self._samples_per_bit = 10
  self._d0_prev = nil
  self._d1_prev = nil
  self._state = nil
  self.ss_state = nil
  self.ss_bit = nil
  self.es_bit = nil
  self._bit = nil
  self._bits = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self._active = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "active"), "high")) then return 1 else return 0 end end)()
  self._inactive = (1 - self._active)
end
function _decoder.metadata(self, key, value)
  local ms_per_sample, ms_per_bit
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    if logicview.truth(self.samplerate) then
      ms_per_sample = logicview.mul(1000, (1.0 / self.samplerate))
      ms_per_bit = (_tonumber(logicview.idx(self.options, "bitwidth_ms")) or 0)
      self._samples_per_bit = logicview.tointeger(_math.max(1, logicview.tointeger((ms_per_bit / ms_per_sample))))
    end
  end
end
function _decoder._update_state(self, state, bit)
  if bit == nil then bit = nil end
  local ann, accum_bits, bstart, bits, blen, s1, s2
  if logicview.truth((self._bit ~= nil)) then
    _table.insert(self._bits, self._bit)
    self:put(self.ss_bit, self.samplenum, self.out_ann, { 0, { _tostring(self._bit) } })
  end
  self._bit = bit
  self.ss_bit = self.samplenum
  if logicview.truth((bit ~= nil)) then
    self.es_bit = logicview.add(self.samplenum, self._samples_per_bit)
  else
    self.es_bit = nil
  end
  if logicview.truth((not logicview.eq(state, self._state))) then
    ann = nil
    if logicview.truth(logicview.eq(self._state, "data")) then
      accum_bits = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self._bits) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(x)
  end
  return _lv_out
end)())
      bstart = (-1)
      bits = self._bits
      blen = logicview.len(self._bits)
      if logicview.truth((not logicview.eq(bstart, (-1)))) then
        bits = {  }
        while logicview.truth((logicview.add(bstart, 4) <= blen)) do
          _table.insert(bits, logicview.idx(self._bits, logicview.add(bstart, 0)))
          _table.insert(bits, logicview.idx(self._bits, logicview.add(bstart, 1)))
          _table.insert(bits, logicview.idx(self._bits, logicview.add(bstart, 2)))
          _table.insert(bits, logicview.idx(self._bits, logicview.add(bstart, 3)))
          bstart = logicview.add(bstart, 4)
          ::continue_1::
        end
      end
      blen = logicview.len(bits)
      s1 = logicview.pymod("%d bits %s", { blen, accum_bits })
      s2 = logicview.pymod("%d bits", blen)
      ann = { 1, { s1, s2 } }
    elseif logicview.truth(logicview.eq(self._state, "invalid")) then
      ann = { 1, { self._state } }
    end
    if logicview.truth(ann) then
      self:put(self.ss_state, self.samplenum, self.out_ann, ann)
    end
    self.ss_state = self.samplenum
    self._state = state
    self._bits = {  }
  end
end
function _decoder.decode(self)
  local d0, d1
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    do
      local _lv_seq = self:wait()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d0 = logicview.idx(_lv_seq, 0)
      d1 = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(d0, self._d0_prev)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(d1, self._d1_prev)
  return _v
end)()) then
      if logicview.truth((function()
  local _v
  _v = self.es_bit
  if not logicview.truth(_v) then return _v end
  _v = (self.samplenum >= self.es_bit)
  return _v
end)()) then
        if logicview.truth(logicview.eq({ d0, d1 }, { self._inactive, self._inactive })) then
          self:_update_state("idle")
        else
          self:_update_state("invalid")
        end
      end
      goto continue_2
    end
    if logicview.truth(logicview.contains({ nil, "idle", "data" }, self._state)) then
      if logicview.truth(logicview.eq({ d0, d1 }, { self._active, self._inactive })) then
        self:_update_state("data", 0)
      elseif logicview.truth(logicview.eq({ d0, d1 }, { self._inactive, self._active })) then
        self:_update_state("data", 1)
      elseif logicview.truth(logicview.eq({ d0, d1 }, { self._active, self._active })) then
        self:_update_state("invalid")
      end
    elseif logicview.truth(logicview.eq(self._state, "invalid")) then
      if logicview.truth(logicview.eq({ d0, d1 }, { self._inactive, self._inactive })) then
        self:_update_state("idle")
      end
    end
    do
      local _lv_a0, _lv_a1 = d0, d1
      self._d0_prev = _lv_a0
      self._d1_prev = _lv_a1
    end
    ::continue_2::
  end
end
function _decoder.report(self)
  return logicview.pymod("%s: %s D0 %d D1 %d (active on %d), %d samples per bit", { self.name, self._state, self._d0_prev, self._d1_prev, self._active, self._samples_per_bit })
end

return _decoder
