-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2015 Uwe Hermann <uwe@hermann-uwe.de>
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
local dacs, Decoder
local _decoder

dacs = logicview.dict({ [0] = "DACA", [1] = "DACB", [2] = "DACC", [3] = "DACD" })
_decoder = {
  api_version = 3,
  id = "tlc5620",
  name = "TI TLC5620",
  longname = "Texas Instruments TLC5620",
  desc = "Texas Instruments TLC5620 8-bit quad DAC.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "Analog/digital" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Serial interface clock" }), logicview.dict({ id = "data", name = "DATA", desc = "Serial interface data" }) },
  optional_channels = { logicview.dict({ id = "load", name = "LOAD", desc = "Serial interface load control" }), logicview.dict({ id = "ldac", name = "LDAC", desc = "Load DAC" }) },
  options = { logicview.dict({ id = "vref_a", desc = "Reference voltage DACA (V)", default = 3.3, values = {  } }), logicview.dict({ id = "vref_b", desc = "Reference voltage DACB (V)", default = 3.3, values = {  } }), logicview.dict({ id = "vref_c", desc = "Reference voltage DACC (V)", default = 3.3, values = {  } }), logicview.dict({ id = "vref_d", desc = "Reference voltage DACD (V)", default = 3.3, values = {  } }) },
  annotations = { { "dac-select", "DAC select" }, { "gain", "Gain" }, { "value", "DAC value" }, { "data-latch", "Data latch point" }, { "ldac-fall", "LDAC falling edge" }, { "bit", "Bit" }, { "reg-write", "Register write" }, { "voltage-update", "Voltage update" }, { "voltage-update-all", "Voltage update (all DACs)" }, { "invalid-cmd", "Invalid command" } },
  annotation_rows = { { "bits", "Bits", { 5 } }, { "fields", "Fields", { 0, 1, 2 } }, { "registers", "Registers", { 6, 7 } }, { "voltage-updates", "Voltage updates", { 8 } }, { "events", "Events", { 3, 4 } }, { "errors", "Errors", { 9 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bits = {  }
  self.ss_dac_first = nil
  do
    local _lv_chain = 0
    self.ss_dac = _lv_chain
    self.es_dac = _lv_chain
  end
  do
    local _lv_chain = 0
    self.ss_gain = _lv_chain
    self.es_gain = _lv_chain
  end
  do
    local _lv_chain = 0
    self.ss_value = _lv_chain
    self.es_value = _lv_chain
  end
  do
    local _lv_chain = nil
    self.dac_select = _lv_chain
    self.gain = _lv_chain
    self.dac_value = _lv_chain
  end
  self.dacval = logicview.dict({ A = "?", B = "?", C = "?", D = "?" })
  self.gains = logicview.dict({ A = "?", B = "?", C = "?", D = "?" })
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.handle_11bits(self)
  local ss, es, s, g, v, i
  if logicview.truth((logicview.len(self.bits) > 11)) then
    self.bits = logicview.slice(self.bits, (-11), nil, nil)
  end
  if logicview.truth((logicview.len(self.bits) < 11)) then
    do
      local _lv_a0, _lv_a1 = self.samplenum, self.samplenum
      ss = _lv_a0
      es = _lv_a1
    end
    if logicview.truth((logicview.len(self.bits) >= 2)) then
      ss = logicview.idx(logicview.idx(self.bits, 0), 1)
      es = logicview.add(logicview.idx(logicview.idx(self.bits, (-1)), 1), (logicview.idx(logicview.idx(self.bits, 1), 1) - logicview.idx(logicview.idx(self.bits, 0), 1)))
    end
    self:put(ss, es, self.out_ann, { 9, { "Command too short" } })
    self.bits = {  }
    return false
  end
  self.ss_dac = logicview.idx(logicview.idx(self.bits, 0), 1)
  do
    local _lv_chain = logicview.idx(logicview.idx(self.bits, 2), 1)
    self.es_dac = _lv_chain
    self.ss_gain = _lv_chain
  end
  do
    local _lv_chain = logicview.idx(logicview.idx(self.bits, 3), 1)
    self.es_gain = _lv_chain
    self.ss_value = _lv_chain
  end
  self.clock_width = (self.es_gain - self.ss_gain)
  self.es_value = logicview.add(logicview.idx(logicview.idx(self.bits, 10), 1), self.clock_width)
  if logicview.truth((self.ss_dac_first == nil)) then
    self.ss_dac_first = self.ss_dac
  end
  s = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, nil, 2, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(i, 0))
  end
  return _lv_out
end)())
  do
    local _lv_chain = logicview.idx(dacs, logicview.tointeger(s, 2))
    self.dac_select = _lv_chain
    s = _lv_chain
  end
  self:put(self.ss_dac, self.es_dac, self.out_ann, { 0, { logicview.pymod("DAC select: %s", s), logicview.pymod("DAC sel: %s", s), logicview.pymod("DAC: %s", s), logicview.pymod("D: %s", s), s, logicview.idx(s, 3) } })
  do
    local _lv_chain = logicview.add(1, logicview.idx(logicview.idx(self.bits, 2), 0))
    self.gain = _lv_chain
    g = _lv_chain
  end
  self:put(self.ss_gain, self.es_gain, self.out_ann, { 1, { logicview.pymod("Gain: x%d", g), logicview.pymod("G: x%d", g), logicview.pymod("x%d", g) } })
  s = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 3, nil, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(i, 0))
  end
  return _lv_out
end)())
  do
    local _lv_chain = logicview.tointeger(s, 2)
    self.dac_value = _lv_chain
    v = _lv_chain
  end
  self:put(self.ss_value, self.es_value, self.out_ann, { 2, { logicview.pymod("DAC value: %d", v), logicview.pymod("Value: %d", v), logicview.pymod("Val: %d", v), logicview.pymod("V: %d", v), logicview.pymod("%d", v) } })
  for _lv_i in logicview.range(1, 11) do
    i = _lv_i
    self:put(logicview.idx(logicview.idx(self.bits, (i - 1)), 1), logicview.idx(logicview.idx(self.bits, i), 1), self.out_ann, { 5, { _tostring(logicview.idx(logicview.idx(self.bits, (i - 1)), 0)) } })
    ::continue_1::
  end
  self:put(logicview.idx(logicview.idx(self.bits, 10), 1), logicview.add(logicview.idx(logicview.idx(self.bits, 10), 1), self.clock_width), self.out_ann, { 5, { _tostring(logicview.idx(logicview.idx(self.bits, 10), 0)) } })
  self.bits = {  }
  return true
end
function _decoder.handle_falling_edge_load(self)
  local s, v, g, vref
  if logicview.truth((not logicview.truth(self:handle_11bits()))) then
    return
  end
  do
    local _lv_a0, _lv_a1, _lv_a2 = self.dac_select, self.dac_value, self.gain
    s = _lv_a0
    v = _lv_a1
    g = _lv_a2
  end
  self:put(self.samplenum, self.samplenum, self.out_ann, { 3, { "Falling edge on LOAD", "LOAD fall", "F" } })
  vref = logicview.idx(self.options, logicview.pymod("vref_%s", _string.lower(logicview.idx(self.dac_select, 3))))
  v = logicview.pymod("%.2fV", logicview.mul(logicview.mul(vref, (v / 256)), self.gain))
  if logicview.truth(logicview.eq(self.ldac, 0)) then
    self:put(self.ss_dac, self.es_value, self.out_ann, { 7, { logicview.pymod("Setting %s voltage to %s", { s, v }), logicview.pymod("%s=%s", { s, v }) } })
  else
    self:put(self.ss_dac, self.es_value, self.out_ann, { 6, { logicview.pymod("Setting %s register value to %s", { s, v }), logicview.pymod("%s=%s", { s, v }) } })
  end
  logicview.setidx(self.dacval, logicview.idx(self.dac_select, (-1)), _tostring(self.dac_value))
  logicview.setidx(self.gains, logicview.idx(self.dac_select, (-1)), self.gain)
end
function _decoder.handle_falling_edge_ldac(self)
  local dacval, key, val, vref, v, s
  self:put(self.samplenum, self.samplenum, self.out_ann, { 4, { "Falling edge on LDAC", "LDAC fall", "LDAC", "L" } })
  if logicview.truth((self.ss_dac_first == nil)) then
    return
  end
  dacval = logicview.dict({  })
  for _lv_k, _lv_v in _pairs(self.dacval) do
    key = _lv_k
    val = _lv_v
    if logicview.truth(logicview.eq(val, "?")) then
      logicview.setidx(dacval, key, "?")
    else
      vref = logicview.idx(self.options, logicview.pymod("vref_%s", _string.lower(key)))
      v = logicview.mul(logicview.mul(vref, (logicview.tointeger(val) / 256)), logicview.idx(self.gains, key))
      logicview.setidx(dacval, key, logicview.pymod("%.2fV", v))
    end
    ::continue_2::
  end
  s = logicview.strip(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter("ABCD") do
    d = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("DAC%s=%s ", { d, logicview.idx(dacval, d) })
  end
  return _lv_out
end)()))
  self:put(self.ss_dac_first, self.samplenum, self.out_ann, { 8, { logicview.pymod("Updating voltages: %s", s), s, logicview.replace(s, "DAC", "", nil) } })
  self.ss_dac_first = nil
end
function _decoder.handle_new_dac_bit(self, datapin)
  _table.insert(self.bits, { datapin, self.samplenum })
end
function _decoder.decode(self)
  local clk, data, load, ldac
  while true do
    do
      local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [2] = "f" }), logicview.dict({ [3] = "f" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
      load = logicview.idx(_lv_seq, 2)
      ldac = logicview.idx(_lv_seq, 3)
    end
    self.ldac = ldac
    if logicview.truth((self.matched & (1 << 0))) then
      self:handle_new_dac_bit(data)
    end
    if logicview.truth((self.matched & (1 << 1))) then
      self:handle_falling_edge_load()
    end
    if logicview.truth((self.matched & (1 << 2))) then
      self:handle_falling_edge_ldac()
    end
    ::continue_3::
  end
end

return _decoder
