-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2020 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2013 Matt Ranostay <mranostay@gmail.com>

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
local re, bcd2int, SrdIntEnum, days_of_week, regs, bits, rates, DS1307_I2C_ADDRESS, regs_and_bits, a, Ann, Decoder
local _decoder

re = logicview.re
bcd2int = logicview.bcd2int
days_of_week = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
regs = { "Seconds", "Minutes", "Hours", "Day", "Date", "Month", "Year", "Control", "RAM" }
bits = { "Clock halt", "Seconds", "Reserved", "Minutes", "12/24 hours", "AM/PM", "Hours", "Day", "Date", "Month", "Year", "OUT", "SQWE", "RS", "RAM" }
rates = logicview.dict({ [0] = "1Hz", [1] = "4096Hz", [2] = "8192Hz", [3] = "32768Hz" })
DS1307_I2C_ADDRESS = 104
regs_and_bits = function()
  local l
  l = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(regs) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = { logicview.add("reg_", _string.lower(r)), logicview.add(r, " register") }
  end
  return _lv_out
end)()
  l = logicview.add(l, (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(bits) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = { logicview.add("bit_", _string.lower(re.sub("\\/| ", "_", b))), logicview.add(b, " bit") }
  end
  return _lv_out
end)())
  return logicview.copy(l)
end
a = logicview.add(logicview.add((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(regs) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("REG_", _string.upper(r))
  end
  return _lv_out
end)(), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(bits) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("BIT_", _string.upper(re.sub("\\/| ", "_", b)))
  end
  return _lv_out
end)()), { "READ_DATE_TIME", "WRITE_DATE_TIME", "READ_REG", "WRITE_REG", "WARNING" })
Ann = logicview.int_enum(a)
_decoder = {
  api_version = 3,
  id = "ds1307",
  name = "DS1307",
  longname = "Dallas DS1307",
  desc = "Dallas DS1307 realtime clock module protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Clock/timing", "IC" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "reg_seconds", "Seconds register" }, { "reg_minutes", "Minutes register" }, { "reg_hours", "Hours register" }, { "reg_day", "Day register" }, { "reg_date", "Date register" }, { "reg_month", "Month register" }, { "reg_year", "Year register" }, { "reg_control", "Control register" }, { "reg_ram", "RAM register" }, { "bit_clock_halt", "Clock halt bit" }, { "bit_seconds", "Seconds bit" }, { "bit_reserved", "Reserved bit" }, { "bit_minutes", "Minutes bit" }, { "bit_12_24_hours", "12/24 hours bit" }, { "bit_am_pm", "AM/PM bit" }, { "bit_hours", "Hours bit" }, { "bit_day", "Day bit" }, { "bit_date", "Date bit" }, { "bit_month", "Month bit" }, { "bit_year", "Year bit" }, { "bit_out", "OUT bit" }, { "bit_sqwe", "SQWE bit" }, { "bit_rs", "RS bit" }, { "bit_ram", "RAM bit" }, { "read_date_time", "Read date/time" }, { "write_date_time", "Write date/time" }, { "read_reg", "Register read" }, { "write_reg", "Register write" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 } }, { "regs", "Registers", { 0, 1, 2, 3, 4, 5, 6, 7, 8 } }, { "date_time", "Date/time", { 24, 26, 25, 27 } }, { "warnings", "Warnings", { 28 } } },
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
  self.date = (-1)
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
  self:put(logicview.idx(logicview.idx(self.bits, bit), 1), logicview.idx(logicview.idx(self.bits, bit), 2), self.out_ann, { Ann.BIT_RESERVED, { "Reserved bit", "Reserved", "Rsvd", "R" } })
end
function _decoder.handle_reg_0x00(self, b)
  local ch, s
  self:putd(7, 0, { Ann.REG_SECONDS, { "Seconds", "Sec", "S" } })
  ch = (function() if logicview.truth((b & (1 << 7))) then return 1 else return 0 end end)()
  self:putd(7, 7, { Ann.BIT_CLOCK_HALT, { logicview.pymod("Clock halt: %d", ch), logicview.pymod("Clk hlt: %d", ch), logicview.pymod("CH: %d", ch), "CH" } })
  do
    local _lv_chain = bcd2int((b & 127))
    s = _lv_chain
    self.seconds = _lv_chain
  end
  self:putd(6, 0, { Ann.BIT_SECONDS, { logicview.pymod("Second: %d", s), logicview.pymod("Sec: %d", s), logicview.pymod("S: %d", s), "S" } })
end
function _decoder.handle_reg_0x01(self, b)
  local m
  self:putd(7, 0, { Ann.REG_MINUTES, { "Minutes", "Min", "M" } })
  self:putr(7)
  do
    local _lv_chain = bcd2int((b & 127))
    m = _lv_chain
    self.minutes = _lv_chain
  end
  self:putd(6, 0, { Ann.BIT_MINUTES, { logicview.pymod("Minute: %d", m), logicview.pymod("Min: %d", m), logicview.pymod("M: %d", m), "M" } })
end
function _decoder.handle_reg_0x02(self, b)
  local ampm_mode, a, h
  self:putd(7, 0, { Ann.REG_HOURS, { "Hours", "H" } })
  self:putr(7)
  ampm_mode = (function() if logicview.truth((b & (1 << 6))) then return true else return false end end)()
  if logicview.truth(ampm_mode) then
    self:putd(6, 6, { Ann.BIT_12_24_HOURS, { "12-hour mode", "12h mode", "12h" } })
    a = (function() if logicview.truth((b & (1 << 5))) then return "PM" else return "AM" end end)()
    self:putd(5, 5, { Ann.BIT_AM_PM, { a, logicview.idx(a, 0) } })
    do
      local _lv_chain = bcd2int((b & 31))
      h = _lv_chain
      self.hours = _lv_chain
    end
    self:putd(4, 0, { Ann.BIT_HOURS, { logicview.pymod("Hour: %d", h), logicview.pymod("H: %d", h), "H" } })
  else
    self:putd(6, 6, { Ann.BIT_12_24_HOURS, { "24-hour mode", "24h mode", "24h" } })
    do
      local _lv_chain = bcd2int((b & 63))
      h = _lv_chain
      self.hours = _lv_chain
    end
    self:putd(5, 0, { Ann.BIT_HOURS, { logicview.pymod("Hour: %d", h), logicview.pymod("H: %d", h), "H" } })
  end
end
function _decoder.handle_reg_0x03(self, b)
  local i, w, ws
  self:putd(7, 0, { Ann.REG_DAY, { "Day of week", "Day", "D" } })
  for _lv_item in logicview.iter({ 7, 6, 5, 4, 3 }) do
    i = _lv_item
    self:putr(i)
    ::continue_1::
  end
  do
    local _lv_chain = bcd2int((b & 7))
    w = _lv_chain
    self.days = _lv_chain
  end
  ws = logicview.idx(days_of_week, (self.days - 1))
  self:putd(2, 0, { Ann.BIT_DAY, { logicview.pymod("Weekday: %s", ws), logicview.pymod("WD: %s", ws), "WD", "W" } })
end
function _decoder.handle_reg_0x04(self, b)
  local i, d
  self:putd(7, 0, { Ann.REG_DATE, { "Date", "D" } })
  for _lv_item in logicview.iter({ 7, 6 }) do
    i = _lv_item
    self:putr(i)
    ::continue_2::
  end
  do
    local _lv_chain = bcd2int((b & 63))
    d = _lv_chain
    self.date = _lv_chain
  end
  self:putd(5, 0, { Ann.BIT_DATE, { logicview.pymod("Date: %d", d), logicview.pymod("D: %d", d), "D" } })
end
function _decoder.handle_reg_0x05(self, b)
  local i, m
  self:putd(7, 0, { Ann.REG_MONTH, { "Month", "Mon", "M" } })
  for _lv_item in logicview.iter({ 7, 6, 5 }) do
    i = _lv_item
    self:putr(i)
    ::continue_3::
  end
  do
    local _lv_chain = bcd2int((b & 31))
    m = _lv_chain
    self.months = _lv_chain
  end
  self:putd(4, 0, { Ann.BIT_MONTH, { logicview.pymod("Month: %d", m), logicview.pymod("Mon: %d", m), logicview.pymod("M: %d", m), "M" } })
end
function _decoder.handle_reg_0x06(self, b)
  local y
  self:putd(7, 0, { Ann.REG_YEAR, { "Year", "Y" } })
  do
    local _lv_chain = bcd2int((b & 255))
    y = _lv_chain
    self.years = _lv_chain
  end
  self.years = logicview.add(self.years, 2000)
  self:putd(7, 0, { Ann.BIT_YEAR, { logicview.pymod("Year: %d", y), logicview.pymod("Y: %d", y), "Y" } })
end
function _decoder.handle_reg_0x07(self, b)
  local i, o, s, s2, r
  self:putd(7, 0, { Ann.REG_CONTROL, { "Control", "Ctrl", "C" } })
  for _lv_item in logicview.iter({ 6, 5, 3, 2 }) do
    i = _lv_item
    self:putr(i)
    ::continue_4::
  end
  o = (function() if logicview.truth((b & (1 << 7))) then return 1 else return 0 end end)()
  s = (function() if logicview.truth((b & (1 << 4))) then return 1 else return 0 end end)()
  s2 = (function() if logicview.truth((b & (1 << 4))) then return "en" else return "dis" end end)()
  r = logicview.idx(rates, (b & 3))
  self:putd(7, 7, { Ann.BIT_OUT, { logicview.pymod("Output control: %d", o), logicview.pymod("OUT: %d", o), logicview.pymod("O: %d", o), "O" } })
  self:putd(4, 4, { Ann.BIT_SQWE, { logicview.pymod("Square wave output: %sabled", s2), logicview.pymod("SQWE: %sabled", s2), logicview.pymod("SQWE: %d", s), logicview.pymod("S: %d", s), "S" } })
  self:putd(1, 0, { Ann.BIT_RS, { logicview.pymod("Square wave output rate: %s", r), logicview.pymod("Square wave rate: %s", r), logicview.pymod("SQW rate: %s", r), logicview.pymod("Rate: %s", r), logicview.pymod("RS: %s", s), "RS", "R" } })
end
function _decoder.handle_reg_0x3f(self, b)
  self:putd(7, 0, { Ann.REG_RAM, { "RAM", "R" } })
  self:putd(7, 0, { Ann.BIT_RAM, { logicview.pymod("SRAM: 0x%02X", b), logicview.pymod("0x%02X", b) } })
end
function _decoder.output_datetime(self, cls, rw)
  local d
  d = logicview.pymod("%s, %02d.%02d.%4d %02d:%02d:%02d", { logicview.idx(days_of_week, (self.days - 1)), self.date, self.months, self.years, self.hours, self.minutes, self.seconds })
  self:put(self.ss_block, self.es, self.out_ann, { cls, { logicview.pymod("%s date/time: %s", { rw, d }) } })
end
function _decoder.handle_reg(self, b)
  local r, fn
  r = (function() if logicview.truth((self.reg < 8)) then return self.reg else return 63 end end)()
  fn = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", r)]; if _v == nil then return nil end; return _v end)()
  fn(b)
  self.reg = logicview.add(self.reg, 1)
  if logicview.truth((self.reg > 63)) then
    self.reg = 0
  end
end
function _decoder.is_correct_chip(self, addr)
  if logicview.truth(logicview.eq(addr, DS1307_I2C_ADDRESS)) then
    return true
  end
  self:put(self.ss_block, self.es, self.out_ann, { Ann.WARNING, { logicview.pymod("Ignoring non-DS1307 data (slave 0x%02X)", addr) } })
  return false
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
      if logicview.truth((not logicview.truth(self:is_correct_chip(databyte)))) then
        self.state = "IDLE"
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
        self:handle_reg(databyte)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self:output_datetime(Ann.WRITE_DATE_TIME, "Written")
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.eq(self.state, "READ RTC REGS")) then
      if logicview.truth((not logicview.eq(cmd, "ADDRESS READ"))) then
        return
      end
      if logicview.truth((not logicview.truth(self:is_correct_chip(databyte)))) then
        self.state = "IDLE"
        return
      end
      self.state = "READ RTC REGS2"
    elseif logicview.truth(logicview.eq(self.state, "READ RTC REGS2")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        self:handle_reg(databyte)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self:output_datetime(Ann.READ_DATE_TIME, "Read")
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
