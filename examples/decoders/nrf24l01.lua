-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Jens Steinhauser <jens.steinhauser@gmail.com>
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
local ChannelError, regs, xn297_regs, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
regs = logicview.dict({ [0] = { "CONFIG", 1 }, [1] = { "EN_AA", 1 }, [2] = { "EN_RXADDR", 1 }, [3] = { "SETUP_AW", 1 }, [4] = { "SETUP_RETR", 1 }, [5] = { "RF_CH", 1 }, [6] = { "RF_SETUP", 1 }, [7] = { "STATUS", 1 }, [8] = { "OBSERVE_TX", 1 }, [9] = { "RPD", 1 }, [10] = { "RX_ADDR_P0", 5 }, [11] = { "RX_ADDR_P1", 5 }, [12] = { "RX_ADDR_P2", 1 }, [13] = { "RX_ADDR_P3", 1 }, [14] = { "RX_ADDR_P4", 1 }, [15] = { "RX_ADDR_P5", 1 }, [16] = { "TX_ADDR", 5 }, [17] = { "RX_PW_P0", 1 }, [18] = { "RX_PW_P1", 1 }, [19] = { "RX_PW_P2", 1 }, [20] = { "RX_PW_P3", 1 }, [21] = { "RX_PW_P4", 1 }, [22] = { "RX_PW_P5", 1 }, [23] = { "FIFO_STATUS", 1 }, [28] = { "DYNPD", 1 }, [29] = { "FEATURE", 1 } })
xn297_regs = logicview.dict({ [25] = { "DEMOD_CAL", 1 }, [26] = { "RF_CAL2", 6 }, [27] = { "DEM_CAL2", 3 }, [30] = { "RF_CAL", 3 }, [31] = { "BB_CAL", 5 } })
_decoder = {
  api_version = 3,
  id = "nrf24l01",
  name = "nRF24L01(+)",
  longname = "Nordic Semiconductor nRF24L01(+)",
  desc = "2.4GHz RF transceiver chip.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "chip", desc = "Chip type", default = "nrf24l01", values = { "nrf24l01", "xn297" } }) },
  annotations = { { "cmd", "Commands sent to the device" }, { "tx-data", "Payload sent to the device" }, { "register", "Registers read from the device" }, { "rx-data", "Payload read from the device" }, { "warning", "Warnings" } },
  annotation_rows = { { "commands", "Commands", { 0, 1 } }, { "responses", "Responses", { 2, 3 } }, { "warnings", "Warnings", { 4 } } },
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
  if logicview.truth(logicview.eq(logicview.idx(self.options, "chip"), "xn297")) then
    logicview.dict_update(regs, xn297_regs)
  end
end
function _decoder.warn(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { self.ann_warn, { msg } })
end
function _decoder.putp(self, pos, ann, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { ann, { msg } })
end
function _decoder.putp_ann(self, pos, ann, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { ann, msg })
end
function _decoder.next(self)
  self.first = true
  self.cmd = nil
  self.min = 0
  self.max = 0
  self.mb = {  }
  self.mb_s = (-1)
  self.mb_e = (-1)
end
function _decoder.mosi_bytes(self)
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.mb) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(b, 0)
  end
  return _lv_out
end)()
end
function _decoder.miso_bytes(self)
  return (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.mb) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(b, 1)
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
  if logicview.truth(logicview.contains({ "W_REGISTER", "ACTIVATE", "RST_FSPI" }, self.cmd)) then
    self.mb_s = logicview.idx(pos, 0)
  else
    self:putp(pos, self.ann_cmd, self:format_command())
  end
end
function _decoder.format_command(self)
  local reg
  if logicview.truth(logicview.eq(self.cmd, "R_REGISTER")) then
    reg = (function() if logicview.truth(logicview.contains(regs, self.dat)) then return logicview.idx(logicview.idx(regs, self.dat), 0) else return "unknown register" end end)()
    return logicview.pyformat("Cmd R_REGISTER \"{}\"", { reg }, logicview.dict({}))
  else
    return logicview.pyformat("Cmd {}", { self.cmd }, logicview.dict({}))
  end
end
function _decoder.parse_command(self, b)
  local buflen, buglen, c, d, m
  buflen = 32
  if logicview.truth(logicview.eq(logicview.idx(self.options, "chip"), "xn297")) then
    buglen = 64
  end
  if logicview.truth(logicview.contains({ 0, 32 }, (b & 224))) then
    c = (function() if logicview.truth((not logicview.truth((b & 224)))) then return "R_REGISTER" else return "W_REGISTER" end end)()
    d = (b & 31)
    m = (function() if logicview.truth(logicview.contains(regs, d)) then return logicview.idx(logicview.idx(regs, d), 1) else return 1 end end)()
    return { c, d, 1, m }
  end
  if logicview.truth(logicview.eq(b, 80)) then
    return { "ACTIVATE", nil, 1, 1 }
  end
  if logicview.truth(logicview.eq(b, 97)) then
    return { "R_RX_PAYLOAD", nil, 1, buflen }
  end
  if logicview.truth(logicview.eq(b, 96)) then
    return { "R_RX_PL_WID", nil, 1, 1 }
  end
  if logicview.truth(logicview.eq(b, 160)) then
    return { "W_TX_PAYLOAD", nil, 1, buflen }
  end
  if logicview.truth(logicview.eq(b, 176)) then
    return { "W_TX_PAYLOAD_NOACK", nil, 1, buflen }
  end
  if logicview.truth(logicview.eq((b & 248), 168)) then
    return { "W_ACK_PAYLOAD", (b & 7), 1, buflen }
  end
  if logicview.truth(logicview.eq(b, 225)) then
    return { "FLUSH_TX", nil, 0, 0 }
  end
  if logicview.truth(logicview.eq(b, 226)) then
    return { "FLUSH_RX", nil, 0, 0 }
  end
  if logicview.truth(logicview.eq(b, 227)) then
    return { "REUSE_TX_PL", nil, 0, 0 }
  end
  if logicview.truth(logicview.eq(b, 255)) then
    return { "NOP", nil, 0, 0 }
  end
  if logicview.truth(logicview.eq(logicview.idx(self.options, "chip"), "xn297")) then
    if logicview.truth(logicview.eq(b, 253)) then
      return { "CE_FSPI_ON", nil, 1, 1 }
    end
    if logicview.truth(logicview.eq(b, 252)) then
      return { "CE_FSPI_OFF", nil, 1, 1 }
    end
    if logicview.truth(logicview.eq(b, 83)) then
      return { "RST_FSPI", nil, 1, 1 }
    end
  end
end
function _decoder.decode_register(self, pos, ann, regid, data)
  local name, label
  if logicview.truth(logicview.eq(logicview.pytype(regid), int)) then
    if logicview.truth((not logicview.contains(regs, regid))) then
      self:warn(pos, "unknown register")
      return
    end
    name = logicview.idx(logicview.idx(regs, regid), 0)
  else
    name = regid
  end
  data = logicview.reversed(data)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmd, "W_REGISTER")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ann, self.ann_cmd)
  return _v
end)()) then
    label = logicview.pyformat("{}: {}", { self:format_command(), name }, logicview.dict({}))
  else
    label = logicview.pyformat("Reg {}", { name }, logicview.dict({}))
  end
  self:decode_mb_data(pos, ann, data, label, true)
end
function _decoder.decode_mb_data(self, pos, ann, data, label, always_hex)
  local escape
  if logicview.truth(always_hex) then
    escape = function(b)
      return logicview.pyformat("{:02X}", { b }, logicview.dict({}))
    end
  else
    escape = function(b)
      local c
      c = _string.char(b)
      if logicview.truth((not logicview.truth(str:isprintable(c)))) then
        return logicview.pyformat("\\x{:02X}", { b }, logicview.dict({}))
      end
      return c
    end
  end
  data = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = escape(b)
  end
  return _lv_out
end)())
  self:putp_ann(pos, ann, { logicview.add(label, " = \"{$}\""), logicview.add("@", logicview.strip(data)) })
end
function _decoder.finish_command(self, pos)
  local always_hex, lbl, msg
  always_hex = true
  if logicview.truth(logicview.eq(self.cmd, "R_REGISTER")) then
    self:decode_register(pos, self.ann_reg, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "W_REGISTER")) then
    self:decode_register(pos, self.ann_cmd, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "R_RX_PAYLOAD")) then
    self:decode_mb_data(pos, self.ann_rx, self:miso_bytes(), "RX payload", always_hex)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmd, "W_TX_PAYLOAD")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmd, "W_TX_PAYLOAD_NOACK")
  return _v
end)()) then
    self:decode_mb_data(pos, self.ann_tx, self:mosi_bytes(), "TX payload", always_hex)
  elseif logicview.truth(logicview.eq(self.cmd, "W_ACK_PAYLOAD")) then
    lbl = logicview.pyformat("ACK payload for pipe {}", { self.dat }, logicview.dict({}))
    self:decode_mb_data(pos, self.ann_tx, self:mosi_bytes(), lbl, always_hex)
  elseif logicview.truth(logicview.eq(self.cmd, "R_RX_PL_WID")) then
    msg = logicview.pyformat("Payload width = {}", { logicview.idx(logicview.idx(self.mb, 0), 1) }, logicview.dict({}))
    self:putp(pos, self.ann_reg, msg)
  elseif logicview.truth(logicview.eq(self.cmd, "ACTIVATE")) then
    if logicview.truth(logicview.eq(logicview.idx(self:mosi_bytes(), 0), 140)) then
      self.cmd = "DEACTIVATE"
    elseif logicview.truth((not logicview.eq(logicview.idx(self:mosi_bytes(), 0), 115))) then
      self:warn(pos, "wrong data for \"ACTIVATE\" command")
    end
    self:putp(pos, self.ann_cmd, self:format_command())
  elseif logicview.truth(logicview.eq(self.cmd, "RST_FSPI")) then
    if logicview.truth(logicview.eq(logicview.idx(self:mosi_bytes(), 0), 90)) then
      self.cmd = "RST_FSPI_HOLD"
    elseif logicview.truth(logicview.eq(logicview.idx(self:mosi_bytes(), 0), 165)) then
      self.cmd = "RST_FSPI_RELS"
    else
      self:warn(pos, "wrong data for \"RST_FSPI\" command")
    end
    self:putp(pos, self.ann_cmd, self:format_command())
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
    if logicview.truth(logicview.eq(ptype, "TRANSFER")) then
      if logicview.truth(self.cmd) then
        if logicview.truth((logicview.len(self.mb) < self.min)) then
          self:warn({ ss, ss }, "missing data bytes")
        elseif logicview.truth(self.mb) then
          self:finish_command({ self.mb_s, self.mb_e })
        end
      end
      self:next()
      self.cs_was_released = true
    elseif logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
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
            self:finish_command({ self.mb_s, self.mb_e })
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
      pos = { ss, es }
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
        self:decode_register(pos, self.ann_reg, "STATUS", { miso })
      elseif logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.cmd))
  if logicview.truth(_v) then return _v end
  _v = (logicview.len(self.mb) >= self.max)
  return _v
end)()) then
        self:warn(pos, "excess byte")
      else
        if logicview.truth(logicview.eq(self.mb_s, (-1))) then
          self.mb_s = ss
        end
        self.mb_e = es
        _table.insert(self.mb, { mosi, miso })
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
