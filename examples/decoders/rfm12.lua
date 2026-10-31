-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Sławek Piotrowski <sentinel@atteo.org>
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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "rfm12",
  name = "RFM12",
  longname = "HopeRF RFM12",
  desc = "HopeRF RFM12 wireless transceiver control protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "cmd", "Command" }, { "params", "Command parameters" }, { "disabled", "Disabled bits" }, { "return", "Returned values" }, { "disabled_return", "Disabled returned values" }, { "interpretation", "Interpretation" } },
  annotation_rows = { { "commands", "Commands", { 0, 1, 2 } }, { "return", "Return", { 3, 4 } }, { "interpretation", "Interpretation", { 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bytes = _lv_a0
    self.miso_bytes = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bits = _lv_a0
    self.miso_bits = _lv_a1
  end
  self.row_pos = { 0, 0, 0 }
  self.ann_to_row = { 0, 0, 0, 1, 1, 2 }
  self.last_status = { 0, 0 }
  self.last_config = 8
  self.last_power = 8
  self.last_freq = 1664
  self.last_data_rate = 35
  self.last_fifo_and_reset = 128
  self.last_afc = 247
  self.last_transceiver = 0
  self.last_pll = 119
end
function _decoder.advance_ann(self, ann, length)
  local row
  row = logicview.idx(self.ann_to_row, ann)
  logicview.setidx(self.row_pos, row, logicview.add(logicview.idx(self.row_pos, row), length))
end
function _decoder.putx(self, ann, length, description)
  local row, bit
  if logicview.truth((not logicview.truth(logicview.is_a(description, "list")))) then
    description = { description }
  end
  row = logicview.idx(self.ann_to_row, ann)
  bit = logicview.idx(self.row_pos, row)
  self:put(logicview.idx(logicview.idx(self.mosi_bits, bit), 1), logicview.idx(logicview.idx(self.mosi_bits, (logicview.add(bit, length) - 1)), 2), self.out_ann, { ann, description })
  bit = logicview.add(bit, length)
  logicview.setidx(self.row_pos, row, bit)
end
function _decoder.describe_bits(self, data, names)
  local i, bit
  i = (1 << (logicview.len(names) - 1))
  bit = 0
  while logicview.truth((not logicview.eq(i, 0))) do
    if logicview.truth((not logicview.eq(logicview.idx(names, bit), ""))) then
      self:putx((function() if logicview.truth((data & i)) then return 1 else return 2 end end)(), 1, logicview.idx(names, bit))
    end
    i = (i >> 1)
    bit = logicview.add(bit, 1)
    ::continue_1::
  end
end
function _decoder.describe_return_bits(self, data, names)
  local i, bit
  i = (1 << (logicview.len(names) - 1))
  bit = 0
  while logicview.truth((not logicview.eq(i, 0))) do
    if logicview.truth((not logicview.eq(logicview.idx(names, bit), ""))) then
      self:putx((function() if logicview.truth((data & i)) then return 3 else return 4 end end)(), 1, logicview.idx(names, bit))
    else
      self:advance_ann(3, 1)
    end
    i = (i >> 1)
    bit = logicview.add(bit, 1)
    ::continue_2::
  end
end
function _decoder.describe_changed_bits(self, data, old_data, names)
  local changes, i, bit, s
  changes = (data ~ old_data)
  i = (1 << (logicview.len(names) - 1))
  bit = 0
  while logicview.truth((not logicview.eq(i, 0))) do
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(names, bit), ""))
  if not logicview.truth(_v) then return _v end
  _v = (changes & i)
  return _v
end)()) then
      s = (function() if logicview.truth((data & i)) then return { "+", "Turning on" } else return { "-", "Turning off" } end end)()
      self:putx(5, 1, s)
    else
      self:advance_ann(5, 1)
    end
    i = (i >> 1)
    bit = logicview.add(bit, 1)
    ::continue_3::
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.handle_configuration_cmd(self, cmd, ret)
  local NAMES, bits, old_bits, FREQUENCIES, f, c
  self:putx(0, 8, { "Configuration command", "Configuration" })
  NAMES = { { "Internal data register", "el" }, { "FIFO mode", "ef" } }
  bits = ((logicview.idx(cmd, 1) & 192) >> 6)
  old_bits = ((self.last_config & 192) >> 6)
  self:describe_bits(bits, NAMES)
  self:describe_changed_bits(bits, old_bits, NAMES)
  FREQUENCIES = { "315", "433", "868", "915" }
  f = logicview.add(logicview.idx(FREQUENCIES, ((logicview.idx(cmd, 1) & 48) >> 4)), "MHz")
  self:putx(1, 2, { logicview.add("Frequency: ", f), f })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 48), (self.last_config & 48)))) then
    self:putx(5, 2, { "Changed", "~" })
  end
  c = logicview.pymod("%.1fpF", logicview.add(8.5, logicview.mul((logicview.idx(cmd, 1) & 15), 0.5)))
  self:putx(1, 4, { logicview.add("Capacitance: ", c), c })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 15), (self.last_config & 15)))) then
    self:putx(5, 4, { "Changed", "~" })
  end
  self.last_config = logicview.idx(cmd, 1)
end
function _decoder.handle_power_management_cmd(self, cmd, ret)
  local NAMES, power
  self:putx(0, 8, { "Power management", "Power" })
  NAMES = { { "Receiver chain", "er" }, { "Baseband circuit", "ebb" }, { "Transmission", "et" }, { "Synthesizer", "es" }, { "Crystal oscillator", "ex" }, { "Low battery detector", "eb" }, { "Wake-up timer", "ew" }, { "Clock output off switch", "dc" } }
  self:describe_bits(logicview.idx(cmd, 1), NAMES)
  power = logicview.idx(cmd, 1)
  if logicview.truth((power & 128)) then
    power = (power | 88)
  end
  if logicview.truth((power & 32)) then
    power = (power | 24)
  end
  self:describe_changed_bits(power, self.last_power, NAMES)
  self.last_power = power
end
function _decoder.handle_frequency_setting_cmd(self, cmd, ret)
  local f
  self:putx(0, 4, { "Frequency setting", "Frequency" })
  f = logicview.add(((logicview.idx(cmd, 1) & 15) << 8), logicview.idx(cmd, 2))
  self:putx(0, 12, { logicview.pymod("F = %3.4f", f) })
  logicview.setidx(self.row_pos, 2, (logicview.idx(self.row_pos, 2) - 4))
  if logicview.truth((not logicview.eq(self.last_freq, f))) then
    self:putx(5, 12, { "Changing", "~" })
  end
  self.last_freq = f
end
function _decoder.handle_data_rate_cmd(self, cmd, ret)
  local r, cs, rate
  self:putx(0, 8, { "Data rate command", "Data rate" })
  r = (logicview.idx(cmd, 1) & 127)
  cs = ((logicview.idx(cmd, 1) & 128) >> 7)
  rate = (((10000 / 29.0) / logicview.add(r, 1)) / logicview.add(1, logicview.mul(7, cs)))
  self:putx(0, 8, { logicview.pymod("%3.1fkbps", rate) })
  if logicview.truth((not logicview.eq(self.last_data_rate, logicview.idx(cmd, 1)))) then
    self:putx(5, 8, { "Changing", "~" })
  end
  self.last_data_rate = logicview.idx(cmd, 1)
end
function _decoder.handle_receiver_control_cmd(self, cmd, ret)
  local s, VDI_NAMES, vdi_speed, BANDWIDTH_NAMES, bandwidth, LNA_GAIN_NAMES, lna_gain, RSSI_THRESHOLD_NAMES, rssi_threshold
  self:putx(0, 5, { "Receiver control command" })
  s = (function() if logicview.truth((logicview.idx(cmd, 0) & 4)) then return "interrupt input" else return "VDI output" end end)()
  self:putx(0, 1, { logicview.add("pin16 = ", s) })
  VDI_NAMES = { "Fast", "Medium", "Slow", "Always on" }
  vdi_speed = logicview.idx(VDI_NAMES, (logicview.idx(cmd, 0) & 3))
  self:putx(0, 2, { logicview.pymod("VDI: %s", vdi_speed) })
  BANDWIDTH_NAMES = { "Reserved", "400kHz", "340kHz", "270kHz", "200kHz", "134kHz", "67kHz", "Reserved" }
  bandwidth = logicview.idx(BANDWIDTH_NAMES, ((logicview.idx(cmd, 1) & 224) >> 5))
  self:putx(0, 3, { logicview.pymod("Bandwidth: %s", bandwidth) })
  LNA_GAIN_NAMES = { 0, (-6), (-14), (-20) }
  lna_gain = logicview.idx(LNA_GAIN_NAMES, ((logicview.idx(cmd, 1) & 24) >> 3))
  self:putx(0, 2, { logicview.pymod("LNA gain: %ddB", lna_gain) })
  RSSI_THRESHOLD_NAMES = { "-103", "-97", "-91", "-85", "-79", "-73", "Reserved", "Reserved" }
  rssi_threshold = logicview.idx(RSSI_THRESHOLD_NAMES, (logicview.idx(cmd, 1) & 7))
  self:putx(0, 3, { logicview.pymod("RSSI threshold: %s", rssi_threshold) })
end
function _decoder.handle_data_filter_cmd(self, cmd, ret)
  local clock_recovery, s
  self:putx(0, 8, { "Data filter command" })
  if logicview.truth((logicview.idx(cmd, 1) & 128)) then
    clock_recovery = "auto"
  elseif logicview.truth((logicview.idx(cmd, 1) & 64)) then
    clock_recovery = "fast"
  else
    clock_recovery = "slow"
  end
  self:putx(0, 2, { logicview.pymod("Clock recovery: %s mode", clock_recovery) })
  self:advance_ann(0, 1)
  s = (function() if logicview.truth((logicview.idx(cmd, 1) & 16)) then return "analog" else return "digital" end end)()
  self:putx(0, 1, { logicview.add("Data filter: ", s) })
  self:advance_ann(0, 1)
  self:putx(0, 3, { logicview.pymod("DQD threshold: %d", (logicview.idx(cmd, 1) & 7)) })
end
function _decoder.handle_fifo_and_reset_cmd(self, cmd, ret)
  local fifo_level, last_fifo_level, s, fifo_fill
  self:putx(0, 8, { "FIFO and reset command" })
  fifo_level = ((logicview.idx(cmd, 1) & 240) >> 4)
  self:putx(0, 4, { logicview.pymod("FIFO trigger level: %d", fifo_level) })
  last_fifo_level = ((self.last_fifo_and_reset & 240) >> 4)
  if logicview.truth((not logicview.eq(fifo_level, last_fifo_level))) then
    self:putx(5, 4, { "Changing", "~" })
  else
    self:advance_ann(5, 4)
  end
  s = (function() if logicview.truth((logicview.idx(cmd, 1) & 8)) then return "one byte" else return "two bytes" end end)()
  self:putx(0, 1, { logicview.add("Synchron length: ", s) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 8), (self.last_fifo_and_reset & 8)))) then
    self:putx(5, 1, { "Changing", "~" })
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(cmd, 1) & 4)) then
    fifo_fill = "Always"
  elseif logicview.truth((logicview.idx(cmd, 1) & 2)) then
    fifo_fill = "After synchron pattern"
  else
    fifo_fill = "Never"
  end
  self:putx(0, 2, { logicview.pymod("FIFO fill: %s", fifo_fill) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 6), (self.last_fifo_and_reset & 6)))) then
    self:putx(5, 2, { "Changing", "~" })
  else
    self:advance_ann(5, 2)
  end
  s = (function() if logicview.truth((logicview.idx(cmd, 1) & 1)) then return "non-sensitive" else return "sensitive" end end)()
  self:putx(0, 1, { logicview.add("Reset mode: ", s) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 1), (self.last_fifo_and_reset & 1)))) then
    self:putx(5, 1, { "Changing", "~" })
  else
    self:advance_ann(5, 1)
  end
  self.last_fifo_and_reset = logicview.idx(cmd, 1)
end
function _decoder.handle_synchron_pattern_cmd(self, cmd, ret)
  self:putx(0, 8, { "Synchron pattern command" })
  if logicview.truth((self.last_fifo_and_reset & 8)) then
    self:putx(0, 8, { logicview.pymod("Pattern: 0x2D%02X", pattern) })
  else
    self:putx(0, 8, { "Pattern: {$}", logicview.pymod("@%02X", pattern) })
  end
end
function _decoder.handle_fifo_read_cmd(self, cmd, ret)
  self:putx(0, 8, { "FIFO read command", "FIFO read" })
  self:putx(3, 8, { "Data: {$}", logicview.pymod("@%02X", logicview.idx(ret, 1)) })
end
function _decoder.handle_afc_cmd(self, cmd, ret)
  local MODES, mode, range_limit, FREQ_TABLE, freq_delta, NAMES
  self:putx(0, 8, { "AFC command" })
  MODES = { "Off", "Once", "During receiving", "Always" }
  mode = ((logicview.idx(cmd, 1) & 192) >> 6)
  self:putx(0, 2, { logicview.pymod("Mode: %s", logicview.idx(MODES, mode)) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 192), (self.last_afc & 192)))) then
    self:putx(5, 2, { "Changing", "~" })
  else
    self:advance_ann(5, 2)
  end
  range_limit = ((logicview.idx(cmd, 1) & 48) >> 4)
  FREQ_TABLE = { 0.0, 2.5, 5.0, 7.5 }
  freq_delta = logicview.idx(FREQ_TABLE, ((self.last_config & 48) >> 4))
  if logicview.truth(logicview.eq(range_limit, 0)) then
    self:putx(0, 2, { "Range: No limit" })
  elseif logicview.truth(logicview.eq(range_limit, 1)) then
    self:putx(0, 2, { logicview.pymod("Range: +/-%dkHz", logicview.mul(15, freq_delta)) })
  elseif logicview.truth(logicview.eq(range_limit, 2)) then
    self:putx(0, 2, { logicview.pymod("Range: +/-%dkHz", logicview.mul(7, freq_delta)) })
  elseif logicview.truth(logicview.eq(range_limit, 3)) then
    self:putx(0, 2, { logicview.pymod("Range: +/-%dkHz", logicview.mul(3, freq_delta)) })
  end
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 48), (self.last_afc & 48)))) then
    self:putx(5, 2, { "Changing", "~" })
  else
    self:advance_ann(5, 2)
  end
  NAMES = { "Strobe edge", "High accuracy mode", "Enable offset register", "Enable offset calculation" }
  self:describe_bits((logicview.idx(cmd, 1) & 15), NAMES)
  self:describe_changed_bits((logicview.idx(cmd, 1) & 15), (self.last_afc & 15), NAMES)
  self.last_afc = logicview.idx(cmd, 1)
end
function _decoder.handle_transceiver_control_cmd(self, cmd, ret)
  local POWERS
  self:putx(0, 8, { "Transceiver control command" })
  self:putx(0, 4, { logicview.pymod("FSK frequency delta: %dkHz", logicview.mul(15, ((logicview.idx(cmd, 1) & 240) >> 4))) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 240), (self.last_transceiver & 240)))) then
    self:putx(5, 4, { "Changing", "~" })
  else
    self:advance_ann(5, 4)
  end
  POWERS = { 0, (-2.5), (-5), (-7.5), (-10), (-12.5), (-15), (-17.5) }
  self:advance_ann(0, 1)
  self:advance_ann(5, 1)
  self:putx(0, 3, { logicview.pymod("Relative power: %dB", (logicview.idx(cmd, 1) & 7)) })
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 7), (self.last_transceiver & 7)))) then
    self:putx(5, 3, { "Changing", "~" })
  else
    self:advance_ann(5, 3)
  end
  self.last_transceiver = logicview.idx(cmd, 1)
end
function _decoder.handle_pll_setting_cmd(self, cmd, ret)
  local NAMES, s
  self:putx(0, 8, { "PLL setting command" })
  self:advance_ann(0, 1)
  self:putx(0, 2, { "Clock buffer rise and fall time" })
  self:advance_ann(0, 1)
  self:advance_ann(5, 4)
  NAMES = { { "Delay in phase detector", "dly" }, { "Disable dithering", "ddit" } }
  self:describe_bits(((logicview.idx(cmd, 1) & 12) >> 2), NAMES)
  self:describe_changed_bits(((logicview.idx(cmd, 1) & 12) >> 2), ((self.last_pll & 12) >> 2), NAMES)
  s = (function() if logicview.truth((logicview.idx(cmd, 1) & 1)) then return "256kbps, high" else return "86.2kbps, low" end end)()
  self:putx(0, 1, { logicview.pymod("Max bit rate: %s noise", s) })
  self:advance_ann(5, 1)
  if logicview.truth((not logicview.eq((logicview.idx(cmd, 1) & 1), (self.last_pll & 1)))) then
    self:putx(5, 1, { "Changing", "~" })
  end
  self.last_pll = logicview.idx(cmd, 1)
end
function _decoder.handle_transmitter_register_cmd(self, cmd, ret)
  self:putx(0, 8, { "Transmitter register command", "Transmit" })
  self:putx(0, 8, { logicview.pymod("Data: %s", logicview.idx(cmd, 1)), logicview.pymod("%s", logicview.idx(cmd, 1)) })
end
function _decoder.handle_software_reset_cmd(self, cmd, ret)
  self:putx(0, 16, { "Software reset command" })
end
function _decoder.handle_wake_up_timer_cmd(self, cmd, ret)
  local r, m, time
  self:putx(0, 3, { "Wake-up timer command", "Timer" })
  r = (logicview.idx(cmd, 0) & 31)
  m = logicview.idx(cmd, 1)
  time = logicview.add(logicview.mul(logicview.mul(1.03, m), (2 ^ r)), 0.5)
  self:putx(0, 13, { logicview.pymod("Time: %7.2f", time) })
end
function _decoder.handle_low_duty_cycle_cmd(self, cmd, ret)
  self:putx(0, 16, { "Low duty cycle command" })
end
function _decoder.handle_low_battery_detector_cmd(self, cmd, ret)
  local NAMES, clock, v
  self:putx(0, 8, { "Low battery detector command" })
  NAMES = { "1", "1.25", "1.66", "2", "2.5", "3.33", "5", "10" }
  clock = logicview.idx(NAMES, ((logicview.idx(cmd, 1) & 224) >> 5))
  self:putx(0, 3, { logicview.pymod("Clock output: %sMHz", clock), logicview.pymod("%sMHz", clock) })
  self:advance_ann(0, 1)
  v = logicview.add(2.25, logicview.mul((logicview.idx(cmd, 1) & 15), 0.1))
  self:putx(0, 4, { logicview.pymod("Low battery voltage: %1.2fV", v), logicview.pymod("%1.2fV", v) })
end
function _decoder.handle_status_read_cmd(self, cmd, ret)
  local NAMES, status, receiver_enabled, s
  self:putx(0, 8, { "Status read command", "Status" })
  NAMES = { "RGIT/FFIT", "POR", "RGUR/FFOV", "WKUP", "EXT", "LBD", "FFEM", "RSSI/ATS", "DQD", "CRL", "ATGL" }
  status = logicview.add((logicview.idx(ret, 0) << 3), (logicview.idx(ret, 1) >> 5))
  logicview.setidx(self.row_pos, 1, (logicview.idx(self.row_pos, 1) - 8))
  logicview.setidx(self.row_pos, 2, (logicview.idx(self.row_pos, 2) - 8))
  self:describe_return_bits(status, NAMES)
  receiver_enabled = ((self.last_power & 128) >> 7)
  if logicview.truth((logicview.idx(ret, 0) & 128)) then
    if logicview.truth(receiver_enabled) then
      s = "Received data in FIFO"
    else
      s = "Transmit register ready"
    end
    self:putx(5, 1, s)
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 64)) then
    self:putx(5, 1, "Power on Reset")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 32)) then
    if logicview.truth(receiver_enabled) then
      s = "RX FIFO overflow"
    else
      s = "Transmit register under run"
    end
    self:putx(5, 1, s)
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 16)) then
    self:putx(5, 1, "Wake-up timer")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 8)) then
    self:putx(5, 1, "External interrupt")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 4)) then
    self:putx(5, 1, "Low battery")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 2)) then
    self:putx(5, 1, "FIFO is empty")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 0) & 1)) then
    if logicview.truth(receiver_enabled) then
      s = "Incoming signal above limit"
    else
      s = "Antenna detected RF signal"
    end
    self:putx(5, 1, s)
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 1) & 128)) then
    self:putx(5, 1, "Data quality detector")
  else
    self:advance_ann(5, 1)
  end
  if logicview.truth((logicview.idx(ret, 1) & 64)) then
    self:putx(5, 1, "Clock recovery locked")
  else
    self:advance_ann(5, 1)
  end
  self:advance_ann(5, 1)
  self:putx(3, 5, { "AFC offset" })
  if logicview.truth((not logicview.eq((logicview.idx(self.last_status, 1) & 31), (logicview.idx(ret, 1) & 31)))) then
    self:putx(5, 5, { "Changed", "~" })
  end
  self.last_status = ret
end
function _decoder.handle_cmd(self, cmd, ret)
  local c, r
  if logicview.truth(logicview.eq(logicview.idx(cmd, 0), 128)) then
    self:handle_configuration_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 130)) then
    self:handle_power_management_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq((logicview.idx(cmd, 0) & 240), 160)) then
    self:handle_frequency_setting_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 198)) then
    self:handle_data_rate_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq((logicview.idx(cmd, 0) & 248), 144)) then
    self:handle_receiver_control_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 194)) then
    self:handle_data_filter_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 202)) then
    self:handle_fifo_and_reset_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 206)) then
    self:handle_synchron_pattern_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 176)) then
    self:handle_fifo_read_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 196)) then
    self:handle_afc_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq((logicview.idx(cmd, 0) & 254), 152)) then
    self:handle_transceiver_control_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 204)) then
    self:handle_pll_setting_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 184)) then
    self:handle_transmitter_register_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 254)) then
    self:handle_software_reset_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq((logicview.idx(cmd, 0) & 224), 224)) then
    self:handle_wake_up_timer_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 200)) then
    self:handle_low_duty_cycle_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 192)) then
    self:handle_low_battery_detector_cmd(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.idx(cmd, 0), 0)) then
    self:handle_status_read_cmd(cmd, ret)
  else
    c = logicview.pymod("%02x %02x", logicview.copy(cmd))
    r = logicview.pymod("%02x %02x", logicview.copy(ret))
    self:putx(0, 16, { logicview.pymod("Unknown command: %s (reply: %s)!", { c, r }) })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso
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
      if logicview.truth((mosi ~= nil)) then
        logicview.extend(self.mosi_bits, logicview.reversed(mosi))
      end
      if logicview.truth((miso ~= nil)) then
        logicview.extend(self.miso_bits, logicview.reversed(miso))
      end
      return
    end
    _table.insert(self.mosi_bytes, mosi)
    _table.insert(self.miso_bytes, miso)
    if logicview.truth((logicview.len(self.mosi_bytes) < 2)) then
      return
    end
    self.row_pos = { 0, 8, 8 }
    self:handle_cmd(self.mosi_bytes, self.miso_bytes)
    do
      local _lv_a0, _lv_a1 = {  }, {  }
      self.mosi_bytes = _lv_a0
      self.miso_bytes = _lv_a1
    end
    do
      local _lv_a0, _lv_a1 = {  }, {  }
      self.mosi_bits = _lv_a0
      self.miso_bits = _lv_a1
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
