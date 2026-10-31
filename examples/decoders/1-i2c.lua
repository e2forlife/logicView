-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2010-2016 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2022 DreamSourceLab <support@dreamsourcelab.com>

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
local proto, Decoder
local _decoder

proto = logicview.dict({ START = { 0, "Start", "S" }, ["START REPEAT"] = { 1, "Start repeat", "Sr" }, STOP = { 2, "Stop", "P" }, ACK = { 3, "ACK", "A" }, NACK = { 4, "NACK", "N" }, BIT = { 5, "Bit", "B" }, ["ADDRESS READ"] = { 6, "Address read", "AR" }, ["ADDRESS WRITE"] = { 7, "Address write", "AW" }, ["DATA READ"] = { 8, "Data read", "DR" }, ["DATA WRITE"] = { 9, "Data write", "DW" } })
_decoder = {
  api_version = 3,
  id = "1:i2c",
  name = "1:I²C",
  longname = "Inter-Integrated Circuit",
  desc = "Two-wire, multi-master, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "i2c" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "scl", name = "SCL", desc = "Serial clock line" }), logicview.dict({ id = "sda", name = "SDA", desc = "Serial data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "address_format", desc = "Displayed slave address format", default = "unshifted", values = { "shifted", "unshifted" } }) },
  annotations = { { "7", "start", "Start condition" }, { "6", "repeat-start", "Repeat start condition" }, { "1", "stop", "Stop condition" }, { "5", "ack", "ACK" }, { "0", "nack", "NACK" }, { "208", "bit", "Data/address bit" }, { "112", "address-read", "Address read" }, { "111", "address-write", "Address write" }, { "110", "data-read", "Data read" }, { "109", "data-write", "Data write" }, { "1000", "warnings", "Human-readable warnings" } },
  annotation_rows = { { "bits", "Bits", { 5 } }, { "addr-data", "Address/Data", { 0, 1, 2, 3, 4, 6, 7, 8, 9 } }, { "warnings", "Warnings", { 10 } } },
  binary = { { "address-read", "Address read" }, { "address-write", "Address write" }, { "data-read", "Data read" }, { "data-write", "Data write" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_chain = (-1)
    self.ss = _lv_chain
    self.es = _lv_chain
    self.ss_byte = _lv_chain
  end
  self.bitcount = 0
  self.databyte = 0
  self.wr = (-1)
  self.is_repeat_start = 0
  self.state = "FIND START"
  self.pdu_start = nil
  self.pdu_bits = 0
  self.bits = {  }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_bitrate = self:register(logicview.OUTPUT_META, "Bitrate")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putp(self, data)
  self:put(self.ss, self.es, self.out_python, data)
end
function _decoder.putb(self, data)
  self:put(self.ss, self.es, self.out_binary, data)
end
function _decoder.handle_start(self)
  local cmd
  do
    local _lv_a0, _lv_a1 = self.samplenum, self.samplenum
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self.pdu_start = self.samplenum
  self.pdu_bits = 0
  cmd = (function() if logicview.truth(logicview.eq(self.is_repeat_start, 1)) then return "START REPEAT" else return "START" end end)()
  self:putp({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = "FIND ADDRESS"
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  self.is_repeat_start = 1
  self.wr = (-1)
  self.bits = {  }
end
function _decoder.handle_address_or_data(self, scl, sda)
  local d, bin_class, cmd, bit, w
  self.pdu_bits = logicview.add(self.pdu_bits, 1)
  self.databyte = (self.databyte << 1)
  self.databyte = (self.databyte | sda)
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.ss_byte = self.samplenum
  end
  logicview.list_insert(self.bits, 0, { sda, self.samplenum, self.samplenum })
  if logicview.truth((self.bitcount > 0)) then
    logicview.setidx(logicview.idx(self.bits, 1), 2, self.samplenum)
  end
  if logicview.truth(logicview.eq(self.bitcount, 7)) then
    self.bitwidth = (logicview.idx(logicview.idx(self.bits, 1), 2) - logicview.idx(logicview.idx(self.bits, 2), 2))
    logicview.setidx(logicview.idx(self.bits, 0), 2, logicview.add(logicview.idx(logicview.idx(self.bits, 0), 2), self.bitwidth))
  end
  if logicview.truth((self.bitcount < 7)) then
    self.bitcount = logicview.add(self.bitcount, 1)
    return
  end
  d = self.databyte
  if logicview.truth(logicview.eq(self.state, "FIND ADDRESS")) then
    self.wr = (function() if logicview.truth((self.databyte & 1)) then return 0 else return 1 end end)()
    if logicview.truth(logicview.eq(logicview.idx(self.options, "address_format"), "shifted")) then
      d = (d >> 1)
    end
  end
  bin_class = (-1)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "FIND ADDRESS")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.wr, 1)
  return _v
end)()) then
    cmd = "ADDRESS WRITE"
    bin_class = 1
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "FIND ADDRESS")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.wr, 0)
  return _v
end)()) then
    cmd = "ADDRESS READ"
    bin_class = 0
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "FIND DATA")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.wr, 1)
  return _v
end)()) then
    cmd = "DATA WRITE"
    bin_class = 3
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "FIND DATA")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.wr, 0)
  return _v
end)()) then
    cmd = "DATA READ"
    bin_class = 2
  end
  do
    local _lv_a0, _lv_a1 = self.ss_byte, logicview.add(self.samplenum, self.bitwidth)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self:putp({ "BITS", self.bits })
  self:putp({ cmd, d })
  self:putb({ bin_class, logicview.bytes({ d }) })
  for _lv_item in logicview.iter(self.bits) do
    bit = _lv_item
    self:put(logicview.idx(bit, 1), logicview.idx(bit, 2), self.out_ann, { 5, { logicview.pymod("%d", logicview.idx(bit, 0)) } })
    ::continue_1::
  end
  if logicview.truth(logicview.startswith(cmd, "ADDRESS")) then
    do
      local _lv_a0, _lv_a1 = self.samplenum, logicview.add(self.samplenum, self.bitwidth)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    w = (function() if logicview.truth(self.wr) then return { "Write", "Wr", "W" } else return { "Read", "Rd", "R" } end end)()
    self:putx({ 0, w })
    do
      local _lv_a0, _lv_a1 = self.ss_byte, self.samplenum
      self.ss = _lv_a0
      self.es = _lv_a1
    end
  end
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), { logicview.pymod("%s: {$}", logicview.idx(logicview.idx(proto, cmd), 1)), logicview.pymod("%s: {$}", logicview.idx(logicview.idx(proto, cmd), 2)), "{$}", d } })
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  self.bits = {  }
  self.state = "FIND ACK"
end
function _decoder.get_ack(self, scl, sda)
  local cmd
  do
    local _lv_a0, _lv_a1 = self.samplenum, logicview.add(self.samplenum, self.bitwidth)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  cmd = (function() if logicview.truth(logicview.eq(sda, 1)) then return "NACK" else return "ACK" end end)()
  self:putp({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = "FIND DATA"
end
function _decoder.handle_stop(self)
  local elapsed, bitrate, cmd
  if logicview.truth(self.samplerate) then
    elapsed = logicview.mul((1 / (_tonumber(self.samplerate) or 0)), logicview.add((self.samplenum - self.pdu_start), 1))
    bitrate = logicview.tointeger(logicview.mul((1 / elapsed), self.pdu_bits))
    self:put(self.ss_byte, self.samplenum, self.out_bitrate, bitrate)
  end
  cmd = "STOP"
  do
    local _lv_a0, _lv_a1 = self.samplenum, self.samplenum
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self:putp({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = "FIND START"
  self.is_repeat_start = 0
  self.wr = (-1)
  self.bits = {  }
end
function _decoder.decode(self)
  local scl, sda
  while true do
    if logicview.truth(logicview.eq(self.state, "FIND START")) then
      self:wait(logicview.dict({ [0] = "h", [1] = "f" }))
      self:handle_start()
    elseif logicview.truth(logicview.eq(self.state, "FIND ADDRESS")) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "r" }), logicview.dict({ [0] = "h", [1] = "f" }), logicview.dict({ [0] = "h", [1] = "r" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        scl = logicview.idx(_lv_seq, 0)
        sda = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((self.matched & (1 << 0))) then
        self:handle_address_or_data(scl, sda)
      elseif logicview.truth((self.matched & (1 << 1))) then
        self:handle_start()
      elseif logicview.truth((self.matched & (1 << 2))) then
        self:handle_stop()
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND DATA")) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "r" }), logicview.dict({ [0] = "h", [1] = "f" }), logicview.dict({ [0] = "h", [1] = "r" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        scl = logicview.idx(_lv_seq, 0)
        sda = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((self.matched & (1 << 0))) then
        self:handle_address_or_data(scl, sda)
      elseif logicview.truth((self.matched & (1 << 1))) then
        self:handle_start()
      elseif logicview.truth((self.matched & (1 << 2))) then
        self:handle_stop()
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND ACK")) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "r" }), logicview.dict({ [0] = "h", [1] = "r" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        scl = logicview.idx(_lv_seq, 0)
        sda = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((self.matched & (1 << 0))) then
        self:get_ack(scl, sda)
      elseif logicview.truth((self.matched & (1 << 1))) then
        self:handle_stop()
      end
    end
    ::continue_2::
  end
end

return _decoder
