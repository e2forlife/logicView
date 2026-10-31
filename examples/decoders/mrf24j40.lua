-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Karl Palsson <karlp@tweak.net.au>
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
local TX, RX, Decoder, sregs, lregs
local _decoder

sregs = logicview.dict({ [0] = "RXMCR", [1] = "PANIDL", [2] = "PANIDH", [3] = "SADRL", [4] = "SADRH", [5] = "EADR0", [6] = "EADR1", [7] = "EADR2", [8] = "EADR3", [9] = "EADR4", [10] = "EADR5", [11] = "EADR6", [12] = "EADR7", [13] = "RXFLUSH", [14] = "Reserved", [15] = "Reserved", [16] = "ORDER", [17] = "TXMCR", [18] = "ACKTMOUT", [19] = "ESLOTG1", [20] = "SYMTICKL", [21] = "SYMTICKH", [22] = "PACON0", [23] = "PACON1", [24] = "PACON2", [25] = "Reserved", [26] = "TXBCON0", [27] = "TXNCON", [28] = "TXG1CON", [29] = "TXG2CON", [30] = "ESLOTG23", [31] = "ESLOTG45", [32] = "ESLOTG67", [33] = "TXPEND", [34] = "WAKECON", [35] = "FRMOFFSET", [36] = "TXSTAT", [37] = "TXBCON1", [38] = "GATECLK", [39] = "TXTIME", [40] = "HSYMTIMRL", [41] = "HSYMTIMRH", [42] = "SOFTRST", [43] = "Reserved", [44] = "SECCON0", [45] = "SECCON1", [46] = "TXSTBL", [47] = "Reserved", [48] = "RXSR", [49] = "INTSTAT", [50] = "INTCON", [51] = "GPIO", [52] = "TRISGPIO", [53] = "SLPACK", [54] = "RFCTL", [55] = "SECCR2", [56] = "BBREG0", [57] = "BBREG1", [58] = "BBREG2", [59] = "BBREG3", [60] = "BBREG4", [61] = "Reserved", [62] = "BBREG6", [63] = "CCAEDTH" })
lregs = logicview.dict({ [512] = "RFCON0", [513] = "RFCON1", [514] = "RFCON2", [515] = "RFCON3", [516] = "Reserved", [517] = "RFCON5", [518] = "RFCON6", [519] = "RFCON7", [520] = "RFCON8", [521] = "SLPCAL0", [522] = "SLPCAL1", [523] = "SLPCAL2", [524] = "Reserved", [525] = "Reserved", [526] = "Reserved", [527] = "RFSTATE", [528] = "RSSI", [529] = "SLPCON0", [530] = "Reserved", [531] = "Reserved", [532] = "Reserved", [533] = "Reserved", [534] = "Reserved", [535] = "Reserved", [536] = "Reserved", [537] = "Reserved", [538] = "Reserved", [539] = "Reserved", [540] = "Reserved", [541] = "Reserved", [542] = "Reserved", [543] = "Reserved", [544] = "SLPCON1", [545] = "Reserved", [546] = "WAKETIMEL", [547] = "WAKETIMEH", [548] = "REMCNTL", [549] = "REMCNTH", [550] = "MAINCNT0", [551] = "MAINCNT1", [552] = "MAINCNT2", [553] = "MAINCNT3", [554] = "Reserved", [555] = "Reserved", [556] = "Reserved", [557] = "Reserved", [558] = "Reserved", [559] = "TESTMODE", [560] = "ASSOEADR0", [561] = "ASSOEADR1", [562] = "ASSOEADR2", [563] = "ASSOEADR3", [564] = "ASSOEADR4", [565] = "ASSOEADR5", [566] = "ASSOEADR6", [567] = "ASSOEADR7", [568] = "ASSOSADR0", [569] = "ASSOSADR1", [570] = "Reserved", [571] = "Reserved", [572] = "Unimplemented", [573] = "Unimplemented", [574] = "Unimplemented", [575] = "Unimplemented", [576] = "UPNONCE0", [577] = "UPNONCE1", [578] = "UPNONCE2", [579] = "UPNONCE3", [580] = "UPNONCE4", [581] = "UPNONCE5", [582] = "UPNONCE6", [583] = "UPNONCE7", [584] = "UPNONCE8", [585] = "UPNONCE9", [586] = "UPNONCE10", [587] = "UPNONCE11", [588] = "UPNONCE12" })

do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  TX = logicview.idx(_lv_seq, 0)
  RX = logicview.idx(_lv_seq, 1)
end
_decoder = {
  api_version = 3,
  id = "mrf24j40",
  name = "MRF24J40",
  longname = "Microchip MRF24J40",
  desc = "IEEE 802.15.4 2.4 GHz RF tranceiver chip.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "sread", "Short register read" }, { "swrite", "Short register write" }, { "lread", "Long register read" }, { "lwrite", "Long register write" }, { "warning", "Warning" }, { "tx-frame", "TX frame" }, { "rx-frame", "RX frame" }, { "tx-retry-1", "1x TX retry" }, { "tx-retry-2", "2x TX retry" }, { "tx-retry-3", "3x TX retry" }, { "tx-fail", "TX fail (too many retries)" }, { "ccafail", "CCAFAIL (channel busy)" } },
  annotation_rows = { { "reads", "Reads", { 0, 2 } }, { "writes", "Writes", { 1, 3 } }, { "warnings", "Warnings", { 4 } }, { "tx-frames", "TX frames", { 5 } }, { "rx-frames", "RX frames", { 6 } }, { "tx-retries-1", "1x TX retries", { 7 } }, { "tx-retries-2", "2x TX retries", { 8 } }, { "tx-retries-3", "3x TX retries", { 9 } }, { "tx-fails", "TX fails", { 10 } }, { "ccafails", "CCAFAILs", { 11 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = { 0, 0 }, { 0, 0 }
    self.ss_frame = _lv_a0
    self.es_frame = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bytes = _lv_a0
    self.miso_bytes = _lv_a1
  end
  self.framecache = { {  }, {  } }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.putw(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 4, { msg } })
end
function _decoder.reset_data(self)
  self.mosi_bytes = {  }
  self.miso_bytes = {  }
end
function _decoder.handle_short(self)
  local write, reg, reg_desc, rxtx, bit0, idx, xmitdir, frame, numretries, txfail
  write = (logicview.idx(self.mosi_bytes, 0) & 1)
  reg = ((logicview.idx(self.mosi_bytes, 0) >> 1) & 63)
  reg_desc = logicview.dget(sregs, reg, "illegal")
  for _lv_item in logicview.iter({ RX, TX }) do
    rxtx = _lv_item
    if logicview.truth(logicview.eq(logicview.idx(self.framecache, rxtx), {  })) then
      goto continue_1
    end
    bit0 = (logicview.idx(self.mosi_bytes, 1) & (1 << 0))
    if logicview.truth((function()
  local _v
  _v = logicview.eq(rxtx, TX)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((function()
  local _v
  _v = logicview.eq(reg_desc, "TXNCON")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bit0, 1)
  return _v
end)()))
  return _v
end)()) then
      goto continue_1
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(rxtx, RX)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((function()
  local _v
  _v = logicview.eq(reg_desc, "RXFLUSH")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bit0, 1)
  return _v
end)()))
  return _v
end)()) then
      goto continue_1
    end
    idx = (function() if logicview.truth(logicview.eq(rxtx, TX)) then return 5 else return 6 end end)()
    xmitdir = (function() if logicview.truth(logicview.eq(rxtx, TX)) then return "TX" else return "RX" end end)()
    frame = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.idx(self.framecache, rxtx)) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02X", b)
  end
  return _lv_out
end)())
    self:put(logicview.idx(self.ss_frame, rxtx), logicview.idx(self.es_frame, rxtx), self.out_ann, { idx, { logicview.pymod("%s frame: %s", { xmitdir, frame }) } })
    logicview.setidx(self.framecache, rxtx, {  })
    ::continue_1::
  end
  if logicview.truth(write) then
    self:putx({ 1, { logicview.pymod("%s: {$}", { reg_desc, logicview.pymod("@%02X", logicview.idx(self.mosi_bytes, 1)) }) } })
  else
    self:putx({ 0, { logicview.pymod("%s: {$}", reg_desc), logicview.pymod("@%02X", logicview.idx(self.miso_bytes, 1)) } })
    numretries = ((logicview.idx(self.miso_bytes, 1) & 192) >> 6)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(reg_desc, "TXSTAT")
  if not logicview.truth(_v) then return _v end
  _v = (numretries > 0)
  return _v
end)()) then
      txfail = (function() if logicview.truth((not logicview.eq((logicview.idx(self.miso_bytes, 1) & (1 << 0)), 0))) then return 1 else return 0 end end)()
      idx = logicview.add(logicview.add(6, numretries), txfail)
      if logicview.truth(txfail) then
        self:putx({ idx, { "TX fail (>= 4 retries)", "TX fail" } })
      else
        self:putx({ idx, { logicview.pymod("TX retries: %d", numretries) } })
      end
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(reg_desc, "TXSTAT")
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq((logicview.idx(self.miso_bytes, 1) & (1 << 5)), 0))
  return _v
end)()) then
      self:putx({ 11, { "CCAFAIL (channel busy)", "CCAFAIL" } })
    end
  end
end
function _decoder.handle_long(self)
  local dword, write, reg, reg_desc, rxtx
  dword = ((logicview.idx(self.mosi_bytes, 0) << 8) | logicview.idx(self.mosi_bytes, 1))
  write = (dword & (1 << 4))
  reg = ((dword >> 5) & 1023)
  if logicview.truth((reg >= 0)) then
    reg_desc = logicview.pymod("TX:%#x", reg)
  end
  if logicview.truth((reg >= 128)) then
    reg_desc = logicview.pymod("TX beacon:%#x", reg)
  end
  if logicview.truth((reg >= 256)) then
    reg_desc = logicview.pymod("TX GTS1:%#x", reg)
  end
  if logicview.truth((reg >= 384)) then
    reg_desc = logicview.pymod("TX GTS2:%#x", reg)
  end
  if logicview.truth((reg >= 512)) then
    reg_desc = logicview.dget(lregs, reg, "illegal")
  end
  if logicview.truth((reg >= 640)) then
    reg_desc = logicview.pymod("Security keys:%#x", reg)
  end
  if logicview.truth((reg >= 704)) then
    reg_desc = logicview.pymod("Reserved:%#x", reg)
  end
  if logicview.truth((reg >= 768)) then
    reg_desc = logicview.pymod("RX:%#x", reg)
  end
  if logicview.truth(write) then
    self:putx({ 3, { logicview.pymod("%s: {$}", reg_desc), logicview.pymod("@%02X", logicview.idx(self.mosi_bytes, 2)) } })
  else
    self:putx({ 2, { logicview.pymod("%s: {$}", reg_desc), logicview.pymod("@%02X", logicview.idx(self.miso_bytes, 2)) } })
  end
  for _lv_item in logicview.iter({ RX, TX }) do
    rxtx = _lv_item
    if logicview.truth((function()
  local _v
  _v = logicview.eq(rxtx, RX)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.slice(reg_desc, nil, 3, nil), "RX:"))
  return _v
end)()) then
      goto continue_2
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(rxtx, TX)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.slice(reg_desc, nil, 3, nil), "TX:"))
  return _v
end)()) then
      goto continue_2
    end
    if logicview.truth(logicview.eq(logicview.len(logicview.idx(self.framecache, rxtx)), 0)) then
      logicview.setidx(self.ss_frame, rxtx, self.ss_cmd)
    end
    logicview.setidx(self.es_frame, rxtx, self.es_cmd)
    logicview.setidx(self.framecache, rxtx, logicview.add(logicview.idx(self.framecache, rxtx), (function() if logicview.truth(logicview.eq(rxtx, TX)) then return { logicview.idx(self.mosi_bytes, 2) } else return { logicview.idx(self.miso_bytes, 2) } end end)()))
    ::continue_2::
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, mosi, miso
    ptype = logicview.idx(data, 0)
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      do
        local _lv_seq = logicview.slice(data, 1, nil, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cs_old = logicview.idx(_lv_seq, 0)
        cs_new = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((function()
  local _v
  _v = (cs_old ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_old, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 1)
  return _v
end)()) then
        if logicview.truth((not logicview.contains({ 0, 2, 3 }, logicview.len(self.mosi_bytes)))) then
          self:putw({ self.ss_cmd, es }, "Misplaced CS!")
          self:reset_data()
        end
      end
      return
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_seq = logicview.slice(data, 1, nil, nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      mosi = logicview.idx(_lv_seq, 0)
      miso = logicview.idx(_lv_seq, 1)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 0)) then
      self.ss_cmd = ss
    end
    _table.insert(self.mosi_bytes, mosi)
    _table.insert(self.miso_bytes, miso)
    if logicview.truth((logicview.len(self.mosi_bytes) < 2)) then
      return
    end
    if logicview.truth((logicview.idx(self.mosi_bytes, 0) & 128)) then
      if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 3)) then
        self.es_cmd = es
        self:handle_long()
        self:reset_data()
      end
    else
      self.es_cmd = es
      self:handle_short()
      self:reset_data()
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
