-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Shirow Miura <shirowmiura@gmail.com>

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
local symbol_map, START, STOP, CLOCK, DATA, Decoder
local _decoder

symbol_map = logicview.dict({ [0] = "0", [8] = "1", [4] = "2", [12] = "3", [2] = "4", [10] = "5", [6] = "6", [14] = "7", [1] = "8", [9] = "9", [5] = "A", [13] = "C", [3] = "F", [11] = "H", [7] = "P", [15] = "U" })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  START = logicview.idx(_lv_seq, 0)
  STOP = logicview.idx(_lv_seq, 1)
  CLOCK = logicview.idx(_lv_seq, 2)
  DATA = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "signature",
  name = "Signature",
  longname = "Signature analysis",
  desc = "Annotate signature of logic patterns.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Debug/trace", "Util", "Encoding" },
  channels = { logicview.dict({ id = "start", name = "START", desc = "START channel" }), logicview.dict({ id = "stop", name = "STOP", desc = "STOP channel" }), logicview.dict({ id = "clk", name = "CLOCK", desc = "CLOCK channel" }), logicview.dict({ id = "data", name = "DATA", desc = "DATA channel" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "start_edge", desc = "START edge polarity", default = "rising", values = { "rising", "falling" } }), logicview.dict({ id = "stop_edge", desc = "STOP edge polarity", default = "rising", values = { "rising", "falling" } }), logicview.dict({ id = "clk_edge", desc = "CLOCK edge polarity", default = "falling", values = { "rising", "falling" } }), logicview.dict({ id = "annbits", desc = "Enable bit level annotations", default = "no", values = { "yes", "no" } }) },
  annotations = { { "bit0", "Bit0" }, { "bit1", "Bit1" }, { "start", "START" }, { "stop", "STOP" }, { "signature", "Signature" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3 } }, { "signatures", "Signatures", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putsig(self, ss, es, signature)
  local s
  s = logicview.join("", { logicview.idx(symbol_map, ((signature >> 0) & 15)), logicview.idx(symbol_map, ((signature >> 4) & 15)), logicview.idx(symbol_map, ((signature >> 8) & 15)), logicview.idx(symbol_map, ((signature >> 12) & 15)) })
  self:put(ss, es, self.out_ann, { 4, { s } })
end
function _decoder.putb(self, ss, ann)
  self:put(ss, self.samplenum, self.out_ann, ann)
end
function _decoder.decode(self)
  local opt, start_edge_mode_rising, stop_edge_mode_rising, annbits, gate_is_open, sample_start, started, last_samplenum, prev_start, prev_stop, shiftreg, start, stop, _, data, s, incoming
  opt = self.options
  start_edge_mode_rising = logicview.eq(logicview.idx(opt, "start_edge"), "rising")
  stop_edge_mode_rising = logicview.eq(logicview.idx(opt, "stop_edge"), "rising")
  annbits = logicview.eq(logicview.idx(opt, "annbits"), "yes")
  gate_is_open = false
  sample_start = nil
  started = false
  last_samplenum = 0
  prev_start = (function() if logicview.truth(start_edge_mode_rising) then return 0 else return 1 end end)()
  prev_stop = (function() if logicview.truth(stop_edge_mode_rising) then return 0 else return 1 end end)()
  shiftreg = 0
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [CLOCK] = logicview.idx(opt, "clk_edge") }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      start = logicview.idx(_lv_seq, 0)
      stop = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
      data = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(start, prev_start))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(gate_is_open))
  return _v
end)()) then
      gate_is_open = (function() if logicview.truth(start_edge_mode_rising) then return logicview.eq(start, 1) else return logicview.eq(start, 0) end end)()
      if logicview.truth(gate_is_open) then
        sample_start = self.samplenum
        started = true
      end
    elseif logicview.truth((function()
  local _v
  _v = (not logicview.eq(stop, prev_stop))
  if not logicview.truth(_v) then return _v end
  _v = gate_is_open
  return _v
end)()) then
      gate_is_open = (not logicview.truth((function() if logicview.truth(stop_edge_mode_rising) then return logicview.eq(stop, 1) else return logicview.eq(stop, 0) end end)()))
      if logicview.truth((not logicview.truth(gate_is_open))) then
        if logicview.truth(annbits) then
          self:putb(last_samplenum, { 3, { "STOP", "STP", "P" } })
        end
        self:putsig(sample_start, self.samplenum, shiftreg)
        shiftreg = 0
        sample_start = nil
      end
    end
    if logicview.truth(gate_is_open) then
      if logicview.truth(annbits) then
        if logicview.truth(started) then
          s = logicview.pyformat("<{}>", { data }, logicview.dict({}))
          self:putb(last_samplenum, { 2, { logicview.add("START", s), logicview.add("STR", s), logicview.add("S", s) } })
          started = false
        else
          self:putb(last_samplenum, { data, { _tostring(data) } })
        end
      end
      incoming = (logicview.add(logicview.count(logicview.bin((shiftreg & 657)), "1"), data) & 1)
      shiftreg = ((incoming << 15) | (shiftreg >> 1))
    end
    prev_start = start
    prev_stop = stop
    last_samplenum = self.samplenum
    ::continue_1::
  end
end

return _decoder
