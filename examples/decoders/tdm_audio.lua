-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Ben Dooks <ben.dooks@codethink.co.uk>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local MAX_CHANNELS, Decoder
local _decoder

MAX_CHANNELS = 8
_decoder = {
  api_version = 3,
  id = "tdm_audio",
  name = "TDM audio",
  longname = "Time division multiplex audio",
  desc = "TDM multi-channel audio protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Audio" },
  channels = { logicview.dict({ id = "clock", name = "Bitclk", desc = "Data bit clock" }), logicview.dict({ id = "frame", name = "Framesync", desc = "Frame sync" }), logicview.dict({ id = "data", name = "Data", desc = "Serial data" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "bps", desc = "Bits per sample", default = 16, values = {  } }), logicview.dict({ id = "channels", desc = "Channels per frame", default = 8, values = { 1, 2, 3, 4, 5, 6, 7, 8 } }), logicview.dict({ id = "edge", desc = "Clock edge to sample on", default = "rising", values = { "rising", "falling" } }), logicview.dict({ id = "sampling edge", desc = "Sampling Edge", default = "first edge", values = { "first edge", "second edge" } }) },
  annotations = { { "ch0", "Ch0" }, { "ch1", "Ch1" }, { "ch2", "Ch2" }, { "ch3", "Ch3" }, { "ch4", "Ch4" }, { "ch5", "Ch5" }, { "ch6", "Ch6" }, { "ch7", "Ch7" } },
  annotation_rows = { { "ch0-vals", "Ch0", { 0 } }, { "ch1-vals", "Ch1", { 1 } }, { "ch2-vals", "Ch2", { 2 } }, { "ch3-vals", "Ch3", { 3 } }, { "ch4-vals", "Ch4", { 4 } }, { "ch5-vals", "Ch5", { 5 } }, { "ch6-vals", "Ch6", { 6 } }, { "ch7-vals", "Ch7", { 7 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.channels = MAX_CHANNELS
  self.channel = 0
  self.bitdepth = 16
  self.bitcount = 0
  self.samplecount = 0
  self.lastsync = 0
  self.lastframe = 0
  self.data = 0
  self.ss_block = nil
end
function _decoder.metdatadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.bitdepth = logicview.idx(self.options, "bps")
  self.edge = logicview.idx(self.options, "edge")
end
function _decoder.decode(self)
  local clock, frame, data, c1, c2, c3, v, ch
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = logicview.idx(self.edge, 0) }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clock = logicview.idx(_lv_seq, 0)
      frame = logicview.idx(_lv_seq, 1)
      data = logicview.idx(_lv_seq, 2)
    end
    self.data = ((self.data << 1) | data)
    self.bitcount = logicview.add(self.bitcount, 1)
    if logicview.truth((self.ss_block ~= nil)) then
      if logicview.truth((self.bitcount >= self.bitdepth)) then
        self.bitcount = 0
        c1 = logicview.pymod("Channel %d", logicview.pymod(self.channel, self.channels))
        c2 = logicview.pymod("C%d", logicview.pymod(self.channel, self.channels))
        c3 = logicview.pymod("%d", logicview.pymod(self.channel, self.channels))
        if logicview.truth((self.bitdepth <= 8)) then
          v = logicview.pymod("%02x", self.data)
        elseif logicview.truth((self.bitdepth <= 16)) then
          v = logicview.pymod("%04x", self.data)
        else
          v = logicview.pymod("%08x", self.data)
        end
        ch = logicview.pymod(self.channel, self.channels)
        self:put(self.ss_block, self.samplenum, self.out_ann, { ch, { logicview.pymod("%s: %s", { c1, v }), logicview.pymod("%s: %s", { c2, v }), logicview.pymod("%s: %s", { c3, v }) } })
        self.data = 0
        self.ss_block = self.samplenum
        self.samplecount = logicview.add(self.samplecount, 1)
        self.channel = logicview.add(self.channel, 1)
      end
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(frame, self.lastframe))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(frame, 1)
  return _v
end)()) then
      self.channel = 0
      if logicview.truth(logicview.eq(logicview.idx(self.options, "sampling edge"), "first edge")) then
        self.bitcount = 1
        self.data = data
      else
        self.bitcount = 0
        self.data = 0
      end
      if logicview.truth((self.ss_block == nil)) then
        self.ss_block = self.samplenum
      end
    end
    self.lastframe = frame
    ::continue_1::
  end
end

return _decoder
