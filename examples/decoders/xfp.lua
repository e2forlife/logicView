-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2013 Bert Vermeulen <bert@biot.com>

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
local MODULE_ID, ALARM_THRESHOLDS, AD_READOUTS, GCS_BITS, CONNECTOR, TRANSCEIVER, SERIAL_ENCODING, XMIT_TECH, CDR, DEVICE_TECH, ENHANCED_OPTS, AUX_TYPES, Decoder
local _decoder

MODULE_ID = logicview.dict({ [1] = "GBIC", [2] = "Integrated module/connector", [3] = "SFP", [4] = "300-pin XBI", [5] = "XENPAK", [6] = "XFP", [7] = "XFF", [8] = "XFP-E", [9] = "XPAK", [10] = "X2" })
ALARM_THRESHOLDS = logicview.dict({ [0] = "Temp high alarm", [2] = "Temp low alarm", [4] = "Temp high warning", [6] = "Temp low warning", [16] = "Bias high alarm", [18] = "Bias low alarm", [20] = "Bias high warning", [22] = "Bias low warning", [24] = "TX power high alarm", [26] = "TX power low alarm", [28] = "TX power high warning", [30] = "TX power low warning", [32] = "RX power high alarm", [34] = "RX power low alarm", [36] = "RX power high warning", [38] = "RX power low warning", [40] = "AUX 1 high alarm", [42] = "AUX 1 low alarm", [44] = "AUX 1 high warning", [46] = "AUX 1 low warning", [48] = "AUX 2 high alarm", [50] = "AUX 2 low alarm", [52] = "AUX 2 high warning", [54] = "AUX 2 low warning" })
AD_READOUTS = logicview.dict({ [0] = "Module temperature", [4] = "TX bias current", [6] = "Measured TX output power", [8] = "Measured RX input power", [10] = "AUX 1 measurement", [12] = "AUX 2 measurement" })
GCS_BITS = { "TX disable", "Soft TX disable", "MOD_NR", "P_Down", "Soft P_Down", "Interrupt", "RX_LOS", "Data_Not_Ready", "TX_NR", "TX_Fault", "TX_CDR not locked", "RX_NR", "RX_CDR not locked" }
CONNECTOR = logicview.dict({ [1] = "SC", [2] = "Fibre Channel style 1 copper", [3] = "Fibre Channel style 2 copper", [4] = "BNC/TNC", [5] = "Fibre Channel coax", [6] = "FiberJack", [7] = "LC", [8] = "MT-RJ", [9] = "MU", [10] = "SG", [11] = "Optical pigtail", [32] = "HSSDC II", [33] = "Copper pigtail" })
TRANSCEIVER = { { "10GBASE-SR", "10GBASE-LR", "10GBASE-ER", "10GBASE-LRM", "10GBASE-SW", "10GBASE-LW", "10GBASE-EW" }, { "1200-MX-SN-I", "1200-SM-LL-L", "Extended Reach 1550 nm", "Intermediate reach 1300 nm FP" }, {  }, { "1000BASE-SX / 1xFC MMF", "1000BASE-LX / 1xFC SMF", "2xFC MMF", "2xFC SMF", "OC48-SR", "OC48-IR", "OC48-LR" }, { "I-64.1r", "I-64.1", "I-64.2r", "I-64.2", "I-64.3", "I-64.5" }, { "S-64.1", "S-64.2a", "S-64.2b", "S-64.3a", "S-64.3b", "S-64.5a", "S-64.5b" }, { "L-64.1", "L-64.2a", "L-64.2b", "L-64.2c", "L-64.3", "G.959.1 P1L1-2D2" }, { "V-64.2a", "V-64.2b", "V-64.3" } }
SERIAL_ENCODING = { "64B/66B", "8B/10B", "SONET scrambled", "NRZ", "RZ" }
XMIT_TECH = { "850 nm VCSEL", "1310 nm VCSEL", "1550 nm VCSEL", "1310 nm FP", "1310 nm DFB", "1550 nm DFB", "1310 nm EML1550 nm EMLcopper" }
CDR = { "9.95Gb/s", "10.3Gb/s", "10.5Gb/s", "10.7Gb/s", "11.1Gb/s", "(unknown)", "lineside loopback mode", "XFI loopback mode" }
DEVICE_TECH = { { "no wavelength control", "sctive wavelength control" }, { "uncooled transmitter device", "cooled transmitter" }, { "PIN detector", "APD detector" }, { "transmitter not tunable", "transmitter tunable" } }
ENHANCED_OPTS = { "VPS", "soft TX_DISABLE", "soft P_Down", "VPS LV regulator mode", "VPS bypassed regulator mode", "active FEC control", "wavelength tunability", "CMU" }
AUX_TYPES = { "not implemented", "APD bias voltage", "(unknown)", "TEC current", "laser temperature", "laser wavelength", "5V supply voltage", "3.3V supply voltage", "1.8V supply voltage", "-5.2V supply voltage", "5V supply current", "(unknown)", "(unknown)", "3.3V supply current", "1.8V supply current", "-5.2V supply current" }

_decoder = {
  api_version = 3,
  id = "xfp",
  name = "XFP",
  longname = "10 Gigabit Small Form Factor Pluggable Module (XFP)",
  desc = "XFP I²C management interface structures/protocol",
  license = "gplv3+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Networking" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "field-name-and-val", "Field name and value" }, { "field-val", "Field value" } },
  annotation_rows = { { "field-names-and-vals", "Field names and values", { 0 } }, { "field-vals", "Field values", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.cnt = (-1)
  self.sn = {  }
  self.buf = {  }
  self.cur_highmem_page = 0
  self.have_clei = false
  self.MAP_LOWER_MEMORY = logicview.dict({ [0] = self.module_id, [1] = self.signal_cc, [57] = self.alarm_warnings, [59] = self.vps, [69] = self.ignore, [71] = self.ber, [75] = self.wavelength_cr, [79] = self.fec_cr, [95] = self.int_ctrl, [109] = self.ad_readout, [111] = self.gcs, [117] = self.ignore, [118] = self.ignore, [122] = self.ignore, [126] = self.ignore, [127] = self.page_select })
  self.MAP_HIGH_TABLE_1 = logicview.dict({ [128] = self.module_id, [129] = self.ext_module_id, [130] = self.connector, [138] = self.transceiver, [139] = self.serial_encoding, [140] = self.br_min, [141] = self.br_max, [142] = self.link_length_smf, [143] = self.link_length_e50, [144] = self.link_length_50um, [145] = self.link_length_625um, [146] = self.link_length_copper, [147] = self.device_tech, [163] = self.vendor, [164] = self.cdr, [167] = self.vendor_oui, [183] = self.vendor_pn, [185] = self.vendor_rev, [187] = self.wavelength, [189] = self.wavelength_tolerance, [190] = self.max_case_temp, [191] = self.ignore, [195] = self.power_supply, [211] = self.vendor_sn, [219] = self.manuf_date, [220] = self.diag_mon, [221] = self.enhanced_opts, [222] = self.aux_mon, [223] = self.ignore, [255] = self.maybe_ascii })
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((not logicview.eq(cmd, "DATA READ"))) then
      return
    end
    self.cnt = logicview.add(self.cnt, 1)
    _table.insert(self.sn, { ss, es })
    _table.insert(self.buf, data)
    if logicview.truth((self.cnt < 128)) then
      if logicview.truth(logicview.contains(self.MAP_LOWER_MEMORY, self.cnt)) then
        logicview.idx(self.MAP_LOWER_MEMORY, self.cnt)(self.buf)
        logicview.list_clear(self.buf)
      end
    elseif logicview.truth((function()
  local _v
  _v = (self.cnt < 256)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cur_highmem_page, 1)
  return _v
end)()) then
      if logicview.truth(logicview.contains(self.MAP_HIGH_TABLE_1, self.cnt)) then
        logicview.idx(self.MAP_HIGH_TABLE_1, self.cnt)(self.buf)
        logicview.list_clear(self.buf)
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
function _decoder.annotate(self, key, value, start_cnt, end_cnt)
  if start_cnt == nil then start_cnt = nil end
  if end_cnt == nil then end_cnt = nil end
  if logicview.truth((start_cnt == nil)) then
    start_cnt = logicview.add((self.cnt - logicview.len(self.buf)), 1)
  end
  if logicview.truth((end_cnt == nil)) then
    end_cnt = self.cnt
  end
  self:put(logicview.idx(logicview.idx(self.sn, start_cnt), 0), logicview.idx(logicview.idx(self.sn, end_cnt), 1), self.out_ann, { 0, { logicview.add(logicview.add(key, ": "), value) } })
  self:put(logicview.idx(logicview.idx(self.sn, start_cnt), 0), logicview.idx(logicview.idx(self.sn, end_cnt), 1), self.out_ann, { 1, { value } })
end
function _decoder.ignore(self, data)
end
function _decoder.maybe_ascii(self, data)
  local i, cnt
  for _lv_i in logicview.range(logicview.len(data)) do
    i = _lv_i
    if logicview.truth((function()
  local _v
  _v = (logicview.idx(data, i) >= 32)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(data, i) < 127)
  return _v
end)()) then
      cnt = logicview.add((self.cnt - logicview.len(data)), 1)
      self:annotate("Vendor ID", _string.char(logicview.idx(data, i)), cnt, cnt)
    end
    ::continue_1::
  end
end
function _decoder.to_temp(self, value)
  local temp
  if logicview.truth((value & 32768)) then
    value = (-logicview.add((value ~ 65535), 1))
  end
  temp = (value / 256.0)
  return logicview.pymod("%.1f C", temp)
end
function _decoder.to_current(self, value)
  local current
  current = (value / 500000.0)
  return logicview.pymod("%.1f mA", current)
end
function _decoder.to_power(self, value)
  local power
  power = (value / 10000.0)
  return logicview.pymod("%.2f mW", power)
end
function _decoder.to_wavelength(self, value)
  local wl
  wl = (value / 20)
  return logicview.pymod("%d nm", wl)
end
function _decoder.to_wavelength_tolerance(self, value)
  local wl
  wl = (value / 200.0)
  return logicview.pymod("%.1f nm", wl)
end
function _decoder.module_id(self, data)
  self:annotate("Module identifier", logicview.dget(MODULE_ID, logicview.idx(data, 0), "Unknown"))
end
function _decoder.signal_cc(self, data)
  if logicview.truth((not logicview.eq(logicview.idx(data, 0), 0))) then
    self:annotate("Signal Conditioner Control", logicview.pymod("%.2x", logicview.idx(data, 0)))
  end
end
function _decoder.alarm_warnings(self, data)
  local cnt_idx, idx, value, name
  cnt_idx = (self.cnt - logicview.len(data))
  idx = 0
  while logicview.truth((idx < 56)) do
    if logicview.truth(logicview.eq(idx, 8)) then
      idx = logicview.add(idx, 8)
    end
    value = ((logicview.idx(data, idx) << 8) | logicview.idx(data, logicview.add(idx, 1)))
    if logicview.truth((not logicview.eq(value, 0))) then
      name = logicview.dget(ALARM_THRESHOLDS, idx, "...")
      if logicview.truth(logicview.contains({ 0, 2, 4, 6 }, idx)) then
        self:annotate(name, self:to_temp(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      elseif logicview.truth(logicview.contains({ 16, 18, 20, 22 }, idx)) then
        self:annotate(name, self:to_current(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      elseif logicview.truth(logicview.contains({ 24, 26, 28, 30, 32, 34, 36, 38 }, idx)) then
        self:annotate(name, self:to_power(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      else
        self:annotate(name, logicview.pymod("%d", name), value, logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      end
    end
    idx = logicview.add(idx, 2)
    ::continue_2::
  end
end
function _decoder.vps(self, data)
  if logicview.truth((not logicview.eq(data, { 0, 0 }))) then
    self:annotate("VPS", logicview.pymod("%.2x%.2x", { logicview.idx(data, 0), logicview.idx(data, 1) }))
  end
end
function _decoder.ber(self, data)
  if logicview.truth((not logicview.eq(data, { 0, 0 }))) then
    self:annotate("BER", _tostring(data))
  end
end
function _decoder.wavelength_cr(self, data)
  if logicview.truth((not logicview.eq(data, { 0, 0, 0, 0 }))) then
    self:annotate("WCR", _tostring(data))
  end
end
function _decoder.fec_cr(self, data)
  if logicview.truth((not logicview.eq(data, { 0, 0, 0, 0 }))) then
    self:annotate("FEC", _tostring(data))
  end
end
function _decoder.int_ctrl(self, data)
  local out, d
  out = {  }
  for _lv_item in logicview.iter(data) do
    d = _lv_item
    _table.insert(out, logicview.pymod("%.2x", d))
    ::continue_3::
  end
  self:annotate("Interrupt bits", logicview.join(" ", out))
end
function _decoder.ad_readout(self, data)
  local cnt_idx, idx, value, name
  cnt_idx = logicview.add((self.cnt - logicview.len(data)), 1)
  idx = 0
  while logicview.truth((idx < 14)) do
    if logicview.truth(logicview.eq(idx, 2)) then
      idx = logicview.add(idx, 2)
    end
    value = ((logicview.idx(data, idx) << 8) | logicview.idx(data, logicview.add(idx, 1)))
    name = logicview.dget(AD_READOUTS, idx, "...")
    if logicview.truth((not logicview.eq(value, 0))) then
      if logicview.truth(logicview.eq(idx, 0)) then
        self:annotate(name, self:to_temp(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      elseif logicview.truth(logicview.eq(idx, 4)) then
        self:annotate(name, self:to_current(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      elseif logicview.truth(logicview.contains({ 6, 8 }, idx)) then
        self:annotate(name, self:to_power(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      else
        self:annotate(name, _tostring(value), logicview.add(cnt_idx, idx), logicview.add(logicview.add(cnt_idx, idx), 1))
      end
    end
    idx = logicview.add(idx, 2)
    ::continue_4::
  end
end
function _decoder.gcs(self, data)
  local allbits, out, b
  allbits = ((logicview.idx(data, 0) << 8) | logicview.idx(data, 1))
  out = {  }
  for _lv_i in logicview.range(13) do
    b = _lv_i
    if logicview.truth((allbits & 32768)) then
      _table.insert(out, logicview.idx(GCS_BITS, b))
    end
    allbits = (allbits << 1)
    ::continue_5::
  end
  self:annotate("General Control/Status", logicview.join(", ", out))
end
function _decoder.page_select(self, data)
  self.cur_highmem_page = logicview.idx(data, 0)
end
function _decoder.ext_module_id(self, data)
  local out
  out = { logicview.pymod("Power level %d module", logicview.add((logicview.idx(data, 0) >> 6), 1)) }
  if logicview.truth(logicview.eq((logicview.idx(data, 0) & 32), 0)) then
    _table.insert(out, "CDR")
  end
  if logicview.truth(logicview.eq((logicview.idx(data, 0) & 16), 0)) then
    _table.insert(out, "TX ref clock input required")
  end
  if logicview.truth(logicview.eq((logicview.idx(data, 0) & 8), 0)) then
    self.have_clei = true
  end
  self:annotate("Extended id", logicview.join(", ", out))
end
function _decoder.connector(self, data)
  if logicview.truth(logicview.contains(CONNECTOR, logicview.idx(data, 0))) then
    self:annotate("Connector", logicview.idx(CONNECTOR, logicview.idx(data, 0)))
  end
end
function _decoder.transceiver(self, data)
  local out, t, value, b
  out = {  }
  for _lv_i in logicview.range(8) do
    t = _lv_i
    if logicview.truth(logicview.eq(logicview.idx(data, t), 0)) then
      goto continue_6
    end
    value = logicview.idx(data, t)
    for _lv_i in logicview.range(8) do
      b = _lv_i
      if logicview.truth((value & 128)) then
        if logicview.truth((logicview.len(logicview.idx(TRANSCEIVER, t)) < logicview.add(b, 1))) then
          _table.insert(out, "(unknown)")
        else
          _table.insert(out, logicview.idx(logicview.idx(TRANSCEIVER, t), b))
        end
      end
      value = (value << 1)
      ::continue_7::
    end
    ::continue_6::
  end
  self:annotate("Transceiver compliance", logicview.join(", ", out))
end
function _decoder.serial_encoding(self, data)
  local out, value, b
  out = {  }
  value = logicview.idx(data, 0)
  for _lv_i in logicview.range(8) do
    b = _lv_i
    if logicview.truth((value & 128)) then
      if logicview.truth((logicview.len(SERIAL_ENCODING) < logicview.add(b, 1))) then
        _table.insert(out, "(unknown)")
      else
        _table.insert(out, logicview.idx(SERIAL_ENCODING, b))
      end
      value = (value << 1)
    end
    ::continue_8::
  end
  self:annotate("Serial encoding support", logicview.join(", ", out))
end
function _decoder.br_min(self, data)
  local rate
  rate = (logicview.idx(data, 0) / 10.0)
  self:annotate("Minimum bit rate", logicview.pymod("%.3f GB/s", rate))
end
function _decoder.br_max(self, data)
  local rate
  rate = (logicview.idx(data, 0) / 10.0)
  self:annotate("Maximum bit rate", logicview.pymod("%.3f GB/s", rate))
end
function _decoder.link_length_smf(self, data)
  local length
  if logicview.truth(logicview.eq(logicview.idx(data, 0), 0)) then
    length = "(standard)"
  elseif logicview.truth(logicview.eq(logicview.idx(data, 0), 255)) then
    length = "> 254 km"
  else
    length = logicview.pymod("%d km", logicview.idx(data, 0))
  end
  self:annotate("Link length (SMF)", length)
end
function _decoder.link_length_e50(self, data)
  local length
  if logicview.truth(logicview.eq(logicview.idx(data, 0), 0)) then
    length = "(standard)"
  elseif logicview.truth(logicview.eq(logicview.idx(data, 0), 255)) then
    length = "> 508 m"
  else
    length = logicview.pymod("%d m", logicview.mul(logicview.idx(data, 0), 2))
  end
  self:annotate("Link length (extended, 50μm MMF)", length)
end
function _decoder.link_length_50um(self, data)
  local length
  if logicview.truth(logicview.eq(logicview.idx(data, 0), 0)) then
    length = "(standard)"
  elseif logicview.truth(logicview.eq(logicview.idx(data, 0), 255)) then
    length = "> 254 m"
  else
    length = logicview.pymod("%d m", logicview.idx(data, 0))
  end
  self:annotate("Link length (50μm MMF)", length)
end
function _decoder.link_length_625um(self, data)
  local length
  if logicview.truth(logicview.eq(logicview.idx(data, 0), 0)) then
    length = "(standard)"
  elseif logicview.truth(logicview.eq(logicview.idx(data, 0), 255)) then
    length = "> 254 m"
  else
    length = logicview.pymod("%d m", logicview.idx(data, 0))
  end
  self:annotate("Link length (62.5μm MMF)", length)
end
function _decoder.link_length_copper(self, data)
  local length
  if logicview.truth(logicview.eq(logicview.idx(data, 0), 0)) then
    length = "(unknown)"
  elseif logicview.truth(logicview.eq(logicview.idx(data, 0), 255)) then
    length = "> 254 m"
  else
    length = logicview.pymod("%d m", logicview.mul(logicview.idx(data, 0), 2))
  end
  self:annotate("Link length (copper)", length)
end
function _decoder.device_tech(self, data)
  local out, xmit, dev, b
  out = {  }
  xmit = (logicview.idx(data, 0) >> 4)
  if logicview.truth((xmit <= (logicview.len(XMIT_TECH) - 1))) then
    _table.insert(out, logicview.pymod("%s transmitter", logicview.idx(XMIT_TECH, xmit)))
  end
  dev = (logicview.idx(data, 0) & 15)
  for _lv_i in logicview.range(4) do
    b = _lv_i
    _table.insert(out, logicview.idx(logicview.idx(DEVICE_TECH, b), ((dev >> (3 - b)) & 1)))
    ::continue_9::
  end
  self:annotate("Device technology", logicview.join(", ", out))
end
function _decoder.vendor(self, data)
  local name
  name = logicview.strip(logicview.strip(logicview.bytes(data)), "\x00")
  if logicview.truth(name) then
    self:annotate("Vendor", name)
  end
end
function _decoder.cdr(self, data)
  local out, value, b
  out = {  }
  value = logicview.idx(data, 0)
  for _lv_i in logicview.range(8) do
    b = _lv_i
    if logicview.truth((value & 128)) then
      _table.insert(out, logicview.idx(CDR, b))
    end
    value = (value << 1)
    ::continue_10::
  end
  self:annotate("CDR support", logicview.join(", ", out))
end
function _decoder.vendor_oui(self, data)
  if logicview.truth((not logicview.eq(data, { 0, 0, 0 }))) then
    self:annotate("Vendor OUI", logicview.pymod("%.2X-%.2X-%.2X", logicview.copy(data)))
  end
end
function _decoder.vendor_pn(self, data)
  local name
  name = logicview.strip(logicview.strip(logicview.bytes(data)), "\x00")
  if logicview.truth(name) then
    self:annotate("Vendor part number", name)
  end
end
function _decoder.vendor_rev(self, data)
  local name
  name = logicview.strip(logicview.strip(logicview.bytes(data)), "\x00")
  if logicview.truth(name) then
    self:annotate("Vendor revision", name)
  end
end
function _decoder.wavelength(self, data)
  local value
  value = ((logicview.idx(data, 0) << 8) | logicview.idx(data, 1))
  self:annotate("Wavelength", self:to_wavelength(value))
end
function _decoder.wavelength_tolerance(self, data)
  local value
  value = ((logicview.idx(data, 0) << 8) | logicview.idx(data, 1))
  self:annotate("Wavelength tolerance", self:to_wavelength_tolerance(value))
end
function _decoder.max_case_temp(self, data)
  self:annotate("Maximum case temperature", logicview.pymod("%d C", logicview.idx(data, 0)))
end
function _decoder.power_supply(self, data)
  local out, value
  out = {  }
  self:annotate("Max power dissipation", logicview.pymod("%.3f W", logicview.mul(logicview.idx(data, 0), 0.02)), (self.cnt - 3), (self.cnt - 3))
  self:annotate("Max power dissipation (powered down)", logicview.pymod("%.3f W", logicview.mul(logicview.idx(data, 1), 0.01)), (self.cnt - 2), (self.cnt - 2))
  value = logicview.mul((logicview.idx(data, 2) >> 4), 0.05)
  self:annotate("Max current required (5V supply)", logicview.pymod("%.3f A", value), (self.cnt - 1), (self.cnt - 1))
  value = logicview.mul((logicview.idx(data, 2) & 15), 0.1)
  self:annotate("Max current required (3.3V supply)", logicview.pymod("%.3f A", value), (self.cnt - 1), (self.cnt - 1))
  value = logicview.mul((logicview.idx(data, 3) >> 4), 0.1)
  self:annotate("Max current required (1.8V supply)", logicview.pymod("%.3f A", value), self.cnt, self.cnt)
  value = logicview.mul((logicview.idx(data, 3) & 15), 0.05)
  self:annotate("Max current required (-5.2V supply)", logicview.pymod("%.3f A", value), self.cnt, self.cnt)
end
function _decoder.vendor_sn(self, data)
  local name
  name = logicview.strip(logicview.strip(logicview.bytes(data)), "\x00")
  if logicview.truth(name) then
    self:annotate("Vendor serial number", name)
  end
end
function _decoder.manuf_date(self, data)
  local y, m, d, mnf, lot
  y = logicview.add(logicview.tointeger(logicview.bytes(logicview.slice(data, 0, 2, nil))), 2000)
  m = logicview.tointeger(logicview.bytes(logicview.slice(data, 2, 4, nil)))
  d = logicview.tointeger(logicview.bytes(logicview.slice(data, 4, 6, nil)))
  mnf = logicview.pymod("%.4d-%.2d-%.2d", { y, m, d })
  lot = logicview.strip(logicview.strip(logicview.bytes(logicview.slice(data, 6, nil, nil))), "\x00")
  if logicview.truth(lot) then
    mnf = logicview.add(mnf, logicview.add(" lot ", lot))
  end
  self:annotate("Manufacturing date", mnf)
end
function _decoder.diag_mon(self, data)
  local out
  out = {  }
  if logicview.truth((logicview.idx(data, 0) & 16)) then
    _table.insert(out, "BER support")
  else
    _table.insert(out, "no BER support")
  end
  if logicview.truth((logicview.idx(data, 0) & 8)) then
    _table.insert(out, "average power measurement")
  else
    _table.insert(out, "OMA power measurement")
  end
  self:annotate("Diagnostic monitoring", logicview.join(", ", out))
end
function _decoder.enhanced_opts(self, data)
  local out, value, b
  out = {  }
  value = logicview.idx(data, 0)
  for _lv_i in logicview.range(8) do
    b = _lv_i
    if logicview.truth((value & 128)) then
      _table.insert(out, logicview.idx(ENHANCED_OPTS, b))
    end
    value = (value << 1)
    ::continue_11::
  end
  self:annotate("Enhanced option support", logicview.join(", ", out))
end
function _decoder.aux_mon(self, data)
  local aux
  aux = logicview.idx(AUX_TYPES, (logicview.idx(data, 0) >> 4))
  self:annotate("AUX1 monitoring", aux)
  aux = logicview.idx(AUX_TYPES, (logicview.idx(data, 0) & 15))
  self:annotate("AUX2 monitoring", aux)
end

return _decoder
