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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "ad5626",
  name = "AD5626",
  longname = "Analog Devices AD5626",
  desc = "Analog Devices AD5626 12-bit nanoDAC.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Analog/digital" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "voltage", "Voltage" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.data = 0
  self.ss = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, mosi, bit
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
        self.data = (self.data >> 1)
        self.data = (self.data / 1000)
        self:put(self.ss, es, self.out_ann, { 0, { logicview.pymod("%.3fV", self.data) } })
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
      mosi = logicview.idx(data, 1)
      for _lv_item in logicview.iter(logicview.reversed(mosi)) do
        bit = _lv_item
        self.data = (self.data | logicview.idx(bit, 0))
        self.data = (self.data << 1)
        ::continue_1::
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
