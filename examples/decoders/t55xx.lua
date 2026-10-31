-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Benjamin Larsson <benjamin@southpole.se>

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
  id = "t55xx",
  name = "T55xx",
  longname = "RFID T55xx",
  desc = "T55xx 100-150kHz RFID protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "RFID" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "coilfreq", desc = "Coil frequency", default = 125000, values = {  } }), logicview.dict({ id = "start_gap", desc = "Start gap min", default = 20, values = {  } }), logicview.dict({ id = "w_gap", desc = "Write gap min", default = 20, values = {  } }), logicview.dict({ id = "w_one_min", desc = "Write one min", default = 48, values = {  } }), logicview.dict({ id = "w_one_max", desc = "Write one max", default = 63, values = {  } }), logicview.dict({ id = "w_zero_min", desc = "Write zero min", default = 16, values = {  } }), logicview.dict({ id = "w_zero_max", desc = "Write zero max", default = 31, values = {  } }), logicview.dict({ id = "em4100_decode", desc = "EM4100 decode", default = "on", values = { "on", "off" } }) },
  annotations = { { "bit_value", "Bit value" }, { "start_gap", "Start gap" }, { "write_gap", "Write gap" }, { "write_mode_exit", "Write mode exit" }, { "bit", "Bit" }, { "opcode", "Opcode" }, { "lock", "Lock" }, { "data", "Data" }, { "password", "Password" }, { "address", "Address" }, { "bitrate", "Bitrate" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "structure", "Structure", { 1, 2, 3, 4 } }, { "fields", "Fields", { 5, 6, 7, 8, 9 } }, { "decode", "Decode", { 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.last_samplenum = nil
  self.lastlast_samplenum = nil
  self.state = "START_GAP"
  self.bits_pos = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(70) do
    row = _lv_i
    _lv_out[#_lv_out + 1] = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(3) do
    col = _lv_i
    _lv_out[#_lv_out + 1] = 0
  end
  return _lv_out
end)()
  end
  return _lv_out
end)()
  self.br_string = { "RF/8", "RF/16", "RF/32", "RF/40", "RF/50", "RF/64", "RF/100", "RF/128" }
  self.mod_str1 = { "Direct", "Manchester", "Biphase", "Reserved" }
  self.mod_str2 = { "Direct", "PSK1", "PSK2", "PSK3", "FSK1", "FSK2", "FSK1a", "FSK2a" }
  self.pskcf_str = { "RF/2", "RF/4", "RF/8", "Reserved" }
  self.em4100_decode1_partial = 0
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
  self.field_clock = (self.samplerate / logicview.idx(self.options, "coilfreq"))
  self.wzmax = logicview.mul(logicview.idx(self.options, "w_zero_max"), self.field_clock)
  self.wzmin = logicview.mul(logicview.idx(self.options, "w_zero_min"), self.field_clock)
  self.womax = logicview.mul(logicview.idx(self.options, "w_one_max"), self.field_clock)
  self.womin = logicview.mul(logicview.idx(self.options, "w_one_min"), self.field_clock)
  self.startgap = logicview.mul(logicview.idx(self.options, "start_gap"), self.field_clock)
  self.writegap = logicview.mul(logicview.idx(self.options, "w_gap"), self.field_clock)
  self.nogap = logicview.mul(64, self.field_clock)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode_config(self, idx)
  local safer_key, bitrate, modulation1, modulation2, mod_string, psk_cf, maxblock
  safer_key = ((((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 2), self.out_ann, { 10, { logicview.add("Safer Key", logicview.pymod(": %X", safer_key)), logicview.pymod("%X", safer_key) } })
  bitrate = (((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 11)), 0) << 2) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 12)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 13)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 11)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 13)), 2), self.out_ann, { 10, { logicview.add("Data Bit Rate: ", logicview.idx(self.br_string, bitrate)), logicview.idx(self.br_string, bitrate) } })
  modulation1 = ((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 0) << 1) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 16)), 0))
  modulation2 = (((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 17)), 0) << 2) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 18)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 0))
  if logicview.truth(logicview.eq(modulation1, 0)) then
    mod_string = logicview.idx(self.mod_str2, modulation2)
  else
    mod_string = logicview.idx(self.mod_str1, modulation1)
  end
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 2), self.out_ann, { 10, { logicview.add("Modulation: ", mod_string), mod_string } })
  psk_cf = ((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 0) << 1) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 21)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 21)), 2), self.out_ann, { 10, { logicview.add("PSK-CF: ", logicview.idx(self.pskcf_str, psk_cf)), logicview.idx(self.pskcf_str, psk_cf) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 2), self.out_ann, { 10, { logicview.add("AOR", logicview.pymod(": %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 0))), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 0)) } })
  maxblock = (((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 24)), 0) << 2) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 26)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 24)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 26)), 2), self.out_ann, { 10, { logicview.add("Max-Block", logicview.pymod(": %d", maxblock)), logicview.pymod("%d", maxblock) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 2), self.out_ann, { 10, { logicview.add("PWD", logicview.pymod(": %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 0))), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 2), self.out_ann, { 10, { logicview.add("ST-sequence terminator", logicview.pymod(": %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 0))), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 2), self.out_ann, { 10, { logicview.add("POR delay", logicview.pymod(": %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 0))), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 0)) } })
end
function _decoder.put4bits(self, idx)
  local bits
  bits = ((((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
end
function _decoder.em4100_decode1(self, idx)
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 8)), 2), self.out_ann, { 10, { "EM4100 header", "EM header", "Header", "H" } })
  self:put4bits(logicview.add(idx, 9))
  self:put4bits(logicview.add(idx, 14))
  self:put4bits(logicview.add(idx, 19))
  self:put4bits(logicview.add(idx, 24))
  self.em4100_decode1_partial = (((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 30)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 0) << 1))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 2), self.out_ann, { 10, { "Partial nibble" } })
end
function _decoder.em4100_decode2(self, idx)
  local bits
  if logicview.truth((not logicview.eq(self.em4100_decode1_partial, 0))) then
    bits = logicview.add(self.em4100_decode1_partial, logicview.idx(logicview.idx(self.bits_pos, idx), 0))
    self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, idx), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
    self.em4100_decode1_partial = 0
  else
    self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, idx), 2), self.out_ann, { 10, { "Partial nibble" } })
  end
  self:put4bits(logicview.add(idx, 2))
  self:put4bits(logicview.add(idx, 7))
  self:put4bits(logicview.add(idx, 12))
  self:put4bits(logicview.add(idx, 17))
  self:put4bits(logicview.add(idx, 22))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 31)), 2), self.out_ann, { 10, { "EM4100 trailer" } })
end
function _decoder.get_32_bits(self, idx)
  local retval, i
  retval = 0
  for _lv_i in logicview.range(0, 32) do
    i = _lv_i
    retval = (retval << 1)
    retval = (retval | logicview.idx(logicview.idx(self.bits_pos, logicview.add(i, idx)), 0))
    ::continue_1::
  end
  return retval
end
function _decoder.get_3_bits(self, idx)
  local retval
  retval = (((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 2) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0))
  return retval
end
function _decoder.put_fields(self)
  local password, data, addr
  if logicview.truth(logicview.eq(self.bit_nr, 70)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, 0), 1), logicview.idx(logicview.idx(self.bits_pos, 1), 2), self.out_ann, { 5, { logicview.add("Opcode", logicview.pymod(": %d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) })), logicview.pymod("%d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) }) } })
    password = self:get_32_bits(2)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 2), 1), logicview.idx(logicview.idx(self.bits_pos, 33), 2), self.out_ann, { 8, { logicview.add("Password", logicview.pymod(": %X", password)), logicview.pymod("%X", password) } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 34), 1), logicview.idx(logicview.idx(self.bits_pos, 34), 2), self.out_ann, { 6, { logicview.add("Lock", logicview.pymod(": %X", logicview.idx(logicview.idx(self.bits_pos, 34), 0))), logicview.pymod("%X", logicview.idx(logicview.idx(self.bits_pos, 34), 0)) } })
    data = self:get_32_bits(35)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 35), 1), logicview.idx(logicview.idx(self.bits_pos, 66), 2), self.out_ann, { 7, { logicview.add("Data", logicview.pymod(": %X", data)), logicview.pymod("%X", data) } })
    addr = self:get_3_bits(67)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 67), 1), logicview.idx(logicview.idx(self.bits_pos, 69), 2), self.out_ann, { 9, { logicview.add("Addr", logicview.pymod(": %X", addr)), logicview.pymod("%X", addr) } })
    if logicview.truth(logicview.eq(addr, 0)) then
      self:decode_config(35)
    end
    if logicview.truth(logicview.eq(addr, 7)) then
      self:put(logicview.idx(logicview.idx(self.bits_pos, 35), 1), logicview.idx(logicview.idx(self.bits_pos, 66), 2), self.out_ann, { 10, { logicview.add("Password", logicview.pymod(": %X", data)), logicview.pymod("%X", data) } })
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode1(35)
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode2(35)
    end
  end
  if logicview.truth(logicview.eq(self.bit_nr, 38)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, 0), 1), logicview.idx(logicview.idx(self.bits_pos, 1), 2), self.out_ann, { 5, { logicview.add("Opcode", logicview.pymod(": %d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) })), logicview.pymod("%d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) }) } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 2), 1), logicview.idx(logicview.idx(self.bits_pos, 2), 2), self.out_ann, { 6, { logicview.add("Lock", logicview.pymod(": %X", logicview.idx(logicview.idx(self.bits_pos, 2), 0))), logicview.pymod("%X", logicview.idx(logicview.idx(self.bits_pos, 2), 0)) } })
    data = self:get_32_bits(3)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 3), 1), logicview.idx(logicview.idx(self.bits_pos, 34), 2), self.out_ann, { 7, { logicview.add("Data", logicview.pymod(": %X", data)), logicview.pymod("%X", data) } })
    addr = self:get_3_bits(35)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 35), 1), logicview.idx(logicview.idx(self.bits_pos, 37), 2), self.out_ann, { 9, { logicview.add("Addr", logicview.pymod(": %X", addr)), logicview.pymod("%X", addr) } })
    if logicview.truth(logicview.eq(addr, 0)) then
      self:decode_config(3)
    end
    if logicview.truth(logicview.eq(addr, 7)) then
      self:put(logicview.idx(logicview.idx(self.bits_pos, 3), 1), logicview.idx(logicview.idx(self.bits_pos, 34), 2), self.out_ann, { 10, { logicview.add("Password", logicview.pymod(": %X", data)), logicview.pymod("%X", data) } })
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode1(3)
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode2(3)
    end
  end
  if logicview.truth(logicview.eq(self.bit_nr, 2)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, 0), 1), logicview.idx(logicview.idx(self.bits_pos, 1), 2), self.out_ann, { 5, { logicview.add("Opcode", logicview.pymod(": %d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) })), logicview.pymod("%d%d", { logicview.idx(logicview.idx(self.bits_pos, 0), 0), logicview.idx(logicview.idx(self.bits_pos, 1), 0) }) } })
  end
  self.bit_nr = 0
end
function _decoder.add_bits_pos(self, bit, bit_start, bit_end)
  if logicview.truth((self.bit_nr < 70)) then
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 0, bit)
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 1, bit_start)
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 2, bit_end)
    self.bit_nr = logicview.add(self.bit_nr, 1)
  end
end
function _decoder.decode(self)
  local pin, pl, pp, samples
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self.last_samplenum = 0
  self.lastlast_samplenum = 0
  self.last_edge = 0
  self.oldpl = 0
  self.oldpp = 0
  self.oldsamplenum = 0
  self.last_bit_pos = 0
  self.old_gap_start = 0
  self.old_gap_end = 0
  self.gap_detected = 0
  self.bit_nr = 0
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      pin = logicview.idx(_lv_seq, 0)
    end
    pl = (self.samplenum - self.oldsamplenum)
    pp = pin
    samples = (self.samplenum - self.last_samplenum)
    if logicview.truth(logicview.eq(self.state, "WRITE_GAP")) then
      if logicview.truth((pl > self.writegap)) then
        self.gap_detected = 1
        self:put(self.last_samplenum, self.samplenum, self.out_ann, { 2, { "Write gap" } })
      end
      if logicview.truth(((self.last_samplenum - self.old_gap_end) > self.nogap)) then
        self.gap_detected = 0
        self.state = "START_GAP"
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 3, { "Write mode exit" } })
        self:put_fields()
      end
    end
    if logicview.truth(logicview.eq(self.state, "START_GAP")) then
      if logicview.truth((pl > self.startgap)) then
        self.gap_detected = 1
        self:put(self.last_samplenum, self.samplenum, self.out_ann, { 1, { "Start gap" } })
        self.state = "WRITE_GAP"
      end
    end
    if logicview.truth(logicview.eq(self.gap_detected, 1)) then
      self.gap_detected = 0
      if logicview.truth((function()
  local _v
  _v = ((self.last_samplenum - self.old_gap_end) > self.wzmin)
  if not logicview.truth(_v) then return _v end
  _v = ((self.last_samplenum - self.old_gap_end) < self.wzmax)
  return _v
end)()) then
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 0, { "0" } })
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 4, { "Bit" } })
        self:add_bits_pos(0, self.old_gap_end, self.last_samplenum)
      end
      if logicview.truth((function()
  local _v
  _v = ((self.last_samplenum - self.old_gap_end) > self.womin)
  if not logicview.truth(_v) then return _v end
  _v = ((self.last_samplenum - self.old_gap_end) < self.womax)
  return _v
end)()) then
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 0, { "1" } })
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 4, { "Bit" } })
        self:add_bits_pos(1, self.old_gap_end, self.last_samplenum)
      end
      self.old_gap_start = self.last_samplenum
      self.old_gap_end = self.samplenum
    end
    self.oldpl = pl
    self.oldpp = pp
    self.oldsamplenum = self.samplenum
    self.last_samplenum = self.samplenum
    ::continue_2::
  end
end

return _decoder
