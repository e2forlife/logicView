-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Mickael Bosch <mickael.bosch@linux.com>

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
    _table.insert(l, logicview.copy({ logicview.pymod("p%d", i), logicview.pymod("P%d", i) }))
    ::continue_1::
  end
  return logicview.copy(l)
end
_decoder = {
  api_version = 3,
  id = "pca9571",
  name = "PCA9571",
  longname = "NXP PCA9571",
  desc = "NXP PCA9571 8-bit I²C output expander.",
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
  self.last_write = 255
  self.last_write_es = 0
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
  if logicview.truth((self.es > self.last_write_es)) then
    data = logicview.bytes({ self.last_write })
    self:put(self.last_write_es, self.es, self.out_logic, { 0, data })
    self.last_write_es = self.es
  end
end
function _decoder.handle_io(self, b)
  local operation
  if logicview.truth(logicview.eq(self.state, "READ DATA")) then
    operation = { "Outputs read", "R" }
    if logicview.truth((not logicview.eq(b, self.last_write))) then
      self:putx({ 2, { logicview.pymod("Warning: read value and last write value (%02X) are different", self.last_write) } })
    end
  else
    operation = { "Outputs set", "W" }
    self:put_logic_states()
    self.last_write = b
  end
  self:putx({ 1, { logicview.add(logicview.idx(operation, 0), logicview.pymod(": %02X", b)), logicview.add(logicview.idx(operation, 1), logicview.pymod(": %02X", b)) } })
end
function _decoder.check_correct_chip(self, addr)
  if logicview.truth((not logicview.eq(addr, 37))) then
    self:putx({ 2, { logicview.pymod("Warning: I²C slave 0x%02X not a PCA9571 compatible chip.", addr) } })
    return false
  end
  return true
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
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.contains({ "ACK", "BITS" }, cmd)) then
    elseif logicview.truth(logicview.contains({ "START", "START REPEAT" }, cmd)) then
      self.state = "GET SLAVE ADDR"
    elseif logicview.truth(logicview.contains({ "NACK", "STOP" }, cmd)) then
      self.state = "IDLE"
    elseif logicview.truth(logicview.contains({ "ADDRESS READ", "ADDRESS WRITE" }, cmd)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "GET SLAVE ADDR")
  if not logicview.truth(_v) then return _v end
  _v = self:check_correct_chip(databyte)
  return _v
end)()) then
        if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
          self.state = "READ DATA"
        else
          self.state = "WRITE DATA"
        end
      else
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.contains({ "DATA READ", "DATA WRITE" }, cmd)) then
      if logicview.truth(logicview.contains({ "READ DATA", "WRITE DATA" }, self.state)) then
        self:handle_io(databyte)
      else
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
