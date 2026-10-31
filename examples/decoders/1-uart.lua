-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011-2014 Uwe Hermann <uwe@hermann-uwe.de>
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
local bitpack, floor, ceil, parity_ok, SamplerateError, ChannelError, Decoder
local _decoder

bitpack = logicview.bitpack
floor = _math.floor
ceil = _math.ceil
parity_ok = function(parity_type, parity_bit, data, num_data_bits)
  local ones
  if logicview.truth(logicview.eq(parity_type, "zero")) then
    return logicview.eq(parity_bit, 0)
  elseif logicview.truth(logicview.eq(parity_type, "one")) then
    return logicview.eq(parity_bit, 1)
  end
  ones = logicview.add(logicview.count(logicview.bin(data), "1"), parity_bit)
  if logicview.truth(logicview.eq(parity_type, "odd")) then
    return logicview.eq(logicview.pymod(ones, 2), 1)
  elseif logicview.truth(logicview.eq(parity_type, "even")) then
    return logicview.eq(logicview.pymod(ones, 2), 0)
  end
end
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "1:uart",
  name = "1:UART",
  longname = "Universal Asynchronous Receiver/Transmitter",
  desc = "Asynchronous, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "uart" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "rxtx", name = "RX/TX", desc = "UART transceive line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "baudrate", desc = "Baud rate", default = 115200, values = {  } }), logicview.dict({ id = "num_data_bits", desc = "Data bits", default = 8, values = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128 } }), logicview.dict({ id = "parity_type", desc = "Parity type", default = "none", values = { "none", "odd", "even", "zero", "one" } }), logicview.dict({ id = "parity_check", desc = "Check parity?", default = "yes", values = { "yes", "no" } }), logicview.dict({ id = "num_stop_bits", desc = "Stop bits", default = 1.0, values = { 0.0, 0.5, 1.0, 1.5, 2.0, 2.5 } }), logicview.dict({ id = "bit_order", desc = "Bit order", default = "lsb-first", values = { "lsb-first", "msb-first" } }), logicview.dict({ id = "format", desc = "Data format", default = "hex", values = { "ascii", "dec", "hex", "oct", "bin" } }), logicview.dict({ id = "invert", desc = "Invert Signal?", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "anno_startstop", desc = "Display Start/Stop?", default = "no", values = { "yes", "no" } }) },
  annotations = { { "108", "data", "data" }, { "7", "start", "start bits" }, { "6", "parity-ok", "parity OK bits" }, { "0", "parity-err", "parity error bits" }, { "1", "stop", "stop bits" }, { "1000", "warnings", "warnings" }, { "209", "data-bits", "data bits" }, { "10", "break", "break" } },
  annotation_rows = { { "data", "RX/TX", { 0, 1, 2, 3, 4 } }, { "data-bits", "Bits", { 6 } }, { "warnings", "Warnings", { 5 } }, { "break", "break", { 7 } } },
  binary = { { "rxtx", "RX/TX dump" } }
}
function _decoder.putx(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.startsample, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  if logicview.truth(logicview.eq(logicview.idx(self.options, "anno_startstop"), "yes")) then
    self:put((s - floor(halfbit)), logicview.add(self.samplenum, ceil(halfbit)), self.out_ann, data)
  else
    self:put(self.frame_start, logicview.add(self.samplenum, ceil(logicview.mul(halfbit, logicview.add(1, logicview.idx(self.options, "num_stop_bits"))))), self.out_ann, data)
  end
end
function _decoder.putpx(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.startsample, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  self:put((s - floor(halfbit)), logicview.add(self.samplenum, ceil(halfbit)), self.out_python, data)
end
function _decoder.putg(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.samplenum, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  self:put((s - floor(halfbit)), logicview.add(s, ceil(halfbit)), self.out_ann, data)
end
function _decoder.putp(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.samplenum, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  self:put((s - floor(halfbit)), logicview.add(s, ceil(halfbit)), self.out_python, data)
end
function _decoder.putgse(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putpse(self, ss, es, data)
  self:put(ss, es, self.out_python, data)
end
function _decoder.putbin(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.startsample, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  self:put((s - floor(halfbit)), logicview.add(self.samplenum, ceil(halfbit)), self.out_binary, data)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.samplenum = 0
  self.frame_start = (-1)
  self.frame_valid = nil
  self.startbit = (-1)
  self.cur_data_bit = 0
  self.datavalue = 0
  self.paritybit = (-1)
  self.stopbit1 = (-1)
  self.startsample = (-1)
  self.state = "WAIT FOR START BIT"
  self.databits = {  }
  self.break_start = nil
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.bw = logicview.floordiv(logicview.add(logicview.idx(self.options, "num_data_bits"), 7), 8)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.bit_width = ((_tonumber(self.samplerate) or 0) / (_tonumber(logicview.idx(self.options, "baudrate")) or 0))
  end
end
function _decoder.get_sample_point(self, bitnum)
  local bitpos
  bitpos = logicview.add(self.frame_start, ((self.bit_width - 1) / 2.0))
  bitpos = logicview.add(bitpos, logicview.mul(bitnum, self.bit_width))
  return bitpos
end
function _decoder.wait_for_start_bit(self, signal)
  self.frame_start = self.samplenum
  self.frame_valid = true
  self.state = "GET START BIT"
end
function _decoder.get_start_bit(self, signal)
  local es
  self.startbit = signal
  if logicview.truth((not logicview.eq(self.startbit, 0))) then
    self:putp({ "INVALID STARTBIT", 0, self.startbit })
    self:putg({ 5, { "Frame error", "Frame err", "FE" } })
    self.frame_valid = false
    es = logicview.add(self.samplenum, ceil((self.bit_width / 2.0)))
    self:putpse(self.frame_start, es, { "FRAME", 0, { self.datavalue, self.frame_valid } })
    self.state = "WAIT FOR START BIT"
    return
  end
  self.cur_data_bit = 0
  self.datavalue = 0
  self.startsample = (-1)
  self:putp({ "STARTBIT", 0, self.startbit })
  if logicview.truth(logicview.eq(logicview.idx(self.options, "anno_startstop"), "yes")) then
    self:putg({ 1, { "Start bit", "Start", "S" } })
  end
  self.state = "GET DATA BITS"
end
function _decoder.get_data_bits(self, signal)
  local s, halfbit, bits, b, bdata
  if logicview.truth(logicview.eq(self.startsample, (-1))) then
    self.startsample = self.samplenum
  end
  self:putg({ 6, { logicview.pymod("%d", signal) } })
  do
    local _lv_a0, _lv_a1 = self.samplenum, logicview.tointeger((self.bit_width / 2))
    s = _lv_a0
    halfbit = _lv_a1
  end
  _table.insert(self.databits, { signal, (s - halfbit), logicview.add(s, halfbit) })
  self.cur_data_bit = logicview.add(self.cur_data_bit, 1)
  if logicview.truth((self.cur_data_bit < logicview.idx(self.options, "num_data_bits"))) then
    return
  end
  bits = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.databits) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(b, 0)
  end
  return _lv_out
end)()
  if logicview.truth(logicview.eq(logicview.idx(self.options, "bit_order"), "msb-first")) then
    logicview.list_reverse(bits)
  end
  self.datavalue = bitpack(bits)
  self:putpx({ "DATA", 0, { self.datavalue, self.databits } })
  self:putx({ 0, { logicview.pymod("@%02X", self.datavalue) } })
  b = self.datavalue
  bdata = logicview.to_bytes(b, self.bw, 'big')
  self:putbin({ 0, bdata })
  self:putbin({ 1, bdata })
  self.databits = {  }
  self.state = "GET PARITY BIT"
  if logicview.truth(logicview.eq(logicview.idx(self.options, "parity_type"), "none")) then
    self.state = "GET STOP BITS"
  end
end
function _decoder.get_parity_bit(self, signal)
  self.paritybit = signal
  if logicview.truth(parity_ok(logicview.idx(self.options, "parity_type"), self.paritybit, self.datavalue, logicview.idx(self.options, "num_data_bits"))) then
    self:putp({ "PARITYBIT", 0, self.paritybit })
    self:putg({ 2, { "Parity bit", "Parity", "P" } })
  else
    self:putp({ "PARITY ERROR", 0, { 0, 1 } })
    self:putg({ 3, { "Parity error", "Parity err", "PE" } })
    self.frame_valid = false
  end
  self.state = "GET STOP BITS"
end
function _decoder.get_stop_bits(self, signal)
  local es
  self.stopbit1 = signal
  if logicview.truth((not logicview.eq(self.stopbit1, 1))) then
    self:putp({ "INVALID STOPBIT", 0, self.stopbit1 })
    self:putg({ 5, { "Frame error", "Frame err", "FE" } })
    self.frame_valid = false
  end
  self:putp({ "STOPBIT", 0, self.stopbit1 })
  if logicview.truth(logicview.eq(logicview.idx(self.options, "anno_startstop"), "yes")) then
    self:putg({ 2, { "Stop bit", "Stop", "T" } })
  end
  es = logicview.add(self.samplenum, ceil((self.bit_width / 2.0)))
  self:putpse(self.frame_start, es, { "FRAME", 0, { self.datavalue, self.frame_valid } })
  self.state = "WAIT FOR START BIT"
end
function _decoder.handle_break(self)
  self:putpse(self.frame_start, self.samplenum, { "BREAK", 0, 0 })
  self:putgse(self.frame_start, self.samplenum, { 7, { "Break condition", "Break", "Brk", "B" } })
  self.state = "WAIT FOR START BIT"
end
function _decoder.get_wait_cond(self, inv)
  local state, bitnum, want_num
  state = self.state
  if logicview.truth(logicview.eq(state, "WAIT FOR START BIT")) then
    return logicview.dict({ [0] = (function() if logicview.truth(inv) then return "r" else return "f" end end)() })
  end
  if logicview.truth(logicview.eq(state, "GET START BIT")) then
    bitnum = 0
  elseif logicview.truth(logicview.eq(state, "GET DATA BITS")) then
    bitnum = logicview.add(1, self.cur_data_bit)
  elseif logicview.truth(logicview.eq(state, "GET PARITY BIT")) then
    bitnum = logicview.add(1, logicview.idx(self.options, "num_data_bits"))
  elseif logicview.truth(logicview.eq(state, "GET STOP BITS")) then
    bitnum = logicview.add(1, logicview.idx(self.options, "num_data_bits"))
    bitnum = logicview.add(bitnum, (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "parity_type"), "none")) then return 0 else return 1 end end)())
  end
  want_num = ceil(self:get_sample_point(bitnum))
  return logicview.dict({ skip = (want_num - self.samplenum) })
end
function _decoder.inspect_sample(self, signal, inv)
  local state
  if logicview.truth(inv) then
    signal = (not logicview.truth(signal))
  end
  state = self.state
  if logicview.truth(logicview.eq(state, "WAIT FOR START BIT")) then
    self:wait_for_start_bit(signal)
  elseif logicview.truth(logicview.eq(state, "GET START BIT")) then
    self:get_start_bit(signal)
  elseif logicview.truth(logicview.eq(state, "GET DATA BITS")) then
    self:get_data_bits(signal)
  elseif logicview.truth(logicview.eq(state, "GET PARITY BIT")) then
    self:get_parity_bit(signal)
  elseif logicview.truth(logicview.eq(state, "GET STOP BITS")) then
    self:get_stop_bits(signal)
  end
end
function _decoder.inspect_edge(self, signal, inv)
  local diff
  if logicview.truth(inv) then
    signal = (not logicview.truth(signal))
  end
  if logicview.truth((not logicview.truth(signal))) then
    self.break_start = self.samplenum
    return
  end
  if logicview.truth((self.break_start == nil)) then
    return
  end
  diff = (self.samplenum - self.break_start)
  if logicview.truth((diff >= self.break_min_sample_count)) then
    self:handle_break()
  end
  self.break_start = nil
end
function _decoder.decode(self)
  local inv, cond_data_idx, frame_samples, cond_edge_idx, conds, rxtx
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  inv = logicview.eq(logicview.idx(self.options, "invert"), "yes")
  cond_data_idx = nil
  frame_samples = 1
  frame_samples = logicview.add(frame_samples, logicview.idx(self.options, "num_data_bits"))
  frame_samples = logicview.add(frame_samples, (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "parity_type"), "none")) then return 0 else return 1 end end)())
  frame_samples = logicview.add(frame_samples, logicview.idx(self.options, "num_stop_bits"))
  frame_samples = logicview.mul(frame_samples, self.bit_width)
  self.break_min_sample_count = ceil(frame_samples)
  cond_edge_idx = nil
  while true do
    conds = {  }
    cond_data_idx = logicview.len(conds)
    _table.insert(conds, self:get_wait_cond(inv))
    cond_edge_idx = logicview.len(conds)
    _table.insert(conds, logicview.dict({ [0] = "e" }))
    do
      local _lv_seq = self:wait(conds)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      rxtx = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth((function()
  local _v
  _v = (cond_data_idx ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.matched & (1 << cond_data_idx))
  return _v
end)()) then
      self:inspect_sample(rxtx, inv)
    end
    if logicview.truth((function()
  local _v
  _v = (cond_edge_idx ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.matched & (1 << cond_edge_idx))
  return _v
end)()) then
      self:inspect_edge(rxtx, inv)
    end
    ::continue_1::
  end
end

return _decoder
