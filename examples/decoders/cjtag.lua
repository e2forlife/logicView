-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2020 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2019 Zhiyuan Wan <dv.xw@qq.com>
-- Copyright (C) 2019 Kongou Hikari <hikari@iloli.bid>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local SrdStrEnum, s, St, jtag_states, CSt, cjtag_states, Decoder
local _decoder

s = "TEST-LOGIC-RESET RUN-TEST/IDLE      SELECT-DR-SCAN CAPTURE-DR UPDATE-DR PAUSE-DR SHIFT-DR EXIT1-DR EXIT2-DR      SELECT-IR-SCAN CAPTURE-IR UPDATE-IR PAUSE-IR SHIFT-IR EXIT1-IR EXIT2-IR"
St = logicview.str_enum(logicview.split(s, ' '))
jtag_states = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(St) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = s.value
  end
  return _lv_out
end)()
s = logicview.split("EC SPARE TPDEL TPREV TPST RDYC DLYC SCNFMT CP OAC", nil, nil)
s = logicview.add((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("CJTAG_", x)
  end
  return _lv_out
end)(), { "OSCAN1", "FOUR_WIRE" })
CSt = logicview.str_enum(s)
cjtag_states = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(CSt) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = s.value
  end
  return _lv_out
end)()
_decoder = {
  api_version = 3,
  id = "cjtag",
  name = "cJTAG",
  longname = "Compact Joint Test Action Group (IEEE 1149.7)",
  desc = "Protocol for testing, debugging, and flashing ICs.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "jtag" },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "tckc", name = "TCKC", desc = "Test clock" }), logicview.dict({ id = "tmsc", name = "TMSC", desc = "Test mode select" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "test-logic-reset", "TEST-LOGIC-RESET" }, { "run-test/idle", "RUN-TEST/IDLE" }, { "select-dr-scan", "SELECT-DR-SCAN" }, { "capture-dr", "CAPTURE-DR" }, { "update-dr", "UPDATE-DR" }, { "pause-dr", "PAUSE-DR" }, { "shift-dr", "SHIFT-DR" }, { "exit1-dr", "EXIT1-DR" }, { "exit2-dr", "EXIT2-DR" }, { "select-ir-scan", "SELECT-IR-SCAN" }, { "capture-ir", "CAPTURE-IR" }, { "update-ir", "UPDATE-IR" }, { "pause-ir", "PAUSE-IR" }, { "shift-ir", "SHIFT-IR" }, { "exit1-ir", "EXIT1-IR" }, { "exit2-ir", "EXIT2-IR" }, { "cjtag_ec", "CJTAG_EC" }, { "cjtag_spare", "CJTAG_SPARE" }, { "cjtag_tpdel", "CJTAG_TPDEL" }, { "cjtag_tprev", "CJTAG_TPREV" }, { "cjtag_tpst", "CJTAG_TPST" }, { "cjtag_rdyc", "CJTAG_RDYC" }, { "cjtag_dlyc", "CJTAG_DLYC" }, { "cjtag_scnfmt", "CJTAG_SCNFMT" }, { "cjtag_cp", "CJTAG_CP" }, { "cjtag_oac", "CJTAG_OAC" }, { "oscan1", "OSCAN1" }, { "four_wire", "FOUR_WIRE" }, { "bit-tdi", "Bit (TDI)" }, { "bit-tdo", "Bit (TDO)" }, { "bitstring-tdi", "Bitstring (TDI)" }, { "bitstring-tdo", "Bitstring (TDO)" }, { "bit-tms", "Bit (TMS)" } },
  annotation_rows = { { "bits-tdi", "Bits (TDI)", { 28 } }, { "bits-tdo", "Bits (TDO)", { 29 } }, { "bitstrings-tdi", "Bitstrings (TDI)", { 30 } }, { "bitstrings-tdo", "Bitstrings (TDO)", { 31 } }, { "bits-tms", "Bits (TMS)", { 32 } }, { "cjtag-states", "CJTAG states", { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 } }, { "jtag-states", "JTAG states", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = St.RUN_TEST_IDLE
  self.cjtagstate = CSt.FOUR_WIRE
  self.oldcjtagstate = nil
  self.escape_edges = 0
  self.oaclen = 0
  self.oldtms = 0
  self.oacp = 0
  self.oscan1cycle = 0
  self.oldstate = nil
  self.bits_tdi = {  }
  self.bits_tdo = {  }
  self.bits_samplenums_tdi = {  }
  self.bits_samplenums_tdo = {  }
  do
    local _lv_chain = nil
    self.ss_item = _lv_chain
    self.es_item = _lv_chain
  end
  do
    local _lv_chain = nil
    self.ss_bitstring = _lv_chain
    self.es_bitstring = _lv_chain
  end
  self.saved_item = nil
  self.first = true
  self.first_bit = true
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_item, self.es_item, self.out_ann, data)
end
function _decoder.putp(self, data)
  self:put(self.ss_item, self.es_item, self.out_python, data)
end
function _decoder.putx_bs(self, data)
  self:put(self.ss_bitstring, self.es_bitstring, self.out_ann, data)
end
function _decoder.putp_bs(self, data)
  self:put(self.ss_bitstring, self.es_bitstring, self.out_python, data)
end
function _decoder.advance_state_machine(self, tms)
  self.oldstate = self.state
  if logicview.truth(logicview.startswith(self.cjtagstate.value, "CJTAG_")) then
    self.oacp = logicview.add(self.oacp, 1)
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 4)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 12)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_EC
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.oacp, 8)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(tms, 0)
  return _v
end)()) then
      self.oaclen = 36
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 8)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_SPARE
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 13)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_TPDEL
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 16)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_TPREV
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 18)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_TPST
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 23)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_RDYC
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 25)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_DLYC
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 27)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_SCNFMT
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 8)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 12)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_CP
    end
    if logicview.truth((function()
  local _v
  _v = (self.oacp > 32)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oaclen, 36)
  return _v
end)()) then
      self.cjtagstate = CSt.CJTAG_CP
    end
    if logicview.truth((self.oacp > self.oaclen)) then
      self.cjtagstate = CSt.OSCAN1
      self.oscan1cycle = 1
      self.state = St.TEST_LOGIC_RESET
    end
    return
  end
  if logicview.truth(logicview.eq(self.state, St.TEST_LOGIC_RESET)) then
    self.state = (function() if logicview.truth(tms) then return St.TEST_LOGIC_RESET else return St.RUN_TEST_IDLE end end)()
  elseif logicview.truth(logicview.eq(self.state, St.RUN_TEST_IDLE)) then
    self.state = (function() if logicview.truth(tms) then return St.SELECT_DR_SCAN else return St.RUN_TEST_IDLE end end)()
  elseif logicview.truth(logicview.eq(self.state, St.SELECT_DR_SCAN)) then
    self.state = (function() if logicview.truth(tms) then return St.SELECT_IR_SCAN else return St.CAPTURE_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.CAPTURE_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT1_DR else return St.SHIFT_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.SHIFT_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT1_DR else return St.SHIFT_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.EXIT1_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.UPDATE_DR else return St.PAUSE_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.PAUSE_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT2_DR else return St.PAUSE_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.EXIT2_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.UPDATE_DR else return St.SHIFT_DR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.UPDATE_DR)) then
    self.state = (function() if logicview.truth(tms) then return St.SELECT_DR_SCAN else return St.RUN_TEST_IDLE end end)()
  elseif logicview.truth(logicview.eq(self.state, St.SELECT_IR_SCAN)) then
    self.state = (function() if logicview.truth(tms) then return St.TEST_LOGIC_RESET else return St.CAPTURE_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.CAPTURE_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT1_IR else return St.SHIFT_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.SHIFT_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT1_IR else return St.SHIFT_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.EXIT1_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.UPDATE_IR else return St.PAUSE_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.PAUSE_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.EXIT2_IR else return St.PAUSE_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.EXIT2_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.UPDATE_IR else return St.SHIFT_IR end end)()
  elseif logicview.truth(logicview.eq(self.state, St.UPDATE_IR)) then
    self.state = (function() if logicview.truth(tms) then return St.SELECT_DR_SCAN else return St.RUN_TEST_IDLE end end)()
  end
end
function _decoder.handle_rising_tckc_edge(self, tdi, tdo, tck, tms)
  local t, b, h, s
  self:advance_state_machine(tms)
  if logicview.truth(self.first) then
    self.ss_item = self.samplenum
    self.first = false
  else
    self.es_item = self.samplenum
    self:putx({ (function() if _type(jtag_states) == 'string' then local _n = logicview.find(jtag_states, self.oldstate.value); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(jtag_states, self.oldstate.value) end)(), { self.oldstate.value } })
    self:putp({ "NEW STATE", self.state.value })
    self:putx({ logicview.add(logicview.len(jtag_states), (function() if _type(cjtag_states) == 'string' then local _n = logicview.find(cjtag_states, self.oldcjtagstate.value); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(cjtag_states, self.oldcjtagstate.value) end)()), { self.oldcjtagstate.value } })
    if logicview.truth(logicview.startswith(self.oldcjtagstate.value, "CJTAG_")) then
      self:putx({ 32, { _tostring(self.oldtms) } })
    end
  end
  self.oldtms = tms
  if logicview.truth((function()
  local _v
  _v = logicview.startswith(self.oldstate.value, "SHIFT-")
  if logicview.truth(_v) then return _v end
  _v = logicview.startswith(self.oldstate.value, "EXIT1-")
  return _v
end)()) then
    if logicview.truth(self.first_bit) then
      self.ss_bitstring = self.samplenum
      self.first_bit = false
    else
      self:putx({ 28, { _tostring(logicview.idx(self.bits_tdi, 0)) } })
      self:putx({ 29, { _tostring(logicview.idx(self.bits_tdo, 0)) } })
      logicview.setidx(logicview.idx(self.bits_samplenums_tdi, 0), 1, self.samplenum)
      logicview.setidx(logicview.idx(self.bits_samplenums_tdo, 0), 1, self.samplenum)
    end
    logicview.list_insert(self.bits_tdi, 0, tdi)
    logicview.list_insert(self.bits_tdo, 0, tdo)
    logicview.list_insert(self.bits_samplenums_tdi, 0, { self.samplenum, (-1) })
    logicview.list_insert(self.bits_samplenums_tdo, 0, { self.samplenum, (-1) })
  end
  if logicview.truth(logicview.startswith(self.state.value, "UPDATE-")) then
    self.es_bitstring = self.samplenum
    t = logicview.add(logicview.slice(self.state.value, (-2), nil, nil), " TDI")
    b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(logicview.slice(self.bits_tdi, 1, nil, nil)) do _t[#_t + 1] = str(_v) end; return _t end)())
    b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(b) do if logicview.truth((function(x) return logicview.contains("01", x) end)(_v)) then _t[#_t + 1] = _v end end; return _t end)())
    h = logicview.add(logicview.pymod(" (0x%x", logicview.tointeger(logicview.add("0b0", b), 2)), ")")
    s = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(t, ": "), b), h), ", "), _tostring(logicview.len(logicview.slice(self.bits_tdi, 1, nil, nil)))), " bits")
    self:putx_bs({ 30, { s } })
    self:putp_bs({ t, { b, logicview.slice(self.bits_samplenums_tdi, 1, nil, nil) } })
    self.bits_tdi = {  }
    self.bits_samplenums_tdi = {  }
    t = logicview.add(logicview.slice(self.state.value, (-2), nil, nil), " TDO")
    b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(logicview.slice(self.bits_tdo, 1, nil, nil)) do _t[#_t + 1] = str(_v) end; return _t end)())
    b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(b) do if logicview.truth((function(x) return logicview.contains("01", x) end)(_v)) then _t[#_t + 1] = _v end end; return _t end)())
    h = logicview.add(logicview.pymod(" (0x%x", logicview.tointeger(logicview.add("0b0", b), 2)), ")")
    s = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(t, ": "), b), h), ", "), _tostring(logicview.len(logicview.slice(self.bits_tdo, 1, nil, nil)))), " bits")
    self:putx_bs({ 31, { s } })
    self:putp_bs({ t, { b, logicview.slice(self.bits_samplenums_tdo, 1, nil, nil) } })
    self.bits_tdo = {  }
    self.bits_samplenums_tdo = {  }
    self.first_bit = true
    self.ss_bitstring = self.samplenum
  end
  self.ss_item = self.samplenum
end
function _decoder.handle_tmsc_edge(self)
  self.escape_edges = logicview.add(self.escape_edges, 1)
end
function _decoder.handle_tapc_state(self)
  self.oldcjtagstate = self.cjtagstate
  if logicview.truth((self.escape_edges >= 8)) then
    self.cjtagstate = CSt.FOUR_WIRE
  end
  if logicview.truth(logicview.eq(self.escape_edges, 6)) then
    self.cjtagstate = CSt.CJTAG_OAC
    self.oacp = 0
    self.oaclen = 12
  end
  self.escape_edges = 0
end
function _decoder.decode(self)
  local tdi, tms, tdo, tckc, tmsc, tmsc_n
  do
    local _lv_chain = 0
    tdi = _lv_chain
    tms = _lv_chain
    tdo = _lv_chain
  end
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      tckc = logicview.idx(_lv_seq, 0)
      tmsc = logicview.idx(_lv_seq, 1)
    end
    self:handle_tapc_state()
    if logicview.truth(logicview.eq(self.cjtagstate, CSt.OSCAN1)) then
      if logicview.truth(logicview.eq(self.oscan1cycle, 0)) then
        tdi = (function() if logicview.truth(logicview.eq(tmsc, 0)) then return 1 else return 0 end end)()
        self.oscan1cycle = 1
      elseif logicview.truth(logicview.eq(self.oscan1cycle, 1)) then
        tms = tmsc
        self.oscan1cycle = 2
      elseif logicview.truth(logicview.eq(self.oscan1cycle, 2)) then
        tdo = tmsc
        self:handle_rising_tckc_edge(tdi, tdo, tckc, tms)
        self.oscan1cycle = 0
      end
    else
      self:handle_rising_tckc_edge(nil, nil, tckc, tmsc)
    end
    while logicview.truth(logicview.eq(tckc, 1)) do
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [1] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        tckc = logicview.idx(_lv_seq, 0)
        tmsc_n = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((not logicview.eq(tmsc_n, tmsc))) then
        tmsc = tmsc_n
        self:handle_tmsc_edge()
      end
      ::continue_2::
    end
    ::continue_1::
  end
end

return _decoder
