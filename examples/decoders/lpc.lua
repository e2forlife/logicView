-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2013 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>
-- Copyright (C) 2020 Raptor Engineering, LLC <support@raptorengineering.com>

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
local fields, Decoder
local _decoder

fields = logicview.dict({ START = logicview.dict({ [0] = "Start of cycle for a target", [1] = "Reserved", [2] = "Grant for bus master 0", [3] = "Grant for bus master 1", [4] = "Reserved", [5] = "TPM", [6] = "Reserved", [7] = "Reserved", [8] = "Reserved", [9] = "Reserved", [10] = "Reserved", [11] = "Reserved", [12] = "Reserved", [13] = "Start of cycle for a Firmware Memory Read cycle", [14] = "Start of cycle for a Firmware Memory Write cycle", [15] = "Stop/abort (end of a cycle for a target)" }), CT_DR = logicview.dict({ [0] = "I/O read", [1] = "I/O read", [2] = "I/O write", [3] = "I/O write", [4] = "Memory read", [5] = "Memory read", [6] = "Memory write", [7] = "Memory write", [8] = "DMA read", [9] = "DMA read", [10] = "DMA write", [11] = "DMA write", [12] = "Reserved / not allowed", [13] = "Reserved / not allowed", [14] = "Reserved / not allowed", [15] = "Reserved / not allowed" }), CT_DR_WR = logicview.dict({ [0] = false, [1] = false, [2] = true, [3] = true, [4] = false, [5] = false, [6] = true, [7] = true, [8] = false, [9] = false, [10] = true, [11] = true, [12] = false, [13] = false, [14] = false, [15] = false }), SIZE = logicview.dict({ [0] = "8 bits (1 byte)", [1] = "16 bits (2 bytes)", [2] = "Reserved / not allowed", [3] = "32 bits (4 bytes)" }), CHANNEL = logicview.dict({ [0] = "0", [1] = "1", [2] = "2", [3] = "3", [4] = "4", [5] = "5", [6] = "6", [7] = "7" }), SYNC = logicview.dict({ [0] = "Ready", [1] = "Reserved", [2] = "Reserved", [3] = "Reserved", [4] = "Reserved", [5] = "Short wait", [6] = "Long wait", [7] = "Reserved", [8] = "Reserved", [9] = "Ready more (DMA only)", [10] = "Error", [11] = "Reserved", [12] = "Reserved", [13] = "Reserved", [14] = "Reserved", [15] = "Reserved" }) })
_decoder = {
  api_version = 3,
  id = "lpc",
  name = "LPC",
  longname = "Low Pin Count",
  desc = "Protocol for low-bandwidth devices on PC mainboards.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PC" },
  channels = { logicview.dict({ id = "lframe", name = "LFRAME#", desc = "Frame" }), logicview.dict({ id = "lclk", name = "LCLK", desc = "Clock" }), logicview.dict({ id = "lad0", name = "LAD[0]", desc = "Addr/control/data 0" }), logicview.dict({ id = "lad1", name = "LAD[1]", desc = "Addr/control/data 1" }), logicview.dict({ id = "lad2", name = "LAD[2]", desc = "Addr/control/data 2" }), logicview.dict({ id = "lad3", name = "LAD[3]", desc = "Addr/control/data 3" }) },
  optional_channels = { logicview.dict({ id = "lreset", name = "LRESET#", desc = "Reset" }), logicview.dict({ id = "ldrq", name = "LDRQ#", desc = "Encoded DMA / bus master request" }), logicview.dict({ id = "serirq", name = "SERIRQ", desc = "Serialized IRQ" }), logicview.dict({ id = "clkrun", name = "CLKRUN#", desc = "Clock run" }), logicview.dict({ id = "lpme", name = "LPME#", desc = "LPC power management event" }), logicview.dict({ id = "lpcpd", name = "LPCPD#", desc = "Power down" }), logicview.dict({ id = "lsmi", name = "LSMI#", desc = "System Management Interrupt" }) },
  options = {  },
  annotations = { { "warnings", "Warnings" }, { "start", "Start" }, { "cycle-type", "Cycle-type/direction" }, { "addr", "Address" }, { "tar1", "Turn-around cycle 1" }, { "sync", "Sync" }, { "timeout", "Time Out" }, { "data", "Data" }, { "tar2", "Turn-around cycle 2" } },
  annotation_rows = { { "data", "Data", { 1, 2, 3, 4, 5, 6, 7, 8 } }, { "warnings", "Warnings", { 0 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.oldlclk = (-1)
  self.samplenum = 0
  self.lad = (-1)
  self.addr = 0
  self.direction = 0
  self.cur_nibble = 0
  self.cycle_type = (-1)
  self.databyte = 0
  self.tarcount = 0
  self.synccount = 0
  self.timeoutcount = 0
  self.oldpins = nil
  do
    local _lv_chain = nil
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
  self.oldlframe = (-1)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.handle_get_start(self, lframe)
  self.es_block = self.samplenum
  self:putb({ 1, { logicview.idx(logicview.idx(fields, "START"), self.oldlad), "START", "St", "S" } })
  self.ss_block = self.samplenum
  if logicview.truth((not logicview.eq(lframe, 1))) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.oldlad, 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oldlad, 5)
  return _v
end)()) then
    self.start_field = self.oldlad
    self.state = "GET CT/DR"
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.oldlad, 13)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oldlad, 14)
  return _v
end)()) then
    self.start_field = self.oldlad
    if logicview.truth(logicview.eq(self.oldlad, 14)) then
      self.direction = true
    else
      self.direction = false
    end
    self.state = "GET FW IDSEL"
  else
    self.state = "IDLE"
  end
end
function _decoder.handle_get_ct_dr(self)
  self.cycle_type = logicview.idx(logicview.idx(fields, "CT_DR"), self.oldlad)
  self.direction = logicview.idx(logicview.idx(fields, "CT_DR_WR"), self.oldlad)
  if logicview.truth(logicview.eq(self.cycle_type, "Reserved")) then
    self:putb({ 0, { logicview.pymod("Invalid cycle type (%s)", self.oldlad_bits) } })
  end
  self.es_block = self.samplenum
  self:putb({ 2, { logicview.pymod("Cycle type: %s", self.cycle_type) } })
  self.ss_block = self.samplenum
  self.state = "GET ADDR"
  self.addr = 0
  self.cur_nibble = 0
end
function _decoder.handle_get_fw_idsel(self)
  local s
  self.es_block = self.samplenum
  s = logicview.pymod("IDSEL: 0x%%0%dx", self.oldlad)
  self:putb({ 3, { logicview.pymod(s, self.oldlad) } })
  self.ss_block = self.samplenum
  self.state = "GET FW ADDR"
  self.addr = 0
  self.cur_nibble = 0
end
function _decoder.handle_get_fw_addr(self)
  local addr_nibbles, offset, s
  addr_nibbles = 7
  offset = logicview.mul(((addr_nibbles - 1) - self.cur_nibble), 4)
  if logicview.truth((offset < 0)) then
    self:putb({ 0, { logicview.pymod("Warning: Invalid address shift: %d", offset) } })
    self.state = "IDLE"
    return
  end
  self.addr = (self.addr | (self.oldlad << offset))
  if logicview.truth((self.cur_nibble < (addr_nibbles - 1))) then
    self.cur_nibble = logicview.add(self.cur_nibble, 1)
    return
  end
  self.es_block = self.samplenum
  s = logicview.pymod("Address: 0x%%0%dx", addr_nibbles)
  self:putb({ 3, { logicview.pymod(s, self.addr) } })
  self.ss_block = self.samplenum
  self.state = "GET FW MSIZE"
end
function _decoder.handle_get_fw_msize(self)
  local s
  self.es_block = self.samplenum
  s = logicview.pymod("MSIZE: 0x%%0%dx", self.oldlad)
  self:putb({ 3, { logicview.pymod(s, self.oldlad) } })
  self.ss_block = self.samplenum
  self.msize = self.oldlad
  if logicview.truth(logicview.eq(self.direction, 1)) then
    self.state = "GET FW DATA"
    self.cycle_count = 0
    self.dataword = 0
    self.cur_nibble = 0
  else
    self.state = "GET TAR"
    self.tar_count = 0
  end
end
function _decoder.handle_get_addr(self)
  local addr_nibbles, offset, s
  if logicview.truth(logicview.contains({ "I/O read", "I/O write" }, self.cycle_type)) then
    addr_nibbles = 4
  elseif logicview.truth(logicview.contains({ "Memory read", "Memory write" }, self.cycle_type)) then
    addr_nibbles = 8
  else
    addr_nibbles = 0
  end
  offset = logicview.mul(((addr_nibbles - 1) - self.cur_nibble), 4)
  if logicview.truth((offset < 0)) then
    self:putb({ 0, { logicview.pymod("Warning: Invalid address shift: %d", offset) } })
    self.state = "IDLE"
    return
  end
  self.addr = (self.addr | (self.oldlad << offset))
  if logicview.truth((self.cur_nibble < (addr_nibbles - 1))) then
    self.cur_nibble = logicview.add(self.cur_nibble, 1)
    return
  end
  self.es_block = self.samplenum
  s = logicview.pymod("Address: 0x%%0%dx", addr_nibbles)
  self:putb({ 3, { logicview.pymod(s, self.addr) } })
  self.ss_block = self.samplenum
  if logicview.truth(logicview.eq(self.direction, 1)) then
    self.state = "GET DATA"
    self.cycle_count = 0
  else
    self.state = "GET TAR"
    self.tar_count = 0
  end
end
function _decoder.handle_get_tar(self)
  self.es_block = self.samplenum
  self:putb({ 4, { logicview.pymod("TAR, cycle %d: %s", { self.tarcount, self.oldlad_bits }) } })
  self.ss_block = self.samplenum
  if logicview.truth((not logicview.eq(self.oldlad_bits, "1111"))) then
    self:putb({ 0, { logicview.pymod("TAR, cycle %d: %s (expected 1111)", { self.tarcount, self.oldlad_bits }) } })
  end
  if logicview.truth((not logicview.eq(self.tarcount, 1))) then
    self.tarcount = logicview.add(self.tarcount, 1)
    return
  end
  self.tarcount = 0
  self.state = "GET SYNC"
end
function _decoder.handle_get_sync(self, lframe)
  self.sync_val = self.oldlad_bits
  self.cycle_type = logicview.idx(logicview.idx(fields, "SYNC"), self.oldlad)
  self.es_block = self.samplenum
  if logicview.truth(logicview.eq(self.cycle_type, "Reserved")) then
    self:putb({ 0, { logicview.pymod("SYNC, cycle %d: %s (reserved value)", { self.synccount, self.sync_val }) } })
  end
  self.es_block = self.samplenum
  self:putb({ 5, { logicview.pymod("SYNC, cycle %d: %s", { self.synccount, self.sync_val }) } })
  self.ss_block = self.samplenum
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.cycle_type, "Short wait"))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.cycle_type, "Long wait"))
  return _v
end)()) then
    self.cycle_count = 0
    if logicview.truth(logicview.eq(lframe, 0)) then
      self.state = "GET TIMEOUT"
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.start_field, 13)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.start_field, 14)
  return _v
end)()) then
      self.state = "GET FW DATA"
      self.cycle_count = 0
      self.dataword = 0
      self.cur_nibble = 0
    else
      self.state = "GET DATA"
    end
  end
end
function _decoder.handle_get_timeout(self)
  if logicview.truth((not logicview.eq(self.oldlframe, 0))) then
    self:putb({ 0, { "TIMEOUT cycle, LFRAME# must be low for 4 LCLk cycles" } })
    self.timeoutcount = 0
    self.state = "IDLE"
    return
  end
  self.es_block = self.samplenum
  self:putb({ 6, { logicview.pymod("Timeout %d", self.timeoutcount) } })
  self.ss_block = self.samplenum
  if logicview.truth((not logicview.eq(self.timeoutcount, 3))) then
    self.timeoutcount = logicview.add(self.timeoutcount, 1)
    return
  end
  self.timeoutcount = 0
  self.state = "IDLE"
end
function _decoder.handle_get_fw_data(self)
  local data_nibbles, nibble_swap, offset, s
  if logicview.truth(logicview.eq(self.msize, 0)) then
    data_nibbles = 2
  elseif logicview.truth(logicview.eq(self.msize, 1)) then
    data_nibbles = 4
  elseif logicview.truth(logicview.eq(self.msize, 2)) then
    data_nibbles = 8
  elseif logicview.truth(logicview.eq(self.msize, 4)) then
    data_nibbles = 32
  elseif logicview.truth(logicview.eq(self.msize, 7)) then
    data_nibbles = 256
  else
    self:putb({ 0, { logicview.pymod("Warning: Invalid MSIZE: %d", self.msize) } })
    self.state = "IDLE"
    return
  end
  nibble_swap = logicview.pymod(self.cur_nibble, 2)
  offset = logicview.mul(((data_nibbles - 1) - self.cur_nibble), 4)
  if logicview.truth(nibble_swap) then
    offset = logicview.add(offset, 4)
  else
    offset = (offset - 4)
  end
  if logicview.truth((offset < 0)) then
    self:putb({ 0, { logicview.pymod("Warning: Invalid data shift: %d", offset) } })
    self.state = "IDLE"
    return
  end
  self.dataword = (self.dataword | (self.oldlad << offset))
  if logicview.truth((self.cur_nibble < (data_nibbles - 1))) then
    self.cur_nibble = logicview.add(self.cur_nibble, 1)
    return
  end
  self.es_block = self.samplenum
  s = logicview.pymod("DATA: 0x%%0%dx", data_nibbles)
  self:putb({ 3, { logicview.pymod(s, self.dataword) } })
  self.ss_block = self.samplenum
  self.cycle_count = 0
  self.state = "GET TAR2"
end
function _decoder.handle_get_data(self)
  if logicview.truth(logicview.eq(self.cycle_count, 0)) then
    self.databyte = self.oldlad
  elseif logicview.truth(logicview.eq(self.cycle_count, 1)) then
    self.databyte = (self.databyte | (self.oldlad << 4))
  else
    self:putb({ 0, { logicview.pymod("Warning: Invalid cycle_count: %d", self.cycle_count) } })
    self.state = "IDLE"
    return
  end
  if logicview.truth((not logicview.eq(self.cycle_count, 1))) then
    self.cycle_count = logicview.add(self.cycle_count, 1)
    return
  end
  self.es_block = self.samplenum
  self:putb({ 7, { logicview.pymod("DATA: 0x%02x", self.databyte) } })
  self.ss_block = self.samplenum
  self.cycle_count = 0
  self.state = "GET TAR2"
end
function _decoder.handle_get_tar2(self)
  self.es_block = self.samplenum
  self:putb({ 8, { logicview.pymod("TAR, cycle %d: %s", { self.tarcount, self.oldlad_bits }) } })
  self.ss_block = self.samplenum
  if logicview.truth((not logicview.eq(self.oldlad_bits, "1111"))) then
    self:putb({ 0, { logicview.pymod("Warning: TAR, cycle %d: %s (expected 1111)", { self.tarcount, self.oldlad_bits }) } })
  end
  if logicview.truth((not logicview.eq(self.tarcount, 1))) then
    self.tarcount = logicview.add(self.tarcount, 1)
    return
  end
  self.tarcount = 0
  self.state = "IDLE"
end
function _decoder.decode(self)
  local lframe, lclk, lad0, lad1, lad2, lad3, lreset, ldrq, serirq, clkrun, lpme, lpcpd, lsmi, lad, lad_bits
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [1] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      lframe = logicview.idx(_lv_seq, 0)
      lclk = logicview.idx(_lv_seq, 1)
      lad0 = logicview.idx(_lv_seq, 2)
      lad1 = logicview.idx(_lv_seq, 3)
      lad2 = logicview.idx(_lv_seq, 4)
      lad3 = logicview.idx(_lv_seq, 5)
      lreset = logicview.idx(_lv_seq, 6)
      ldrq = logicview.idx(_lv_seq, 7)
      serirq = logicview.idx(_lv_seq, 8)
      clkrun = logicview.idx(_lv_seq, 9)
      lpme = logicview.idx(_lv_seq, 10)
      lpcpd = logicview.idx(_lv_seq, 11)
      lsmi = logicview.idx(_lv_seq, 12)
    end
    lad = ((((lad3 << 3) | (lad2 << 2)) | (lad1 << 1)) | lad0)
    lad_bits = logicview.pyformat("{:04b}", { lad }, logicview.dict({}))
    if logicview.truth((function()
  local _v
  _v = logicview.eq(lframe, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.oldlframe, 0)
  return _v
end)()) then
      self.state = "GET TIMEOUT"
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(logicview.eq(lframe, 0)) then
        self.ss_block = self.samplenum
        self.state = "GET START"
        self.lad = (-1)
      else
        self:wait(logicview.dict({ [0] = "f" }))
      end
    elseif logicview.truth(logicview.eq(self.state, "GET START")) then
      self:handle_get_start(lframe)
    elseif logicview.truth(logicview.eq(self.state, "GET CT/DR")) then
      self:handle_get_ct_dr()
    elseif logicview.truth(logicview.eq(self.state, "GET ADDR")) then
      self:handle_get_addr()
    elseif logicview.truth(logicview.eq(self.state, "GET FW IDSEL")) then
      self:handle_get_fw_idsel()
    elseif logicview.truth(logicview.eq(self.state, "GET FW ADDR")) then
      self:handle_get_fw_addr()
    elseif logicview.truth(logicview.eq(self.state, "GET FW MSIZE")) then
      self:handle_get_fw_msize()
    elseif logicview.truth(logicview.eq(self.state, "GET TAR")) then
      self:handle_get_tar()
    elseif logicview.truth(logicview.eq(self.state, "GET SYNC")) then
      self:handle_get_sync(lframe)
    elseif logicview.truth(logicview.eq(self.state, "GET TIMEOUT")) then
      self:handle_get_timeout()
    elseif logicview.truth(logicview.eq(self.state, "GET FW DATA")) then
      self:handle_get_fw_data()
    elseif logicview.truth(logicview.eq(self.state, "GET DATA")) then
      self:handle_get_data()
    elseif logicview.truth(logicview.eq(self.state, "GET TAR2")) then
      self:handle_get_tar2()
    end
    self.oldlframe = lframe
    self.oldlad = lad
    self.oldlad_bits = lad_bits
    ::continue_1::
  end
end

return _decoder
