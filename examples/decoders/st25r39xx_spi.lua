-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019-2020 Benjamin Vernoux <bvernoux@gmail.com>
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
local namedtuple, SrdIntEnum, Ann, Pos, Data, Decoder, dir_cmd, regsSpaceA, regsSpaceB, regsTest
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
dir_cmd = logicview.dict({ [192] = "SET_DEFAULT", [193] = "SET_DEFAULT", [194] = "STOP", [195] = "STOP", [196] = "TXCRC", [197] = "TXNOCRC", [198] = "TXREQA", [199] = "TXWUPA", [200] = "NFCINITFON", [201] = "NFCRESFON", [205] = "GOIDLE", [206] = "GOHALT", [208] = "STOPRX", [209] = "STARRX", [210] = "SETAMSTATE", [211] = "MAMP", [213] = "RSTRXGAIN", [214] = "ADJREG", [216] = "CALDRVTIM", [217] = "MPHASE", [218] = "CLRRSSI", [219] = "CLRFIFO", [220] = "TRMODE", [221] = "CALCAPA", [222] = "MCAPA", [223] = "MPOWER", [224] = "STARGPTIM", [225] = "STARWTIM", [226] = "STARMSKTIM", [227] = "STARNRESPTIM", [228] = "STARPPON2TIM", [232] = "STOPNRESTIM", [250] = "RFU", [251] = "REGSPACEB", [252] = "TESTACCESS" })
regsSpaceA = logicview.dict({ [0] = "IOCFG1", [1] = "IOCFG2", [2] = "OPCTRL", [3] = "MODEDEF", [4] = "BITRATE", [5] = "TYPEA", [6] = "TYPEB", [7] = "TYPEBF", [8] = "NFCIP1", [9] = "STREAM", [10] = "AUX", [11] = "RXCFG1", [12] = "RXCFG2", [13] = "RXCFG3", [14] = "RXCFG4", [15] = "MSKRXTIM", [16] = "NRESPTIM1", [17] = "NRESPTIM2", [18] = "TIMEMV", [19] = "GPTIM1", [20] = "GPTIM2", [21] = "PPON2", [22] = "MSKMAINIRQ", [23] = "MSKTIMNFCIRQ", [24] = "MSKERRWAKEIRQ", [25] = "TARGIRQ", [26] = "MAINIRQ", [27] = "TIMNFCIRQ", [28] = "ERRWAKEIRQ", [29] = "TARGIRQ", [30] = "FIFOSTAT1", [31] = "FIFOSTAT2", [32] = "COLLDISP", [33] = "TARGDISP", [34] = "NBTXB1", [35] = "NBTXB2", [36] = "BITRATEDET", [37] = "ADCONVOUT", [38] = "ANTTUNECTRL1", [39] = "ANTTUNECTRL2", [40] = "TXDRV", [41] = "TARGMOD", [42] = "EXTFIELDON", [43] = "EXTFIELDOFF", [44] = "REGVDDCTRL", [45] = "RSSIDISP", [46] = "GAINSTATE", [47] = "CAPACTRL", [48] = "CAPADISP", [49] = "AUXDISP", [50] = "WAKETIMCTRL", [51] = "AMPCFG", [52] = "AMPREF", [53] = "AMPAAVGDISP", [54] = "AMPDISP", [55] = "PHASECFG", [56] = "PHASEREF", [57] = "PHASEAAVGDISP", [58] = "PHASEDISP", [59] = "CAPACFG", [60] = "CAPAREF", [61] = "CAPAAAVGDISP", [62] = "CAPADISP", [63] = "ICIDENT", [160] = "PT_memLoadA", [168] = "PT_memLoadF", [172] = "PT_memLoadTSN", [191] = "PT_memRead" })
regsSpaceB = logicview.dict({ [5] = "EMDSUPPRCONF", [6] = "SUBCSTARTIM", [11] = "P2PRXCONF", [12] = "CORRCONF1", [13] = "CORRCONF2", [15] = "SQUELSHTIM", [21] = "NFCGUARDTIM", [40] = "AUXMODSET", [41] = "TXDRVTIM", [42] = "RESAMMODE", [43] = "TXDRVTIMDISP", [44] = "REGDISP", [48] = "OSHOOTCONF1", [49] = "OSHOOTCONF2", [50] = "USHOOTCONF1", [51] = "USHOOTCONF2" })
regsTest = logicview.dict({ [1] = "ANTSTOBS" })

Ann = logicview.int_enum(logicview.split("BURST_READ BURST_WRITE     BURST_READB BURST_WRITEB BURST_READT BURST_WRITET     DIRECTCMD FIFO_WRITE FIFO_READ STATUS WARN", ' '))
Pos = (function() local _f = { "ss", "es" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
Data = (function() local _f = { "mosi", "miso" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
_decoder = {
  api_version = 3,
  id = "st25r39xx_spi",
  name = "ST25R39xx (SPI mode)",
  longname = "STMicroelectronics ST25R39xx",
  desc = "High performance NFC universal device and EMVCo reader protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "Read", "Burst register read" }, { "Write", "Burst register write" }, { "ReadB", "Burst register SpaceB read" }, { "WriteB", "Burst register SpaceB write" }, { "ReadT", "Burst register Test read" }, { "WriteT", "Burst register Test write" }, { "Cmd", "Direct command" }, { "FIFOW", "FIFO write" }, { "FIFOR", "FIFO read" }, { "status_reg", "Status register" }, { "warning", "Warning" } },
  annotation_rows = { { "regs", "Regs", { 0, 1, 2, 3, 4, 5 } }, { "cmds", "Commands", { 6 } }, { "data", "Data", { 7, 8 } }, { "status", "Status register", { 9 } }, { "warnings", "Warnings", { 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self:next()
  self.requirements_met = true
  self.cs_was_released = false
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.warn(self, pos, msg)
  self:put(pos.ss, pos.es, self.out_ann, { Ann.WARN, { msg } })
end
function _decoder.putp(self, pos, ann, msg)
  self:put(pos.ss, pos.es, self.out_ann, { ann, { msg } })
end
function _decoder.putp2(self, pos, ann, msg1, msg2)
  self:put(pos.ss, pos.es, self.out_ann, { ann, { msg1, msg2 } })
end
function _decoder.put_ann(self, pos, ann, data)
  self:put(pos.ss, pos.es, self.out_ann, { ann, data })
end
function _decoder.next(self)
  self.first = true
  self.cmd = nil
  self.min = 0
  self.max = 0
  self.mb = {  }
  self.ss_mb = (-1)
  self.es_mb = (-1)
end
function _decoder.mosi_bytes(self)
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.mb) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = b.mosi
  end
  return _lv_out
end)()
end
function _decoder.miso_bytes(self)
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.mb) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = b.miso
  end
  return _lv_out
end)()
end
function _decoder.decode_command(self, pos, b)
  local c
  c = self:parse_command(pos, b)
  if logicview.truth((c == nil)) then
    self:warn(pos, "Unknown command")
    return
  end
  do
    local _lv_seq = c
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    self.cmd = logicview.idx(_lv_seq, 0)
    self.dat = logicview.idx(_lv_seq, 1)
    self.min = logicview.idx(_lv_seq, 2)
    self.max = logicview.idx(_lv_seq, 3)
  end
  if logicview.truth(logicview.eq(self.cmd, "Cmd")) then
    self:putp(pos, Ann.DIRECTCMD, self:format_command())
  else
    self.ss_mb = pos.ss
  end
end
function _decoder.format_command(self)
  local reg
  if logicview.truth(logicview.contains({ "Write", "Read", "WriteB", "ReadB", "WriteT", "ReadT", "FIFO Write", "FIFO Read" }, self.cmd)) then
    return self.cmd
  end
  if logicview.truth(logicview.eq(self.cmd, "Cmd")) then
    reg = logicview.dget(dir_cmd, self.dat, "Unknown direct command")
    return logicview.pyformat("{} {}", { self.cmd, reg }, logicview.dict({}))
  else
    return logicview.pyformat("TODO Cmd {}", { self.cmd }, logicview.dict({}))
  end
end
function _decoder.parse_command(self, pos, b)
  local addr
  addr = (b & 63)
  if logicview.truth(logicview.eq(self.cmd, "Space B")) then
    if logicview.truth(logicview.eq((b & 192), 0)) then
      return { "WriteB", addr, 1, 99999 }
    end
    if logicview.truth(logicview.eq((b & 192), 64)) then
      return { "ReadB", addr, 1, 99999 }
    else
      self:warn(pos, "Unknown address/command combination")
    end
  elseif logicview.truth(logicview.eq(self.cmd, "TestAccess")) then
    if logicview.truth(logicview.eq((b & 192), 0)) then
      return { "WriteT", addr, 1, 99999 }
    end
    if logicview.truth(logicview.eq((b & 192), 64)) then
      return { "ReadT", addr, 1, 99999 }
    else
      self:warn(pos, "Unknown address/command combination")
    end
  elseif logicview.truth((b <= 127)) then
    if logicview.truth(logicview.eq((b & 192), 0)) then
      return { "Write", addr, 1, 99999 }
    end
    if logicview.truth(logicview.eq((b & 192), 64)) then
      return { "Read", addr, 1, 99999 }
    else
      self:warn(pos, "Unknown address/command combination")
    end
  else
    if logicview.truth(logicview.eq(b, 128)) then
      return { "FIFO Write", b, 1, 99999 }
    end
    if logicview.truth(logicview.eq(b, 160)) then
      return { "Write", b, 1, 99999 }
    end
    if logicview.truth(logicview.eq(b, 168)) then
      return { "Write", b, 1, 99999 }
    end
    if logicview.truth(logicview.eq(b, 172)) then
      return { "Write", b, 1, 99999 }
    end
    if logicview.truth(logicview.eq(b, 191)) then
      return { "Read", b, 1, 99999 }
    end
    if logicview.truth(logicview.eq(b, 159)) then
      return { "FIFO Read", b, 1, 99999 }
    end
    if logicview.truth((function()
  local _v
  _v = (b >= 12)
  if not logicview.truth(_v) then return _v end
  _v = (b <= 232)
  return _v
end)()) then
      return { "Cmd", b, 0, 0 }
    end
    if logicview.truth(logicview.eq(b, 251)) then
      return { "Space B", b, 0, 0 }
    end
    if logicview.truth(logicview.eq(b, 252)) then
      return { "TestAccess", b, 0, 0 }
    else
      self:warn(pos, "Unknown address/command combination")
    end
  end
end
function _decoder.decode_reg(self, pos, ann, regid, data)
  local name, label
  if logicview.truth(logicview.eq(logicview.pytype(regid), int)) then
    if logicview.truth((function()
  local _v
  _v = logicview.eq(ann, Ann.FIFO_READ)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, Ann.FIFO_WRITE)
  return _v
end)()) then
      name = ""
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(ann, Ann.BURST_READB)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, Ann.BURST_WRITEB)
  return _v
end)()) then
      if logicview.truth((not logicview.contains(regsSpaceB, regid))) then
        self:warn(pos, "Unknown register SpaceB")
        return
      end
      name = logicview.pyformat("{} ({:02X})", { logicview.idx(regsSpaceB, regid), regid }, logicview.dict({}))
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(ann, Ann.BURST_READT)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, Ann.BURST_WRITET)
  return _v
end)()) then
      if logicview.truth((not logicview.contains(regsTest, regid))) then
        self:warn(pos, "Unknown register Test")
        return
      end
      name = logicview.pyformat("{} ({:02X})", { logicview.idx(regsTest, regid), regid }, logicview.dict({}))
    else
      if logicview.truth((not logicview.contains(regsSpaceA, regid))) then
        self:warn(pos, "Unknown register SpaceA")
        return
      end
      name = logicview.pyformat("{} ({:02X})", { logicview.idx(regsSpaceA, regid), regid }, logicview.dict({}))
    end
  else
    name = regid
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(regid, "STATUS")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, Ann.STATUS)
  return _v
end)()) then
    label = "Status"
    self:decode_status_reg(pos, ann, data, label)
  else
    label = logicview.pyformat("{}: {}", { self:format_command(), name }, logicview.dict({}))
  end
  self:decode_mb_data(pos, ann, data, label)
end
function _decoder.decode_status_reg(self, pos, ann, data, label)
end
function _decoder.decode_mb_data(self, pos, ann, data, label)
  local escape, text
  escape = function(b)
    return logicview.pyformat("{:02X}", { b }, logicview.dict({}))
  end
  data = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = escape(b)
  end
  return _lv_out
end)())
  if logicview.truth((function()
  local _v
  _v = logicview.eq(ann, Ann.FIFO_WRITE)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, Ann.FIFO_READ)
  return _v
end)()) then
    text = logicview.add(label, "{$}")
  else
    text = logicview.add(label, " = {$}")
  end
  self:put_ann(pos, ann, { text, logicview.add("@", data) })
end
function _decoder.finish_command(self, pos)
  if logicview.truth(logicview.eq(self.cmd, "Write")) then
    self:decode_reg(pos, Ann.BURST_WRITE, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Read")) then
    self:decode_reg(pos, Ann.BURST_READ, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "WriteB")) then
    self:decode_reg(pos, Ann.BURST_WRITEB, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "ReadB")) then
    self:decode_reg(pos, Ann.BURST_READB, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "WriteT")) then
    self:decode_reg(pos, Ann.BURST_WRITET, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "ReadT")) then
    self:decode_reg(pos, Ann.BURST_READT, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "FIFO Write")) then
    self:decode_reg(pos, Ann.FIFO_WRITE, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "FIFO Read")) then
    self:decode_reg(pos, Ann.FIFO_READ, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Cmd")) then
    self:decode_reg(pos, Ann.DIRECTCMD, self.dat, self:mosi_bytes())
  else
    self:warn(pos, logicview.pyformat("Unhandled command {}", { self.cmd }, logicview.dict({})))
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, data1, data2, mosi, miso, pos
    if logicview.truth((not logicview.truth(self.requirements_met))) then
      return
    end
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      data1 = logicview.idx(_lv_seq, 1)
      data2 = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      if logicview.truth((data1 == nil)) then
        if logicview.truth((data2 == nil)) then
          self.requirements_met = false
          _error(ChannelError("CS# pin required."), 0)
        elseif logicview.truth(logicview.eq(data2, 1)) then
          self.cs_was_released = true
        end
      end
      if logicview.truth((function()
  local _v
  _v = logicview.eq(data1, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data2, 1)
  return _v
end)()) then
        if logicview.truth(self.cmd) then
          if logicview.truth((logicview.len(self.mb) < self.min)) then
            self:warn({ ss, ss }, "Missing data bytes")
          elseif logicview.truth(self.mb) then
            self:finish_command(Pos(self.ss_mb, self.es_mb))
          end
        end
        self:next()
        self.cs_was_released = true
      end
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(ptype, "DATA")
  if not logicview.truth(_v) then return _v end
  _v = self.cs_was_released
  return _v
end)()) then
      do
        local _lv_a0, _lv_a1 = data1, data2
        mosi = _lv_a0
        miso = _lv_a1
      end
      pos = Pos(ss, es)
      if logicview.truth((function()
  local _v
  _v = (miso == nil)
  if logicview.truth(_v) then return _v end
  _v = (mosi == nil)
  return _v
end)()) then
        self.requirements_met = false
        _error(ChannelError("Both MISO and MOSI pins are required."), 0)
      end
      if logicview.truth(self.first) then
        if logicview.truth(logicview.eq(mosi, 251)) then
          self.first = true
          self:decode_command(pos, mosi)
        elseif logicview.truth(logicview.eq(mosi, 252)) then
          self.first = true
          self:decode_command(pos, mosi)
        else
          self.first = false
          self:decode_command(pos, mosi)
        end
      elseif logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.cmd))
  if logicview.truth(_v) then return _v end
  _v = (logicview.len(self.mb) >= self.max)
  return _v
end)()) then
        self:warn(pos, "Excess byte")
      else
        if logicview.truth(logicview.eq(self.ss_mb, (-1))) then
          self.ss_mb = ss
        end
        self.es_mb = es
        _table.insert(self.mb, Data(mosi, miso))
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
