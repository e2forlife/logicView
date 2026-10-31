-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Marco Geisler <m-sigrok@mageis.de>
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
local namedtuple, ANN_STROBE, ANN_SINGLE_READ, ANN_SINGLE_WRITE, ANN_BURST_READ, ANN_BURST_WRITE, ANN_STATUS_READ, ANN_STATUS, ANN_WARN, Pos, Data, ChannelError, Decoder, regs, strobes, status_reg_states
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
regs = logicview.dict({ [0] = "IOCFG2", [1] = "IOCFG1", [2] = "IOCFG0", [3] = "FIFOTHR", [4] = "SYNC1", [5] = "SYNC0", [6] = "PKTLEN", [7] = "PKTCTRL1", [8] = "PKTCTRL0", [9] = "ADDR", [10] = "CHANNR", [11] = "FSCTRL1", [12] = "FSCTRL0", [13] = "FREQ2", [14] = "FREQ1", [15] = "FREQ0", [16] = "MDMCFG4", [17] = "MDMCFG3", [18] = "MDMCFG2", [19] = "MDMCFG1", [20] = "MDMCFG0", [21] = "DEVIATN", [22] = "MCSM2", [23] = "MCSM1", [24] = "MCSM0", [25] = "FOCCFG", [26] = "BSCFG", [27] = "AGCTRL2", [28] = "AGCTRL1", [29] = "AGCTRL0", [30] = "WOREVT1", [31] = "WOREVT0", [32] = "WORCTRL", [33] = "FREND1", [34] = "FREND0", [35] = "FSCAL3", [36] = "FSCAL2", [37] = "FSCAL1", [38] = "FSCAL0", [39] = "RCCTRL1", [40] = "RCCTRL0", [41] = "FSTEST", [42] = "PTEST", [43] = "AGCTEST", [44] = "TEST2", [45] = "TEST1", [46] = "TEST0", [48] = "PARTNUM", [49] = "VERSION", [50] = "FREQEST", [51] = "LQI", [52] = "RSSI", [53] = "MARCSTATE", [54] = "WORTIME1", [55] = "WORTIME0", [56] = "PKTSTATUS", [57] = "VCO_VC_DAC", [58] = "TXBYTES", [59] = "RXBYTES", [60] = "RCCTRL1_STATUS", [61] = "RCCTRL0_STATUS", [62] = "PATABLE", [63] = "FIFO" })
strobes = logicview.dict({ [48] = "SRES", [49] = "SFSTXON", [50] = "SXOFF", [51] = "SCAL", [52] = "SRX", [53] = "STX", [54] = "SIDLE", [55] = "", [56] = "SWOR", [57] = "SPWD", [58] = "SFRX", [59] = "SFTX", [60] = "SWORRST", [61] = "SNOP" })
status_reg_states = logicview.dict({ [0] = "IDLE", [1] = "RX", [2] = "TX", [3] = "FSTXON", [4] = "CALIBRATE", [5] = "SETTLING", [6] = "RXFIFO_OVERFLOW", [7] = "TXFIFO_OVERFLOW" })

do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(8) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_STROBE = logicview.idx(_lv_seq, 0)
  ANN_SINGLE_READ = logicview.idx(_lv_seq, 1)
  ANN_SINGLE_WRITE = logicview.idx(_lv_seq, 2)
  ANN_BURST_READ = logicview.idx(_lv_seq, 3)
  ANN_BURST_WRITE = logicview.idx(_lv_seq, 4)
  ANN_STATUS_READ = logicview.idx(_lv_seq, 5)
  ANN_STATUS = logicview.idx(_lv_seq, 6)
  ANN_WARN = logicview.idx(_lv_seq, 7)
end
Pos = (function() local _f = { "ss", "es" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
Data = (function() local _f = { "mosi", "miso" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "cc1101",
  name = "CC1101",
  longname = "Texas Instruments CC1101",
  desc = "Low-power sub-1GHz RF transceiver chip.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "strobe", "Command strobe" }, { "single_read", "Single register read" }, { "single_write", "Single register write" }, { "burst_read", "Burst register read" }, { "burst_write", "Burst register write" }, { "status_read", "Status read" }, { "status", "Status register" }, { "warning", "Warning" } },
  annotation_rows = { { "cmd", "Commands", { 0 } }, { "data", "Data", { 1, 2, 3, 4, 5 } }, { "status", "Status register", { 6 } }, { "warnings", "Warnings", { 7 } } },
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
  self:put(pos.ss, pos.es, self.out_ann, { ANN_WARN, { msg } })
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
  c = self:parse_command(b)
  if logicview.truth((c == nil)) then
    self:warn(pos, "unknown command")
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
  if logicview.truth(logicview.eq(self.cmd, "Strobe")) then
    self:put_ann(pos, ANN_STROBE, { self:format_command() })
  else
    self.ss_mb = pos.ss
  end
end
function _decoder.format_command(self)
  local reg
  if logicview.truth(logicview.contains({ "Read", "Burst read", "Write", "Burst write", "Status read" }, self.cmd)) then
    return self.cmd
  end
  if logicview.truth(logicview.eq(self.cmd, "Strobe")) then
    reg = logicview.dget(strobes, self.dat, "unknown strobe")
    return logicview.pyformat("{} {}", { self.cmd, reg }, logicview.dict({}))
  else
    return logicview.pyformat("TODO Cmd {}", { self.cmd }, logicview.dict({}))
  end
end
function _decoder.parse_command(self, b)
  local addr
  addr = (b & 63)
  if logicview.truth((function()
  local _v
  _v = (addr < 48)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(addr, 62)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(addr, 63)
  return _v
end)()) then
    if logicview.truth(logicview.eq((b & 192), 0)) then
      return { "Write", addr, 1, 1 }
    end
    if logicview.truth(logicview.eq((b & 192), 64)) then
      return { "Burst write", addr, 1, 99999 }
    end
    if logicview.truth(logicview.eq((b & 192), 128)) then
      return { "Read", addr, 1, 1 }
    end
    if logicview.truth(logicview.eq((b & 192), 192)) then
      return { "Burst read", addr, 1, 99999 }
    else
      self:warn(pos, "unknown address/command combination")
    end
  else
    if logicview.truth(logicview.eq((b & 64), 0)) then
      return { "Strobe", addr, 0, 0 }
    end
    if logicview.truth(logicview.eq((b & 192), 192)) then
      return { "Status read", addr, 1, 99999 }
    else
      self:warn(pos, "unknown address/command combination")
    end
  end
end
function _decoder.decode_reg(self, pos, ann, regid, data)
  local name, label
  if logicview.truth(logicview.eq(logicview.pytype(regid), int)) then
    if logicview.truth((not logicview.contains(regs, regid))) then
      self:warn(pos, "unknown register")
      return
    end
    name = logicview.pyformat("{} ({:02X})", { logicview.idx(regs, regid), regid }, logicview.dict({}))
  else
    name = regid
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(regid, "STATUS")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, ANN_STATUS)
  return _v
end)()) then
    label = "Status"
    self:decode_status_reg(pos, ann, data, label)
  else
    if logicview.truth(logicview.contains({ "Write", "Read", "Status read", "Burst read", "Burst write" }, self.cmd)) then
      label = logicview.pyformat("{}: {}", { self:format_command(), name }, logicview.dict({}))
    else
      label = logicview.pyformat("Reg ({}) {}", { self.cmd, name }, logicview.dict({}))
    end
    self:decode_mb_data(pos, ann, data, label)
  end
end
function _decoder.decode_status_reg(self, pos, ann, data, label)
  local status, longtext_chiprdy, state, longtext_state, fifo_bytes, longtext_fifo, text, longtext
  status = logicview.idx(data, 0)
  if logicview.truth(logicview.eq((status & 128), 128)) then
    longtext_chiprdy = "CHIP_RDYn is high! "
  else
    longtext_chiprdy = ""
  end
  state = ((status & 112) >> 4)
  longtext_state = logicview.pyformat("STATE is {}, ", { logicview.idx(status_reg_states, state) }, logicview.dict({}))
  fifo_bytes = (status & 15)
  if logicview.truth(logicview.contains({ "Single read", "Status read", "Burst read" }, self.cmd)) then
    longtext_fifo = logicview.pyformat("{} bytes available in RX FIFO", { fifo_bytes }, logicview.dict({}))
  else
    longtext_fifo = logicview.pyformat("{} bytes free in TX FIFO", { fifo_bytes }, logicview.dict({}))
  end
  text = logicview.add(logicview.pyformat("{} = ", { label }, logicview.dict({})), "{$}")
  longtext = logicview.join("", { text, "; ", longtext_chiprdy, longtext_state, longtext_fifo })
  self:put_ann(pos, ann, { longtext, text, logicview.pymod("@%02X", status) })
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
  text = logicview.add(logicview.pyformat("{} = ", { label }, logicview.dict({})), "{$}")
  self:put_ann(pos, ann, { text, logicview.add("@", data) })
end
function _decoder.finish_command(self, pos)
  if logicview.truth(logicview.eq(self.cmd, "Write")) then
    self:decode_reg(pos, ANN_SINGLE_WRITE, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Burst write")) then
    self:decode_reg(pos, ANN_BURST_WRITE, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Read")) then
    self:decode_reg(pos, ANN_SINGLE_READ, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Burst read")) then
    self:decode_reg(pos, ANN_BURST_READ, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Strobe")) then
    self:decode_reg(pos, ANN_STROBE, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "Status read")) then
    self:decode_reg(pos, ANN_STATUS_READ, self.dat, self:miso_bytes())
  else
    self:warn(pos, "unhandled command")
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
            self:warn({ ss, ss }, "missing data bytes")
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
        _error(ChannelError("Both MISO and MOSI pins required."), 0)
      end
      if logicview.truth(self.first) then
        self.first = false
        self:decode_command(pos, mosi)
        self:decode_reg(pos, ANN_STATUS, "STATUS", { miso })
      elseif logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.cmd))
  if logicview.truth(_v) then return _v end
  _v = (logicview.len(self.mb) >= self.max)
  return _v
end)()) then
        self:warn(pos, "excess byte")
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
