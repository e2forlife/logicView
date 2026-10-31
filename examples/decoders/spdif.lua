-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Guenther Wenninger <robin@bitschubbser.org>
-- Copyright (C) 2023 DreamSourceLab <support@dreamsourcelab.com>

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
local SamplerateError, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "spdif",
  name = "S/PDIF",
  longname = "Sony/Philips Digital Interface Format",
  desc = "Serial bus for connecting digital audio devices.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Audio", "PC" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bitrate", "Bitrate / baudrate" }, { "preamble", "Preamble" }, { "bits", "Bits" }, { "aux", "Auxillary-audio-databits" }, { "samples", "Audio Samples" }, { "validity", "Data Valid" }, { "subcode", "Subcode data" }, { "chan_stat", "Channnel Status" }, { "parity", "Parity Bit" } },
  annotation_rows = { { "info", "Info", { 0, 1, 3, 5, 6, 7, 8 } }, { "bits", "Bits", { 2 } }, { "samples", "Samples", { 4 } } },
  binary = {  }
}
function _decoder.putx(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.puty(self, data)
  self:put(self.ss_edge, self.samplenum, self.out_ann, data)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "GET FIRST PULSE WIDTH"
  self.ss_edge = nil
  self.first_edge = true
  self.samplenum_prev_edge = 0
  self.pulse_width = 0
  self.clocks = {  }
  self.range1 = 0
  self.range2 = 0
  self.preamble_state = 0
  self.preamble = {  }
  self.seen_preamble = false
  self.last_preamble = 0
  self.first_one = true
  self.subframe = {  }
  self.temp_pulse_width = {  }
  self.temp_samplenum = {  }
  self.firstpramble = true
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.get_pulse_type(self)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.range1, 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.range2, 0)
  return _v
end)()) then
    return (-1)
  end
  if logicview.truth((self.pulse_width >= self.range2)) then
    return 2
  elseif logicview.truth((self.pulse_width >= self.range1)) then
    return 0
  else
    return 1
  end
end
function _decoder.find_first_pulse_width(self)
  _table.insert(self.temp_pulse_width, self.pulse_width)
  _table.insert(self.temp_samplenum, self.samplenum)
  if logicview.truth((not logicview.eq(self.pulse_width, 0))) then
    _table.insert(self.clocks, self.pulse_width)
    self.state = "GET SECOND PULSE WIDTH"
  end
end
function _decoder.find_second_pulse_width(self)
  _table.insert(self.temp_pulse_width, self.pulse_width)
  _table.insert(self.temp_samplenum, self.samplenum)
  if logicview.truth((function()
  local _v
  _v = (self.pulse_width > logicview.mul(logicview.idx(self.clocks, 0), 1.3))
  if logicview.truth(_v) then return _v end
  _v = (self.pulse_width < logicview.mul(logicview.idx(self.clocks, 0), 0.7))
  return _v
end)()) then
    _table.insert(self.clocks, self.pulse_width)
    self.state = "GET THIRD PULSE WIDTH"
  end
end
function _decoder.find_third_pulse_width(self)
  local spdif_bitrate, clock_period_nsec, is_preamble_status
  _table.insert(self.temp_pulse_width, self.pulse_width)
  _table.insert(self.temp_samplenum, self.samplenum)
  if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (self.pulse_width <= logicview.mul(logicview.idx(self.clocks, 0), 1.3))
  if not logicview.truth(_v) then return _v end
  _v = (self.pulse_width >= logicview.mul(logicview.idx(self.clocks, 0), 0.7))
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (self.pulse_width <= logicview.mul(logicview.idx(self.clocks, 1), 1.3))
  if not logicview.truth(_v) then return _v end
  _v = (self.pulse_width >= logicview.mul(logicview.idx(self.clocks, 1), 0.7))
  return _v
end)()
  return _v
end)()) then
    return
  end
  _table.insert(self.clocks, self.pulse_width)
  (function() _table.sort(self.clocks) end)()
  self.range1 = (logicview.add(logicview.idx(self.clocks, 0), logicview.idx(self.clocks, 1)) / 2)
  self.range2 = (logicview.add(logicview.idx(self.clocks, 1), logicview.idx(self.clocks, 2)) / 2)
  spdif_bitrate = logicview.tointeger((self.samplerate / (logicview.idx(self.clocks, 2) / 1.5)))
  self.ss_edge = 0
  self:putx(0, (logicview.idx(self.temp_samplenum, 0) - 24), { 0, { logicview.pymod("Signal Bitrate: %d Mbit/s (=> %d kHz)", { spdif_bitrate, (spdif_bitrate / logicview.mul(2, 32)) }) } })
  clock_period_nsec = (1000000000 / spdif_bitrate)
  self.last_preamble = self.samplenum
  is_preamble_status = true
  while logicview.truth((logicview.len(self:decode_re_get_pulse_type()) > 0)) do
    if logicview.truth(logicview.eq(is_preamble_status, true)) then
      if logicview.truth(logicview.eq(self:decode_recheck_preablm(), 0)) then
        return
      else
        is_preamble_status = false
      end
    elseif logicview.truth(logicview.eq(self:decode_recheck_stream(), 0)) then
      return
    else
      is_preamble_status = true
    end
    ::continue_1::
  end
  self.state = "DECODE STREAM"
end
function _decoder.decode_re_get_pulse_type(self)
  local pulse_type, temp_pulse
  pulse_type = {  }
  for _lv_item in logicview.iter(self.temp_pulse_width) do
    temp_pulse = _lv_item
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.range1, 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.range2, 0)
  return _v
end)()) then
      return pulse_type
    end
    if logicview.truth((temp_pulse >= self.range2)) then
      _table.insert(pulse_type, 2)
    elseif logicview.truth((temp_pulse >= self.range1)) then
      _table.insert(pulse_type, 0)
    else
      _table.insert(pulse_type, 1)
    end
    ::continue_2::
  end
  return pulse_type
end
function _decoder.decode_recheck_preablm(self)
  local pulse_type, temp_preamble, preamble_is_ok, preamble_state, temp_samnum, temp_pul_type, temp_pul_width
  if logicview.truth(logicview.eq(self:decode_re_get_pulse_type(), (-1))) then
    return (-1)
  end
  pulse_type = self:decode_re_get_pulse_type()
  temp_preamble = {  }
  preamble_is_ok = 0
  preamble_state = (-1)
  while logicview.truth((logicview.len(pulse_type) > 0)) do
    temp_samnum = logicview.list_pop(self.temp_samplenum, 0)
    temp_pul_type = logicview.list_pop(pulse_type, 0)
    temp_pul_width = logicview.list_pop(self.temp_pulse_width, 0)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(preamble_state, (-1))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(temp_pul_type, 2)
  return _v
end)()) then
      _table.insert(temp_preamble, temp_pul_type)
      preamble_state = 0
      self.ss_edge = ((temp_samnum - temp_pul_width) - 1)
    elseif logicview.truth(logicview.eq(preamble_state, 0)) then
      _table.insert(temp_preamble, temp_pul_type)
      preamble_state = 1
    elseif logicview.truth(logicview.eq(preamble_state, 1)) then
      _table.insert(temp_preamble, temp_pul_type)
      preamble_state = 2
    elseif logicview.truth(logicview.eq(preamble_state, 2)) then
      _table.insert(temp_preamble, temp_pul_type)
      if logicview.truth(logicview.eq(temp_preamble, { 2, 0, 1, 0 })) then
        self:putx(self.ss_edge, temp_samnum, { 1, { "Preamble W", "W" } })
        self.seen_preamble = true
      elseif logicview.truth(logicview.eq(temp_preamble, { 2, 2, 1, 1 })) then
        self:putx(self.ss_edge, temp_samnum, { 1, { "Preamble M", "M" } })
        self.seen_preamble = true
      elseif logicview.truth(logicview.eq(temp_preamble, { 2, 1, 1, 2 })) then
        self:putx(self.ss_edge, temp_samnum, { 1, { "Preamble B", "B" } })
        self.seen_preamble = true
      else
        self:putx(self.ss_edge, temp_samnum, { 1, { "Unknown Preamble", "Unknown Prea.", "U" } })
      end
      preamble_state = (-1)
      preamble_is_ok = 1
      temp_preamble = {  }
      self.bitcount = 0
      self.first_one = true
      self.last_preamble = temp_samnum
      break
    end
    ::continue_3::
  end
  if logicview.truth(logicview.eq(preamble_is_ok, 1)) then
    if logicview.truth(logicview.eq(logicview.len(pulse_type), 0)) then
      self.state = "DECODE STREAM"
      return 0
    else
      return 1
    end
  else
    self.state = "DECODE PREAMBLE"
    self.preamble = logicview.copy(temp_preamble)
    if logicview.truth(logicview.eq(preamble_state, (-1))) then
      self.preamble_state = 0
    else
      self.preamble_state = preamble_state
    end
    return 0
  end
end
function _decoder.decode_recheck_stream(self)
  local pulse_type, subframe, first_one, subframe_is_ok, bitcount, samnum, pul_type, pul_width, aux_audio_data, sam, sam_rot, a, sample, s, validity, subcode_data, channel_status, parity
  if logicview.truth(logicview.eq(self:decode_re_get_pulse_type(), (-1))) then
    return (-1)
  end
  pulse_type = self:decode_re_get_pulse_type()
  subframe = {  }
  first_one = true
  subframe_is_ok = 0
  bitcount = 0
  while logicview.truth((logicview.len(pulse_type) > 0)) do
    samnum = logicview.list_pop(self.temp_samplenum, 0)
    pul_type = logicview.list_pop(pulse_type, 0)
    pul_width = logicview.list_pop(self.temp_pulse_width, 0)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(pul_type, 1)
  if not logicview.truth(_v) then return _v end
  _v = first_one
  return _v
end)()) then
      first_one = false
      _table.insert(subframe, { pul_type, ((samnum - pul_width) - 1), samnum })
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(pul_type, 1)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(first_one))
  return _v
end)()) then
      logicview.setidx(logicview.idx(subframe, (-1)), 2, samnum)
      self:putx(logicview.idx(logicview.idx(subframe, (-1)), 1), samnum, { 2, { "1" } })
      bitcount = logicview.add(bitcount, 1)
      first_one = true
    else
      _table.insert(subframe, { pul_type, ((samnum - pul_width) - 1), samnum })
      self:putx(((samnum - pul_width) - 1), samnum, { 2, { "0" } })
      bitcount = logicview.add(bitcount, 1)
    end
    if logicview.truth(logicview.eq(bitcount, 28)) then
      aux_audio_data = logicview.slice(subframe, 0, 4, nil)
      do
        local _lv_a0, _lv_a1 = "", ""
        sam = _lv_a0
        sam_rot = _lv_a1
      end
      for _lv_item in logicview.iter(aux_audio_data) do
        a = _lv_item
        sam = logicview.add(sam, _tostring(logicview.idx(a, 0)))
        sam_rot = logicview.add(_tostring(logicview.idx(a, 0)), sam_rot)
        ::continue_5::
      end
      sample = logicview.slice(subframe, 4, 24, nil)
      for _lv_item in logicview.iter(sample) do
        s = _lv_item
        sam = logicview.add(sam, _tostring(logicview.idx(s, 0)))
        sam_rot = logicview.add(_tostring(logicview.idx(s, 0)), sam_rot)
        ::continue_6::
      end
      validity = logicview.slice(subframe, 24, 25, nil)
      subcode_data = logicview.slice(subframe, 25, 26, nil)
      channel_status = logicview.slice(subframe, 26, 27, nil)
      parity = logicview.slice(subframe, 27, 28, nil)
      self:putx(logicview.idx(logicview.idx(aux_audio_data, 0), 1), logicview.idx(logicview.idx(aux_audio_data, 3), 2), { 3, { logicview.pymod("Aux 0x%x", logicview.tointeger(logicview.slice(sam, nil, 4, nil), 2)), logicview.pymod("0x%x", logicview.tointeger(logicview.slice(sam, nil, 4, nil), 2)) } })
      self:putx(logicview.idx(logicview.idx(sample, 0), 1), logicview.idx(logicview.idx(sample, 19), 2), { 3, { logicview.pymod("Sample 0x%x", logicview.tointeger(sam, 2)), logicview.pymod("0x%x", logicview.tointeger(sam, 2)) } })
      self:putx(logicview.idx(logicview.idx(aux_audio_data, 0), 1), logicview.idx(logicview.idx(sample, 19), 2), { 4, { logicview.pymod("Audio 0x%x", logicview.tointeger(sam_rot, 2)), logicview.pymod("0x%x", logicview.tointeger(sam_rot, 2)) } })
      if logicview.truth(logicview.eq(logicview.idx(logicview.idx(validity, 0), 0), 0)) then
        self:putx(logicview.idx(logicview.idx(validity, 0), 1), logicview.idx(logicview.idx(validity, 0), 2), { 5, { "V" } })
      else
        self:putx(logicview.idx(logicview.idx(validity, 0), 1), logicview.idx(logicview.idx(validity, 0), 2), { 5, { "E" } })
      end
      self:putx(logicview.idx(logicview.idx(subcode_data, 0), 1), logicview.idx(logicview.idx(subcode_data, 0), 2), { 6, { logicview.pymod("S: %d", logicview.idx(logicview.idx(subcode_data, 0), 0)) } })
      self:putx(logicview.idx(logicview.idx(channel_status, 0), 1), logicview.idx(logicview.idx(channel_status, 0), 2), { 7, { logicview.pymod("C: %d", logicview.idx(logicview.idx(channel_status, 0), 0)) } })
      self:putx(logicview.idx(logicview.idx(parity, 0), 1), logicview.idx(logicview.idx(parity, 0), 2), { 8, { logicview.pymod("P: %d", logicview.idx(logicview.idx(parity, 0), 0)) } })
      subframe = {  }
      self.seen_preamble = false
      bitcount = 0
      subframe_is_ok = 1
      break
    end
    ::continue_4::
  end
  if logicview.truth(logicview.eq(subframe_is_ok, 1)) then
    if logicview.truth(logicview.eq(logicview.len(pulse_type), 0)) then
      self.state = "DECODE STREAM"
      return 0
    else
      return 1
    end
  else
    self.state = "DECODE STREAM"
    self.subframe = logicview.copy(subframe)
    self.bitcount = bitcount
    self.first_one = first_one
    return 0
  end
end
function _decoder.decode_stream(self)
  local pulse, aux_audio_data, sam, sam_rot, a, sample, s, validity, subcode_data, channel_status, parity
  pulse = self:get_pulse_type()
  if logicview.truth((not logicview.truth(self.seen_preamble))) then
    if logicview.truth(logicview.eq(pulse, 2)) then
      _table.insert(self.preamble, self:get_pulse_type())
      logicview.eq(self.preamble_state, 0)
      self.state = "DECODE PREAMBLE"
      self.ss_edge = ((self.samplenum - self.pulse_width) - 1)
    end
    return
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(pulse, 1)
  if not logicview.truth(_v) then return _v end
  _v = self.first_one
  return _v
end)()) then
    self.first_one = false
    _table.insert(self.subframe, { pulse, ((self.samplenum - self.pulse_width) - 1), self.samplenum })
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(pulse, 1)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.first_one))
  return _v
end)()) then
    logicview.setidx(logicview.idx(self.subframe, (-1)), 2, self.samplenum)
    self:putx(logicview.idx(logicview.idx(self.subframe, (-1)), 1), self.samplenum, { 2, { "1" } })
    self.bitcount = logicview.add(self.bitcount, 1)
    self.first_one = true
  else
    _table.insert(self.subframe, { pulse, ((self.samplenum - self.pulse_width) - 1), self.samplenum })
    self:putx(((self.samplenum - self.pulse_width) - 1), self.samplenum, { 2, { "0" } })
    self.bitcount = logicview.add(self.bitcount, 1)
  end
  if logicview.truth(logicview.eq(self.bitcount, 28)) then
    aux_audio_data = logicview.slice(self.subframe, 0, 4, nil)
    do
      local _lv_a0, _lv_a1 = "", ""
      sam = _lv_a0
      sam_rot = _lv_a1
    end
    for _lv_item in logicview.iter(aux_audio_data) do
      a = _lv_item
      sam = logicview.add(sam, _tostring(logicview.idx(a, 0)))
      sam_rot = logicview.add(_tostring(logicview.idx(a, 0)), sam_rot)
      ::continue_7::
    end
    sample = logicview.slice(self.subframe, 4, 24, nil)
    for _lv_item in logicview.iter(sample) do
      s = _lv_item
      sam = logicview.add(sam, _tostring(logicview.idx(s, 0)))
      sam_rot = logicview.add(_tostring(logicview.idx(s, 0)), sam_rot)
      ::continue_8::
    end
    validity = logicview.slice(self.subframe, 24, 25, nil)
    subcode_data = logicview.slice(self.subframe, 25, 26, nil)
    channel_status = logicview.slice(self.subframe, 26, 27, nil)
    parity = logicview.slice(self.subframe, 27, 28, nil)
    self:putx(logicview.idx(logicview.idx(aux_audio_data, 0), 1), logicview.idx(logicview.idx(aux_audio_data, 3), 2), { 3, { logicview.pymod("Aux 0x%x", logicview.tointeger(logicview.slice(sam, nil, 4, nil), 2)), logicview.pymod("0x%x", logicview.tointeger(logicview.slice(sam, nil, 4, nil), 2)) } })
    self:putx(logicview.idx(logicview.idx(sample, 0), 1), logicview.idx(logicview.idx(sample, 19), 2), { 3, { logicview.pymod("Sample 0x%x", logicview.tointeger(sam, 2)), logicview.pymod("0x%x", logicview.tointeger(sam, 2)) } })
    self:putx(logicview.idx(logicview.idx(aux_audio_data, 0), 1), logicview.idx(logicview.idx(sample, 19), 2), { 4, { logicview.pymod("Audio 0x%x", logicview.tointeger(sam_rot, 2)), logicview.pymod("0x%x", logicview.tointeger(sam_rot, 2)) } })
    if logicview.truth(logicview.eq(logicview.idx(logicview.idx(validity, 0), 0), 0)) then
      self:putx(logicview.idx(logicview.idx(validity, 0), 1), logicview.idx(logicview.idx(validity, 0), 2), { 5, { "V" } })
    else
      self:putx(logicview.idx(logicview.idx(validity, 0), 1), logicview.idx(logicview.idx(validity, 0), 2), { 5, { "E" } })
    end
    self:putx(logicview.idx(logicview.idx(subcode_data, 0), 1), logicview.idx(logicview.idx(subcode_data, 0), 2), { 6, { logicview.pymod("S: %d", logicview.idx(logicview.idx(subcode_data, 0), 0)) } })
    self:putx(logicview.idx(logicview.idx(channel_status, 0), 1), logicview.idx(logicview.idx(channel_status, 0), 2), { 7, { logicview.pymod("C: %d", logicview.idx(logicview.idx(channel_status, 0), 0)) } })
    self:putx(logicview.idx(logicview.idx(parity, 0), 1), logicview.idx(logicview.idx(parity, 0), 2), { 8, { logicview.pymod("P: %d", logicview.idx(logicview.idx(parity, 0), 0)) } })
    self.subframe = {  }
    self.seen_preamble = false
    self.bitcount = 0
  end
end
function _decoder.decode_preamble(self)
  if logicview.truth(logicview.eq(self.preamble_state, 0)) then
    _table.insert(self.preamble, self:get_pulse_type())
    self.preamble_state = 1
  elseif logicview.truth(logicview.eq(self.preamble_state, 1)) then
    _table.insert(self.preamble, self:get_pulse_type())
    self.preamble_state = 2
  elseif logicview.truth(logicview.eq(self.preamble_state, 2)) then
    _table.insert(self.preamble, self:get_pulse_type())
    self.preamble_state = 0
    self.state = "DECODE STREAM"
    if logicview.truth(logicview.eq(self.preamble, { 2, 0, 1, 0 })) then
      self:puty({ 1, { "Preamble W", "W" } })
      self.seen_preamble = true
    elseif logicview.truth(logicview.eq(self.preamble, { 2, 2, 1, 1 })) then
      self:puty({ 1, { "Preamble M", "M" } })
      self.seen_preamble = true
    elseif logicview.truth(logicview.eq(self.preamble, { 2, 1, 1, 2 })) then
      self:puty({ 1, { "Preamble B", "B" } })
      self.seen_preamble = true
    else
      self:puty({ 1, { "Unknown Preamble", "Unknown Prea.", "U" } })
    end
    self.preamble = {  }
    self.bitcount = 0
    self.first_one = true
  end
  self.last_preamble = self.samplenum
end
function _decoder.decode(self)
  local data
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  self:wait(logicview.dict({ [0] = "e" }))
  self.samplenum_prev_edge = self.samplenum
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      data = logicview.idx(_lv_seq, 0)
    end
    self.pulse_width = ((self.samplenum - self.samplenum_prev_edge) - 1)
    self.samplenum_prev_edge = self.samplenum
    if logicview.truth(logicview.eq(self.state, "GET FIRST PULSE WIDTH")) then
      self:find_first_pulse_width()
    elseif logicview.truth(logicview.eq(self.state, "GET SECOND PULSE WIDTH")) then
      self:find_second_pulse_width()
    elseif logicview.truth(logicview.eq(self.state, "GET THIRD PULSE WIDTH")) then
      self:find_third_pulse_width()
    elseif logicview.truth(logicview.eq(self.state, "DECODE STREAM")) then
      self:decode_stream()
    elseif logicview.truth(logicview.eq(self.state, "DECODE PREAMBLE")) then
      self:decode_preamble()
    end
    ::continue_9::
  end
end

return _decoder
