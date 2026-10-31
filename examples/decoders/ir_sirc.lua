-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Tom Flanagan <knio@zkpq.ca>

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
local bitpack_lsb, ADDRESSES, SamplerateError, SIRCError, SIRCErrorSilent, Ann, AGC_USEC, ONE_USEC, ZERO_USEC, PAUSE_USEC, Decoder, NUMBERS, address, extended, name, commands
local _decoder

bitpack_lsb = logicview.bitpack_lsb
NUMBERS = logicview.dict({ [0] = "1", [1] = "2", [2] = "3", [3] = "4", [4] = "5", [5] = "6", [6] = "7", [7] = "8", [8] = "9", [9] = "0/10" })
ADDRESSES = logicview.dict({ [logicview.tkey(1, nil)] = { { "TV: ", "TV:" }, logicview.dict({ [21] = "Power", [37] = "Input", [51] = "Right", [52] = "Left", [58] = "Display", [96] = "Home", [101] = "Enter", [116] = "Up", [117] = "Down" }) }, [logicview.tkey(11, nil)] = { { "Video: ", "V:" }, logicview.dict({ [24] = "Stop", [25] = "Pause", [26] = "Play", [27] = "Rewind", [28] = "Fast Forward", [66] = "Up", [67] = "Down", [77] = "Home", [81] = "Enter", [90] = "Display", [97] = "Right", [98] = "Left" }) }, [logicview.tkey(16, 40)] = { { "BlueRay: ", "BR:" }, logicview.dict({ [22] = "BlueRay" }) }, [logicview.tkey(16, 8)] = { { "Playback: ", "PB:" }, logicview.dict({ [42] = "Shuffle", [44] = "Repeat", [46] = "Folder Down", [47] = "Folder Up", [48] = "Previous", [49] = "Next", [50] = "Play", [51] = "Rewind", [52] = "Fast Forward", [56] = "Stop", [57] = "Pause", [115] = "Options", [125] = "Return" }) }, [logicview.tkey(17, nil)] = { { "CD: ", "CD:" }, logicview.dict({ [40] = "Display", [48] = "Previous", [49] = "Next", [50] = "Play", [51] = "Rewind", [52] = "Fast Forward", [56] = "Stop", [57] = "Pause" }) }, [logicview.tkey(26, 226)] = { { "BlueRay: ", "BD:" }, logicview.dict({ [24] = "Stop", [25] = "Pause", [26] = "Play", [27] = "Rewind", [28] = "Fast Forward", [41] = "Menu", [44] = "Top Menu", [57] = "Up", [58] = "Down", [59] = "Left", [60] = "Right", [61] = "Enter", [63] = "Options", [65] = "Display", [66] = "Home", [67] = "Return", [86] = "Next", [87] = "Previous" }) }, [logicview.tkey(26, 73)] = { { "DVD: ", "DVD:" }, logicview.dict({ [11] = "Enter", [14] = "Return", [23] = "Options", [26] = "Top Menu", [27] = "Menu", [48] = "Previous", [49] = "Next", [50] = "Play", [51] = "Rewind", [52] = "Fast Forward", [56] = "Stop", [57] = "Pause", [84] = "Display", [123] = "Left", [124] = "Right", [121] = "Up", [122] = "Down" }) }, [logicview.tkey(48, nil)] = { { "Keypad: ", "KP:" }, logicview.dict({ [12] = "Enter", [18] = "Volume Up", [19] = "Volume Down", [20] = "Mute", [21] = "Power", [33] = "Tuner", [34] = "Video", [37] = "CD", [77] = "Home", [75] = "Display", [96] = "Sleep", [106] = "TV", [83] = "Home", [124] = "Game", [125] = "DVD" }) }, [logicview.tkey(176, nil)] = { { "Arrows: ", "Ar:" }, logicview.dict({ [122] = "Left", [123] = "Right", [120] = "Up", [121] = "Down", [119] = "Amp Menu" }) }, [logicview.tkey(151, nil)] = { { "TV Extra", "TV:" }, logicview.dict({ [35] = "Return", [54] = "Options" }) } })
for _lv_k, _lv_v in _pairs(ADDRESSES) do
  do
    local _lv_sub = _lv_k
    address = logicview.idx(_lv_sub, 0)
    extended = logicview.idx(_lv_sub, 1)
  end
  do
    local _lv_sub = _lv_v
    name = logicview.idx(_lv_sub, 0)
    commands = logicview.idx(_lv_sub, 1)
  end
  logicview.dict_update(commands, NUMBERS)
  ::continue_1::
end

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
SIRCError = function(msg)
  local text = _tostring(msg or "SIRCError")
  return _setmetatable({ _exc = "SIRCError", args = { text } }, { __tostring = function() return text end })
end
SIRCErrorSilent = {}
SIRCErrorSilent.__index = SIRCErrorSilent
_setmetatable(SIRCErrorSilent, { __index = SIRCError })
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIT = logicview.idx(_lv_seq, 0)
  Ann.AGC = logicview.idx(_lv_seq, 1)
  Ann.PAUSE = logicview.idx(_lv_seq, 2)
  Ann.START = logicview.idx(_lv_seq, 3)
  Ann.CMD = logicview.idx(_lv_seq, 4)
  Ann.ADDR = logicview.idx(_lv_seq, 5)
  Ann.EXT = logicview.idx(_lv_seq, 6)
  Ann.REMOTE = logicview.idx(_lv_seq, 7)
  Ann.WARN = logicview.idx(_lv_seq, 8)
end
AGC_USEC = 2400
ONE_USEC = 1200
ZERO_USEC = 600
PAUSE_USEC = 600
_decoder = {
  api_version = 3,
  id = "ir_sirc",
  name = "IR SIRC",
  longname = "Sony IR (SIRC)",
  desc = "Sony infrared remote control protocol (SIRC).",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IR" },
  channels = { logicview.dict({ id = "ir", name = "IR", desc = "IR data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-low", values = { "active-low", "active-high" } }) },
  annotations = { { "bit", "Bit" }, { "agc", "AGC" }, { "pause", "Pause" }, { "start", "Start" }, { "command", "Command" }, { "address", "Address" }, { "extended", "Extended" }, { "remote", "Remote" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2 } }, { "fields", "Fields", { 3, 4, 5, 6 } }, { "remotes", "Remotes", { 7 } }, { "warnings", "Warnings", { 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.active = logicview.eq(logicview.idx(self.options, "polarity"), "active-high")
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.snum_per_us = (self.samplerate / 1000000.0)
  end
end
function _decoder.putg(self, ss, es, cls, texts)
  self:put(ss, es, self.out_ann, { cls, texts })
end
function _decoder.tolerance(self, ss, es, expected)
  local microseconds, tolerance
  microseconds = ((es - ss) / self.snum_per_us)
  tolerance = logicview.mul(expected, 0.3)
  return (((expected - tolerance) < microseconds) and (microseconds < logicview.add(expected, tolerance)))
end
function _decoder.wait_wrap(self, conds, timeout)
  local to, ss, pins, es
  if logicview.truth((timeout ~= nil)) then
    to = logicview.tointeger(logicview.mul(timeout, self.snum_per_us))
    _table.insert(conds, logicview.dict({ skip = to }))
  end
  ss = self.samplenum
  pins = self:wait(conds)
  es = self.samplenum
  return { pins, ss, es, self.matched }
end
function _decoder.read_pulse(self, high, time)
  local e, max_time, ir, ss, es, matched
  e = (function() if logicview.truth(high) then return "f" else return "r" end end)()
  max_time = logicview.tointeger(logicview.mul(time, 1.3))
  do
    local _lv_seq = self:wait_wrap({ logicview.dict({ [0] = e }) }, max_time)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    do
      local _lv_sub = logicview.idx(_lv_seq, 0)
      ir = logicview.idx(_lv_sub, 0)
    end
    ss = logicview.idx(_lv_seq, 1)
    es = logicview.idx(_lv_seq, 2)
    matched = logicview.idx(_lv_seq, 3)
  end
  if logicview.truth((function()
  local _v
  _v = (matched & 1)
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self:tolerance(ss, es, time)))
  return _v
end)()) then
    _error(SIRCError("Timeout"), 0)
  end
  return { ir, ss, es, matched }
end
function _decoder.read_bit(self)
  local e, _, high_ss, high_es, matched, bit, low_ss, low_es, good
  e = (function() if logicview.truth(self.active) then return "f" else return "r" end end)()
  do
    local _lv_seq = self:wait_wrap({ logicview.dict({ [0] = e }) }, 2000)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    _ = logicview.idx(_lv_seq, 0)
    high_ss = logicview.idx(_lv_seq, 1)
    high_es = logicview.idx(_lv_seq, 2)
    matched = logicview.idx(_lv_seq, 3)
  end
  if logicview.truth((matched & 1)) then
    _error(SIRCError("Bit High Timeout"), 0)
  end
  if logicview.truth(self:tolerance(high_ss, high_es, ONE_USEC)) then
    bit = 1
  elseif logicview.truth(self:tolerance(high_ss, high_es, ZERO_USEC)) then
    bit = 0
  else
    _error(SIRCError("Bit Low Timeout"), 0)
  end
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      do
        local _lv_seq = self:read_pulse((not logicview.truth(self.active)), PAUSE_USEC)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        _ = logicview.idx(_lv_seq, 0)
        low_ss = logicview.idx(_lv_seq, 1)
        low_es = logicview.idx(_lv_seq, 2)
        _ = logicview.idx(_lv_seq, 3)
      end
      good = true
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "SIRCError") then
        low_es = logicview.add(high_es, logicview.tointeger(logicview.mul(PAUSE_USEC, self.snum_per_us)))
        good = false
      else
        _error(_err, 0)
      end
    end
  end
  self:putg(high_ss, low_es, Ann.BIT, { logicview.pyformat("{}", { bit }, logicview.dict({})) })
  return { bit, high_ss, low_es, good }
end
function _decoder.read_signal(self)
  local _, agc_ss, agc_es, pause_ss, pause_es, bits, bit, ss, es, good, command, address, extended, command_num, address_num, command_str, address_str, extended_num, extended_str
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      do
        local _lv_seq = self:read_pulse(self.active, AGC_USEC)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        _ = logicview.idx(_lv_seq, 0)
        agc_ss = logicview.idx(_lv_seq, 1)
        agc_es = logicview.idx(_lv_seq, 2)
        _ = logicview.idx(_lv_seq, 3)
      end
      do
        local _lv_seq = self:read_pulse((not logicview.truth(self.active)), PAUSE_USEC)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        _ = logicview.idx(_lv_seq, 0)
        pause_ss = logicview.idx(_lv_seq, 1)
        pause_es = logicview.idx(_lv_seq, 2)
        _ = logicview.idx(_lv_seq, 3)
      end
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "SIRCError") then
        _error(SIRCErrorSilent.new("not an SIRC message"), 0)
      else
        _error(_err, 0)
      end
    end
  end
  self:putg(agc_ss, agc_es, Ann.AGC, { "AGC", "A" })
  self:putg(pause_ss, pause_es, Ann.PAUSE, { "Pause", "P" })
  self:putg(agc_ss, pause_es, Ann.START, { "Start", "S" })
  bits = {  }
  while true do
    do
      local _lv_seq = self:read_bit()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      bit = logicview.idx(_lv_seq, 0)
      ss = logicview.idx(_lv_seq, 1)
      es = logicview.idx(_lv_seq, 2)
      good = logicview.idx(_lv_seq, 3)
    end
    _table.insert(bits, { bit, ss, es })
    if logicview.truth((logicview.len(bits) > 20)) then
      _error(SIRCError("too many bits"), 0)
    end
    if logicview.truth((not logicview.truth(good))) then
      if logicview.truth(logicview.eq(logicview.len(bits), 12)) then
        command = logicview.slice(bits, 0, 7, nil)
        address = logicview.slice(bits, 7, 12, nil)
        extended = {  }
      elseif logicview.truth(logicview.eq(logicview.len(bits), 15)) then
        command = logicview.slice(bits, 0, 7, nil)
        address = logicview.slice(bits, 7, 15, nil)
        extended = {  }
      elseif logicview.truth(logicview.eq(logicview.len(bits), 20)) then
        command = logicview.slice(bits, 0, 7, nil)
        address = logicview.slice(bits, 7, 12, nil)
        extended = logicview.slice(bits, 12, 20, nil)
      else
        _error(SIRCError(logicview.pyformat("incorrect bits count {}", { logicview.len(bits) }, logicview.dict({}))), 0)
      end
      break
    end
    ::continue_2::
  end
  command_num = bitpack_lsb(command, 0)
  address_num = bitpack_lsb(address, 0)
  command_str = logicview.pyformat("0x{:02X}", { command_num }, logicview.dict({}))
  address_str = logicview.pyformat("0x{:02X}", { address_num }, logicview.dict({}))
  self:putg(logicview.idx(logicview.idx(command, 0), 1), logicview.idx(logicview.idx(command, (-1)), 2), Ann.CMD, { logicview.pyformat("Command: {}", { command_str }, logicview.dict({})), logicview.pyformat("C:{}", { command_str }, logicview.dict({})) })
  self:putg(logicview.idx(logicview.idx(address, 0), 1), logicview.idx(logicview.idx(address, (-1)), 2), Ann.ADDR, { logicview.pyformat("Address: {}", { address_str }, logicview.dict({})), logicview.pyformat("A:{}", { address_str }, logicview.dict({})) })
  extended_num = nil
  if logicview.truth(extended) then
    extended_num = bitpack_lsb(extended, 0)
    extended_str = logicview.pyformat("0x{:02X}", { extended_num }, logicview.dict({}))
    self:putg(logicview.idx(logicview.idx(extended, 0), 1), logicview.idx(logicview.idx(extended, (-1)), 2), Ann.EXT, { logicview.pyformat("Extended: {}", { extended_str }, logicview.dict({})), logicview.pyformat("E:{}", { extended_str }, logicview.dict({})) })
  end
  return { address_num, command_num, extended_num, logicview.idx(logicview.idx(bits, 0), 1), logicview.idx(logicview.idx(bits, (-1)), 2) }
end
function _decoder.decode(self)
  local unknown, e, _, frame_ss, addr, cmd, ext, payload_ss, payload_es, names, cmds, text
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  unknown = { { "Unknown Device: ", "UNK: " }, logicview.dict({  }) }
  while true do
    e = (function() if logicview.truth(self.active) then return "h" else return "l" end end)()
    do
      local _lv_seq = self:wait_wrap({ logicview.dict({ [0] = e }) }, nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      _ = logicview.idx(_lv_seq, 0)
      _ = logicview.idx(_lv_seq, 1)
      frame_ss = logicview.idx(_lv_seq, 2)
      _ = logicview.idx(_lv_seq, 3)
    end
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        do
          local _lv_seq = self:read_signal()
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          addr = logicview.idx(_lv_seq, 0)
          cmd = logicview.idx(_lv_seq, 1)
          ext = logicview.idx(_lv_seq, 2)
          payload_ss = logicview.idx(_lv_seq, 3)
          payload_es = logicview.idx(_lv_seq, 4)
        end
        do
          local _lv_seq = logicview.dget(ADDRESSES, { addr, ext }, unknown)
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          names = logicview.idx(_lv_seq, 0)
          cmds = logicview.idx(_lv_seq, 1)
        end
        text = logicview.dget(cmds, cmd, "Unknown")
        self:putg(frame_ss, payload_es, Ann.REMOTE, (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(names) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add(n, text)
  end
  return _lv_out
end)())
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if (_type(_err) == 'table' and _err._exc == "SIRCErrorSilent") then
          e = _err
        elseif (_type(_err) == 'table' and _err._exc == "SIRCError") then
          e = _err
          self:putg(frame_ss, self.samplenum, Ann.WARN, { logicview.pyformat("Error: {}", { e }, logicview.dict({})), "Error", "E" })
        else
          _error(_err, 0)
        end
      end
    end
    ::continue_3::
  end
end

return _decoder
