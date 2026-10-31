-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
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
local ChannelError, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "C2",
  name = "C2 interface",
  longname = "Silabs C2 Interface",
  desc = "Half-duplex, synchronous, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "C2" },
  tags = { "Embedded/mcu" },
  channels = { logicview.dict({ id = "c2ck", name = "c2ck", desc = "Clock" }), logicview.dict({ id = "c2d", name = "c2d", desc = "Data" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "106", "raw-Data", "raw data" }, { "106", "c2-data", "c2 data" }, { "warnings", "Warnings" } },
  annotation_rows = { { "raw-Data", "raw data", { 0 } }, { "c2-data", "c2 data", { 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.state = "reset"
  self.bitcount = 0
  self.c2_data = 0
  self.data = 0
  do
    local _lv_chain = nil
    self.have_c2ck = _lv_chain
    self.have_c2d = _lv_chain
  end
  self.ins = nil
  self.start_first_sample = 0
  self.data_first_sample = 0
  self.data_len = 0
  self.remain_data = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.decode(self)
  local tf, tr, c2ck, c2d, interval, ss
  if logicview.truth((not logicview.truth(self:has_channel(0)))) then
    _error(ChannelError("CLK pin required."), 0)
  end
  self.have_c2d = self:has_channel(1)
  if logicview.truth((not logicview.truth(self.have_c2d))) then
    _error(ChannelError("C2D pins required."), 0)
  end
  tf = 0
  tr = 0
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      c2ck = logicview.idx(_lv_seq, 0)
      c2d = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(c2ck, 0)) then
      tf = self.samplenum
    else
      tr = self.samplenum
      interval = (logicview.mul(logicview.mul((tr - tf), 1000), 1000) / self.samplerate)
      if logicview.truth((interval > 20)) then
        self:put(tf, tr, self.out_ann, { 0, { "Reset", "R" } })
        self.state = "start"
      elseif logicview.truth(logicview.eq(self.state, "start")) then
        self:put(tf, tr, self.out_ann, { 0, { "Start", "S" } })
        self.start_first_sample = tf
        self.state = "ins"
        ss = tr
        self.ins = 0
        self.bitcount = 0
      elseif logicview.truth(logicview.eq(self.state, "ins")) then
        self.ins = (self.ins | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 2)) then
          self:put(ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%1d", self.ins) } })
          if logicview.truth(logicview.eq(self.ins, 0)) then
            self.state = "Data Read Len"
            self.data_len = 0
            self.remain_data = 0
          elseif logicview.truth(logicview.eq(self.ins, 1)) then
            self.state = "Data Write Len"
            self.data_len = 0
            self.remain_data = 0
          elseif logicview.truth(logicview.eq(self.ins, 2)) then
            self.state = "Address Read"
          elseif logicview.truth(logicview.eq(self.ins, 3)) then
            self.state = "Address Write"
          end
          ss = tr
          self.c2_data = 0
          self.bitcount = 0
        end
      elseif logicview.truth(logicview.eq(self.state, "Data Read Len")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 2)) then
          self:put(ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%01d", self.c2_data) } })
          self.state = "Read Wait"
          self.data_len = logicview.add(self.c2_data, 1)
          self.remain_data = self.data_len
          ss = tr
        end
      elseif logicview.truth(logicview.eq(self.state, "Read Wait")) then
        self:put(ss, self.samplenum, self.out_ann, { 0, { "Wait", "W" } })
        self.state = "Data Read"
        self.data = 0
        ss = tr
        self.c2_data = 0
        self.bitcount = 0
      elseif logicview.truth(logicview.eq(self.state, "Data Read")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 8)) then
          self:put(ss, tr, self.out_ann, { 0, { logicview.pymod("%02X", self.c2_data) } })
          self.data = (self.data | (self.c2_data << logicview.mul((self.data_len - self.remain_data), 8)))
          ss = tr
          self.c2_data = 0
          self.bitcount = 0
          self.remain_data = (self.remain_data - 1)
          if logicview.truth(logicview.eq(self.remain_data, 0)) then
            self.state = "End"
          end
        end
      elseif logicview.truth(logicview.eq(self.state, "Data Write Len")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 2)) then
          self:put(ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%01d", self.c2_data) } })
          self.state = "Data Write"
          self.data_len = logicview.add(self.c2_data, 1)
          self.remain_data = self.data_len
          self.data = 0
          ss = tr
          self.c2_data = 0
          self.bitcount = 0
        end
      elseif logicview.truth(logicview.eq(self.state, "Data Write")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 8)) then
          self:put(ss, tr, self.out_ann, { 0, { logicview.pymod("%02X", self.c2_data) } })
          self.data = (self.data | (self.c2_data << logicview.mul((self.data_len - self.remain_data), 8)))
          ss = tr
          self.c2_data = 0
          self.bitcount = 0
          self.remain_data = (self.remain_data - 1)
          if logicview.truth(logicview.eq(self.remain_data, 0)) then
            self.state = "Write Wait"
          end
        end
      elseif logicview.truth(logicview.eq(self.state, "Write Wait")) then
        self:put(ss, self.samplenum, self.out_ann, { 0, { "Wait", "W" } })
        self.state = "End"
        ss = tr
      elseif logicview.truth(logicview.eq(self.state, "Address Write")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 8)) then
          self:put(ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%02X", self.c2_data) } })
          self.state = "End"
          ss = tr
        end
      elseif logicview.truth(logicview.eq(self.state, "Address Read")) then
        self.c2_data = (self.c2_data | (c2d << self.bitcount))
        self.bitcount = logicview.add(self.bitcount, 1)
        if logicview.truth((self.bitcount >= 8)) then
          self:put(ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%02X", self.c2_data) } })
          self.state = "End"
          ss = tr
        end
      elseif logicview.truth(logicview.eq(self.state, "End")) then
        self:put(ss, self.samplenum, self.out_ann, { 0, { "End", "E" } })
        if logicview.truth(logicview.eq(self.ins, 0)) then
          self:put(self.start_first_sample, self.samplenum, self.out_ann, { 1, { logicview.pymod("ReadData(%01d)=0x%02X", { self.data_len, self.data }) } })
        elseif logicview.truth(logicview.eq(self.ins, 1)) then
          self:put(self.start_first_sample, self.samplenum, self.out_ann, { 1, { logicview.pymod("WriteData(0x%02X,%01d)", { self.data, self.data_len }) } })
        elseif logicview.truth(logicview.eq(self.ins, 2)) then
          self:put(self.start_first_sample, self.samplenum, self.out_ann, { 1, { logicview.pymod("ReadAddress()=0x%02X", self.c2_data) } })
        elseif logicview.truth(logicview.eq(self.ins, 3)) then
          self:put(self.start_first_sample, self.samplenum, self.out_ann, { 1, { logicview.pymod("WriteAddress(0x%02X)", self.c2_data) } })
        end
        self.state = "start"
      end
    end
    ::continue_1::
  end
end

return _decoder
