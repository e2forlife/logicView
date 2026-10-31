-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 fenugrec <fenugrec@users.sourceforge.net>
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
local ChannelError, Decoder
local _decoder

ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "mcs48",
  name = "MCS-48",
  longname = "Intel MCS-48",
  desc = "Intel MCS-48 external memory access protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Retro computing" },
  channels = { logicview.dict({ id = "ale", name = "ALE", desc = "Address latch enable" }), logicview.dict({ id = "psen", name = "/PSEN", desc = "Program store enable" }), logicview.dict({ id = "d0", name = "D0", desc = "CPU data line 0" }), logicview.dict({ id = "d1", name = "D1", desc = "CPU data line 1" }), logicview.dict({ id = "d2", name = "D2", desc = "CPU data line 2" }), logicview.dict({ id = "d3", name = "D3", desc = "CPU data line 3" }), logicview.dict({ id = "d4", name = "D4", desc = "CPU data line 4" }), logicview.dict({ id = "d5", name = "D5", desc = "CPU data line 5" }), logicview.dict({ id = "d6", name = "D6", desc = "CPU data line 6" }), logicview.dict({ id = "d7", name = "D7", desc = "CPU data line 7" }), logicview.dict({ id = "a8", name = "A8", desc = "CPU address line 8" }), logicview.dict({ id = "a9", name = "A9", desc = "CPU address line 9" }), logicview.dict({ id = "a10", name = "A10", desc = "CPU address line 10" }), logicview.dict({ id = "a11", name = "A11", desc = "CPU address line 11" }) },
  optional_channels = { logicview.dict({ id = "a12", name = "A12", desc = "CPU address line 12" }) },
  options = {  },
  annotations = { { "romdata", "Address:Data" } },
  annotation_rows = {  },
  binary = { { "romdata", "AAAA:DD" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.addr = 0
  self.addr_s = 0
  self.data = 0
  self.data_s = 0
  self.started = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_bin = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.newaddr(self, addr, data)
  self.started = 1
  addr = logicview.sum((function()
  local _lv_out = {}
  for _lv_i, _lv_v in logicview.enumerate(addr) do
    i = _lv_i
    bit = _lv_v
    _lv_out[#_lv_out + 1] = (bit << i)
  end
  return _lv_out
end)())
  addr = (addr << logicview.len(data))
  addr = (addr | logicview.sum((function()
  local _lv_out = {}
  for _lv_i, _lv_v in logicview.enumerate(data) do
    i = _lv_i
    bit = _lv_v
    _lv_out[#_lv_out + 1] = (bit << i)
  end
  return _lv_out
end)()))
  self.addr = addr
  self.addr_s = self.samplenum
end
function _decoder.newdata(self, data)
  local anntext, bindata
  data = logicview.sum((function()
  local _lv_out = {}
  for _lv_i, _lv_v in logicview.enumerate(data) do
    i = _lv_i
    bit = _lv_v
    _lv_out[#_lv_out + 1] = (bit << i)
  end
  return _lv_out
end)())
  self.data = data
  self.data_s = self.samplenum
  if logicview.truth(self.started) then
    anntext = logicview.pyformat("{:04X}:{:02X}", { self.addr, self.data }, logicview.dict({}))
    self:put(self.addr_s, self.data_s, self.out_ann, { 0, { anntext } })
    bindata = logicview.to_bytes(self.addr, 2, 'big')
    bindata = logicview.add(bindata, logicview.to_bytes(self.data, 1, 'big'))
    self:put(self.addr_s, self.data_s, self.out_bin, { 0, bindata })
  end
end
function _decoder.decode(self)
  local has_bank, bank_pin_count, ale, psen, d0, d1, d2, d3, d4, d5, d6, d7, a8, a9, a10, a11, a12, data, addr, bank
  has_bank = self:has_channel(14)
  bank_pin_count = (function() if logicview.truth(has_bank) then return 1 else return 0 end end)()
  while true do
    do
      local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [1] = "r" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ale = logicview.idx(_lv_seq, 0)
      psen = logicview.idx(_lv_seq, 1)
      d0 = logicview.idx(_lv_seq, 2)
      d1 = logicview.idx(_lv_seq, 3)
      d2 = logicview.idx(_lv_seq, 4)
      d3 = logicview.idx(_lv_seq, 5)
      d4 = logicview.idx(_lv_seq, 6)
      d5 = logicview.idx(_lv_seq, 7)
      d6 = logicview.idx(_lv_seq, 8)
      d7 = logicview.idx(_lv_seq, 9)
      a8 = logicview.idx(_lv_seq, 10)
      a9 = logicview.idx(_lv_seq, 11)
      a10 = logicview.idx(_lv_seq, 12)
      a11 = logicview.idx(_lv_seq, 13)
      a12 = logicview.idx(_lv_seq, 14)
    end
    data = { d0, d1, d2, d3, d4, d5, d6, d7 }
    addr = { a8, a9, a10, a11 }
    bank = { a12 }
    if logicview.truth(has_bank) then
      addr = logicview.add(addr, logicview.slice(bank, nil, bank_pin_count, nil))
    end
    if logicview.truth((self.matched & (1 << 0))) then
      self:newaddr(addr, data)
    end
    if logicview.truth((self.matched & (1 << 1))) then
      self:newdata(data)
    end
    ::continue_1::
  end
end

return _decoder
