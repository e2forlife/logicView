-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Fabian J. Stumpf <sigrok@fabianstumpf.de>
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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "dmx512",
  name = "DMX512",
  longname = "Digital MultipleX 512",
  desc = "Digital MultipleX 512 (DMX512) lighting protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial", "Lighting" },
  channels = { logicview.dict({ id = "dmx", name = "DMX data", desc = "Any DMX data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "invert", desc = "Invert Signal?", default = "no", values = { "yes", "no" } }) },
  annotations = { { "bit", "Bit" }, { "break", "Break" }, { "mab", "Mark after break" }, { "startbit", "Start bit" }, { "stopbits", "Stop bit" }, { "startcode", "Start code" }, { "channel", "Channel" }, { "interframe", "Interframe" }, { "interpacket", "Interpacket" }, { "data", "Data" }, { "error", "Error" } },
  annotation_rows = { { "name", "Logical", { 1, 2, 5, 6, 7, 8 } }, { "data", "Data", { 9 } }, { "bits", "Bits", { 0, 3, 4 } }, { "errors", "Errors", { 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.sample_usec = nil
  self.run_start = (-1)
  self.state = "FIND BREAK"
  self.bit_pos = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(11) do
    _ = _lv_i
    _lv_out[#_lv_out + 1] = { 0, 0, 0 }
  end
  return _lv_out
end)()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.sample_usec = logicview.mul((1 / value), 1000000)
    self.skip_per_bit = logicview.tointeger((4 / self.sample_usec))
  end
end
function _decoder.putr(self, data)
  self:put(self.run_start, self.samplenum, self.out_ann, data)
end
function _decoder.decode(self)
  local inv, dmx, runlen, bit_start, bit_end, bit_value, index, value, d
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  inv = logicview.eq(logicview.idx(self.options, "invert"), "yes")
  do
    local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "h" else return "l" end end)() }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    dmx = logicview.idx(_lv_seq, 0)
  end
  self.run_start = self.samplenum
  while true do
    if logicview.truth(logicview.eq(self.state, "FIND BREAK")) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "f" else return "r" end end)() }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dmx = logicview.idx(_lv_seq, 0)
      end
      runlen = logicview.mul((self.samplenum - self.run_start), self.sample_usec)
      if logicview.truth((function()
  local _v
  _v = (runlen > 88)
  if not logicview.truth(_v) then return _v end
  _v = (runlen < 1000000)
  return _v
end)()) then
        self:putr({ 1, { "Break" } })
        self.state = "MARK MAB"
        self.channel = 0
      elseif logicview.truth((runlen >= 1000000)) then
        self:putr({ 10, { "Invalid break length" } })
      else
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "h" else return "l" end end)() }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          dmx = logicview.idx(_lv_seq, 0)
        end
        self.run_start = self.samplenum
      end
    elseif logicview.truth(logicview.eq(self.state, "MARK MAB")) then
      self.run_start = self.samplenum
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "r" else return "f" end end)() }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dmx = logicview.idx(_lv_seq, 0)
      end
      self:putr({ 2, { "MAB" } })
      self.state = "READ BYTE"
      self.channel = 0
      self.bit = 0
      self.aggreg = dmx
      self.run_start = self.samplenum
    elseif logicview.truth(logicview.eq(self.state, "READ BYTE")) then
      bit_start = self.samplenum
      bit_end = logicview.add(self.run_start, logicview.mul(logicview.add(self.bit, 1), self.skip_per_bit))
      do
        local _lv_seq = self:wait(logicview.dict({ skip = (function() local _n = (self.skip_per_bit / 2); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)() }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dmx = logicview.idx(_lv_seq, 0)
      end
      bit_value = (function() if logicview.truth(inv) then return (not logicview.truth(dmx)) else return dmx end end)()
      logicview.setidx(self.bit_pos, self.bit, { bit_start, bit_end, bit_value })
      if logicview.truth(logicview.eq(self.bit, 0)) then
        self.byte = 0
      elseif logicview.truth((self.bit >= 9)) then
        if logicview.truth((not logicview.eq(bit_value, 1))) then
          if logicview.truth(logicview.eq(self.bit, 10)) then
            self.state = "FIND BREAK"
          end
        end
      else
        self.byte = (self.byte | (bit_value << (self.bit - 1)))
      end
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "READ BYTE")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bit, 10)
  return _v
end)()) then
        for _lv_i, _lv_v in logicview.enumerate(self.bit_pos) do
          index = _lv_i
          value = _lv_v
          if logicview.truth(logicview.eq(index, 0)) then
            if logicview.truth(logicview.eq(logicview.idx(value, 2), 0)) then
              self:put(logicview.idx(value, 0), logicview.idx(value, 1), self.out_ann, { 3, { "Start bit" } })
            else
              self:put(logicview.idx(value, 0), logicview.idx(value, 1), self.out_ann, { 10, { "Invalid start bit" } })
            end
          elseif logicview.truth((index >= 9)) then
            if logicview.truth(logicview.eq(logicview.idx(value, 2), 1)) then
              self:put(logicview.idx(value, 0), logicview.idx(value, 1), self.out_ann, { 4, { "Stop bit" } })
            else
              self:put(logicview.idx(value, 0), logicview.idx(value, 1), self.out_ann, { 10, { "Invalid stop bit" } })
            end
          else
            self:put(logicview.idx(value, 0), logicview.idx(value, 1), self.out_ann, { 0, { _tostring(logicview.idx(value, 2)) } })
          end
          ::continue_2::
        end
        if logicview.truth(logicview.eq(self.channel, 0)) then
          d = { 5, { "Start code" } }
        else
          d = { 6, { logicview.add("Channel ", _tostring(self.channel)) } }
        end
        self:put(self.run_start, bit_end, self.out_ann, d)
        self:put(logicview.add(self.run_start, self.skip_per_bit), (bit_end - logicview.mul(2, self.skip_per_bit)), self.out_ann, { 9, { logicview.add(logicview.add(_tostring(self.byte), " / "), _tostring(logicview.hex(self.byte))) } })
        self.channel = logicview.add(self.channel, 1)
        self.run_start = self.samplenum
        self.state = "MARK IFT"
      end
      self.bit = logicview.add(self.bit, 1)
      do
        local _lv_seq = self:wait(logicview.dict({ skip = (function() local _n = (bit_end - self.samplenum); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)() }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dmx = logicview.idx(_lv_seq, 0)
      end
    elseif logicview.truth(logicview.eq(self.state, "MARK IFT")) then
      self.run_start = self.samplenum
      if logicview.truth((self.channel > 65535)) then
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "h" else return "l" end end)() }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          dmx = logicview.idx(_lv_seq, 0)
        end
        self:putr({ 8, { "Interpacket" } })
        self.state = "FIND BREAK"
        self.run_start = self.samplenum
      else
        if logicview.truth((function() if logicview.truth(inv) then return (not logicview.truth(dmx)) else return dmx end end)()) then
          do
            local _lv_seq = self:wait(logicview.dict({ [0] = (function() if logicview.truth(inv) then return "h" else return "l" end end)() }))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            dmx = logicview.idx(_lv_seq, 0)
          end
          self:putr({ 7, { "Interframe" } })
        end
        self.state = "READ BYTE"
        self.bit = 0
        self.run_start = self.samplenum
      end
    end
    ::continue_1::
  end
end

return _decoder
