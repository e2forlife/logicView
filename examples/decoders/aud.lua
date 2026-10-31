-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 fenugrec <fenugrec users.sourceforge.net>
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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "aud",
  name = "AUD",
  longname = "Advanced User Debugger",
  desc = "Renesas/Hitachi Advanced User Debugger (AUD) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "audck", name = "AUDCK", desc = "AUD clock" }), logicview.dict({ id = "naudsync", name = "nAUDSYNC", desc = "AUD sync" }), logicview.dict({ id = "audata3", name = "AUDATA3", desc = "AUD data line 3" }), logicview.dict({ id = "audata2", name = "AUDATA2", desc = "AUD data line 2" }), logicview.dict({ id = "audata1", name = "AUDATA1", desc = "AUD data line 1" }), logicview.dict({ id = "audata0", name = "AUDATA0", desc = "AUD data line 0" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "dest", "Destination address" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.ncnt = 0
  self.nmax = 0
  self.addr = 0
  self.lastaddr = 0
  self.ss = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.samplenum, self.out_ann, data)
end
function _decoder.handle_clk_edge(self, clk, sync, datapins)
  local nib, i
  nib = 0
  for _lv_i in logicview.range(4) do
    i = _lv_i
    nib = (nib | (logicview.idx(datapins, (3 - i)) << i))
    ::continue_1::
  end
  if logicview.truth(logicview.eq(sync, 1)) then
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.ncnt, self.nmax)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.nmax, 0))
  return _v
end)()) then
      self:putx({ 0, { logicview.pymod("0x%08X", self.addr) } })
      self.lastaddr = self.addr
    end
    self.ncnt = 0
    self.addr = self.lastaddr
    self.ss = self.samplenum
    if logicview.truth(logicview.eq(nib, 8)) then
      self.nmax = 1
    elseif logicview.truth(logicview.eq(nib, 9)) then
      self.nmax = 2
    elseif logicview.truth(logicview.eq(nib, 10)) then
      self.nmax = 4
    elseif logicview.truth(logicview.eq(nib, 11)) then
      self.nmax = 8
    else
      self.nmax = 0
    end
  elseif logicview.truth((self.nmax > 0)) then
    self.addr = (self.addr & (~(15 << logicview.mul(self.ncnt, 4))))
    self.addr = (self.addr | (nib << logicview.mul(self.ncnt, 4)))
    self.ncnt = logicview.add(self.ncnt, 1)
  end
end
function _decoder.decode(self)
  local clk, sync, d3, d2, d1, d0, d
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      sync = logicview.idx(_lv_seq, 1)
      d3 = logicview.idx(_lv_seq, 2)
      d2 = logicview.idx(_lv_seq, 3)
      d1 = logicview.idx(_lv_seq, 4)
      d0 = logicview.idx(_lv_seq, 5)
    end
    d = { d3, d2, d1, d0 }
    self:handle_clk_edge(clk, sync, d)
    ::continue_2::
  end
end

return _decoder
