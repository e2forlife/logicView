-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2015 Uwe Hermann <uwe@hermann-uwe.de>
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
local jtag_states, Decoder
local _decoder

jtag_states = { "TEST-LOGIC-RESET", "RUN-TEST/IDLE", "SELECT-DR-SCAN", "CAPTURE-DR", "UPDATE-DR", "PAUSE-DR", "SHIFT-DR", "EXIT1-DR", "EXIT2-DR", "SELECT-IR-SCAN", "CAPTURE-IR", "UPDATE-IR", "PAUSE-IR", "SHIFT-IR", "EXIT1-IR", "EXIT2-IR" }
_decoder = {
  api_version = 3,
  id = "jtag",
  name = "JTAG",
  longname = "Joint Test Action Group (IEEE 1149.1)",
  desc = "Protocol for testing, debugging, and flashing ICs.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "jtag" },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "tdi", name = "TDI", desc = "Test data input" }), logicview.dict({ id = "tdo", name = "TDO", desc = "Test data output" }), logicview.dict({ id = "tck", name = "TCK", desc = "Test clock" }), logicview.dict({ id = "tms", name = "TMS", desc = "Test mode select" }) },
  optional_channels = { logicview.dict({ id = "trst", name = "TRST#", desc = "Test reset" }), logicview.dict({ id = "srst", name = "SRST#", desc = "System reset" }), logicview.dict({ id = "rtck", name = "RTCK", desc = "Return clock signal" }) },
  options = {  },
  annotations = { { "test-logic-reset", "TEST-LOGIC-RESET" }, { "run-test/idle", "RUN-TEST/IDLE" }, { "select-dr-scan", "SELECT-DR-SCAN" }, { "capture-dr", "CAPTURE-DR" }, { "update-dr", "UPDATE-DR" }, { "pause-dr", "PAUSE-DR" }, { "shift-dr", "SHIFT-DR" }, { "exit1-dr", "EXIT1-DR" }, { "exit2-dr", "EXIT2-DR" }, { "select-ir-scan", "SELECT-IR-SCAN" }, { "capture-ir", "CAPTURE-IR" }, { "update-ir", "UPDATE-IR" }, { "pause-ir", "PAUSE-IR" }, { "shift-ir", "SHIFT-IR" }, { "exit1-ir", "EXIT1-IR" }, { "exit2-ir", "EXIT2-IR" }, { "bit-tdi", "Bit (TDI)" }, { "bit-tdo", "Bit (TDO)" }, { "bitstring-tdi", "Bitstring (TDI)" }, { "bitstring-tdo", "Bitstring (TDO)" } },
  annotation_rows = { { "bits-tdi", "Bits (TDI)", { 16 } }, { "bits-tdo", "Bits (TDO)", { 17 } }, { "bitstrings-tdi", "Bitstring (TDI)", { 18 } }, { "bitstrings-tdo", "Bitstring (TDO)", { 19 } }, { "states", "States", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "RUN-TEST/IDLE"
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
  self.bits_cnt = 0
  self.data_ready = false
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
  if logicview.truth(logicview.eq(self.state, "TEST-LOGIC-RESET")) then
    self.state = (function() if logicview.truth(tms) then return "TEST-LOGIC-RESET" else return "RUN-TEST/IDLE" end end)()
  elseif logicview.truth(logicview.eq(self.state, "RUN-TEST/IDLE")) then
    self.state = (function() if logicview.truth(tms) then return "SELECT-DR-SCAN" else return "RUN-TEST/IDLE" end end)()
  elseif logicview.truth(logicview.eq(self.state, "SELECT-DR-SCAN")) then
    self.state = (function() if logicview.truth(tms) then return "SELECT-IR-SCAN" else return "CAPTURE-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "CAPTURE-DR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT1-DR" else return "SHIFT-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "SHIFT-DR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT1-DR" else return "SHIFT-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "EXIT1-DR")) then
    self.state = (function() if logicview.truth(tms) then return "UPDATE-DR" else return "PAUSE-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "PAUSE-DR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT2-DR" else return "PAUSE-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "EXIT2-DR")) then
    self.state = (function() if logicview.truth(tms) then return "UPDATE-DR" else return "SHIFT-DR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "UPDATE-DR")) then
    self.state = (function() if logicview.truth(tms) then return "SELECT-DR-SCAN" else return "RUN-TEST/IDLE" end end)()
  elseif logicview.truth(logicview.eq(self.state, "SELECT-IR-SCAN")) then
    self.state = (function() if logicview.truth(tms) then return "TEST-LOGIC-RESET" else return "CAPTURE-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "CAPTURE-IR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT1-IR" else return "SHIFT-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "SHIFT-IR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT1-IR" else return "SHIFT-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "EXIT1-IR")) then
    self.state = (function() if logicview.truth(tms) then return "UPDATE-IR" else return "PAUSE-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "PAUSE-IR")) then
    self.state = (function() if logicview.truth(tms) then return "EXIT2-IR" else return "PAUSE-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "EXIT2-IR")) then
    self.state = (function() if logicview.truth(tms) then return "UPDATE-IR" else return "SHIFT-IR" end end)()
  elseif logicview.truth(logicview.eq(self.state, "UPDATE-IR")) then
    self.state = (function() if logicview.truth(tms) then return "SELECT-DR-SCAN" else return "RUN-TEST/IDLE" end end)()
  end
end
function _decoder.handle_rising_tck_edge(self, tdi, tdo, tck, tms, trst, srst, rtck)
  local t, b, h, s
  self:advance_state_machine(tms)
  if logicview.truth(self.first) then
    self.ss_item = self.samplenum
    self.first = false
  else
    self.es_item = self.samplenum
    self:putx({ (function() if _type(jtag_states) == 'string' then local _n = logicview.find(jtag_states, self.oldstate); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(jtag_states, self.oldstate) end)(), { self.oldstate } })
    self:putp({ "NEW STATE", self.state })
  end
  if logicview.truth(logicview.startswith(self.state, "SHIFT-")) then
    if logicview.truth((self.bits_cnt > 0)) then
      if logicview.truth(logicview.eq(self.bits_cnt, 1)) then
        self.ss_bitstring = self.samplenum
      end
      if logicview.truth((self.bits_cnt > 1)) then
        self:putx({ 16, { _tostring(logicview.idx(self.bits_tdi, 0)) } })
        self:putx({ 17, { _tostring(logicview.idx(self.bits_tdo, 0)) } })
        logicview.setidx(logicview.idx(self.bits_samplenums_tdi, 0), 1, self.samplenum)
        logicview.setidx(logicview.idx(self.bits_samplenums_tdo, 0), 1, self.samplenum)
      end
      logicview.list_insert(self.bits_tdi, 0, tdi)
      logicview.list_insert(self.bits_tdo, 0, tdo)
    end
    logicview.list_insert(self.bits_samplenums_tdi, 0, { self.samplenum, (-1) })
    logicview.list_insert(self.bits_samplenums_tdo, 0, { self.samplenum, (-1) })
    self.bits_cnt = logicview.add(self.bits_cnt, 1)
  end
  if logicview.truth((function()
  local _v
  _v = logicview.startswith(self.oldstate, "SHIFT-")
  if not logicview.truth(_v) then return _v end
  _v = logicview.startswith(self.state, "EXIT1-")
  return _v
end)()) then
    if logicview.truth((self.bits_cnt > 0)) then
      if logicview.truth(logicview.eq(self.bits_cnt, 1)) then
        self.ss_bitstring = self.samplenum
        logicview.list_insert(self.bits_tdi, 0, tdi)
        logicview.list_insert(self.bits_tdo, 0, tdo)
        logicview.list_insert(self.bits_samplenums_tdi, 0, { self.samplenum, (-1) })
        logicview.list_insert(self.bits_samplenums_tdo, 0, { self.samplenum, (-1) })
      else
        self:putx({ 16, { _tostring(logicview.idx(self.bits_tdi, 0)) } })
        self:putx({ 17, { _tostring(logicview.idx(self.bits_tdo, 0)) } })
        logicview.setidx(logicview.idx(self.bits_samplenums_tdi, 0), 1, self.samplenum)
        logicview.setidx(logicview.idx(self.bits_samplenums_tdo, 0), 1, self.samplenum)
        logicview.list_insert(self.bits_tdi, 0, tdi)
        logicview.list_insert(self.bits_tdo, 0, tdo)
        logicview.list_insert(self.bits_samplenums_tdi, 0, { self.samplenum, (-1) })
        logicview.list_insert(self.bits_samplenums_tdo, 0, { self.samplenum, (-1) })
      end
      self.data_ready = true
    end
    self.first_bit = true
    self.bits_cnt = 0
  end
  if logicview.truth(logicview.startswith(self.oldstate, "EXIT")) then
    if logicview.truth(self.data_ready) then
      self.data_ready = false
      self.es_bitstring = self.samplenum
      t = logicview.add(logicview.slice(self.state, (-2), nil, nil), " TDI")
      b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(self.bits_tdi) do _t[#_t + 1] = str(_v) end; return _t end)())
      h = logicview.add(logicview.pymod(" (0x%X", logicview.tointeger(logicview.add("0b", b), 2)), ")")
      s = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(t, ": "), h), ", "), _tostring(logicview.len(self.bits_tdi))), " bits")
      self:putx_bs({ 18, { s } })
      logicview.setidx(logicview.idx(self.bits_samplenums_tdi, 0), 1, self.samplenum)
      self:putp_bs({ t, { b, self.bits_samplenums_tdi } })
      self:putx({ 16, { _tostring(logicview.idx(self.bits_tdi, 0)) } })
      self.bits_tdi = {  }
      self.bits_samplenums_tdi = {  }
      t = logicview.add(logicview.slice(self.state, (-2), nil, nil), " TDO")
      b = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(self.bits_tdo) do _t[#_t + 1] = str(_v) end; return _t end)())
      h = logicview.add(logicview.pymod(" (0x%X", logicview.tointeger(logicview.add("0b", b), 2)), ")")
      s = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(t, ": "), h), ", "), _tostring(logicview.len(self.bits_tdo))), " bits")
      self:putx_bs({ 19, { s } })
      logicview.setidx(logicview.idx(self.bits_samplenums_tdo, 0), 1, self.samplenum)
      self:putp_bs({ t, { b, self.bits_samplenums_tdo } })
      self:putx({ 17, { _tostring(logicview.idx(self.bits_tdo, 0)) } })
      self.bits_tdo = {  }
      self.bits_samplenums_tdo = {  }
    end
  end
  self.ss_item = self.samplenum
end
function _decoder.decode(self)
  local tdi, tdo, tck, tms, trst, srst, rtck
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [2] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      tdi = logicview.idx(_lv_seq, 0)
      tdo = logicview.idx(_lv_seq, 1)
      tck = logicview.idx(_lv_seq, 2)
      tms = logicview.idx(_lv_seq, 3)
      trst = logicview.idx(_lv_seq, 4)
      srst = logicview.idx(_lv_seq, 5)
      rtck = logicview.idx(_lv_seq, 6)
    end
    self:handle_rising_tck_edge(tdi, tdo, tck, tms, trst, srst, rtck)
    ::continue_1::
  end
end

return _decoder
