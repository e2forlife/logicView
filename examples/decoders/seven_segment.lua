-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Benedikt Otto <benedikt_o@web.de>

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
local ChannelError, digits, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
digits = logicview.dict({ [logicview.tkey(0, 0, 0, 0, 0, 0, 0)] = " ", [logicview.tkey(1, 1, 1, 1, 1, 1, 0)] = "0", [logicview.tkey(0, 1, 1, 0, 0, 0, 0)] = "1", [logicview.tkey(1, 1, 0, 1, 1, 0, 1)] = "2", [logicview.tkey(1, 1, 1, 1, 0, 0, 1)] = "3", [logicview.tkey(0, 1, 1, 0, 0, 1, 1)] = "4", [logicview.tkey(1, 0, 1, 1, 0, 1, 1)] = "5", [logicview.tkey(1, 0, 1, 1, 1, 1, 1)] = "6", [logicview.tkey(1, 1, 1, 0, 0, 0, 0)] = "7", [logicview.tkey(1, 1, 1, 1, 1, 1, 1)] = "8", [logicview.tkey(1, 1, 1, 1, 0, 1, 1)] = "9", [logicview.tkey(1, 1, 1, 0, 1, 1, 1)] = "A", [logicview.tkey(0, 0, 1, 1, 1, 1, 1)] = "B", [logicview.tkey(1, 0, 0, 1, 1, 1, 0)] = "C", [logicview.tkey(0, 1, 1, 1, 1, 0, 1)] = "D", [logicview.tkey(1, 0, 0, 1, 1, 1, 1)] = "E", [logicview.tkey(1, 0, 0, 0, 1, 1, 1)] = "F" })
_decoder = {
  api_version = 3,
  id = "seven_segment",
  name = "Segment-7",
  longname = "7-segment display",
  desc = "7-segment display protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Display" },
  channels = { logicview.dict({ id = "a", name = "A", desc = "Segment A" }), logicview.dict({ id = "b", name = "B", desc = "Segment B" }), logicview.dict({ id = "c", name = "C", desc = "Segment C" }), logicview.dict({ id = "d", name = "D", desc = "Segment D" }), logicview.dict({ id = "e", name = "E", desc = "Segment E" }), logicview.dict({ id = "f", name = "F", desc = "Segment F" }), logicview.dict({ id = "g", name = "G", desc = "Segment G" }) },
  optional_channels = { logicview.dict({ id = "dp", name = "DP", desc = "Decimal point" }) },
  options = { logicview.dict({ id = "polarity", desc = "Expected polarity", default = "common-cathode", values = { "common-cathode", "common-anode" } }) },
  annotations = { { "decoded-digit", "Decoded digit" } },
  annotation_rows = { { "decoded-digits", "Decoded digits", { 0 } } },
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
function _decoder.putb(self, ss_block, es_block, data)
  self:put(ss_block, es_block, self.out_ann, data)
end
function _decoder.pins_to_hex(self, pins)
  return logicview.dget(digits, pins, nil)
end
function _decoder.decode(self)
  local s0, s1, s2, s3, s4, s5, s6, dp, oldpins, lastpos, conditions, pins, digit
  do
    local _lv_seq = self:wait()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    s0 = logicview.idx(_lv_seq, 0)
    s1 = logicview.idx(_lv_seq, 1)
    s2 = logicview.idx(_lv_seq, 2)
    s3 = logicview.idx(_lv_seq, 3)
    s4 = logicview.idx(_lv_seq, 4)
    s5 = logicview.idx(_lv_seq, 5)
    s6 = logicview.idx(_lv_seq, 6)
    dp = logicview.idx(_lv_seq, 7)
  end
  oldpins = { s0, s1, s2, s3, s4, s5, s6, dp }
  if logicview.truth(logicview.contains((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(oldpins, nil, 7, nil)) do
    p = _lv_item
    _lv_out[#_lv_out + 1] = logicview.contains({ 0, 1 }, p)
  end
  return _lv_out
end)(), false)) then
    _error(ChannelError("7 or 8 pins have to be present."), 0)
  end
  lastpos = self.samplenum
  self.have_dp = self:has_channel(7)
  conditions = { logicview.dict({ [0] = "e" }), logicview.dict({ [1] = "e" }), logicview.dict({ [2] = "e" }), logicview.dict({ [3] = "e" }), logicview.dict({ [4] = "e" }), logicview.dict({ [5] = "e" }), logicview.dict({ [6] = "e" }) }
  if logicview.truth(self.have_dp) then
    _table.insert(conditions, logicview.dict({ [7] = "e" }))
  end
  while true do
    do
      local _lv_seq = self:wait(conditions)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      s0 = logicview.idx(_lv_seq, 0)
      s1 = logicview.idx(_lv_seq, 1)
      s2 = logicview.idx(_lv_seq, 2)
      s3 = logicview.idx(_lv_seq, 3)
      s4 = logicview.idx(_lv_seq, 4)
      s5 = logicview.idx(_lv_seq, 5)
      s6 = logicview.idx(_lv_seq, 6)
      dp = logicview.idx(_lv_seq, 7)
    end
    pins = { s0, s1, s2, s3, s4, s5, s6, dp }
    if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "common-anode")) then
      if logicview.truth(self.have_dp) then
        oldpins = logicview.copy((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(oldpins) do
    state = _lv_item
    _lv_out[#_lv_out + 1] = (1 - state)
  end
  return _lv_out
end)())
      else
        oldpins = logicview.copy((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(oldpins, nil, 7, nil)) do
    state = _lv_item
    _lv_out[#_lv_out + 1] = (1 - state)
  end
  return _lv_out
end)())
      end
    end
    digit = self:pins_to_hex(logicview.slice(oldpins, nil, 7, nil))
    if logicview.truth((digit ~= nil)) then
      dp = logicview.idx(oldpins, 7)
      if logicview.truth((function()
  local _v
  _v = self.have_dp
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(dp, 1)
  return _v
end)()) then
        digit = logicview.add(digit, ".")
      end
      self:putb(lastpos, self.samplenum, { 0, { digit } })
    end
    lastpos = self.samplenum
    oldpins = pins
    ::continue_1::
  end
end

return _decoder
