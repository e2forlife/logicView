-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Stefan Brüns <stefan.bruens@rwth-aachen.de>

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
local PIN_DATA, PIN_RESET, ROW_EDGE, ROW_WORD, ROW_RESET, Decoder
local _decoder

do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  PIN_DATA = logicview.idx(_lv_seq, 0)
  PIN_RESET = logicview.idx(_lv_seq, 1)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(3) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ROW_EDGE = logicview.idx(_lv_seq, 0)
  ROW_WORD = logicview.idx(_lv_seq, 1)
  ROW_RESET = logicview.idx(_lv_seq, 2)
end
_decoder = {
  api_version = 3,
  id = "counter",
  name = "Counter",
  longname = "Edge counter",
  desc = "Count the number of edges in a signal.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Util" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = { logicview.dict({ id = "reset", name = "Reset", desc = "Reset line" }) },
  options = { logicview.dict({ id = "data_edge", desc = "Edges to count (data)", default = "any", values = { "any", "rising", "falling" } }), logicview.dict({ id = "divider", desc = "Count divider (word width)", default = 0, values = {  } }), logicview.dict({ id = "reset_edge", desc = "Edge which clears counters (reset)", default = "falling", values = { "rising", "falling" } }), logicview.dict({ id = "edge_off", desc = "Edge counter value after start/reset", default = 0, values = {  } }), logicview.dict({ id = "word_off", desc = "Word counter value after start/reset", default = 0, values = {  } }), logicview.dict({ id = "dead_cycles", desc = "Ignore this many edges after reset", default = 0, values = {  } }), logicview.dict({ id = "start_with_reset", desc = "Assume decode starts with reset", default = "no", values = { "no", "yes" } }) },
  annotations = { { "edge_count", "Edge count" }, { "word_count", "Word count" }, { "word_reset", "Word reset" } },
  annotation_rows = { { "edge_counts", "Edges", { 0 } }, { "word_counts", "Words", { 1 } }, { "word_resets", "Word resets", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putc(self, cls, ss, annlist)
  self:put(ss, self.samplenum, self.out_ann, { cls, annlist })
end
function _decoder.decode(self)
  local opt_edge_map, data_edge, divider, reset_edge, condition, have_reset, cond_reset, edge_count, edge_start, word_count, word_start, dead_count, now, word_edge_count
  opt_edge_map = logicview.dict({ rising = "r", falling = "f", any = "e" })
  data_edge = logicview.idx(self.options, "data_edge")
  divider = logicview.idx(self.options, "divider")
  if logicview.truth((divider < 0)) then
    divider = 0
  end
  reset_edge = logicview.idx(self.options, "reset_edge")
  condition = { logicview.dict({ [PIN_DATA] = logicview.idx(opt_edge_map, data_edge) }) }
  have_reset = self:has_channel(PIN_RESET)
  if logicview.truth(have_reset) then
    cond_reset = logicview.len(condition)
    _table.insert(condition, logicview.dict({ [PIN_RESET] = logicview.idx(opt_edge_map, reset_edge) }))
  end
  edge_count = logicview.tointeger(logicview.idx(self.options, "edge_off"))
  edge_start = nil
  word_count = logicview.tointeger(logicview.idx(self.options, "word_off"))
  word_start = nil
  if logicview.truth(logicview.eq(logicview.idx(self.options, "start_with_reset"), "yes")) then
    dead_count = logicview.tointeger(logicview.idx(self.options, "dead_cycles"))
  else
    dead_count = 0
  end
  while true do
    self:wait(condition)
    now = self.samplenum
    if logicview.truth((function()
  local _v
  _v = have_reset
  if not logicview.truth(_v) then return _v end
  _v = (self.matched & (1 << cond_reset))
  return _v
end)()) then
      edge_count = logicview.tointeger(logicview.idx(self.options, "edge_off"))
      edge_start = now
      word_count = logicview.tointeger(logicview.idx(self.options, "word_off"))
      word_start = now
      self:putc(ROW_RESET, now, { "Word reset", "Reset", "Rst", "R" })
      dead_count = logicview.tointeger(logicview.idx(self.options, "dead_cycles"))
      goto continue_1
    end
    if logicview.truth(dead_count) then
      dead_count = (dead_count - 1)
      edge_start = now
      word_start = now
      goto continue_1
    end
    if logicview.truth((edge_start == nil)) then
      edge_start = 0
    end
    if logicview.truth((word_start == nil)) then
      word_start = 0
    end
    edge_count = logicview.add(edge_count, 1)
    self:putc(ROW_EDGE, edge_start, { logicview.pyformat("{:d}", { edge_count }, logicview.dict({})) })
    edge_start = now
    word_edge_count = (edge_count - logicview.tointeger(logicview.idx(self.options, "edge_off")))
    if logicview.truth((function()
  local _v
  _v = divider
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.pymod(word_edge_count, divider), 0)
  return _v
end)()) then
      word_count = logicview.add(word_count, 1)
      self:putc(ROW_WORD, word_start, { logicview.pyformat("{:d}", { word_count }, logicview.dict({})) })
      word_start = now
    end
    ::continue_1::
  end
end

return _decoder
