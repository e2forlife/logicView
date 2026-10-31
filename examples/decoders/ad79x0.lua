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
local modes, input_voltage_format, validation, Decoder
local _decoder

modes = logicview.dict({ [0] = { "Normal Mode", "Normal", "Norm", "N" }, [1] = { "Power Down Mode", "Power Down", "PD" }, [2] = { "Power Up Mode", "Power Up", "PU" } })
input_voltage_format = { "%.6fV", "%.2fV" }
validation = logicview.dict({ invalid = { "Invalid data", "Invalid", "N/A" }, incomplete = { "Incomplete conversion", "Incomplete", "I" }, complete = { "Complete conversion", "Complete", "C" } })
_decoder = {
  api_version = 3,
  id = "ad79x0",
  name = "AD79x0",
  longname = "Analog Devices AD79x0",
  desc = "Analog Devices AD7910/AD7920 12-bit ADC.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Analog/digital" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "vref", desc = "Reference voltage (V)", default = 1.5, values = {  } }) },
  annotations = { { "mode", "Mode" }, { "voltage", "Voltage" }, { "validation", "Validation" } },
  annotation_rows = { { "modes", "Modes", { 0 } }, { "voltages", "Voltages", { 1 } }, { "data_validation", "Data validation", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = 0
  self.samples_bit = (-1)
  self.ss = (-1)
  self.start_sample = 0
  self.previous_state = 0
  self.data = 0
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.put_validation(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 2, logicview.idx(validation, msg) })
end
function _decoder.put_data(self, pos, input_voltage)
  local ann, format
  ann = {  }
  for _lv_item in logicview.iter(input_voltage_format) do
    format = _lv_item
    _table.insert(ann, logicview.pymod(format, input_voltage))
    ::continue_1::
  end
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 1, ann })
end
function _decoder.put_mode(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 0, logicview.idx(modes, msg) })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, nb_bits, vin, miso, bit
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
        if logicview.truth(logicview.eq(self.samples_bit, (-1))) then
          return
        end
        self.data = (self.data >> 1)
        nb_bits = logicview.floordiv((ss - self.ss), self.samples_bit)
        if logicview.truth((nb_bits >= 10)) then
          if logicview.truth(logicview.eq(self.data, 4095)) then
            self:put_mode({ self.start_sample, es }, 2)
            self.previous_state = 0
            self:put_validation({ self.start_sample, es }, "invalid")
          else
            self:put_mode({ self.start_sample, es }, 0)
            if logicview.truth(logicview.eq(nb_bits, 16)) then
              self:put_validation({ self.start_sample, es }, "complete")
            elseif logicview.truth((nb_bits < 16)) then
              self:put_validation({ self.start_sample, es }, "incomplete")
            end
            vin = logicview.mul((self.data / ((2 ^ 12) - 1)), logicview.idx(self.options, "vref"))
            self:put_data({ self.start_sample, es }, vin)
          end
        elseif logicview.truth((nb_bits < 10)) then
          self:put_mode({ self.start_sample, es }, 1)
          self.previous_state = 1
          self:put_validation({ self.start_sample, es }, "invalid")
        end
        self.ss = (-1)
        self.samples_bit = (-1)
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
        self.start_sample = ss
        self.samples_bit = (-1)
      end
    elseif logicview.truth(logicview.eq(ptype, "BITS")) then
      if logicview.truth((logicview.idx(data, 2) == nil)) then
        return
      end
      miso = logicview.idx(data, 2)
      if logicview.truth(logicview.eq(self.samples_bit, (-1))) then
        self.samples_bit = (logicview.idx(logicview.idx(miso, 0), 2) - logicview.idx(logicview.idx(miso, 0), 1))
      end
      if logicview.truth(logicview.eq(self.ss, (-1))) then
        self.ss = ss
      end
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
