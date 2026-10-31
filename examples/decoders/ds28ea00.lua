-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Iztok Jeras <iztok.jeras@gmail.com>

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
local command, Decoder
local _decoder

command = logicview.dict({ [78] = "Write scratchpad", [190] = "Read scratchpad", [72] = "Copy scratchpad", [68] = "Convert temperature", [180] = "Read power mode", [184] = "Recall EEPROM", [245] = "PIO access read", [165] = "PIO access write", [153] = "Chain" })
_decoder = {
  api_version = 3,
  id = "ds28ea00",
  name = "DS28EA00",
  longname = "Maxim DS28EA00 1-Wire digital thermometer",
  desc = "1-Wire digital thermometer with Sequence Detect and PIO.",
  license = "gplv2+",
  inputs = { "onewire_network" },
  outputs = {  },
  tags = { "IC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text", "Human-readable text" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.trn_beg = 0
  self.trn_end = 0
  self.state = "ROM"
  self.rom = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local code, val
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      code = logicview.idx(_lv_seq, 0)
      val = logicview.idx(_lv_seq, 1)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(code, "RESET/PRESENCE")) then
      self:putx({ 0, { logicview.pymod("Reset/presence: %s", (function() if logicview.truth(val) then return "true" else return "false" end end)()) } })
      self.state = "ROM"
    elseif logicview.truth(logicview.eq(code, "ROM")) then
      self.rom = val
      self:putx({ 0, { logicview.pymod("ROM: 0x%016x", val) } })
      self.state = "COMMAND"
    elseif logicview.truth(logicview.eq(code, "DATA")) then
      if logicview.truth(logicview.eq(self.state, "COMMAND")) then
        if logicview.truth((not logicview.contains(command, val))) then
          self:putx({ 0, { logicview.pymod("Unrecognized command: 0x%02x", val) } })
          return
        end
        self:putx({ 0, { logicview.pymod("Function command: 0x%02x '%s'", { val, logicview.idx(command, val) }) } })
        self.state = _string.upper(logicview.idx(command, val))
      elseif logicview.truth(logicview.eq(self.state, "READ SCRATCHPAD")) then
        self:putx({ 0, { logicview.pymod("Scratchpad data: 0x%02x", val) } })
      elseif logicview.truth(logicview.eq(self.state, "CONVERT TEMPERATURE")) then
        self:putx({ 0, { logicview.pymod("Temperature conversion status: 0x%02x", val) } })
      elseif logicview.truth(logicview.contains((function()
  local _lv_out = {}
  for _, _lv_v in _pairs(command) do
    s = _lv_v
    _lv_out[#_lv_out + 1] = _string.upper(s)
  end
  return _lv_out
end)(), self.state)) then
        self:putx({ 0, { logicview.pymod("TODO '%s': 0x%02x", { self.state, val }) } })
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
