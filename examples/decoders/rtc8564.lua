-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>

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
local bcd2int, reg_list, Decoder
local _decoder

bcd2int = logicview.bcd2int
reg_list = function()
  local l, i
  l = {  }
  for _lv_i in logicview.range(logicview.add(8, 1)) do
    i = _lv_i
    _table.insert(l, { logicview.pymod("reg-0x%02x", i), logicview.pymod("Register 0x%02x", i) })
    ::continue_1::
  end
  return logicview.copy(l)
end
_decoder = {
  api_version = 3,
  id = "rtc8564",
  name = "RTC-8564",
  longname = "Epson RTC-8564 JE/NB",
  desc = "Realtime clock module protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Clock/timing" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "reg-0x00", "Register 0x00" }, { "reg-0x01", "Register 0x01" }, { "reg-0x02", "Register 0x02" }, { "reg-0x03", "Register 0x03" }, { "reg-0x04", "Register 0x04" }, { "reg-0x05", "Register 0x05" }, { "reg-0x06", "Register 0x06" }, { "reg-0x07", "Register 0x07" }, { "reg-0x08", "Register 0x08" }, { "read", "Read date/time" }, { "write", "Write date/time" }, { "bit-reserved", "Reserved bit" }, { "bit-vl", "VL bit" }, { "bit-century", "Century bit" }, { "reg-read", "Register read" }, { "reg-write", "Register write" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13 } }, { "regs", "Register access", { 14, 15 } }, { "date-time", "Date/time", { 9, 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.hours = (-1)
  self.minutes = (-1)
  self.seconds = (-1)
  self.days = (-1)
  self.weekdays = (-1)
  self.months = (-1)
  self.years = (-1)
  self.bits = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putd(self, bit1, bit2, data)
  self:put(logicview.idx(logicview.idx(self.bits, bit1), 1), logicview.idx(logicview.idx(self.bits, bit2), 2), self.out_ann, data)
end
function _decoder.putr(self, bit)
  self:put(logicview.idx(logicview.idx(self.bits, bit), 1), logicview.idx(logicview.idx(self.bits, bit), 2), self.out_ann, { 11, { "Reserved bit", "Reserved", "Rsvd", "R" } })
end
function _decoder.handle_reg_0x00(self, b)
end
function _decoder.handle_reg_0x01(self, b)
  local ti_tp, af, tf, aie, tie, ann, s
  ti_tp = (function() if logicview.truth((b & (1 << 4))) then return 1 else return 0 end end)()
  af = (function() if logicview.truth((b & (1 << 3))) then return 1 else return 0 end end)()
  tf = (function() if logicview.truth((b & (1 << 2))) then return 1 else return 0 end end)()
  aie = (function() if logicview.truth((b & (1 << 1))) then return 1 else return 0 end end)()
  tie = (function() if logicview.truth((b & (1 << 0))) then return 1 else return 0 end end)()
  ann = ""
  s = (function() if logicview.truth(ti_tp) then return "repeated" else return "single-shot" end end)()
  ann = logicview.add(ann, logicview.pymod("TI/TP = %d: %s operation upon fixed-cycle timer interrupt events\n", { ti_tp, s }))
  s = (function() if logicview.truth(af) then return "" else return "no " end end)()
  ann = logicview.add(ann, logicview.pymod("AF = %d: %salarm interrupt detected\n", { af, s }))
  s = (function() if logicview.truth(tf) then return "" else return "no " end end)()
  ann = logicview.add(ann, logicview.pymod("TF = %d: %sfixed-cycle timer interrupt detected\n", { tf, s }))
  s = (function() if logicview.truth(aie) then return "enabled" else return "prohibited" end end)()
  ann = logicview.add(ann, logicview.pymod("AIE = %d: INT# pin output %s when an alarm interrupt occurs\n", { aie, s }))
  s = (function() if logicview.truth(tie) then return "enabled" else return "prohibited" end end)()
  ann = logicview.add(ann, logicview.pymod("TIE = %d: INT# pin output %s when a fixed-cycle interrupt event occurs\n", { tie, s }))
  self:putx({ 1, { ann } })
end
function _decoder.handle_reg_0x02(self, b)
  local vl, s
  vl = (function() if logicview.truth((b & (1 << 7))) then return 1 else return 0 end end)()
  self:putd(7, 7, { 12, { logicview.pymod("Voltage low: %d", vl), logicview.pymod("Volt. low: %d", vl), logicview.pymod("VL: %d", vl), "VL" } })
  do
    local _lv_chain = bcd2int((b & 127))
    s = _lv_chain
    self.seconds = _lv_chain
  end
  self:putd(6, 0, { 2, { logicview.pymod("Second: %d", s), logicview.pymod("Sec: %d", s), logicview.pymod("S: %d", s), "S" } })
end
function _decoder.handle_reg_0x03(self, b)
  local m
  self:putr(7)
  do
    local _lv_chain = bcd2int((b & 127))
    m = _lv_chain
    self.minutes = _lv_chain
  end
  self:putd(6, 0, { 3, { logicview.pymod("Minute: %d", m), logicview.pymod("Min: %d", m), logicview.pymod("M: %d", m), "M" } })
end
function _decoder.handle_reg_0x04(self, b)
  local h
  self:putr(7)
  self:putr(6)
  do
    local _lv_chain = bcd2int((b & 63))
    h = _lv_chain
    self.hours = _lv_chain
  end
  self:putd(5, 0, { 4, { logicview.pymod("Hour: %d", h), logicview.pymod("H: %d", h), "H" } })
end
function _decoder.handle_reg_0x05(self, b)
  local d
  self:putr(7)
  self:putr(6)
  do
    local _lv_chain = bcd2int((b & 63))
    d = _lv_chain
    self.days = _lv_chain
  end
  self:putd(5, 0, { 5, { logicview.pymod("Day: %d", d), logicview.pymod("D: %d", d), "D" } })
end
function _decoder.handle_reg_0x06(self, b)
  local i, w
  for _lv_item in logicview.iter({ 7, 6, 5, 4, 3 }) do
    i = _lv_item
    self:putr(i)
    ::continue_2::
  end
  do
    local _lv_chain = bcd2int((b & 7))
    w = _lv_chain
    self.weekdays = _lv_chain
  end
  self:putd(2, 0, { 6, { logicview.pymod("Weekday: %d", w), logicview.pymod("WD: %d", w), "WD", "W" } })
end
function _decoder.handle_reg_0x07(self, b)
  local c, m
  c = (function() if logicview.truth((b & (1 << 7))) then return 1 else return 0 end end)()
  self:putd(7, 7, { 13, { logicview.pymod("Century bit: %d", c), logicview.pymod("Century: %d", c), logicview.pymod("Cent: %d", c), logicview.pymod("C: %d", c), "C" } })
  self:putr(6)
  self:putr(5)
  do
    local _lv_chain = bcd2int((b & 31))
    m = _lv_chain
    self.months = _lv_chain
  end
  self:putd(4, 0, { 7, { logicview.pymod("Month: %d", m), logicview.pymod("Mon: %d", m), logicview.pymod("M: %d", m), "M" } })
end
function _decoder.handle_reg_0x08(self, b)
  local y
  do
    local _lv_chain = bcd2int((b & 255))
    y = _lv_chain
    self.years = _lv_chain
  end
  self:putx({ 8, { logicview.pymod("Year: %d", y), logicview.pymod("Y: %d", y), "Y" } })
end
function _decoder.handle_reg_0x09(self, b)
end
function _decoder.handle_reg_0x0a(self, b)
end
function _decoder.handle_reg_0x0b(self, b)
end
function _decoder.handle_reg_0x0c(self, b)
end
function _decoder.handle_reg_0x0d(self, b)
end
function _decoder.handle_reg_0x0e(self, b)
end
function _decoder.handle_reg_0x0f(self, b)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, r, s, handle_reg, d
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
      if logicview.truth((not logicview.eq(cmd, "ADDRESS WRITE"))) then
        return
      end
      self.state = "GET REG ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET REG ADDR")) then
      if logicview.truth((not logicview.eq(cmd, "DATA WRITE"))) then
        return
      end
      self.reg = databyte
      self.state = "WRITE RTC REGS"
    elseif logicview.truth(logicview.eq(self.state, "WRITE RTC REGS")) then
      if logicview.truth(logicview.eq(cmd, "START REPEAT")) then
        self.state = "READ RTC REGS"
        return
      end
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        do
          local _lv_a0, _lv_a1 = self.reg, logicview.pymod("%02X: %02X", { self.reg, databyte })
          r = _lv_a0
          s = _lv_a1
        end
        self:putx({ 15, { logicview.pymod("Write register %s", s), logicview.pymod("Write reg %s", s), logicview.pymod("WR %s", s), "WR", "W" } })
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
        self.reg = logicview.add(self.reg, 1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        d = logicview.pymod("%02d.%02d.%02d %02d:%02d:%02d", { self.days, self.months, self.years, self.hours, self.minutes, self.seconds })
        self:put(self.ss_block, es, self.out_ann, { 9, { logicview.pymod("Write date/time: %s", d), logicview.pymod("Write: %s", d), logicview.pymod("W: %s", d) } })
        self.state = "IDLE"
      else
      end
    elseif logicview.truth(logicview.eq(self.state, "READ RTC REGS")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "READ RTC REGS2"
        return
      else
      end
    elseif logicview.truth(logicview.eq(self.state, "READ RTC REGS2")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        do
          local _lv_a0, _lv_a1 = self.reg, logicview.pymod("%02X: %02X", { self.reg, databyte })
          r = _lv_a0
          s = _lv_a1
        end
        self:putx({ 15, { logicview.pymod("Read register %s", s), logicview.pymod("Read reg %s", s), logicview.pymod("RR %s", s), "RR", "R" } })
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
        self.reg = logicview.add(self.reg, 1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        d = logicview.pymod("%02d.%02d.%02d %02d:%02d:%02d", { self.days, self.months, self.years, self.hours, self.minutes, self.seconds })
        self:put(self.ss_block, es, self.out_ann, { 10, { logicview.pymod("Read date/time: %s", d), logicview.pymod("Read: %s", d), logicview.pymod("R: %s", d) } })
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
