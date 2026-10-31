-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2010-2014 Uwe Hermann <uwe@hermann-uwe.de>

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
  id = "nunchuk",
  name = "Nunchuk",
  longname = "Nintendo Wii Nunchuk",
  desc = "Nintendo Wii Nunchuk controller protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "reg-0x00", "Register 0x00" }, { "reg-0x01", "Register 0x01" }, { "reg-0x02", "Register 0x02" }, { "reg-0x03", "Register 0x03" }, { "reg-0x04", "Register 0x04" }, { "reg-0x05", "Register 0x05" }, { "bit-bz", "BZ bit" }, { "bit-bc", "BC bit" }, { "bit-ax", "AX bits" }, { "bit-ay", "AY bits" }, { "bit-az", "AZ bits" }, { "nunchuk-write", "Nunchuk write" }, { "cmd-init", "Init command" }, { "summary", "Summary" }, { "warnings", "Warnings" } },
  annotation_rows = { { "regs", "Registers", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 } }, { "summary", "Summary", { 13 } }, { "warnings", "Warnings", { 14 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  do
    local _lv_chain = (-1)
    self.sx = _lv_chain
    self.sy = _lv_chain
    self.ax = _lv_chain
    self.ay = _lv_chain
    self.az = _lv_chain
    self.bz = _lv_chain
    self.bc = _lv_chain
  end
  self.databytecount = 0
  self.reg = 0
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
  self.init_seq = {  }
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
function _decoder.putd(self, bit1, bit2, data)
  self:put(logicview.idx(logicview.idx(self.bits, bit1), 1), logicview.idx(logicview.idx(self.bits, bit2), 2), self.out_ann, data)
end
function _decoder.handle_reg_0x00(self, databyte)
  self.ss_block = self.ss
  self.sx = databyte
  self:putx({ 0, { logicview.pymod("Analog stick X position: 0x%02X", self.sx), logicview.pymod("SX: 0x%02X", self.sx) } })
end
function _decoder.handle_reg_0x01(self, databyte)
  self.sy = databyte
  self:putx({ 1, { logicview.pymod("Analog stick Y position: 0x%02X", self.sy), logicview.pymod("SY: 0x%02X", self.sy) } })
end
function _decoder.handle_reg_0x02(self, databyte)
  self.ax = (databyte << 2)
  self:putx({ 2, { logicview.pymod("Accelerometer X value bits[9:2]: 0x%03X", self.ax), logicview.pymod("AX[9:2]: 0x%03X", self.ax) } })
end
function _decoder.handle_reg_0x03(self, databyte)
  self.ay = (databyte << 2)
  self:putx({ 3, { logicview.pymod("Accelerometer Y value bits[9:2]: 0x%03X", self.ay), logicview.pymod("AY[9:2]: 0x%03X", self.ay) } })
end
function _decoder.handle_reg_0x04(self, databyte)
  self.az = (databyte << 2)
  self:putx({ 4, { logicview.pymod("Accelerometer Z value bits[9:2]: 0x%03X", self.az), logicview.pymod("AZ[9:2]: 0x%03X", self.az) } })
end
function _decoder.handle_reg_0x05(self, databyte)
  local ax_rest, ay_rest, az_rest, s
  self.es_block = self.es
  self.bz = ((databyte & (1 << 0)) >> 0)
  self.bc = ((databyte & (1 << 1)) >> 1)
  ax_rest = ((databyte & (3 << 2)) >> 2)
  ay_rest = ((databyte & (3 << 4)) >> 4)
  az_rest = ((databyte & (3 << 6)) >> 6)
  self.ax = (self.ax | ax_rest)
  self.ay = (self.ay | ay_rest)
  self.az = (self.az | az_rest)
  s = (function() if logicview.truth(logicview.eq(self.bz, 0)) then return "" else return "not " end end)()
  self:putd(0, 0, { 6, { logicview.pymod("Z: %spressed", s), logicview.pymod("BZ: %d", self.bz) } })
  s = (function() if logicview.truth(logicview.eq(self.bc, 0)) then return "" else return "not " end end)()
  self:putd(1, 1, { 7, { logicview.pymod("C: %spressed", s), logicview.pymod("BC: %d", self.bc) } })
  self:putd(3, 2, { 8, { logicview.pymod("Accelerometer X value bits[1:0]: 0x%X", ax_rest), logicview.pymod("AX[1:0]: 0x%X", ax_rest) } })
  self:putd(5, 4, { 9, { logicview.pymod("Accelerometer Y value bits[1:0]: 0x%X", ay_rest), logicview.pymod("AY[1:0]: 0x%X", ay_rest) } })
  self:putd(7, 6, { 10, { logicview.pymod("Accelerometer Z value bits[1:0]: 0x%X", az_rest), logicview.pymod("AZ[1:0]: 0x%X", az_rest) } })
  self.reg = 0
end
function _decoder.output_full_block_if_possible(self)
  local t, bz, bc, s
  t = { self.sx, self.sy, self.ax, self.ay, self.az, self.bz, self.bc }
  if logicview.truth(logicview.contains(t, (-1))) then
    return
  end
  bz = (function() if logicview.truth(logicview.eq(self.bz, 0)) then return "pressed" else return "not pressed" end end)()
  bc = (function() if logicview.truth(logicview.eq(self.bc, 0)) then return "pressed" else return "not pressed" end end)()
  s = logicview.pymod("Analog stick: %d/%d, accelerometer: %d/%d/%d, Z: %s, C: %s", { self.sx, self.sy, self.ax, self.ay, self.az, bz, bc })
  self:putb({ 13, { s } })
end
function _decoder.handle_reg_write(self, databyte)
  self:putx({ 11, { logicview.pymod("Nunchuk write: 0x%02X", databyte) } })
  if logicview.truth((logicview.len(self.init_seq) < 2)) then
    _table.insert(self.init_seq, databyte)
  end
end
function _decoder.output_init_seq(self)
  if logicview.truth((not logicview.eq(logicview.len(self.init_seq), 2))) then
    self:putb({ 14, { logicview.pymod("Init sequence was %d bytes long (2 expected)", logicview.len(self.init_seq)) } })
    return
  end
  if logicview.truth((not logicview.eq(self.init_seq, { 64, 0 }))) then
    self:putb({ 14, { "Unknown init sequence (expected: 0x40 0x00)" } })
    return
  end
  self:putb({ 12, { "Initialize Nunchuk", "Init Nunchuk", "Init", "I" } })
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
    if logicview.truth(logicview.eq(cmd, "BITS")) then
      self.bits = databyte
      return
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
      self.ss_block = ss
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "READ REGS"
      elseif logicview.truth(logicview.eq(cmd, "ADDRESS WRITE")) then
        self.state = "WRITE REGS"
      end
    elseif logicview.truth(logicview.eq(self.state, "READ REGS")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
        self.reg = logicview.add(self.reg, 1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.es_block = es
        self:output_full_block_if_possible()
        do
          local _lv_chain = (-1)
          self.sx = _lv_chain
          self.sy = _lv_chain
          self.ax = _lv_chain
          self.ay = _lv_chain
          self.az = _lv_chain
        end
        do
          local _lv_chain = (-1)
          self.bz = _lv_chain
          self.bc = _lv_chain
        end
        self.state = "IDLE"
      else
      end
    elseif logicview.truth(logicview.eq(self.state, "WRITE REGS")) then
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        self:handle_reg_write(databyte)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.es_block = es
        self:output_init_seq()
        self.init_seq = {  }
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
