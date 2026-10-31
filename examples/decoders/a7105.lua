-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Richard Li <richard.li@ces.hk>
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
local ChannelError, regs, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
regs = logicview.dict({ [0] = { "MODE", 1 }, [1] = { "MODE_CTRL", 1 }, [2] = { "CALC", 1 }, [3] = { "FIFO_I", 1 }, [4] = { "FIFO_II", 1 }, [5] = { "FIFO_DATA", 1 }, [6] = { "ID_DATA", 1 }, [7] = { "RC_OSC_I", 1 }, [8] = { "RC_OSC_II", 1 }, [9] = { "RC_OSC_III", 1 }, [10] = { "CKO_PIN", 1 }, [11] = { "GPIO1_PIN_I", 1 }, [12] = { "GPIO2_PIN_II", 1 }, [13] = { "CLOCK", 1 }, [14] = { "DATA_RATE", 1 }, [15] = { "PLL_I", 1 }, [16] = { "PLL_II", 1 }, [17] = { "PLL_III", 1 }, [18] = { "PLL_IV", 1 }, [19] = { "PLL_V", 1 }, [20] = { "TX_I", 1 }, [21] = { "TX_II", 1 }, [22] = { "DELAY_I", 1 }, [23] = { "DELAY_II", 1 }, [24] = { "RX", 1 }, [25] = { "RX_GAIN_I", 1 }, [26] = { "RX_GAIN_II", 1 }, [27] = { "RX_GAIN_III", 1 }, [28] = { "RX_GAIN_IV", 1 }, [29] = { "RSSI_THRES", 1 }, [30] = { "ADC", 1 }, [31] = { "CODE_I", 1 }, [32] = { "CODE_II", 1 }, [33] = { "CODE_III", 1 }, [34] = { "IF_CAL_I", 1 }, [35] = { "IF_CAL_II", 1 }, [36] = { "VCO_CURR_CAL", 1 }, [37] = { "VCO_SB_CALC_I", 1 }, [38] = { "VCO_SB_CALC_II", 1 }, [39] = { "BATT_DETECT", 1 }, [40] = { "TX_TEST", 1 }, [41] = { "RX_DEM_TEST_I", 1 }, [42] = { "RX_DEM_TEST_II", 1 }, [43] = { "CPC", 1 }, [44] = { "CRYSTAL_TEST", 1 }, [45] = { "PLL_TEST", 1 }, [46] = { "VCO_TEST_I", 1 }, [47] = { "VCO_TEST_II", 1 }, [48] = { "IFAT", 1 }, [49] = { "RSCALE", 1 }, [50] = { "FILTER_TEST", 1 }, [51] = { "UNKNOWN", 1 } })
_decoder = {
  api_version = 3,
  id = "a7105",
  name = "A7105",
  longname = "AMICCOM A7105",
  desc = "2.4GHz FSK/GFSK Transceiver with 2K ~ 500Kbps data rate.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "cmd", "Commands sent to the device" }, { "tx-data", "Payload sent to the device" }, { "rx-data", "Payload read from the device" }, { "warning", "Warnings" } },
  annotation_rows = { { "commands", "Commands", { 0, 1, 2 } }, { "warnings", "Warnings", { 3 } } },
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
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { self.ann_warn, { msg } })
end
function _decoder.putp(self, pos, ann, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { ann, { msg } })
end
function _decoder.put_ann(self, pos, ann, msg_arr)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { ann, msg_arr })
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
  if logicview.truth(logicview.contains({ "W_REGISTER", "R_REGISTER" }, self.cmd)) then
    self.mb_s = logicview.idx(pos, 0)
  else
    self:putp(pos, self.ann_cmd, self:format_command())
  end
end
function _decoder.format_command(self)
  return logicview.pyformat("Cmd {}", { self.cmd }, logicview.dict({}))
end
function _decoder.parse_command(self, b)
  local c, d, cmd
  if logicview.truth(logicview.eq(b, 5)) then
    return { "W_TX_FIFO", nil, 1, 32 }
  elseif logicview.truth(logicview.eq(b, 69)) then
    return { "R_RX_FIFO", nil, 1, 32 }
  end
  if logicview.truth(logicview.eq(b, 6)) then
    return { "W_ID", nil, 1, 4 }
  elseif logicview.truth(logicview.eq(b, 70)) then
    return { "R_ID", nil, 1, 4 }
  elseif logicview.truth(logicview.eq((b & 128), 0)) then
    if logicview.truth(logicview.eq((b & 64), 0)) then
      c = "W_REGISTER"
    else
      c = "R_REGISTER"
    end
    d = (b & 63)
    return { c, d, 1, 1 }
  else
    cmd = (b & 240)
    if logicview.truth(logicview.eq(cmd, 128)) then
      return { "SLEEP_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 144)) then
      return { "IDLE_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 160)) then
      return { "STANDBY_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 176)) then
      return { "PLL_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 192)) then
      return { "RX_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 208)) then
      return { "TX_MODE", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 224)) then
      return { "FIFO_WRITE_PTR_RESET", nil, 0, 0 }
    end
    if logicview.truth(logicview.eq(cmd, 240)) then
      return { "FIFO_READ_PTR_RESET", nil, 0, 0 }
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
  label = logicview.pyformat("{}: {}", { self:format_command(), name }, logicview.dict({}))
  self:decode_mb_data(pos, ann, data, label, true)
end
function _decoder.decode_mb_data(self, pos, ann, data, label, always_hex)
  local escape, ann_arr
  escape = function(b)
    return logicview.pyformat("{:02X}", { b }, logicview.dict({}))
  end
  data = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = escape(b)
  end
  return _lv_out
end)())
  ann_arr = { logicview.add(label, " = \"{$}\""), logicview.add("@", data) }
  self:put_ann(pos, ann, ann_arr)
end
function _decoder.finish_command(self, pos)
  local always_hex
  always_hex = true
  if logicview.truth(logicview.eq(self.cmd, "R_REGISTER")) then
    self:decode_register(pos, self.ann_cmd, self.dat, self:miso_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "W_REGISTER")) then
    self:decode_register(pos, self.ann_cmd, self.dat, self:mosi_bytes())
  elseif logicview.truth(logicview.eq(self.cmd, "R_RX_FIFO")) then
    self:decode_mb_data(pos, self.ann_rx, self:miso_bytes(), "RX FIFO", always_hex)
  elseif logicview.truth(logicview.eq(self.cmd, "W_TX_FIFO")) then
    self:decode_mb_data(pos, self.ann_tx, self:mosi_bytes(), "TX FIFO", always_hex)
  elseif logicview.truth(logicview.eq(self.cmd, "R_ID")) then
    self:decode_mb_data(pos, self.ann_rx, self:miso_bytes(), "R ID", always_hex)
  elseif logicview.truth(logicview.eq(self.cmd, "W_ID")) then
    self:decode_mb_data(pos, self.ann_tx, self:mosi_bytes(), "W ID", always_hex)
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
  if not logicview.truth(_v) then return _v end
  _v = (mosi == nil)
  return _v
end)()) then
        self.requirements_met = false
        _error(ChannelError("Either MISO or MOSI pins required (3 wires SPI)."), 0)
      end
      if logicview.truth((miso == nil)) then
        miso = mosi
      end
      if logicview.truth((mosi == nil)) then
        mosi = miso
      end
      if logicview.truth(self.first) then
        self.first = false
        self:decode_command(pos, mosi)
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
