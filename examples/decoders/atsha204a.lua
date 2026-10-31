-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Michalis Pappas <mpappas@fastmail.fm>

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
local WORD_ADDR_RESET, WORD_ADDR_SLEEP, WORD_ADDR_IDLE, WORD_ADDR_COMMAND, WORD_ADDR, OPCODE_COUNTER, OPCODE_DERIVE_KEY, OPCODE_DEV_REV, OPCODE_ECDH, OPCODE_GEN_DIG, OPCODE_GEN_KEY, OPCODE_HMAC, OPCODE_CHECK_MAC, OPCODE_LOCK, OPCODE_MAC, OPCODE_NONCE, OPCODE_PAUSE, OPCODE_PRIVWRITE, OPCODE_RANDOM, OPCODE_READ, OPCODE_SHA, OPCODE_SIGN, OPCODE_UPDATE_EXTRA, OPCODE_VERIFY, OPCODE_WRITE, OPCODES, ZONE_CONFIG, ZONE_OTP, ZONE_DATA, ZONES, STATUS_SUCCESS, STATUS_CHECKMAC_FAIL, STATUS_PARSE_ERROR, STATUS_EXECUTION_ERROR, STATUS_READY, STATUS_CRC_COMM_ERROR, STATUS, Decoder
local _decoder

WORD_ADDR_RESET = 0
WORD_ADDR_SLEEP = 1
WORD_ADDR_IDLE = 2
WORD_ADDR_COMMAND = 3
WORD_ADDR = logicview.dict({ [0] = "RESET", [1] = "SLEEP", [2] = "IDLE", [3] = "COMMAND" })
OPCODE_COUNTER = 36
OPCODE_DERIVE_KEY = 28
OPCODE_DEV_REV = 48
OPCODE_ECDH = 67
OPCODE_GEN_DIG = 21
OPCODE_GEN_KEY = 64
OPCODE_HMAC = 17
OPCODE_CHECK_MAC = 40
OPCODE_LOCK = 23
OPCODE_MAC = 8
OPCODE_NONCE = 22
OPCODE_PAUSE = 1
OPCODE_PRIVWRITE = 70
OPCODE_RANDOM = 27
OPCODE_READ = 2
OPCODE_SHA = 71
OPCODE_SIGN = 65
OPCODE_UPDATE_EXTRA = 32
OPCODE_VERIFY = 69
OPCODE_WRITE = 18
OPCODES = logicview.dict({ [1] = "Pause", [2] = "Read", [8] = "MAC", [17] = "HMAC", [18] = "Write", [21] = "GenDig", [22] = "Nonce", [23] = "Lock", [27] = "Random", [28] = "DeriveKey", [32] = "UpdateExtra", [36] = "Counter", [40] = "CheckMac", [48] = "DevRev", [64] = "GenKey", [65] = "Sign", [67] = "ECDH", [69] = "Verify", [70] = "PrivWrite", [71] = "SHA" })
ZONE_CONFIG = 0
ZONE_OTP = 1
ZONE_DATA = 2
ZONES = logicview.dict({ [0] = "CONFIG", [1] = "OTP", [2] = "DATA" })
STATUS_SUCCESS = 0
STATUS_CHECKMAC_FAIL = 1
STATUS_PARSE_ERROR = 3
STATUS_EXECUTION_ERROR = 15
STATUS_READY = 17
STATUS_CRC_COMM_ERROR = 255
STATUS = logicview.dict({ [0] = "Command success", [1] = "Checkmac failure", [3] = "Parse error", [15] = "Execution error", [17] = "Ready", [255] = "CRC / communications error" })
_decoder = {
  api_version = 3,
  id = "atsha204a",
  name = "ATSHA204A",
  longname = "Microchip ATSHA204A",
  desc = "Microchip ATSHA204A family crypto authentication protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Security/crypto", "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "waddr", "Word address" }, { "count", "Count" }, { "opcode", "Opcode" }, { "param1", "Param1" }, { "param2", "Param2" }, { "data", "Data" }, { "crc", "CRC" }, { "status", "Status" }, { "warning", "Warning" } },
  annotation_rows = { { "frame", "Frame", { 0, 1, 2, 3, 4, 5, 6 } }, { "status", "Status", { 7 } }, { "warnings", "Warnings", { 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  do
    local _lv_chain = (-1)
    self.waddr = _lv_chain
    self.opcode = _lv_chain
  end
  do
    local _lv_chain = 0
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
  self.bytes = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.output_tx_bytes(self)
  local b, count
  b = self.bytes
  if logicview.truth((logicview.len(b) < 1)) then
    return
  end
  self.waddr = logicview.idx(logicview.idx(b, 0), 2)
  self:put_waddr(logicview.idx(b, 0))
  if logicview.truth(logicview.eq(self.waddr, WORD_ADDR_COMMAND)) then
    count = logicview.idx(logicview.idx(b, 1), 2)
    self:put_count(logicview.idx(b, 1))
    if logicview.truth((not logicview.eq((logicview.len(b) - 1), count))) then
      self:put_warning(logicview.idx(logicview.idx(b, 0), 0), logicview.idx(logicview.idx(b, (-1)), 1), logicview.pyformat("Invalid frame length: Got {}, expecting {} ", { (logicview.len(b) - 1), count }, logicview.dict({})))
      return
    end
    self.opcode = logicview.idx(logicview.idx(b, 2), 2)
    self:put_opcode(logicview.idx(b, 2))
    self:put_param1(logicview.idx(b, 3))
    self:put_param2({ logicview.idx(b, 4), logicview.idx(b, 5) })
    self:put_data(logicview.slice(b, 6, (-2), nil))
    self:put_crc({ logicview.idx(b, (-2)), logicview.idx(b, (-1)) })
  end
end
function _decoder.output_rx_bytes(self)
  local b, count
  b = self.bytes
  count = logicview.idx(logicview.idx(b, 0), 2)
  self:put_count(logicview.idx(b, 0))
  if logicview.truth(logicview.eq(self.waddr, WORD_ADDR_RESET)) then
    self:put_data({ logicview.idx(b, 1) })
    self:put_crc({ logicview.idx(b, 2), logicview.idx(b, 3) })
    self:put_status(logicview.idx(logicview.idx(b, 0), 0), logicview.idx(logicview.idx(b, (-1)), 1), logicview.idx(logicview.idx(b, 1), 2))
  elseif logicview.truth(logicview.eq(self.waddr, WORD_ADDR_COMMAND)) then
    if logicview.truth(logicview.eq(count, 4)) then
      self:put_data({ logicview.idx(b, 1) })
      self:put_crc({ logicview.idx(b, 2), logicview.idx(b, 3) })
      self:put_status(logicview.idx(logicview.idx(b, 0), 0), logicview.idx(logicview.idx(b, (-1)), 1), logicview.idx(logicview.idx(b, 1), 2))
    else
      self:put_data(logicview.slice(b, 1, (-2), nil))
      self:put_crc({ logicview.idx(b, (-2)), logicview.idx(b, (-1)) })
    end
  end
end
function _decoder.putx(self, s, data)
  self:put(logicview.idx(s, 0), logicview.idx(s, 1), self.out_ann, data)
end
function _decoder.puty(self, s, data)
  self:put(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 1), 1), self.out_ann, data)
end
function _decoder.putz(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.put_waddr(self, s)
  self:putx(s, { 0, { logicview.pymod("Word addr: %s", logicview.idx(WORD_ADDR, logicview.idx(s, 2))) } })
end
function _decoder.put_count(self, s)
  self:putx(s, { 1, { logicview.pymod("Count: %s", logicview.idx(s, 2)) } })
end
function _decoder.put_opcode(self, s)
  self:putx(s, { 2, { logicview.pymod("Opcode: %s", logicview.idx(OPCODES, logicview.idx(s, 2))) } })
end
function _decoder.put_param1(self, s)
  local op
  op = self.opcode
  if logicview.truth(logicview.contains({ OPCODE_CHECK_MAC, OPCODE_COUNTER, OPCODE_DEV_REV, OPCODE_ECDH, OPCODE_GEN_KEY, OPCODE_HMAC, OPCODE_MAC, OPCODE_NONCE, OPCODE_RANDOM, OPCODE_SHA, OPCODE_SIGN, OPCODE_VERIFY }, op)) then
    self:putx(s, { 3, { logicview.pymod("Mode: %02X", logicview.idx(s, 2)) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_DERIVE_KEY)) then
    self:putx(s, { 3, { logicview.pymod("Random: %s", logicview.idx(s, 2)) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_PRIVWRITE)) then
    self:putx(s, { 3, { logicview.pyformat("Encrypted: {}", { (function() if logicview.truth((logicview.idx(s, 2) & 64)) then return "Yes" else return "No" end end)() }, logicview.dict({})) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_GEN_DIG)) then
    self:putx(s, { 3, { logicview.pymod("Zone: %s", logicview.idx(ZONES, logicview.idx(s, 2))) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_LOCK)) then
    self:putx(s, { 3, { logicview.pyformat("Zone: {}, Summary: {}", { (function() if logicview.truth(logicview.idx(s, 2)) then return "DATA/OTP" else return "CONFIG" end end)(), (function() if logicview.truth((logicview.idx(s, 2) & 128)) then return "Ignored" else return "Used" end end)() }, logicview.dict({})) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_PAUSE)) then
    self:putx(s, { 3, { logicview.pymod("Selector: %02X", logicview.idx(s, 2)) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_READ)) then
    self:putx(s, { 3, { logicview.pyformat("Zone: {}, Length: {}", { logicview.idx(ZONES, (logicview.idx(s, 2) & 3)), (function() if logicview.truth((logicview.idx(s, 2) & 144)) then return "32 bytes" else return "4 bytes" end end)() }, logicview.dict({})) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_WRITE)) then
    self:putx(s, { 3, { logicview.pyformat("Zone: {}, Encrypted: {}, Length: {}", { logicview.idx(ZONES, (logicview.idx(s, 2) & 3)), (function() if logicview.truth((logicview.idx(s, 2) & 64)) then return "Yes" else return "No" end end)(), (function() if logicview.truth((logicview.idx(s, 2) & 144)) then return "32 bytes" else return "4 bytes" end end)() }, logicview.dict({})) } })
  else
    self:putx(s, { 3, { logicview.pymod("Param1: %02X", logicview.idx(s, 2)) } })
  end
end
function _decoder.put_param2(self, s)
  local op
  op = self.opcode
  if logicview.truth(logicview.eq(op, OPCODE_DERIVE_KEY)) then
    self:puty(s, { 4, { logicview.pyformat("TargetKey: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.contains({ OPCODE_COUNTER, OPCODE_ECDH, OPCODE_GEN_KEY, OPCODE_PRIVWRITE, OPCODE_SIGN, OPCODE_VERIFY }, op)) then
    self:puty(s, { 4, { logicview.pyformat("KeyID: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.contains({ OPCODE_NONCE, OPCODE_PAUSE, OPCODE_RANDOM }, op)) then
    self:puty(s, { 4, { logicview.pyformat("Zero: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.contains({ OPCODE_HMAC, OPCODE_MAC, OPCODE_CHECK_MAC, OPCODE_GEN_DIG }, op)) then
    self:puty(s, { 4, { logicview.pyformat("SlotID: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_LOCK)) then
    self:puty(s, { 4, { logicview.pyformat("Summary: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.contains({ OPCODE_READ, OPCODE_WRITE }, op)) then
    self:puty(s, { 4, { logicview.pyformat("Address: {:02x} {:02x}", { logicview.idx(logicview.idx(s, 1), 2), logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_UPDATE_EXTRA)) then
    self:puty(s, { 4, { logicview.pyformat("NewValue: {:02x}", { logicview.idx(logicview.idx(s, 0), 2) }, logicview.dict({})) } })
  else
    self:puty(s, { 4, { "-" } })
  end
end
function _decoder.put_data(self, s)
  local op
  if logicview.truth(logicview.eq(logicview.len(s), 0)) then
    return
  end
  op = self.opcode
  if logicview.truth(logicview.eq(op, OPCODE_CHECK_MAC)) then
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 31), 1), { 5, { logicview.pymod("ClientChal: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 0, 32, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    self:putz(logicview.idx(logicview.idx(s, 32), 0), logicview.idx(logicview.idx(s, 63), 1), { 5, { logicview.pymod("ClientResp: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 32, 64, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    self:putz(logicview.idx(logicview.idx(s, 64), 0), logicview.idx(logicview.idx(s, 76), 1), { 5, { logicview.pymod("OtherData: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 64, 77, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_DERIVE_KEY)) then
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 31), 1), { 5, { logicview.pymod("MAC: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_ECDH)) then
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 31), 1), { 5, { logicview.pymod("Pub X: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 0, 32, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    self:putz(logicview.idx(logicview.idx(s, 32), 0), logicview.idx(logicview.idx(s, 63), 1), { 5, { logicview.pymod("Pub Y: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 32, 64, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  elseif logicview.truth(logicview.contains({ OPCODE_GEN_DIG, OPCODE_GEN_KEY }, op)) then
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 3), 1), { 5, { logicview.pymod("OtherData: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_MAC)) then
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 31), 1), { 5, { logicview.pymod("Challenge: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  elseif logicview.truth(logicview.eq(op, OPCODE_PRIVWRITE)) then
    if logicview.truth((logicview.len(s) > 36)) then
      self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, (-35)), 1), { 5, { logicview.pymod("Value: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
      self:putz(logicview.idx(logicview.idx(s, (-32)), 0), logicview.idx(logicview.idx(s, (-1)), 1), { 5, { logicview.pymod("MAC: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    else
      self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, (-1)), 1), { 5, { logicview.pymod("Value: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    end
  elseif logicview.truth(logicview.eq(op, OPCODE_VERIFY)) then
    if logicview.truth((logicview.len(s) >= 64)) then
      self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, 31), 1), { 5, { logicview.pymod("ECDSA R: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 0, 32, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
      self:putz(logicview.idx(logicview.idx(s, 32), 0), logicview.idx(logicview.idx(s, 63), 1), { 5, { logicview.pymod("ECDSA S: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 32, 64, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    end
    if logicview.truth(logicview.eq(logicview.len(s), 83)) then
      self:putz(logicview.idx(logicview.idx(s, 64), 0), logicview.idx(logicview.idx(s, 82), 1), { 5, { logicview.pymod("OtherData: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 64, 83, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    end
    if logicview.truth(logicview.eq(logicview.len(s), 128)) then
      self:putz(logicview.idx(logicview.idx(s, 64), 0), logicview.idx(logicview.idx(s, 95), 1), { 5, { logicview.pymod("Pub X: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 64, 96, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
      self:putz(logicview.idx(logicview.idx(s, 96), 0), logicview.idx(logicview.idx(s, 127), 1), { 5, { logicview.pymod("Pub Y: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(s, 96, 128, nil)) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    end
  elseif logicview.truth(logicview.eq(op, OPCODE_WRITE)) then
    if logicview.truth((logicview.len(s) > 32)) then
      self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, (-31)), 1), { 5, { logicview.pymod("Value: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
      self:putz(logicview.idx(logicview.idx(s, (-32)), 0), logicview.idx(logicview.idx(s, (-1)), 1), { 5, { logicview.pymod("MAC: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    else
      self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, (-1)), 1), { 5, { logicview.pymod("Value: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
    end
  else
    self:putz(logicview.idx(logicview.idx(s, 0), 0), logicview.idx(logicview.idx(s, (-1)), 1), { 5, { logicview.pymod("Data: %s", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(logicview.idx(i, 2), "02x")
  end
  return _lv_out
end)())) } })
  end
end
function _decoder.put_crc(self, s)
  self:puty(s, { 6, { logicview.pyformat("CRC: {:02X} {:02X}", { logicview.idx(logicview.idx(s, 0), 2), logicview.idx(logicview.idx(s, 1), 2) }, logicview.dict({})) } })
end
function _decoder.put_status(self, ss, es, status)
  self:putz(ss, es, { 7, { logicview.pymod("Status: %s", logicview.idx(STATUS, status)) } })
end
function _decoder.put_warning(self, ss, es, msg)
  self:putz(ss, es, { 8, { logicview.pymod("Warning: %s", msg) } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      databyte = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth((not logicview.eq(cmd, "START"))) then
        return
      end
      self.state = "GET SLAVE ADDR"
      self.ss_block = ss
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "READ REGS"
      elseif logicview.truth(logicview.eq(cmd, "ADDRESS WRITE")) then
        self.state = "WRITE REGS"
      end
    elseif logicview.truth(logicview.eq(self.state, "READ REGS")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        _table.insert(self.bytes, { ss, es, databyte })
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.es_block = es
        self.opcode = (-1)
        if logicview.truth((logicview.len(self.bytes) > 0)) then
          self:output_rx_bytes()
        end
        self.waddr = (-1)
        self.bytes = {  }
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.eq(self.state, "WRITE REGS")) then
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        _table.insert(self.bytes, { ss, es, databyte })
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.es_block = es
        self:output_tx_bytes()
        self.bytes = {  }
        self.state = "IDLE"
      end
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

return _decoder
