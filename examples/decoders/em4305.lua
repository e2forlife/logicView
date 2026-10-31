-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Benjamin Larsson <benjamin@southpole.se>

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
  id = "em4305",
  name = "EM4305",
  longname = "RFID EM4205/EM4305",
  desc = "EM4205/EM4305 100-150kHz RFID protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "RFID" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "coilfreq", desc = "Coil frequency", default = 125000, values = {  } }), logicview.dict({ id = "first_field_stop", desc = "First field stop min", default = 40, values = {  } }), logicview.dict({ id = "w_gap", desc = "Write gap min", default = 12, values = {  } }), logicview.dict({ id = "w_one_max", desc = "Write one max", default = 32, values = {  } }), logicview.dict({ id = "w_zero_on_min", desc = "Write zero on min", default = 15, values = {  } }), logicview.dict({ id = "w_zero_off_max", desc = "Write zero off max", default = 27, values = {  } }), logicview.dict({ id = "em4100_decode", desc = "EM4100 decode", default = "on", values = { "on", "off" } }) },
  annotations = { { "bit_value", "Bit value" }, { "first_field_stop", "First field stop" }, { "write_gap", "Write gap" }, { "write_mode_exit", "Write mode exit" }, { "bit", "Bit" }, { "opcode", "Opcode" }, { "lock", "Lock" }, { "data", "Data" }, { "password", "Password" }, { "address", "Address" }, { "bitrate", "Bitrate" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "structure", "Structure", { 1, 2, 3, 4 } }, { "fields", "Fields", { 5, 6, 7, 8, 9 } }, { "decode", "Decode", { 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.last_samplenum = nil
  self.state = "FFS_SEARCH"
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
  self.br_string = { "RF/8", "RF/16", "Unused", "RF/32", "RF/40", "Unused", "Unused", "RF/64" }
  self.encoder = { "not used", "Manchester", "Bi-phase", "not used" }
  self.delayed_on = { "No delay", "Delayed on - BP/8", "Delayed on - BP/4", "No delay" }
  self.em4100_decode1_partial = 0
  self.cmds = { "Invalid", "Login", "Write word", "Invalid", "Read word", "Disable", "Protect", "Invalid" }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
  self.field_clock = (self.samplerate / logicview.idx(self.options, "coilfreq"))
  self.wzmax = logicview.mul(logicview.idx(self.options, "w_zero_off_max"), self.field_clock)
  self.wzmin = logicview.mul(logicview.idx(self.options, "w_zero_on_min"), self.field_clock)
  self.womax = logicview.mul(logicview.idx(self.options, "w_one_max"), self.field_clock)
  self.ffs = logicview.mul(logicview.idx(self.options, "first_field_stop"), self.field_clock)
  self.writegap = logicview.mul(logicview.idx(self.options, "w_gap"), self.field_clock)
  self.nogap = logicview.mul(300, self.field_clock)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode_config(self, idx)
  local bitrate, encoding, delay_on, lwr
  bitrate = self:get_3_bits(logicview.add(idx, 2))
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 5)), 2), self.out_ann, { 10, { logicview.add("Data rate: ", logicview.idx(self.br_string, bitrate)), logicview.idx(self.br_string, bitrate) } })
  encoding = ((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 6)), 0) << 0) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 7)), 0) << 1))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 6)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 10)), 2), self.out_ann, { 10, { logicview.add("Encoder: ", logicview.idx(self.encoder, encoding)), logicview.idx(self.encoder, encoding) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 11)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 12)), 2), self.out_ann, { 10, { "Zero bits", "ZB" } })
  delay_on = ((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 13)), 0) << 0) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 14)), 0) << 1))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 13)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 14)), 2), self.out_ann, { 10, { logicview.add("Delayed on: ", logicview.idx(self.delayed_on, delay_on)), logicview.idx(self.delayed_on, delay_on) } })
  lwr = ((((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 16)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 18)), 0) << 1)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 0) << 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 2), self.out_ann, { 10, { logicview.pymod("Last default read word: %d", lwr), logicview.pymod("LWR: %d", lwr), logicview.pymod("%d", lwr) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 2), self.out_ann, { 10, { logicview.pymod("Read login: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 0)), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 20)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 21)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 21)), 2), self.out_ann, { 10, { "Zero bits", "ZB" } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 2), self.out_ann, { 10, { logicview.pymod("Write login: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 0)), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 22)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 23)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 24)), 2), self.out_ann, { 10, { "Zero bits", "ZB" } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 2), self.out_ann, { 10, { logicview.pymod("Disable: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 0)), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 2), self.out_ann, { 10, { logicview.pymod("Reader talk first: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 0)), logicview.pymod("RTF: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 2), self.out_ann, { 10, { "Zero bits", "ZB" } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 2), self.out_ann, { 10, { logicview.pymod("Pigeon mode: %d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 0)), logicview.pymod("%d", logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 29)), 0)) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 30)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 34)), 2), self.out_ann, { 10, { "Reserved", "Res", "R" } })
end
function _decoder.put4bits(self, idx)
  local bits
  bits = ((((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
end
function _decoder.em4100_decode1(self, idx)
  local bits
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 9)), 2), self.out_ann, { 10, { "EM4100 header", "EM header", "Header", "H" } })
  self:put4bits(logicview.add(idx, 10))
  bits = ((((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 16)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 18)), 0) << 1)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 0) << 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 15)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 19)), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
  self:put4bits(logicview.add(idx, 21))
  self:put4bits(logicview.add(idx, 27))
  self.em4100_decode1_partial = (((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 32)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 33)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 34)), 0) << 1))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 32)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 34)), 2), self.out_ann, { 10, { "Partial nibble" } })
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
  bits = ((((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 7)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 9)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 10)), 0) << 1)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 11)), 0) << 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 7)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 11)), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
  self:put4bits(logicview.add(idx, 13))
  self:put4bits(logicview.add(idx, 19))
  bits = ((((logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 24)), 0) << 3) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 25)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 27)), 0) << 1)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 0) << 0))
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 24)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 28)), 2), self.out_ann, { 10, { logicview.pymod("%X", bits) } })
  self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 30)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 34)), 2), self.out_ann, { 10, { "EM4100 trailer" } })
end
function _decoder.get_32_bits(self, idx)
  return ((((self:get_8_bits(logicview.add(idx, 27)) << 24) | (self:get_8_bits(logicview.add(idx, 18)) << 16)) | (self:get_8_bits(logicview.add(idx, 9)) << 8)) | self:get_8_bits(idx))
end
function _decoder.get_8_bits(self, idx)
  local retval, i
  retval = 0
  for _lv_i in logicview.range(0, 8) do
    i = _lv_i
    retval = (retval << 1)
    retval = (retval | logicview.idx(logicview.idx(self.bits_pos, logicview.add(i, idx)), 0))
    ::continue_1::
  end
  return retval
end
function _decoder.get_3_bits(self, idx)
  return (((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 2) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 1)) | logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0))
end
function _decoder.get_4_bits(self, idx)
  return ((((logicview.idx(logicview.idx(self.bits_pos, idx), 0) << 0) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 1)), 0) << 1)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 2)), 0) << 2)) | (logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 3)), 0) << 3))
end
function _decoder.print_row_parity(self, idx, length)
  local parity, i
  parity = 0
  for _lv_i in logicview.range(0, length) do
    i = _lv_i
    parity = logicview.add(parity, logicview.idx(logicview.idx(self.bits_pos, logicview.add(i, idx)), 0))
    ::continue_2::
  end
  parity = (parity & 1)
  if logicview.truth(logicview.eq(parity, logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, length)), 0))) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, length)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, length)), 2), self.out_ann, { 5, { "Row parity OK", "Parity OK", "OK" } })
  else
    self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, length)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, length)), 2), self.out_ann, { 5, { "Row parity failed", "Parity failed", "Fail" } })
  end
end
function _decoder.print_col_parity(self, idx)
  local data_1, data_2, data_3, data_4, col_par, col_par_calc
  data_1 = self:get_8_bits(idx)
  data_2 = self:get_8_bits(logicview.add(idx, 9))
  data_3 = self:get_8_bits(logicview.add(logicview.add(idx, 9), 9))
  data_4 = self:get_8_bits(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9))
  col_par = self:get_8_bits(logicview.add(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9), 9))
  col_par_calc = (((data_1 ~ data_2) ~ data_3) ~ data_4)
  if logicview.truth(logicview.eq(col_par, col_par_calc)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9), 9)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9), 9), 7)), 2), self.out_ann, { 5, { "Column parity OK", "Parity OK", "OK" } })
  else
    self:put(logicview.idx(logicview.idx(self.bits_pos, logicview.add(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9), 9)), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(idx, 9), 9), 9), 9), 7)), 2), self.out_ann, { 5, { "Column parity failed", "Parity failed", "Fail" } })
  end
end
function _decoder.print_8bit_data(self, idx)
  local data
  data = self:get_8_bits(idx)
  self:put(logicview.idx(logicview.idx(self.bits_pos, idx), 1), logicview.idx(logicview.idx(self.bits_pos, logicview.add(idx, 7)), 2), self.out_ann, { 9, { logicview.add("Data", logicview.pymod(": %X", data)), logicview.pymod("%X", data) } })
end
function _decoder.put_fields(self)
  local cmd, password, addr
  if logicview.truth(logicview.eq(self.bit_nr, 50)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, 0), 1), logicview.idx(logicview.idx(self.bits_pos, 0), 2), self.out_ann, { 4, { "Logic zero" } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 1), 1), logicview.idx(logicview.idx(self.bits_pos, 4), 2), self.out_ann, { 4, { "Command", "Cmd", "C" } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 5), 1), logicview.idx(logicview.idx(self.bits_pos, 49), 2), self.out_ann, { 4, { "Password", "Passwd", "Pass", "P" } })
    cmd = self:get_3_bits(1)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 1), 1), logicview.idx(logicview.idx(self.bits_pos, 3), 2), self.out_ann, { 5, { logicview.idx(self.cmds, cmd) } })
    self:print_row_parity(1, 3)
    self:print_8bit_data(5)
    self:print_row_parity(5, 8)
    self:print_8bit_data(14)
    self:print_row_parity(14, 8)
    self:print_8bit_data(23)
    self:print_row_parity(23, 8)
    self:print_8bit_data(32)
    self:print_row_parity(32, 8)
    self:print_col_parity(5)
    if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.bits_pos, 49), 0), 0)) then
      self:put(logicview.idx(logicview.idx(self.bits_pos, 49), 1), logicview.idx(logicview.idx(self.bits_pos, 49), 2), self.out_ann, { 5, { "Stop bit", "Stop", "SB" } })
    else
      self:put(logicview.idx(logicview.idx(self.bits_pos, 49), 1), logicview.idx(logicview.idx(self.bits_pos, 49), 2), self.out_ann, { 5, { "Stop bit error", "Error" } })
    end
    if logicview.truth(logicview.eq(cmd, 1)) then
      password = self:get_32_bits(5)
      self:put(logicview.idx(logicview.idx(self.bits_pos, 12), 1), logicview.idx(logicview.idx(self.bits_pos, 46), 2), self.out_ann, { 10, { logicview.pymod("Login password: %X", password) } })
    end
  end
  if logicview.truth(logicview.eq(self.bit_nr, 57)) then
    self:put(logicview.idx(logicview.idx(self.bits_pos, 0), 1), logicview.idx(logicview.idx(self.bits_pos, 0), 2), self.out_ann, { 4, { "Logic zero", "LZ" } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 1), 1), logicview.idx(logicview.idx(self.bits_pos, 4), 2), self.out_ann, { 4, { "Command", "Cmd", "C" } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 5), 1), logicview.idx(logicview.idx(self.bits_pos, 11), 2), self.out_ann, { 4, { "Address", "Addr", "A" } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 12), 1), logicview.idx(logicview.idx(self.bits_pos, 56), 2), self.out_ann, { 4, { "Data", "Da", "D" } })
    cmd = self:get_3_bits(1)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 1), 1), logicview.idx(logicview.idx(self.bits_pos, 3), 2), self.out_ann, { 5, { logicview.idx(self.cmds, cmd) } })
    self:print_row_parity(1, 3)
    addr = self:get_4_bits(5)
    self:put(logicview.idx(logicview.idx(self.bits_pos, 5), 1), logicview.idx(logicview.idx(self.bits_pos, 8), 2), self.out_ann, { 9, { logicview.add("Addr", logicview.pymod(": %d", addr)), logicview.pymod("%d", addr) } })
    self:put(logicview.idx(logicview.idx(self.bits_pos, 9), 1), logicview.idx(logicview.idx(self.bits_pos, 10), 2), self.out_ann, { 5, { "Zero bits", "ZB" } })
    self:print_row_parity(5, 6)
    self:print_8bit_data(12)
    self:print_row_parity(12, 8)
    self:print_8bit_data(21)
    self:print_row_parity(21, 8)
    self:print_8bit_data(30)
    self:print_row_parity(30, 8)
    self:print_8bit_data(39)
    self:print_row_parity(39, 8)
    self:print_col_parity(12)
    if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.bits_pos, 56), 0), 0)) then
      self:put(logicview.idx(logicview.idx(self.bits_pos, 56), 1), logicview.idx(logicview.idx(self.bits_pos, 56), 2), self.out_ann, { 5, { "Stop bit", "Stop", "SB" } })
    else
      self:put(logicview.idx(logicview.idx(self.bits_pos, 56), 1), logicview.idx(logicview.idx(self.bits_pos, 56), 2), self.out_ann, { 5, { "Stop bit error", "Error" } })
    end
    if logicview.truth(logicview.eq(addr, 4)) then
      self:decode_config(12)
    end
    if logicview.truth(logicview.eq(addr, 2)) then
      password = self:get_32_bits(12)
      self:put(logicview.idx(logicview.idx(self.bits_pos, 12), 1), logicview.idx(logicview.idx(self.bits_pos, 46), 2), self.out_ann, { 10, { logicview.pymod("Write password: %X", password) } })
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 5)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode1(12)
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addr, 6)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.options, "em4100_decode"), "on")
  return _v
end)()) then
      self:em4100_decode2(12)
    end
  end
  self.bit_nr = 0
end
function _decoder.add_bits_pos(self, bit, ss_bit, es_bit)
  if logicview.truth((self.bit_nr < 70)) then
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 0, bit)
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 1, ss_bit)
    logicview.setidx(logicview.idx(self.bits_pos, self.bit_nr), 2, es_bit)
    self.bit_nr = logicview.add(self.bit_nr, 1)
  end
end
function _decoder.decode(self)
  local pin, pl, pp, samples, one_bits, ox, bs, be
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self.last_samplenum = self.samplenum
  self.oldsamplenum = 0
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
    if logicview.truth(logicview.eq(self.state, "FFS_DETECTED")) then
      if logicview.truth((pl > self.writegap)) then
        self.gap_detected = 1
      end
      if logicview.truth(((self.last_samplenum - self.old_gap_end) > self.nogap)) then
        self.gap_detected = 0
        self.state = "FFS_SEARCH"
        self:put(self.old_gap_end, self.last_samplenum, self.out_ann, { 3, { "Write mode exit" } })
        self:put_fields()
      end
    end
    if logicview.truth(logicview.eq(self.state, "FFS_SEARCH")) then
      if logicview.truth((pl > self.ffs)) then
        self.gap_detected = 1
        self:put(self.last_samplenum, self.samplenum, self.out_ann, { 1, { "First field stop", "Field stop", "FFS" } })
        self.state = "FFS_DETECTED"
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
        self:put(self.old_gap_end, self.samplenum, self.out_ann, { 0, { "0" } })
        self:add_bits_pos(0, self.old_gap_end, self.samplenum)
      end
      if logicview.truth((function()
  local _v
  _v = ((self.last_samplenum - self.old_gap_end) > self.womax)
  if not logicview.truth(_v) then return _v end
  _v = ((self.last_samplenum - self.old_gap_end) < self.nogap)
  return _v
end)()) then
        one_bits = logicview.tointeger(((self.last_samplenum - self.old_gap_end) / self.womax))
        for _lv_i in logicview.range(0, one_bits) do
          ox = _lv_i
          bs = logicview.tointeger(logicview.add(self.old_gap_end, logicview.mul(ox, self.womax)))
          be = logicview.tointeger(logicview.add(logicview.add(self.old_gap_end, logicview.mul(ox, self.womax)), self.womax))
          self:put(bs, be, self.out_ann, { 0, { "1" } })
          self:add_bits_pos(1, bs, be)
          ::continue_4::
        end
        if logicview.truth((function()
  local _v
  _v = ((self.samplenum - self.last_samplenum) > self.wzmin)
  if not logicview.truth(_v) then return _v end
  _v = ((self.samplenum - self.last_samplenum) < self.wzmax)
  return _v
end)()) then
          bs = logicview.tointeger(logicview.add(self.old_gap_end, logicview.mul(one_bits, self.womax)))
          self:put(bs, self.samplenum, self.out_ann, { 0, { "0" } })
          self:add_bits_pos(0, bs, self.samplenum)
        end
      end
      self.old_gap_end = self.samplenum
    end
    if logicview.truth(logicview.eq(self.state, "SKIP")) then
      self.state = "FFS_SEARCH"
    end
    self.oldsamplenum = self.samplenum
    self.last_samplenum = self.samplenum
    ::continue_3::
  end
end

return _decoder
