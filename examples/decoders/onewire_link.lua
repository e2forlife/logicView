-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Kevin Redon <kingkevin@cuvoodoo.info>

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
local SamplerateError, timing, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
timing = logicview.dict({ RSTL = logicview.dict({ min = logicview.dict({ [false] = 480.0, [true] = 48.0 }), max = logicview.dict({ [false] = 960.0, [true] = 80.0 }) }), RSTH = logicview.dict({ min = logicview.dict({ [false] = 480.0, [true] = 48.0 }) }), PDH = logicview.dict({ min = logicview.dict({ [false] = 15.0, [true] = 2.0 }), max = logicview.dict({ [false] = 60.0, [true] = 6.0 }) }), PDL = logicview.dict({ min = logicview.dict({ [false] = 60.0, [true] = 8.0 }), max = logicview.dict({ [false] = 240.0, [true] = 24.0 }) }), SLOT = logicview.dict({ min = logicview.dict({ [false] = 60.0, [true] = 6.0 }), max = logicview.dict({ [false] = 120.0, [true] = 16.0 }) }), REC = logicview.dict({ min = logicview.dict({ [false] = 1.0, [true] = 1.0 }) }), LOWR = logicview.dict({ min = logicview.dict({ [false] = 1.0, [true] = 1.0 }), max = logicview.dict({ [false] = 15.0, [true] = 2.0 }) }) })
_decoder = {
  api_version = 3,
  id = "onewire_link",
  name = "OneWire link layer",
  longname = "1-Wire serial communication bus (link layer)",
  desc = "Bidirectional, half-duplex, asynchronous serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "onewire_link" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "owr", name = "OWR", desc = "1-Wire signal line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "overdrive", desc = "Start in overdrive speed", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "min height level pulse time", desc = "min height level pulse time(us)", default = 2.0, values = {  } }), logicview.dict({ id = "min overdrive height level pulse time", desc = "min overdrive height level pulse time(us)", default = 15.0, values = {  } }), logicview.dict({ id = "data order", desc = "data order", default = "bit first", values = { "bit first", "space first" } }) },
  annotations = { { "bit", "Bit" }, { "warnings", "Warnings" }, { "reset", "Reset" }, { "presence", "Presence" }, { "overdrive", "Overdrive speed notifications" } },
  annotation_rows = { { "bits", "Bits", { 0, 2, 3 } }, { "info", "Info", { 4 } }, { "warnings", "Warnings", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.state = "INITIAL"
  self.present = 0
  self.bit = 0
  self.bit_count = (-1)
  self.command = 0
  self.overdrive = false
  self.bit_first = true
  self.fall = 0
  self.rise = 0
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.overdrive = logicview.eq(logicview.idx(self.options, "overdrive"), "yes")
  self.bit_first = logicview.eq(logicview.idx(self.options, "data order"), "bit first")
  logicview.setidx(logicview.idx(logicview.idx(timing, "LOWR"), "max"), false, (_tonumber(logicview.idx(self.options, "min height level pulse time")) or 0))
  logicview.setidx(logicview.idx(logicview.idx(timing, "LOWR"), "max"), true, (_tonumber(logicview.idx(self.options, "min overdrive height level pulse time")) or 0))
  self.fall = 0
  self.rise = 0
  self.bit_count = (-1)
end
function _decoder.putm(self, data)
  self:put(0, 0, self.out_ann, data)
end
function _decoder.putpfs(self, data)
  self:put(self.fall, self.samplenum, self.out_python, data)
end
function _decoder.putfs(self, data)
  self:put(self.fall, self.samplenum, self.out_ann, data)
end
function _decoder.putfr(self, data)
  self:put(self.fall, self.rise, self.out_ann, data)
end
function _decoder.putprs(self, data)
  self:put(self.rise, self.samplenum, self.out_python, data)
end
function _decoder.putrs(self, data)
  self:put(self.rise, self.samplenum, self.out_ann, data)
end
function _decoder.checks(self)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "overdrive"), "yes")) then
    if logicview.truth((self.samplerate < 2000000)) then
      self:putm({ 1, { logicview.add("Sampling rate is too low. Must be above ", "2MHz for proper overdrive mode decoding.") } })
    elseif logicview.truth((self.samplerate < 5000000)) then
      self:putm({ 1, { logicview.add("Sampling rate is suggested to be above 5MHz ", "for proper overdrive mode decoding.") } })
    end
  elseif logicview.truth((self.samplerate < 400000)) then
    self:putm({ 1, { logicview.add("Sampling rate is too low. Must be above ", "400kHz for proper normal mode decoding.") } })
  elseif logicview.truth((self.samplerate < 1000000)) then
    self:putm({ 1, { logicview.add("Sampling rate is suggested to be above ", "1MHz for proper normal mode decoding.") } })
  end
end
function _decoder.metadata(self, key, value)
  if logicview.truth((not logicview.eq(key, logicview.SRD_CONF_SAMPLERATE))) then
    return
  end
  self.samplerate = value
end
function _decoder.wait_falling_timeout(self, start, t)
  local cnt, samples_to_skip
  cnt = logicview.tointeger(logicview.mul((logicview.idx(t, self.overdrive) / 1000000.0), self.samplerate))
  samples_to_skip = (logicview.add(start, cnt) - self.samplenum)
  samples_to_skip = (function() if logicview.truth((samples_to_skip > 0)) then return samples_to_skip else return 0 end end)()
  return self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ skip = samples_to_skip }) })
end
function _decoder.MinBitTimeOutput(self, time)
  if logicview.truth((time < logicview.idx(logicview.idx(logicview.idx(timing, "LOWR"), "min"), self.overdrive))) then
    self:putfr({ 1, { "Low signal not long enough", "Low too short", logicview.add("LOW < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "LOWR"), "min"), self.overdrive))) } })
  end
end
function _decoder.GetBitValue(self, time)
  if logicview.truth((time > logicview.idx(logicview.idx(logicview.idx(timing, "LOWR"), "max"), self.overdrive))) then
    self.bit = 1
  else
    self.bit = 0
  end
end
function _decoder.decode(self)
  local time
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:checks()
  while true do
    if logicview.truth(logicview.eq(self.state, "INITIAL")) then
      self:wait(logicview.dict({ [0] = "h" }))
      self.rise = self.samplenum
      self.state = "IDLE"
    elseif logicview.truth(logicview.eq(self.state, "IDLE")) then
      self:wait(logicview.dict({ [0] = "f" }))
      self.fall = self.samplenum
      time = logicview.mul(((self.fall - self.rise) / self.samplerate), 1000000.0)
      if logicview.truth((function()
  local _v
  _v = (self.rise > 0)
  if not logicview.truth(_v) then return _v end
  _v = (time < logicview.idx(logicview.idx(logicview.idx(timing, "REC"), "min"), self.overdrive))
  return _v
end)()) then
        self:putfr({ 1, { "Recovery time not long enoughRecovery too short", logicview.add("REC < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "REC"), "min"), self.overdrive))) } })
      end
      self.state = "LOW"
    elseif logicview.truth(logicview.eq(self.state, "LOW")) then
      self:wait(logicview.dict({ [0] = "r" }))
      self.rise = self.samplenum
      time = logicview.mul(((self.rise - self.fall) / self.samplerate), 1000000.0)
      if logicview.truth((time >= logicview.idx(logicview.idx(logicview.idx(timing, "RSTL"), "min"), false))) then
        if logicview.truth((time > logicview.idx(logicview.idx(logicview.idx(timing, "RSTL"), "max"), false))) then
          self:putfr({ 1, { logicview.add("Too long reset pulse might mask interrupt ", "signalling by other devices"), "Reset pulse too long", logicview.add("RST > ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "RSTL"), "max"), false))) } })
        end
        if logicview.truth(self.overdrive) then
          self:putfr({ 4, { "Exiting overdrive mode", "Overdrive off" } })
        end
        self.overdrive = false
        self:putfr({ 2, { "Reset", "Rst", "R" } })
        self.state = "PRESENCE DETECT HIGH"
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.overdrive, true)
  if not logicview.truth(_v) then return _v end
  _v = (time >= logicview.idx(logicview.idx(logicview.idx(timing, "RSTL"), "min"), self.overdrive))
  if not logicview.truth(_v) then return _v end
  _v = (time < logicview.idx(logicview.idx(logicview.idx(timing, "RSTL"), "max"), self.overdrive))
  return _v
end)()) then
        self:putfr({ 2, { "Reset", "Rst", "R" } })
        self.state = "PRESENCE DETECT HIGH"
      elseif logicview.truth((time < logicview.idx(logicview.idx(logicview.idx(timing, "SLOT"), "max"), self.overdrive))) then
        if logicview.truth(logicview.eq(self.bit_first, true)) then
          self:MinBitTimeOutput(time)
          self:GetBitValue(time)
        end
        self.state = "SLOT"
      else
        self:putfr({ 1, { "Erroneous signal", "Error", "Err", "E" } })
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.eq(self.state, "PRESENCE DETECT HIGH")) then
      self:wait_falling_timeout(self.rise, logicview.idx(logicview.idx(timing, "PDH"), "max"))
      time = logicview.mul(((self.samplenum - self.rise) / self.samplerate), 1000000.0)
      if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 1))))
  return _v
end)()) then
        if logicview.truth((time < logicview.idx(logicview.idx(logicview.idx(timing, "PDH"), "min"), self.overdrive))) then
          self:putrs({ 1, { "Presence detect signal is too early", "Presence detect too early", logicview.add("PDH < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "PDH"), "min"), self.overdrive))) } })
        end
        self.fall = self.samplenum
        self.state = "PRESENCE DETECT LOW"
      else
        self:putrs({ 3, { "Presence: false", "Presence", "Pres", "P" } })
        self:putprs({ "RESET/PRESENCE", false })
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.eq(self.state, "PRESENCE DETECT LOW")) then
      self:wait(logicview.dict({ [0] = "r" }))
      time = logicview.mul(((self.samplenum - self.fall) / self.samplerate), 1000000.0)
      if logicview.truth((time < logicview.idx(logicview.idx(logicview.idx(timing, "PDL"), "min"), self.overdrive))) then
        self:putfs({ 1, { "Presence detect signal is too short", "Presence detect too short", logicview.add("PDL < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "PDL"), "min"), self.overdrive))) } })
      elseif logicview.truth((time > logicview.idx(logicview.idx(logicview.idx(timing, "PDL"), "max"), self.overdrive))) then
        self:putfs({ 1, { "Presence detect signal is too long", "Presence detect too long", logicview.add("PDL > ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "PDL"), "max"), self.overdrive))) } })
      end
      if logicview.truth((time > logicview.idx(logicview.idx(logicview.idx(timing, "RSTH"), "min"), self.overdrive))) then
        self.rise = self.samplenum
      end
      self.state = "PRESENCE DETECT"
    end
    if logicview.truth(logicview.eq(self.state, "SLOT")) then
      self:wait_falling_timeout(self.fall, logicview.idx(logicview.idx(timing, "SLOT"), "min"))
      if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 1))))
  return _v
end)()) then
        self:putfs({ 1, { "Time slot not long enough", "Slot too short", logicview.add("SLOT < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "SLOT"), "min"), self.overdrive))) } })
        self.fall = self.samplenum
        self.state = "LOW"
      else
        if logicview.truth(logicview.eq(self.bit_first, false)) then
          time = logicview.mul(((self.samplenum - self.rise) / self.samplerate), 1000000.0)
          self:MinBitTimeOutput(time)
          self:GetBitValue(time)
        end
        self:putfs({ 0, { logicview.pymod("Bit: %d", self.bit), logicview.pymod("%d", self.bit) } })
        self:putpfs({ "BIT", self.bit })
        if logicview.truth((self.bit_count >= 0)) then
          self.command = logicview.add(self.command, (self.bit << self.bit_count))
          self.bit_count = logicview.add(self.bit_count, 1)
        end
        if logicview.truth((self.bit_count >= 8)) then
          if logicview.truth((function()
  local _v
  _v = logicview.eq(self.command, 60)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command, 105)
  return _v
end)()) then
            self.overdrive = true
            self:put(self.samplenum, self.samplenum, self.out_ann, { 4, { "Entering overdrive mode", "Overdrive on" } })
          end
          self.bit_count = (-1)
        end
        self.state = "IDLE"
      end
    end
    if logicview.truth(logicview.eq(self.state, "PRESENCE DETECT")) then
      self:wait_falling_timeout(self.rise, logicview.idx(logicview.idx(timing, "RSTH"), "min"))
      if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 1))))
  return _v
end)()) then
        self:putfs({ 1, { "Presence detect not long enough", "Presence detect too short", logicview.add("RTSH < ", _tostring(logicview.idx(logicview.idx(logicview.idx(timing, "RSTH"), "min"), self.overdrive))) } })
        self:putrs({ 3, { "Slave presence detected", "Slave present", "Present", "P" } })
        self:putprs({ "RESET/PRESENCE", true })
        self.fall = self.samplenum
        self.state = "LOW"
      else
        self:putrs({ 3, { "Presence: true", "Presence", "Pres", "P" } })
        self:putprs({ "RESET/PRESENCE", true })
        self.rise = self.samplenum
        self.bit_count = 0
        self.command = 0
        self.state = "IDLE"
      end
    end
    ::continue_1::
  end
end

return _decoder
