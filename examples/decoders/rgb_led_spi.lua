-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Matt Ranostay <mranostay@gmail.com>

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
  id = "rgb_led_spi",
  name = "RGB LED (SPI)",
  longname = "RGB LED string decoder (SPI)",
  desc = "RGB LED string protocol (RGB values clocked over SPI).",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Display" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "rgb", "RGB values" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self.mosi_bytes = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso, red, green, blue, rgb_value
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 0)) then
      self.ss_cmd = ss
    end
    _table.insert(self.mosi_bytes, mosi)
    if logicview.truth((not logicview.eq(logicview.len(self.mosi_bytes), 3))) then
      return
    end
    do
      local _lv_seq = self.mosi_bytes
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      red = logicview.idx(_lv_seq, 0)
      green = logicview.idx(_lv_seq, 1)
      blue = logicview.idx(_lv_seq, 2)
    end
    rgb_value = (((logicview.tointeger(red) << 16) | (logicview.tointeger(green) << 8)) | logicview.tointeger(blue))
    self.es_cmd = es
    self:putx({ 0, { logicview.pymod("#%.6x", rgb_value) } })
    self.mosi_bytes = {  }
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
