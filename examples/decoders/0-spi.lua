-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011 Gareth McMullin <gareth@blacksphere.co.nz>
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>
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
  id = "0:spi",
  name = "0:SPI",
  longname = "Serial Peripheral Interface",
  desc = "Full-duplex, synchronous, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "spi" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }) },
  optional_channels = { logicview.dict({ id = "miso", name = "MISO", desc = "Master in, slave out" }), logicview.dict({ id = "mosi", name = "MOSI", desc = "Master out, slave in" }), logicview.dict({ id = "cs", name = "CS#", desc = "Chip-select" }) },
  options = { logicview.dict({ id = "cs_polarity", desc = "CS# polarity", default = "active-low", values = { "active-low", "active-high" } }), logicview.dict({ id = "cpol", desc = "Clock polarity (CPOL)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "cpha", desc = "Clock phase (CPHA)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "bitorder", desc = "Bit order", default = "msb-first", values = { "msb-first", "lsb-first" } }), logicview.dict({ id = "wordsize", desc = "Word size", default = 8, values = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128 } }) },
  annotations = { { "106", "miso-data", "MISO data" }, { "108", "mosi-data", "MOSI data" } },
  lanes = {
    { id = "mosi", name = "MOSI", channel = "mosi", channels = { "mosi", "clk", "cs" }, classes = { "mosi-data" }, value_field = "value" },
    { id = "miso", name = "MISO", channel = "miso", channels = { "clk", "miso", "cs" }, classes = { "miso-data" }, value_field = "value" }
  },
  annotation_rows = { { "miso-data", "MISO data", { 0 } }, { "mosi-data", "MOSI data", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.bitcount = 0
  do
    local _lv_chain = 0
    self.misodata = _lv_chain
    self.mosidata = _lv_chain
  end
  self.misobits = {  }
  self.mosibits = {  }
  self.ss_block = (-1)
  self.samplenum = (-1)
  self.ss_transfer = (-1)
  self.cs_was_deasserted = false
  do
    local _lv_chain = nil
    self.have_cs = _lv_chain
    self.have_miso = _lv_chain
    self.have_mosi = _lv_chain
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
  local so, si, ss, es
  so = (function() if logicview.truth(self.have_miso) then return self.misodata else return nil end end)()
  si = (function() if logicview.truth(self.have_mosi) then return self.mosidata else return nil end end)()
  if logicview.truth(self.have_miso) then
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.misobits, (-1)), 1), logicview.idx(logicview.idx(self.misobits, 0), 2)
      ss = _lv_a0
      es = _lv_a1
    end
  end
  if logicview.truth(self.have_mosi) then
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.mosibits, (-1)), 1), logicview.idx(logicview.idx(self.mosibits, 0), 2)
      ss = _lv_a0
      es = _lv_a1
    end
  end
  if logicview.truth(self.have_miso) then
    self:put(ss, es, self.out_ann, { 0, { logicview.pyformat("@{1:0>{0}X}", { logicview.tointeger((logicview.add(logicview.idx(self.options, "wordsize"), 3) / 4)), self.misodata }, logicview.dict({})) } })
  end
  if logicview.truth(self.have_mosi) then
    self:put(ss, es, self.out_ann, { 1, { logicview.pyformat("@{1:0>{0}X}", { logicview.tointeger((logicview.add(logicview.idx(self.options, "wordsize"), 3) / 4)), self.mosidata }, logicview.dict({})) } })
  end
end
function _decoder.reset_decoder_state(self)
  self.misodata = (function() if logicview.truth(self.have_miso) then return 0 else return nil end end)()
  self.mosidata = (function() if logicview.truth(self.have_mosi) then return 0 else return nil end end)()
  self.misobits = (function() if logicview.truth(self.have_miso) then return {  } else return nil end end)()
  self.mosibits = (function() if logicview.truth(self.have_mosi) then return {  } else return nil end end)()
  self.bitcount = 0
end
function _decoder.cs_asserted(self, cs)
  local active_low
  active_low = logicview.eq(logicview.idx(self.options, "cs_polarity"), "active-low")
  return (function() if logicview.truth(active_low) then return logicview.eq(cs, 0) else return logicview.eq(cs, 1) end end)()
end
function _decoder.handle_bit(self, miso, mosi, clk, cs)
  local ws, bo, es
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.ss_block = self.samplenum
    self.cs_was_deasserted = (function() if logicview.truth(self.have_cs) then return (not logicview.truth(self:cs_asserted(cs))) else return false end end)()
  end
  ws = logicview.idx(self.options, "wordsize")
  bo = logicview.idx(self.options, "bitorder")
  if logicview.truth(self.have_miso) then
    if logicview.truth(logicview.eq(bo, "msb-first")) then
      self.misodata = (self.misodata | (miso << ((ws - 1) - self.bitcount)))
    else
      self.misodata = (self.misodata | (miso << self.bitcount))
    end
  end
  if logicview.truth(self.have_mosi) then
    if logicview.truth(logicview.eq(bo, "msb-first")) then
      self.mosidata = (self.mosidata | (mosi << ((ws - 1) - self.bitcount)))
    else
      self.mosidata = (self.mosidata | (mosi << self.bitcount))
    end
  end
  es = self.samplenum
  if logicview.truth((self.bitcount > 0)) then
    if logicview.truth(self.have_miso) then
      es = logicview.add(es, (self.samplenum - logicview.idx(logicview.idx(self.misobits, 0), 1)))
    elseif logicview.truth(self.have_mosi) then
      es = logicview.add(es, (self.samplenum - logicview.idx(logicview.idx(self.mosibits, 0), 1)))
    end
  end
  if logicview.truth(self.have_miso) then
    logicview.list_insert(self.misobits, 0, { miso, self.samplenum, es })
  end
  if logicview.truth(self.have_mosi) then
    logicview.list_insert(self.mosibits, 0, { mosi, self.samplenum, es })
  end
  if logicview.truth((function()
  local _v
  _v = (self.bitcount > 0)
  if not logicview.truth(_v) then return _v end
  _v = self.have_miso
  return _v
end)()) then
    logicview.setidx(logicview.idx(self.misobits, 1), 2, self.samplenum)
  end
  if logicview.truth((function()
  local _v
  _v = (self.bitcount > 0)
  if not logicview.truth(_v) then return _v end
  _v = self.have_mosi
  return _v
end)()) then
    logicview.setidx(logicview.idx(self.mosibits, 1), 2, self.samplenum)
  end
  self.bitcount = logicview.add(self.bitcount, 1)
  if logicview.truth((not logicview.eq(self.bitcount, ws))) then
    return
  end
  self:putdata()
  self:reset_decoder_state()
end
function _decoder.find_clk_edge(self, miso, mosi, clk, cs, first)
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
  self:handle_bit(miso, mosi, clk, cs)
end
function _decoder.decode(self)
  local mode, wait_cond, clk, miso, mosi, cs
  if logicview.truth((not logicview.truth(self:has_channel(0)))) then
    _error(ChannelError("CLK pin required."), 0)
  end
  self.have_miso = self:has_channel(1)
  self.have_mosi = self:has_channel(2)
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.have_miso))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.have_mosi))
  return _v
end)()) then
    _error(ChannelError("Either MISO or MOSI (or both) pins required."), 0)
  end
  self.have_cs = self:has_channel(3)
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
    _table.insert(wait_cond, logicview.dict({ [3] = "e" }))
  end
  do
    local _lv_seq = self:wait(logicview.dict({  }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    clk = logicview.idx(_lv_seq, 0)
    miso = logicview.idx(_lv_seq, 1)
    mosi = logicview.idx(_lv_seq, 2)
    cs = logicview.idx(_lv_seq, 3)
  end
  self:find_clk_edge(miso, mosi, clk, cs, true)
  while true do
    do
      local _lv_seq = self:wait(wait_cond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      miso = logicview.idx(_lv_seq, 1)
      mosi = logicview.idx(_lv_seq, 2)
      cs = logicview.idx(_lv_seq, 3)
    end
    self:find_clk_edge(miso, mosi, clk, cs, false)
    ::continue_1::
  end
end

return _decoder
