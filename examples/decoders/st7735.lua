-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Aleksander Alekseev <afiskon@gmail.com>

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
local MAX_DATA_LEN, META, Ann, Decoder
local _decoder

MAX_DATA_LEN = 128
META = logicview.dict({ [0] = logicview.dict({ name = "NOP    ", desc = "No operation" }), [1] = logicview.dict({ name = "SWRESET", desc = "Software reset" }), [4] = logicview.dict({ name = "RDDID  ", desc = "Read display ID" }), [9] = logicview.dict({ name = "RDDST  ", desc = "Read display status" }), [16] = logicview.dict({ name = "SLPIN  ", desc = "Sleep in & booster off" }), [17] = logicview.dict({ name = "SLPOUT ", desc = "Sleep out & booster on" }), [18] = logicview.dict({ name = "PTLON  ", desc = "Partial mode on" }), [19] = logicview.dict({ name = "NORON  ", desc = "Partial off (normal)" }), [32] = logicview.dict({ name = "INVOFF ", desc = "Display inversion off" }), [33] = logicview.dict({ name = "INVON  ", desc = "Display inversion on" }), [40] = logicview.dict({ name = "DISPOFF", desc = "Display off" }), [41] = logicview.dict({ name = "DISPON ", desc = "Display on" }), [42] = logicview.dict({ name = "CASET  ", desc = "Column address set" }), [43] = logicview.dict({ name = "RASET  ", desc = "Row address set" }), [44] = logicview.dict({ name = "RAMWR  ", desc = "Memory write" }), [46] = logicview.dict({ name = "RAMRD  ", desc = "Memory read" }), [48] = logicview.dict({ name = "PTLAR  ", desc = "Partial start/end address set" }), [54] = logicview.dict({ name = "MADCTL ", desc = "Memory data address control" }), [58] = logicview.dict({ name = "COLMOD ", desc = "Interface pixel format" }), [177] = logicview.dict({ name = "FRMCTR1", desc = "Frame rate control (in normal mode / full colors)" }), [178] = logicview.dict({ name = "FRMCTR2", desc = "Frame rate control (in idle mode / 8-colors)" }), [179] = logicview.dict({ name = "FRMCTR3", desc = "Frame rate control (in partial mode / full colors) " }), [180] = logicview.dict({ name = "INVCTR ", desc = "Display inversion control" }), [182] = logicview.dict({ name = "DISSET5", desc = "Display function set 5" }), [192] = logicview.dict({ name = "PWCTR1 ", desc = "Power control 1" }), [193] = logicview.dict({ name = "PWCTR2 ", desc = "Power control 2" }), [194] = logicview.dict({ name = "PWCTR3 ", desc = "Power control 3" }), [195] = logicview.dict({ name = "PWCTR4 ", desc = "Power control 4" }), [196] = logicview.dict({ name = "PWCTR5 ", desc = "Power control 5" }), [197] = logicview.dict({ name = "VMCTR1 ", desc = "VCOM control 1" }), [218] = logicview.dict({ name = "RDID1  ", desc = "Read ID1" }), [219] = logicview.dict({ name = "RDID2  ", desc = "Read ID2" }), [220] = logicview.dict({ name = "RDID3  ", desc = "Read ID3" }), [221] = logicview.dict({ name = "RDID4  ", desc = "Read ID4" }), [252] = logicview.dict({ name = "PWCTR6 ", desc = "Power control 6" }), [224] = logicview.dict({ name = "GMCTRP1", desc = "Gamma '+'polarity correction characteristics setting" }), [225] = logicview.dict({ name = "GMCTRN1", desc = "Gamma '-'polarity correction characteristics setting" }) })
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BITS = logicview.idx(_lv_seq, 0)
  Ann.CMD = logicview.idx(_lv_seq, 1)
  Ann.DATA = logicview.idx(_lv_seq, 2)
  Ann.DESC = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "st7735",
  name = "ST7735",
  longname = "Sitronix ST7735",
  desc = "Sitronix ST7735 TFT controller protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Display", "IC" },
  channels = { logicview.dict({ id = "cs", name = "CS#", desc = "Chip-select" }), logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "mosi", name = "MOSI", desc = "Master out, slave in" }), logicview.dict({ id = "dc", name = "DC", desc = "Data or command" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bit", "Bit" }, { "command", "Command" }, { "data", "Data" }, { "description", "Description" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2 } }, { "description", "Description", { 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.accum_byte = 0
  self.accum_bits_num = 0
  self.bit_ss = (-1)
  self.byte_ss = (-1)
  self.current_bit = (-1)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.put_desc(self, ss, es, cmd, data)
  local dots, data_str
  if logicview.truth(logicview.eq(cmd, (-1))) then
    return
  end
  if logicview.truth(logicview.idx(META, cmd)) then
    self:put(ss, es, self.out_ann, { Ann.DESC, { logicview.pymod("%s: %s", { logicview.strip(logicview.idx(logicview.idx(META, cmd), "name")), logicview.idx(logicview.idx(META, cmd), "desc") }) } })
  else
    dots = ""
    if logicview.truth(logicview.eq(logicview.len(data), MAX_DATA_LEN)) then
      data = logicview.slice(data, nil, (-1), nil)
      dots = "..."
    end
    data_str = "(none)"
    if logicview.truth((logicview.len(data) > 0)) then
      data_str = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02X", b)
  end
  return _lv_out
end)())
    end
    self:put(ss, es, self.out_ann, { Ann.DESC, { logicview.pymod("Unknown command: %02X. Data: %s%s", { cmd, data_str, dots }) } })
  end
end
function _decoder.decode(self)
  local current_cmd, current_data, desc_ss, desc_es, cs, clk, mosi, dc, ann
  current_cmd = (-1)
  current_data = {  }
  desc_ss = (-1)
  desc_es = (-1)
  self:reset()
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [1] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cs = logicview.idx(_lv_seq, 0)
      clk = logicview.idx(_lv_seq, 1)
      mosi = logicview.idx(_lv_seq, 2)
      dc = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth(logicview.eq(cs, 1)) then
      self:reset()
      goto continue_1
    end
    if logicview.truth(logicview.eq(clk, 1)) then
      self.bit_ss = self.samplenum
      if logicview.truth(logicview.eq(self.accum_bits_num, 0)) then
        self.byte_ss = self.samplenum
      end
      self.current_bit = mosi
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(clk, 0)
  if not logicview.truth(_v) then return _v end
  _v = (self.current_bit >= 0)
  return _v
end)()) then
      self:put(self.bit_ss, self.samplenum, self.out_ann, { Ann.BITS, { _tostring(self.current_bit) } })
      self.accum_byte = ((self.accum_byte << 1) | self.current_bit)
      self.accum_bits_num = logicview.add(self.accum_bits_num, 1)
      if logicview.truth(logicview.eq(self.accum_bits_num, 8)) then
        ann = (function() if logicview.truth(dc) then return Ann.DATA else return Ann.CMD end end)()
        self:put(self.byte_ss, self.samplenum, self.out_ann, { ann, { logicview.pymod("%02X", self.accum_byte) } })
        if logicview.truth(logicview.eq(ann, Ann.CMD)) then
          self:put_desc(desc_ss, desc_es, current_cmd, current_data)
          desc_ss = self.byte_ss
          desc_es = self.samplenum
          current_cmd = self.accum_byte
          current_data = {  }
        else
          if logicview.truth((logicview.len(current_data) < MAX_DATA_LEN)) then
            current_data = logicview.add(current_data, { self.accum_byte })
          end
          desc_es = self.samplenum
        end
        self.accum_bits_num = 0
        self.accum_byte = 0
        self.byte_ss = (-1)
      end
      self.current_bit = (-1)
      self.bit_ss = (-1)
    end
    ::continue_1::
  end
end

return _decoder
