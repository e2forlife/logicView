-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Iztok Jeras <iztok.jeras@gmail.com>

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
local command, Decoder
local _decoder

command = logicview.dict({ [51] = { "Read ROM", "GET ROM" }, [15] = { "Conditional read ROM", "GET ROM" }, [204] = { "Skip ROM", "TRANSPORT" }, [85] = { "Match ROM", "GET ROM" }, [240] = { "Search ROM", "SEARCH ROM" }, [236] = { "Conditional search ROM", "SEARCH ROM" }, [60] = { "Overdrive skip ROM", "TRANSPORT" }, [105] = { "Overdrive match ROM", "GET ROM" }, [165] = { "Resume", "TRANSPORT" }, [150] = { "DS2408: Disable Test Mode", "GET ROM" } })
_decoder = {
  api_version = 3,
  id = "onewire_network",
  name = "1-Wire network layer",
  longname = "1-Wire serial communication bus (network layer)",
  desc = "Bidirectional, half-duplex, asynchronous serial bus.",
  license = "gplv2+",
  inputs = { "onewire_link" },
  outputs = { "onewire_network" },
  tags = { "Embedded/industrial" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text", "Human-readable text" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.ss_block = 0
  self.es_block = 0
  self.state = "COMMAND"
  self.bit_cnt = 0
  self.search = "P"
  self.data_p = 0
  self.data_n = 0
  self.data = 0
  self.rom = 0
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.puty(self, data)
  self:put(self.ss_block, self.es_block, self.out_python, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local code, val
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      code = logicview.idx(_lv_seq, 0)
      val = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(code, "RESET/PRESENCE")) then
      self.search = "P"
      self.bit_cnt = 0
      self:put(ss, es, self.out_ann, { 0, { logicview.pymod("Reset/presence: %s", (function() if logicview.truth(val) then return "true" else return "false" end end)()) } })
      self:put(ss, es, self.out_python, { "RESET/PRESENCE", val })
      self.state = "COMMAND"
      return
    end
    if logicview.truth((not logicview.eq(code, "BIT"))) then
      return
    end
    if logicview.truth(logicview.eq(self.state, "COMMAND")) then
      if logicview.truth(logicview.eq(self:onewire_collect(8, val, ss, es), 0)) then
        return
      end
      if logicview.truth(logicview.contains(command, self.data)) then
        self:putx({ 0, { logicview.pymod("ROM command: 0x%02x '%s'", { self.data, logicview.idx(logicview.idx(command, self.data), 0) }) } })
        self.state = logicview.idx(logicview.idx(command, self.data), 1)
      else
        self:putx({ 0, { logicview.pymod("ROM command: 0x%02x '%s'", { self.data, "unrecognized" }) } })
        self.state = "COMMAND ERROR"
      end
    elseif logicview.truth(logicview.eq(self.state, "GET ROM")) then
      if logicview.truth(logicview.eq(self:onewire_collect(64, val, ss, es), 0)) then
        return
      end
      self.rom = (self.data & 1.8446744073709552e+19)
      self:putx({ 0, { logicview.pymod("ROM: 0x%016x", self.rom) } })
      self:puty({ "ROM", self.rom })
      self.state = "TRANSPORT"
    elseif logicview.truth(logicview.eq(self.state, "SEARCH ROM")) then
      if logicview.truth(logicview.eq(self:onewire_search(64, val, ss, es), 0)) then
        return
      end
      self.rom = (self.data & 1.8446744073709552e+19)
      self:putx({ 0, { logicview.pymod("ROM: 0x%016x", self.rom) } })
      self:puty({ "ROM", self.rom })
      self.state = "TRANSPORT"
    elseif logicview.truth(logicview.eq(self.state, "TRANSPORT")) then
      if logicview.truth(logicview.eq(self:onewire_collect(8, val, ss, es), 0)) then
        return
      end
      self:putx({ 0, { logicview.pymod("Data: 0x%02x", self.data) } })
      self:puty({ "DATA", self.data })
    elseif logicview.truth(logicview.eq(self.state, "COMMAND ERROR")) then
      if logicview.truth(logicview.eq(self:onewire_collect(8, val, ss, es), 0)) then
        return
      end
      self:putx({ 0, { logicview.pymod("ROM error data: 0x%02x", self.data) } })
    end
  end
  if _type(packets) ~= 'table' then return _lv_packet(self, start_sample, end_sample, packets) end
  for _, _item in ipairs(packets) do
    local payload = _item.data
    if payload == nil then payload = _item end
    local ss = _item.start_sample or start_sample
    local es = _item.end_sample
    if es ~= nil then es = es - 1 end
    _lv_packet(self, ss, es, payload)
  end
end
function _decoder.onewire_collect(self, length, val, ss, es)
  if logicview.truth(logicview.eq(self.bit_cnt, 0)) then
    self.ss_block = ss
  end
  self.data = ((self.data & (~(1 << self.bit_cnt))) | (val << self.bit_cnt))
  self.bit_cnt = logicview.add(self.bit_cnt, 1)
  if logicview.truth(logicview.eq(self.bit_cnt, length)) then
    self.es_block = es
    self.data = (self.data & ((1 << length) - 1))
    self.bit_cnt = 0
    return 1
  else
    return 0
  end
end
function _decoder.onewire_search(self, length, val, ss, es)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.bit_cnt, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.search, "P")
  return _v
end)()) then
    self.ss_block = ss
  end
  if logicview.truth(logicview.eq(self.search, "P")) then
    self.data_p = ((self.data_p & (~(1 << self.bit_cnt))) | (val << self.bit_cnt))
    self.search = "N"
  elseif logicview.truth(logicview.eq(self.search, "N")) then
    self.data_n = ((self.data_n & (~(1 << self.bit_cnt))) | (val << self.bit_cnt))
    self.search = "D"
  elseif logicview.truth(logicview.eq(self.search, "D")) then
    self.data = ((self.data & (~(1 << self.bit_cnt))) | (val << self.bit_cnt))
    self.search = "P"
    self.bit_cnt = logicview.add(self.bit_cnt, 1)
  end
  if logicview.truth(logicview.eq(self.bit_cnt, length)) then
    self.es_block = es
    self.data_p = (self.data_p & ((1 << length) - 1))
    self.data_n = (self.data_n & ((1 << length) - 1))
    self.data = (self.data & ((1 << length) - 1))
    self.search = "P"
    self.bit_cnt = 0
    return 1
  else
    return 0
  end
end

return _decoder
