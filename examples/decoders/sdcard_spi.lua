-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2020 Uwe Hermann <uwe@hermann-uwe.de>
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
local SrdIntEnum, cmd_names, acmd_names, responses, a, Ann, Decoder, accepted_voltages, sd_status
local _decoder

cmd_names = logicview.dict({ [0] = "GO_IDLE_STATE", [1] = "SEND_OP_COND", [2] = "ALL_SEND_CID", [3] = "SEND_RELATIVE_ADDR", [4] = "SET_DSR", [5] = "IO_SEND_OP_COND", [6] = "SWITCH_FUNC", [7] = "SELECT/DESELECT_CARD", [8] = "SEND_IF_COND", [9] = "SEND_CSD", [10] = "SEND_CID", [11] = "VOLTAGE_SWITCH", [12] = "STOP_TRANSMISSION", [13] = "SEND_STATUS", [15] = "GO_INACTIVE_STATE", [16] = "SET_BLOCKLEN", [17] = "READ_SINGLE_BLOCK", [18] = "READ_MULTIPLE_BLOCK", [19] = "SEND_TUNING_BLOCK", [20] = "SPEED_CLASS_CONTROL", [23] = "SET_BLOCK_COUNT", [24] = "WRITE_BLOCK", [25] = "WRITE_MULTIPLE_BLOCK", [26] = "Reserved for manufacturer", [27] = "PROGRAM_CSD", [28] = "SET_WRITE_PROT", [29] = "CLR_WRITE_PROT", [30] = "SEND_WRITE_PROT", [32] = "ERASE_WR_BLK_START", [33] = "ERASE_WR_BLK_END", [34] = "Reserved for CMD6", [35] = "Reserved for CMD6", [36] = "Reserved for CMD6", [37] = "Reserved for CMD6", [38] = "ERASE", [40] = "Reserved for security specification", [42] = "LOCK_UNLOCK", [50] = "Reserved for CMD6", [52] = "IO_RW_DIRECT", [53] = "IO_RW_EXTENDED", [54] = "Unknown", [55] = "APP_CMD", [56] = "GEN_CMD", [57] = "Reserved for CMD6", [58] = "READ_OCR", [59] = "CRC_ON_OFF", [60] = "Reserved for manufacturer", [61] = "Reserved for manufacturer", [62] = "Reserved for manufacturer", [63] = "Reserved for manufacturer" })
acmd_names = logicview.dict({ [6] = "SET_BUS_WIDTH", [13] = "SD_STATUS", [14] = "Reserved for Security Application", [15] = "Reserved for Security Application", [16] = "Reserved for Security Application", [18] = "Reserved for SD security applications", [22] = "SEND_NUM_WR_BLOCKS", [23] = "SET_WR_BLK_ERASE_COUNT", [25] = "Reserved for SD security applications", [26] = "Reserved for SD security applications", [27] = "Reserved for security specification", [28] = "Reserved for security specification", [30] = "Reserved for security specification", [31] = "Reserved for security specification", [32] = "Reserved for security specification", [33] = "Reserved for security specification", [34] = "Reserved for security specification", [35] = "Reserved for security specification", [38] = "Reserved for SD security applications", [41] = "SD_SEND_OP_COND", [42] = "SET_CLR_CARD_DETECT", [43] = "Reserved for SD security applications", [44] = "Reserved for SD security applications", [45] = "Reserved for SD security applications", [46] = "Reserved for SD security applications", [47] = "Reserved for SD security applications", [48] = "Reserved for SD security applications", [49] = "Reserved for SD security applications", [50] = "Unknown", [51] = "SEND_SCR", [52] = "Reserved for security specification", [53] = "Reserved for security specification", [54] = "Reserved for security specification", [55] = "Non-existant", [56] = "Reserved for security specification", [57] = "Reserved for security specification", [58] = "Reserved for security specification", [59] = "Reserved for security specification", [60] = "Unknown", [61] = "Unknown", [62] = "Unknown", [63] = "Unknown" })
accepted_voltages = logicview.dict({ [1] = "2.7-3.6V", [2] = "reserved for low voltage range", [4] = "reserved", [8] = "reserved" })
sd_status = logicview.dict({  })

responses = logicview.split("1 1b 2 3 7", nil, nil)
a = logicview.add(logicview.add(logicview.add((function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("CMD%d", i)
  end
  return _lv_out
end)(), (function()
  local _lv_out = {}
  for _lv_i in logicview.range(64) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.pymod("ACMD%d", i)
  end
  return _lv_out
end)()), (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(responses) do
    r = _lv_item
    _lv_out[#_lv_out + 1] = logicview.add("R", _string.upper(r))
  end
  return _lv_out
end)()), { "BIT", "BIT_WARNING" })
Ann = logicview.int_enum(a)
_decoder = {
  api_version = 3,
  id = "sdcard_spi",
  name = "SD card (SPI mode)",
  longname = "Secure Digital card (SPI mode)",
  desc = "Secure Digital card (SPI mode) low-level protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Memory" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "cmd0", "CMD0" }, { "cmd1", "CMD1" }, { "cmd2", "CMD2" }, { "cmd3", "CMD3" }, { "cmd4", "CMD4" }, { "cmd5", "CMD5" }, { "cmd6", "CMD6" }, { "cmd7", "CMD7" }, { "cmd8", "CMD8" }, { "cmd9", "CMD9" }, { "cmd10", "CMD10" }, { "cmd11", "CMD11" }, { "cmd12", "CMD12" }, { "cmd13", "CMD13" }, { "cmd14", "CMD14" }, { "cmd15", "CMD15" }, { "cmd16", "CMD16" }, { "cmd17", "CMD17" }, { "cmd18", "CMD18" }, { "cmd19", "CMD19" }, { "cmd20", "CMD20" }, { "cmd21", "CMD21" }, { "cmd22", "CMD22" }, { "cmd23", "CMD23" }, { "cmd24", "CMD24" }, { "cmd25", "CMD25" }, { "cmd26", "CMD26" }, { "cmd27", "CMD27" }, { "cmd28", "CMD28" }, { "cmd29", "CMD29" }, { "cmd30", "CMD30" }, { "cmd31", "CMD31" }, { "cmd32", "CMD32" }, { "cmd33", "CMD33" }, { "cmd34", "CMD34" }, { "cmd35", "CMD35" }, { "cmd36", "CMD36" }, { "cmd37", "CMD37" }, { "cmd38", "CMD38" }, { "cmd39", "CMD39" }, { "cmd40", "CMD40" }, { "cmd41", "CMD41" }, { "cmd42", "CMD42" }, { "cmd43", "CMD43" }, { "cmd44", "CMD44" }, { "cmd45", "CMD45" }, { "cmd46", "CMD46" }, { "cmd47", "CMD47" }, { "cmd48", "CMD48" }, { "cmd49", "CMD49" }, { "cmd50", "CMD50" }, { "cmd51", "CMD51" }, { "cmd52", "CMD52" }, { "cmd53", "CMD53" }, { "cmd54", "CMD54" }, { "cmd55", "CMD55" }, { "cmd56", "CMD56" }, { "cmd57", "CMD57" }, { "cmd58", "CMD58" }, { "cmd59", "CMD59" }, { "cmd60", "CMD60" }, { "cmd61", "CMD61" }, { "cmd62", "CMD62" }, { "cmd63", "CMD63" }, { "acmd0", "ACMD0" }, { "acmd1", "ACMD1" }, { "acmd2", "ACMD2" }, { "acmd3", "ACMD3" }, { "acmd4", "ACMD4" }, { "acmd5", "ACMD5" }, { "acmd6", "ACMD6" }, { "acmd7", "ACMD7" }, { "acmd8", "ACMD8" }, { "acmd9", "ACMD9" }, { "acmd10", "ACMD10" }, { "acmd11", "ACMD11" }, { "acmd12", "ACMD12" }, { "acmd13", "ACMD13" }, { "acmd14", "ACMD14" }, { "acmd15", "ACMD15" }, { "acmd16", "ACMD16" }, { "acmd17", "ACMD17" }, { "acmd18", "ACMD18" }, { "acmd19", "ACMD19" }, { "acmd20", "ACMD20" }, { "acmd21", "ACMD21" }, { "acmd22", "ACMD22" }, { "acmd23", "ACMD23" }, { "acmd24", "ACMD24" }, { "acmd25", "ACMD25" }, { "acmd26", "ACMD26" }, { "acmd27", "ACMD27" }, { "acmd28", "ACMD28" }, { "acmd29", "ACMD29" }, { "acmd30", "ACMD30" }, { "acmd31", "ACMD31" }, { "acmd32", "ACMD32" }, { "acmd33", "ACMD33" }, { "acmd34", "ACMD34" }, { "acmd35", "ACMD35" }, { "acmd36", "ACMD36" }, { "acmd37", "ACMD37" }, { "acmd38", "ACMD38" }, { "acmd39", "ACMD39" }, { "acmd40", "ACMD40" }, { "acmd41", "ACMD41" }, { "acmd42", "ACMD42" }, { "acmd43", "ACMD43" }, { "acmd44", "ACMD44" }, { "acmd45", "ACMD45" }, { "acmd46", "ACMD46" }, { "acmd47", "ACMD47" }, { "acmd48", "ACMD48" }, { "acmd49", "ACMD49" }, { "acmd50", "ACMD50" }, { "acmd51", "ACMD51" }, { "acmd52", "ACMD52" }, { "acmd53", "ACMD53" }, { "acmd54", "ACMD54" }, { "acmd55", "ACMD55" }, { "acmd56", "ACMD56" }, { "acmd57", "ACMD57" }, { "acmd58", "ACMD58" }, { "acmd59", "ACMD59" }, { "acmd60", "ACMD60" }, { "acmd61", "ACMD61" }, { "acmd62", "ACMD62" }, { "acmd63", "ACMD63" }, { "r1", "R1 response" }, { "r1b", "R1b response" }, { "r2", "R2 response" }, { "r3", "R3 response" }, { "r7", "R7 response" }, { "bit", "Bit" }, { "bit-warning", "Bit warning" } },
  annotation_rows = { { "bits", "Bits", { 133, 134 } }, { "commands-replies", "Commands/replies", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_bit = _lv_a0
    self.es_bit = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_busy = _lv_a0
    self.es_busy = _lv_a1
  end
  self.cmd_token = {  }
  self.cmd_token_bits = {  }
  self.is_acmd = false
  self.blocklen = 0
  self.read_buf = {  }
  self.cmd_str = ""
  self.is_cmd24 = false
  self.cmd24_start_token_found = false
  self.is_cmd17 = false
  self.cmd17_start_token_found = false
  self.busy_first_byte = false
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.putc(self, cmd, desc)
  self:putx({ cmd, { logicview.pymod("%s: %s", { self.cmd_str, desc }) } })
end
function _decoder.putb(self, data)
  self:put(self.ss_bit, self.es_bit, self.out_ann, data)
end
function _decoder.cmd_name(self, cmd)
  local c, s
  c = (function() if logicview.truth(self.is_acmd) then return acmd_names else return cmd_names end end)()
  s = logicview.dget(c, cmd, "Unknown")
  if logicview.truth(logicview.contains({ 32, 33 }, cmd)) then
    s = logicview.add(s, "_ADDR")
  end
  return s
end
function _decoder.handle_command_token(self, mosi, miso)
  local t, s, tb, bit, cmd, crc, a
  if logicview.truth(logicview.eq(logicview.len(self.cmd_token), 0)) then
    self.ss_cmd = self.ss
  end
  _table.insert(self.cmd_token, mosi)
  _table.insert(self.cmd_token_bits, self.mosi_bits)
  if logicview.truth((logicview.len(self.cmd_token) < 6)) then
    return
  end
  self.es_cmd = self.es
  t = self.cmd_token
  s = (function() if logicview.truth(self.is_acmd) then return "ACMD" else return "CMD" end end)()
  tb = function(byte, bit)
    return logicview.idx(logicview.idx(self.cmd_token_bits, (5 - byte)), bit)
  end
  do
    local _lv_a0, _lv_a1, _lv_a2 = logicview.idx(tb(5, 7), 0), logicview.idx(tb(5, 7), 1), logicview.idx(tb(5, 7), 2)
    bit = _lv_a0
    self.ss_bit = _lv_a1
    self.es_bit = _lv_a2
  end
  if logicview.truth(logicview.eq(bit, 0)) then
    self:putb({ Ann.BIT, { logicview.pymod("Start bit: %d", bit) } })
  else
    self:putb({ Ann.BIT_WARNING, { logicview.pymod("Start bit: %s (Warning: Must be 0!)", bit) } })
  end
  do
    local _lv_a0, _lv_a1, _lv_a2 = logicview.idx(tb(5, 6), 0), logicview.idx(tb(5, 6), 1), logicview.idx(tb(5, 6), 2)
    bit = _lv_a0
    self.ss_bit = _lv_a1
    self.es_bit = _lv_a2
  end
  if logicview.truth(logicview.eq(bit, 1)) then
    self:putb({ Ann.BIT, { logicview.pymod("Transmitter bit: %d", bit) } })
  else
    self:putb({ Ann.BIT_WARNING, { logicview.pymod("Transmitter bit: %d (Warning: Must be 1!)", bit) } })
  end
  do
    local _lv_chain = (logicview.idx(t, 0) & 63)
    cmd = _lv_chain
    self.cmd_index = _lv_chain
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(tb(5, 5), 1), logicview.idx(tb(5, 0), 2)
    self.ss_bit = _lv_a0
    self.es_bit = _lv_a1
  end
  self:putb({ Ann.BIT, { logicview.pymod("Command: %s%d (%s)", { s, cmd, self:cmd_name(cmd) }) } })
  self.arg = ((((logicview.idx(t, 1) << 24) | (logicview.idx(t, 2) << 16)) | (logicview.idx(t, 3) << 8)) | logicview.idx(t, 4))
  do
    local _lv_a0, _lv_a1 = logicview.idx(tb(4, 7), 1), logicview.idx(tb(1, 0), 2)
    self.ss_bit = _lv_a0
    self.es_bit = _lv_a1
  end
  self:putb({ Ann.BIT, { "Argument: {$}", logicview.pymod("@%04X", self.arg) } })
  crc = (logicview.idx(t, 5) >> 1)
  do
    local _lv_a0, _lv_a1 = logicview.idx(tb(0, 7), 1), logicview.idx(tb(0, 1), 2)
    self.ss_bit = _lv_a0
    self.es_bit = _lv_a1
  end
  self:putb({ Ann.BIT, { "CRC7: {$}", logicview.pymod("@%01X", crc) } })
  do
    local _lv_a0, _lv_a1, _lv_a2 = logicview.idx(tb(0, 0), 0), logicview.idx(tb(0, 0), 1), logicview.idx(tb(0, 0), 2)
    bit = _lv_a0
    self.ss_bit = _lv_a1
    self.es_bit = _lv_a2
  end
  if logicview.truth(logicview.eq(bit, 1)) then
    self:putb({ Ann.BIT, { logicview.pymod("End bit: %d", bit) } })
  else
    self:putb({ Ann.BIT_WARNING, { logicview.pymod("End bit: %d (Warning: Must be 1!)", bit) } })
  end
  if logicview.truth(logicview.contains({ 0, 1, 9, 16, 17, 24, 41, 49, 55, 59 }, cmd)) then
    self.state = logicview.pymod("HANDLE CMD%d", cmd)
    self.cmd_str = logicview.pymod("%s%d (%s)", { s, cmd, self:cmd_name(cmd) })
  else
    self.state = "HANDLE CMD999"
    a = logicview.pymod("%s%d: {$}", { s, cmd })
    self:putx({ cmd, { a, logicview.add("@", logicview.pymod("%02x %02x %02x %02x %02x %02x", logicview.copy(t))) } })
  end
end
function _decoder.handle_cmd0(self)
  self:putc(Ann.CMD0, "Reset the SD card")
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd1(self)
  local hcs
  self:putc(Ann.CMD1, "Send HCS info and activate the card init process")
  hcs = ((self.arg & (1 << 30)) >> 30)
  self.ss_bit = logicview.idx(logicview.idx(logicview.idx(self.cmd_token_bits, (5 - 4)), 6), 1)
  self.es_bit = logicview.idx(logicview.idx(logicview.idx(self.cmd_token_bits, (5 - 4)), 6), 2)
  self:putb({ Ann.BIT, { logicview.pymod("HCS: %d", hcs) } })
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd9(self)
  self:putc(Ann.CMD9, "Ask card to send its card specific data (CSD)")
  if logicview.truth(logicview.eq(logicview.len(self.read_buf), 0)) then
    self.ss_cmd = self.ss
  end
  _table.insert(self.read_buf, self.miso)
  if logicview.truth((logicview.len(self.read_buf) < logicview.add(16, 4))) then
    return
  end
  self.es_cmd = self.es
  self.read_buf = logicview.slice(self.read_buf, 4, nil, nil)
  self:putx({ Ann.CMD9, { logicview.pymod("CSD: %s", self.read_buf) } })
  self.read_buf = {  }
  self.state = "IDLE"
end
function _decoder.handle_cmd10(self)
  self:putc(Ann.CMD10, "Ask card to send its card identification (CID)")
  _table.insert(self.read_buf, self.miso)
  if logicview.truth((logicview.len(self.read_buf) < 16)) then
    return
  end
  self:putx({ Ann.CMD10, { logicview.pymod("CID: %s", self.read_buf) } })
  self.read_buf = {  }
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd16(self)
  self.blocklen = self.arg
  self:putc(Ann.CMD16, logicview.pymod("Set the block length to %d bytes", self.blocklen))
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd17(self)
  self:putc(Ann.CMD17, "Read a block from address {$}", self.arg)
  self.is_cmd17 = true
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd24(self)
  self:putc(Ann.CMD24, "Write a block to address {$}", self.arg)
  self.is_cmd24 = true
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd49(self)
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd55(self)
  self:putc(Ann.CMD55, "Next command is an application-specific command")
  self.is_acmd = true
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd59(self)
  local crc_on_off, s
  crc_on_off = (self.arg & (1 << 0))
  s = (function() if logicview.truth(logicview.eq(crc_on_off, 1)) then return "on" else return "off" end end)()
  self:putc(Ann.CMD59, logicview.pymod("Turn the SD card CRC option %s", s))
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_acmd41(self)
  self:putc(Ann.ACMD41, "Send HCS info and activate the card init process")
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cmd999(self)
  self.state = "GET RESPONSE R1"
end
function _decoder.handle_cid_register(self)
  local cid, mid, oid, pnm, i, prv, psn
  cid = self.cid
  mid = logicview.idx(cid, 15)
  oid = ((logicview.idx(cid, 14) << 8) | logicview.idx(cid, 13))
  pnm = 0
  for _lv_i in logicview.range(12, (8 - 1), (-1)) do
    i = _lv_i
    pnm = (pnm << 8)
    pnm = (pnm | logicview.idx(cid, i))
    ::continue_1::
  end
  prv = logicview.idx(cid, 7)
  psn = 0
  for _lv_i in logicview.range(6, (3 - 1), (-1)) do
    i = _lv_i
    psn = (psn << 8)
    psn = (psn | logicview.idx(cid, i))
    ::continue_2::
  end
end
function _decoder.handle_response_r1(self, res)
  local putbit, s
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.miso_bits, 7), 1), logicview.idx(logicview.idx(self.miso_bits, 0), 2)
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self:putx({ Ann.R1, { "R1: {$}", logicview.pymod("@%02x", res) } })
  putbit = function(bit, data)
    local b
    b = logicview.idx(self.miso_bits, bit)
    do
      local _lv_a0, _lv_a1 = logicview.idx(b, 1), logicview.idx(b, 2)
      self.ss_bit = _lv_a0
      self.es_bit = _lv_a1
    end
    self:putb({ Ann.BIT, data })
  end
  s = (function() if logicview.truth((res & (1 << 0))) then return "" else return "not " end end)()
  putbit(0, { logicview.pymod("Card is %sin idle state", s) })
  s = (function() if logicview.truth((res & (1 << 1))) then return "" else return "not " end end)()
  putbit(1, { logicview.pymod("Erase sequence %scleared", s) })
  s = (function() if logicview.truth((res & (1 << 2))) then return "I" else return "No i" end end)()
  putbit(2, { logicview.pymod("%sllegal command detected", s) })
  s = (function() if logicview.truth((res & (1 << 3))) then return "failed" else return "was successful" end end)()
  putbit(3, { logicview.pymod("CRC check of last command %s", s) })
  s = (function() if logicview.truth((res & (1 << 4))) then return "E" else return "No e" end end)()
  putbit(4, { logicview.pymod("%srror in the sequence of erase commands", s) })
  s = (function() if logicview.truth((res & (1 << 4))) then return "M" else return "No m" end end)()
  putbit(5, { logicview.pymod("%sisaligned address used in command", s) })
  s = (function() if logicview.truth((res & (1 << 4))) then return "" else return "not " end end)()
  putbit(6, { logicview.pymod("Command argument %soutside allowed range", s) })
  putbit(7, { "Bit 7 (always 0)" })
  if logicview.truth(self.is_cmd17) then
    self.state = "HANDLE DATA BLOCK CMD17"
  end
  if logicview.truth(self.is_cmd24) then
    self.state = "HANDLE DATA BLOCK CMD24"
  end
end
function _decoder.handle_response_r1b(self, res)
end
function _decoder.handle_response_r2(self, res)
end
function _decoder.handle_response_r3(self, res)
end
function _decoder.handle_response_r7(self, res)
end
function _decoder.handle_data_cmd17(self, miso)
  if logicview.truth(self.cmd17_start_token_found) then
    if logicview.truth(logicview.eq(logicview.len(self.read_buf), 0)) then
      self.ss_data = self.ss
      if logicview.truth((not logicview.truth(self.blocklen))) then
        self.blocklen = 512
      end
    end
    _table.insert(self.read_buf, miso)
    if logicview.truth((logicview.len(self.read_buf) < self.blocklen)) then
      return
    end
    if logicview.truth(logicview.eq(logicview.len(self.read_buf), self.blocklen)) then
      self.es_data = self.es
      self:put(self.ss_data, self.es_data, self.out_ann, { Ann.CMD17, { logicview.pymod("Block data: %s", self.read_buf) } })
    elseif logicview.truth(logicview.eq(logicview.len(self.read_buf), logicview.add(self.blocklen, 1))) then
      self.ss_crc = self.ss
    elseif logicview.truth(logicview.eq(logicview.len(self.read_buf), logicview.add(self.blocklen, 2))) then
      self.es_crc = self.es
      self:put(self.ss_crc, self.es_crc, self.out_ann, { Ann.CMD17, { "CRC" } })
      self.state = "IDLE"
    end
  elseif logicview.truth(logicview.eq(miso, 254)) then
    self:put(self.ss, self.es, self.out_ann, { Ann.CMD17, { "Start Block" } })
    self.cmd17_start_token_found = true
  end
end
function _decoder.handle_data_cmd24(self, mosi)
  if logicview.truth(self.cmd24_start_token_found) then
    if logicview.truth(logicview.eq(logicview.len(self.read_buf), 0)) then
      self.ss_data = self.ss
      if logicview.truth((not logicview.truth(self.blocklen))) then
        self.blocklen = 512
      end
    end
    _table.insert(self.read_buf, mosi)
    if logicview.truth((logicview.len(self.read_buf) < self.blocklen)) then
      return
    end
    self.es_data = self.es
    self:put(self.ss_data, self.es_data, self.out_ann, { Ann.CMD24, { logicview.pymod("Block data: %s", self.read_buf) } })
    self.read_buf = {  }
    self.state = "DATA RESPONSE"
  elseif logicview.truth(logicview.eq(mosi, 254)) then
    self:put(self.ss, self.es, self.out_ann, { Ann.CMD24, { "Start Block" } })
    self.cmd24_start_token_found = true
  end
end
function _decoder.handle_data_response(self, miso)
  local m, cls
  miso = (miso & 31)
  if logicview.truth((not logicview.eq((miso & 17), 1))) then
    return
  end
  m = self.miso_bits
  self:put(logicview.idx(logicview.idx(m, 7), 1), logicview.idx(logicview.idx(m, 5), 2), self.out_ann, { Ann.BIT, { "Don't care" } })
  self:put(logicview.idx(logicview.idx(m, 4), 1), logicview.idx(logicview.idx(m, 4), 2), self.out_ann, { Ann.BIT, { "Always 0" } })
  if logicview.truth(logicview.eq(miso, 5)) then
    self:put(logicview.idx(logicview.idx(m, 3), 1), logicview.idx(logicview.idx(m, 1), 2), self.out_ann, { Ann.BIT, { "Data accepted" } })
  elseif logicview.truth(logicview.eq(miso, 11)) then
    self:put(logicview.idx(logicview.idx(m, 3), 1), logicview.idx(logicview.idx(m, 1), 2), self.out_ann, { Ann.BIT, { "Data rejected (CRC error)" } })
  elseif logicview.truth(logicview.eq(miso, 13)) then
    self:put(logicview.idx(logicview.idx(m, 3), 1), logicview.idx(logicview.idx(m, 1), 2), self.out_ann, { Ann.BIT, { "Data rejected (write error)" } })
  end
  self:put(logicview.idx(logicview.idx(m, 0), 1), logicview.idx(logicview.idx(m, 0), 2), self.out_ann, { Ann.BIT, { "Always 1" } })
  cls = (function() if logicview.truth(self.is_cmd24) then return Ann.CMD24 else return nil end end)()
  if logicview.truth((cls ~= nil)) then
    self:put(self.ss, self.es, self.out_ann, { cls, { "Data Response" } })
  end
  if logicview.truth(self.is_cmd24) then
    self.state = "WAIT WHILE CARD BUSY"
    self.busy_first_byte = true
  else
    self.state = "IDLE"
  end
end
function _decoder.wait_while_busy(self, miso)
  local cls
  if logicview.truth((not logicview.eq(miso, 0))) then
    cls = (function() if logicview.truth(self.is_cmd24) then return Ann.CMD24 else return nil end end)()
    if logicview.truth((cls ~= nil)) then
      self:put(self.ss_busy, self.es_busy, self.out_ann, { cls, { "Card is busy" } })
    end
    self.state = "IDLE"
    return
  elseif logicview.truth(self.busy_first_byte) then
    self.ss_busy = self.ss
    self.busy_first_byte = false
  else
    self.es_busy = self.es
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso, a, cmdstr, handle_cmd, s, handle_response
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth((not logicview.contains({ "DATA", "BITS" }, ptype))) then
      return
    end
    if logicview.truth(logicview.eq(ptype, "BITS")) then
      do
        local _lv_a0, _lv_a1 = miso, mosi
        self.miso_bits = _lv_a0
        self.mosi_bits = _lv_a1
      end
      return
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(logicview.eq(mosi, 255)) then
        return
      end
      self.state = "GET COMMAND TOKEN"
      self:handle_command_token(mosi, miso)
    elseif logicview.truth(logicview.eq(self.state, "GET COMMAND TOKEN")) then
      self:handle_command_token(mosi, miso)
    elseif logicview.truth(logicview.startswith(self.state, "HANDLE CMD")) then
      do
        local _lv_a0, _lv_a1 = miso, mosi
        self.miso = _lv_a0
        self.mosi = _lv_a1
      end
      do
        local _lv_a0, _lv_a1 = (function() if logicview.truth(self.is_acmd) then return "a" else return "" end end)(), _string.lower(logicview.slice(self.state, 10, nil, nil))
        a = _lv_a0
        cmdstr = _lv_a1
      end
      handle_cmd = (function() local _v = self[logicview.pymod("handle_%scmd%s", { a, cmdstr })]; if _v == nil then return nil end; return _v end)()
      handle_cmd()
      self.cmd_token = {  }
      self.cmd_token_bits = {  }
      if logicview.truth((function()
  local _v
  _v = self.is_acmd
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(cmdstr, "55"))
  return _v
end)()) then
        self.is_acmd = false
      end
    elseif logicview.truth(logicview.startswith(self.state, "GET RESPONSE")) then
      if logicview.truth(logicview.eq(miso, 255)) then
        return
      end
      s = logicview.pymod("handle_response_%s", _string.lower(logicview.slice(self.state, 13, nil, nil)))
      handle_response = (function() local _v = self[s]; if _v == nil then return nil end; return _v end)()
      self.state = "IDLE"
      handle_response(miso)
    elseif logicview.truth(logicview.eq(self.state, "HANDLE DATA BLOCK CMD17")) then
      self:handle_data_cmd17(miso)
    elseif logicview.truth(logicview.eq(self.state, "HANDLE DATA BLOCK CMD24")) then
      self:handle_data_cmd24(mosi)
    elseif logicview.truth(logicview.eq(self.state, "DATA RESPONSE")) then
      self:handle_data_response(miso)
    elseif logicview.truth(logicview.eq(self.state, "WAIT WHILE CARD BUSY")) then
      self:wait_while_busy(miso)
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
