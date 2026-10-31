-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2013 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2019 Stephan Thiele <stephan.thiele@mailbox.org>
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
local bitpack_msb, SamplerateError, dlc2len, ParityCheck, gray_to_binary, Decoder
local _decoder

bitpack_msb = logicview.bitpack_msb
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
dlc2len = function(dlc)
  return logicview.idx({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64 }, dlc)
end
ParityCheck = function(value)
  local paritycheck, parity, parityvalue
  paritycheck = false
  parity = { 0, 3, 5, 6, 9, 10, 12, 15 }
  for _lv_item in logicview.iter(parity) do
    parityvalue = _lv_item
    if logicview.truth(logicview.eq(parityvalue, value)) then
      paritycheck = true
      break
    end
    ::continue_1::
  end
  return paritycheck
end
gray_to_binary = function(gray_code)
  local binary_code, i
  binary_code = logicview.idx(gray_code, 0)
  for _lv_i in logicview.range(1, logicview.len(gray_code)) do
    i = _lv_i
    if logicview.truth(logicview.eq(logicview.idx(gray_code, i), "0")) then
      binary_code = logicview.add(binary_code, logicview.idx(binary_code, (i - 1)))
    else
      binary_code = logicview.add(binary_code, (function() if logicview.truth(logicview.eq(logicview.idx(binary_code, (i - 1)), "0")) then return "1" else return "0" end end)())
    end
    ::continue_2::
  end
  return binary_code
end
_decoder = {
  api_version = 3,
  id = "can-fd",
  name = "CAN-FD",
  longname = "Controller Area Network with Flexible Data rate",
  desc = "Field bus protocol for distributed realtime control.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "can" },
  tags = { "Automotive" },
  channels = { logicview.dict({ id = "can_rx", name = "CAN FD", desc = "CAN FD bus line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "nominal_bitrate", desc = "Nominal bitrate (bits/s)", default = 1000000, values = {  } }), logicview.dict({ id = "fast_bitrate", desc = "Fast bitrate (bits/s)", default = 2000000, values = {  } }), logicview.dict({ id = "sample_point", desc = "Sample point (%)", default = 70.0, values = {  } }) },
  annotations = { { "data", "CAN payload data" }, { "sof", "Start of frame" }, { "eof", "End of frame" }, { "id", "Identifier" }, { "ext-id", "Extended identifier" }, { "full-id", "Full identifier" }, { "ide", "Identifier extension bit" }, { "reserved-bit", "Reserved bit 0 and 1" }, { "rtr", "Remote transmission request" }, { "srr", "Substitute remote request" }, { "dlc", "Data length count" }, { "crc-sequence", "CRC sequence" }, { "crc-delimiter", "CRC delimiter" }, { "ack-slot", "ACK slot" }, { "ack-delimiter", "ACK delimiter" }, { "stuff-bit", "Stuff bit" }, { "warnings", "Human-readable warnings" }, { "bit", "Bit" } },
  annotation_rows = { { "bits", "Bits", { 15, 17 } }, { "fields", "Fields", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 } }, { "warnings", "Warnings", { 16 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self:reset_variables()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.set_bit_rate(self, bitrate)
  self.bit_width = ((_tonumber(self.samplerate) or 0) / (_tonumber(bitrate) or 0))
  self.sample_point = logicview.mul((self.bit_width / 100.0), logicview.idx(self.options, "sample_point"))
end
function _decoder.set_nominal_bitrate(self)
  self:set_bit_rate(logicview.idx(self.options, "nominal_bitrate"))
end
function _decoder.set_fast_bitrate(self)
  self:set_bit_rate(logicview.idx(self.options, "fast_bitrate"))
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.bit_width = ((_tonumber(self.samplerate) or 0) / (_tonumber(logicview.idx(self.options, "nominal_bitrate")) or 0))
    self.sample_point = logicview.mul((self.bit_width / 100.0), logicview.idx(self.options, "sample_point"))
  end
end
function _decoder.putg(self, ss, es, data)
  local left, right
  do
    local _lv_a0, _lv_a1 = logicview.tointeger(self.sample_point), logicview.tointeger((self.bit_width - self.sample_point))
    left = _lv_a0
    right = _lv_a1
  end
  self:put((ss - left), logicview.add(es, right), self.out_ann, data)
end
function _decoder.putx(self, data)
  self:putg(self.samplenum, self.samplenum, data)
end
function _decoder.put12(self, data)
  self:putg(self.ss_bit12, self.ss_bit12, data)
end
function _decoder.put32(self, data)
  self:putg(self.ss_bit32, self.ss_bit32, data)
end
function _decoder.putb(self, data)
  self:putg(self.ss_block, self.samplenum, data)
end
function _decoder.putpy(self, data)
  self:put(self.ss_packet, self.es_packet, self.out_python, data)
end
function _decoder.reset_variables(self)
  self.state = "IDLE"
  do
    local _lv_chain = nil
    self.sof = _lv_chain
    self.frame_type = _lv_chain
    self.dlc = _lv_chain
  end
  self.rawbits = {  }
  self.bits = {  }
  self.curbit = 0
  self.last_databit = 999
  self.ss_block = nil
  self.ss_bit12 = nil
  self.ss_bit32 = nil
  self.ss_databytebits = {  }
  self.frame_bytes = {  }
  self.rtr_type = nil
  self.fd = false
  self.rtr = nil
  self.crc_data = {  }
  self.stuff_count_start = nil
  self.stuff_count = 0
end
function _decoder.dom_edge_seen(self, force)
  if force == nil then force = false end
  self.dom_edge_snum = self.samplenum
  self.dom_edge_bcount = self.curbit
end
function _decoder.get_sample_point(self, bitnum)
  local samplenum
  samplenum = self.dom_edge_snum
  samplenum = logicview.add(samplenum, logicview.mul(self.bit_width, (bitnum - self.dom_edge_bcount)))
  samplenum = logicview.add(samplenum, self.sample_point)
  return logicview.tointeger(samplenum)
end
function _decoder.is_stuff_bit(self)
  local last_6_bits
  if logicview.truth((logicview.len(self.bits) > logicview.add(self.last_databit, 17))) then
    return false
  end
  if logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.bits) > logicview.add(self.last_databit, 1))
  return _v
end)()) then
    return false
  end
  last_6_bits = logicview.slice(self.rawbits, (-6), nil, nil)
  if logicview.truth((not logicview.contains({ { 0, 0, 0, 0, 0, 1 }, { 1, 1, 1, 1, 1, 0 } }, last_6_bits))) then
    return false
  end
  self.stuff_count = logicview.add(self.stuff_count, 1)
  logicview.list_pop(self.bits)
  return true
end
function _decoder.is_valid_crc(self, crc_bits, crc_type)
  return true
end
function _decoder.decode_error_frame(self, bits)
end
function _decoder.decode_overload_frame(self, bits)
end
function _decoder.decode_frame_end(self, can_rx, bitnum)
  local stuff_bits, stuff_count, stuff_count_bin, stuff_count_bin_val, stuff_and_parity_bits, stuff_and_parity, index, crc_type, x, crc_bits, ack, py_data
  if logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, 1))) then
    self.ss_block = self.samplenum
    if logicview.truth(self.fd) then
      if logicview.truth((dlc2len(self.dlc) <= 16)) then
        self.crc_len = 27
      else
        self.crc_len = 32
      end
      self:putx({ 15, { logicview.pymod("Fixed stuff bit: %d", can_rx), logicview.pymod("FSB: %d", can_rx), logicview.pymod("%d", can_rx) } })
    else
      self.crc_len = 15
    end
  elseif logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bitnum, logicview.add(self.last_databit, 2))
  return _v
end)()) then
    self.ss_block = self.samplenum
    self.stuff_count_start = self.samplenum
  elseif logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bitnum, logicview.add(self.last_databit, 4))
  return _v
end)()) then
    stuff_bits = logicview.slice(self.bits, (-3), nil, nil)
    stuff_count = logicview.pyformat("{0:b}", { bitpack_msb(stuff_bits) }, logicview.dict({}))
    while logicview.truth((not logicview.eq(logicview.len(stuff_count), 3))) do
      stuff_count = logicview.add("0", stuff_count)
      ::continue_3::
    end
    stuff_count_bin = gray_to_binary(stuff_count)
    stuff_count_bin_val = logicview.tointeger(stuff_count_bin, 2)
    if logicview.truth((not logicview.eq(logicview.pymod(self.stuff_count, 8), stuff_count_bin_val))) then
      self:putb({ 16, { "Gray Code Error", "GCE", "GCE" } })
    end
    self.stuff_count = 0
    self:putb({ 11, { logicview.pymod("Stuff count: %s", stuff_count), logicview.pymod("Stuff count: %s", stuff_count), logicview.pymod("%s", stuff_count) } })
    self.ss_block = logicview.add(self.samplenum, logicview.tointeger(self.bit_width))
  elseif logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bitnum, logicview.add(self.last_databit, 5))
  return _v
end)()) then
    stuff_and_parity_bits = logicview.slice(self.bits, (-4), nil, nil)
    stuff_and_parity = bitpack_msb(stuff_and_parity_bits)
    if logicview.truth(logicview.eq(ParityCheck(stuff_and_parity), false)) then
      self:putg(self.stuff_count_start, self.samplenum, { 16, { "Parity Check Error", "PCE", "PCE" } })
    end
    self:putx({ 11, { logicview.pymod("Parity: %d", can_rx), logicview.pymod("P: %d", can_rx), logicview.pymod("%d", can_rx) } })
    self.ss_block = logicview.add(self.samplenum, logicview.tointeger(self.bit_width))
  elseif logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = (bitnum > logicview.add(self.last_databit, 5))
  if not logicview.truth(_v) then return _v end
  _v = (bitnum < logicview.add(self.last_databit, self.crc_len))
  return _v
end)()) then
    index = (bitnum - logicview.add(self.last_databit, 5))
    if logicview.truth(logicview.eq(logicview.pymod((index - 1), 5), 0)) then
      self:putx({ 15, { logicview.pymod("Fixed stuff bit: %d", can_rx), logicview.pymod("FSB: %d", can_rx), logicview.pymod("%d", can_rx) } })
    end
    if logicview.truth(logicview.eq(logicview.pymod(index, 5), 0)) then
      self.crc_data = logicview.add(self.crc_data, logicview.slice(self.bits, (-4), nil, nil))
    end
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, self.crc_len))) then
    if logicview.truth(self.fd) then
      if logicview.truth((dlc2len(self.dlc) <= 16)) then
        crc_type = "CRC-17"
      else
        crc_type = "CRC-21"
      end
    else
      crc_type = "CRC-15"
    end
    x = logicview.add(self.last_databit, 1)
    crc_bits = logicview.slice(self.bits, x, logicview.add(logicview.add(x, self.crc_len), 1), nil)
    if logicview.truth(self.fd) then
      _table.insert(self.crc_data, can_rx)
      self.crc = bitpack_msb(self.crc_data)
    else
      self.crc = bitpack_msb(crc_bits)
    end
    self:putb({ 11, { logicview.pymod("%s sequence: 0x%04x", { crc_type, self.crc }), logicview.pymod("%s: 0x%04x", { crc_type, self.crc }), logicview.pymod("0x%04x", self.crc) } })
    if logicview.truth((not logicview.truth(self:is_valid_crc(crc_bits, crc_type)))) then
      self:putb({ 16, { "CRC is invalid" } })
    end
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(logicview.add(self.last_databit, self.crc_len), 1))) then
    self:putx({ 12, { logicview.pymod("CRC delimiter: %d", can_rx), logicview.pymod("CRC d: %d", can_rx), logicview.pymod("%d", can_rx) } })
    if logicview.truth((not logicview.eq(can_rx, 1))) then
      self:putx({ 16, { "CRC delimiter must be a recessive bit" } })
    end
    if logicview.truth(self.fd) then
      self:set_nominal_bitrate()
    end
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(logicview.add(self.last_databit, self.crc_len), 2))) then
    ack = (function() if logicview.truth(logicview.eq(can_rx, 0)) then return "ACK" else return "NACK" end end)()
    self:putx({ 13, { logicview.pymod("ACK slot: %s", ack), logicview.pymod("ACK s: %s", ack), logicview.pymod("%s", ack) } })
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(logicview.add(self.last_databit, self.crc_len), 3))) then
    self:putx({ 14, { logicview.pymod("ACK delimiter: %d", can_rx), logicview.pymod("ACK d: %d", can_rx), logicview.pymod("%d", can_rx) } })
    if logicview.truth((not logicview.eq(can_rx, 1))) then
      self:putx({ 16, { "ACK delimiter must be a recessive bit" } })
    end
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(logicview.add(self.last_databit, self.crc_len), 4))) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(logicview.add(self.last_databit, self.crc_len), 10))) then
    self:putb({ 2, { "End of frame", "EOF", "E" } })
    if logicview.truth((not logicview.eq(logicview.slice(self.rawbits, (-7), nil, nil), { 1, 1, 1, 1, 1, 1, 1 }))) then
      self:putb({ 16, { "End of frame (EOF) must be 7 recessive bits" } })
    end
    self.es_packet = self.samplenum
    py_data = logicview.copy({ self.frame_type, self.fullid, self.rtr_type, self.dlc, self.frame_bytes })
    self:putpy(py_data)
    self:reset_variables()
    return true
  end
  return false
end
function _decoder.decode_standard_frame(self, can_rx, bitnum)
  local rtr, i, x, b, ss, es
  if logicview.truth(logicview.eq(bitnum, 14)) then
    self.fd = (function() if logicview.truth(can_rx) then return true else return false end end)()
    self:putx({ 7, { logicview.pymod("Flexible data format: %d", can_rx), logicview.pymod("FDF: %d", can_rx), logicview.pymod("%d", can_rx) } })
    if logicview.truth(self.fd) then
      self:put12({ 8, { "Remote request subtitution", "RRS" } })
      self.dlc_start = 18
    else
      rtr = (function() if logicview.truth(logicview.eq(logicview.idx(self.bits, 12), 1)) then return "remote" else return "data" end end)()
      self:put12({ 8, { logicview.pymod("Remote transmission request: %s frame", rtr), logicview.pymod("RTR: %s frame", rtr), logicview.pymod("%s", rtr) } })
      self.rtr_type = rtr
      self.dlc_start = 15
    end
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(bitnum, 15)
  if not logicview.truth(_v) then return _v end
  _v = self.fd
  return _v
end)()) then
    self:putx({ 7, { logicview.pymod("Reserved bit 0: %d", can_rx), logicview.pymod("RB0: %d", can_rx), logicview.pymod("%d", can_rx) } })
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(bitnum, 16)
  if not logicview.truth(_v) then return _v end
  _v = self.fd
  return _v
end)()) then
    self:putx({ 7, { logicview.pymod("Bit rate switch: %d", can_rx), logicview.pymod("BRS: %d", can_rx), logicview.pymod("%d", can_rx) } })
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(bitnum, 17)
  if not logicview.truth(_v) then return _v end
  _v = self.fd
  return _v
end)()) then
    self:putx({ 7, { logicview.pymod("Error state indicator: %d", can_rx), logicview.pymod("ESI: %d", can_rx), logicview.pymod("%d", can_rx) } })
  elseif logicview.truth(logicview.eq(bitnum, self.dlc_start)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.dlc_start, 3))) then
    self.dlc = bitpack_msb(logicview.slice(self.bits, self.dlc_start, logicview.add(self.dlc_start, 4), nil))
    self:putb({ 10, { logicview.pymod("Data length code: %d", self.dlc), logicview.pymod("DLC: %d", self.dlc), logicview.pymod("%d", self.dlc) } })
    self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.dlc, 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.rtr_type, "remote")
  return _v
end)()) then
      self:putb({ 16, { "Data length code (DLC) != 0 is not allowed" } })
      self.dlc = 0
      self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    elseif logicview.truth((function()
  local _v
  _v = (self.dlc > 8)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.fd))
  return _v
end)()) then
      self:putb({ 16, { "CAN Data length code (DLC) > 8 is not allowed" } })
      self.dlc = 8
      self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(logicview.add(self.dlc_start, 4), self.last_databit) do _t[#_t + 1] = _v end; return _t end)(), bitnum)) then
    _table.insert(self.ss_databytebits, self.samplenum)
  elseif logicview.truth(logicview.eq(bitnum, self.last_databit)) then
    _table.insert(self.ss_databytebits, self.samplenum)
    for _lv_i in logicview.range(dlc2len(self.dlc)) do
      i = _lv_i
      x = logicview.add(logicview.add(self.dlc_start, 4), logicview.mul(8, i))
      b = bitpack_msb(logicview.slice(self.bits, x, logicview.add(x, 8), nil))
      _table.insert(self.frame_bytes, b)
      ss = logicview.idx(self.ss_databytebits, logicview.mul(i, 8))
      es = logicview.idx(self.ss_databytebits, (logicview.mul(logicview.add(i, 1), 8) - 1))
      self:putg(ss, es, { 0, { logicview.pymod("Data byte %d: 0x%02x", { i, b }), logicview.pymod("DB %d: 0x%02x", { i, b }), logicview.pymod("0x%02x", b) } })
      ::continue_4::
    end
    self.ss_databytebits = {  }
  elseif logicview.truth((bitnum > self.last_databit)) then
    return self:decode_frame_end(can_rx, bitnum)
  end
  return false
end
function _decoder.decode_extended_frame(self, can_rx, bitnum)
  local s, rtr, i, x, b, ss, es
  if logicview.truth(logicview.eq(bitnum, 14)) then
    self.ss_block = self.samplenum
    self.dlc_start = 35
  elseif logicview.truth(logicview.eq(bitnum, 31)) then
    self.eid = bitpack_msb(logicview.slice(self.bits, 14, nil, nil))
    s = logicview.pymod("%d (0x%x)", { self.eid, self.eid })
    self:putb({ 4, { logicview.pymod("Extended Identifier: %s", s), logicview.pymod("Extended ID: %s", s), "Extended ID", logicview.pymod("%s", s) } })
    self.fullid = ((self.ident << 18) | self.eid)
    s = logicview.pymod("%d (0x%x)", { self.fullid, self.fullid })
    self:putb({ 5, { logicview.pymod("Full Identifier: %s", s), logicview.pymod("Full ID: %s", s), logicview.pymod("%s", s) } })
    self:put12({ 9, { logicview.pymod("Substitute remote request: %d", logicview.idx(self.bits, 12)), logicview.pymod("SRR: %d", logicview.idx(self.bits, 12)), logicview.pymod("%d", logicview.idx(self.bits, 12)) } })
  end
  if logicview.truth(logicview.eq(bitnum, 32)) then
    self.ss_bit32 = self.samplenum
    self.rtr = can_rx
  elseif logicview.truth(logicview.eq(bitnum, 33)) then
    self.fd = (function() if logicview.truth(can_rx) then return true else return false end end)()
    self:putx({ 7, { logicview.pymod("Flexible data format: %d", can_rx), logicview.pymod("FDF: %d", can_rx), logicview.pymod("%d", can_rx) } })
    if logicview.truth(self.fd) then
      self:put32({ 7, { logicview.pymod("Remote requset substituion: %d", self.rtr), logicview.pymod("RRS: %d", self.rtr), logicview.pymod("%d", self.rtr) } })
      self.dlc_start = 37
    else
      rtr = (function() if logicview.truth(logicview.eq(self.rtr, 1)) then return "remote" else return "data" end end)()
      self.rtr_type = rtr
      self:put32({ 8, { logicview.pymod("Remote transmission request: %s frame", rtr), logicview.pymod("RTR: %s frame", rtr), logicview.pymod("%s", rtr) } })
      self.dlc_start = 35
    end
  elseif logicview.truth(logicview.eq(bitnum, 34)) then
    self:putx({ 7, { logicview.pymod("Reserved bit 0: %d", can_rx), logicview.pymod("RB0: %d", can_rx), logicview.pymod("%d", can_rx) } })
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(bitnum, 35)
  if not logicview.truth(_v) then return _v end
  _v = self.fd
  return _v
end)()) then
    self:putx({ 7, { logicview.pymod("Bit rate switch: %d", can_rx), logicview.pymod("BRS: %d", can_rx), logicview.pymod("%d", can_rx) } })
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(bitnum, 36)
  if not logicview.truth(_v) then return _v end
  _v = self.fd
  return _v
end)()) then
    self:putx({ 7, { logicview.pymod("Error state indicator: %d", can_rx), logicview.pymod("ESI: %d", can_rx), logicview.pymod("%d", can_rx) } })
  elseif logicview.truth(logicview.eq(bitnum, self.dlc_start)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.dlc_start, 3))) then
    self.dlc = bitpack_msb(logicview.slice(self.bits, self.dlc_start, logicview.add(self.dlc_start, 4), nil))
    self:putb({ 10, { logicview.pymod("Data length code: %d", self.dlc), logicview.pymod("DLC: %d", self.dlc), logicview.pymod("%d", self.dlc) } })
    self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.dlc, 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.rtr_type, "remote")
  return _v
end)()) then
      self.dlc = 0
      self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    elseif logicview.truth((function()
  local _v
  _v = (self.dlc > 8)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.fd))
  return _v
end)()) then
      self.dlc = 8
      self.last_databit = logicview.add(logicview.add(self.dlc_start, 3), logicview.mul(dlc2len(self.dlc), 8))
    end
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(logicview.add(self.dlc_start, 4), self.last_databit) do _t[#_t + 1] = _v end; return _t end)(), bitnum)) then
    _table.insert(self.ss_databytebits, self.samplenum)
  elseif logicview.truth(logicview.eq(bitnum, self.last_databit)) then
    _table.insert(self.ss_databytebits, self.samplenum)
    for _lv_i in logicview.range(dlc2len(self.dlc)) do
      i = _lv_i
      x = logicview.add(logicview.add(self.dlc_start, 4), logicview.mul(8, i))
      b = bitpack_msb(logicview.slice(self.bits, x, logicview.add(x, 8), nil))
      _table.insert(self.frame_bytes, b)
      ss = logicview.idx(self.ss_databytebits, logicview.mul(i, 8))
      es = logicview.idx(self.ss_databytebits, (logicview.mul(logicview.add(i, 1), 8) - 1))
      self:putg(ss, es, { 0, { logicview.pymod("Data byte %d: 0x%02x", { i, b }), logicview.pymod("DB %d: 0x%02x", { i, b }), logicview.pymod("0x%02x", b) } })
      ::continue_5::
    end
    self.ss_databytebits = {  }
  elseif logicview.truth((bitnum > self.last_databit)) then
    return self:decode_frame_end(can_rx, bitnum)
  end
  return false
end
function _decoder.handle_bit(self, can_rx)
  local bitnum, s, ide, done
  _table.insert(self.rawbits, can_rx)
  _table.insert(self.bits, can_rx)
  bitnum = (logicview.len(self.bits) - 1)
  if logicview.truth((function()
  local _v
  _v = self.fd
  if not logicview.truth(_v) then return _v end
  _v = can_rx
  return _v
end)()) then
    if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(bitnum, 16)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.frame_type, "standard")
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(bitnum, 35)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.frame_type, "extended")
  return _v
end)()
  return _v
end)()) then
      self:dom_edge_seen()
      self:set_fast_bitrate()
    end
  end
  if logicview.truth(self:is_stuff_bit()) then
    self:putx({ 15, { _tostring(can_rx) } })
    self.curbit = logicview.add(self.curbit, 1)
    return
  else
    self:putx({ 17, { _tostring(can_rx) } })
  end
  if logicview.truth(logicview.eq(bitnum, 0)) then
    self.ss_packet = self.samplenum
    self:putx({ 1, { "Start of frame", "SOF", "S" } })
    if logicview.truth((not logicview.eq(can_rx, 0))) then
      self:putx({ 16, { "Start of frame (SOF) must be a dominant bit" } })
    end
  elseif logicview.truth(logicview.eq(bitnum, 1)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 11)) then
    self.ident = bitpack_msb(logicview.slice(self.bits, 1, nil, nil))
    self.fullid = self.ident
    s = { logicview.pymod("%d (0x%x)", { self.ident, self.ident }) }
    self:putb({ 3, { logicview.pymod("Identifier: %s", s), logicview.pymod("ID: %s", s), logicview.pymod("%s", s) } })
    if logicview.truth(logicview.eq((self.ident & 2032), 2032)) then
      self:putb({ 16, { "Identifier bits 10..4 must not be all recessive" } })
    end
  elseif logicview.truth(logicview.eq(bitnum, 12)) then
    self.ss_bit12 = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 13)) then
    do
      local _lv_chain = (function() if logicview.truth(logicview.eq(can_rx, 0)) then return "standard" else return "extended" end end)()
      ide = _lv_chain
      self.frame_type = _lv_chain
    end
    self:putx({ 6, { logicview.pymod("Identifier extension bit: %s frame", ide), logicview.pymod("IDE: %s frame", ide), logicview.pymod("%s", ide) } })
  elseif logicview.truth((bitnum >= 14)) then
    if logicview.truth(logicview.eq(self.frame_type, "standard")) then
      done = self:decode_standard_frame(can_rx, bitnum)
    else
      done = self:decode_extended_frame(can_rx, bitnum)
    end
    if logicview.truth(done) then
      return
    end
  end
  self.curbit = logicview.add(self.curbit, 1)
end
function _decoder.decode(self)
  local can_rx, pos
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        can_rx = logicview.idx(_lv_seq, 0)
      end
      self.sof = self.samplenum
      self:dom_edge_seen()
      self.state = "GET BITS"
    elseif logicview.truth(logicview.eq(self.state, "GET BITS")) then
      pos = self:get_sample_point(self.curbit)
      do
        local _lv_seq = self:wait({ logicview.dict({ skip = (pos - self.samplenum) }), logicview.dict({ [0] = "f" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        can_rx = logicview.idx(_lv_seq, 0)
      end
      if logicview.truth((self.matched & (1 << 1))) then
        self:dom_edge_seen()
      end
      if logicview.truth((self.matched & (1 << 0))) then
        self:handle_bit(can_rx)
      end
    end
    ::continue_6::
  end
end

return _decoder
