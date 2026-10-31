-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Angus Gratton <gus@projectgus.com>

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
local re, swd_states, RE_SWDSWITCH, RE_SWDREQ, RE_IDLE, RISING, FALLING, ADDR_DP_SELECT, ADDR_DP_CTRLSTAT, BIT_SELECT_CTRLSEL, BIT_CTRLSTAT_ORUNDETECT, ANNOTATIONS, Decoder
local _decoder

re = logicview.re
swd_states = { "IDLE", "REQUEST", "ACK", "READ", "WRITE", "DPARITY" }
RE_SWDSWITCH = re.compile(logicview.add(logicview.slice(logicview.bin(59294), nil, 1, (-1)), "$"))
RE_SWDREQ = re.compile("1(?P<apdp>.)(?P<rw>.)(?P<addr>..)(?P<parity>.)01$")
RE_IDLE = re.compile(logicview.add(logicview.mul("0", 50), "$"))
RISING = 1
FALLING = 0
ADDR_DP_SELECT = 8
ADDR_DP_CTRLSTAT = 4
BIT_SELECT_CTRLSEL = 1
BIT_CTRLSTAT_ORUNDETECT = 1
ANNOTATIONS = { "reset", "enable", "read", "write", "ack", "data", "parity" }
_decoder = {
  api_version = 3,
  id = "swd",
  name = "SWD",
  longname = "Serial Wire Debug",
  desc = "Two-wire protocol for debug access to ARM CPUs.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "swd" },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "swclk", name = "SWCLK", desc = "Master clock" }), logicview.dict({ id = "swdio", name = "SWDIO", desc = "Data input/output" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "strict_start", desc = "Wait for a line reset before starting to decode", default = "no", values = { "yes", "no" } }) },
  annotations = { { "reset", "RESET" }, { "enable", "ENABLE" }, { "read", "READ" }, { "write", "WRITE" }, { "ack", "ACK" }, { "data", "DATA" }, { "parity", "PARITY" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "UNKNOWN"
  self.sample_edge = RISING
  self.ack = nil
  self.ss_req = 0
  self.turnaround = 0
  self.bits = ""
  self.samplenums = {  }
  self.linereset_count = 0
  self.data = nil
  self.addr = nil
  self.rw = nil
  self.ctrlsel = 0
  self.orundetect = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "strict_start"), "no")) then
    self.state = "REQ"
  end
end
function _decoder.putx(self, ann, length, data)
  local ss, es
  ann = (function() if _type(ANNOTATIONS) == 'string' then local _n = logicview.find(ANNOTATIONS, ann); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(ANNOTATIONS, ann) end)()
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      ss = logicview.idx(self.samplenums, (-length))
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "IndexError") then
        ss = logicview.idx(self.samplenums, 0)
      else
        _error(_err, 0)
      end
    end
  end
  if logicview.truth(logicview.eq(self.state, "REQ")) then
    self.ss_req = ss
  end
  es = self.samplenum
  self:put(ss, es, self.out_ann, { ann, { data } })
end
function _decoder.putp(self, ptype, pdata)
  self:put(self.ss_req, self.samplenum, self.out_python, { ptype, pdata })
end
function _decoder.put_python_data(self)
  local ptype
  ptype = logicview.idx(logicview.dict({ [logicview.tkey("AP", "R")] = "AP_READ", [logicview.tkey("AP", "W")] = "AP_WRITE", [logicview.tkey("DP", "R")] = "DP_READ", [logicview.tkey("DP", "W")] = "DP_WRITE" }), logicview.tkey(self.apdp, self.rw))
  self:putp(ptype, { self.addr, self.data, self.ack })
end
function _decoder.decode(self)
  local clk, dio
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      dio = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(clk, RISING)) then
      if logicview.truth(logicview.eq(dio, 1)) then
        self.linereset_count = logicview.add(self.linereset_count, 1)
      else
        if logicview.truth((self.linereset_count >= 50)) then
          self:putx("reset", self.linereset_count, "LINERESET")
          self:putp("LINE_RESET", nil)
          self:reset_state()
        end
        self.linereset_count = 0
      end
    end
    if logicview.truth((not logicview.eq(clk, self.sample_edge))) then
      goto continue_1
    end
    if logicview.truth((self.turnaround > 0)) then
      self.turnaround = (self.turnaround - 1)
      goto continue_1
    end
    self.bits = logicview.add(self.bits, _tostring(dio))
    _table.insert(self.samplenums, self.samplenum)
    logicview.idx(logicview.dict({ UNKNOWN = self.handle_unknown_edge, REQ = self.handle_req_edge, ACK = self.handle_ack_edge, DATA = self.handle_data_edge, DPARITY = self.handle_dparity_edge }), self.state)()
    ::continue_1::
  end
end
function _decoder.next_state(self)
  self.bits = ""
  self.samplenums = {  }
  self.linereset_count = 0
  if logicview.truth(logicview.eq(self.state, "UNKNOWN")) then
    self.state = "REQ"
    self.sample_edge = RISING
    self.turnaround = 0
  elseif logicview.truth(logicview.eq(self.state, "REQ")) then
    self.state = "ACK"
    self.sample_edge = FALLING
    self.turnaround = 1
  elseif logicview.truth(logicview.eq(self.state, "ACK")) then
    self.state = "DATA"
    self.sample_edge = (function() if logicview.truth(logicview.eq(self.rw, "W")) then return RISING else return FALLING end end)()
    self.turnaround = (function() if logicview.truth(logicview.eq(self.rw, "R")) then return 0 else return 2 end end)()
  elseif logicview.truth(logicview.eq(self.state, "DATA")) then
    self.state = "DPARITY"
  elseif logicview.truth(logicview.eq(self.state, "DPARITY")) then
    self.state = "REQ"
    self.sample_edge = RISING
    self.turnaround = (function() if logicview.truth(logicview.eq(self.rw, "R")) then return 1 else return 0 end end)()
  end
end
function _decoder.reset_state(self)
  self.bits = ""
  self.samplenums = {  }
  self.linereset_count = 0
  self.turnaround = 0
  self.sample_edge = RISING
  self.data = ""
  self.ack = nil
  self.state = "REQ"
end
function _decoder.handle_unknown_edge(self)
end
function _decoder.handle_req_edge(self)
  local m, calc_parity, parity
  m = re.search(RE_SWDSWITCH, self.bits)
  if logicview.truth((m ~= nil)) then
    self:putx("enable", 16, "JTAG->SWD")
    self:reset_state()
    return
  end
  m = re.search(RE_SWDREQ, self.bits)
  if logicview.truth((m ~= nil)) then
    calc_parity = logicview.pymod(logicview.sum((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.add(logicview.add(m:group("rw"), m:group("apdp")), m:group("addr"))) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.tointeger(x)
  end
  return _lv_out
end)()), 2)
    parity = (function() if logicview.truth(logicview.eq(_tostring(calc_parity), m:group("parity"))) then return "" else return "E" end end)()
    self.rw = (function() if logicview.truth(logicview.eq(m:group("rw"), "1")) then return "R" else return "W" end end)()
    self.apdp = (function() if logicview.truth(logicview.eq(m:group("apdp"), "1")) then return "AP" else return "DP" end end)()
    self.addr = (logicview.tointeger(logicview.slice(m:group("addr"), nil, nil, (-1)), 2) << 2)
    self:putx((function() if logicview.truth(logicview.eq(self.rw, "R")) then return "read" else return "write" end end)(), 8, self:get_address_description())
    self:next_state()
    return
  end
end
function _decoder.handle_ack_edge(self)
  if logicview.truth((logicview.len(self.bits) < 3)) then
    return
  end
  if logicview.truth(logicview.eq(self.bits, "100")) then
    self:putx("ack", 3, "OK")
    self.ack = "OK"
    self:next_state()
  elseif logicview.truth(logicview.eq(self.bits, "001")) then
    self:putx("ack", 3, "FAULT")
    self.ack = "FAULT"
    if logicview.truth(logicview.eq(self.orundetect, 1)) then
      self:next_state()
    else
      self:reset_state()
    end
    self.turnaround = 1
  elseif logicview.truth(logicview.eq(self.bits, "010")) then
    self:putx("ack", 3, "WAIT")
    self.ack = "WAIT"
    if logicview.truth(logicview.eq(self.orundetect, 1)) then
      self:next_state()
    else
      self:reset_state()
    end
    self.turnaround = 1
  elseif logicview.truth(logicview.eq(self.bits, "111")) then
    self:putx("ack", 3, "NOREPLY")
    self.ack = "NOREPLY"
    self:reset_state()
  else
    self:putx("ack", 3, "ERROR")
    self.ack = "ERROR"
    self:reset_state()
  end
end
function _decoder.handle_data_edge(self)
  local x
  if logicview.truth((logicview.len(self.bits) < 32)) then
    return
  end
  self.data = 0
  self.dparity = 0
  for _lv_i in logicview.range(32) do
    x = _lv_i
    if logicview.truth(logicview.eq(logicview.idx(self.bits, x), "1")) then
      self.data = logicview.add(self.data, (1 << x))
      self.dparity = logicview.add(self.dparity, 1)
    end
    ::continue_2::
  end
  self.dparity = logicview.pymod(self.dparity, 2)
  self:putx("data", 32, logicview.pymod("0x%08x", self.data))
  self:next_state()
end
function _decoder.handle_dparity_edge(self)
  if logicview.truth((not logicview.eq(_tostring(self.dparity), self.bits))) then
    self:putx("parity", 1, logicview.add(_tostring(self.dparity), self.bits))
  elseif logicview.truth(logicview.eq(self.rw, "W")) then
    self:handle_completed_write()
  end
  self:next_state()
end
function _decoder.handle_completed_write(self)
  if logicview.truth((not logicview.eq(self.apdp, "DP"))) then
    return
  elseif logicview.truth(logicview.eq(self.addr, ADDR_DP_SELECT)) then
    self.ctrlsel = (self.data & BIT_SELECT_CTRLSEL)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.addr, ADDR_DP_CTRLSTAT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.ctrlsel, 0)
  return _v
end)()) then
    self.orundetect = (self.data & BIT_CTRLSTAT_ORUNDETECT)
  end
end
function _decoder.get_address_description(self)
  if logicview.truth(logicview.eq(self.apdp, "DP")) then
    if logicview.truth(logicview.eq(self.rw, "R")) then
      return logicview.idx(logicview.dict({ [0] = "IDCODE", [4] = (function() if logicview.truth(logicview.eq(self.ctrlsel, 0)) then return "R CTRL/STAT" else return "R DLCR" end end)(), [8] = "RESEND", [12] = "RDBUFF" }), self.addr)
    elseif logicview.truth(logicview.eq(self.rw, "W")) then
      return logicview.idx(logicview.dict({ [0] = "W ABORT", [4] = (function() if logicview.truth(logicview.eq(self.ctrlsel, 0)) then return "W CTRL/STAT" else return "W DLCR" end end)(), [8] = "W SELECT", [12] = "W RESERVED" }), self.addr)
    end
  elseif logicview.truth(logicview.eq(self.apdp, "AP")) then
    if logicview.truth(logicview.eq(self.rw, "R")) then
      return logicview.pymod("R AP%x", self.addr)
    elseif logicview.truth(logicview.eq(self.rw, "W")) then
      return logicview.pymod("W AP%x", self.addr)
    end
  end
  return logicview.pymod("? %s%s%x", { self.rw, self.apdp, self.addr })
end

return _decoder
