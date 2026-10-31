-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2012 Bert Vermeulen <bert@biot.com>
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
  id = "i2cfilter",
  name = "I²C filter",
  longname = "I²C filter",
  desc = "Filter out addresses/directions in an I²C stream.",
  license = "gplv3+",
  inputs = { "i2c" },
  outputs = { "i2c" },
  tags = { "Util" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "address", desc = "Address to filter out of the I²C stream", default = 0, values = {  } }), logicview.dict({ id = "direction", desc = "Direction to filter", default = "both", values = { "read", "write", "both" } }) },
  annotations = {  },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.curslave = (-1)
  self.curdirection = nil
  self.packets = {  }
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  if logicview.truth((not logicview.contains((function() local _t = {}; for _v in logicview.range(0, logicview.add(127, 1)) do _t[#_t + 1] = _v end; return _t end)(), logicview.idx(self.options, "address")))) then
    _error(Exception("Invalid slave (must be 0..127)."), 0)
  end
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
      self.curslave = databyte
      self.curdirection = _string.lower(logicview.slice(cmd, 8, nil, nil))
    elseif logicview.truth(logicview.contains({ "STOP", "START REPEAT" }, cmd)) then
      if logicview.truth(logicview.eq(logicview.idx(self.options, "address"), 0)) then
      elseif logicview.truth((not logicview.eq(self.curslave, logicview.idx(self.options, "address")))) then
        self.packets = {  }
        return
      end
      if logicview.truth(logicview.eq(logicview.idx(self.options, "direction"), "both")) then
      elseif logicview.truth((not logicview.eq(logicview.idx(self.options, "direction"), self.curdirection))) then
        self.packets = {  }
        return
      end
      for _lv_item in logicview.iter(self.packets) do
        p = _lv_item
        self:put(logicview.idx(p, 0), logicview.idx(p, 1), self.out_python, logicview.idx(p, 2))
        ::continue_1::
      end
      self.packets = {  }
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
