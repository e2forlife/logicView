-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Johannes Roemer <jroemer@physik.uni-wuerzburg.de>

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
local timing, SamplerateError, Decoder
local _decoder

timing = logicview.dict({ ["START LOW"] = logicview.dict({ min = 750, max = 25000 }), ["START HIGH"] = logicview.dict({ min = 10, max = 10000 }), ["RESPONSE LOW"] = logicview.dict({ min = 50, max = 90 }), ["RESPONSE HIGH"] = logicview.dict({ min = 50, max = 90 }), ["BIT LOW"] = logicview.dict({ min = 45, max = 90 }), ["BIT 0 HIGH"] = logicview.dict({ min = 20, max = 35 }), ["BIT 1 HIGH"] = logicview.dict({ min = 65, max = 80 }) })
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "am230x",
  name = "AM230x",
  longname = "Aosong AM230x/DHTxx/RHTxx",
  desc = "Aosong AM230x/DHTxx/RHTxx humidity/temperature sensor.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "Sensor" },
  channels = { logicview.dict({ id = "sda", name = "SDA", desc = "Single wire serial data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "device", desc = "Device type", default = "am230x", values = { "am230x/rht", "dht11" } }) },
  annotations = { { "start", "Start" }, { "response", "Response" }, { "bit", "Bit" }, { "end", "End" }, { "byte", "Byte" }, { "humidity", "Relative humidity in percent" }, { "temperature", "Temperature in degrees Celsius" }, { "checksum", "Checksum" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3 } }, { "bytes", "Bytes", { 4 } }, { "results", "Results", { 5, 6, 7 } } },
  binary = {  }
}
function _decoder.putfs(self, data)
  self:put(self.fall, self.samplenum, self.out_ann, data)
end
function _decoder.putb(self, data)
  self:put(logicview.idx(self.bytepos, (-1)), self.samplenum, self.out_ann, data)
end
function _decoder.putv(self, data)
  self:put(logicview.idx(self.bytepos, (-2)), self.samplenum, self.out_ann, data)
end
function _decoder.reset_variables(self)
  self.state = "WAIT FOR START LOW"
  self.fall = 0
  self.rise = 0
  self.bits = {  }
  self.bytepos = {  }
end
function _decoder.is_valid(self, name)
  local dt
  dt = 0
  if logicview.truth(logicview.endswith(name, "LOW")) then
    dt = (self.samplenum - self.fall)
  elseif logicview.truth(logicview.endswith(name, "HIGH")) then
    dt = (self.samplenum - self.rise)
  end
  if logicview.truth((function()
  local _v
  _v = (dt >= logicview.idx(logicview.idx(self.cnt, name), "min"))
  if not logicview.truth(_v) then return _v end
  _v = (dt <= logicview.idx(logicview.idx(self.cnt, name), "max"))
  return _v
end)()) then
    return true
  end
  return false
end
function _decoder.bits2num(self, bitlist)
  local number, i
  number = 0
  for _lv_i in logicview.range(logicview.len(bitlist)) do
    i = _lv_i
    number = logicview.add(number, logicview.mul(logicview.idx(bitlist, ((-1) - i)), (2 ^ i)))
    ::continue_1::
  end
  return number
end
function _decoder.calculate_humidity(self, bitlist)
  local h
  h = 0
  if logicview.truth(logicview.eq(logicview.idx(self.options, "device"), "dht11")) then
    h = self:bits2num(logicview.slice(bitlist, 0, 8, nil))
  else
    h = (self:bits2num(bitlist) / 10)
  end
  return h
end
function _decoder.calculate_temperature(self, bitlist)
  local t
  t = 0
  if logicview.truth(logicview.eq(logicview.idx(self.options, "device"), "dht11")) then
    t = self:bits2num(logicview.slice(bitlist, 0, 8, nil))
  else
    t = (self:bits2num(logicview.slice(bitlist, 1, nil, nil)) / 10)
    if logicview.truth(logicview.eq(logicview.idx(bitlist, 0), 1)) then
      t = (-t)
    end
  end
  return t
end
function _decoder.calculate_checksum(self, bitlist)
  local checksum, i
  checksum = 0
  for _lv_i in logicview.range(8, logicview.add(logicview.len(bitlist), 1), 8) do
    i = _lv_i
    checksum = logicview.add(checksum, self:bits2num(logicview.slice(bitlist, (i - 8), i, nil)))
    ::continue_2::
  end
  return logicview.pymod(checksum, 256)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self:reset_variables()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  local e, t
  if logicview.truth((not logicview.eq(key, logicview.SRD_CONF_SAMPLERATE))) then
    return
  end
  self.samplerate = value
  self.cnt = logicview.dict({  })
  for _lv_item in logicview.iter(timing) do
    e = _lv_item
    logicview.setidx(self.cnt, e, logicview.dict({  }))
    for _lv_item in logicview.iter(logicview.idx(timing, e)) do
      t = _lv_item
      logicview.setidx(logicview.idx(self.cnt, e), t, (logicview.mul(logicview.idx(logicview.idx(timing, e), t), self.samplerate) / 1000000))
      ::continue_4::
    end
    ::continue_3::
  end
end
function _decoder.handle_byte(self, bit)
  local byte, h, t, parity
  _table.insert(self.bits, bit)
  self:putfs({ 2, { logicview.pymod("Bit: %d", bit), logicview.pymod("%d", bit) } })
  self.fall = self.samplenum
  self.state = "WAIT FOR BIT HIGH"
  if logicview.truth(logicview.eq(logicview.pymod(logicview.len(self.bits), 8), 0)) then
    byte = self:bits2num(logicview.slice(self.bits, (-8), nil, nil))
    self:putb({ 4, { logicview.pymod("Byte: %#04x", byte), logicview.pymod("%#04x", byte) } })
    if logicview.truth(logicview.eq(logicview.len(self.bits), 16)) then
      h = self:calculate_humidity(logicview.slice(self.bits, (-16), nil, nil))
      self:putv({ 5, { logicview.pymod("Humidity: %.1f %%", h), logicview.pymod("RH = %.1f %%", h) } })
    elseif logicview.truth(logicview.eq(logicview.len(self.bits), 32)) then
      t = self:calculate_temperature(logicview.slice(self.bits, (-16), nil, nil))
      self:putv({ 6, { logicview.pymod("Temperature: %.1f °C", t), logicview.pymod("T = %.1f °C", t) } })
    elseif logicview.truth(logicview.eq(logicview.len(self.bits), 40)) then
      parity = self:bits2num(logicview.slice(self.bits, (-8), nil, nil))
      if logicview.truth(logicview.eq(parity, self:calculate_checksum(logicview.slice(self.bits, 0, 32, nil)))) then
        self:putb({ 7, { "Checksum: OK", "OK" } })
      else
        self:putb({ 7, { "Checksum: not OK", "NOK" } })
      end
      self.state = "WAIT FOR END"
    end
    _table.insert(self.bytepos, self.samplenum)
  end
end
function _decoder.decode(self)
  local bit
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    if logicview.truth(logicview.eq(self.state, "WAIT FOR START LOW")) then
      self:wait(logicview.dict({ [0] = "f" }))
      self.fall = self.samplenum
      self.state = "WAIT FOR START HIGH"
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR START HIGH")) then
      self:wait(logicview.dict({ [0] = "r" }))
      if logicview.truth(self:is_valid("START LOW")) then
        self.rise = self.samplenum
        self.state = "WAIT FOR RESPONSE LOW"
      else
        self:reset_variables()
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR RESPONSE LOW")) then
      self:wait(logicview.dict({ [0] = "f" }))
      if logicview.truth(self:is_valid("START HIGH")) then
        self:putfs({ 0, { "Start", "S" } })
        self.fall = self.samplenum
        self.state = "WAIT FOR RESPONSE HIGH"
      else
        self:reset_variables()
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR RESPONSE HIGH")) then
      self:wait(logicview.dict({ [0] = "r" }))
      if logicview.truth(self:is_valid("RESPONSE LOW")) then
        self.rise = self.samplenum
        self.state = "WAIT FOR FIRST BIT"
      else
        self:reset_variables()
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR FIRST BIT")) then
      self:wait(logicview.dict({ [0] = "f" }))
      if logicview.truth(self:is_valid("RESPONSE HIGH")) then
        self:putfs({ 1, { "Response", "R" } })
        self.fall = self.samplenum
        _table.insert(self.bytepos, self.samplenum)
        self.state = "WAIT FOR BIT HIGH"
      else
        self:reset_variables()
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR BIT HIGH")) then
      self:wait(logicview.dict({ [0] = "r" }))
      if logicview.truth(self:is_valid("BIT LOW")) then
        self.rise = self.samplenum
        self.state = "WAIT FOR BIT LOW"
      else
        self:reset_variables()
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR BIT LOW")) then
      self:wait(logicview.dict({ [0] = "f" }))
      if logicview.truth(self:is_valid("BIT 0 HIGH")) then
        bit = 0
      elseif logicview.truth(self:is_valid("BIT 1 HIGH")) then
        bit = 1
      else
        self:reset_variables()
        goto continue_5
      end
      self:handle_byte(bit)
    elseif logicview.truth(logicview.eq(self.state, "WAIT FOR END")) then
      self:wait(logicview.dict({ [0] = "r" }))
      self:putfs({ 3, { "End", "E" } })
      self:reset_variables()
    end
    ::continue_5::
  end
end

return _decoder
