-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Google, Inc
-- Copyright (C) 2018 davidanger <davidanger@163.com>
-- Copyright (C) 2018 Peter Hazenberg <sigrok@haas-en-berg.nl>

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
local struct, zlib, UI_US, THRESHOLD_US, CTRL_TYPES, DATA_TYPES, EXTENDED_TYPES, DEC4B5B, SYM_ERR, SYNC1, SYNC2, SYNC3, RST1, RST2, EOP, SYNC_CODES, HRST_CODES, SOP_SEQUENCES, START_OF_PACKETS, SYM_NAME, RDO_FLAGS, BIST_MODES, VDM_CMDS, VDM_ACK, EPR_MODE_ACTION, EPR_MODE_DATA, EXT_CONTROL_MSG_TYPES, SamplerateError, Decoder
local _decoder

struct = logicview.struct
zlib = { crc32 = logicview.crc32 }
UI_US = (1000000 / 600000.0)
THRESHOLD_US = (logicview.add(UI_US, logicview.mul(2, UI_US)) / 2)
CTRL_TYPES = logicview.dict({ [0] = "reserved", [1] = "GOOD CRC", [2] = "GOTO MIN", [3] = "ACCEPT", [4] = "REJECT", [5] = "PING", [6] = "PS RDY", [7] = "GET SOURCE CAP", [8] = "GET SINK CAP", [9] = "DR SWAP", [10] = "PR SWAP", [11] = "VCONN SWAP", [12] = "WAIT", [13] = "SOFT RESET", [14] = "reserved", [15] = "reserved", [16] = "Not Supported", [17] = "Get_Source_Cap_Extended", [18] = "Get_Status", [19] = "FR_Swap", [20] = "Get_PPS_Status", [21] = "Get_Country_Codes", [22] = "Get_Sink_Cap_Extended", [23] = "Get_Source_Info", [24] = "Get_Revision" })
DATA_TYPES = logicview.dict({ [1] = "SOURCE CAP", [2] = "REQUEST", [3] = "BIST", [4] = "SINK CAP", [5] = "Battery_Status", [6] = "Alert", [7] = "Get_Country_Info", [8] = "Enter_USB", [9] = "EPR_Request", [10] = "EPR_Mode", [11] = "Source_Info", [12] = "Revision", [15] = "VDM" })
EXTENDED_TYPES = logicview.dict({ [1] = "Source_Cap_Extended", [2] = "Status", [3] = "Get_Battery_Cap", [4] = "Get_Battery_Status", [5] = "Battery_Cap", [6] = "Get_Manufacturer_Info", [7] = "Manufacturer_Info", [8] = "Security_Request", [9] = "Security_Response", [10] = "Firmware_Update_Request", [11] = "Firmware_Update_Response", [12] = "PPS_Status", [13] = "Country_Info", [14] = "Country_Codes", [15] = "Sink_Capabilities_Extended", [16] = "Extended_Control", [17] = "EPR_Source_Capabilities", [18] = "EPR_Sink_Capabilities", [30] = "Vendor_Defined_Extended" })
DEC4B5B = { 16, 16, 16, 16, 16, 16, 19, 20, 16, 1, 4, 5, 16, 22, 6, 7, 16, 18, 8, 9, 2, 3, 10, 11, 17, 21, 12, 13, 14, 15, 0, 16 }
SYM_ERR = 16
SYNC1 = 17
SYNC2 = 18
SYNC3 = 19
RST1 = 20
RST2 = 21
EOP = 22
SYNC_CODES = { SYNC1, SYNC2, SYNC3 }
HRST_CODES = { RST1, RST1, RST1, RST2 }
SOP_SEQUENCES = { { SYNC1, SYNC1, SYNC1, SYNC2 }, { SYNC1, SYNC1, SYNC3, SYNC3 }, { SYNC1, SYNC3, SYNC1, SYNC3 }, { SYNC1, RST2, RST2, SYNC3 }, { SYNC1, RST2, SYNC3, SYNC2 }, { RST1, SYNC1, RST1, SYNC3 }, { RST1, RST1, RST1, RST2 } }
START_OF_PACKETS = logicview.dict({ [logicview.idx(SOP_SEQUENCES, 0)] = "SOP", [logicview.idx(SOP_SEQUENCES, 1)] = "SOP'", [logicview.idx(SOP_SEQUENCES, 2)] = "SOP\"", [logicview.idx(SOP_SEQUENCES, 3)] = "SOP' Debug", [logicview.idx(SOP_SEQUENCES, 4)] = "SOP\" Debug", [logicview.idx(SOP_SEQUENCES, 5)] = "Cable Reset", [logicview.idx(SOP_SEQUENCES, 6)] = "Hard Reset" })
SYM_NAME = { { "0x0", "0" }, { "0x1", "1" }, { "0x2", "2" }, { "0x3", "3" }, { "0x4", "4" }, { "0x5", "5" }, { "0x6", "6" }, { "0x7", "7" }, { "0x8", "8" }, { "0x9", "9" }, { "0xA", "A" }, { "0xB", "B" }, { "0xC", "C" }, { "0xD", "D" }, { "0xE", "E" }, { "0xF", "F" }, { "ERROR", "X" }, { "SYNC-1", "S1" }, { "SYNC-2", "S2" }, { "SYNC-3", "S3" }, { "RST-1", "R1" }, { "RST-2", "R2" }, { "EOP", "#" } }
RDO_FLAGS = logicview.dict({ [(1 << 23)] = "unchunked", [(1 << 24)] = "no_suspend", [(1 << 25)] = "comm_cap", [(1 << 26)] = "cap_mismatch", [(1 << 27)] = "give_back" })
BIST_MODES = logicview.dict({ [0] = "Receiver", [1] = "Transmit", [2] = "Counters", [3] = "Carrier 0", [4] = "Carrier 1", [5] = "Carrier 2", [6] = "Carrier 3", [7] = "Eye" })
VDM_CMDS = logicview.dict({ [1] = "Disc Ident", [2] = "Disc SVID", [3] = "Disc Mode", [4] = "Enter Mode", [5] = "Exit Mode", [6] = "Attention", [16] = "DP Status", [17] = "DP Configure" })
VDM_ACK = { "REQ", "ACK", "NAK", "BSY" }
EPR_MODE_ACTION = logicview.dict({ [1] = "Enter", [2] = "Enter Acknowledged", [3] = "Enter Succeeded", [4] = "Enter Failed", [5] = "Exit" })
EPR_MODE_DATA = logicview.dict({ [0] = "Unknown cause", [1] = "Cable not EPR capable", [2] = "Source failed to become Vconn source", [3] = "EPR Mode Capable bit not set in RDO", [4] = "Source unable to enter EPR Mode at this time", [5] = "EPR Mode Capable bit not set in PDO" })
EXT_CONTROL_MSG_TYPES = logicview.dict({ [1] = "EPR Get Source_Cap", [2] = "EPR Get Sink Cap", [3] = "EPR KeepAlive", [4] = "EPR KeepAlive Ack" })
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "usb_power_delivery",
  name = "USB PD",
  longname = "USB Power Delivery",
  desc = "USB Power Delivery protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "usb_pd" },
  tags = { "PC" },
  channels = { logicview.dict({ id = "cc1", name = "CC1", desc = "Configuration Channel 1" }) },
  optional_channels = { logicview.dict({ id = "cc2", name = "CC2", desc = "Configuration Channel 2" }) },
  options = { logicview.dict({ id = "fulltext", desc = "Full text decoding of packets", default = "no", values = { "yes", "no" } }) },
  annotations = { { "type", "Packet Type" }, { "preamble", "Preamble" }, { "sop", "Start of Packet" }, { "header", "Header" }, { "data", "Data" }, { "crc", "Checksum" }, { "eop", "End Of Packet" }, { "sym", "4b5b symbols" }, { "warnings", "Warnings" }, { "src", "Source Message" }, { "snk", "Sink Message" }, { "payload", "Payload" }, { "text", "Plain text" } },
  annotation_rows = { { "4b5b", "Symbols", { 7 } }, { "phase", "Parts", { 1, 2, 3, 4, 5, 6 } }, { "payload", "Payload", { 11 } }, { "type", "Type", { 0, 9, 10 } }, { "warnings", "Warnings", { 8 } }, { "text", "Full text", { 12 } } },
  binary = { { "raw-data", "RAW binary data" } }
}
function _decoder.get_request(self, rdo)
  local pos, op_ma, max_ma, mark, op_v, op_a, t_settings, op_w, mp_w, max_a, t_flags, f, t_pdo
  pos = ((rdo >> 28) & 15)
  op_ma = logicview.mul(((rdo >> 10) & 1023), 0.01)
  max_ma = logicview.mul((rdo & 1023), 0.01)
  mark = logicview.idx(self.cap_mark, pos)
  if logicview.truth(logicview.eq(mark, 3)) then
    op_v = logicview.mul(((rdo >> 9) & 2047), 0.02)
    op_a = logicview.mul((rdo & 255), 0.05)
    t_settings = logicview.pymod("%gV %gA", { op_v, op_a })
  elseif logicview.truth(logicview.eq(mark, 2)) then
    op_w = logicview.mul(((rdo >> 10) & 1023), 0.25)
    mp_w = logicview.mul((rdo & 1023), 0.25)
    t_settings = logicview.pymod("%gW (operating)", op_w)
  else
    op_a = logicview.mul(((rdo >> 10) & 1023), 0.01)
    max_a = logicview.mul((rdo & 1023), 0.01)
    t_settings = logicview.pymod("%gA (operating) / %gA (max)", { op_a, max_a })
  end
  t_flags = ""
  for _lv_item in logicview.iter(logicview.sorted((function() local _t = {}; for _k in _pairs(RDO_FLAGS) do _t[#_t + 1] = _k end; return _t end)(), nil)) do
    f = _lv_item
    if logicview.truth((rdo & f)) then
      t_flags = logicview.add(t_flags, logicview.add(logicview.add(" [", logicview.idx(RDO_FLAGS, f)), "]"))
    end
    ::continue_1::
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _k in _pairs(self.stored_pdos) do _t[#_t + 1] = _k end; return _t end)(), pos)) then
    t_pdo = logicview.pymod("#%d: %s", { pos, logicview.idx(self.stored_pdos, pos) })
  else
    t_pdo = logicview.pymod("#%d", pos)
  end
  return logicview.pymod("(PDO %s) %s%s", { t_pdo, t_settings, t_flags })
end
function _decoder.get_source_sink_cap(self, pdo, idx, source)
  local t1, flags, t_name, mv, ma, p, minv, maxv, mw, t2, t_flags, f
  t1 = ((pdo >> 30) & 3)
  logicview.setidx(self.cap_mark, idx, t1)
  flags = logicview.dict({  })
  if logicview.truth(logicview.eq(t1, 0)) then
    t_name = "Fixed"
    if logicview.truth(source) then
      flags = logicview.dict({ [(1 << 29)] = "dual_role_power", [(1 << 28)] = "suspend", [(1 << 27)] = "unconstrained", [(1 << 26)] = "comm_cap", [(1 << 25)] = "dual_role_data", [(1 << 24)] = "unchunked" })
    else
      flags = logicview.dict({ [(1 << 29)] = "dual_role_power", [(1 << 28)] = "high_capability", [(1 << 27)] = "unconstrained", [(1 << 26)] = "comm_cap", [(1 << 25)] = "dual_role_data", [(1 << 23)] = "fr_swap default power", [(2 << 23)] = "fr_swap 1.5 A", [(3 << 23)] = "fr_swap 3.0 A" })
    end
    mv = logicview.mul(((pdo >> 10) & 1023), 0.05)
    ma = logicview.mul(((pdo >> 0) & 1023), 0.01)
    p = logicview.pymod("%gV %gA (%gW)", { mv, ma, logicview.mul(mv, ma) })
    logicview.setidx(self.stored_pdos, idx, logicview.pymod("%s %gV", { t_name, mv }))
  elseif logicview.truth(logicview.eq(t1, 1)) then
    t_name = "Battery"
    flags = logicview.dict({  })
    minv = logicview.mul(((pdo >> 10) & 1023), 0.05)
    maxv = logicview.mul(((pdo >> 20) & 1023), 0.05)
    mw = logicview.mul(((pdo >> 0) & 1023), 0.25)
    p = logicview.pymod("%g/%gV %gW", { minv, maxv, mw })
    logicview.setidx(self.stored_pdos, idx, logicview.pymod("%s %g/%gV", { t_name, minv, maxv }))
  elseif logicview.truth(logicview.eq(t1, 2)) then
    t_name = "Variable"
    flags = logicview.dict({  })
    minv = logicview.mul(((pdo >> 10) & 1023), 0.05)
    maxv = logicview.mul(((pdo >> 20) & 1023), 0.05)
    ma = logicview.mul(((pdo >> 0) & 1023), 0.01)
    p = logicview.pymod("%g/%gV %gA (%gW)", { minv, maxv, ma, logicview.mul(maxv, ma) })
    logicview.setidx(self.stored_pdos, idx, logicview.pymod("%s %g/%gV", { t_name, minv, maxv }))
  elseif logicview.truth(logicview.eq(t1, 3)) then
    t2 = ((pdo >> 28) & 3)
    if logicview.truth(logicview.eq(t2, 0)) then
      t_name = "PPS"
      flags = logicview.dict({ [(1 << 29)] = "power_limited" })
      minv = logicview.mul(((pdo >> 8) & 255), 0.1)
      maxv = logicview.mul(((pdo >> 17) & 255), 0.1)
      ma = logicview.mul(((pdo >> 0) & 255), 0.05)
      p = logicview.pymod("%g/%gV %gA (%gW)", { minv, maxv, ma, logicview.mul(maxv, ma) })
      if logicview.truth(((pdo >> 27) & 1)) then
        p = logicview.add(p, " [limited]")
      end
      logicview.setidx(self.stored_pdos, idx, logicview.pymod("%s %g/%gV", { t_name, minv, maxv }))
    else
      t_name = logicview.add("Reserved APDO: ", logicview.bin(t2))
      p = logicview.pymod("[raw: %s]", logicview.bin(pdo))
      logicview.setidx(self.stored_pdos, idx, logicview.pymod("%s %s", { t_name, p }))
    end
  end
  t_flags = ""
  for _lv_item in logicview.iter(logicview.sorted((function() local _t = {}; for _k in _pairs(flags) do _t[#_t + 1] = _k end; return _t end)(), nil)) do
    f = _lv_item
    if logicview.truth((pdo & f)) then
      t_flags = logicview.add(t_flags, logicview.add(logicview.add(" [", logicview.idx(flags, f)), "]"))
    end
    ::continue_2::
  end
  return logicview.pymod("[%s] %s%s", { t_name, p, t_flags })
end
function _decoder.get_vdm(self, idx, data)
  local vid, struct, txt, cmd, src, ack, pos, ver
  if logicview.truth(logicview.eq(idx, 0)) then
    vid = (data >> 16)
    struct = (data & (1 << 15))
    txt = "VDM"
    if logicview.truth(struct) then
      cmd = (data & 31)
      src = (data & (1 << 5))
      ack = ((data >> 6) & 3)
      pos = ((data >> 8) & 7)
      ver = ((data >> 13) & 3)
      txt = logicview.add(logicview.idx(VDM_ACK, ack), " ")
      txt = logicview.add(txt, (function() if logicview.truth(logicview.contains(VDM_CMDS, cmd)) then return logicview.idx(VDM_CMDS, cmd) else return "cmd?" end end)())
      txt = logicview.add(txt, (function() if logicview.truth(pos) then return logicview.pymod(" pos %d", pos) else return " " end end)())
    else
      txt = logicview.pymod("unstruct [%04x]", (data & 32767))
    end
    txt = logicview.add(txt, logicview.pymod(" SVID:%04x", vid))
  else
    txt = logicview.pymod("VDO:%08x", data)
  end
  return txt
end
function _decoder.get_bist(self, idx, data)
  local mode, counter, mode_name
  mode = (data >> 28)
  counter = (data & 65535)
  mode_name = (function() if logicview.truth(logicview.contains(BIST_MODES, mode)) then return logicview.idx(BIST_MODES, mode) else return "INVALID" end end)()
  if logicview.truth(logicview.eq(mode, 2)) then
    mode_name = logicview.pymod("Counter[= %d]", counter)
  end
  return (function() if logicview.truth(logicview.eq(idx, 0)) then return logicview.pymod("mode %s", mode_name) else return "invalid BRO" end end)()
end
function _decoder.get_hex(self, idx, data)
  local txt
  txt = logicview.pymod("%02x", ((data >> 8) & 255))
  txt = logicview.add(txt, logicview.pymod(" %02x", ((data >> 0) & 255)))
  txt = logicview.add(txt, logicview.pymod(" %02x", ((data >> 24) & 255)))
  txt = logicview.add(txt, logicview.pymod(" %02x", ((data >> 16) & 255)))
  return txt
end
function _decoder.get_hex16(self, data)
  local txt
  txt = logicview.pymod("%02x", ((data >> 8) & 255))
  txt = logicview.add(txt, logicview.pymod(" %02x", ((data >> 0) & 255)))
  return txt
end
function _decoder.get_epr_mode(self, idx, data)
  local txt
  txt = logicview.idx(EPR_MODE_ACTION, (data >> 24))
  if logicview.truth(logicview.eq((data >> 24), 4)) then
    txt = logicview.add(txt, "  ")
    txt = logicview.add(txt, logicview.idx(EPR_MODE_DATA, ((data >> 16) & 255)))
  end
  return txt
end
function _decoder.get_ext_control_type(self, idx, data)
  local txt
  txt = logicview.idx(EXT_CONTROL_MSG_TYPES, (data >> 16))
  return txt
end
function _decoder.put_ext_head(self, s0, s1)
  local txt
  txt = logicview.pyformat("Chunked: {}  ", { self.chunked }, logicview.dict({}))
  txt = logicview.add(txt, logicview.pyformat("Chunk Num: {}  ", { self.chunk_num }, logicview.dict({})))
  txt = logicview.add(txt, logicview.pyformat("Req Chunk: {}  ", { self.req_chunk }, logicview.dict({})))
  txt = logicview.add(txt, logicview.pyformat("Data Size: {}  ", { self.data_size }, logicview.dict({})))
  self:putx(s0, s1, { 11, { txt, txt } })
end
function _decoder.putpayload(self, s0, s1, idx)
  local t, txt
  t = (function() if logicview.truth(logicview.eq(self:head_ext(), 0)) then return self:head_type() else return 255 end end)()
  txt = logicview.add(logicview.add("[", _tostring(logicview.add(idx, 1))), "] ")
  if logicview.truth(logicview.eq(t, 255)) then
    t = self:head_type()
    if logicview.truth(logicview.eq(t, 16)) then
      txt = logicview.add(txt, self:get_ext_control_type(idx, logicview.idx(self.data, idx)))
    elseif logicview.truth(((s1 - s0) < 40)) then
      txt = logicview.add(txt, self:get_hex16((logicview.idx(self.ext_data, idx) & 65535)))
    else
      txt = logicview.add(txt, self:get_hex(idx, logicview.idx(self.ext_data, idx)))
    end
  elseif logicview.truth(logicview.eq(t, 2)) then
    txt = logicview.add(txt, self:get_request(logicview.idx(self.data, idx)))
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(t, 1)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(t, 4)
  return _v
end)()) then
    txt = logicview.add(txt, self:get_source_sink_cap(logicview.idx(self.data, idx), logicview.add(idx, 1), logicview.eq(t, 1)))
  elseif logicview.truth(logicview.eq(t, 15)) then
    txt = logicview.add(txt, self:get_vdm(idx, logicview.idx(self.data, idx)))
  elseif logicview.truth(logicview.eq(t, 3)) then
    txt = logicview.add(txt, self:get_bist(idx, logicview.idx(self.data, idx)))
  elseif logicview.truth(logicview.eq(t, 10)) then
    txt = logicview.add(txt, self:get_epr_mode(idx, logicview.idx(self.data, idx)))
  elseif logicview.truth(logicview.eq(t, 9)) then
    if logicview.truth(logicview.eq(idx, 0)) then
      txt = logicview.add(txt, self:get_request(logicview.idx(self.data, idx)))
    else
      txt = logicview.add(txt, self:get_source_sink_cap(logicview.idx(self.data, idx), logicview.add(idx, 1), true))
    end
  end
  self:putx(s0, s1, { 11, { txt, txt } })
  self.text = logicview.add(self.text, logicview.add(" - ", txt))
end
function _decoder.puthead(self)
  local ann_type, role, t, shortm, longm
  ann_type = (function() if logicview.truth(self:head_power_role()) then return 9 else return 10 end end)()
  role = (function() if logicview.truth(self:head_power_role()) then return "SRC" else return "SNK" end end)()
  if logicview.truth((not logicview.eq(self:head_data_role(), self:head_power_role()))) then
    role = logicview.add(role, (function() if logicview.truth(self:head_data_role()) then return "/DFP" else return "/UFP" end end)())
  end
  t = self:head_type()
  if logicview.truth(logicview.eq(self:head_ext(), 1)) then
    shortm = (function() if logicview.truth(logicview.contains(EXTENDED_TYPES, t)) then return logicview.idx(EXTENDED_TYPES, t) else return "EXTENDED???" end end)()
  elseif logicview.truth(logicview.eq(self:head_count(), 0)) then
    if logicview.truth((function()
  local _v
  _v = (t >= 25)
  if not logicview.truth(_v) then return _v end
  _v = (t <= 31)
  return _v
end)()) then
      shortm = "reserved"
    else
      shortm = logicview.idx(CTRL_TYPES, t)
    end
  else
    shortm = (function() if logicview.truth(logicview.contains(DATA_TYPES, t)) then return logicview.idx(DATA_TYPES, t) else return "DAT???" end end)()
  end
  longm = logicview.pyformat("(r{:d}) {:s}[{:d}]: {:s}", { self:head_rev(), role, self:head_id(), shortm }, logicview.dict({}))
  self:putx(0, (-1), { ann_type, { longm, shortm } })
  self.text = logicview.add(self.text, longm)
end
function _decoder.head_ext(self)
  return ((self.head >> 15) & 1)
end
function _decoder.head_id(self)
  return ((self.head >> 9) & 7)
end
function _decoder.head_power_role(self)
  return ((self.head >> 8) & 1)
end
function _decoder.head_data_role(self)
  return ((self.head >> 5) & 1)
end
function _decoder.head_rev(self)
  return logicview.add(((self.head >> 6) & 3), 1)
end
function _decoder.head_type(self)
  return (self.head & 31)
end
function _decoder.head_count(self)
  return ((self.head >> 12) & 7)
end
function _decoder.putx(self, s0, s1, data)
  self:put(logicview.idx(self.edges, s0), logicview.idx(self.edges, s1), self.out_ann, data)
end
function _decoder.putwarn(self, longm, shortm)
  self:putx(0, (-1), { 8, { longm, shortm } })
end
function _decoder.compute_crc32(self)
  local bdata
  bdata = struct.pack(logicview.add("<H", logicview.mul("I", logicview.len(self.data))), (self.head & 65535), table.unpack(logicview.copy((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.data) do
    d = _lv_item
    _lv_out[#_lv_out + 1] = (d & 4294967295)
  end
  return _lv_out
end)())))
  return zlib.crc32(bdata)
end
function _decoder.rec_sym(self, i, sym)
  self:putx(i, logicview.add(i, 5), { 7, logicview.idx(SYM_NAME, sym) })
end
function _decoder.get_sym(self, i, rec)
  if rec == nil then rec = true end
  local v, sym
  v = ((((logicview.idx(self.bits, i) | (logicview.idx(self.bits, logicview.add(i, 1)) << 1)) | (logicview.idx(self.bits, logicview.add(i, 2)) << 2)) | (logicview.idx(self.bits, logicview.add(i, 3)) << 3)) | (logicview.idx(self.bits, logicview.add(i, 4)) << 4))
  sym = logicview.idx(DEC4B5B, v)
  if logicview.truth(rec) then
    self:rec_sym(i, sym)
  end
  return sym
end
function _decoder.get_short(self)
  local i, k, val
  i = self.idx
  if logicview.truth(((logicview.len(self.bits) - i) <= 20)) then
    self:putwarn("Truncated", "!")
    return 2989
  end
  k = { self:get_sym(i), self:get_sym(logicview.add(i, 5)), self:get_sym(logicview.add(i, 10)), self:get_sym(logicview.add(i, 15)) }
  val = (((logicview.idx(k, 0) | (logicview.idx(k, 1) << 4)) | (logicview.idx(k, 2) << 8)) | (logicview.idx(k, 3) << 12))
  self.idx = logicview.add(self.idx, 20)
  return val
end
function _decoder.get_word(self)
  local lo, hi
  lo = self:get_short()
  hi = self:get_short()
  return (lo | (hi << 16))
end
function _decoder.find_corrupted_sop(self, k)
  local seq
  for _lv_item in logicview.iter(SOP_SEQUENCES) do
    seq = _lv_item
    if logicview.truth((logicview.count((function()
  local _lv_out = {}
  for _lv_i in logicview.range(logicview.len(k)) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = logicview.eq(logicview.idx(k, i), logicview.idx(seq, i))
  end
  return _lv_out
end)(), true) >= 3)) then
      return logicview.idx(START_OF_PACKETS, seq)
    end
    ::continue_3::
  end
  return nil
end
function _decoder.scan_eop(self)
  local i, k, sym
  for _lv_i in logicview.range((logicview.len(self.bits) - 19)) do
    i = _lv_i
    k = { self:get_sym(i), self:get_sym(logicview.add(i, 5)), self:get_sym(logicview.add(i, 10)), self:get_sym(logicview.add(i, 15)) }
    sym = logicview.dget(START_OF_PACKETS, k, nil)
    if logicview.truth((not logicview.truth(sym))) then
      sym = self:find_corrupted_sop(k)
    end
    if logicview.truth(sym) then
      self:putx(0, i, { 1, { "Preamble", "..." } })
      self:rec_sym(i, logicview.idx(k, 0))
      self:rec_sym(logicview.add(i, 5), logicview.idx(k, 1))
      self:rec_sym(logicview.add(i, 10), logicview.idx(k, 2))
      self:rec_sym(logicview.add(i, 15), logicview.idx(k, 3))
      if logicview.truth(logicview.eq(sym, "Hard Reset")) then
        self.text = logicview.add(self.text, "HRST")
        return (-1)
      elseif logicview.truth(logicview.eq(sym, "Cable Reset")) then
        self.text = logicview.add(self.text, "CRST")
        return (-1)
      else
        self:putx(i, logicview.add(i, 20), { 2, { sym, "S" } })
      end
      return logicview.add(i, 20)
    end
    ::continue_4::
  end
  self:putx(0, logicview.len(self.bits), { 1, { "Junk???", "XXX" } })
  self.text = logicview.add(self.text, "Junk???")
  self:putwarn("No start of packet found", "XXX")
  return (-1)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.idx = 0
  self.packet_seq = 0
  self.previous = 0
  self.startsample = nil
  self.bits = {  }
  self.edges = {  }
  self.bad = {  }
  self.half_one = false
  self.start_one = 0
  self.stored_pdos = logicview.dict({  })
  self.cap_mark = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.maxbit = self:us2samples(logicview.mul(3, UI_US))
    self.threshold = self:us2samples(THRESHOLD_US)
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_bitrate = self:register(logicview.OUTPUT_META, "Bitrate")
end
function _decoder.us2samples(self, us)
  return logicview.tointeger((logicview.mul(us, self.samplerate) / 1000000))
end
function _decoder.decode_packet(self)
  local tstamp, i, data, ccrc, ss, es, bitrate
  self.data = {  }
  self.ext_head = 0
  self.ext_data = {  }
  self.idx = 0
  self.text = ""
  if logicview.truth((logicview.len(self.edges) < 50)) then
    return
  end
  self.packet_seq = logicview.add(self.packet_seq, 1)
  tstamp = ((_tonumber(self.startsample) or 0) / self.samplerate)
  self.text = logicview.add(self.text, logicview.pymod("#%-4d (%8.6fms): ", { self.packet_seq, logicview.mul(tstamp, 1000) }))
  self.idx = self:scan_eop()
  if logicview.truth((self.idx < 0)) then
    self:putx(0, self.idx, { 12, { self.text, "..." } })
    return
  end
  self.head = self:get_short()
  self:putx((self.idx - 20), self.idx, { 3, { logicview.pymod("H:%04X", self.head), "HD" } })
  self:puthead()
  if logicview.truth(logicview.eq(self:head_ext(), 1)) then
    self.ext_head = self:get_short()
    self.chunked = ((self.ext_head >> 15) & 1)
    self.chunk_num = ((self.ext_head >> 11) & 15)
    self.req_chunk = ((self.ext_head >> 10) & 1)
    self.data_size = (self.ext_head & 511)
    self:putx((self.idx - 20), self.idx, { 3, { logicview.pymod("Ext H:%04X", self.ext_head), "EXHD" } })
    self:put_ext_head((self.idx - 20), self.idx)
    self.idx = (self.idx - 20)
    for _lv_i in logicview.range(self:head_count()) do
      i = _lv_i
      _table.insert(self.data, self:get_word())
      ::continue_5::
    end
    self.idx = (self.idx - logicview.add(logicview.mul((self:head_count() - 1), 40), 20))
    if logicview.truth(logicview.eq(self.chunk_num, 0)) then
      for _lv_i in logicview.range(self:head_count()) do
        i = _lv_i
        if logicview.truth(logicview.eq(i, (self:head_count() - 1))) then
          data = self:get_short()
          _table.insert(self.ext_data, data)
          self:putx((self.idx - 20), self.idx, { 4, { logicview.pymod("[%d]%04x", { i, data }), logicview.pymod("D%d", i) } })
          self:putpayload((self.idx - 20), self.idx, i)
        else
          data = self:get_word()
          _table.insert(self.ext_data, data)
          self:putx((self.idx - 40), self.idx, { 4, { logicview.pymod("[%d]%08x", { i, data }), logicview.pymod("D%d", i) } })
          self:putpayload((self.idx - 40), self.idx, i)
        end
        ::continue_6::
      end
    else
      for _lv_i in logicview.range(self:head_count()) do
        i = _lv_i
        if logicview.truth(logicview.eq(i, 0)) then
          data = self:get_short()
          _table.insert(self.ext_data, data)
          self:putx((self.idx - 20), self.idx, { 4, { logicview.pymod("[%d]%04x", { i, data }), logicview.pymod("D%d", i) } })
          self:putpayload((self.idx - 20), self.idx, i)
        else
          data = self:get_word()
          _table.insert(self.ext_data, data)
          self:putx((self.idx - 40), self.idx, { 4, { logicview.pymod("[%d]%08x", { i, data }), logicview.pymod("D%d", i) } })
          self:putpayload((self.idx - 40), self.idx, i)
        end
        ::continue_7::
      end
    end
  else
    for _lv_i in logicview.range(self:head_count()) do
      i = _lv_i
      _table.insert(self.data, self:get_word())
      self:putx((self.idx - 40), self.idx, { 4, { logicview.pymod("[%d]%08x", { i, logicview.idx(self.data, i) }), logicview.pymod("D%d", i) } })
      self:putpayload((self.idx - 40), self.idx, i)
      ::continue_8::
    end
  end
  self.crc = self:get_word()
  ccrc = self:compute_crc32()
  if logicview.truth((not logicview.eq(self.crc, ccrc))) then
    self:putwarn(logicview.pymod("Bad CRC %08x != %08x", { self.crc, ccrc }), "CRC!")
  end
  self:putx((self.idx - 40), self.idx, { 5, { logicview.pymod("CRC:%08x", self.crc), "CRC" } })
  if logicview.truth((function()
  local _v
  _v = (logicview.len(self.bits) >= logicview.add(self.idx, 5))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self:get_sym(self.idx), EOP)
  return _v
end)()) then
    self:putx(self.idx, logicview.add(self.idx, 5), { 6, { "EOP", "E" } })
    self.idx = logicview.add(self.idx, 5)
  else
    self:putwarn("No EOP", "EOP!")
  end
  if logicview.truth(logicview.eq(logicview.idx(self.options, "fulltext"), "yes")) then
    self:putx(0, self.idx, { 12, { self.text, "..." } })
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(self.edges, 0), logicview.idx(self.edges, (-1))
    ss = _lv_a0
    es = _lv_a1
  end
  bitrate = (logicview.mul(self.samplerate, logicview.len(self.bits)) / (_tonumber((es - ss)) or 0))
  self:put(es, ss, self.out_bitrate, logicview.tointeger(bitrate))
  self:put(es, ss, self.out_binary, { 0, logicview.bytes(self.bits) })
end
function _decoder.decode(self)
  local diff, is_zero
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ [1] = "e" }), logicview.dict({ skip = logicview.tointeger((self.samplerate / 1000.0)) }) })
    if logicview.truth((not logicview.truth(self.startsample))) then
      self.startsample = self.samplenum
      self.previous = self.samplenum
      goto continue_9
    end
    diff = (self.samplenum - self.previous)
    if logicview.truth((diff > self.maxbit)) then
      _table.insert(self.edges, self.previous)
      self:decode_packet()
      self.startsample = self.samplenum
      self.bits = {  }
      self.edges = {  }
      self.bad = {  }
      self.half_one = false
      self.start_one = 0
    else
      is_zero = (diff > self.threshold)
      if logicview.truth((function()
  local _v
  _v = is_zero
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.half_one))
  return _v
end)()) then
        _table.insert(self.bits, 0)
        _table.insert(self.edges, self.previous)
      elseif logicview.truth((function()
  local _v
  _v = (not logicview.truth(is_zero))
  if not logicview.truth(_v) then return _v end
  _v = self.half_one
  return _v
end)()) then
        _table.insert(self.bits, 1)
        _table.insert(self.edges, self.start_one)
        self.half_one = false
      elseif logicview.truth((function()
  local _v
  _v = (not logicview.truth(is_zero))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.half_one))
  return _v
end)()) then
        self.half_one = true
        self.start_one = self.previous
      else
        _table.insert(self.bad, { self.start_one, self.previous })
        _table.insert(self.bits, 0)
        _table.insert(self.edges, self.previous)
        self.half_one = false
      end
    end
    self.previous = self.samplenum
    ::continue_9::
  end
end

return _decoder
