-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Rudolf Reuter <reuterru@arcor.de>
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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "gpib",
  name = "GPIB",
  longname = "General Purpose Interface Bus",
  desc = "IEEE-488 General Purpose Interface Bus (GPIB / HPIB).",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PC" },
  channels = { logicview.dict({ id = "dio1", name = "DIO1", desc = "Data I/O bit 1" }), logicview.dict({ id = "dio2", name = "DIO2", desc = "Data I/O bit 2" }), logicview.dict({ id = "dio3", name = "DIO3", desc = "Data I/O bit 3" }), logicview.dict({ id = "dio4", name = "DIO4", desc = "Data I/O bit 4" }), logicview.dict({ id = "dio5", name = "DIO5", desc = "Data I/O bit 5" }), logicview.dict({ id = "dio6", name = "DIO6", desc = "Data I/O bit 6" }), logicview.dict({ id = "dio7", name = "DIO7", desc = "Data I/O bit 7" }), logicview.dict({ id = "dio8", name = "DIO8", desc = "Data I/O bit 8" }), logicview.dict({ id = "eoi", name = "EOI", desc = "End or identify" }), logicview.dict({ id = "dav", name = "DAV", desc = "Data valid" }), logicview.dict({ id = "nrfd", name = "NRFD", desc = "Not ready for data" }), logicview.dict({ id = "ndac", name = "NDAC", desc = "Not data accepted" }), logicview.dict({ id = "ifc", name = "IFC", desc = "Interface clear" }), logicview.dict({ id = "srq", name = "SRQ", desc = "Service request" }), logicview.dict({ id = "atn", name = "ATN", desc = "Attention" }), logicview.dict({ id = "ren", name = "REN", desc = "Remote enable" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "sample_total", desc = "Total number of samples", default = 0, values = {  } }) },
  annotations = { { "items", "Items" }, { "gpib", "DAT/CMD" }, { "eoi", "EOI" } },
  annotation_rows = { { "bytes", "Bytes", { 0 } }, { "gpib", "DAT/CMD", { 1 } }, { "eoi", "EOI", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.items = {  }
  self.itemcount = 0
  self.saved_item = nil
  self.saved_ATN = false
  self.saved_EOI = false
  self.samplenum = 0
  do
    local _lv_chain = nil
    self.ss_item = _lv_chain
    self.es_item = _lv_chain
  end
  self.first = true
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putb(self, data)
  self:put(self.ss_item, self.es_item, self.out_ann, data)
end
function _decoder.handle_bits(self, datapins)
  local dbyte, dATN, item2, dEOI, item3, item, i
  dbyte = 32
  dATN = false
  item2 = false
  dEOI = false
  item3 = false
  if logicview.truth(logicview.eq(self.itemcount, 0)) then
    self.ss_word = self.samplenum
  end
  item = 0
  for _lv_i in logicview.range(8) do
    i = _lv_i
    item = (item | (logicview.idx(datapins, i) << i))
    ::continue_1::
  end
  item = (item ~ 255)
  _table.insert(self.items, item)
  self.itemcount = logicview.add(self.itemcount, 1)
  if logicview.truth(logicview.eq(logicview.idx(datapins, 14), 0)) then
    item2 = true
  end
  if logicview.truth(logicview.eq(logicview.idx(datapins, 8), 0)) then
    item3 = true
  end
  if logicview.truth(self.first) then
    self.ss_item = self.samplenum
    self.first = false
    self.saved_item = item
    self.saved_ATN = item2
    self.saved_EOI = item3
  else
    dbyte = self.saved_item
    dATN = self.saved_ATN
    dEOI = self.saved_EOI
    self.es_item = self.samplenum
    self:putb({ 0, { logicview.pymod("%02X", self.saved_item) } })
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
    self.ss_item = self.samplenum
    self.saved_item = item
    self.saved_ATN = item2
    self.saved_EOI = item3
  end
  if logicview.truth((self.itemcount < 16)) then
    return
  end
  do
    local _lv_a0, _lv_a1 = 0, {  }
    self.itemcount = _lv_a0
    self.items = _lv_a1
  end
end
function _decoder.decode(self)
  local waitcond, lsn, d1, d2, d3, d4, d5, d6, d7, d8, eoi, dav, nrfd, ndac, ifc, srq, atn, ren, pins
  waitcond = { logicview.dict({ [9] = "l" }) }
  lsn = logicview.idx(self.options, "sample_total")
  if logicview.truth(lsn) then
    _table.insert(waitcond, logicview.dict({ skip = lsn }))
  end
  while true do
    if logicview.truth(lsn) then
      logicview.setidx(logicview.idx(waitcond, 1), "skip", ((lsn - self.samplenum) - 1))
    end
    do
      local _lv_seq = self:wait(waitcond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d1 = logicview.idx(_lv_seq, 0)
      d2 = logicview.idx(_lv_seq, 1)
      d3 = logicview.idx(_lv_seq, 2)
      d4 = logicview.idx(_lv_seq, 3)
      d5 = logicview.idx(_lv_seq, 4)
      d6 = logicview.idx(_lv_seq, 5)
      d7 = logicview.idx(_lv_seq, 6)
      d8 = logicview.idx(_lv_seq, 7)
      eoi = logicview.idx(_lv_seq, 8)
      dav = logicview.idx(_lv_seq, 9)
      nrfd = logicview.idx(_lv_seq, 10)
      ndac = logicview.idx(_lv_seq, 11)
      ifc = logicview.idx(_lv_seq, 12)
      srq = logicview.idx(_lv_seq, 13)
      atn = logicview.idx(_lv_seq, 14)
      ren = logicview.idx(_lv_seq, 15)
    end
    pins = { d1, d2, d3, d4, d5, d6, d7, d8, eoi, dav, nrfd, ndac, ifc, srq, atn, ren }
    self:handle_bits(pins)
    logicview.setidx(logicview.idx(waitcond, 0), 9, "f")
    ::continue_2::
  end
end

return _decoder
