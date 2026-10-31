-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Jorge Solla Rubiales <jorgesolla@gmail.com>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>

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
local Pulse, Stat, timing, ChannelError, Decoder, logical_adresses, opcodes, resolve_logical_address, decode_header
local _decoder

logical_adresses = { "TV", "Recording_1", "Recording_2", "Tuner_1", "Playback_1", "AudioSystem", "Tuner2", "Tuner3", "Playback_2", "Recording_3", "Tuner_4", "Playback_3", "Backup_1", "Backup_2", "FreeUse" }
opcodes = logicview.dict({ [130] = "ACTIVE_SOURCE", [4] = "IMAGE_VIEW_ON", [13] = "TEXT_VIEW_ON", [157] = "INACTIVE_SOURCE", [133] = "REQUEST_ACTIVE_SOURCE", [128] = "ROUTING_CHANGE", [129] = "ROUTING_INFORMATION", [134] = "SET_STREAM_PATH", [54] = "STANDBY", [11] = "RECORD_OFF", [9] = "RECORD_ON", [10] = "RECORD_STATUS", [15] = "RECORD_TV_SCREEN", [51] = "CLEAR_ANALOGUE_TIMER", [153] = "CLEAR_DIGITAL_TIMER", [161] = "CLEAR_EXTERNAL_TIMER", [52] = "SET_ANALOGUE_TIMER", [151] = "SET_DIGITAL_TIMER", [162] = "SET_EXTERNAL_TIMER", [103] = "SET_TIMER_PROGRAM_TITLE", [67] = "TIMER_CLEARED_STATUS", [53] = "TIMER_STATUS", [158] = "CEC_VERSION", [159] = "GET_CEC_VERSION", [131] = "GIVE_PHYSICAL_ADDRESS", [145] = "GET_MENU_LANGUAGE", [132] = "REPORT_PHYSICAL_ADDRESS", [50] = "SET_MENU_LANGUAGE", [66] = "DECK_CONTROL", [27] = "DECK_STATUS", [26] = "GIVE_DECK_STATUS", [65] = "PLAY", [8] = "GIVE_TUNER_DEVICE_STATUS", [146] = "SELECT_ANALOGUE_SERVICE", [147] = "SELECT_DIGITAL_SERVICE", [7] = "TUNER_DEVICE_STATUS", [6] = "TUNER_STEP_DECREMENT", [5] = "TUNER_STEP_INCREMENT", [135] = "DEVICE_VENDOR_ID", [140] = "GIVE_DEVICE_VENDOR_ID", [137] = "VENDOR_COMMAND", [160] = "VENDOR_COMMAND_WITH_ID", [138] = "VENDOR_REMOTE_BUTTON_DOWN", [139] = "VENDOR_REMOTE_BUTTON_UP", [100] = "SET_OSD_STRING", [70] = "GIVE_OSD_NAME", [71] = "SET_OSD_NAME", [141] = "MENU_REQUEST", [142] = "MENU_STATUS", [68] = "USER_CONTROL_PRESSED", [69] = "USER_CONTROL_RELEASE", [143] = "GIVE_DEVICE_POWER_STATUS", [144] = "REPORT_POWER_STATUS", [0] = "FEATURE_ABORT", [255] = "ABORT", [113] = "GIVE_AUDIO_STATUS", [125] = "GIVE_SYSTEM_AUDIO_MODE_STATUS", [122] = "REPORT_AUDIO_STATUS", [114] = "SET_SYSTEM_AUDIO_MODE", [112] = "SYSTEM_AUDIO_MODE_REQUEST", [126] = "SYSTEM_AUDIO_MODE_STATUS", [154] = "SET_AUDIO_RATE" })
resolve_logical_address = function(id_, is_initiator)
  if logicview.truth((function()
  local _v
  _v = (id_ < 0)
  if logicview.truth(_v) then return _v end
  _v = (id_ > 15)
  return _v
end)()) then
    return "Invalid"
  end
  if logicview.truth(logicview.eq(id_, 15)) then
    return (function() if logicview.truth(is_initiator) then return "Unregistered" else return "Broadcast" end end)()
  end
  return logicview.idx(logical_adresses, id_)
end
decode_header = function(header)
  local src, dst
  src = ((header & 240) >> 4)
  dst = (header & 15)
  return { resolve_logical_address(src, 1), resolve_logical_address(dst, 0) }
end

Pulse = {}
Pulse.__index = Pulse
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pulse.INVALID = logicview.idx(_lv_seq, 0)
  Pulse.START = logicview.idx(_lv_seq, 1)
  Pulse.ZERO = logicview.idx(_lv_seq, 2)
  Pulse.ONE = logicview.idx(_lv_seq, 3)
end
Stat = {}
Stat.__index = Stat
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Stat.WAIT_START = logicview.idx(_lv_seq, 0)
  Stat.GET_BITS = logicview.idx(_lv_seq, 1)
  Stat.WAIT_EOM = logicview.idx(_lv_seq, 2)
  Stat.WAIT_ACK = logicview.idx(_lv_seq, 3)
end
timing = logicview.dict({ [Pulse.START] = logicview.dict({ low = logicview.dict({ min = 3.5, max = 3.9 }), total = logicview.dict({ min = 4.3, max = 4.7 }) }), [Pulse.ZERO] = logicview.dict({ low = logicview.dict({ min = 1.3, max = 1.7 }), total = logicview.dict({ min = 2.05, max = 2.75 }) }), [Pulse.ONE] = logicview.dict({ low = logicview.dict({ min = 0.4, max = 0.8 }), total = logicview.dict({ min = 2.05, max = 2.75 }) }) })
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "cec",
  name = "CEC",
  longname = "HDMI-CEC",
  desc = "HDMI Consumer Electronics Control (CEC) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Display", "PC" },
  channels = { logicview.dict({ id = "cec", name = "CEC", desc = "CEC bus data" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "st", "Start" }, { "eom-0", "End of message" }, { "eom-1", "Message continued" }, { "nack", "ACK not set" }, { "ack", "ACK set" }, { "bits", "Bits" }, { "bytes", "Bytes" }, { "frames", "Frames" }, { "sections", "Sections" }, { "warnings", "Warnings" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3, 4, 5 } }, { "bytes", "Bytes", { 6 } }, { "frames", "Frames", { 7 } }, { "sections", "Sections", { 8 } }, { "warnings", "Warnings", { 9 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.precalculate(self)
  local bit_time
  bit_time = logicview.mul(logicview.idx(logicview.idx(logicview.idx(timing, Pulse.ZERO), "total"), "min"), 2)
  self.max_ack_len_samples = (function() local _n = logicview.mul((bit_time / 1000), self.samplerate); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)()
end
function _decoder.reset(self)
  self.stat = Stat.WAIT_START
  self.samplerate = nil
  self.fall_start = nil
  self.fall_end = nil
  self.rise = nil
  self:reset_frame_vars()
end
function _decoder.reset_frame_vars(self)
  self.eom = nil
  self.bit_count = 0
  self.byte_count = 0
  self.byte = 0
  self.byte_start = nil
  self.frame_start = nil
  self.frame_end = nil
  self.is_nack = 0
  self.cmd_bytes = {  }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self:precalculate()
  end
end
function _decoder.handle_frame(self, is_nack)
  local i, string, operands, src, dst
  if logicview.truth((function()
  local _v
  _v = (self.fall_start == nil)
  if logicview.truth(_v) then return _v end
  _v = (self.fall_end == nil)
  return _v
end)()) then
    return
  end
  i = 0
  string = ""
  while logicview.truth((i < logicview.len(self.cmd_bytes))) do
    string = logicview.add(string, logicview.pyformat("{:02x}", { logicview.idx(logicview.idx(self.cmd_bytes, i), "val") }, logicview.dict({})))
    if logicview.truth((not logicview.eq(i, (logicview.len(self.cmd_bytes) - 1)))) then
      string = logicview.add(string, ":")
    end
    i = logicview.add(i, 1)
    ::continue_1::
  end
  self:put(self.frame_start, self.frame_end, self.out_ann, { 7, { string } })
  i = 0
  operands = 0
  string = ""
  while logicview.truth((i < logicview.len(self.cmd_bytes))) do
    if logicview.truth(logicview.eq(i, 0)) then
      do
        local _lv_seq = decode_header(logicview.idx(logicview.idx(self.cmd_bytes, i), "val"))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        src = logicview.idx(_lv_seq, 0)
        dst = logicview.idx(_lv_seq, 1)
      end
      string = logicview.add(logicview.add(logicview.add("HDR: ", src), ", "), dst)
    elseif logicview.truth(logicview.eq(i, 1)) then
      string = logicview.add(string, logicview.add(" | OPC: ", logicview.dget(opcodes, logicview.idx(logicview.idx(self.cmd_bytes, i), "val"), "Invalid")))
    else
      if logicview.truth(logicview.eq(operands, 0)) then
        string = logicview.add(string, " | OPS: ")
      end
      operands = logicview.add(operands, 1)
      string = logicview.add(string, logicview.pyformat("0x{:02x}", { logicview.idx(logicview.idx(self.cmd_bytes, i), "val") }, logicview.dict({})))
      if logicview.truth((not logicview.eq(i, (logicview.len(self.cmd_bytes) - 1)))) then
        string = logicview.add(string, ", ")
      end
    end
    i = logicview.add(i, 1)
    ::continue_2::
  end
  if logicview.truth(logicview.eq(i, 1)) then
    string = logicview.add(string, (function() if logicview.truth(self.eom) then return " | OPC: PING" else return " | OPC: NONE. Aborted cmd" end end)())
  end
  string = logicview.add(string, (function() if logicview.truth(is_nack) then return " | R: NACK" else return " | R: ACK" end end)())
  self:put(self.frame_start, self.frame_end, self.out_ann, { 8, { string } })
end
function _decoder.process(self)
  local zero_time, total_time, pulse, key, bit, a, ann_end
  zero_time = logicview.mul(((self.rise - self.fall_start) / self.samplerate), 1000.0)
  total_time = logicview.mul(((self.fall_end - self.fall_start) / self.samplerate), 1000.0)
  pulse = Pulse.INVALID
  for _lv_item in logicview.iter(timing) do
    key = _lv_item
    if logicview.truth((function()
  local _v
  _v = (zero_time >= logicview.idx(logicview.idx(logicview.idx(timing, key), "low"), "min"))
  if not logicview.truth(_v) then return _v end
  _v = (zero_time <= logicview.idx(logicview.idx(logicview.idx(timing, key), "low"), "max"))
  return _v
end)()) then
      pulse = key
      break
    end
    ::continue_3::
  end
  if logicview.truth(logicview.eq(pulse, Pulse.INVALID)) then
    self.stat = Stat.WAIT_START
    self:put(self.fall_start, self.fall_end, self.out_ann, { 9, { "Invalid pulse: Wrong timing" } })
    return
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.stat, Stat.WAIT_START)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(pulse, Pulse.START))
  return _v
end)()) then
    self:put(self.fall_start, self.fall_end, self.out_ann, { 9, { "Expected START: BIT found" } })
    return
  end
  if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(self.stat, Stat.WAIT_ACK)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.stat, Stat.WAIT_EOM)
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(pulse, Pulse.START)
  return _v
end)()) then
    self:put(self.fall_start, self.fall_end, self.out_ann, { 9, { "Expected BIT: START received)" } })
    self.stat = Stat.WAIT_START
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.stat, Stat.WAIT_ACK)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(pulse, Pulse.START))
  return _v
end)()) then
    if logicview.truth((total_time < logicview.idx(logicview.idx(logicview.idx(timing, pulse), "total"), "min"))) then
      pulse = Pulse.INVALID
      self:put(self.fall_start, self.fall_end, self.out_ann, { 9, { "ACK pulse below minimun time" } })
      self.stat = Stat.WAIT_START
      return
    end
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.stat, Stat.GET_BITS)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(pulse, Pulse.START)
  return _v
end)()) then
    if logicview.truth(logicview.eq(self.bit_count, 0)) then
      self:handle_frame(self.is_nack)
    else
      self:put(self.frame_start, self.samplenum, self.out_ann, { 9, { "ERROR: Incomplete byte received" } })
    end
    self.stat = Stat.WAIT_START
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(self.stat, Stat.WAIT_ACK))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(pulse, Pulse.START))
  return _v
end)()) then
    if logicview.truth((function()
  local _v
  _v = (total_time < logicview.idx(logicview.idx(logicview.idx(timing, pulse), "total"), "min"))
  if logicview.truth(_v) then return _v end
  _v = (total_time > logicview.idx(logicview.idx(logicview.idx(timing, pulse), "total"), "max"))
  return _v
end)()) then
      self:put(self.fall_start, self.fall_end, self.out_ann, { 9, { "Bit pulse exceeds total pulse timespan" } })
      pulse = Pulse.INVALID
      self.stat = Stat.WAIT_START
      return
    end
  end
  if logicview.truth(logicview.eq(pulse, Pulse.ZERO)) then
    bit = 0
  elseif logicview.truth(logicview.eq(pulse, Pulse.ONE)) then
    bit = 1
  end
  if logicview.truth(logicview.eq(self.stat, Stat.WAIT_START)) then
    self.stat = Stat.GET_BITS
    self:reset_frame_vars()
    self:put(self.fall_start, self.fall_end, self.out_ann, { 0, { "ST" } })
  elseif logicview.truth(logicview.eq(self.stat, Stat.GET_BITS)) then
    if logicview.truth(logicview.eq(self.bit_count, 0)) then
      self.byte_start = self.fall_start
      self.byte = 0
      if logicview.truth(logicview.eq(logicview.len(self.cmd_bytes), 0)) then
        self.frame_start = self.fall_start
      end
    end
    self.byte = logicview.add(self.byte, (bit << (7 - self.bit_count)))
    self.bit_count = logicview.add(self.bit_count, 1)
    self:put(self.fall_start, self.fall_end, self.out_ann, { 5, { _tostring(bit) } })
    if logicview.truth(logicview.eq(self.bit_count, 8)) then
      self.bit_count = 0
      self.byte_count = logicview.add(self.byte_count, 1)
      self.stat = Stat.WAIT_EOM
      self:put(self.byte_start, self.samplenum, self.out_ann, { 6, { logicview.pyformat("0x{:02x}", { self.byte }, logicview.dict({})) } })
      _table.insert(self.cmd_bytes, logicview.dict({ st = self.byte_start, ed = self.samplenum, val = self.byte }))
    end
  elseif logicview.truth(logicview.eq(self.stat, Stat.WAIT_EOM)) then
    self.eom = bit
    self.frame_end = self.fall_end
    a = (function() if logicview.truth(self.eom) then return { 2, { "EOM=Y" } } else return { 1, { "EOM=N" } } end end)()
    self:put(self.fall_start, self.fall_end, self.out_ann, a)
    self.stat = Stat.WAIT_ACK
  elseif logicview.truth(logicview.eq(self.stat, Stat.WAIT_ACK)) then
    if logicview.truth(logicview.eq((logicview.idx(logicview.idx(self.cmd_bytes, 0), "val") & 15), 15)) then
      bit = ((~bit) & 1)
    end
    if logicview.truth(((self.fall_end - self.fall_start) > self.max_ack_len_samples)) then
      ann_end = logicview.add(self.fall_start, self.max_ack_len_samples)
    else
      ann_end = self.fall_end
    end
    if logicview.truth(bit) then
      self.is_nack = 1
      self:put(self.fall_start, ann_end, self.out_ann, { 3, { "NACK" } })
    else
      self:put(self.fall_start, ann_end, self.out_ann, { 4, { "ACK" } })
    end
    if logicview.truth((function()
  local _v
  _v = self.eom
  if logicview.truth(_v) then return _v end
  _v = self.is_nack
  return _v
end)()) then
      self.stat = Stat.WAIT_START
      self:handle_frame(self.is_nack)
    else
      self.stat = Stat.GET_BITS
    end
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self)
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:wait(logicview.dict({ [0] = "f" }))
  self.fall_end = self.samplenum
  while true do
    self:wait(logicview.dict({ [0] = "r" }))
    self.rise = self.samplenum
    if logicview.truth(logicview.eq(self.stat, Stat.WAIT_ACK)) then
      self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ skip = self.max_ack_len_samples }) })
    else
      self:wait({ logicview.dict({ [0] = "f" }) })
    end
    self.fall_start = self.fall_end
    self.fall_end = self.samplenum
    self:process()
    if logicview.truth(logicview.eq(self.matched, 2)) then
      self:wait(logicview.dict({ [0] = "f" }))
      self.fall_end = self.samplenum
    end
    ::continue_4::
  end
end

return _decoder
