-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Rudolf Reuter <reuterru@arcor.de>
-- Copyright (C) 2017 Marcus Comstedt <marcus@mc.pp.se>
-- Copyright (C) 2019 Gerhard Sittig <gerhard.sittig@gmx.net>

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
local bitpack, ChannelError, _format_ann_texts, _cmd_table, _is_command, _is_listen_addr, _is_talk_addr, _is_secondary_addr, _is_msb_set, _get_raw_byte, _get_raw_text, _get_command_texts, _get_address_texts, _get_data_text, PIN_DIO1, PIN_DIO2, PIN_DIO3, PIN_DIO4, PIN_DIO5, PIN_DIO6, PIN_DIO7, PIN_DIO8, PIN_EOI, PIN_DAV, PIN_NRFD, PIN_NDAC, PIN_IFC, PIN_SRQ, PIN_ATN, PIN_REN, PIN_CLK, PIN_DATA, ANN_RAW_BIT, ANN_RAW_BYTE, ANN_CMD, ANN_LADDR, ANN_TADDR, ANN_SADDR, ANN_DATA, ANN_EOI, ANN_TEXT, ANN_IEC_PERIPH, ANN_WARN, BIN_RAW, BIN_DATA, Decoder
local _decoder

bitpack = logicview.bitpack
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_format_ann_texts = function(fmts)
  if logicview.truth((not logicview.truth(fmts))) then
    return nil
  end
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(fmts) do
    fmt = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat(fmt, {  }, args)
  end
  return _lv_out
end)()
end
_cmd_table = logicview.dict({ [1] = { "Go To Local", "GTL" }, [4] = { "Selected Device Clear", "SDC" }, [5] = { "Parallel Poll Configure", "PPC" }, [8] = { "Global Execute Trigger", "GET" }, [9] = { "Take Control", "TCT" }, [17] = { "Local Lock Out", "LLO" }, [20] = { "Device Clear", "DCL" }, [21] = { "Parallel Poll Unconfigure", "PPU" }, [24] = { "Serial Poll Enable", "SPE" }, [25] = { "Serial Poll Disable", "SPD" }, [logicview.NIL] = { "Unknown command 0x{cmd:02x}", "command 0x{cmd:02x}", "cmd {cmd:02x}", "C{cmd_ord:c}" }, [63] = { "Unlisten", "UNL" }, [95] = { "Untalk", "UNT" } })
_is_command = function(b)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(0, 32) do _t[#_t + 1] = _v end; return _t end)(), b)) then
    return { true, nil, nil }
  end
  if logicview.truth((function()
  local _v
  _v = logicview.contains((function() local _t = {}; for _v in logicview.range(32, 64) do _t[#_t + 1] = _v end; return _t end)(), b)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((b & 31), 31)
  return _v
end)()) then
    return { true, true, false }
  end
  if logicview.truth((function()
  local _v
  _v = logicview.contains((function() local _t = {}; for _v in logicview.range(64, 96) do _t[#_t + 1] = _v end; return _t end)(), b)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((b & 31), 31)
  return _v
end)()) then
    return { true, false, true }
  end
  return { false, nil, nil }
end
_is_listen_addr = function(b)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(32, 64) do _t[#_t + 1] = _v end; return _t end)(), b)) then
    return (b & 31)
  end
  return nil
end
_is_talk_addr = function(b)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(64, 96) do _t[#_t + 1] = _v end; return _t end)(), b)) then
    return (b & 31)
  end
  return nil
end
_is_secondary_addr = function(b)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(96, 128) do _t[#_t + 1] = _v end; return _t end)(), b)) then
    return (b & 31)
  end
  return nil
end
_is_msb_set = function(b)
  if logicview.truth((b & 128)) then
    return b
  end
  return nil
end
_get_raw_byte = function(b, atn)
  return (function() if logicview.truth(atn) then return (b | 256) else return b end end)()
end
_get_raw_text = function(b, atn)
  return { logicview.pyformat("{leader}{data:02x}", {  }, logicview.dict({ leader = (function() if logicview.truth(atn) then return "/" else return "" end end)(), data = b })) }
end
_get_command_texts = function(b)
  local fmts, known
  fmts = logicview.dget(_cmd_table, b, nil)
  known = (fmts ~= nil)
  if logicview.truth((not logicview.truth(fmts))) then
    fmts = logicview.dget(_cmd_table, nil, nil)
  end
  if logicview.truth((not logicview.truth(fmts))) then
    return { known, nil }
  end
  return { known, _format_ann_texts(fmts) }
end
_get_address_texts = function(b)
  local laddr, taddr, saddr, msb, fmts, addr
  laddr = _is_listen_addr(b)
  taddr = _is_talk_addr(b)
  saddr = _is_secondary_addr(b)
  msb = _is_msb_set(b)
  fmts = nil
  if logicview.truth((laddr ~= nil)) then
    fmts = { "Listen {addr:d}", "L {addr:d}", "L{addr_ord:c}" }
    addr = laddr
  elseif logicview.truth((taddr ~= nil)) then
    fmts = { "Talk {addr:d}", "T {addr:d}", "T{addr_ord:c}" }
    addr = taddr
  elseif logicview.truth((saddr ~= nil)) then
    fmts = { "Secondary {addr:d}", "S {addr:d}", "S{addr_ord:c}" }
    addr = saddr
  elseif logicview.truth((msb ~= nil)) then
    fmts = { "Secondary {addr:d}", "S {addr:d}", "S{addr_ord:c}" }
    addr = msb
  end
  return _format_ann_texts(fmts)
end
_get_data_text = function(b)
  local _control_codes
  _control_codes = logicview.dict({ [0] = "NUL", [1] = "SOH", [2] = "STX", [3] = "ETX", [4] = "EOT", [5] = "ENQ", [6] = "ACK", [7] = "BEL", [8] = "BS", [9] = "TAB", [10] = "LF", [11] = "VT", [12] = "FF", [13] = "CR", [14] = "SO", [15] = "SI", [16] = "DLE", [17] = "DC1", [18] = "DC2", [19] = "DC3", [20] = "DC4", [21] = "NAK", [22] = "SYN", [23] = "ETB", [24] = "CAN", [25] = "EM", [26] = "SUB", [27] = "ESC", [28] = "FS", [29] = "GS", [30] = "RS", [31] = "US" })
  if logicview.truth((function()
  local _v
  _v = logicview.contains((function() local _t = {}; for _v in logicview.range(32, 127) do _t[#_t + 1] = _v end; return _t end)(), b)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.contains({ "[", "]" }, b))
  return _v
end)()) then
    return logicview.pyformat("{:s}", { _string.char(b) }, logicview.dict({}))
  elseif logicview.truth(logicview.contains(_control_codes, b)) then
    return logicview.pyformat("[{:s}]", { logicview.idx(_control_codes, b) }, logicview.dict({}))
  end
  return logicview.pyformat("[{:02x}]", { b }, logicview.dict({}))
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(17) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  PIN_DIO1 = logicview.idx(_lv_seq, 0)
  PIN_DIO2 = logicview.idx(_lv_seq, 1)
  PIN_DIO3 = logicview.idx(_lv_seq, 2)
  PIN_DIO4 = logicview.idx(_lv_seq, 3)
  PIN_DIO5 = logicview.idx(_lv_seq, 4)
  PIN_DIO6 = logicview.idx(_lv_seq, 5)
  PIN_DIO7 = logicview.idx(_lv_seq, 6)
  PIN_DIO8 = logicview.idx(_lv_seq, 7)
  PIN_EOI = logicview.idx(_lv_seq, 8)
  PIN_DAV = logicview.idx(_lv_seq, 9)
  PIN_NRFD = logicview.idx(_lv_seq, 10)
  PIN_NDAC = logicview.idx(_lv_seq, 11)
  PIN_IFC = logicview.idx(_lv_seq, 12)
  PIN_SRQ = logicview.idx(_lv_seq, 13)
  PIN_ATN = logicview.idx(_lv_seq, 14)
  PIN_REN = logicview.idx(_lv_seq, 15)
  PIN_CLK = logicview.idx(_lv_seq, 16)
end
PIN_DATA = PIN_DIO1
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(11) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_RAW_BIT = logicview.idx(_lv_seq, 0)
  ANN_RAW_BYTE = logicview.idx(_lv_seq, 1)
  ANN_CMD = logicview.idx(_lv_seq, 2)
  ANN_LADDR = logicview.idx(_lv_seq, 3)
  ANN_TADDR = logicview.idx(_lv_seq, 4)
  ANN_SADDR = logicview.idx(_lv_seq, 5)
  ANN_DATA = logicview.idx(_lv_seq, 6)
  ANN_EOI = logicview.idx(_lv_seq, 7)
  ANN_TEXT = logicview.idx(_lv_seq, 8)
  ANN_IEC_PERIPH = logicview.idx(_lv_seq, 9)
  ANN_WARN = logicview.idx(_lv_seq, 10)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  BIN_RAW = logicview.idx(_lv_seq, 0)
  BIN_DATA = logicview.idx(_lv_seq, 1)
end
_decoder = {
  api_version = 3,
  id = "ieee488",
  name = "IEEE-488",
  longname = "IEEE-488 GPIB/HPIB/IEC",
  desc = "IEEE-488 General Purpose Interface Bus (GPIB/HPIB or IEC).",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "ieee488" },
  tags = { "PC", "Retro computing" },
  channels = { logicview.dict({ id = "dio1", name = "DIO1/DATA", desc = "Data I/O bit 1, or serial data" }) },
  optional_channels = { logicview.dict({ id = "dio2", name = "DIO2", desc = "Data I/O bit 2" }), logicview.dict({ id = "dio3", name = "DIO3", desc = "Data I/O bit 3" }), logicview.dict({ id = "dio4", name = "DIO4", desc = "Data I/O bit 4" }), logicview.dict({ id = "dio5", name = "DIO5", desc = "Data I/O bit 5" }), logicview.dict({ id = "dio6", name = "DIO6", desc = "Data I/O bit 6" }), logicview.dict({ id = "dio7", name = "DIO7", desc = "Data I/O bit 7" }), logicview.dict({ id = "dio8", name = "DIO8", desc = "Data I/O bit 8" }), logicview.dict({ id = "eoi", name = "EOI", desc = "End or identify" }), logicview.dict({ id = "dav", name = "DAV", desc = "Data valid" }), logicview.dict({ id = "nrfd", name = "NRFD", desc = "Not ready for data" }), logicview.dict({ id = "ndac", name = "NDAC", desc = "Not data accepted" }), logicview.dict({ id = "ifc", name = "IFC", desc = "Interface clear" }), logicview.dict({ id = "srq", name = "SRQ", desc = "Service request" }), logicview.dict({ id = "atn", name = "ATN", desc = "Attention" }), logicview.dict({ id = "ren", name = "REN", desc = "Remote enable" }), logicview.dict({ id = "clk", name = "CLK", desc = "Serial clock" }) },
  options = { logicview.dict({ id = "iec_periph", desc = "Decode Commodore IEC bus peripherals details", default = "no", values = { "no", "yes" } }), logicview.dict({ id = "delim", desc = "Payload data delimiter", default = "eol", values = { "none", "eol" } }) },
  annotations = { { "bit", "IEC bit" }, { "raw", "Raw byte" }, { "cmd", "Command" }, { "laddr", "Listener address" }, { "taddr", "Talker address" }, { "saddr", "Secondary address" }, { "data", "Data byte" }, { "eoi", "EOI" }, { "text", "Talker text" }, { "periph", "IEC bus peripherals" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "IEC bits", { 0 } }, { "raws", "Raw bytes", { 1 } }, { "gpib", "Commands/data", { 2, 3, 4, 5, 6 } }, { "eois", "EOI", { 7 } }, { "texts", "Talker texts", { 8 } }, { "periphs", "IEC peripherals", { 9 } }, { "warnings", "Warnings", { 10 } } },
  binary = { { "raw", "Raw bytes" }, { "data", "Talker bytes" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.curr_raw = nil
  self.curr_atn = nil
  self.curr_eoi = nil
  self.latch_atn = nil
  self.latch_eoi = nil
  self.accu_bytes = {  }
  self.accu_text = {  }
  self.ss_raw = nil
  self.es_raw = nil
  self.ss_eoi = nil
  self.es_eoi = nil
  self.ss_text = nil
  self.es_text = nil
  self.last_talker = nil
  self.last_listener = {  }
  self.last_iec_addr = nil
  self.last_iec_sec = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_bin = self:register(logicview.OUTPUT_BINARY)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.putg(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putbin(self, ss, es, data)
  self:put(ss, es, self.out_bin, data)
end
function _decoder.putpy(self, ss, es, ptype, addr, pdata)
  self:put(ss, es, self.out_python, { ptype, addr, pdata })
end
function _decoder.emit_eoi_ann(self, ss, es)
  self:putg(ss, es, { ANN_EOI, { "EOI" } })
end
function _decoder.emit_bin_ann(self, ss, es, ann_cls, data)
  self:putbin(ss, es, { ann_cls, logicview.bytes(data) })
end
function _decoder.emit_data_ann(self, ss, es, ann_cls, data)
  self:putg(ss, es, { ann_cls, data })
end
function _decoder.emit_warn_ann(self, ss, es, data)
  self:putg(ss, es, { ANN_WARN, data })
end
function _decoder.flush_bytes_text_accu(self)
  local text
  if logicview.truth((function()
  local _v
  _v = self.accu_bytes
  if not logicview.truth(_v) then return _v end
  _v = (self.ss_text ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.es_text ~= nil)
  return _v
end)()) then
    self:emit_bin_ann(self.ss_text, self.es_text, BIN_DATA, logicview.bytes(self.accu_bytes))
    self:putpy(self.ss_text, self.es_text, "TALKER_BYTES", self.last_talker, logicview.bytes(self.accu_bytes))
    self.accu_bytes = {  }
  end
  if logicview.truth((function()
  local _v
  _v = self.accu_text
  if not logicview.truth(_v) then return _v end
  _v = (self.ss_text ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.es_text ~= nil)
  return _v
end)()) then
    text = logicview.join("", self.accu_text)
    self:emit_data_ann(self.ss_text, self.es_text, ANN_TEXT, { text })
    self:putpy(self.ss_text, self.es_text, "TALKER_TEXT", self.last_talker, text)
    self.accu_text = {  }
  end
  do
    local _lv_chain = nil
    self.ss_text = _lv_chain
    self.es_text = _lv_chain
  end
end
function _decoder.check_extra_flush(self, b)
  local term_chars, is_eol, had_eol
  if logicview.truth(logicview.eq(logicview.idx(self.options, "delim"), "none")) then
    return
  end
  if logicview.truth((not logicview.truth(self.accu_bytes))) then
    return
  end
  term_chars = { 10, 13 }
  is_eol = logicview.contains(term_chars, b)
  had_eol = logicview.contains(term_chars, logicview.idx(self.accu_bytes, (-1)))
  if logicview.truth((function()
  local _v
  _v = had_eol
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_eol))
  return _v
end)()) then
    self:flush_bytes_text_accu()
  end
end
function _decoder.handle_ifc_change(self, ifc)
  if logicview.truth(ifc) then
    self.last_talker = nil
    self.last_listener = {  }
    self:flush_bytes_text_accu()
  end
end
function _decoder.handle_eoi_change(self, eoi)
  if logicview.truth(eoi) then
    self.ss_eoi = self.samplenum
    self.curr_eoi = eoi
  else
    self.es_eoi = self.samplenum
    if logicview.truth((function()
  local _v
  _v = self.ss_eoi
  if not logicview.truth(_v) then return _v end
  _v = self.latch_eoi
  return _v
end)()) then
      self:emit_eoi_ann(self.ss_eoi, self.es_eoi)
    end
    self.es_text = self.es_eoi
    self:flush_bytes_text_accu()
    do
      local _lv_chain = nil
      self.ss_eoi = _lv_chain
      self.es_eoi = _lv_chain
    end
    self.curr_eoi = nil
  end
end
function _decoder.handle_atn_change(self, atn)
  self.curr_atn = atn
  if logicview.truth(atn) then
    self:flush_bytes_text_accu()
  end
end
function _decoder.handle_iec_periph(self, ss, es, addr, sec, data)
  local _iec_addr_names, _iec_disk_range, name, subcmd, channel, channel_ord, subcmd_fmts, texts
  if logicview.truth((not logicview.eq(logicview.idx(self.options, "iec_periph"), "yes"))) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = (addr == nil)
  if not logicview.truth(_v) then return _v end
  _v = (sec == nil)
  if not logicview.truth(_v) then return _v end
  _v = (data == nil)
  return _v
end)()) then
    self.last_iec_addr = nil
    self.last_iec_sec = nil
    return
  end
  _iec_addr_names = logicview.dict({ [8] = "Disk 0", [9] = "Disk 1" })
  _iec_disk_range = (function() local _t = {}; for _v in logicview.range(8, 16) do _t[#_t + 1] = _v end; return _t end)()
  if logicview.truth((addr ~= nil)) then
    self.last_iec_addr = addr
    name = logicview.dget(_iec_addr_names, addr, nil)
    if logicview.truth(name) then
      self:emit_data_ann(ss, es, ANN_IEC_PERIPH, { name })
    end
  end
  addr = self.last_iec_addr
  if logicview.truth((sec ~= nil)) then
    self.last_iec_sec = sec
    do
      local _lv_a0, _lv_a1 = (sec & 240), (sec & 15)
      subcmd = _lv_a0
      channel = _lv_a1
    end
    channel_ord = logicview.add(_string.byte("0"), channel)
    if logicview.truth((function()
  local _v
  _v = (addr ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains(_iec_disk_range, addr)
  return _v
end)()) then
      subcmd_fmts = logicview.dget(logicview.dict({ [96] = { "Reopen {ch:d}", "Re {ch:d}", "R{ch_ord:c}" }, [224] = { "Close {ch:d}", "Cl {ch:d}", "C{ch_ord:c}" }, [240] = { "Open {ch:d}", "Op {ch:d}", "O{ch_ord:c}" } }), subcmd, nil)
      if logicview.truth(subcmd_fmts) then
        texts = _format_ann_texts(subcmd_fmts)
        self:emit_data_ann(ss, es, ANN_IEC_PERIPH, texts)
      end
    end
  end
  sec = self.last_iec_sec
  if logicview.truth((data ~= nil)) then
    if logicview.truth((function()
  local _v
  _v = (addr == nil)
  if logicview.truth(_v) then return _v end
  _v = (sec == nil)
  return _v
end)()) then
      return
    end
  end
end
function _decoder.handle_data_byte(self)
  local b, texts, ann_cls, upd_iec, py_type, py_peers, is_cmd, is_unl, is_unt, laddr, taddr, saddr, msb, known, warn_texts, py_addr, addr, text
  if logicview.truth((not logicview.truth(self.curr_atn))) then
    self:check_extra_flush(self.curr_raw)
  end
  b = self.curr_raw
  texts = _get_raw_text(b, self.curr_atn)
  self:emit_data_ann(self.ss_raw, self.es_raw, ANN_RAW_BYTE, texts)
  self:emit_bin_ann(self.ss_raw, self.es_raw, BIN_RAW, logicview.to_bytes(b, 1, 'big'))
  self:putpy(self.ss_raw, self.es_raw, "GPIB_RAW", nil, _get_raw_byte(b, self.curr_atn))
  if logicview.truth(self.curr_atn) then
    ann_cls = nil
    upd_iec = { false }
    py_type = nil
    py_peers = false
    do
      local _lv_seq = _is_command(b)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      is_cmd = logicview.idx(_lv_seq, 0)
      is_unl = logicview.idx(_lv_seq, 1)
      is_unt = logicview.idx(_lv_seq, 2)
    end
    laddr = _is_listen_addr(b)
    taddr = _is_talk_addr(b)
    saddr = _is_secondary_addr(b)
    msb = _is_msb_set(b)
    if logicview.truth(is_cmd) then
      do
        local _lv_seq = _get_command_texts(b)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        known = logicview.idx(_lv_seq, 0)
        texts = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((not logicview.truth(known))) then
        warn_texts = { "Unknown GPIB command", "unknown", "UNK" }
        self:emit_warn_ann(self.ss_raw, self.es_raw, warn_texts)
      end
      ann_cls = ANN_CMD
      do
        local _lv_a0, _lv_a1 = "COMMAND", nil
        py_type = _lv_a0
        py_addr = _lv_a1
      end
      if logicview.truth(is_unl) then
        self.last_listener = {  }
        py_peers = true
      end
      if logicview.truth(is_unt) then
        self.last_talker = nil
        py_peers = true
      end
      if logicview.truth((function()
  local _v
  _v = is_unl
  if logicview.truth(_v) then return _v end
  _v = is_unt
  return _v
end)()) then
        upd_iec = { true, nil, nil, nil }
      end
    elseif logicview.truth((laddr ~= nil)) then
      addr = laddr
      texts = _get_address_texts(b)
      ann_cls = ANN_LADDR
      do
        local _lv_a0, _lv_a1 = "LISTEN", addr
        py_type = _lv_a0
        py_addr = _lv_a1
      end
      if logicview.truth(logicview.eq(addr, self.last_talker)) then
        self.last_talker = nil
      end
      _table.insert(self.last_listener, addr)
      upd_iec = { true, addr, nil, nil }
      py_peers = true
    elseif logicview.truth((taddr ~= nil)) then
      addr = taddr
      texts = _get_address_texts(b)
      ann_cls = ANN_TADDR
      do
        local _lv_a0, _lv_a1 = "TALK", addr
        py_type = _lv_a0
        py_addr = _lv_a1
      end
      if logicview.truth(logicview.contains(self.last_listener, addr)) then
        (function() local _i = logicview.list_index(self.last_listener, addr); _table.remove(self.last_listener, _i + 1) end)()
      end
      self.last_talker = addr
      upd_iec = { true, addr, nil, nil }
      py_peers = true
    elseif logicview.truth((saddr ~= nil)) then
      addr = saddr
      texts = _get_address_texts(b)
      ann_cls = ANN_SADDR
      upd_iec = { true, nil, b, nil }
      do
        local _lv_a0, _lv_a1 = "SECONDARY", addr
        py_type = _lv_a0
        py_addr = _lv_a1
      end
    elseif logicview.truth((msb ~= nil)) then
      texts = _get_address_texts(b)
      ann_cls = ANN_SADDR
      upd_iec = { true, nil, b, nil }
      do
        local _lv_a0, _lv_a1 = "MSB_SET", b
        py_type = _lv_a0
        py_addr = _lv_a1
      end
    end
    if logicview.truth((function()
  local _v
  _v = (ann_cls ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (texts ~= nil)
  return _v
end)()) then
      self:emit_data_ann(self.ss_raw, self.es_raw, ann_cls, texts)
    end
    if logicview.truth(logicview.idx(upd_iec, 0)) then
      self:handle_iec_periph(self.ss_raw, self.es_raw, logicview.idx(upd_iec, 1), logicview.idx(upd_iec, 2), logicview.idx(upd_iec, 3))
    end
    if logicview.truth(py_type) then
      self:putpy(self.ss_raw, self.es_raw, py_type, py_addr, b)
    end
    if logicview.truth(py_peers) then
      (function() _table.sort(self.last_listener) end)()
      self:putpy(self.ss_raw, self.es_raw, "TALK_LISTEN", self.last_talker, self.last_listener)
    end
  else
    _table.insert(self.accu_bytes, b)
    text = _get_data_text(b)
    if logicview.truth((not logicview.truth(self.accu_text))) then
      self.ss_text = self.ss_raw
    end
    _table.insert(self.accu_text, text)
    self.es_text = self.es_raw
    self:emit_data_ann(self.ss_raw, self.es_raw, ANN_DATA, { text })
    self:handle_iec_periph(self.ss_raw, self.es_raw, nil, nil, b)
    self:putpy(self.ss_raw, self.es_raw, "DATA_BYTE", self.last_talker, b)
  end
end
function _decoder.handle_dav_change(self, dav, data)
  if logicview.truth(dav) then
    self.ss_raw = self.samplenum
    self.curr_raw = bitpack(data)
    self.latch_atn = self.curr_atn
    self.latch_eoi = self.curr_eoi
    return
  end
  self.es_raw = self.samplenum
  self:handle_data_byte()
  do
    local _lv_chain = nil
    self.ss_raw = _lv_chain
    self.es_raw = _lv_chain
  end
  self.curr_raw = nil
end
function _decoder.inject_dav_phase(self, ss, es, data)
  self.ss_raw = ss
  self.curr_raw = bitpack(data)
  self.latch_atn = self.curr_atn
  self.latch_eoi = self.curr_eoi
  self.es_raw = es
  self:handle_data_byte()
  do
    local _lv_chain = nil
    self.ss_raw = _lv_chain
    self.es_raw = _lv_chain
  end
  self.curr_raw = nil
end
function _decoder.invert_pins(self, pins)
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(pins) do
    p = _lv_item
    _lv_out[#_lv_out + 1] = (function() if logicview.truth(logicview.contains({ 0, 1 }, p)) then return (1 - p) else return p end end)()
  end
  return _lv_out
end)()
end
function _decoder.decode_serial(self, has_clk, has_data_1, has_atn, has_srq)
  local STEP_WAIT_READY_TO_SEND, STEP_WAIT_READY_FOR_DATA, STEP_PREP_DATA_TEST_EOI, STEP_CLOCK_DATA_BITS, step_wait_conds, step, bits, dio1, dio2, dio3, dio4, dio5, dio6, dio7, dio8, eoi, dav, nrfd, ndac, ifc, srq, atn, ren, clk, pins, data, ss_byte, ss_bit, es_bit, es_byte
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(has_clk))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(has_data_1))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(has_atn))
  return _v
end)()) then
    _error(ChannelError("IEC bus needs at least ATN and serial CLK and DATA."), 0)
  end
  do
    local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    STEP_WAIT_READY_TO_SEND = logicview.idx(_lv_seq, 0)
    STEP_WAIT_READY_FOR_DATA = logicview.idx(_lv_seq, 1)
    STEP_PREP_DATA_TEST_EOI = logicview.idx(_lv_seq, 2)
    STEP_CLOCK_DATA_BITS = logicview.idx(_lv_seq, 3)
  end
  step_wait_conds = { { logicview.dict({ [PIN_ATN] = "f" }), logicview.dict({ [PIN_DATA] = "l", [PIN_CLK] = "h" }) }, { logicview.dict({ [PIN_ATN] = "f" }), logicview.dict({ [PIN_DATA] = "h", [PIN_CLK] = "h" }), logicview.dict({ [PIN_CLK] = "l" }) }, { logicview.dict({ [PIN_ATN] = "f" }), logicview.dict({ [PIN_DATA] = "f" }), logicview.dict({ [PIN_CLK] = "l" }) }, { logicview.dict({ [PIN_ATN] = "f" }), logicview.dict({ [PIN_CLK] = "e" }) } }
  step = STEP_WAIT_READY_TO_SEND
  bits = {  }
  while true do
    do
      local _lv_seq = self:wait(logicview.idx(step_wait_conds, step))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      dio1 = logicview.idx(_lv_seq, 0)
      dio2 = logicview.idx(_lv_seq, 1)
      dio3 = logicview.idx(_lv_seq, 2)
      dio4 = logicview.idx(_lv_seq, 3)
      dio5 = logicview.idx(_lv_seq, 4)
      dio6 = logicview.idx(_lv_seq, 5)
      dio7 = logicview.idx(_lv_seq, 6)
      dio8 = logicview.idx(_lv_seq, 7)
      eoi = logicview.idx(_lv_seq, 8)
      dav = logicview.idx(_lv_seq, 9)
      nrfd = logicview.idx(_lv_seq, 10)
      ndac = logicview.idx(_lv_seq, 11)
      ifc = logicview.idx(_lv_seq, 12)
      srq = logicview.idx(_lv_seq, 13)
      atn = logicview.idx(_lv_seq, 14)
      ren = logicview.idx(_lv_seq, 15)
      clk = logicview.idx(_lv_seq, 16)
    end
    pins = { dio1, dio2, dio3, dio4, dio5, dio6, dio7, dio8, eoi, dav, nrfd, ndac, ifc, srq, atn, ren, clk }
    do
      local _lv_a0, _lv_a1 = logicview.idx(pins, PIN_DATA), logicview.idx(pins, PIN_CLK)
      data = _lv_a0
      clk = _lv_a1
    end
    do
      local _lv_seq = self:invert_pins({ logicview.idx(pins, PIN_ATN) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      atn = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth((self.matched & 1)) then
      step = STEP_WAIT_READY_TO_SEND
    end
    if logicview.truth(logicview.eq(step, STEP_WAIT_READY_TO_SEND)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        step = STEP_WAIT_READY_FOR_DATA
      end
    elseif logicview.truth(logicview.eq(step, STEP_WAIT_READY_FOR_DATA)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        ss_byte = self.samplenum
        self:handle_atn_change(atn)
        if logicview.truth(self.curr_eoi) then
          self:handle_eoi_change(false)
        end
        bits = {  }
        step = STEP_PREP_DATA_TEST_EOI
      elseif logicview.truth(logicview.eq(clk, 0)) then
        step = STEP_WAIT_READY_TO_SEND
      end
    elseif logicview.truth(logicview.eq(step, STEP_PREP_DATA_TEST_EOI)) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
        self:handle_eoi_change(true)
      elseif logicview.truth(logicview.eq(clk, 0)) then
        step = STEP_CLOCK_DATA_BITS
        ss_bit = self.samplenum
      end
    elseif logicview.truth(logicview.eq(step, STEP_CLOCK_DATA_BITS)) then
      if logicview.truth((self.matched & 2)) then
        if logicview.truth(logicview.eq(clk, 1)) then
          _table.insert(bits, data)
        elseif logicview.truth(logicview.eq(clk, 0)) then
          es_bit = self.samplenum
          self:emit_data_ann(ss_bit, es_bit, ANN_RAW_BIT, { logicview.pyformat("{:d}", { logicview.idx(bits, (-1)) }, logicview.dict({})) })
          self:putpy(ss_bit, es_bit, "IEC_BIT", nil, logicview.idx(bits, (-1)))
          ss_bit = self.samplenum
          if logicview.truth(logicview.eq(logicview.len(bits), 8)) then
            es_byte = self.samplenum
            self:inject_dav_phase(ss_byte, es_byte, bits)
            if logicview.truth(self.curr_eoi) then
              self:handle_eoi_change(false)
            end
            step = STEP_WAIT_READY_TO_SEND
          end
        end
      end
    end
    ::continue_1::
  end
end
function _decoder.check_bit(self, d)
  local v
  v = (self.matched & (1 << d))
  return logicview.eq((v >> d), 1)
end
function _decoder.decode_parallel(self, has_data_n, has_dav, has_atn, has_eoi, has_srq)
  local has_ifc, waitcond, idx_dav, idx_atn, idx_eoi, idx_ifc, pins
  if logicview.truth((function()
  local _v
  _v = logicview.contains(has_data_n, false)
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(has_dav))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(has_atn))
  return _v
end)()) then
    _error(ChannelError("IEEE-488 needs at least ATN and DAV and eight DIO lines."), 0)
  end
  has_ifc = self:has_channel(PIN_IFC)
  waitcond = {  }
  idx_dav = logicview.len(waitcond)
  _table.insert(waitcond, logicview.dict({ [PIN_DAV] = "l" }))
  idx_atn = logicview.len(waitcond)
  _table.insert(waitcond, logicview.dict({ [PIN_ATN] = "l" }))
  idx_eoi = nil
  if logicview.truth(has_eoi) then
    idx_eoi = logicview.len(waitcond)
    _table.insert(waitcond, logicview.dict({ [PIN_EOI] = "l" }))
  end
  idx_ifc = nil
  if logicview.truth(has_ifc) then
    idx_ifc = logicview.len(waitcond)
    _table.insert(waitcond, logicview.dict({ [PIN_IFC] = "l" }))
  end
  while true do
    pins = self:wait(waitcond)
    pins = self:invert_pins(pins)
    if logicview.truth((function()
  local _v
  _v = (idx_ifc ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = self:check_bit(idx_ifc)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_IFC), 1)
  return _v
end)()) then
      self:handle_ifc_change(logicview.idx(pins, PIN_IFC))
    end
    if logicview.truth((function()
  local _v
  _v = (idx_eoi ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = self:check_bit(idx_eoi)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_EOI), 1)
  return _v
end)()) then
      self:handle_eoi_change(logicview.idx(pins, PIN_EOI))
    end
    if logicview.truth((function()
  local _v
  _v = self:check_bit(idx_atn)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_ATN), 1)
  return _v
end)()) then
      self:handle_atn_change(logicview.idx(pins, PIN_ATN))
    end
    if logicview.truth(self:check_bit(idx_dav)) then
      self:handle_dav_change(logicview.idx(pins, PIN_DAV), logicview.slice(pins, PIN_DIO1, logicview.add(PIN_DIO8, 1), nil))
    end
    if logicview.truth((function()
  local _v
  _v = self:check_bit(idx_atn)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_ATN), 0)
  return _v
end)()) then
      self:handle_atn_change(logicview.idx(pins, PIN_ATN))
    end
    if logicview.truth((function()
  local _v
  _v = (idx_eoi ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = self:check_bit(idx_eoi)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_EOI), 0)
  return _v
end)()) then
      self:handle_eoi_change(logicview.idx(pins, PIN_EOI))
    end
    if logicview.truth((function()
  local _v
  _v = (idx_ifc ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = self:check_bit(idx_ifc)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(pins, PIN_IFC), 0)
  return _v
end)()) then
      self:handle_ifc_change(logicview.idx(pins, PIN_IFC))
    end
    logicview.setidx(logicview.idx(waitcond, idx_dav), PIN_DAV, "e")
    logicview.setidx(logicview.idx(waitcond, idx_atn), PIN_ATN, "e")
    if logicview.truth(has_eoi) then
      logicview.setidx(logicview.idx(waitcond, idx_eoi), PIN_EOI, "e")
    end
    if logicview.truth(has_ifc) then
      logicview.setidx(logicview.idx(waitcond, idx_ifc), PIN_IFC, "e")
    end
    ::continue_2::
  end
end
function _decoder.decode(self)
  local has_clk, has_data_1, has_data_n, has_dav, has_atn, has_eoi, has_srq
  has_clk = self:has_channel(PIN_CLK)
  has_data_1 = self:has_channel(PIN_DIO1)
  has_data_n = { logicview.truth((function()
  local _lv_out = {}
  for _lv_i in logicview.range(PIN_DIO1, logicview.add(PIN_DIO8, 1)) do
    pin = _lv_i
    _lv_out[#_lv_out + 1] = self:has_channel(pin)
  end
  return _lv_out
end)()) }
  has_dav = self:has_channel(PIN_DAV)
  has_atn = self:has_channel(PIN_ATN)
  has_eoi = self:has_channel(PIN_EOI)
  has_srq = self:has_channel(PIN_SRQ)
  if logicview.truth(has_clk) then
    self:decode_serial(has_clk, has_data_1, has_atn, has_srq)
  else
    self:decode_parallel(has_data_n, has_dav, has_atn, has_eoi, has_srq)
  end
end

return _decoder
