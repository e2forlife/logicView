-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Uwe Hermann <uwe@hermann-uwe.de>

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
  id = "i2cdemux",
  name = "I²C demux",
  longname = "I²C demultiplexer",
  desc = "Demux I²C packets into per-slave-address streams.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Util" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = {  },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.packets = {  }
  self.slaves = {  }
  self.stream = (-1)
  self.streamcount = 0
end
function _decoder.start(self)
  self.out_python = {  }
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, p
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      databyte = logicview.idx(_lv_seq, 1)
    end
    _table.insert(self.packets, { ss, es, data })
    if logicview.truth(logicview.contains({ "ADDRESS READ", "ADDRESS WRITE" }, cmd)) then
      if logicview.truth(logicview.contains(self.slaves, databyte)) then
        self.stream = (function() if _type(self.slaves) == 'string' then local _n = logicview.find(self.slaves, databyte); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(self.slaves, databyte) end)()
        return
      end
      _table.insert(self.slaves, databyte)
      _table.insert(self.out_python, self:register(logicview.OUTPUT_PYTHON))
      self.stream = self.streamcount
      self.streamcount = logicview.add(self.streamcount, 1)
    elseif logicview.truth(logicview.eq(cmd, "STOP")) then
      if logicview.truth(logicview.eq(self.stream, (-1))) then
        _error(Exception("Invalid stream!"), 0)
      end
      for _lv_item in logicview.iter(self.packets) do
        p = _lv_item
        self:put(logicview.idx(p, 0), logicview.idx(p, 1), logicview.idx(self.out_python, self.stream), logicview.idx(p, 2))
        ::continue_1::
      end
      self.packets = {  }
      self.stream = (-1)
    else
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
