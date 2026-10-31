-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Mike Jagdis <mjagdis@eris-associates.co.uk>

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
local SamplerateError, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "swim",
  name = "SWIM",
  longname = "STM8 SWIM bus",
  desc = "STM8 Single Wire Interface Module (SWIM) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "swim", name = "SWIM", desc = "SWIM data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "debug", desc = "Debug", default = "no", values = { "yes", "no" } }) },
  annotations = { { "bit", "Bit" }, { "enterseq", "SWIM enter sequence" }, { "start-host", "Start bit (host)" }, { "start-target", "Start bit (target)" }, { "parity", "Parity bit" }, { "ack", "Acknowledgement" }, { "nack", "Negative acknowledgement" }, { "byte-write", "Byte write" }, { "byte-read", "Byte read" }, { "cmd-unknown", "Unknown SWIM command" }, { "cmd", "SWIM command" }, { "bytes", "Byte count" }, { "address", "Address" }, { "data-write", "Data write" }, { "data-read", "Data read" }, { "debug", "Debug" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "framing", "Framing", { 2, 3, 4, 5, 6, 7, 8 } }, { "protocol", "Protocol", { 1, 9, 10, 11, 12, 13, 14 } }, { "debug", "Debug", { 15 } } },
  binary = { { "tx", "Dump of data written to target" }, { "rx", "Dump of data read from target" } }
}
function _decoder.__init__(self)
  self.HSI = 8000000
  self.HSI_min = logicview.mul(self.HSI, 0.9)
  self.HSI_max = logicview.mul(self.HSI, 1.1)
  self.swim_clock = (self.HSI_min / 2)
  self.eseq_edge = { { (-1), nil }, { (-1), nil } }
  self.eseq_pairnum = 0
  self.eseq_pairstart = nil
  self:reset()
end
function _decoder.reset(self)
  self.bit_edge = { { (-1), nil }, { (-1), nil } }
  self.bit_maxlen = (-1)
  self.bitseq_len = 0
  self.bitseq_end = nil
  self.proto_state = "CMD"
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.adjust_timings(self)
  self.bit_reflen = math.ceil((logicview.mul(self.samplerate, 22) / self.swim_clock))
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self.sync_reflen_min = math.floor((logicview.mul(self.samplerate, 64) / self.HSI_max))
  self.sync_reflen_max = math.ceil((logicview.mul(self.samplerate, 128) / (self.HSI_min / 2)))
  self.debug = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "debug"), "yes")) then return true else return false end end)()
  self.eseq_reflen = math.ceil((self.samplerate / 2048))
  self:adjust_timings()
end
function _decoder.protocol(self)
  if logicview.truth(logicview.eq(self.proto_state, "CMD")) then
    if logicview.truth(logicview.eq(self.bitseq_value, 0)) then
      self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 10, { "system reset", "SRST", "!" } })
    elseif logicview.truth(logicview.eq(self.bitseq_value, 1)) then
      self.proto_state = "N"
      self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 10, { "read on-the-fly", "ROTF", "r" } })
    elseif logicview.truth(logicview.eq(self.bitseq_value, 2)) then
      self.proto_state = "N"
      self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 10, { "write on-the-fly", "WOTF", "w" } })
    else
      self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 9, { "unknown", "UNK" } })
    end
  elseif logicview.truth(logicview.eq(self.proto_state, "N")) then
    self.proto_byte_count = self.bitseq_value
    self.proto_state = "@E"
    self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 11, { logicview.pymod("byte count 0x%02x", self.bitseq_value), logicview.pymod("bytes 0x%02x", self.bitseq_value), logicview.pymod("0x%02x", self.bitseq_value), logicview.pymod("%02x", self.bitseq_value), logicview.pymod("%x", self.bitseq_value) } })
  elseif logicview.truth(logicview.eq(self.proto_state, "@E")) then
    self.proto_addr = self.bitseq_value
    self.proto_addr_start = self.bitseq_start
    self.proto_state = "@H"
  elseif logicview.truth(logicview.eq(self.proto_state, "@H")) then
    self.proto_addr = ((self.proto_addr << 8) | self.bitseq_value)
    self.proto_state = "@L"
  elseif logicview.truth(logicview.eq(self.proto_state, "@L")) then
    self.proto_addr = ((self.proto_addr << 8) | self.bitseq_value)
    self.proto_state = "D"
    self:put(self.proto_addr_start, self.bitseq_end, self.out_ann, { 12, { logicview.pymod("address 0x%06x", self.proto_addr), logicview.pymod("addr 0x%06x", self.proto_addr), logicview.pymod("0x%06x", self.proto_addr), logicview.pymod("%06x", self.proto_addr), logicview.pymod("%x", self.proto_addr) } })
  else
    if logicview.truth((self.proto_byte_count > 0)) then
      self.proto_byte_count = (self.proto_byte_count - 1)
      if logicview.truth(logicview.eq(self.proto_byte_count, 0)) then
        self.proto_state = "CMD"
      end
    end
    self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { logicview.add(13, self.bitseq_dir), { logicview.pymod("0x%02x", self.bitseq_value), logicview.pymod("%02x", self.bitseq_value), logicview.pymod("%x", self.bitseq_value) } })
    self:put(self.bitseq_start, self.bitseq_end, self.out_binary, { logicview.add(0, self.bitseq_dir), logicview.bytes({ self.bitseq_value }) })
    if logicview.truth(self.debug) then
      self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { 15, { logicview.pymod("%d more", self.proto_byte_count), logicview.pymod("%d", self.proto_byte_count) } })
    end
  end
end
function _decoder.bitseq(self, bitstart, bitend, bit)
  if logicview.truth(logicview.eq(self.bitseq_len, 0)) then
    self.bit_reflen = (bitend - bitstart)
    self.bitseq_value = 0
    self.bitseq_dir = bit
    self.bitseq_len = 1
    self:put(bitstart, bitend, self.out_ann, { logicview.add(2, self.bitseq_dir), { "start", "s" } })
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(self.proto_state, "CMD")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bitseq_len, 4)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.eq(self.proto_state, "CMD"))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bitseq_len, 9)
  return _v
end)()
  return _v
end)()) then
    self.bitseq_end = bitstart
    self.bitseq_len = logicview.add(self.bitseq_len, 1)
    self:put(bitstart, bitend, self.out_ann, { 4, { "parity", "par", "p" } })
    self.bitseq_value = (self.bitseq_value & 255)
    self:put(self.bitseq_start, self.bitseq_end, self.out_ann, { logicview.add(7, self.bitseq_dir), { logicview.pymod("0x%02x", self.bitseq_value), logicview.pymod("%02x", self.bitseq_value), logicview.pymod("%x", self.bitseq_value) } })
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(self.proto_state, "CMD")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bitseq_len, 5)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.eq(self.proto_state, "CMD"))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bitseq_len, 10)
  return _v
end)()
  return _v
end)()) then
    if logicview.truth(bit) then
      self:put(bitstart, bitend, self.out_ann, { 5, { "ack", "a" } })
    else
      self:put(bitstart, bitend, self.out_ann, { 6, { "nack", "n" } })
    end
    if logicview.truth(bit) then
      self:protocol()
    end
    self.bitseq_len = 0
  else
    if logicview.truth(logicview.eq(self.bitseq_len, 1)) then
      self.bitseq_start = bitstart
    end
    self.bitseq_value = ((self.bitseq_value << 1) | bit)
    self.bitseq_len = logicview.add(self.bitseq_len, 1)
  end
end
function _decoder.bit(self, start, mid, end_)
  local bit
  if logicview.truth(((mid - start) >= (end_ - mid))) then
    self:put(start, end_, self.out_ann, { 0, { "0" } })
    bit = 0
  else
    self:put(start, end_, self.out_ann, { 0, { "1" } })
    bit = 1
  end
  self:bitseq(start, end_, bit)
end
function _decoder.detect_synchronize_frame(self, start, end_)
  if logicview.truth((function()
  local _v
  _v = ((self.samplenum - logicview.idx(logicview.idx(self.eseq_edge, 1), 1)) >= self.sync_reflen_min)
  if not logicview.truth(_v) then return _v end
  _v = ((self.samplenum - logicview.idx(logicview.idx(self.eseq_edge, 1), 1)) <= self.sync_reflen_max)
  return _v
end)()) then
    self:put(logicview.idx(logicview.idx(self.eseq_edge, 1), 1), self.samplenum, self.out_ann, { 1, { "synchronization frame", "synchronization", "sync", "s" } })
    self:reset()
    self.swim_clock = logicview.mul(128, (self.samplerate / (self.samplenum - logicview.idx(logicview.idx(self.eseq_edge, 1), 1))))
    self:adjust_timings()
  end
end
function _decoder.eseq_potential_start(self, start, end_)
  self.eseq_pairstart = start
  self.eseq_reflen = (end_ - start)
  self.eseq_pairnum = 1
end
function _decoder.detect_enter_sequence(self, start, end_)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.eseq_pairnum, 0)
  if logicview.truth(_v) then return _v end
  _v = (_math.abs((self.eseq_reflen - (end_ - start))) > 2)
  return _v
end)()) then
    self:eseq_potential_start(start, end_)
  elseif logicview.truth((self.eseq_pairnum < 4)) then
    self.eseq_pairnum = logicview.add(self.eseq_pairnum, 1)
    if logicview.truth(logicview.eq(self.eseq_pairnum, 4)) then
      self.eseq_reflen = (self.eseq_reflen / 2)
    end
  else
    self.eseq_pairnum = logicview.add(self.eseq_pairnum, 1)
    if logicview.truth(logicview.eq(self.eseq_pairnum, 8)) then
      self:put(self.eseq_pairstart, end_, self.out_ann, { 1, { "enter sequence", "enter seq", "enter", "ent", "e" } })
      self.eseq_pairnum = 0
    end
  end
end
function _decoder.decode(self)
  local swim
  while true do
    if logicview.truth((self.bit_maxlen >= 0)) then
      do
        local _lv_seq = self:wait()
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        swim = logicview.idx(_lv_seq, 0)
      end
      self.bit_maxlen = (self.bit_maxlen - 1)
    else
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        swim = logicview.idx(_lv_seq, 0)
      end
    end
    if logicview.truth((not logicview.eq(swim, logicview.idx(logicview.idx(self.eseq_edge, 1), 0)))) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(swim, 1)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(logicview.idx(self.eseq_edge, 1), 1) ~= nil)
  return _v
end)()) then
        self:detect_synchronize_frame(logicview.idx(logicview.idx(self.eseq_edge, 1), 1), self.samplenum)
        if logicview.truth((logicview.idx(logicview.idx(self.eseq_edge, 0), 1) ~= nil)) then
          self:detect_enter_sequence(logicview.idx(logicview.idx(self.eseq_edge, 0), 1), self.samplenum)
        end
      end
      logicview.list_pop(self.eseq_edge, 0)
      _table.insert(self.eseq_edge, { swim, self.samplenum })
    end
    if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (not logicview.eq(swim, logicview.idx(logicview.idx(self.bit_edge, 1), 0)))
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.eq(swim, 1))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(logicview.idx(self.bit_edge, 1), 0), (-1)))
  return _v
end)()
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bit_maxlen, 0)
  return _v
end)()) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.bit_maxlen, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(self.bit_edge, 1), 0), 1)
  return _v
end)()) then
        swim = (-1)
      end
      if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(logicview.idx(self.bit_edge, 1), 0), 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(swim, 0)
  return _v
end)()) then
        self.bit_maxlen = self.bit_reflen
      end
      if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(self.bit_edge, 0), 0), 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(self.bit_edge, 1), 0), 1)
  if not logicview.truth(_v) then return _v end
  _v = ((self.samplenum - logicview.idx(logicview.idx(self.bit_edge, 0), 1)) <= logicview.add(self.bit_reflen, 10))
  return _v
end)()) then
        self:bit(logicview.idx(logicview.idx(self.bit_edge, 0), 1), logicview.idx(logicview.idx(self.bit_edge, 1), 1), self.samplenum)
      end
      logicview.list_pop(self.bit_edge, 0)
      _table.insert(self.bit_edge, { swim, self.samplenum })
    end
    ::continue_1::
  end
end

return _decoder
