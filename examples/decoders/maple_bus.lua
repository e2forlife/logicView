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
local ann, Decoder
local _decoder

ann = { { "Size", "L" }, { "SrcAP", "S" }, { "DstAP", "D" }, { "Cmd", "C" }, { "Data" }, { "Cksum", "K" } }
_decoder = {
  api_version = 3,
  id = "maple_bus",
  name = "Maple bus",
  longname = "SEGA Maple bus",
  desc = "Maple bus peripheral protocol for SEGA Dreamcast.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Retro computing" },
  channels = { logicview.dict({ id = "sdcka", name = "SDCKA", desc = "Data/clock line A" }), logicview.dict({ id = "sdckb", name = "SDCKB", desc = "Data/clock line B" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "start", "Start pattern" }, { "end", "End pattern" }, { "start-with-crc", "Start pattern with CRC" }, { "occupancy", "SDCKB occupancy pattern" }, { "reset", "RESET pattern" }, { "bit", "Bit" }, { "size", "Data size" }, { "source", "Source AP" }, { "dest", "Destination AP" }, { "command", "Command" }, { "data", "Data" }, { "checksum", "Checksum" }, { "frame-error", "Frame error" }, { "checksum-error", "Checksum error" }, { "size-error", "Size error" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3, 4, 5 } }, { "fields", "Fields", { 6, 7, 8, 9, 10, 11 } }, { "warnings", "Warnings", { 12, 13, 14 } } },
  binary = { { "size", "Data size" }, { "source", "Source AP" }, { "dest", "Destination AP" }, { "command", "Command code" }, { "data", "Data" }, { "checksum", "Checksum" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.pending_bit_pos = nil
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putb(self, data)
  self:put(self.ss, self.es, self.out_binary, data)
end
function _decoder.byte_annotation(self, bintype, d)
  return { logicview.add(bintype, 6), logicview.add((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.idx(ann, bintype)) do
    name = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%s: %02X", { name, d })
  end
  return _lv_out
end)(), { logicview.pymod("%02X", d) }) }
end
function _decoder.got_start(self)
  self:putx({ 0, { "Start pattern", "Start", "S" } })
end
function _decoder.got_end(self)
  self:putx({ 1, { "End pattern", "End", "E" } })
  if logicview.truth((not logicview.eq(self.length, logicview.add(self.expected_length, 1)))) then
    self:putx({ 14, { "Size error", "L error", "LE" } })
  end
end
function _decoder.got_start_with_crc(self)
  self:putx({ 2, { "Start pattern with CRC", "Start CRC", "SC" } })
end
function _decoder.got_occupancy(self)
  self:putx({ 3, { "SDCKB occupancy pattern", "Occupancy", "O" } })
end
function _decoder.got_reset(self)
  self:putx({ 4, { "RESET pattern", "RESET", "R" } })
end
function _decoder.output_pending_bit(self)
  if logicview.truth(self.pending_bit_pos) then
    self:put(self.pending_bit_pos, self.pending_bit_pos, self.out_ann, { 5, { logicview.pymod("Bit: %d", self.pending_bit), logicview.pymod("%d", self.pending_bit) } })
  end
end
function _decoder.got_bit(self, n)
  self:output_pending_bit()
  self.data = logicview.add(logicview.mul(self.data, 2), n)
  self.pending_bit = n
  self.pending_bit_pos = self.samplenum
end
function _decoder.got_byte(self)
  local bintype
  self:output_pending_bit()
  bintype = 4
  if logicview.truth((self.length < 4)) then
    if logicview.truth(logicview.eq(self.length, 0)) then
      self.expected_length = logicview.mul(4, logicview.add(self.data, 1))
    end
    bintype = self.length
  elseif logicview.truth(logicview.eq(self.length, self.expected_length)) then
    bintype = 5
    if logicview.truth((not logicview.eq(self.data, self.checksum))) then
      self:putx({ 13, { "Cksum error", "K error", "KE" } })
    end
  end
  self.length = logicview.add(self.length, 1)
  self.checksum = (self.checksum ~ self.data)
  self:putx(self:byte_annotation(bintype, self.data))
  self:putb({ bintype, logicview.bytes({ self.data }) })
  self.pending_bit_pos = nil
end
function _decoder.frame_error(self)
  self:putx({ 7, { "Frame error", "F error", "FE" } })
end
function _decoder.handle_start(self)
  local count, sdcka, sdckb
  self:wait(logicview.dict({ [0] = "l", [1] = "h" }))
  self.ss = self.samplenum
  count = 0
  while true do
    do
      local _lv_seq = self:wait({ logicview.dict({ [1] = "f" }), logicview.dict({ [0] = "r" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sdcka = logicview.idx(_lv_seq, 0)
      sdckb = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((self.matched & (1 << 0))) then
      count = logicview.add(count, 1)
    end
    if logicview.truth((self.matched & (1 << 1))) then
      self.es = self.samplenum
      if logicview.truth(logicview.eq(sdckb, 1)) then
        if logicview.truth(logicview.eq(count, 4)) then
          self:got_start()
          return true
        elseif logicview.truth(logicview.eq(count, 6)) then
          self:got_start_with_crc()
          return true
        elseif logicview.truth(logicview.eq(count, 8)) then
          self:got_occupancy()
          return false
        elseif logicview.truth((count >= 14)) then
          self:got_reset()
          return false
        end
      end
      self:frame_error()
      return false
    end
    ::continue_1::
  end
end
function _decoder.handle_byte_or_stop(self)
  local initial, counta, countb, sdcka, sdckb
  self.ss = self.samplenum
  self.pending_bit_pos = nil
  initial = true
  counta = 0
  countb = 0
  self.data = 0
  while logicview.truth((countb < 4)) do
    do
      local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [1] = "f" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sdcka = logicview.idx(_lv_seq, 0)
      sdckb = logicview.idx(_lv_seq, 1)
    end
    self.es = self.samplenum
    if logicview.truth((self.matched & (1 << 0))) then
      if logicview.truth(logicview.eq(counta, countb)) then
        self:got_bit(sdckb)
        counta = logicview.add(counta, 1)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(counta, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(countb, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.data, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(sdckb, 0)
  return _v
end)()) then
        self:wait({ logicview.dict({ [0] = "h", [1] = "h" }), logicview.dict({ [0] = "f" }), logicview.dict({ [1] = "f" }) })
        self.es = self.samplenum
        if logicview.truth((self.matched & (1 << 0))) then
          self:got_end()
        else
          self:frame_error()
        end
        return false
      else
        self:frame_error()
        return false
      end
    elseif logicview.truth((self.matched & (1 << 1))) then
      if logicview.truth(logicview.eq(counta, logicview.add(countb, 1))) then
        self:got_bit(sdcka)
        countb = logicview.add(countb, 1)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(counta, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(countb, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(sdcka, 1)
  if not logicview.truth(_v) then return _v end
  _v = initial
  return _v
end)()) then
        self.ss = self.samplenum
        initial = false
      else
        self:frame_error()
        return false
      end
    end
    ::continue_2::
  end
  self:wait(logicview.dict({ [0] = "h" }))
  self.es = self.samplenum
  self:got_byte()
  return true
end
function _decoder.decode(self)
  while true do
    while logicview.truth((not logicview.truth(self:handle_start()))) do
      ::continue_4::
    end
    self.length = 0
    self.expected_length = 4
    self.checksum = 0
    while logicview.truth(self:handle_byte_or_stop()) do
      ::continue_5::
    end
    ::continue_3::
  end
end

return _decoder
