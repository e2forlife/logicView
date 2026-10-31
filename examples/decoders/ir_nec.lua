-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Gump Yang <gump.yang@gmail.com>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>

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
local bitpack, _TIME_TOL, _TIME_IDLE, _TIME_LC, _TIME_RC, _TIME_ONE, _TIME_ZERO, _TIME_STOP, SamplerateError, Pin, Ann, Decoder, address, digits, command
local _decoder

bitpack = logicview.bitpack
address = logicview.dict({ [64] = "Matsui TV" })
digits = logicview.dict({ [0] = { "0", "0" }, [1] = { "1", "1" }, [2] = { "2", "2" }, [3] = { "3", "3" }, [4] = { "4", "4" }, [5] = { "5", "5" }, [6] = { "6", "6" }, [7] = { "7", "7" }, [8] = { "8", "8" }, [9] = { "9", "9" } })
command = logicview.dict({ [64] = logicview.dict(logicview.add(logicview.copy((function() local _t = {}; for _k, _v in _pairs(digits) do _t[#_t + 1] = {_k, _v} end; return _t end)()), logicview.copy((function() local _t = {}; for _k, _v in _pairs(logicview.dict({ [11] = { "-/--", "-/--" }, [16] = { "Mute", "M" }, [18] = { "Standby", "StBy" }, [26] = { "Volume up", "Vol+" }, [27] = { "Program up", "P+" }, [30] = { "Volume down", "Vol-" }, [31] = { "Program down", "P-" }, [68] = { "AV", "AV" } })) do _t[#_t + 1] = {_k, _v} end; return _t end)()))) })

_TIME_TOL = 10
_TIME_IDLE = 20.0
_TIME_LC = 13.5
_TIME_RC = 11.25
_TIME_ONE = 2.25
_TIME_ZERO = 1.125
_TIME_STOP = 0.562
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
Pin = {}
Pin.__index = Pin
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(1) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pin.IR = logicview.idx(_lv_seq, 0)
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(13) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIT = logicview.idx(_lv_seq, 0)
  Ann.AGC = logicview.idx(_lv_seq, 1)
  Ann.LONG_PAUSE = logicview.idx(_lv_seq, 2)
  Ann.SHORT_PAUSE = logicview.idx(_lv_seq, 3)
  Ann.STOP_BIT = logicview.idx(_lv_seq, 4)
  Ann.LEADER_CODE = logicview.idx(_lv_seq, 5)
  Ann.ADDR = logicview.idx(_lv_seq, 6)
  Ann.ADDR_INV = logicview.idx(_lv_seq, 7)
  Ann.CMD = logicview.idx(_lv_seq, 8)
  Ann.CMD_INV = logicview.idx(_lv_seq, 9)
  Ann.REPEAT_CODE = logicview.idx(_lv_seq, 10)
  Ann.REMOTE = logicview.idx(_lv_seq, 11)
  Ann.WARN = logicview.idx(_lv_seq, 12)
end
_decoder = {
  api_version = 3,
  id = "ir_nec",
  name = "IR NEC",
  longname = "IR NEC",
  desc = "NEC infrared remote control protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IR" },
  channels = { logicview.dict({ id = "ir", name = "IR", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-low", values = { "auto", "active-low", "active-high" } }), logicview.dict({ id = "cd_freq", desc = "Carrier Frequency", default = 0, values = {  } }), logicview.dict({ id = "extended", desc = "Extended NEC Protocol", default = "no", values = { "yes", "no" } }) },
  annotations = { { "bit", "Bit" }, { "agc-pulse", "AGC pulse" }, { "longpause", "Long pause" }, { "shortpause", "Short pause" }, { "stop-bit", "Stop bit" }, { "leader-code", "Leader code" }, { "addr", "Address" }, { "addr-inv", "Address#" }, { "cmd", "Command" }, { "cmd-inv", "Command#" }, { "repeat-code", "Repeat code" }, { "remote", "Remote" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3, 4 } }, { "fields", "Fields", { 5, 6, 7, 8, 9, 10 } }, { "remote-vals", "Remote", { 11 } }, { "warnings", "Warnings", { 12 } } },
  binary = {  }
}
function _decoder.putx(self, data)
  self:put(self.ss_start, self.samplenum, self.out_ann, data)
end
function _decoder.putb(self, data)
  self:put(self.ss_bit, self.samplenum, self.out_ann, data)
end
function _decoder.putd(self, data, bit_count)
  local name, d, s, fmt
  name = self.state:title()
  d = logicview.dict({ ADDRESS = Ann.ADDR, ["ADDRESS#"] = Ann.ADDR_INV, COMMAND = Ann.CMD, ["COMMAND#"] = Ann.CMD_INV })
  s = logicview.dict({ ADDRESS = { "ADDR", "A" }, ["ADDRESS#"] = { "ADDR#", "A#" }, COMMAND = { "CMD", "C" }, ["COMMAND#"] = { "CMD#", "C#" } })
  fmt = logicview.pyformat("{{}}: 0x{{:0{}X}}", { logicview.floordiv(bit_count, 4) }, logicview.dict({}))
  self:putx({ logicview.idx(d, self.state), { logicview.pyformat(fmt, { name, data }, logicview.dict({})), logicview.pyformat(fmt, { logicview.idx(logicview.idx(s, self.state), 0), data }, logicview.dict({})), logicview.pyformat(fmt, { logicview.idx(logicview.idx(s, self.state), 1), data }, logicview.dict({})), logicview.idx(logicview.idx(s, self.state), 1) } })
end
function _decoder.putstop(self, ss)
  self:put(ss, logicview.add(ss, self.stop), self.out_ann, { Ann.STOP_BIT, { "Stop bit", "Stop", "St", "S" } })
end
function _decoder.putpause(self, p)
  local idx
  self:put(self.ss_start, self.ss_other_edge, self.out_ann, { Ann.AGC, { "AGC pulse", "AGC", "A" } })
  idx = (function() if logicview.truth(logicview.eq(p, "Long")) then return Ann.LONG_PAUSE else return Ann.SHORT_PAUSE end end)()
  self:put(self.ss_other_edge, self.samplenum, self.out_ann, { idx, { logicview.pyformat("{} pause", { p }, logicview.dict({})), logicview.pyformat("{}-pause", { logicview.idx(p, 0) }, logicview.dict({})), logicview.pyformat("{}P", { logicview.idx(p, 0) }, logicview.dict({})), "P" } })
end
function _decoder.putremote(self)
  local dev, buttons, btn
  dev = logicview.dget(address, self.addr, "Unknown device")
  buttons = logicview.dget(command, self.addr, logicview.dict({  }))
  btn = logicview.dget(buttons, self.cmd, { "Unknown", "Unk" })
  self:put(self.ss_remote, logicview.add(self.ss_bit, self.stop), self.out_ann, { Ann.REMOTE, { logicview.pyformat("{}: {}", { dev, logicview.idx(btn, 0) }, logicview.dict({})), logicview.pyformat("{}: {}", { dev, logicview.idx(btn, 1) }, logicview.dict({})), logicview.pyformat("{}", { logicview.idx(btn, 1) }, logicview.dict({})) } })
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  do
    local _lv_chain = 0
    self.ss_bit = _lv_chain
    self.ss_start = _lv_chain
    self.ss_other_edge = _lv_chain
    self.ss_remote = _lv_chain
  end
  self.data = {  }
  do
    local _lv_chain = nil
    self.addr = _lv_chain
    self.cmd = _lv_chain
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.calc_rate(self)
  self.tolerance = (_TIME_TOL / 100)
  self.lc = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_LC) / 1000)) - 1)
  self.rc = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_RC) / 1000)) - 1)
  self.dazero = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_ZERO) / 1000)) - 1)
  self.daone = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_ONE) / 1000)) - 1)
  self.stop = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_STOP) / 1000)) - 1)
  self.idle_to = (logicview.tointeger((logicview.mul(self.samplerate, _TIME_IDLE) / 1000)) - 1)
end
function _decoder.compare_with_tolerance(self, measured, base)
  return (function()
  local _v
  _v = (measured >= logicview.mul(base, (1 - self.tolerance)))
  if not logicview.truth(_v) then return _v end
  _v = (measured <= logicview.mul(base, logicview.add(1, self.tolerance)))
  return _v
end)()
end
function _decoder.handle_bit(self, tick)
  local ret
  ret = nil
  if logicview.truth(self:compare_with_tolerance(tick, self.dazero)) then
    ret = 0
  elseif logicview.truth(self:compare_with_tolerance(tick, self.daone)) then
    ret = 1
  end
  if logicview.truth(logicview.contains({ 0, 1 }, ret)) then
    self:putb({ Ann.BIT, { logicview.pyformat("{:d}", { ret }, logicview.dict({})) } })
    _table.insert(self.data, ret)
  end
  self.ss_bit = self.samplenum
end
function _decoder.data_ok(self, check, want_len)
  local name, normal, inverted, valid, show, is_ext_addr, warn_show
  name = self.state:title()
  do
    local _lv_a0, _lv_a1 = bitpack(logicview.slice(self.data, nil, 8, nil)), bitpack(logicview.slice(self.data, 8, nil, nil))
    normal = _lv_a0
    inverted = _lv_a1
  end
  valid = logicview.eq((normal ~ inverted), 255)
  show = (function() if logicview.truth(logicview.endswith(self.state, "#")) then return inverted else return normal end end)()
  is_ext_addr = (function()
  local _v
  _v = self.is_extended
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "ADDRESS")
  return _v
end)()
  if logicview.truth(is_ext_addr) then
    normal = bitpack(self.data)
    show = normal
    valid = true
  end
  if logicview.truth(logicview.eq(logicview.len(self.data), want_len)) then
    if logicview.truth(logicview.eq(self.state, "ADDRESS")) then
      self.addr = normal
    end
    if logicview.truth(logicview.eq(self.state, "COMMAND")) then
      self.cmd = normal
    end
    self:putd(show, want_len)
    self.ss_start = self.samplenum
    if logicview.truth(is_ext_addr) then
      self.data = {  }
      do
        local _lv_chain = self.samplenum
        self.ss_bit = _lv_chain
        self.ss_start = _lv_chain
      end
    end
    return true
  end
  self:putd(show, want_len)
  if logicview.truth((function()
  local _v
  _v = check
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(valid))
  return _v
end)()) then
    warn_show = bitpack(self.data)
    self:putx({ Ann.WARN, { logicview.pyformat("{} error: 0x{:04X}", { name, warn_show }, logicview.dict({})) } })
  end
  self.data = {  }
  do
    local _lv_chain = self.samplenum
    self.ss_bit = _lv_chain
    self.ss_start = _lv_chain
  end
  return valid
end
function _decoder.decode(self)
  local cd_count, prev_ir, curr_level, active, want_addr_len, cur_ir, width
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:calc_rate()
  cd_count = nil
  if logicview.truth(logicview.idx(self.options, "cd_freq")) then
    cd_count = logicview.add(logicview.tointeger((self.samplerate / logicview.idx(self.options, "cd_freq"))), 1)
  end
  prev_ir = nil
  if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "auto")) then
    do
      local _lv_seq = self:wait(logicview.dict({ skip = 0 }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      curr_level = logicview.idx(_lv_seq, 0)
    end
    active = (1 - curr_level)
  else
    active = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return 0 else return 1 end end)()
  end
  self.is_extended = logicview.eq(logicview.idx(self.options, "extended"), "yes")
  want_addr_len = (function() if logicview.truth(self.is_extended) then return 16 else return 8 end end)()
  while true do
    if logicview.truth(cd_count) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [Pin.IR] = "e" }), logicview.dict({ skip = cd_count }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cur_ir = logicview.idx(_lv_seq, 0)
      end
      if logicview.truth((self.matched & (1 << 0))) then
        cur_ir = active
      end
      if logicview.truth(logicview.eq(cur_ir, prev_ir)) then
        goto continue_1
      end
      prev_ir = cur_ir
      self.ir = cur_ir
    else
      do
        local _lv_seq = self:wait(logicview.dict({ [Pin.IR] = "e" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        self.ir = logicview.idx(_lv_seq, 0)
      end
    end
    if logicview.truth((not logicview.eq(self.ir, active))) then
      self.ss_other_edge = self.samplenum
      if logicview.truth((not logicview.eq(self.state, "STOP"))) then
        goto continue_1
      end
    end
    width = (self.samplenum - self.ss_bit)
    if logicview.truth((function()
  local _v
  _v = (width >= self.idle_to)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.state, "STOP"))
  return _v
end)()) then
      self:reset()
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(self:compare_with_tolerance(width, self.lc)) then
        self:putpause("Long")
        self:putx({ Ann.LEADER_CODE, { "Leader code", "Leader", "LC", "L" } })
        self.ss_remote = self.ss_start
        self.data = {  }
        self.state = "ADDRESS"
      elseif logicview.truth(self:compare_with_tolerance(width, self.rc)) then
        self:putpause("Short")
        self:putstop(self.samplenum)
        self.samplenum = logicview.add(self.samplenum, self.stop)
        self:putx({ Ann.REPEAT_CODE, { "Repeat code", "Repeat", "RC", "R" } })
        self.data = {  }
      end
      do
        local _lv_chain = self.samplenum
        self.ss_bit = _lv_chain
        self.ss_start = _lv_chain
      end
    elseif logicview.truth(logicview.eq(self.state, "ADDRESS")) then
      self:handle_bit(width)
      if logicview.truth(logicview.eq(logicview.len(self.data), want_addr_len)) then
        self:data_ok(false, want_addr_len)
        self.state = (function() if logicview.truth(self.is_extended) then return "COMMAND" else return "ADDRESS#" end end)()
      end
    elseif logicview.truth(logicview.eq(self.state, "ADDRESS#")) then
      self:handle_bit(width)
      if logicview.truth(logicview.eq(logicview.len(self.data), 16)) then
        self:data_ok(true, 8)
        self.state = "COMMAND"
      end
    elseif logicview.truth(logicview.eq(self.state, "COMMAND")) then
      self:handle_bit(width)
      if logicview.truth(logicview.eq(logicview.len(self.data), 8)) then
        self:data_ok(false, 8)
        self.state = "COMMAND#"
      end
    elseif logicview.truth(logicview.eq(self.state, "COMMAND#")) then
      self:handle_bit(width)
      if logicview.truth(logicview.eq(logicview.len(self.data), 16)) then
        self:data_ok(true, 8)
        self.state = "STOP"
      end
    elseif logicview.truth(logicview.eq(self.state, "STOP")) then
      self:putstop(self.ss_bit)
      self:putremote()
      do
        local _lv_chain = self.samplenum
        self.ss_bit = _lv_chain
        self.ss_start = _lv_chain
      end
      self.state = "IDLE"
    end
    ::continue_1::
  end
end

return _decoder
