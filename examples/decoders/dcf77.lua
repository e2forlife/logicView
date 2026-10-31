-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2016 Uwe Hermann <uwe@hermann-uwe.de>

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
local calendar, bcd2int, SamplerateError, Decoder
local _decoder

calendar = {}
bcd2int = logicview.bcd2int
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "dcf77",
  name = "DCF77",
  longname = "DCF77 time protocol",
  desc = "European longwave time signal (77.5kHz carrier signal).",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Clock/timing" },
  channels = { logicview.dict({ id = "data", name = "DATA", desc = "DATA line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "start-of-minute", "Start of minute" }, { "special-bits", "Special bits (civil warnings, weather forecast)" }, { "call-bit", "Call bit" }, { "summer-time", "Summer time announcement" }, { "cest", "CEST bit" }, { "cet", "CET bit" }, { "leap-second", "Leap second bit" }, { "start-of-time", "Start of encoded time" }, { "minute", "Minute" }, { "minute-parity", "Minute parity bit" }, { "hour", "Hour" }, { "hour-parity", "Hour parity bit" }, { "day", "Day of month" }, { "day-of-week", "Day of week" }, { "month", "Month" }, { "year", "Year" }, { "date-parity", "Date parity bit" }, { "raw-bits", "Raw bits" }, { "unknown-bits", "Unknown bits" }, { "warnings", "Human-readable warnings" } },
  annotation_rows = { { "bits", "Bits", { 17, 18 } }, { "fields", "Fields", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } }, { "warnings", "Warnings", { 19 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.state = "WAIT FOR RISING EDGE"
  do
    local _lv_chain = 0
    self.ss_bit = _lv_chain
    self.ss_bit_old = _lv_chain
    self.es_bit = _lv_chain
    self.ss_block = _lv_chain
  end
  self.datebits = {  }
  self.bitcount = 0
  self.dcf77_bitnumber_is_known = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.putx(self, data)
  self:put(self.ss_bit, self.es_bit, self.out_ann, data)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.samplenum, self.out_ann, data)
end
function _decoder.handle_dcf77_bit(self, bit)
  local c, s, ann, x, m, parity, d, dn, mn
  c = self.bitcount
  s = (function() if logicview.truth(self.dcf77_bitnumber_is_known) then return "B" else return "Unknown b" end end)()
  ann = (function() if logicview.truth(self.dcf77_bitnumber_is_known) then return 17 else return 18 end end)()
  self:putx({ ann, { logicview.pymod("%sit %d: %d", { s, c, bit }), logicview.pymod("%d", bit) } })
  if logicview.truth((not logicview.truth(self.dcf77_bitnumber_is_known))) then
    return
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(36, logicview.add(58, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    _table.insert(self.datebits, bit)
  end
  if logicview.truth(logicview.eq(c, 0)) then
    if logicview.truth(logicview.eq(bit, 0)) then
      self:putx({ 0, { "Start of minute (always 0)", "Start of minute", "SoM" } })
    else
      self:putx({ 19, { "Start of minute != 0", "SoM != 0" } })
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(1, logicview.add(14, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 1)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 1)))
    end
    if logicview.truth(logicview.eq(c, 14)) then
      s = logicview.pyformat("{:014b}", { self.tmp }, logicview.dict({}))
      self:putb({ 1, { logicview.pymod("Special bits: %s", s), logicview.pymod("SB: %s", s) } })
    end
  elseif logicview.truth(logicview.eq(c, 15)) then
    s = (function() if logicview.truth(logicview.eq(bit, 1)) then return "" else return "not " end end)()
    self:putx({ 2, { logicview.pymod("Call bit: %sset", s), logicview.pymod("CB: %sset", s) } })
  elseif logicview.truth(logicview.eq(c, 16)) then
    s = (function() if logicview.truth(logicview.eq(bit, 1)) then return "" else return "not " end end)()
    x = (function() if logicview.truth(logicview.eq(bit, 1)) then return "yes" else return "no" end end)()
    self:putx({ 3, { logicview.pymod("Summer time announcement: %sactive", s), logicview.pymod("Summer time: %sactive", s), logicview.pymod("Summer time: %s", x), logicview.pymod("ST: %s", x) } })
  elseif logicview.truth(logicview.eq(c, 17)) then
    s = (function() if logicview.truth(logicview.eq(bit, 1)) then return "" else return "not " end end)()
    x = (function() if logicview.truth(logicview.eq(bit, 1)) then return "yes" else return "no" end end)()
    self:putx({ 4, { logicview.pymod("CEST: %sin effect", s), logicview.pymod("CEST: %s", x) } })
  elseif logicview.truth(logicview.eq(c, 18)) then
    s = (function() if logicview.truth(logicview.eq(bit, 1)) then return "" else return "not " end end)()
    x = (function() if logicview.truth(logicview.eq(bit, 1)) then return "yes" else return "no" end end)()
    self:putx({ 5, { logicview.pymod("CET: %sin effect", s), logicview.pymod("CET: %s", x) } })
  elseif logicview.truth(logicview.eq(c, 19)) then
    s = (function() if logicview.truth(logicview.eq(bit, 1)) then return "" else return "not " end end)()
    x = (function() if logicview.truth(logicview.eq(bit, 1)) then return "yes" else return "no" end end)()
    self:putx({ 6, { logicview.pymod("Leap second announcement: %sactive", s), logicview.pymod("Leap second: %sactive", s), logicview.pymod("Leap second: %s", x), logicview.pymod("LS: %s", x) } })
  elseif logicview.truth(logicview.eq(c, 20)) then
    if logicview.truth(logicview.eq(bit, 1)) then
      self:putx({ 7, { "Start of encoded time (always 1)", "Start of encoded time", "SoeT" } })
    else
      self:putx({ 19, { "Start of encoded time != 1", "SoeT != 1" } })
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(21, logicview.add(27, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 21)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 21)))
    end
    if logicview.truth(logicview.eq(c, 27)) then
      m = bcd2int(self.tmp)
      self:putb({ 8, { logicview.pymod("Minutes: %d", m), logicview.pymod("Min: %d", m) } })
    end
  elseif logicview.truth(logicview.eq(c, 28)) then
    self.tmp = (self.tmp | (bit << (c - 21)))
    parity = logicview.count(logicview.bin(self.tmp), "1")
    s = (function() if logicview.truth(logicview.eq(logicview.pymod(parity, 2), 0)) then return "OK" else return "INVALID!" end end)()
    self:putx({ 9, { logicview.pymod("Minute parity: %s", s), logicview.pymod("Min parity: %s", s) } })
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(29, logicview.add(34, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 29)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 29)))
    end
    if logicview.truth(logicview.eq(c, 34)) then
      self:putb({ 10, { logicview.pymod("Hours: %d", bcd2int(self.tmp)) } })
    end
  elseif logicview.truth(logicview.eq(c, 35)) then
    self.tmp = (self.tmp | (bit << (c - 29)))
    parity = logicview.count(logicview.bin(self.tmp), "1")
    s = (function() if logicview.truth(logicview.eq(logicview.pymod(parity, 2), 0)) then return "OK" else return "INVALID!" end end)()
    self:putx({ 11, { logicview.pymod("Hour parity: %s", s) } })
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(36, logicview.add(41, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 36)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 36)))
    end
    if logicview.truth(logicview.eq(c, 41)) then
      self:putb({ 12, { logicview.pymod("Day: %d", bcd2int(self.tmp)) } })
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(42, logicview.add(44, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 42)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 42)))
    end
    if logicview.truth(logicview.eq(c, 44)) then
      d = bcd2int(self.tmp)
      do
        local _lv_return = false
        local _lv_value = nil
        local _ok, _err = _pcall(function()
          dn = logicview.idx(calendar.day_name, (d - 1))
          self:putb({ 13, { logicview.pymod("Day of week: %d (%s)", { d, dn }), logicview.pymod("DoW: %d (%s)", { d, dn }) } })
        end)
        if _lv_return then return _lv_value end
        if not _ok then
          if (_type(_err) == 'table' and _err._exc == "IndexError") then
            self:putb({ 19, { logicview.pymod("Day of week: %d (%s)", { d, "invalid" }), logicview.pymod("DoW: %d (%s)", { d, "inv" }) } })
          else
            _error(_err, 0)
          end
        end
      end
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(45, logicview.add(49, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 45)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 45)))
    end
    if logicview.truth(logicview.eq(c, 49)) then
      m = bcd2int(self.tmp)
      do
        local _lv_return = false
        local _lv_value = nil
        local _ok, _err = _pcall(function()
          mn = logicview.idx(calendar.month_name, m)
          self:putb({ 14, { logicview.pymod("Month: %d (%s)", { m, mn }), logicview.pymod("Mon: %d (%s)", { m, mn }) } })
        end)
        if _lv_return then return _lv_value end
        if not _ok then
          if (_type(_err) == 'table' and _err._exc == "IndexError") then
            self:putb({ 19, { logicview.pymod("Month: %d (%s)", { m, "invalid" }), logicview.pymod("Mon: %d (%s)", { m, "inv" }) } })
          else
            _error(_err, 0)
          end
        end
      end
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(50, logicview.add(57, 1)) do _t[#_t + 1] = _v end; return _t end)(), c)) then
    if logicview.truth(logicview.eq(c, 50)) then
      self.tmp = bit
      self.ss_block = self.ss_bit
    else
      self.tmp = (self.tmp | (bit << (c - 50)))
    end
    if logicview.truth(logicview.eq(c, 57)) then
      self:putb({ 15, { logicview.pymod("Year: %d", bcd2int(self.tmp)) } })
    end
  elseif logicview.truth(logicview.eq(c, 58)) then
    parity = logicview.count(self.datebits, 1)
    s = (function() if logicview.truth(logicview.eq(logicview.pymod(parity, 2), 0)) then return "OK" else return "INVALID!" end end)()
    self:putx({ 16, { logicview.pymod("Date parity: %s", s), logicview.pymod("DP: %s", s) } })
    self.datebits = {  }
  else
    self:putx({ 19, { logicview.pymod("Invalid DCF77 bit: %d", c), logicview.pymod("Invalid bit: %d", c), logicview.pymod("Inv: %d", c) } })
  end
end
function _decoder.decode(self)
  local len_edges, len_edges_ms, len_high, len_high_ms, bit
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    if logicview.truth(logicview.eq(self.state, "WAIT FOR RISING EDGE")) then
      self:wait(logicview.dict({ [0] = "r" }))
      self.ss_bit = self.samplenum
      len_edges = (self.ss_bit - self.ss_bit_old)
      len_edges_ms = logicview.tointeger(logicview.mul((len_edges / self.samplerate), 1000))
      if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(1600, logicview.add(2400, 1)) do _t[#_t + 1] = _v end; return _t end)(), len_edges_ms)) then
        self.bitcount = 0
        self.ss_bit_old = self.ss_bit
        self.dcf77_bitnumber_is_known = 1
      end
      self.ss_bit_old = self.ss_bit
      self.state = "GET BIT"
    elseif logicview.truth(logicview.eq(self.state, "GET BIT")) then
      self:wait(logicview.dict({ [0] = "f" }))
      self.es_bit = self.samplenum
      len_high = (self.samplenum - self.ss_bit)
      len_high_ms = logicview.tointeger(logicview.mul((len_high / self.samplerate), 1000))
      if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(40, logicview.add(160, 1)) do _t[#_t + 1] = _v end; return _t end)(), len_high_ms)) then
        bit = 0
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(161, logicview.add(260, 1)) do _t[#_t + 1] = _v end; return _t end)(), len_high_ms)) then
        bit = 1
      else
        bit = (-1)
      end
      if logicview.truth(logicview.contains({ 0, 1 }, bit)) then
        self:handle_dcf77_bit(bit)
        self.bitcount = logicview.add(self.bitcount, 1)
      else
        self:putx({ 19, { "Invalid bit timing", "Inv timing", "Inv" } })
      end
      self.state = "WAIT FOR RISING EDGE"
    end
    ::continue_1::
  end
end

return _decoder
