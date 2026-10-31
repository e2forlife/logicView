-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Steve R <steversig@virginmedia.com>
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
  id = "ook",
  name = "OOK",
  longname = "On-off keying",
  desc = "On-off keying protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "ook" },
  tags = { "Encoding" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "invert", desc = "Invert data", default = "no", values = { "no", "yes" } }), logicview.dict({ id = "decodeas", desc = "Decode type", default = "Manchester", values = { "NRZ", "Manchester", "Diff Manchester" } }), logicview.dict({ id = "preamble", desc = "Preamble", default = "auto", values = { "auto", "1010", "1111" } }), logicview.dict({ id = "preamlen", desc = "Filter length", default = "7", values = { "0", "3", "4", "5", "6", "7", "8", "9", "10" } }), logicview.dict({ id = "diffmanvar", desc = "Transition at start", default = "1", values = { "1", "0" } }) },
  annotations = { { "frame", "Frame" }, { "info", "Info" }, { "1111", "1111" }, { "1010", "1010" }, { "diffman", "Diff man" }, { "nrz", "NRZ" } },
  annotation_rows = { { "frames", "Framing", { 0 } }, { "info-vals", "Info", { 1 } }, { "man1111", "Man 1111", { 2 } }, { "man1010", "Man 1010", { 3 } }, { "diffmans", "Diff man", { 4 } }, { "nrz-vals", "NRZ", { 5 } } },
  binary = { { "pulse-lengths", "Pulse lengths" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_chain = (-1)
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  do
    local _lv_chain = (-1)
    self.ss_1111 = _lv_chain
    self.ss_1010 = _lv_chain
  end
  self.samplenumber_last = nil
  self.sample_first = nil
  self.sample_high = 0
  self.sample_low = 0
  self.edge_count = 0
  self.word_first = nil
  self.word_count = 0
  self.state = "IDLE"
  self.lstate = nil
  self.lstate_1010 = nil
  self.insync = 0
  self.man_errors = 0
  self.man_errors_1010 = 0
  self.preamble = {  }
  self.half_time = (-1)
  self.half_time_1010 = 0
  self.pulse_lengths = {  }
  self.decoded = {  }
  self.decoded_1010 = {  }
  self.diff_man_trans = "0"
  self.diff_man_len = 1
  self.max_errors = 5
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.invert = logicview.idx(self.options, "invert")
  self.decodeas = logicview.idx(self.options, "decodeas")
  self.preamble_val = logicview.idx(self.options, "preamble")
  self.preamble_len = logicview.idx(self.options, "preamlen")
  self.diffmanvar = logicview.idx(self.options, "diffmanvar")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putp(self, data)
  self:put(self.ss, self.es, self.out_python, data)
end
function _decoder.dump_pulse_lengths(self)
  local s
  if logicview.truth(self.samplerate) then
    logicview.setidx(self.pulse_lengths, (-1), self.sample_first)
    s = "Pulses(us)="
    s = logicview.add(s, logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.pulse_lengths) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(logicview.tointeger((logicview.mul(logicview.tointeger(x), 1000000) / self.samplerate)))
  end
  return _lv_out
end)()))
    s = logicview.add(s, "\n")
    self:put((self.samplenum - 10), self.samplenum, self.out_binary, { 0, logicview.bytes((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = _string.byte(c)
  end
  return _lv_out
end)()) })
  end
end
function _decoder.decode_nrz(self, start, samples, state)
  local dsamples
  _table.insert(self.pulse_lengths, samples)
  dsamples = (function() if logicview.truth(logicview.eq(state, "1")) then return self.sample_high else return self.sample_low end end)()
  do
    local _lv_a0, _lv_a1 = start, logicview.add(start, samples)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  while logicview.truth((samples > logicview.mul(dsamples, 0.5))) do
    if logicview.truth((samples >= logicview.mul(dsamples, 1.5))) then
      self.es = logicview.add(self.ss, dsamples)
      self:putx({ 5, { state } })
      _table.insert(self.decoded, { self.ss, self.es, state })
      self.edge_count = logicview.add(self.edge_count, 1)
    elseif logicview.truth((function()
  local _v
  _v = (samples >= logicview.mul(dsamples, 0.5))
  if not logicview.truth(_v) then return _v end
  _v = (samples < logicview.mul(dsamples, 1.5))
  return _v
end)()) then
      self:putx({ 5, { state } })
      _table.insert(self.decoded, { self.ss, self.es, state })
      self.edge_count = logicview.add(self.edge_count, 1)
    else
      self.edge_count = logicview.add(self.edge_count, 1)
    end
    samples = (samples - dsamples)
    self.ss = logicview.add(self.ss, dsamples)
    self.es = logicview.add(self.es, dsamples)
    if logicview.truth((self.es > self.samplenum)) then
      self.es = self.samplenum
    end
    if logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")) then
      self.ss = logicview.idx(logicview.idx(self.decoded, 0), 0)
      self.es = logicview.idx(logicview.idx(self.decoded, (logicview.len(self.decoded) - 1)), 1)
      self:dump_pulse_lengths()
      self:putp(self.decoded)
      self:decode_timeout()
      break
    end
    ::continue_1::
  end
end
function _decoder.lock_onto_preamble(self, samples, state)
  local l2s, pre_detect, pre_samples, pre, i
  self.edge_count = logicview.add(self.edge_count, 1)
  l2s = 5
  if logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")) then
    self.preamble = {  }
    self.edge_count = 0
    self.word_first = self.samplenum
    self.sample_first = (self.samplenum - self.samplenumber_last)
    self.state = "WAITING_FOR_PREAMBLE"
    self.man_errors = 0
  end
  pre_detect = logicview.tointeger(self.preamble_len)
  pre_samples = (self.samplenum - self.samplenumber_last)
  if logicview.truth((logicview.len(self.preamble) > 0)) then
    if logicview.truth((function()
  local _v
  _v = (logicview.mul(pre_samples, l2s) < logicview.idx(logicview.idx(self.preamble, (-1)), 1))
  if logicview.truth(_v) then return _v end
  _v = (logicview.mul(logicview.idx(logicview.idx(self.preamble, (-1)), 1), l2s) < pre_samples)
  return _v
end)()) then
      self:put(self.samplenum, self.samplenum, self.out_ann, { 0, { "R" } })
      self.preamble = {  }
      _table.insert(self.preamble, { self.samplenumber_last, pre_samples, state })
      self.edge_count = 0
      self.samplenumber_last = self.samplenum
      self.word_first = self.samplenum
    else
      _table.insert(self.preamble, { self.samplenumber_last, pre_samples, state })
    end
  else
    _table.insert(self.preamble, { self.samplenumber_last, pre_samples, state })
  end
  pre = self.preamble
  if logicview.truth(logicview.eq(logicview.len(self.preamble), pre_detect)) then
    if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.preamble, 0), 2), "1")) then
      self.sample_high = logicview.idx(logicview.idx(self.preamble, 0), 1)
      self.sample_low = logicview.idx(logicview.idx(self.preamble, 1), 1)
    else
      self.sample_high = logicview.idx(logicview.idx(self.preamble, 1), 1)
      self.sample_low = logicview.idx(logicview.idx(self.preamble, 0), 1)
    end
    self.edge_count = 0
    for _lv_i in logicview.range(logicview.len(self.preamble)) do
      i = _lv_i
      if logicview.truth((i > 1)) then
        if logicview.truth((function()
  local _v
  _v = (logicview.idx(logicview.idx(pre, i), 1) > logicview.mul(logicview.idx(logicview.idx(pre, (i - 2)), 1), 1.25))
  if logicview.truth(_v) then return _v end
  _v = (logicview.mul(logicview.idx(logicview.idx(pre, i), 1), 1.25) < logicview.idx(logicview.idx(pre, (i - 2)), 1))
  return _v
end)()) then
          if logicview.truth(logicview.eq(logicview.idx(logicview.idx(pre, i), 2), "1")) then
            self.sample_high = logicview.idx(logicview.idx(pre, i), 1)
          else
            self.sample_low = logicview.idx(logicview.idx(pre, i), 1)
          end
        end
      end
      if logicview.truth(logicview.eq(self.decodeas, "NRZ")) then
        self:decode_nrz(logicview.idx(logicview.idx(pre, i), 0), logicview.idx(logicview.idx(pre, i), 1), logicview.idx(logicview.idx(pre, i), 2))
      end
      if logicview.truth(logicview.eq(self.decodeas, "Manchester")) then
        self:decode_manchester(logicview.idx(logicview.idx(pre, i), 0), logicview.idx(logicview.idx(pre, i), 1), logicview.idx(logicview.idx(pre, i), 2))
      end
      if logicview.truth(logicview.eq(self.decodeas, "Diff Manchester")) then
        self.es = logicview.add(logicview.idx(logicview.idx(pre, i), 0), logicview.idx(logicview.idx(pre, i), 1))
        self:decode_diff_manchester(logicview.idx(logicview.idx(pre, i), 0), logicview.idx(logicview.idx(pre, i), 1), logicview.idx(logicview.idx(pre, i), 2))
      end
      self.sample_first = logicview.tointeger((logicview.add(self.sample_high, self.sample_low) / 2))
      ::continue_2::
    end
    self.insync = 1
    self.state = "DECODING"
  end
  self.lstate = state
  self.lstate_1010 = state
end
function _decoder.decode_diff_manchester(self, start, samples, state)
  local dsamples, p_length, error_message
  _table.insert(self.pulse_lengths, samples)
  dsamples = (function() if logicview.truth(logicview.eq(state, "1")) then return self.sample_high else return self.sample_low end end)()
  self.es = logicview.add(start, samples)
  p_length = (function() local _n = (samples / dsamples); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)()
  if logicview.truth(logicview.eq(self.edge_count, 0)) then
    self.diff_man_trans = "1"
    self.diff_man_len = 1
    self.ss = start
  elseif logicview.truth(logicview.eq(logicview.pymod(self.edge_count, 2), 1)) then
    if logicview.truth(logicview.eq(self.diffmanvar, "0")) then
      self.diff_man_trans = (function() if logicview.truth(logicview.eq(self.diff_man_trans, "1")) then return "0" else return "1" end end)()
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.diff_man_len, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(p_length, 1)
  return _v
end)()) then
      self:putx({ 4, { self.diff_man_trans } })
      _table.insert(self.decoded, { self.ss, self.es, self.diff_man_trans })
      self.diff_man_trans = "1"
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.diff_man_len, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(p_length, 2)
  return _v
end)()) then
      self.es = (self.es - logicview.tointeger((samples / 2)))
      self:putx({ 4, { self.diff_man_trans } })
      _table.insert(self.decoded, { self.ss, self.es, self.diff_man_trans })
      self.diff_man_trans = "0"
      self.edge_count = logicview.add(self.edge_count, 1)
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.diff_man_len, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(p_length, 1)
  return _v
end)()) then
      self:putx({ 4, { self.diff_man_trans } })
      _table.insert(self.decoded, { self.ss, self.es, self.diff_man_trans })
      self.diff_man_trans = "1"
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.diff_man_len, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(p_length, 2)
  return _v
end)()) then
      self.es = (self.es - samples)
      self:putx({ 4, { "E" } })
      _table.insert(self.decoded, { self.ss, self.es, "E" })
      self.ss = self.es
      self.es = logicview.add(self.es, samples)
      self:putx({ 4, { "E" } })
      _table.insert(self.decoded, { self.ss, self.es, "E" })
      self.diff_man_trans = "1"
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.diff_man_len, 1)
  if not logicview.truth(_v) then return _v end
  _v = (p_length > 4)
  return _v
end)()) then
      if logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")) then
        self.es = logicview.add(self.ss, logicview.mul(2, self.sample_first))
        self:putx({ 4, { self.diff_man_trans } })
        _table.insert(self.decoded, { self.ss, self.es, self.diff_man_trans })
        self.ss = logicview.idx(logicview.idx(self.decoded, 0), 0)
        self.es = logicview.idx(logicview.idx(self.decoded, (logicview.len(self.decoded) - 1)), 1)
        self:dump_pulse_lengths()
        if logicview.truth((self.man_errors < self.max_errors)) then
          self:putp(self.decoded)
        else
          error_message = "Probably not Diff Manchester encoded"
          self.ss = self.word_first
          self:putx({ 1, { error_message } })
        end
        self:decode_timeout()
      end
      self.diff_man_trans = "1"
    end
    self.ss = self.es
  end
  self.diff_man_len = p_length
  self.edge_count = logicview.add(self.edge_count, 1)
end
function _decoder.decode_manchester_sim(self, start, samples, state, dsamples, half_time, lstate, ss, pream)
  local ook_bit, errors, es
  ook_bit = {  }
  errors = 0
  if logicview.truth(logicview.eq(self.edge_count, 0)) then
    half_time = logicview.add(half_time, 1)
  end
  if logicview.truth((function()
  local _v
  _v = (samples > logicview.mul(0.75, dsamples))
  if not logicview.truth(_v) then return _v end
  _v = (samples <= logicview.mul(1.5, dsamples))
  return _v
end)()) then
    half_time = logicview.add(half_time, 2)
    if logicview.truth(logicview.eq(logicview.pymod(half_time, 2), 0)) then
      es = start
    else
      es = logicview.add(start, logicview.tointeger((samples / 2)))
    end
    if logicview.truth(logicview.eq(ss, start)) then
      lstate = "E"
      es = logicview.add(start, samples)
    end
    if logicview.truth((not logicview.truth((function()
  local _v
  _v = logicview.eq(self.edge_count, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(pream, "1010")
  return _v
end)()))) then
      ook_bit = { ss, es, lstate }
    end
    lstate = state
    ss = es
  elseif logicview.truth((function()
  local _v
  _v = (samples > logicview.mul(0.25, dsamples))
  if not logicview.truth(_v) then return _v end
  _v = (samples <= logicview.mul(0.75, dsamples))
  return _v
end)()) then
    half_time = logicview.add(half_time, 1)
    if logicview.truth(logicview.eq(logicview.pymod(half_time, 2), 0)) then
      es = logicview.add(start, samples)
      ook_bit = { ss, es, lstate }
      lstate = state
      ss = es
    else
      ss = start
      lstate = state
    end
  else
    errors = 1
    if logicview.truth((not logicview.eq(self.state, "DECODE_TIMEOUT"))) then
      lstate = "E"
      es = logicview.add(ss, samples)
    else
      es = logicview.add(ss, self.sample_first)
    end
    ook_bit = { ss, es, lstate }
    ss = es
  end
  return { half_time, lstate, ss, ook_bit, errors }
end
function _decoder.decode_manchester(self, start, samples, state)
  local dsamples, ook_bit, errors, decoded, man_errors, d_row, i, error_message
  _table.insert(self.pulse_lengths, samples)
  dsamples = (function() if logicview.truth(logicview.eq(state, "1")) then return self.sample_high else return self.sample_low end end)()
  if logicview.truth((not logicview.eq(self.preamble_val, "1010"))) then
    do
      local _lv_seq = self:decode_manchester_sim(start, samples, state, logicview.mul(dsamples, 2), self.half_time, self.lstate, self.ss_1111, "1111")
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.half_time = logicview.idx(_lv_seq, 0)
      self.lstate = logicview.idx(_lv_seq, 1)
      self.ss_1111 = logicview.idx(_lv_seq, 2)
      ook_bit = logicview.idx(_lv_seq, 3)
      errors = logicview.idx(_lv_seq, 4)
    end
    self.man_errors = logicview.add(self.man_errors, errors)
    if logicview.truth((not logicview.eq(ook_bit, {  }))) then
      _table.insert(self.decoded, { logicview.idx(ook_bit, 0), logicview.idx(ook_bit, 1), logicview.idx(ook_bit, 2) })
    end
  end
  if logicview.truth((not logicview.eq(self.preamble_val, "1111"))) then
    do
      local _lv_seq = self:decode_manchester_sim(start, samples, state, dsamples, self.half_time_1010, self.lstate_1010, self.ss_1010, "1010")
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.half_time_1010 = logicview.idx(_lv_seq, 0)
      self.lstate_1010 = logicview.idx(_lv_seq, 1)
      self.ss_1010 = logicview.idx(_lv_seq, 2)
      ook_bit = logicview.idx(_lv_seq, 3)
      errors = logicview.idx(_lv_seq, 4)
    end
    self.man_errors_1010 = logicview.add(self.man_errors_1010, errors)
    if logicview.truth((not logicview.eq(ook_bit, {  }))) then
      _table.insert(self.decoded_1010, { logicview.idx(ook_bit, 0), logicview.idx(ook_bit, 1), logicview.idx(ook_bit, 2) })
    end
  end
  self.edge_count = logicview.add(self.edge_count, 1)
  if logicview.truth((not logicview.eq(ook_bit, {  }))) then
    do
      local _lv_a0, _lv_a1 = logicview.idx(ook_bit, 0), logicview.idx(ook_bit, 1)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(self.preamble_val, "1111")) then
      self:putx({ 2, { logicview.idx(ook_bit, 2) } })
    end
    if logicview.truth(logicview.eq(self.preamble_val, "1010")) then
      self:putx({ 3, { logicview.idx(ook_bit, 2) } })
    end
  end
  if logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")) then
    self:dump_pulse_lengths()
    decoded = {  }
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.preamble_val, "1010")
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (self.man_errors_1010 < self.max_errors)
  if not logicview.truth(_v) then return _v end
  _v = (self.man_errors_1010 < self.man_errors)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.decoded_1010) > 0)
  return _v
end)()
  return _v
end)()) then
      decoded = self.decoded_1010
      man_errors = self.man_errors_1010
      d_row = 3
    else
      decoded = self.decoded
      man_errors = self.man_errors
      d_row = 2
    end
    if logicview.truth(logicview.eq(self.preamble_val, "auto")) then
      for _lv_i in logicview.range(logicview.len(decoded)) do
        i = _lv_i
        do
          local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(decoded, i), 0), logicview.idx(logicview.idx(decoded, i), 1)
          self.ss = _lv_a0
          self.es = _lv_a1
        end
        self:putx({ d_row, { logicview.idx(logicview.idx(decoded, i), 2) } })
        ::continue_3::
      end
    end
    if logicview.truth((function()
  local _v
  _v = (man_errors < self.max_errors)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(decoded) > 0)
  return _v
end)()) then
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(decoded, 0), 0), logicview.idx(logicview.idx(decoded, (logicview.len(decoded) - 1)), 1)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putp(decoded)
    else
      error_message = "Not Manchester encoded or wrong preamble"
      self.ss = self.word_first
      self:putx({ 1, { error_message } })
    end
    self:put(self.es, self.es, self.out_ann, { 0, { "T" } })
    self:decode_timeout()
  end
end
function _decoder.decode_timeout(self)
  self.word_count = 0
  self.samplenumber_last = nil
  self.edge_count = 0
  self.man_errors = 0
  self.man_errors_1010 = 0
  self.state = "IDLE"
  self:wait(logicview.dict({ [0] = "e" }))
  self.samplenumber_last = self.samplenum
  self.word_first = self.samplenum
  self.insync = 0
  self.preamble = {  }
  self.half_time = (-1)
  self.half_time_1010 = 0
  self.decoded = {  }
  self.decoded_1010 = {  }
  self.pulse_lengths = {  }
end
function _decoder.end_(self)
  self:putp(self.decoded)
end
function _decoder.decode(self)
  local ook, samples, pinstate, state
  while true do
    if logicview.truth(logicview.eq(self.edge_count, 0)) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ook = logicview.idx(_lv_seq, 0)
      end
      self.state = "DECODING"
    else
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ skip = logicview.mul(5, self.sample_first) }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ook = logicview.idx(_lv_seq, 0)
      end
      if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 1))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 0))))
  return _v
end)()) then
        self.state = "DECODE_TIMEOUT"
      end
    end
    if logicview.truth((not logicview.truth(self.samplenumber_last))) then
      self.samplenumber_last = self.samplenum
      self.word_first = self.samplenum
      goto continue_4
    end
    samples = (self.samplenum - self.samplenumber_last)
    if logicview.truth((not logicview.truth(self.sample_first))) then
      self.sample_first = samples
    end
    pinstate = ook
    if logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")) then
      pinstate = logicview.tointeger((not logicview.truth(pinstate)))
    end
    if logicview.truth(logicview.eq(self.invert, "yes")) then
      pinstate = logicview.tointeger((not logicview.truth(pinstate)))
    end
    state = (function() if logicview.truth(pinstate) then return "0" else return "1" end end)()
    if logicview.truth(logicview.eq(self.preamble_len, "0")) then
      self.sample_high = self.sample_first
      self.sample_low = self.sample_first
      self.insync = 0
    end
    if logicview.truth(logicview.eq(self.insync, 0)) then
      self:lock_onto_preamble(samples, state)
    else
      if logicview.truth(logicview.eq(self.decodeas, "NRZ")) then
        self:decode_nrz(self.samplenumber_last, samples, state)
      end
      if logicview.truth(logicview.eq(self.decodeas, "Manchester")) then
        self:decode_manchester(self.samplenumber_last, samples, state)
      end
      if logicview.truth(logicview.eq(self.decodeas, "Diff Manchester")) then
        self:decode_diff_manchester(self.samplenumber_last, samples, state)
      end
    end
    self.samplenumber_last = self.samplenum
    ::continue_4::
  end
end

return _decoder
