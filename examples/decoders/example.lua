-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011 Gareth McMullin <gareth@blacksphere.co.nz>
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>
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
  id = "example",
  name = "Example",
  longname = "example-lala",
  desc = "This is an example of protocol",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "test" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "c1", name = "c1", desc = "chan1-input" }) },
  optional_channels = { logicview.dict({ id = "c2", name = "c2", desc = "chan2-input" }) },
  options = { logicview.dict({ id = "debug_bits", desc = "Print each bit", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "wordsize", desc = "Data wordsize (# bus cycles)", default = 0, values = {  } }) },
  annotations = { { "1", "data1", "test data1" }, { "2", "data2", "test data2" }, { "222", "data3", "test data3" } },
  annotation_rows = { { "lab1", "row1", { 0 } }, { "lab2", "row2", { 1, 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.count = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.put_ann(self, a, b, ann, data)
  self:put(a, b, self.out_ann, { ann, data })
end
function _decoder.decode(self)
  local times, rising_sample, flag_arr, flag_dex, edge, a, b, falling_sample, v, s, ann
  times = 0
  rising_sample = 0
  flag_arr = { logicview.dict({ [0] = "r" }), logicview.dict({ [0] = "f" }) }
  flag_dex = 0
  while true do
    edge = logicview.idx(flag_arr, flag_dex)
    do
      local _lv_seq = self:wait(edge)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      a = logicview.idx(_lv_seq, 0)
      b = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(flag_dex, 0)) then
      flag_dex = 1
      rising_sample = self.samplenum
    else
      flag_dex = 0
      times = logicview.add(times, 1)
      falling_sample = self.samplenum
      v = (falling_sample - rising_sample)
      s = logicview.pymod("%02X", v)
      ann = logicview.pymod(times, 2)
      self:put_ann(rising_sample, falling_sample, ann, { s })
    end
    ::continue_1::
  end
end

return _decoder
