-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Marcus Comstedt <marcus@mc.pp.se>
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
local step_wait_conds, Decoder
local _decoder

step_wait_conds = { { logicview.dict({ [2] = "f" }), logicview.dict({ [0] = "l", [1] = "h" }) }, { logicview.dict({ [2] = "f" }), logicview.dict({ [0] = "h", [1] = "h" }), logicview.dict({ [1] = "l" }) }, { logicview.dict({ [2] = "f" }), logicview.dict({ [0] = "f" }), logicview.dict({ [1] = "l" }) }, { logicview.dict({ [2] = "f" }), logicview.dict({ [1] = "e" }) } }
_decoder = {
  api_version = 3,
  id = "iec",
  name = "IEC",
  longname = "Commodore IEC bus",
  desc = "Commodore serial IEEE-488 (IEC) bus protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PC", "Retro computing" },
  channels = { logicview.dict({ id = "data", name = "DATA", desc = "Data I/O" }), logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "atn", name = "ATN", desc = "Attention" }) },
  optional_channels = { logicview.dict({ id = "srq", name = "SRQ", desc = "Service request" }) },
  options = {  },
  annotations = { { "items", "Items" }, { "gpib", "DAT/CMD" }, { "eoi", "EOI" } },
  annotation_rows = { { "bytes", "Bytes", { 0 } }, { "gpib", "DAT/CMD", { 1 } }, { "eoi", "EOI", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.saved_ATN = false
  self.saved_EOI = false
  do
    local _lv_chain = nil
    self.ss_item = _lv_chain
    self.es_item = _lv_chain
  end
  self.step = 0
  self.bits = 0
  self.numbits = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putb(self, data)
  self:put(self.ss_item, self.es_item, self.out_ann, data)
end
function _decoder.handle_bits(self)
  local dbyte, dATN, dEOI
  dbyte = self.bits
  dATN = self.saved_ATN
  dEOI = self.saved_EOI
  self.es_item = self.samplenum
  self:putb({ 0, { logicview.pymod("%02X", dbyte) } })
  self.strgpib = " "
  if logicview.truth(dATN) then
    if logicview.truth(logicview.eq(dbyte, 1)) then
      self.strgpib = "GTL"
    end
    if logicview.truth(logicview.eq(dbyte, 4)) then
      self.strgpib = "SDC"
    end
    if logicview.truth(logicview.eq(dbyte, 5)) then
      self.strgpib = "PPC"
    end
    if logicview.truth(logicview.eq(dbyte, 8)) then
      self.strgpib = "GET"
    end
    if logicview.truth(logicview.eq(dbyte, 9)) then
      self.strgpib = "TCT"
    end
    if logicview.truth(logicview.eq(dbyte, 17)) then
      self.strgpib = "LLO"
    end
    if logicview.truth(logicview.eq(dbyte, 20)) then
      self.strgpib = "DCL"
    end
    if logicview.truth(logicview.eq(dbyte, 21)) then
      self.strgpib = "PPU"
    end
    if logicview.truth(logicview.eq(dbyte, 24)) then
      self.strgpib = "SPE"
    end
    if logicview.truth(logicview.eq(dbyte, 25)) then
      self.strgpib = "SPD"
    end
    if logicview.truth(logicview.eq(dbyte, 63)) then
      self.strgpib = "UNL"
    end
    if logicview.truth(logicview.eq(dbyte, 95)) then
      self.strgpib = "UNT"
    end
    if logicview.truth((function()
  local _v
  _v = (dbyte > 31)
  if not logicview.truth(_v) then return _v end
  _v = (dbyte < 63)
  return _v
end)()) then
      self.strgpib = logicview.add("L", _string.char(logicview.add(dbyte, 16)))
    end
    if logicview.truth((function()
  local _v
  _v = (dbyte > 63)
  if not logicview.truth(_v) then return _v end
  _v = (dbyte < 95)
  return _v
end)()) then
      self.strgpib = logicview.add("T", _string.char((dbyte - 16)))
    end
    if logicview.truth((function()
  local _v
  _v = (dbyte > 95)
  if not logicview.truth(_v) then return _v end
  _v = (dbyte < 112)
  return _v
end)()) then
      self.strgpib = logicview.add("R", _string.char((dbyte - 48)))
    end
    if logicview.truth((function()
  local _v
  _v = (dbyte > 223)
  if not logicview.truth(_v) then return _v end
  _v = (dbyte < 240)
  return _v
end)()) then
      self.strgpib = logicview.add("C", _string.char((dbyte - 176)))
    end
    if logicview.truth((dbyte > 239)) then
      self.strgpib = logicview.add("O", _string.char((dbyte - 192)))
    end
  else
    if logicview.truth((function()
  local _v
  _v = (dbyte > 31)
  if not logicview.truth(_v) then return _v end
  _v = (dbyte < 127)
  return _v
end)()) then
      self.strgpib = _string.char(dbyte)
    end
    if logicview.truth(logicview.eq(dbyte, 10)) then
      self.strgpib = "LF"
    end
    if logicview.truth(logicview.eq(dbyte, 13)) then
      self.strgpib = "CR"
    end
  end
  self:putb({ 1, { self.strgpib } })
  self.strEOI = " "
  if logicview.truth(dEOI) then
    self.strEOI = "EOI"
  end
  self:putb({ 2, { self.strEOI } })
end
function _decoder.decode(self)
  local data, clk, atn, srq
  while true do
    do
      local _lv_seq = self:wait(logicview.idx(step_wait_conds, self.step))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      data = logicview.idx(_lv_seq, 0)
      clk = logicview.idx(_lv_seq, 1)
      atn = logicview.idx(_lv_seq, 2)
      srq = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth((self.matched & (1 << 0))) then
      self.step = 0
    end
    if logicview.truth(logicview.eq(self.step, 0)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        self.step = 1
      end
    elseif logicview.truth(logicview.eq(self.step, 1)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        self.ss_item = self.samplenum
        self.saved_ATN = (not logicview.truth(atn))
        self.saved_EOI = false
        self.bits = 0
        self.numbits = 0
        self.step = 2
      elseif logicview.truth(logicview.eq(clk, 0)) then
        self.step = 0
      end
    elseif logicview.truth(logicview.eq(self.step, 2)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        self.saved_EOI = true
      elseif logicview.truth(logicview.eq(clk, 0)) then
        self.step = 3
      end
    elseif logicview.truth(logicview.eq(self.step, 3)) then
      if logicview.truth((self.matched & (1 << 1))) then
        if logicview.truth(logicview.eq(clk, 1)) then
          self.bits = (self.bits | (data << self.numbits))
        elseif logicview.truth(logicview.eq(clk, 0)) then
          self.numbits = logicview.add(self.numbits, 1)
          if logicview.truth(logicview.eq(self.numbits, 8)) then
            self:handle_bits()
            self.step = 0
          end
        end
      end
    end
    ::continue_1::
  end
end

return _decoder
