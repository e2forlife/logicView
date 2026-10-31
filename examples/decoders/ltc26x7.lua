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
local slave_address, commands, addresses, input_voltage_format, Decoder
local _decoder

slave_address = logicview.dict({ [0] = { "GND", "GND", "GND", "G" }, [1] = { "FLOAT", "FLOAT", "FLOAT", "F" }, [2] = { "VCC", "VCC", "VCC", "V" } })
commands = logicview.dict({ [0] = { "Write Input Register", "Write In Reg", "Wr In Reg", "WIR" }, [1] = { "Update DAC", "Update", "U" }, [3] = { "Write and Power Up DAC", "Write & Power Up", "W&PU" }, [4] = { "Power Down DAC", "Power Down", "PD" }, [15] = { "No Operation", "No Op", "NO" } })
addresses = logicview.dict({ [0] = { "DAC A", "A" }, [1] = { "DAC B", "B" }, [15] = { "All DACs", "All" } })
input_voltage_format = { "%.6fV", "%.2fV" }
_decoder = {
  api_version = 3,
  id = "ltc26x7",
  name = "LTC26x7",
  longname = "Linear Technology LTC26x7",
  desc = "Linear Technology LTC26x7 16-/14-/12-bit rail-to-rail DACs.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "IC", "Analog/digital" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "chip", desc = "Chip", default = "ltc2607", values = { "ltc2607", "ltc2617", "ltc2627" } }), logicview.dict({ id = "vref", desc = "Reference voltage (V)", default = 1.5, values = {  } }) },
  annotations = { { "slave_addr", "Slave address" }, { "command", "Command" }, { "address", "Address" }, { "dac_a_voltage", "DAC A voltage" }, { "dac_b_voltage", "DAC B voltage" } },
  annotation_rows = { { "addr_cmd", "Address/command", { 0, 1, 2 } }, { "dac_a_voltages", "DAC A voltages", { 3 } }, { "dac_b_voltages", "DAC B voltages", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.ss = (-1)
  self.data = 0
  self.dac_val = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.convert_ternary_str(self, n)
  local nums, r
  if logicview.truth(logicview.eq(n, 0)) then
    return { 0, 0, 0 }
  end
  nums = {  }
  while logicview.truth(n) do
    do
      local _lv_seq = (function() local _q = logicview.floordiv(n, 3); return {_q, n - _q * 3} end)()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      n = logicview.idx(_lv_seq, 0)
      r = logicview.idx(_lv_seq, 1)
    end
    _table.insert(nums, r)
    ::continue_1::
  end
  while logicview.truth((logicview.len(nums) < 3)) do
    _table.insert(nums, 0)
    ::continue_2::
  end
  return logicview.copy(logicview.reversed(nums))
end
function _decoder.handle_slave_addr(self, data)
  local ann, addr, i, offset, mask, ternary_values
  if logicview.truth(logicview.eq(data, 115)) then
    ann = { "Global address", "Global addr", "Glob addr", "GA" }
    self:put(self.ss, self.es, self.out_ann, { 0, ann })
    return
  end
  ann = { "CA2=%s CA1=%s CA0=%s", "2=%s 1=%s 0=%s", "%s %s %s", "%s %s %s" }
  addr = 0
  for _lv_i in logicview.range(7) do
    i = _lv_i
    if logicview.truth(logicview.contains({ 2, 3 }, i)) then
      goto continue_3
    end
    offset = i
    if logicview.truth((i > 3)) then
      offset = (offset - 2)
    end
    mask = (1 << i)
    if logicview.truth((data & mask)) then
      mask = (1 << offset)
      addr = (addr | mask)
    end
    ::continue_3::
  end
  addr = (addr - 4)
  ternary_values = self:convert_ternary_str(addr)
  for _lv_i in logicview.range(logicview.len(ann)) do
    i = _lv_i
    logicview.setidx(ann, i, logicview.pymod(logicview.idx(ann, i), { logicview.idx(logicview.idx(slave_address, logicview.idx(ternary_values, 0)), i), logicview.idx(logicview.idx(slave_address, logicview.idx(ternary_values, 1)), i), logicview.idx(logicview.idx(slave_address, logicview.idx(ternary_values, 2)), i) }))
    ::continue_4::
  end
  self:put(self.ss, self.es, self.out_ann, { 0, ann })
end
function _decoder.handle_cmd_addr(self, data)
  local cmd_val, sm
  cmd_val = ((data >> 4) & 15)
  self.dac_val = (data & 15)
  sm = logicview.floordiv(logicview.add(self.ss, self.es), 2)
  self:put(self.ss, sm, self.out_ann, { 1, logicview.idx(commands, cmd_val) })
  self:put(sm, self.es, self.out_ann, { 2, logicview.idx(addresses, self.dac_val) })
end
function _decoder.handle_data(self, data)
  local ann, format
  self.data = ((self.data << 8) & 65280)
  self.data = logicview.add(self.data, data)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "chip"), "ltc2617")) then
    self.data = (self.data >> 2)
    self.data = (logicview.mul(logicview.idx(self.options, "vref"), self.data) / 16383)
  elseif logicview.truth(logicview.eq(logicview.idx(self.options, "chip"), "ltc2627")) then
    self.data = (self.data >> 4)
    self.data = (logicview.mul(logicview.idx(self.options, "vref"), self.data) / 4095)
  else
    self.data = (logicview.mul(logicview.idx(self.options, "vref"), self.data) / 65535)
  end
  ann = {  }
  for _lv_item in logicview.iter(input_voltage_format) do
    format = _lv_item
    _table.insert(ann, logicview.pymod(format, self.data))
    ::continue_5::
  end
  self.data = 0
  if logicview.truth(logicview.eq(self.dac_val, 15)) then
    self:put(self.ss, self.es, self.out_ann, { logicview.add(3, 0), ann })
    self:put(self.ss, self.es, self.out_ann, { logicview.add(3, 1), ann })
  else
    self:put(self.ss, self.es, self.out_ann, { logicview.add(3, self.dac_val), ann })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte
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
    self.es = es
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth((not logicview.eq(cmd, "START"))) then
        return
      end
      self.state = "GET SLAVE ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth((not logicview.eq(cmd, "ADDRESS WRITE"))) then
        return
      end
      self.ss = ss
      self:handle_slave_addr(databyte)
      self.ss = (-1)
      self.state = "GET CMD ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET CMD ADDR")) then
      if logicview.truth((not logicview.eq(cmd, "DATA WRITE"))) then
        return
      end
      self.ss = ss
      self:handle_cmd_addr(databyte)
      self.ss = (-1)
      self.state = "WRITE DATA"
    elseif logicview.truth(logicview.eq(self.state, "WRITE DATA")) then
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        if logicview.truth(logicview.eq(self.ss, (-1))) then
          self.ss = ss
          self.data = databyte
          return
        end
        self:handle_data(databyte)
        self.ss = (-1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
      else
        return
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
