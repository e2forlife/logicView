-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Stephan Thiele <stephan.thiele@mailbox.org>

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
local Const, SamplerateError, Decoder
local _decoder

Const = {}
Const.__index = Const
Const.cChannelIdleDelimiter = 11
Const.cCrcInitA = 16702650
Const.cCrcInitB = 11259375
Const.cCrcPolynomial = 6122955
Const.cCrcSize = 24
Const.cCycleCountMax = 63
Const.cdBSS = 2
Const.cdCAS = 30
Const.cdFES = 2
Const.cdFSS = 1
Const.cHCrcInit = 26
Const.cHCrcPolynomial = 901
Const.cHCrcSize = 11
Const.cSamplesPerBit = 8
Const.cSlotIDMax = 2047
Const.cStaticSlotIDMax = 1023
Const.cVotingSamples = 5
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "flexray",
  name = "FlexRay",
  longname = "FlexRay",
  desc = "Automotive network communications protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Automotive" },
  channels = { logicview.dict({ id = "channel", name = "Channel", desc = "FlexRay bus channel" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "channel_type", desc = "Channel type", default = "A", values = { "A", "B" } }), logicview.dict({ id = "bitrate", desc = "Bitrate (bit/s)", default = 10000000, values = { 10000000, 5000000, 2500000 } }) },
  annotations = { { "data", "FlexRay payload data" }, { "tss", "Transmission start sequence" }, { "fss", "Frame start sequence" }, { "reserved-bit", "Reserved bit" }, { "ppi", "Payload preamble indicator" }, { "null-frame", "Nullframe indicator" }, { "sync-frame", "Full identifier" }, { "startup-frame", "Startup frame indicator" }, { "id", "Frame ID" }, { "length", "Data length" }, { "header-crc", "Header CRC" }, { "cycle", "Cycle code" }, { "data-byte", "Data byte" }, { "frame-crc", "Frame CRC" }, { "fes", "Frame end sequence" }, { "bss", "Byte start sequence" }, { "warning", "Warning" }, { "bit", "Bit" }, { "cid", "Channel idle delimiter" }, { "dts", "Dynamic trailing sequence" }, { "cas", "Collision avoidance symbol" } },
  annotation_rows = { { "bits", "Bits", { 15, 17 } }, { "fields", "Fields", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 18, 19, 20 } }, { "warnings", "Warnings", { 16 } } },
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
end
function _decoder.metadata(self, key, value)
  local bitrate
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    bitrate = (_tonumber(logicview.idx(self.options, "bitrate")) or 0)
    self.samplerate = value
    self.bit_width = ((_tonumber(self.samplerate) or 0) / bitrate)
    self.sample_point = logicview.mul((self.bit_width / 100.0), self.sample_point_percent)
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
function _decoder.putb(self, data)
  self:putg(self.ss_block, self.samplenum, data)
end
function _decoder.crc(data, data_len_bits, polynom, crc_len_bits, iv, xor)
  if iv == nil then iv = 0 end
  if xor == nil then xor = 0 end
  local reg, i, bit, mask, crc
  reg = (iv ~ xor)
  for _lv_i in logicview.range((data_len_bits - 1), (-1), (-1)) do
    i = _lv_i
    bit = (((reg >> (crc_len_bits - 1)) & 1) ~ ((data >> i) & 1))
    reg = (reg << 1)
    if logicview.truth(bit) then
      reg = (reg ~ polynom)
    end
    ::continue_1::
  end
  mask = ((1 << crc_len_bits) - 1)
  crc = (reg & mask)
  return (crc ~ xor)
end
function _decoder.reset_variables(self)
  self.sample_point_percent = 50
  self.state = "IDLE"
  do
    local _lv_chain = nil
    self.tss_start = _lv_chain
    self.tss_end = _lv_chain
    self.frame_type = _lv_chain
    self.dlc = _lv_chain
  end
  self.rawbits = {  }
  self.bits = {  }
  self.curbit = 0
  self.last_databit = 999
  self.last_xmit_bit = 999
  self.ss_block = nil
  self.ss_databytebits = {  }
  self.end_of_frame = false
  self.dynamic_frame = false
  self.ss_bit0 = nil
  self.ss_bit1 = nil
  self.ss_bit2 = nil
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
function _decoder.is_bss_sequence(self)
  if logicview.truth(self.end_of_frame) then
    return false
  end
  if logicview.truth(logicview.eq(logicview.pymod((logicview.len(self.rawbits) - 2), 10), 0)) then
    return true
  elseif logicview.truth(logicview.eq(logicview.pymod((logicview.len(self.rawbits) - 3), 10), 0)) then
    return true
  end
  return false
end
function _decoder.handle_bit(self, fr_rx)
  local bitnum, data_type, bits, header_to_check, expected_crc, crc_ok, crc_ann, i, x, b, ss, es, frame_to_check, iv
  _table.insert(self.rawbits, fr_rx)
  _table.insert(self.bits, fr_rx)
  bitnum = (logicview.len(self.bits) - 1)
  if logicview.truth(self:is_bss_sequence()) then
    logicview.list_pop(self.bits)
    if logicview.truth((bitnum > 1)) then
      self:putx({ 15, { _tostring(fr_rx) } })
    elseif logicview.truth(logicview.eq(logicview.len(self.rawbits), 2)) then
      self.ss_bit1 = self.samplenum
    elseif logicview.truth(logicview.eq(logicview.len(self.rawbits), 3)) then
      self.ss_bit2 = self.samplenum
    end
    self.curbit = logicview.add(self.curbit, 1)
    return
  elseif logicview.truth((bitnum > 1)) then
    self:putx({ 17, { _tostring(fr_rx) } })
  end
  if logicview.truth(logicview.eq(bitnum, 0)) then
    self.ss_bit0 = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 1)) then
    if logicview.truth(logicview.eq(logicview.slice(self.rawbits, nil, 3, nil), { 1, 1, 0 })) then
      self:put(self.tss_start, self.tss_end, self.out_ann, { 1, { "Transmission start sequence", "TSS" } })
      self:putg(self.ss_bit0, self.ss_bit0, { 17, { _tostring(logicview.idx(logicview.slice(self.rawbits, nil, 3, nil), 0)) } })
      self:putg(self.ss_bit0, self.ss_bit0, { 2, { "FSS", "Frame start sequence" } })
      self:putg(self.ss_bit1, self.ss_bit1, { 15, { _tostring(logicview.idx(logicview.slice(self.rawbits, nil, 3, nil), 1)) } })
      self:putg(self.ss_bit2, self.ss_bit2, { 15, { _tostring(logicview.idx(logicview.slice(self.rawbits, nil, 3, nil), 2)) } })
      self:putx({ 17, { _tostring(fr_rx) } })
      self:putx({ 3, { logicview.pymod("Reserved bit: %d", fr_rx), logicview.pymod("RB: %d", fr_rx), "RB" } })
    else
      self:put(self.tss_start, self.tss_end, self.out_ann, { 20, { "Collision avoidance symbol", "CAS" } })
      self:reset_variables()
    end
  elseif logicview.truth(logicview.eq(bitnum, 2)) then
    self:putx({ 4, { logicview.pymod("Payload preamble indicator: %d", fr_rx), logicview.pymod("PPI: %d", fr_rx) } })
  elseif logicview.truth(logicview.eq(bitnum, 3)) then
    data_type = (function() if logicview.truth(fr_rx) then return "data frame" else return "null frame" end end)()
    self:putx({ 5, { logicview.pymod("Null frame indicator: %s", data_type), logicview.pymod("NF: %d", fr_rx), "NF" } })
  elseif logicview.truth(logicview.eq(bitnum, 4)) then
    self:putx({ 6, { logicview.pymod("Sync frame indicator: %d", fr_rx), logicview.pymod("Sync: %d", fr_rx), "Sync" } })
  elseif logicview.truth(logicview.eq(bitnum, 5)) then
    self:putx({ 7, { logicview.pymod("Startup frame indicator: %d", fr_rx), logicview.pymod("Startup: %d", fr_rx), "Startup" } })
  elseif logicview.truth(logicview.eq(bitnum, 6)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 16)) then
    self.id = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 6, nil, nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
    self:putb({ 8, { logicview.pymod("Frame ID: %d", self.id), logicview.pymod("ID: %d", self.id), logicview.pymod("%d", self.id) } })
  elseif logicview.truth(logicview.eq(bitnum, 17)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 23)) then
    self.payload_length = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 17, nil, nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
    self:putb({ 9, { logicview.pymod("Payload length: %d", self.payload_length), logicview.pymod("Length: %d", self.payload_length), logicview.pymod("%d", self.payload_length) } })
  elseif logicview.truth(logicview.eq(bitnum, 24)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 34)) then
    bits = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 4, 24, nil)) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(b)
  end
  return _lv_out
end)())
    header_to_check = logicview.tointeger(bits, 2)
    expected_crc = self:crc(header_to_check, logicview.len(bits), Const.cHCrcPolynomial, Const.cHCrcSize, Const.cHCrcInit)
    self.header_crc = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 24, nil, nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
    crc_ok = logicview.eq(self.header_crc, expected_crc)
    crc_ann = (function() if logicview.truth(crc_ok) then return "OK" else return "bad" end end)()
    self:putb({ 10, { logicview.pymod("Header CRC: 0x%X (%s)", { self.header_crc, crc_ann }), logicview.pymod("0x%X (%s)", { self.header_crc, crc_ann }), logicview.pymod("0x%X", self.header_crc) } })
  elseif logicview.truth(logicview.eq(bitnum, 35)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, 40)) then
    self.cycle = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 35, nil, nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
    self:putb({ 11, { logicview.pymod("Cycle: %d", self.cycle), logicview.pymod("Cyc: %d", self.cycle), logicview.pymod("%d", self.cycle) } })
    self.last_databit = logicview.add(41, logicview.mul(logicview.mul(2, self.payload_length), 8))
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(41, self.last_databit) do _t[#_t + 1] = _v end; return _t end)(), bitnum)) then
    _table.insert(self.ss_databytebits, self.samplenum)
  elseif logicview.truth(logicview.eq(bitnum, self.last_databit)) then
    _table.insert(self.ss_databytebits, self.samplenum)
    for _lv_i in logicview.range(logicview.mul(2, self.payload_length)) do
      i = _lv_i
      x = logicview.add(logicview.add(40, logicview.mul(8, i)), 1)
      b = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, x, logicview.add(x, 8), nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
      ss = logicview.idx(self.ss_databytebits, logicview.mul(i, 8))
      es = logicview.idx(self.ss_databytebits, (logicview.mul(logicview.add(i, 1), 8) - 1))
      self:putg(ss, es, { 12, { logicview.pymod("Data byte %d: 0x%02x", { i, b }), logicview.pymod("DB%d: 0x%02x", { i, b }), logicview.pymod("%02X", b) } })
      ::continue_2::
    end
    self.ss_databytebits = {  }
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, 23))) then
    bits = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, 1, (-24), nil)) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(b)
  end
  return _lv_out
end)())
    frame_to_check = logicview.tointeger(bits, 2)
    iv = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "channel_type"), "A")) then return Const.cCrcInitA else return Const.cCrcInitB end end)()
    expected_crc = self:crc(frame_to_check, logicview.len(bits), Const.cCrcPolynomial, Const.cCrcSize)
    self.frame_crc = logicview.tointeger(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bits, self.last_databit, nil, nil)) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(d)
  end
  return _lv_out
end)()), 2)
    crc_ok = logicview.eq(self.frame_crc, expected_crc)
    crc_ann = (function() if logicview.truth(crc_ok) then return "OK" else return "bad" end end)()
    self:putb({ 13, { logicview.pymod("Frame CRC: 0x%X (%s)", { self.frame_crc, crc_ann }), logicview.pymod("0x%X (%s)", { self.frame_crc, crc_ann }), logicview.pymod("0x%X", self.frame_crc) } })
    self.end_of_frame = true
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, 24))) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, 25))) then
    self:putb({ 14, { "Frame end sequence", "FES" } })
  elseif logicview.truth(logicview.eq(bitnum, logicview.add(self.last_databit, 26))) then
    if logicview.truth((not logicview.truth(fr_rx))) then
      self.dynamic_frame = true
    else
      self.last_xmit_bit = bitnum
    end
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, self.last_xmit_bit)) then
    self.ss_block = self.samplenum
  elseif logicview.truth(logicview.eq(bitnum, (logicview.add(self.last_xmit_bit, Const.cChannelIdleDelimiter) - 1))) then
    self:putb({ 18, { "Channel idle delimiter", "CID" } })
    self:reset_variables()
  elseif logicview.truth((bitnum > logicview.add(self.last_databit, 27))) then
    if logicview.truth(self.dynamic_frame) then
      if logicview.truth(fr_rx) then
        if logicview.truth(logicview.eq(self.last_xmit_bit, 999)) then
          self:putb({ 19, { "Dynamic trailing sequence", "DTS" } })
          self.last_xmit_bit = logicview.add(bitnum, 1)
          self.ss_block = self.samplenum
        end
      end
    end
  end
  self.curbit = logicview.add(self.curbit, 1)
end
function _decoder.decode(self)
  local fr_rx, pos
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "l" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        fr_rx = logicview.idx(_lv_seq, 0)
      end
      self.tss_start = self.samplenum
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "h" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        fr_rx = logicview.idx(_lv_seq, 0)
      end
      self.tss_end = self.samplenum
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
        fr_rx = logicview.idx(_lv_seq, 0)
      end
      if logicview.truth((self.matched & 2)) then
        self:dom_edge_seen()
      end
      if logicview.truth((self.matched & 1)) then
        self:handle_bit(fr_rx)
      end
    end
    ::continue_3::
  end
end

return _decoder
