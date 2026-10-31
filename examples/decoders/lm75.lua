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
local resolution, ft, Decoder
local _decoder

resolution = logicview.dict({ [0] = 9, [1] = 10, [2] = 11, [3] = 12 })
ft = logicview.dict({ [0] = 1, [1] = 2, [2] = 4, [3] = 6 })
_decoder = {
  api_version = 3,
  id = "lm75",
  name = "LM75",
  longname = "National LM75",
  desc = "National LM75 (and compatibles) temperature sensor.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "sensor", desc = "Sensor type", default = "lm75", values = { "lm75" } }), logicview.dict({ id = "resolution", desc = "Resolution (bits)", default = 9, values = { 9, 10, 11, 12 } }) },
  annotations = { { "celsius", "Temperature in degrees Celsius" }, { "kelvin", "Temperature in Kelvin" }, { "text-verbose", "Human-readable text (verbose)" }, { "text", "Human-readable text" }, { "warnings", "Human-readable warnings" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.reg = 0
  self.databytes = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.warn_upon_invalid_slave(self, addr)
  local s
  if logicview.truth((not logicview.contains((function() local _t = {}; for _v in logicview.range(72, logicview.add(79, 1)) do _t[#_t + 1] = _v end; return _t end)(), addr))) then
    s = "Warning: I²C slave 0x%02x not an LM75 compatible sensor."
    self:putx({ 4, { logicview.pymod(s, addr) } })
  end
end
function _decoder.output_temperature(self, s, rw)
  local before, after, celsius, kelvin
  do
    local _lv_a0, _lv_a1 = logicview.idx(self.databytes, 0), logicview.mul((logicview.idx(self.databytes, 1) >> 7), 5)
    before = _lv_a0
    after = _lv_a1
  end
  celsius = (_tonumber(logicview.pymod("%d.%d", { before, after })) or 0)
  kelvin = logicview.add(celsius, 273.15)
  self:putb({ 0, { logicview.pymod("%s: %.1f °C", { s, celsius }) } })
  self:putb({ 1, { logicview.pymod("%s: %.1f K", { s, kelvin }) } })
  if logicview.truth((function()
  local _v
  _v = logicview.eq(s, "Temperature")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(rw, "WRITE")
  return _v
end)()) then
    s = "Warning: The temperature register is read-only!"
    self:putb({ 4, { s } })
  end
end
function _decoder.handle_temperature_reg(self, b, s, rw)
  if logicview.truth(logicview.eq(logicview.len(self.databytes), 0)) then
    self.ss_block = self.ss
    _table.insert(self.databytes, b)
    return
  end
  _table.insert(self.databytes, b)
  self.es_block = self.es
  self:output_temperature(s, rw)
  self.databytes = {  }
end
function _decoder.handle_reg_0x00(self, b, rw)
  self:handle_temperature_reg(b, "Temperature", rw)
end
function _decoder.handle_reg_0x01(self, b, rw)
  local sd, tmp, s, s2, cmp_int, pol, bits
  sd = (b & (1 << 0))
  tmp = (function() if logicview.truth(logicview.eq(sd, 0)) then return "normal operation" else return "shutdown mode" end end)()
  s = logicview.pymod("SD = %d: %s\n", { sd, tmp })
  s2 = logicview.pymod("SD = %s, ", tmp)
  cmp_int = (b & (1 << 1))
  tmp = (function() if logicview.truth(logicview.eq(cmp_int, 0)) then return "comparator" else return "interrupt" end end)()
  s = logicview.add(s, logicview.pymod("CMP/INT = %d: %s mode\n", { cmp_int, tmp }))
  s2 = logicview.add(s2, logicview.pymod("CMP/INT = %s, ", tmp))
  pol = (b & (1 << 2))
  tmp = (function() if logicview.truth(logicview.eq(pol, 0)) then return "low" else return "high" end end)()
  s = logicview.add(s, logicview.pymod("POL = %d: OS polarity is active-%s\n", { pol, tmp }))
  s2 = logicview.add(s2, logicview.pymod("POL = active-%s, ", tmp))
  bits = ((b & ((1 << 4) | (1 << 3))) >> 3)
  s = logicview.add(s, logicview.pymod("Fault tolerance setting: %d bit(s)\n", logicview.idx(ft, bits)))
  s2 = logicview.add(s2, logicview.pymod("FT = %d", logicview.idx(ft, bits)))
  if logicview.truth((not logicview.eq(logicview.idx(self.options, "sensor"), "lm75"))) then
    bits = ((b & ((1 << 6) | (1 << 5))) >> 5)
    s = logicview.add(s, logicview.pymod("Resolution: %d bits\n", logicview.idx(resolution, bits)))
    s2 = logicview.add(s2, logicview.pymod(", resolution = %d", logicview.idx(resolution, bits)))
  end
  self:putx({ 2, { s } })
  self:putx({ 3, { s2 } })
end
function _decoder.handle_reg_0x02(self, b, rw)
  self:handle_temperature_reg(b, "T_HYST trip temperature", rw)
end
function _decoder.handle_reg_0x03(self, b, rw)
  self:handle_temperature_reg(b, "T_OS trip temperature", rw)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, handle_reg
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
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth((not logicview.eq(cmd, "START"))) then
        return
      end
      self.state = "GET SLAVE ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth(logicview.contains({ "ADDRESS READ", "ADDRESS WRITE" }, cmd)) then
        self:warn_upon_invalid_slave(databyte)
        self.state = logicview.add(logicview.slice(cmd, 8, nil, nil), " REGS")
      end
    elseif logicview.truth(logicview.contains({ "READ REGS", "WRITE REGS" }, self.state)) then
      if logicview.truth(logicview.contains({ "DATA READ", "DATA WRITE" }, cmd)) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte, logicview.slice(cmd, 5, nil, nil))
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
      else
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
