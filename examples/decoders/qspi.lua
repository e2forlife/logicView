-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 DreamSourceLab <support@dreamsourcelab.com>

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
local namedtuple, Data, spi_mode, ChannelError, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
Data = (function() local _f = { "ss", "es", "val" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
spi_mode = logicview.dict({ [logicview.tkey(0, 0)] = 0, [logicview.tkey(0, 1)] = 1, [logicview.tkey(1, 0)] = 2, [logicview.tkey(1, 1)] = 3 })
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "qspi",
  name = "QSPI",
  longname = "Quad Serial Peripheral Interface",
  desc = "Full-duplex, synchronous, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "spi" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "io0", name = "IO0", desc = "Data i/o 0" }) },
  optional_channels = { logicview.dict({ id = "io1", name = "IO1", desc = "Data i/o 1" }), logicview.dict({ id = "io2", name = "IO2", desc = "Data i/o 2" }), logicview.dict({ id = "io3", name = "IO3", desc = "Data i/o 3" }), logicview.dict({ id = "cs", name = "CS#", desc = "Chip-select" }) },
  options = { logicview.dict({ id = "cs_polarity", desc = "CS# polarity", default = "active-low", values = { "active-low", "active-high" } }), logicview.dict({ id = "cpol", desc = "Clock polarity (CPOL)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "cpha", desc = "Clock phase (CPHA)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "bitorder", desc = "Bit order", default = "msb-first", values = { "msb-first", "lsb-first" } }), logicview.dict({ id = "wordsize", desc = "Word size", default = 8, values = {  } }) },
  annotations = { { "106", "data", "data" } },
  annotation_rows = { { "data", "data", { 0 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.bitcount = 0
  self.data = 0
  self.bits = {  }
  self.ss_block = (-1)
  self.samplenum = (-1)
  self.ss_transfer = (-1)
  self.cs_was_deasserted = false
  do
    local _lv_chain = nil
    self.have_cs = _lv_chain
    self.have_io1 = _lv_chain
    self.have_io3 = _lv_chain
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.bw = logicview.floordiv(logicview.add(logicview.idx(self.options, "wordsize"), 7), 8)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.putw(self, data)
  self:put(self.ss_block, self.samplenum, self.out_ann, data)
end
function _decoder.putdata(self)
  local ss, es
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, (-1)), 1), logicview.idx(logicview.idx(self.bits, 0), 2)
    ss = _lv_a0
    es = _lv_a1
  end
  self:put(ss, es, self.out_ann, { 0, { logicview.pymod("%02X", self.data) } })
end
function _decoder.reset_decoder_state(self)
  self.data = 0
  self.bits = {  }
  self.bitcount = 0
end
function _decoder.cs_asserted(self, cs)
  local active_low
  active_low = logicview.eq(logicview.idx(self.options, "cs_polarity"), "active-low")
  return (function() if logicview.truth(active_low) then return logicview.eq(cs, 0) else return logicview.eq(cs, 1) end end)()
end
function _decoder.handle_bit(self, datapins, clk, cs)
  local bo, ws, nibws, i, es
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.ss_block = self.samplenum
    self.cs_was_deasserted = (function() if logicview.truth(self.have_cs) then return (not logicview.truth(self:cs_asserted(cs))) else return false end end)()
  end
  bo = logicview.idx(self.options, "bitorder")
  ws = logicview.idx(self.options, "wordsize")
  if logicview.truth(self.have_io3) then
    nibws = (ws >> 2)
  elseif logicview.truth(self.have_io1) then
    nibws = (ws >> 1)
  else
    nibws = ws
  end
  if logicview.truth(self.have_io3) then
    for _lv_i in logicview.range(4) do
      i = _lv_i
      if logicview.truth(logicview.eq(bo, "msb-first")) then
        self.data = (self.data | (logicview.idx(datapins, i) << (((ws - 1) - logicview.mul(self.bitcount, 4)) - i)))
      else
        self.data = (self.data | (logicview.idx(datapins, (3 - i)) << logicview.add(logicview.mul(self.bitcount, 4), i)))
      end
      ::continue_1::
    end
  elseif logicview.truth(self.have_io1) then
    for _lv_i in logicview.range(2) do
      i = _lv_i
      if logicview.truth(logicview.eq(bo, "msb-first")) then
        self.data = (self.data | (logicview.idx(datapins, logicview.add(i, 2)) << (((ws - 1) - logicview.mul(self.bitcount, 2)) - i)))
      else
        self.data = (self.data | (logicview.idx(datapins, (3 - i)) << logicview.add(logicview.mul(self.bitcount, 2), i)))
      end
      ::continue_2::
    end
  elseif logicview.truth(logicview.eq(bo, "msb-first")) then
    self.data = (self.data | (logicview.idx(datapins, 3) << ((ws - 1) - self.bitcount)))
  else
    self.data = (self.data | (logicview.idx(datapins, 3) << self.bitcount))
  end
  es = self.samplenum
  if logicview.truth((self.bitcount > 0)) then
    es = logicview.add(es, (self.samplenum - logicview.idx(logicview.idx(self.bits, 0), 1)))
  end
  logicview.list_insert(self.bits, 0, { logicview.idx(datapins, 3), self.samplenum, es })
  if logicview.truth((self.bitcount > 0)) then
    logicview.setidx(logicview.idx(self.bits, 1), 2, self.samplenum)
  end
  self.bitcount = logicview.add(self.bitcount, 1)
  if logicview.truth((not logicview.eq(self.bitcount, nibws))) then
    return
  end
  self:putdata()
  self:reset_decoder_state()
end
function _decoder.find_clk_edge(self, datapins, clk, cs, first)
  local oldcs
  if logicview.truth((function()
  local _v
  _v = self.have_cs
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = first
  if logicview.truth(_v) then return _v end
  _v = (self.matched & (1 << self.have_cs))
  return _v
end)()
  return _v
end)()) then
    oldcs = (function() if logicview.truth(first) then return nil else return (1 - cs) end end)()
    self:reset_decoder_state()
  end
  if logicview.truth((function()
  local _v
  _v = self.have_cs
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self:cs_asserted(cs)))
  return _v
end)()) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = first
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 0))))
  return _v
end)()) then
    return
  end
  self:handle_bit(datapins, clk, cs)
end
function _decoder.decode(self)
  local mode, wait_cond, clk, d0, d1, d2, d3, cs, d
  if logicview.truth((not logicview.truth(self:has_channel(0)))) then
    _error(ChannelError("CLK pin required."), 0)
  end
  self.have_io1 = self:has_channel(2)
  self.have_io3 = (self:has_channel(3) & self:has_channel(4))
  self.have_cs = self:has_channel(5)
  mode = logicview.idx(spi_mode, logicview.tkey(logicview.idx(self.options, "cpol"), logicview.idx(self.options, "cpha")))
  if logicview.truth((function()
  local _v
  _v = logicview.eq(mode, 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(mode, 3)
  return _v
end)()) then
    wait_cond = { logicview.dict({ [0] = "r" }) }
  else
    wait_cond = { logicview.dict({ [0] = "f" }) }
  end
  if logicview.truth(self.have_cs) then
    self.have_cs = logicview.len(wait_cond)
    _table.insert(wait_cond, logicview.dict({ [5] = "e" }))
  end
  do
    local _lv_seq = self:wait(logicview.dict({  }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    clk = logicview.idx(_lv_seq, 0)
    d0 = logicview.idx(_lv_seq, 1)
    d1 = logicview.idx(_lv_seq, 2)
    d2 = logicview.idx(_lv_seq, 3)
    d3 = logicview.idx(_lv_seq, 4)
    cs = logicview.idx(_lv_seq, 5)
  end
  d = { d3, d2, d1, d0 }
  self:find_clk_edge(d, clk, cs, true)
  while true do
    do
      local _lv_seq = self:wait(wait_cond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      d0 = logicview.idx(_lv_seq, 1)
      d1 = logicview.idx(_lv_seq, 2)
      d2 = logicview.idx(_lv_seq, 3)
      d3 = logicview.idx(_lv_seq, 4)
      cs = logicview.idx(_lv_seq, 5)
    end
    d = { d3, d2, d1, d0 }
    self:find_clk_edge(d, clk, cs, false)
    ::continue_3::
  end
end

return _decoder
