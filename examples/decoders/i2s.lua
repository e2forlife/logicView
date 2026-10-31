-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Joel Holdsworth <joel@airwebreathe.org.uk>
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
local struct, Decoder
local _decoder

struct = logicview.struct
_decoder = {
  api_version = 3,
  id = "i2s",
  name = "I²S",
  longname = "Integrated Interchip Sound",
  desc = "Serial bus for connecting digital audio devices.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "i2s" },
  tags = { "Audio", "PC" },
  channels = { logicview.dict({ id = "sck", name = "SCK", desc = "Bit clock line" }), logicview.dict({ id = "ws", name = "WS", desc = "Word select line" }), logicview.dict({ id = "sd", name = "SD", desc = "Serial data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "ws_polarity", desc = "WS polarity", default = "left-high", values = { "left-low", "left-high" } }), logicview.dict({ id = "clk_edge", desc = "SCK active edge", default = "rising-edge", values = { "rising-edge", "falling-edge" } }), logicview.dict({ id = "bit_shift", desc = "Bit shift", default = "none", values = { "right-shifted by one", "none" } }), logicview.dict({ id = "bit_align", desc = "Bit align", default = "left-aligned", values = { "left-aligned", "right-aligned" } }), logicview.dict({ id = "bitorder", desc = "Bit order", default = "msb-first", values = { "msb-first", "lsb-first" } }), logicview.dict({ id = "wordsize", desc = "Word size", default = 16, values = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128 } }) },
  annotations = { { "left", "Left channel" }, { "right", "Right channel" }, { "warnings", "Warnings" } },
  annotation_rows = {  },
  binary = { { "wav", "WAV file" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.oldws = 1
  self.bitcount = 0
  self.data = 0
  self.samplesreceived = 0
  self.first_sample = nil
  self.ss_block = nil
  self.wordlength = (-1)
  self.wrote_wav_header = false
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.putpb(self, data)
  self:put(self.ss_block, self.samplenum, self.out_python, data)
end
function _decoder.putbin(self, data)
  self:put(self.ss_block, self.samplenum, self.out_binary, data)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.samplenum, self.out_ann, data)
end
function _decoder.report(self)
  local samplerate
  samplerate = "?"
  if logicview.truth((function()
  local _v
  _v = (self.ss_block ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.first_sample ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.ss_block > self.first_sample)
  if not logicview.truth(_v) then return _v end
  _v = self.samplerate
  return _v
end)()) then
    samplerate = logicview.pymod("%d", (logicview.mul(self.samplesreceived, self.samplerate) / (self.ss_block - self.first_sample)))
  end
  return logicview.pymod("I²S: %d %d-bit samples received at %sHz", { self.samplesreceived, self.wordlength, samplerate })
end
function _decoder.wav_header(self)
  local h
  h = "\x52\x49\x46\x46"
  h = logicview.add(h, "\x24\x80\x00\x00")
  h = logicview.add(h, "\x57\x41\x56\x45")
  h = logicview.add(h, "\x66\x6d\x74\x20")
  h = logicview.add(h, "\x10\x00\x00\x00")
  h = logicview.add(h, "\x01\x00")
  h = logicview.add(h, "\x02\x00")
  h = logicview.add(h, "\x80\x3e\x00\x00")
  h = logicview.add(h, "\x00\xfa\x00\x00")
  h = logicview.add(h, "\x04\x00")
  h = logicview.add(h, "\x20\x00")
  h = logicview.add(h, "\x64\x61\x74\x61")
  h = logicview.add(h, "\xff\xff\xff\xff")
  return h
end
function _decoder.wav_sample(self, sample)
  return struct.pack("<I", self.data)
end
function _decoder.decode(self)
  local left_high, active_rising, right_shifted, left_algined, msb, sck, ws, sd, idx, c1, c2, c3, v
  left_high = logicview.eq(logicview.idx(self.options, "ws_polarity"), "left-high")
  active_rising = logicview.eq(logicview.idx(self.options, "clk_edge"), "rising-edge")
  right_shifted = logicview.eq(logicview.idx(self.options, "bit_shift"), "right-shifted by one")
  left_algined = logicview.eq(logicview.idx(self.options, "bit_align"), "left-aligned")
  msb = logicview.eq(logicview.idx(self.options, "bitorder"), "msb-first")
  self.wordlength = logicview.idx(self.options, "wordsize")
  do
    local _lv_seq = self:wait(logicview.dict({ [1] = "e" }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    sck = logicview.idx(_lv_seq, 0)
    ws = logicview.idx(_lv_seq, 1)
    sd = logicview.idx(_lv_seq, 2)
  end
  self.ss_block = self.samplenum
  self.oldws = ws
  if logicview.truth(right_shifted) then
    self:wait(logicview.dict({ [0] = (function() if logicview.truth(active_rising) then return "r" else return "f" end end)() }))
  end
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(active_rising) then return "r" else return "f" end end)() }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sck = logicview.idx(_lv_seq, 0)
      ws = logicview.idx(_lv_seq, 1)
      sd = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(right_shifted))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(ws, self.oldws))
  return _v
end)()) then
      self.last = sd
    else
      if logicview.truth(msb) then
        self.data = ((self.data << 1) | sd)
      else
        self.data = (self.data | (sd << self.bitcount))
      end
      self.bitcount = logicview.add(self.bitcount, 1)
    end
    if logicview.truth(logicview.eq(ws, self.oldws)) then
      goto continue_1
    end
    if logicview.truth((not logicview.truth(self.wrote_wav_header))) then
      self:put(0, 0, self.out_binary, { 0, self:wav_header() })
      self.wrote_wav_header = true
    end
    self.samplesreceived = logicview.add(self.samplesreceived, 1)
    if logicview.truth(right_shifted) then
      self:wait(logicview.dict({ [0] = (function() if logicview.truth(active_rising) then return "f" else return "r" end end)() }))
    end
    if logicview.truth((self.wordlength > self.bitcount)) then
      self:putb({ 2, { logicview.pymod("Received %d-bit word, expected %d-bit word", { self.bitcount, self.wordlength }) } })
    else
      if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = left_algined
  if not logicview.truth(_v) then return _v end
  _v = msb
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.truth(left_algined))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(msb))
  return _v
end)()
  return _v
end)()) then
        self.data = (self.data >> (self.bitcount - self.wordlength))
      else
        self.data = (self.data & logicview.tointeger(logicview.mul("1", self.wordlength), 2))
      end
      self.oldws = (function() if logicview.truth(left_high) then return self.oldws else return (not logicview.truth(self.oldws)) end end)()
      idx = (function() if logicview.truth(self.oldws) then return 0 else return 1 end end)()
      c1 = (function() if logicview.truth(self.oldws) then return "Left channel" else return "Right channel" end end)()
      c2 = (function() if logicview.truth(self.oldws) then return "Left" else return "Right" end end)()
      c3 = (function() if logicview.truth(self.oldws) then return "L" else return "R" end end)()
      v = logicview.pymod("%08x", self.data)
      self:putpb({ "DATA", { c3, self.data } })
      self:putb({ idx, { logicview.pymod("%s: %s", { c1, v }), logicview.pymod("%s: %s", { c2, v }), logicview.pymod("%s: %s", { c3, v }), c3 } })
      self:putbin({ 0, self:wav_sample(self.data) })
    end
    self.data = (function() if logicview.truth(right_shifted) then return 0 else return self.last end end)()
    self.bitcount = (function() if logicview.truth(right_shifted) then return 0 else return 1 end end)()
    self.ss_block = self.samplenum
    if logicview.truth((self.first_sample == nil)) then
      self.first_sample = self.samplenum
    end
    self.oldws = ws
    ::continue_1::
  end
end

return _decoder
