-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2013 Matt Ranostay <mranostay@gmail.com>
-- Copyright (C) 2014 alberink <alberink@stampfini.org>

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
local NUM_OUTPUT_CHANNELS, logic_channels, Decoder
local _decoder

NUM_OUTPUT_CHANNELS = 8
logic_channels = function(num_channels)
  local l, i
  l = {  }
  for _lv_i in logicview.range(num_channels) do
    i = _lv_i
    _table.insert(l, logicview.copy({ logicview.pymod("p%d", i), logicview.pymod("P-port input/output %d", i) }))
    ::continue_1::
  end
  return logicview.copy(l)
end
_decoder = {
  api_version = 3,
  id = "tca6408a",
  name = "TI TCA6408A",
  longname = "Texas Instruments TCA6408A",
  desc = "Texas Instruments TCA6408A 8-bit I²C I/O expander.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Embedded/industrial", "IC" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "register", "Register type" }, { "value", "Register value" }, { "warning", "Warning" } },
  annotation_rows = { { "regs", "Registers", { 0, 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.chip = (-1)
  self.logic_output_es = 0
  self.logic_value = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_logic = self:register(logicview.OUTPUT_LOGIC)
end
function _decoder.flush(self)
  self:put_logic_states()
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.put_logic_states(self)
  local data
  if logicview.truth((self.es > self.logic_output_es)) then
    data = logicview.bytes({ self.logic_value })
    self:put(self.logic_output_es, self.es, self.out_logic, { 0, data })
    self.logic_output_es = self.es
  end
end
function _decoder.handle_reg_0x00(self, b)
  self:putx({ 1, { logicview.pymod("State of inputs: %02X", b) } })
end
function _decoder.handle_reg_0x01(self, b)
  self:put_logic_states()
  self:putx({ 1, { logicview.pymod("Outputs set: %02X", b) } })
  self.logic_value = b
end
function _decoder.handle_reg_0x02(self, b)
  self:putx({ 1, { logicview.pymod("Polarity inverted: %02X", b) } })
end
function _decoder.handle_reg_0x03(self, b)
  self:putx({ 1, { logicview.pymod("Configuration: %02X", b) } })
end
function _decoder.handle_write_reg(self, b)
  if logicview.truth(logicview.eq(b, 0)) then
    self:putx({ 0, { "Input port", "In", "I" } })
  elseif logicview.truth(logicview.eq(b, 1)) then
    self:putx({ 0, { "Output port", "Out", "O" } })
  elseif logicview.truth(logicview.eq(b, 2)) then
    self:putx({ 0, { "Polarity inversion register", "Pol", "P" } })
  elseif logicview.truth(logicview.eq(b, 3)) then
    self:putx({ 0, { "Configuration register", "Conf", "C" } })
  end
end
function _decoder.check_correct_chip(self, addr)
  if logicview.truth((not logicview.contains({ 32, 33 }, addr))) then
    self:putx({ 2, { logicview.pymod("Warning: I²C slave 0x%02X not a TCA6408A compatible chip.", addr) } })
    self.state = "IDLE"
  end
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
      self.chip = databyte
      self.state = "GET REG ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET REG ADDR")) then
      if logicview.truth(logicview.contains({ "ADDRESS READ", "ADDRESS WRITE" }, cmd)) then
        self:check_correct_chip(databyte)
      end
      if logicview.truth((not logicview.eq(cmd, "DATA WRITE"))) then
        return
      end
      self.reg = databyte
      self:handle_write_reg(self.reg)
      self.state = "WRITE IO REGS"
    elseif logicview.truth(logicview.eq(self.state, "WRITE IO REGS")) then
      if logicview.truth(logicview.eq(cmd, "START REPEAT")) then
        self.state = "READ IO REGS"
        return
      end
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
        self.chip = (-1)
      end
    elseif logicview.truth(logicview.eq(self.state, "READ IO REGS")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "READ IO REGS2"
        self.chip = databyte
        return
      end
    elseif logicview.truth(logicview.eq(self.state, "READ IO REGS2")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
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
