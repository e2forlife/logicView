-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Analog Devices Inc.

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
local input_voltage_format, Decoder
local _decoder

input_voltage_format = { "%.6fV", "%.2fV" }
_decoder = {
  api_version = 3,
  id = "ltc242x",
  name = "LTC242x",
  longname = "Linear Technology LTC242x",
  desc = "Linear Technology LTC2421/LTC2422 1-/2-channel 20-bit ADC.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Analog/digital" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "vref", desc = "Reference voltage (V)", default = 1.5, values = {  } }) },
  annotations = { { "ch0_voltage", "CH0 voltage" }, { "ch1_voltage", "CH1 voltage" } },
  annotation_rows = { { "ch0_voltages", "CH0 voltages", { 0 } }, { "ch1_voltages", "CH1 voltages", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.data = 0
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss = _lv_a0
    self.es = _lv_a1
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.handle_input_voltage(self, data)
  local input_voltage, ann, format, channel
  input_voltage = (data & 4194303)
  input_voltage = (-((2 ^ 21) - input_voltage))
  input_voltage = logicview.mul((input_voltage / 1048575), logicview.idx(self.options, "vref"))
  ann = {  }
  for _lv_item in logicview.iter(input_voltage_format) do
    format = _lv_item
    _table.insert(ann, logicview.pymod(format, input_voltage))
    ::continue_1::
  end
  channel = ((data & (1 << 22)) >> 22)
  self:put(self.ss, self.es, self.out_ann, { channel, ann })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, miso, bit
    ptype = logicview.idx(data, 0)
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      do
        local _lv_seq = logicview.slice(data, 1, nil, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cs_old = logicview.idx(_lv_seq, 0)
        cs_new = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((function()
  local _v
  _v = (cs_old ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_old, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 1)
  return _v
end)()) then
        self.es = es
        self.data = (self.data >> 1)
        self:handle_input_voltage(self.data)
        self.data = 0
      elseif logicview.truth((function()
  local _v
  _v = (cs_old ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_old, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 0)
  return _v
end)()) then
        self.ss = ss
      end
    elseif logicview.truth(logicview.eq(ptype, "BITS")) then
      miso = logicview.idx(data, 2)
      for _lv_item in logicview.iter(logicview.reversed(miso)) do
        bit = _lv_item
        self.data = (self.data | logicview.idx(bit, 0))
        self.data = (self.data << 1)
        ::continue_2::
      end
    end
  end
  if _type(packets) ~= 'table' then return _lv_packet(self, start_sample, end_sample, packets) end
  for _, _item in ipairs(packets) do
    local payload = _item.data
    if payload == nil then payload = _item end
    local ss = _item.start_sample or start_sample
    local es = _item.end_sample
    if es ~= nil then es = es - 1 end
    _lv_packet(self, ss, es, payload)
  end
end

return _decoder
