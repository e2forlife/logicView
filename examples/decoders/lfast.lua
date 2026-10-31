-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Soeren Apel <soeren@apelpie.net>

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
local bitpack, decimal, payload_sizes, payload_byte_sizes, channel_types, control_payloads, ann_bit, ann_sync, ann_header_pl_size, ann_header_ch_type, ann_header_cts, ann_payload, ann_control_data, ann_sleepbit, ann_warning, state_sync, state_header, state_payload, state_sleepbit, Decoder
local _decoder

bitpack = logicview.bitpack
decimal = { getcontext = function() return {} end, ROUND_HALF_UP = 0, Decimal = function(v) return _tonumber(v) or 0 end }
payload_sizes = logicview.dict({ [0] = "8 bit", [1] = "32 bit / 4 byte", [2] = "64 bit / 8 byte", [3] = "96 bit / 12 byte", [4] = "128 bit / 16 byte", [5] = "256 bit / 32 byte", [6] = "512 bit / 64 byte", [7] = "288 bit / 36 byte" })
payload_byte_sizes = logicview.dict({ [0] = 1, [1] = 4, [2] = 8, [3] = 12, [4] = 16, [5] = 32, [6] = 64, [7] = 36 })
channel_types = logicview.dict({ [0] = "Interface Control / PING", [1] = "Unsolicited Status (32 bit)", [2] = "Slave Interface Control / Read", [3] = "CTS Transfer", [4] = "Data Channel A", [5] = "Data Channel B", [6] = "Data Channel C", [7] = "Data Channel D", [8] = "Data Channel E", [9] = "Data Channel F", [10] = "Data Channel G", [11] = "Data Channel H", [12] = "Reserved", [13] = "Reserved", [14] = "Reserved", [15] = "Reserved" })
control_payloads = logicview.dict({ [0] = "PING", [1] = "Reserved", [2] = "Slave interface clock multiplier start", [4] = "Slave interface clock multiplier stop", [8] = "Use 5 MBaud for M->S", [16] = "Use 320 MBaud for M->S", [32] = "Use 5 MBaud for S->M", [64] = "Use 20 MBaud for S->M (needs 20 MHz SysClk)", [128] = "Use 320 MBaud for S->M", [49] = "Enable slave interface transmitter", [50] = "Disable slave interface transmitter", [52] = "Enable clock test mode", [56] = "Disable clock test mode and payload loopback", [255] = "Enable payload loopback" })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_bit = logicview.idx(_lv_seq, 0)
  ann_sync = logicview.idx(_lv_seq, 1)
  ann_header_pl_size = logicview.idx(_lv_seq, 2)
  ann_header_ch_type = logicview.idx(_lv_seq, 3)
  ann_header_cts = logicview.idx(_lv_seq, 4)
  ann_payload = logicview.idx(_lv_seq, 5)
  ann_control_data = logicview.idx(_lv_seq, 6)
  ann_sleepbit = logicview.idx(_lv_seq, 7)
  ann_warning = logicview.idx(_lv_seq, 8)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  state_sync = logicview.idx(_lv_seq, 0)
  state_header = logicview.idx(_lv_seq, 1)
  state_payload = logicview.idx(_lv_seq, 2)
  state_sleepbit = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "lfast",
  name = "LFAST",
  longname = "NXP LFAST interface",
  desc = "Differential high-speed P2P interface",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "lfast" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "TXP or RXP" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bit", "Bits" }, { "sync", "Sync Pattern" }, { "header_pl_size", "Payload Size" }, { "header_ch_type", "Logical Channel Type" }, { "header_cts", "Clear To Send" }, { "payload", "Payload" }, { "ctrl_data", "Control Data" }, { "sleep", "Sleep Bit" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6, 7 } }, { "warnings", "Warnings", { 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  decimal.getcontext().rounding = decimal.ROUND_HALF_UP
  self.bit_len = 4294967295
  self:reset()
end
function _decoder.reset(self)
  self.prev_bit_len = self.bit_len
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  do
    local _lv_chain = 0
    self.ss_payload = _lv_chain
    self.es_payload = _lv_chain
  end
  self.ss_byte = 0
  self.bits = {  }
  self.payload = {  }
  self.payload_size = 0
  self.bit_len = 0
  self.timeout = 0
  self.ch_type_id = 0
  self.state = state_sync
end
function _decoder.metadata(self, key, value)
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.put_ann(self, ss, es, ann_class, value)
  self:put(ss, es, self.out_ann, { ann_class, value })
end
function _decoder.put_payload(self)
  self:put(self.ss_payload, self.es_payload, self.out_python, self.payload)
end
function _decoder.handle_sync(self)
  local value
  if logicview.truth(logicview.eq(logicview.len(self.bits), 1)) then
    self.ss_sync = self.ss_bit
  end
  if logicview.truth(logicview.eq(logicview.len(self.bits), 16)) then
    value = bitpack(self.bits)
    if logicview.truth(logicview.eq(value, 43083)) then
      self:put_ann(self.ss_sync, self.es_bit, ann_sync, { "Sync OK" })
    else
      self:put_ann(self.ss_sync, self.es_bit, ann_warning, { logicview.pyformat("Wrong Sync Value: {:02X}", { value }, logicview.dict({})) })
      self:reset()
    end
    if logicview.truth((self.ss > 0)) then
      self.bits = {  }
      self.state = state_header
      self.timeout = logicview.tointeger(logicview.mul(9.4, self.bit_len))
    end
  end
end
function _decoder.handle_header(self)
  local bit_len, value, ss, es, size_id, size, ch_type, cts
  if logicview.truth(logicview.eq(logicview.len(self.bits), 1)) then
    self.ss_header = self.ss_bit
  end
  if logicview.truth(logicview.eq(logicview.len(self.bits), 8)) then
    bit_len = ((self.es_bit - self.ss_header) / 8)
    value = bitpack(self.bits)
    ss = self.ss_header
    es = logicview.add(ss, logicview.mul(3, bit_len))
    size_id = ((value & 224) >> 5)
    size = logicview.dget(payload_sizes, size_id, nil)
    self.payload_size = logicview.dget(payload_byte_sizes, size_id, nil)
    self:put_ann(logicview.tointeger(ss), logicview.tointeger(es), ann_header_pl_size, { size })
    ss = es
    es = logicview.add(ss, logicview.mul(4, bit_len))
    self.ch_type_id = ((value & 30) >> 1)
    ch_type = logicview.dget(channel_types, self.ch_type_id, nil)
    self:put_ann(logicview.tointeger(ss), logicview.tointeger(es), ann_header_ch_type, { ch_type })
    ss = es
    es = logicview.add(ss, bit_len)
    cts = (value & 1)
    self:put_ann(logicview.tointeger(ss), logicview.tointeger(es), ann_header_cts, { logicview.pyformat("{}", { cts }, logicview.dict({})) })
    self.bits = {  }
    self.state = state_payload
    self.timeout = logicview.tointeger(logicview.mul(9.4, self.bit_len))
  end
end
function _decoder.handle_payload(self)
  local value, value_hex, ctrl_data
  self.timeout = logicview.tointeger(logicview.mul(logicview.mul((self.payload_size - logicview.len(self.payload)), 8), self.bit_len))
  if logicview.truth(logicview.eq(logicview.len(self.bits), 1)) then
    self.ss_byte = self.ss_bit
    if logicview.truth(logicview.eq(self.ss_payload, 0)) then
      self.ss_payload = self.ss_bit
    end
  end
  if logicview.truth(logicview.eq(logicview.len(self.bits), 8)) then
    value = bitpack(self.bits)
    value_hex = logicview.pyformat("{:02X}", { value }, logicview.dict({}))
    if logicview.truth((function()
  local _v
  _v = (self.ch_type_id >= 4)
  if not logicview.truth(_v) then return _v end
  _v = (self.ch_type_id <= 11)
  return _v
end)()) then
      self:put_ann(self.ss_byte, self.es_bit, ann_payload, { value_hex })
    elseif logicview.truth(logicview.eq(logicview.len(self.payload), 0)) then
      ctrl_data = logicview.dget(control_payloads, value, value_hex)
      self:put_ann(self.ss_byte, self.es_bit, ann_control_data, { ctrl_data })
    else
      self:put_ann(self.ss_byte, self.es_bit, ann_control_data, { value_hex })
    end
    self.bits = {  }
    self.es_payload = self.es_bit
    _table.insert(self.payload, { self.ss_byte, self.es_payload, value })
    if logicview.truth(logicview.eq(logicview.len(self.payload), self.payload_size)) then
      self.timeout = logicview.tointeger(logicview.mul(1.4, self.bit_len))
      self.state = state_sleepbit
    end
  end
end
function _decoder.handle_sleepbit(self)
  if logicview.truth(logicview.eq(logicview.len(self.bits), 0)) then
    self:put_ann(self.ss_bit, self.es_bit, ann_sleepbit, { "No LVDS sleep mode request", "No sleep", "N" })
  elseif logicview.truth((logicview.len(self.bits) > 1)) then
    self:put_ann(self.ss_bit, self.es_bit, ann_warning, { logicview.pyformat("Expected only the sleep bit, got {} bits instead", { logicview.len(self.bits) }, logicview.dict({})) })
  elseif logicview.truth(logicview.eq(logicview.idx(self.bits, 0), 1)) then
    self:put_ann(self.ss_bit, self.es_bit, ann_sleepbit, { "LVDS sleep mode request", "Sleep", "Y" })
  else
    self:put_ann(self.ss_bit, self.es_bit, ann_sleepbit, { "No LVDS sleep mode request", "No sleep", "N" })
  end
  if logicview.truth((function()
  local _v
  _v = (self.ch_type_id >= 4)
  if not logicview.truth(_v) then return _v end
  _v = (self.ch_type_id <= 11)
  return _v
end)()) then
    if logicview.truth((logicview.len(self.payload) > 0)) then
      self:put_payload()
    end
  end
end
function _decoder.decode(self)
  local rising_edge, bit_count, bit_value, divided_len, i
  while true do
    if logicview.truth(logicview.eq(self.timeout, 0)) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        rising_edge = logicview.idx(_lv_seq, 0)
      end
    else
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ skip = self.timeout }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        rising_edge = logicview.idx(_lv_seq, 0)
      end
    end
    if logicview.truth(logicview.eq(self.ss, 0)) then
      self.ss = self.samplenum
      self.timeout = logicview.tointeger(logicview.mul(16.2, self.prev_bit_len))
      goto continue_1
    end
    self.es = self.samplenum
    if logicview.truth((function()
  local _v
  _v = bMoreMatch
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((self.matched & 2), 2)
  return _v
end)()) then
      rising_edge = (~rising_edge)
      if logicview.truth(logicview.eq(self.state, state_sync)) then
        self:reset()
        goto continue_1
      elseif logicview.truth(logicview.eq(self.state, state_sleepbit)) then
        self.ss_bit = logicview.add(self.ss_bit, self.bit_len)
        self.es_bit = logicview.add(self.ss_bit, self.bit_len)
        self:handle_sleepbit()
        self:reset()
        goto continue_1
      end
    end
    if logicview.truth(logicview.eq(logicview.tointeger((self.es - self.ss)), 0)) then
      goto continue_1
    end
    if logicview.truth(logicview.eq(self.bit_len, 0)) then
      self.bit_len = (self.es - self.ss)
    end
    bit_count = ((self.es - self.ss) / self.bit_len)
    bit_count = logicview.tointeger(decimal.Decimal(bit_count):to_integral_value())
    if logicview.truth(logicview.eq(bit_count, 0)) then
      self:put_ann(self.ss, self.es, ann_warning, { "Bit time too short" })
      self:reset()
      goto continue_1
    end
    bit_value = (function() if logicview.truth(rising_edge) then return "0" else return "1" end end)()
    divided_len = ((self.es - self.ss) / bit_count)
    for _lv_i in logicview.range(bit_count) do
      i = _lv_i
      self.ss_bit = logicview.tointeger(logicview.add(self.ss, logicview.mul(i, divided_len)))
      self.es_bit = logicview.tointeger(logicview.add(self.ss_bit, divided_len))
      self:put_ann(self.ss_bit, self.es_bit, ann_bit, { bit_value })
      logicview.list_insert(self.bits, 0, (function() if logicview.truth(rising_edge) then return 0 else return 1 end end)())
      if logicview.truth(logicview.eq(self.state, state_sync)) then
        self:handle_sync()
      elseif logicview.truth(logicview.eq(self.state, state_header)) then
        self:handle_header()
      elseif logicview.truth(logicview.eq(self.state, state_payload)) then
        self:handle_payload()
      elseif logicview.truth(logicview.eq(self.state, state_sleepbit)) then
        self:handle_sleepbit()
        self:reset()
      end
      if logicview.truth(logicview.eq(self.ss, 0)) then
        break
      end
      ::continue_2::
    end
    if logicview.truth((self.ss > 0)) then
      self.ss = self.samplenum
    end
    if logicview.truth((function()
  local _v
  _v = bMoreMatch
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((self.matched & 2), 2)
  return _v
end)()) then
      self:reset()
    end
    ::continue_1::
  end
end

return _decoder
