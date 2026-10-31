-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Uwe Hermann <uwe@hermann-uwe.de>

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
  id = "mlx90614",
  name = "MLX90614",
  longname = "Melexis MLX90614",
  desc = "Melexis MLX90614 infrared thermometer protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "IC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "celsius", "Temperature / °C" }, { "kelvin", "Temperature / K" } },
  annotation_rows = { { "temps-celsius", "Temperature / °C", { 0 } }, { "temps-kelvin", "Temperature / K", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IGNORE START REPEAT"
  self.data = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, kelvin, celsius
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      databyte = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(self.state, "IGNORE START REPEAT")) then
      if logicview.truth((not logicview.eq(cmd, "START REPEAT"))) then
        return
      end
      self.state = "IGNORE ADDRESS WRITE"
    elseif logicview.truth(logicview.eq(self.state, "IGNORE ADDRESS WRITE")) then
      if logicview.truth((not logicview.eq(cmd, "ADDRESS WRITE"))) then
        return
      end
      self.state = "GET TEMPERATURE"
    elseif logicview.truth(logicview.eq(self.state, "GET TEMPERATURE")) then
      if logicview.truth((not logicview.eq(cmd, "DATA WRITE"))) then
        return
      end
      if logicview.truth(logicview.eq(logicview.len(self.data), 0)) then
        _table.insert(self.data, databyte)
        self.ss = ss
      elseif logicview.truth(logicview.eq(logicview.len(self.data), 1)) then
        _table.insert(self.data, databyte)
        self.es = es
      else
        kelvin = logicview.mul((logicview.idx(self.data, 0) | (logicview.idx(self.data, 1) << 8)), 0.02)
        celsius = (kelvin - 273.15)
        self:putx({ 0, { logicview.pymod("Temperature: %3.2f °C", celsius) } })
        self:putx({ 1, { logicview.pymod("Temperature: %3.2f K", kelvin) } })
        self.state = "IGNORE START REPEAT"
        self.data = {  }
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
