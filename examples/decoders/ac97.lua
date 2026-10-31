-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Gerhard Sittig <gerhard.sittig@gmx.net>
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
local ChannelError, Pins, Ann, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
Pins = {}
Pins.__index = Pins
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(5) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pins.SYNC = logicview.idx(_lv_seq, 0)
  Pins.BIT_CLK = logicview.idx(_lv_seq, 1)
  Pins.SDATA_OUT = logicview.idx(_lv_seq, 2)
  Pins.SDATA_IN = logicview.idx(_lv_seq, 3)
  Pins.RESET = logicview.idx(_lv_seq, 4)
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(32) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BITS_OUT = logicview.idx(_lv_seq, 0)
  Ann.BITS_IN = logicview.idx(_lv_seq, 1)
  Ann.SLOT_OUT_RAW = logicview.idx(_lv_seq, 2)
  Ann.SLOT_OUT_TAG = logicview.idx(_lv_seq, 3)
  Ann.SLOT_OUT_ADDR = logicview.idx(_lv_seq, 4)
  Ann.SLOT_OUT_DATA = logicview.idx(_lv_seq, 5)
  Ann.SLOT_OUT_03 = logicview.idx(_lv_seq, 6)
  Ann.SLOT_OUT_04 = logicview.idx(_lv_seq, 7)
  Ann.SLOT_OUT_05 = logicview.idx(_lv_seq, 8)
  Ann.SLOT_OUT_06 = logicview.idx(_lv_seq, 9)
  Ann.SLOT_OUT_07 = logicview.idx(_lv_seq, 10)
  Ann.SLOT_OUT_08 = logicview.idx(_lv_seq, 11)
  Ann.SLOT_OUT_09 = logicview.idx(_lv_seq, 12)
  Ann.SLOT_OUT_10 = logicview.idx(_lv_seq, 13)
  Ann.SLOT_OUT_11 = logicview.idx(_lv_seq, 14)
  Ann.SLOT_OUT_IO = logicview.idx(_lv_seq, 15)
  Ann.SLOT_IN_RAW = logicview.idx(_lv_seq, 16)
  Ann.SLOT_IN_TAG = logicview.idx(_lv_seq, 17)
  Ann.SLOT_IN_ADDR = logicview.idx(_lv_seq, 18)
  Ann.SLOT_IN_DATA = logicview.idx(_lv_seq, 19)
  Ann.SLOT_IN_03 = logicview.idx(_lv_seq, 20)
  Ann.SLOT_IN_04 = logicview.idx(_lv_seq, 21)
  Ann.SLOT_IN_05 = logicview.idx(_lv_seq, 22)
  Ann.SLOT_IN_06 = logicview.idx(_lv_seq, 23)
  Ann.SLOT_IN_07 = logicview.idx(_lv_seq, 24)
  Ann.SLOT_IN_08 = logicview.idx(_lv_seq, 25)
  Ann.SLOT_IN_09 = logicview.idx(_lv_seq, 26)
  Ann.SLOT_IN_10 = logicview.idx(_lv_seq, 27)
  Ann.SLOT_IN_11 = logicview.idx(_lv_seq, 28)
  Ann.SLOT_IN_IO = logicview.idx(_lv_seq, 29)
  Ann.WARN = logicview.idx(_lv_seq, 30)
  Ann.ERROR = logicview.idx(_lv_seq, 31)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIN_FRAME_OUT = logicview.idx(_lv_seq, 0)
  Ann.BIN_FRAME_IN = logicview.idx(_lv_seq, 1)
  Ann.BIN_SLOT_RAW_OUT = logicview.idx(_lv_seq, 2)
  Ann.BIN_SLOT_RAW_IN = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "ac97",
  name = "AC '97",
  longname = "Audio Codec '97",
  desc = "Audio and modem control for PC systems.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Audio", "PC" },
  channels = { logicview.dict({ id = "sync", name = "SYNC", desc = "Frame synchronization" }), logicview.dict({ id = "clk", name = "BIT_CLK", desc = "Data bits clock" }) },
  optional_channels = { logicview.dict({ id = "out", name = "SDATA_OUT", desc = "Data output" }), logicview.dict({ id = "in", name = "SDATA_IN", desc = "Data input" }), logicview.dict({ id = "rst", name = "RESET#", desc = "Reset line" }) },
  options = {  },
  annotations = { { "bit-out", "Output bits" }, { "bit-in", "Input bits" }, { "slot-out-raw", "Output raw value" }, { "slot-out-tag", "Output TAG" }, { "slot-out-cmd-addr", "Output command address" }, { "slot-out-cmd-data", "Output command data" }, { "slot-out-03", "Output slot 3" }, { "slot-out-04", "Output slot 4" }, { "slot-out-05", "Output slot 5" }, { "slot-out-06", "Output slot 6" }, { "slot-out-07", "Output slot 7" }, { "slot-out-08", "Output slot 8" }, { "slot-out-09", "Output slot 9" }, { "slot-out-10", "Output slot 10" }, { "slot-out-11", "Output slot 11" }, { "slot-out-io-ctrl", "Output I/O control" }, { "slot-in-raw", "Input raw value" }, { "slot-in-tag", "Input TAG" }, { "slot-in-sts-addr", "Input status address" }, { "slot-in-sts-data", "Input status data" }, { "slot-in-03", "Input slot 3" }, { "slot-in-04", "Input slot 4" }, { "slot-in-05", "Input slot 5" }, { "slot-in-06", "Input slot 6" }, { "slot-in-07", "Input slot 7" }, { "slot-in-08", "Input slot 8" }, { "slot-in-09", "Input slot 9" }, { "slot-in-10", "Input slot 10" }, { "slot-in-11", "Input slot 11" }, { "slot-in-io-sts", "Input I/O status" }, { "warning", "Warning" }, { "error", "Error" } },
  annotation_rows = { { "bits-out", "Output bits", { 0 } }, { "slots-out-raw", "Output numbers", { 2 } }, { "slots-out", "Output slots", { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } }, { "bits-in", "Input bits", { 1 } }, { "slots-in-raw", "Input numbers", { 16 } }, { "slots-in", "Input slots", { 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 } }, { "warnings", "Warnings", { 30 } }, { "errors", "Errors", { 31 } } },
  binary = { { "frame-out", "Frame bits, output data" }, { "frame-in", "Frame bits, input data" }, { "slot-raw-out", "Raw slot bits, output data" }, { "slot-raw-in", "Raw slot bits, input data" } }
}
function _decoder.putx(self, ss, es, cls, data)
  self:put(ss, es, self.out_ann, { cls, data })
end
function _decoder.putf(self, frombit, bitcount, cls, data)
  local ss, es
  ss = logicview.idx(self.frame_ss_list, frombit)
  es = logicview.idx(self.frame_ss_list, logicview.add(frombit, bitcount))
  self:putx(ss, es, cls, data)
end
function _decoder.putb(self, frombit, bitcount, cls, data)
  local ss, es
  ss = logicview.idx(self.frame_ss_list, frombit)
  es = logicview.idx(self.frame_ss_list, logicview.add(frombit, bitcount))
  self:put(ss, es, self.out_binary, { cls, data })
end
function _decoder.__init__(self)
  self.out_binary = nil
  self.out_ann = nil
  self:reset()
end
function _decoder.reset(self)
  self.frame_ss_list = nil
  self.frame_slot_lens = logicview.add({ 0, 16 }, (function()
  local _lv_out = {}
  for _lv_i in logicview.range(1, 13) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.add(16, logicview.mul(20, i))
  end
  return _lv_out
end)())
  self.frame_total_bits = logicview.idx(self.frame_slot_lens, (-1))
  self.handle_slots = logicview.dict({ [0] = self.handle_slot_00, [1] = self.handle_slot_01, [2] = self.handle_slot_02 })
end
function _decoder.start(self)
  if logicview.truth((not logicview.truth(self.out_binary))) then
    self.out_binary = self:register(logicview.OUTPUT_BINARY)
  end
  if logicview.truth((not logicview.truth(self.out_ann))) then
    self.out_ann = self:register(logicview.OUTPUT_ANN)
  end
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.bits_to_int(self, bits)
  local count, value
  if logicview.truth((not logicview.truth(bits))) then
    return 0
  end
  count = logicview.len(bits)
  value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(count) do
    i = _lv_i
    if logicview.truth(logicview.idx(bits, i)) then
    _lv_out[#_lv_out + 1] = (2 ^ ((count - 1) - i))
  end
    end
  return _lv_out
end)())
  return value
end
function _decoder.bits_to_bin_ann(self, bits)
  local out, count, by
  out = {  }
  count = logicview.len(bits)
  while logicview.truth((count > 0)) do
    count = (count - 8)
    do
      local _lv_a0, _lv_a1 = logicview.slice(bits, nil, 8, nil), logicview.slice(bits, 8, nil, nil)
      by = _lv_a0
      bits = _lv_a1
    end
    by = self:bits_to_int(by)
    _table.insert(out, by)
    ::continue_1::
  end
  out = logicview.bytes(out)
  return out
end
function _decoder.int_to_nibble_text(self, value, bitcount)
  local digits, text
  digits = logicview.floordiv(logicview.add(bitcount, 3), 4)
  text = logicview.pyformat(logicview.pyformat("{{:0{:d}x}}", { digits }, logicview.dict({})), { value }, logicview.dict({}))
  return text
end
function _decoder.get_bit_field(self, data, size, off, count)
  local shift, mask
  shift = ((size - off) - count)
  data = (data >> shift)
  mask = ((1 << count) - 1)
  data = (data & mask)
  return data
end
function _decoder.flush_frame_bits(self)
  local anncls, data, count
  anncls = Ann.BIN_FRAME_OUT
  data = logicview.slice(self.frame_bits_out, nil, nil, nil)
  count = logicview.len(data)
  data = self:bits_to_bin_ann(data)
  self:putb(0, count, anncls, data)
  anncls = Ann.BIN_FRAME_IN
  data = logicview.slice(self.frame_bits_in, nil, nil, nil)
  count = logicview.len(data)
  data = self:bits_to_bin_ann(data)
  self:putb(0, count, anncls, data)
end
function _decoder.start_frame(self, ss)
  if logicview.truth(self.frame_ss_list) then
    self:flush_frame_bits()
  end
  self.frame_ss_list = { ss }
  self.frame_bits_out = {  }
  self.frame_bits_in = {  }
  self.frame_slot_data_out = {  }
  self.frame_slot_data_in = {  }
  self.have_slots = logicview.dict({ [true] = nil, [false] = nil })
end
function _decoder.handle_slot_dummy(self, slotidx, bitidx, bitcount, is_out, data)
  local text, anncls, data_bin
  if logicview.truth((not logicview.truth(logicview.idx(self.have_slots, is_out)))) then
    return
  end
  if logicview.truth((not logicview.truth(logicview.idx(logicview.idx(self.have_slots, is_out), slotidx)))) then
    return
  end
  text = self:int_to_nibble_text(data, bitcount)
  anncls = (function() if logicview.truth(is_out) then return Ann.SLOT_OUT_TAG else return Ann.SLOT_IN_TAG end end)()
  self:putf(bitidx, bitcount, logicview.add(anncls, slotidx), { text })
  anncls = (function() if logicview.truth(is_out) then return Ann.BIN_SLOT_RAW_OUT else return Ann.BIN_SLOT_RAW_IN end end)()
  data_bin = (data >> 4)
  data_bin = (data_bin & 65535)
  data_bin = logicview.to_bytes(data_bin, 2, 'big')
  self:putb(bitidx, bitcount, anncls, data_bin)
end
function _decoder.handle_slot_00(self, slotidx, bitidx, bitcount, is_out, data)
  local slotpos, fieldoff, anncls, fieldlen, ready, text, valid, have_slots, idx, rsv, codec
  slotpos = logicview.idx(self.frame_slot_lens, slotidx)
  fieldoff = 0
  anncls = (function() if logicview.truth(is_out) then return Ann.SLOT_OUT_TAG else return Ann.SLOT_IN_TAG end end)()
  fieldlen = 1
  ready = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  text = (function() if logicview.truth(ready) then return { "READY: 1", "READY", "RDY", "R" } else return { "ready: 0", "rdy", "-" } end end)()
  self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 12
  valid = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  text = { logicview.pyformat("VALID: {:3x}", { valid }, logicview.dict({})), logicview.pyformat("{:3x}", { valid }, logicview.dict({})) }
  self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  have_slots = logicview.add({ true }, logicview.mul({ false }, 12))
  for _lv_i in logicview.range(12) do
    idx = _lv_i
    logicview.setidx(have_slots, logicview.add(idx, 1), logicview.truth((valid & (1 << (11 - idx)))))
    ::continue_2::
  end
  logicview.setidx(self.have_slots, is_out, have_slots)
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 1
  rsv = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  if logicview.truth((not logicview.eq(rsv, 0))) then
    text = { "reserved bit error", "rsv error", "rsv" }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 2
  codec = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  text = { logicview.pyformat("CODEC: {:1x}", { codec }, logicview.dict({})), logicview.pyformat("{:1x}", { codec }, logicview.dict({})) }
  self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  fieldoff = logicview.add(fieldoff, fieldlen)
end
function _decoder.handle_slot_01(self, slotidx, bitidx, bitcount, is_out, data)
  local slotpos, fieldoff, anncls, fieldlen, is_read, text, rsv, regaddr, reqdata
  slotpos = logicview.idx(self.frame_slot_lens, slotidx)
  if logicview.truth((not logicview.truth(logicview.idx(self.have_slots, is_out)))) then
    return
  end
  if logicview.truth((not logicview.truth(logicview.idx(logicview.idx(self.have_slots, is_out), slotidx)))) then
    return
  end
  fieldoff = 0
  anncls = (function() if logicview.truth(is_out) then return Ann.SLOT_OUT_TAG else return Ann.SLOT_IN_TAG end end)()
  anncls = logicview.add(anncls, slotidx)
  fieldlen = 1
  if logicview.truth(is_out) then
    is_read = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
    text = (function() if logicview.truth(is_read) then return { "READ", "RD", "R" } else return { "WRITE", "WR", "W" } end end)()
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  else
    rsv = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
    if logicview.truth((not logicview.eq(rsv, 0))) then
      text = { "reserved bit error", "rsv error", "rsv" }
      self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
    end
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 7
  regaddr = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  text = { logicview.pyformat("ADDR: {:2x}", { regaddr }, logicview.dict({})), logicview.pyformat("{:2x}", { regaddr }, logicview.dict({})) }
  self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  if logicview.truth((regaddr & 1)) then
    text = { "odd register address", "odd reg addr", "odd addr", "odd" }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 10
  reqdata = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  if logicview.truth((function()
  local _v
  _v = is_out
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(reqdata, 0))
  return _v
end)()) then
    text = { "reserved bit error", "rsv error", "rsv" }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
  end
  if logicview.truth((not logicview.truth(is_out))) then
    text = { logicview.pyformat("REQ: {:3x}", { reqdata }, logicview.dict({})), logicview.pyformat("{:3x}", { reqdata }, logicview.dict({})) }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 2
  rsv = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  if logicview.truth((not logicview.eq(rsv, 0))) then
    text = { "reserved bit error", "rsv error", "rsv" }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
end
function _decoder.handle_slot_02(self, slotidx, bitidx, bitcount, is_out, data)
  local slotpos, fieldoff, anncls, fieldlen, rwdata, text, rsv
  slotpos = logicview.idx(self.frame_slot_lens, slotidx)
  if logicview.truth((not logicview.truth(logicview.idx(self.have_slots, is_out)))) then
    return
  end
  if logicview.truth((not logicview.truth(logicview.idx(logicview.idx(self.have_slots, is_out), slotidx)))) then
    return
  end
  fieldoff = 0
  anncls = (function() if logicview.truth(is_out) then return Ann.SLOT_OUT_TAG else return Ann.SLOT_IN_TAG end end)()
  anncls = logicview.add(anncls, slotidx)
  fieldlen = 16
  rwdata = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  text = { logicview.pyformat("DATA: {:4x}", { rwdata }, logicview.dict({})), logicview.pyformat("{:4x}", { rwdata }, logicview.dict({})) }
  self:putf(logicview.add(slotpos, fieldoff), fieldlen, anncls, text)
  fieldoff = logicview.add(fieldoff, fieldlen)
  fieldlen = 4
  rsv = self:get_bit_field(data, bitcount, fieldoff, fieldlen)
  if logicview.truth((not logicview.eq(rsv, 0))) then
    text = { "reserved bits error", "rsv error", "rsv" }
    self:putf(logicview.add(slotpos, fieldoff), fieldlen, Ann.ERROR, text)
  end
  fieldoff = logicview.add(fieldoff, fieldlen)
end
function _decoder.handle_slot(self, slotidx, data_out, data_in)
  local func, bitidx, bitcount
  func = logicview.dget(self.handle_slots, slotidx, self.handle_slot_dummy)
  bitidx = logicview.idx(self.frame_slot_lens, slotidx)
  bitcount = (logicview.idx(self.frame_slot_lens, logicview.add(slotidx, 1)) - bitidx)
  if logicview.truth((data_out ~= nil)) then
    func(slotidx, bitidx, bitcount, true, data_out)
  end
  if logicview.truth((data_in ~= nil)) then
    func(slotidx, bitidx, bitcount, false, data_in)
  end
end
function _decoder.handle_bits(self, ss, es, bit_out, bit_in)
  local have_len, slot_idx, want_len, prev_len, slot_data_out, slot_bits, slot_data, slot_data_in, slot_len, slot_ss, slot_es, slot_text
  if logicview.truth((bit_out ~= nil)) then
    self:putx(ss, es, Ann.BITS_OUT, { logicview.pyformat("{:d}", { bit_out }, logicview.dict({})) })
  end
  if logicview.truth((bit_in ~= nil)) then
    self:putx(ss, es, Ann.BITS_IN, { logicview.pyformat("{:d}", { bit_in }, logicview.dict({})) })
  end
  if logicview.truth((self.frame_ss_list == nil)) then
    return
  end
  _table.insert(self.frame_ss_list, es)
  have_len = (logicview.len(self.frame_ss_list) - 1)
  if logicview.truth((have_len > self.frame_total_bits)) then
    return
  end
  slot_idx = 0
  if logicview.truth((bit_out ~= nil)) then
    _table.insert(self.frame_bits_out, bit_out)
    slot_idx = logicview.len(self.frame_slot_data_out)
  end
  if logicview.truth((bit_in ~= nil)) then
    _table.insert(self.frame_bits_in, bit_in)
    slot_idx = logicview.len(self.frame_slot_data_in)
  end
  want_len = logicview.idx(self.frame_slot_lens, logicview.add(slot_idx, 1))
  if logicview.truth((not logicview.eq(have_len, want_len))) then
    return
  end
  prev_len = logicview.idx(self.frame_slot_lens, slot_idx)
  slot_data_out = nil
  if logicview.truth((bit_out ~= nil)) then
    slot_bits = logicview.slice(self.frame_bits_out, prev_len, nil, nil)
    slot_data = self:bits_to_int(slot_bits)
    _table.insert(self.frame_slot_data_out, slot_data)
    slot_data_out = slot_data
  end
  slot_data_in = nil
  if logicview.truth((bit_in ~= nil)) then
    slot_bits = logicview.slice(self.frame_bits_in, prev_len, nil, nil)
    slot_data = self:bits_to_int(slot_bits)
    _table.insert(self.frame_slot_data_in, slot_data)
    slot_data_in = slot_data
  end
  slot_len = (have_len - prev_len)
  slot_ss = logicview.idx(self.frame_ss_list, prev_len)
  slot_es = logicview.idx(self.frame_ss_list, have_len)
  if logicview.truth((slot_data_out ~= nil)) then
    slot_text = self:int_to_nibble_text(slot_data_out, slot_len)
    self:putx(slot_ss, slot_es, Ann.SLOT_OUT_RAW, { slot_text })
  end
  if logicview.truth((slot_data_in ~= nil)) then
    slot_text = self:int_to_nibble_text(slot_data_in, slot_len)
    self:putx(slot_ss, slot_es, Ann.SLOT_IN_RAW, { slot_text })
  end
  self:handle_slot(slot_idx, slot_data_out, slot_data_in)
end
function _decoder.decode(self)
  local have_sdo, have_sdi, have_reset, prev_sync, sync, bit_clk, sdata_out, sdata_in, reset, bit_ss
  have_sdo = self:has_channel(Pins.SDATA_OUT)
  have_sdi = self:has_channel(Pins.SDATA_IN)
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(have_sdo))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(have_sdi))
  return _v
end)()) then
    _error(ChannelError("Either SDATA_OUT or SDATA_IN (or both) are required."), 0)
  end
  have_reset = self:has_channel(Pins.RESET)
  prev_sync = { nil, nil, nil }
  do
    local _lv_seq = self:wait(logicview.dict({ [Pins.BIT_CLK] = "e" }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    sync = logicview.idx(_lv_seq, 0)
    bit_clk = logicview.idx(_lv_seq, 1)
    sdata_out = logicview.idx(_lv_seq, 2)
    sdata_in = logicview.idx(_lv_seq, 3)
    reset = logicview.idx(_lv_seq, 4)
  end
  if logicview.truth(logicview.eq(bit_clk, 0)) then
    logicview.setidx(prev_sync, (-1), sync)
    do
      local _lv_seq = self:wait(logicview.dict({ [Pins.BIT_CLK] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sync = logicview.idx(_lv_seq, 0)
      bit_clk = logicview.idx(_lv_seq, 1)
      sdata_out = logicview.idx(_lv_seq, 2)
      sdata_in = logicview.idx(_lv_seq, 3)
      reset = logicview.idx(_lv_seq, 4)
    end
  end
  bit_ss = self.samplenum
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [Pins.BIT_CLK] = "f" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sync = logicview.idx(_lv_seq, 0)
      bit_clk = logicview.idx(_lv_seq, 1)
      sdata_out = logicview.idx(_lv_seq, 2)
      sdata_in = logicview.idx(_lv_seq, 3)
      reset = logicview.idx(_lv_seq, 4)
    end
    logicview.list_pop(prev_sync, 0)
    _table.insert(prev_sync, sync)
    self:wait(logicview.dict({ [Pins.BIT_CLK] = "r" }))
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(prev_sync, 0), 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(prev_sync, 1), 1)
  return _v
end)()) then
      self:start_frame(bit_ss)
    end
    self:handle_bits(bit_ss, self.samplenum, (function() if logicview.truth(have_sdo) then return sdata_out else return nil end end)(), (function() if logicview.truth(have_sdi) then return sdata_in else return nil end end)())
    bit_ss = self.samplenum
    ::continue_3::
  end
end

return _decoder
