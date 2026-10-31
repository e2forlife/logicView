-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Paul Evans <leonerd@leonerd.org.uk>
-- Copyright (C) 2022 DreamSourceLab <support@dreamsourcelab.com>

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
local re, _decode_intensity, registers, ann_reg, ann_digit, ann_warning, Decoder
local _decoder

re = logicview.re
_decode_intensity = function(val)
  local intensity
  intensity = (val & 15)
  if logicview.truth(logicview.eq(intensity, 0)) then
    return "min"
  elseif logicview.truth(logicview.eq(intensity, 15)) then
    return "max"
  else
    return intensity
  end
end
registers = logicview.dict({ [0] = { "No-op", (function(_) return "" end) }, [9] = { "Decode", (function(v) return logicview.pyformat("0b{:08b}", { v }, logicview.dict({})) end) }, [10] = { "Intensity", _decode_intensity }, [11] = { "Scan limit", (function(v) return logicview.add(1, v) end) }, [12] = { "Shutdown", (function(v) return (function() if logicview.truth(v) then return "off" else return "on" end end)() end) }, [15] = { "Display test", (function(v) return (function() if logicview.truth(v) then return "on" else return "off" end end)() end) } })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(3) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_reg = logicview.idx(_lv_seq, 0)
  ann_digit = logicview.idx(_lv_seq, 1)
  ann_warning = logicview.idx(_lv_seq, 2)
end
_decoder = {
  api_version = 3,
  id = "max7219",
  name = "MAX7219",
  longname = "Maxim MAX7219/MAX7221",
  desc = "Maxim MAX72xx series 8-digit LED display driver.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Display" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "register", "Registers written to the device" }, { "digit", "Digits displayed on the device" }, { "warnings", "Human-readable warnings" } },
  annotation_rows = { { "commands", "Commands", { 0, 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.pos = 0
  self.cs_start = 0
end
function _decoder.putreg(self, ss, es, reg, value)
  self:put(ss, es, self.out_ann, { ann_reg, { logicview.pymod("%s: %s", { reg, value }) } })
end
function _decoder.putdigit(self, ss, es, digit, value)
  self:put(ss, es, self.out_ann, { ann_digit, { logicview.pymod("Digit %d: {$}", digit), logicview.pymod("@%02X", value) } })
end
function _decoder.putwarn(self, ss, es, message)
  self:put(ss, es, self.out_ann, { ann_warning, { message } })
end
function _decoder.putwarn_ann(self, ss, es, message)
  self:put(ss, es, self.out_ann, { ann_warning, message })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, _, name, decoder
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "DATA")) then
      if logicview.truth((not logicview.truth(self.cs_asserted))) then
        return
      end
      if logicview.truth(logicview.eq(self.pos, 0)) then
        self.addr = mosi
        self.addr_start = ss
      elseif logicview.truth(logicview.eq(self.pos, 1)) then
        if logicview.truth((function()
  local _v
  _v = (self.addr >= 1)
  if not logicview.truth(_v) then return _v end
  _v = (self.addr <= 8)
  return _v
end)()) then
          self:putdigit(self.addr_start, es, self.addr, mosi)
        elseif logicview.truth(logicview.contains(registers, self.addr)) then
          do
            local _lv_seq = logicview.idx(registers, self.addr)
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            name = logicview.idx(_lv_seq, 0)
            decoder = logicview.idx(_lv_seq, 1)
          end
          self:putreg(self.addr_start, es, name, decoder(mosi))
        else
          self:putwarn_ann(self.addr_start, es, { "Unknown register {$}", logicview.pymod("@%02X", self.addr) })
        end
      end
      self.pos = logicview.add(self.pos, 1)
    elseif logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      self.cs_asserted = mosi
      if logicview.truth(self.cs_asserted) then
        self.pos = 0
        self.cs_start = ss
      elseif logicview.truth(logicview.eq(self.pos, 1)) then
        self:putwarn(self.cs_start, es, "Short write")
      elseif logicview.truth((self.pos > 2)) then
        self:putwarn(self.cs_start, es, "Overlong write")
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
