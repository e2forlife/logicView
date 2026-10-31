-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: mit
-- Copyright (C) 2020 Tomas Mudrunka <harvie@github>

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
local bitpack, mm_per_inch, Decoder
local _decoder

bitpack = logicview.bitpack
mm_per_inch = 25.4
_decoder = {
  api_version = 3,
  id = "caliper",
  name = "Caliper",
  longname = "Digital calipers",
  desc = "Protocol of cheap generic digital calipers.",
  license = "mit",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Analog/digital", "Sensor" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Serial clock line" }), logicview.dict({ id = "data", name = "DATA", desc = "Serial data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "timeout_ms", desc = "Packet timeout in ms, 0 to disable", default = 10, values = {  } }), logicview.dict({ id = "unit", desc = "Convert units", default = "keep", values = { "keep", "mm", "inch" } }), logicview.dict({ id = "changes", desc = "Changes only", default = "no", values = { "no", "yes" } }) },
  annotations = { { "measurement", "Measurement" }, { "warning", "Warning" } },
  annotation_rows = { { "measurements", "Measurements", { 0 } }, { "warnings", "Warnings", { 1 } } },
  binary = {  }
}
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self.number_bits = {  }
  self.flags_bits = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putg(self, ss, es, cls, data)
  self:put(ss, es, self.out_ann, { cls, data })
end
function _decoder.decode(self)
  local last_sent, timeout_ms, want_unit, show_all, wait_cond, snum_per_ms, timeout_snum, clk, data, count, negative, is_inch, number, unit
  last_sent = nil
  timeout_ms = logicview.idx(self.options, "timeout_ms")
  want_unit = logicview.idx(self.options, "unit")
  show_all = logicview.eq(logicview.idx(self.options, "changes"), "no")
  wait_cond = { logicview.dict({ [0] = "r" }) }
  if logicview.truth(timeout_ms) then
    snum_per_ms = (self.samplerate / 1000)
    timeout_snum = logicview.mul(timeout_ms, snum_per_ms)
    _table.insert(wait_cond, logicview.dict({ skip = (function() local _n = timeout_snum; if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)() }))
  end
  while true do
    do
      local _lv_seq = self:wait(wait_cond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = timeout_ms
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(logicview.eq((self.matched & 1), 1)))
  return _v
end)()) then
      if logicview.truth((function()
  local _v
  _v = self.number_bits
  if logicview.truth(_v) then return _v end
  _v = self.flags_bits
  return _v
end)()) then
        count = logicview.add(logicview.len(self.number_bits), logicview.len(self.flags_bits))
        self:putg(self.ss, self.samplenum, 1, { logicview.pyformat("timeout with {} bits in buffer", { count }, logicview.dict({})), logicview.pyformat("timeout ({} bits)", { count }, logicview.dict({})), "timeout" })
      end
      self:reset()
      goto continue_1
    end
    if logicview.truth((not logicview.truth(self.ss))) then
      self.ss = self.samplenum
    end
    self.es = self.samplenum
    if logicview.truth((logicview.len(self.number_bits) < 16)) then
      _table.insert(self.number_bits, data)
      goto continue_1
    end
    if logicview.truth((logicview.len(self.flags_bits) < 8)) then
      _table.insert(self.flags_bits, data)
      if logicview.truth((logicview.len(self.flags_bits) < 8)) then
        goto continue_1
      end
    end
    negative = logicview.truth(logicview.idx(self.flags_bits, 4))
    is_inch = logicview.truth(logicview.idx(self.flags_bits, 7))
    number = bitpack(self.number_bits)
    if logicview.truth(negative) then
      number = (-number)
    end
    if logicview.truth(is_inch) then
      number = (number / 2000)
      if logicview.truth(logicview.eq(want_unit, "mm")) then
        number = logicview.mul(number, mm_per_inch)
        is_inch = false
      end
    else
      number = (number / 100)
      if logicview.truth(logicview.eq(want_unit, "inch")) then
        number = (function() local _n, _p = (number / mm_per_inch), 10 ^ 4; if _n >= 0 then return _math.floor(_n * _p + 0.5) / _p end; return _math.ceil(_n * _p - 0.5) / _p end)()
        is_inch = true
      end
    end
    unit = (function() if logicview.truth(is_inch) then return "in" else return "mm" end end)()
    if logicview.truth((function()
  local _v
  _v = show_all
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq({ number, unit }, last_sent))
  return _v
end)()) then
      self:putg(self.ss, self.es, 0, { (_tostring(number)) .. (_tostring(unit)), (_tostring(number)) })
      last_sent = { number, unit }
    end
    self:reset()
    ::continue_1::
  end
end

return _decoder
