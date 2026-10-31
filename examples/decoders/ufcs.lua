-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2023 edison ren <i2tv@qq.com>

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
local CTRL_TYPES, DATA_TYPES, Decoder
local _decoder

CTRL_TYPES = logicview.dict({ [0] = "PING", [1] = "ACK", [2] = "NCK", [3] = "ACCEPT", [4] = "SOFT RESET", [5] = "POWER READY", [6] = "GET OUTPUT CAP", [7] = "GET SOURCE INFO", [8] = "GET SINK INFO", [9] = "GET CABLE INFO", [10] = "GET DEVICE INFO", [11] = "GET ERROR INFO", [12] = "DETECT CABLE INFO", [13] = "START CABLE DETECT", [14] = "END CABLE DETECT", [15] = "EXIT UFCS MODE" })
DATA_TYPES = logicview.dict({ [1] = "OUTPUT CAP", [2] = "REQUEST", [3] = "SOURCE INFO", [4] = "SINK INFO", [5] = "CABLE INFO", [6] = "DEVICE INFO", [7] = "ERROR INFO", [8] = "CONFIG WATCHDOG", [9] = "REFUSE", [10] = "Verify_Request", [11] = "Verify_Response", [255] = "Test Request" })
_decoder = {
  api_version = 3,
  id = "ufcs",
  name = "UFCS",
  longname = "Universal Fast Charging Specification",
  desc = "Universal fast charging specification for mobile devices. T/TAF 083-2021. Coding by edison ren 2023.1.25 <i2tv@qq.com>",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "PC/Mobile" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "fulltext", desc = "Full text decoding of packets", default = "no", values = { "yes", "no" } }) },
  annotations = { { "type", "Packet Type" }, { "training", "Training" }, { "header", "Header" }, { "data", "Data" }, { "crc", "Checksum" }, { "warnings", "Warnings" }, { "src", "Source Message" }, { "snk", "Sink Message" }, { "payload", "Payload" }, { "text", "Plain text" }, { "cable", "Cable Message" }, { "reserved", "Reserved" } },
  annotation_rows = { { "phase", "Parts", { 1, 2, 3, 4 } }, { "payload", "Payload", { 8 } }, { "type", "Type", { 0, 6, 7, 10, 11 } }, { "warnings", "Warnings", { 5 } }, { "text", "Full text", { 9 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.ss_block = nil
  self.es_block = nil
  self.dataidx = 0
  self.datapkt = {  }
  self.head = {  }
  self.bytepos = {  }
  self.text = ""
  self.plen = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.head_id(self)
  return ((logicview.idx(self.head, 0) >> 1) & 15)
end
function _decoder.head_power_role(self)
  return ((logicview.idx(self.head, 0) >> 5) & 7)
end
function _decoder.head_rev(self)
  return ((logicview.idx(self.head, 1) >> 3) & 31)
end
function _decoder.head_type(self)
  return logicview.idx(self.head, 2)
end
function _decoder.data_len(self)
  return (function() if logicview.truth(logicview.eq((logicview.idx(self.head, 1) & 7), 1)) then return logicview.idx(self.head, 3) else return 0 end end)()
end
function _decoder.putx(self, s0, s1, data)
  self:put(s0, s1, self.out_ann, data)
end
function _decoder.putwarn(self, longm, shortm)
  self:putx(0, (-1), { 8, { longm, shortm } })
end
function _decoder.compute_crc8(self)
  local CRC_8_POLYNOMIAL, rCRC, s, i
  CRC_8_POLYNOMIAL = 41
  rCRC = 0
  for _lv_i in logicview.range((self.plen - 1)) do
    s = _lv_i
    rCRC = (rCRC ~ logicview.idx(self.datapkt, s))
    for _lv_i in logicview.range(8) do
      i = _lv_i
      if logicview.truth((rCRC & 128)) then
        rCRC = ((rCRC << 1) ~ CRC_8_POLYNOMIAL)
      else
        rCRC = (rCRC << 1)
      end
      ::continue_2::
    end
    ::continue_1::
  end
  return (rCRC & 255)
end
function _decoder.get_short(self, i)
  local k, val
  k = { logicview.idx(self.datapkt, i), logicview.idx(self.datapkt, logicview.add(i, 1)) }
  val = ((logicview.idx(k, 0) << 8) | logicview.idx(k, 1))
  return val
end
function _decoder.get_word(self, i)
  local hi, lo
  hi = self:get_short(i)
  lo = self:get_short(logicview.add(i, 2))
  return (lo | (hi << 16))
end
function _decoder.get_dword(self, i)
  local hi, lo
  hi = self:get_word(i)
  lo = self:get_word(logicview.add(i, 4))
  return (lo | (hi << 32))
end
function _decoder.puthead(self)
  local pwr_role, ann_type, role, t, shortm, longm
  pwr_role = self:head_power_role()
  if logicview.truth(logicview.eq(pwr_role, 1)) then
    ann_type = 6
    role = "SRC"
  elseif logicview.truth(logicview.eq(pwr_role, 2)) then
    ann_type = 7
    role = "SNK"
  elseif logicview.truth(logicview.eq(pwr_role, 3)) then
    ann_type = 10
    role = "Cable"
  else
    ann_type = 11
    role = "Reserved"
  end
  t = self:head_type()
  if logicview.truth(logicview.eq(self:data_len(), 0)) then
    if logicview.truth((t > 15)) then
      shortm = "reserved cmd"
    else
      shortm = logicview.idx(CTRL_TYPES, t)
    end
  else
    shortm = (function() if logicview.truth(logicview.contains(DATA_TYPES, t)) then return logicview.idx(DATA_TYPES, t) else return "DAT???" end end)()
  end
  longm = logicview.pyformat("(r{:d}) {:s}[{:d}]: {:s}", { self:head_rev(), role, self:head_id(), shortm }, logicview.dict({}))
  self:putx(logicview.idx(logicview.idx(self.bytepos, 0), 0), logicview.idx(logicview.idx(self.bytepos, 2), 1), { ann_type, { longm, shortm } })
  self.text = logicview.add(self.text, longm)
end
function _decoder.get_source_cap(self)
  local numbpdo, strpdo, numb, pdo, mode, step_ma, step_mv, max_mv, min_mv, max_ma, min_ma, s0, s1, txt
  numbpdo = logicview.floordiv(logicview.tointeger(self:data_len()), 8)
  strpdo = ""
  for _lv_i in logicview.range(numbpdo) do
    numb = _lv_i
    pdo = self:get_dword(logicview.add(4, logicview.mul(8, numb)))
    mode = ((pdo >> 60) & 15)
    step_ma = logicview.add(logicview.mul(((pdo >> 57) & 7), 10), 10)
    step_mv = logicview.add(logicview.mul(((pdo >> 56) & 1), 10), 10)
    max_mv = logicview.mul(((pdo >> 40) & 65535), 0.01)
    min_mv = logicview.mul(((pdo >> 24) & 65535), 0.01)
    max_ma = logicview.mul(((pdo >> 8) & 65535), 0.01)
    min_ma = logicview.mul((pdo & 255), 0.01)
    strpdo = logicview.pymod("[%d] %g/%gV *%gmv %g/%gA *%gma ", { mode, min_mv, max_mv, step_mv, min_ma, max_ma, step_ma })
    s0 = logicview.idx(logicview.idx(self.bytepos, logicview.add(4, logicview.mul(8, numb))), 0)
    s1 = logicview.idx(logicview.idx(self.bytepos, logicview.add(logicview.add(4, logicview.mul(8, numb)), 7)), 1)
    self:putx(s0, s1, { 3, { logicview.pymod("[%d]%08x", { numb, pdo }), logicview.pymod("D%d", numb) } })
    txt = logicview.pymod("(PDO %s)", strpdo)
    self:putx(s0, s1, { 8, { txt, txt } })
    self.text = logicview.add(self.text, logicview.add(" - ", txt))
    ::continue_3::
  end
  return self.text
end
function _decoder.get_request(self)
  local rdo, mode, curr, volt, s
  rdo = self:get_dword(4)
  mode = ((rdo >> 60) & 15)
  curr = logicview.mul((rdo & 65535), 0.01)
  volt = logicview.mul(((rdo >> 16) & 65535), 0.01)
  s = logicview.pymod("%gV %gA", { volt, curr })
  return { rdo, logicview.pymod("(PDO #%d) %s", { mode, s }) }
end
function _decoder.get_src_info(self)
  local d, it, its, pt, pts, curr, volt
  d = self:get_dword(4)
  it = (((d >> 40) & 255) - 50)
  its = logicview.pymod(",internal temp %s", (function() if logicview.truth((it > (-50))) then return logicview.pymod("%dC", it) else return "no data" end end)())
  pt = (((d >> 32) & 255) - 50)
  pts = logicview.pymod(",usb port temp %s", (function() if logicview.truth((pt > (-50))) then return logicview.pymod("%dC", pt) else return "no data" end end)())
  curr = logicview.mul((d & 65535), 0.01)
  volt = logicview.mul(((d >> 16) & 65535), 0.01)
  return { d, logicview.pymod("(SRC info: %gV %gA %s %s)", { volt, curr, its, pts }) }
end
function _decoder.get_snk_info(self)
  local d, it, its, pt, pts, curr, volt
  d = self:get_dword(4)
  it = (((d >> 40) & 255) - 50)
  its = logicview.pymod(",battery temp %s", (function() if logicview.truth((it > (-50))) then return logicview.pymod("%dC", it) else return "no data" end end)())
  pt = (((d >> 32) & 255) - 50)
  pts = logicview.pymod(",usb port temp %s", (function() if logicview.truth((pt > (-50))) then return logicview.pymod("%dC", pt) else return "no data" end end)())
  curr = logicview.mul((d & 65535), 0.01)
  volt = logicview.mul(((d >> 16) & 65535), 0.01)
  return { d, logicview.pymod("(SNK info: %gV %gA %s %s)", { volt, curr, its, pts }) }
end
function _decoder.get_cable_info(self)
  local d, id, ids, emk, emks, imp, imps, curr, volt
  d = self:get_dword(4)
  id = ((d >> 48) & 65535)
  ids = logicview.pymod("Cable VID %04X", id)
  emk = ((d >> 32) & 65535)
  emks = logicview.pymod("Emark VID %04X", emk)
  imp = ((d >> 16) & 65535)
  imps = logicview.pymod("IMP %d", imp)
  curr = (d & 255)
  volt = ((d >> 8) & 255)
  return { d, logicview.pymod("(%s %s %s %gV %gA)", { ids, emks, imps, volt, curr }) }
end
function _decoder.get_device_info(self)
  local d, id, ids, pid, pids, hwv, hwvs, swv, swvs
  d = self:get_dword(4)
  id = ((d >> 48) & 65535)
  ids = logicview.pymod("Device VID %04X", id)
  pid = ((d >> 32) & 65535)
  pids = logicview.pymod("Protocol IC VID %04X", emk)
  hwv = ((d >> 16) & 65535)
  hwvs = logicview.pymod("HW rev%04X", imp)
  swv = (d & 65535)
  swvs = logicview.pymod("SW rev%04X", imp)
  return { d, logicview.pymod("(%s %s %s %s)", { ids, pids, hwv, swv }) }
end
function _decoder.get_error_info(self)
  local d, id, ids, e14, e14s, e13, e13s, e12, e12s, e11, e11s, e10, e10s, e9, e9s, e8, e8s, e7, e7s, e6, e6s, e5, e5s, e4, e4s, e3, e3s, e2, e2s, e1, e1s, e0, e0s
  d = self:get_word(4)
  id = ((d >> 15) & 131071)
  ids = logicview.pymod("Reversed %04X", id)
  e14 = ((d >> 14) & 1)
  e14s = logicview.pymod("Watchdog %s", (function() if logicview.truth(logicview.eq(e14, 0)) then return "OK" else return "NG!" end end)())
  e13 = ((d >> 13) & 1)
  e13s = logicview.pymod("CRC %s", (function() if logicview.truth(logicview.eq(e13, 0)) then return "OK" else return "NG!" end end)())
  e12 = ((d >> 12) & 1)
  e12s = logicview.pymod("Input %s", (function() if logicview.truth(logicview.eq(e12, 0)) then return "OK" else return "NG!" end end)())
  e11 = ((d >> 11) & 1)
  e11s = logicview.pymod("Current loss %s", (function() if logicview.truth(logicview.eq(e11, 0)) then return "OK" else return "NG!" end end)())
  e10 = ((d >> 10) & 1)
  e10s = logicview.pymod("UVP %s", (function() if logicview.truth(logicview.eq(e10, 0)) then return "OK" else return "NG!" end end)())
  e9 = ((d >> 9) & 1)
  e9s = logicview.pymod("OVP %s", (function() if logicview.truth(logicview.eq(e9, 0)) then return "OK" else return "NG" end end)())
  e8 = ((d >> 8) & 1)
  e8s = logicview.pymod("D+OVP %s", (function() if logicview.truth(logicview.eq(e8, 0)) then return "OK" else return "NG" end end)())
  e7 = ((d >> 7) & 1)
  e7s = logicview.pymod("D-OVP %s", (function() if logicview.truth(logicview.eq(e7, 0)) then return "OK" else return "NG" end end)())
  e6 = ((d >> 6) & 1)
  e6s = logicview.pymod("CCOVP %s", (function() if logicview.truth(logicview.eq(e6, 0)) then return "OK" else return "NG" end end)())
  e5 = ((d >> 5) & 1)
  e5s = logicview.pymod("Battery OTP %s", (function() if logicview.truth(logicview.eq(e5, 0)) then return "OK" else return "NG" end end)())
  e4 = ((d >> 4) & 1)
  e4s = logicview.pymod("USB port OTP %s", (function() if logicview.truth(logicview.eq(e4, 0)) then return "OK" else return "NG" end end)())
  e3 = ((d >> 3) & 1)
  e3s = logicview.pymod("SCP %s", (function() if logicview.truth(logicview.eq(e3, 0)) then return "OK" else return "NG" end end)())
  e2 = ((d >> 2) & 1)
  e2s = logicview.pymod("OCP %s", (function() if logicview.truth(logicview.eq(e2, 0)) then return "OK" else return "NG" end end)())
  e1 = ((d >> 1) & 1)
  e1s = logicview.pymod("UVP %s", (function() if logicview.truth(logicview.eq(e1, 0)) then return "OK" else return "NG" end end)())
  e0 = ((d >> 0) & 1)
  e0s = logicview.pymod("OVP %s", (function() if logicview.truth(logicview.eq(e0, 0)) then return "OK" else return "NG" end end)())
  return { d, logicview.pymod("(%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s)", { ids, e14, e13, e12, e11, e10, e9, e8, e7, e6, e5, e4, e3, e2, e1, e0 }) }
end
function _decoder.config_watchdog(self)
  local d
  d = self:get_short(4)
  return { d, logicview.pymod("Watchdog overflow time %dms", d) }
end
function _decoder.refuse(self)
  local d, rev, revs, rev2, revs2, id, ids, t, ts, c, cs, r1, rs1
  d = self:get_word(4)
  rev = ((d >> 28) & 15)
  revs = (function() if logicview.truth(rev) then return logicview.pymod("Reversed %01X", rev) else return "" end end)()
  rev2 = ((d >> 19) & 15)
  revs2 = (function() if logicview.truth(rev2) then return logicview.pymod("Reversed %01X", rev2) else return "" end end)()
  id = ((d >> 24) & 15)
  ids = logicview.pymod("MSG #%d", id)
  t = ((d >> 16) & 7)
  ts = logicview.pymod(", Type %d", ts)
  c = ((d >> 8) & 255)
  cs = logicview.pymod(", CMD %d", c)
  r1 = ((d >> 0) & 7)
  rs1 = (function() if logicview.truth(logicview.eq(r1, 1)) then return ", unknow" else return "" end end)()
  rs1 = logicview.add(rs1, (function() if logicview.truth(logicview.eq(r1, 2)) then return ", not support" else return "" end end)())
  rs1 = logicview.add(rs1, (function() if logicview.truth(logicview.eq(r1, 3)) then return ", busy" else return "" end end)())
  rs1 = logicview.add(rs1, (function() if logicview.truth(logicview.eq(r1, 4)) then return ", over range" else return "" end end)())
  rs1 = logicview.add(rs1, (function() if logicview.truth(logicview.eq(r1, 5)) then return ", other" else return "" end end)())
  return { d, logicview.pymod("Refuse why? $s", logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(ids, ts), cs), revs), revs2), rs1)) }
end
function _decoder.verify_request(self)
  local id, dhi, dlo
  id = logicview.idx(self.datapkt, 4)
  dhi = self:get_dword(5)
  dlo = self:get_dword(logicview.add(5, 8))
  return { id, logicview.pymod("Verify request key ID %d, random %08x%08x", { id, dhi, dhl }) }
end
function _decoder.verify_response(self)
  local key, rand
  key = self:get_dword(4)
  rand = self:get_word(logicview.add(4, 8))
  return { id, logicview.pymod("Verify request data %08x, random %04x", { key, rand }) }
end
function _decoder.decode_data_msg(self)
  local dlen, txt, t, d, s0, s1
  dlen = self:data_len()
  if logicview.truth(logicview.eq(dlen, 0)) then
    return
  end
  txt = ""
  t = self:head_type()
  if logicview.truth(logicview.eq(t, 1)) then
    self:get_source_cap()
    return
  elseif logicview.truth(logicview.eq(t, 2)) then
    do
      local _lv_seq = self:get_request()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 3)) then
    do
      local _lv_seq = self:get_src_info()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 4)) then
    do
      local _lv_seq = self:get_snk_info()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 5)) then
    do
      local _lv_seq = self:get_cable_info()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 6)) then
    do
      local _lv_seq = self:get_device_info()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 7)) then
    do
      local _lv_seq = self:get_error_info()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 8)) then
    do
      local _lv_seq = self:config_watchdog()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 9)) then
    do
      local _lv_seq = self:refuse()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 10)) then
    do
      local _lv_seq = self:verify_request()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  elseif logicview.truth(logicview.eq(t, 11)) then
    do
      local _lv_seq = self:verify_response()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      d = logicview.idx(_lv_seq, 0)
      txt = logicview.idx(_lv_seq, 1)
    end
  else
    do
      local _lv_a0, _lv_a1 = 4294967295, "TODO..."
      d = _lv_a0
      txt = _lv_a1
    end
  end
  s0 = logicview.idx(logicview.idx(self.bytepos, 4), 0)
  s1 = logicview.idx(logicview.idx(self.bytepos, logicview.add(dlen, 3)), 1)
  self:putx(s0, s1, { 3, { logicview.pymod("H:%08x", d), "DATA" } })
  self:putx(s0, s1, { 8, { txt, txt } })
  self.text = logicview.add(self.text, logicview.add(" - ", txt))
end
function _decoder.decode_pkt(self)
  local ccrc
  self.head = logicview.slice(self.datapkt, 0, 4, nil)
  self:putx(logicview.idx(logicview.idx(self.bytepos, 0), 0), logicview.idx(logicview.idx(self.bytepos, 1), 1), { 2, { logicview.pymod("HEAD:%04x", ((logicview.idx(self.head, 0) << 8) | logicview.idx(self.head, 1))), "HD" } })
  self:puthead()
  self:putx(logicview.idx(logicview.idx(self.bytepos, 2), 0), logicview.idx(logicview.idx(self.bytepos, 2), 1), { 2, { logicview.pymod("CMD:%02x", logicview.idx(self.head, 2)), "CMD" } })
  if logicview.truth(self:data_len()) then
    self:putx(logicview.idx(logicview.idx(self.bytepos, 3), 0), logicview.idx(logicview.idx(self.bytepos, 3), 1), { 2, { logicview.pymod("LEN:%02x", logicview.idx(self.head, 3)), "LEN" } })
  end
  self:decode_data_msg()
  self.crc = logicview.idx(self.datapkt, (self.plen - 1))
  ccrc = self:compute_crc8()
  if logicview.truth((not logicview.eq(self.crc, ccrc))) then
    self:putwarn(logicview.pymod("Bad CRC %02x != %02x", { self.crc, ccrc }), "CRC!")
  end
  self:putx(self.ss_block, self.es_block, { 4, { logicview.pymod("CRC:%02x", self.crc), "CRC" } })
  if logicview.truth(logicview.eq(logicview.idx(self.options, "fulltext"), "yes")) then
    self:putx(logicview.idx(logicview.idx(self.bytepos, 0), 0), self.es_block, { 9, { self.text, "..." } })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      rxtx = logicview.idx(_lv_seq, 1)
      pdata = logicview.idx(_lv_seq, 2)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss_block = _lv_a0
      self.es_block = _lv_a1
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    if logicview.truth(logicview.eq(logicview.idx(pdata, 0), 170)) then
      self:putx(ss, es, { 3, { "SOP:0xaa", "SOP" } })
      self:reset()
      return
    end
    _table.insert(self.datapkt, logicview.idx(pdata, 0))
    _table.insert(self.bytepos, { ss, es })
    if logicview.truth(logicview.eq(self.dataidx, 3)) then
      if logicview.truth(logicview.eq((logicview.idx(self.datapkt, 1) & 1), 1)) then
        self.plen = logicview.add(logicview.idx(self.datapkt, 3), 5)
      else
        self.plen = 4
      end
    end
    self.dataidx = logicview.add(self.dataidx, 1)
    if logicview.truth(logicview.eq(self.dataidx, self.plen)) then
      self:decode_pkt()
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
