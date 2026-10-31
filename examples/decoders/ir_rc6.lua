-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Benedikt Otto <benedikt_o@web.de>

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
  id = "ir_rc6",
  name = "IR RC-6",
  longname = "IR RC-6",
  desc = "RC-6 infrared remote control protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IR" },
  channels = { logicview.dict({ id = "ir", name = "IR", desc = "IR data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "auto", values = { "auto", "active-low", "active-high" } }) },
  annotations = { { "bit", "Bit" }, { "sync", "Sync" }, { "startbit", "Startbit" }, { "field", "Field" }, { "togglebit", "Togglebit" }, { "address", "Address" }, { "command", "Command" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.deltas = _lv_a1
    self.bits = _lv_a2
  end
  self.state = "IDLE"
  self.mode = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.halfbit = logicview.tointeger((logicview.mul(self.samplerate, 0.000889) / 2.0))
  end
end
function _decoder.putb(self, bit, data)
  self:put(logicview.idx(bit, 0), logicview.idx(bit, 1), self.out_ann, data)
end
function _decoder.putbits(self, bit1, bit2, data)
  self:put(logicview.idx(bit1, 0), logicview.idx(bit2, 1), self.out_ann, data)
end
function _decoder.putx(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.handle_bit(self)
  if logicview.truth((not logicview.eq(logicview.len(self.bits), 6))) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(self.bits, 0), 2), 8)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(self.bits, 0), 3), 1)
  return _v
end)()) then
    self:putb(logicview.idx(self.bits, 0), { 1, { "Synchronisation", "Sync" } })
  else
    return
  end
  if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.bits, 1), 3), 1)) then
    self:putb(logicview.idx(self.bits, 1), { 2, { "Startbit", "Start" } })
  else
    return
  end
  self.mode = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(3) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(2, i)), 3) << (2 - i))
  end
  return _lv_out
end)())
  self:putbits(logicview.idx(self.bits, 2), logicview.idx(self.bits, 4), { 3, { logicview.pymod("Field: %d", self.mode) } })
  self:putb(logicview.idx(self.bits, 5), { 4, { logicview.pymod("Toggle: %d", logicview.idx(logicview.idx(self.bits, 5), 3)) } })
end
function _decoder.handle_package(self)
  local value, num_data_bits
  if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(self.bits, 0), 3), 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(self.bits, 1), 3), 0)
  return _v
end)()) then
    return
  end
  if logicview.truth((logicview.len(self.bits) <= 6)) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.mode, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.bits), 22)
  return _v
end)()) then
    value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(8) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(6, i)), 3) << (7 - i))
  end
  return _lv_out
end)())
    self:putbits(logicview.idx(self.bits, 6), logicview.idx(self.bits, 13), { 5, { logicview.pymod("Address: %0.2X", value) } })
    value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(8) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(14, i)), 3) << (7 - i))
  end
  return _lv_out
end)())
    self:putbits(logicview.idx(self.bits, 14), logicview.idx(self.bits, 21), { 6, { logicview.pymod("Data: %0.2X", value) } })
    self.bits = {  }
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.mode, 6)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.bits) >= 15)
  return _v
end)()) then
    if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.bits, 6), 3), 0)) then
      value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(8) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(6, i)), 3) << (7 - i))
  end
  return _lv_out
end)())
      self:putbits(logicview.idx(self.bits, 6), logicview.idx(self.bits, 13), { 5, { logicview.pymod("Address: %0.2X", value) } })
      num_data_bits = (logicview.len(self.bits) - 14)
      value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(num_data_bits) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(14, i)), 3) << ((num_data_bits - 1) - i))
  end
  return _lv_out
end)())
      self:putbits(logicview.idx(self.bits, 14), logicview.idx(self.bits, (-1)), { 6, { logicview.pymod("Data: %X", value) } })
      self.bits = {  }
    elseif logicview.truth((logicview.len(self.bits) >= 23)) then
      value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(16) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(6, i)), 3) << (15 - i))
  end
  return _lv_out
end)())
      self:putbits(logicview.idx(self.bits, 6), logicview.idx(self.bits, 21), { 5, { logicview.pymod("Address: %0.2X", value) } })
      num_data_bits = (logicview.len(self.bits) - 22)
      value = logicview.sum((function()
  local _lv_out = {}
  for _lv_i in logicview.range(num_data_bits) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (logicview.idx(logicview.idx(self.bits, logicview.add(22, i)), 3) << ((num_data_bits - 1) - i))
  end
  return _lv_out
end)())
      self:putbits(logicview.idx(self.bits, 22), logicview.idx(self.bits, (-1)), { 6, { logicview.pymod("Data: %X", value) } })
      self.bits = {  }
    end
  end
end
function _decoder.decode(self)
  local value, num_edges, conditions, delta, total
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  value = 0
  num_edges = (-1)
  self.invert = false
  while true do
    conditions = { logicview.dict({ [0] = "e" }) }
    if logicview.truth(logicview.eq(self.state, "DATA")) then
      _table.insert(conditions, logicview.dict({ skip = logicview.mul(self.halfbit, 6) }))
    end
    do
      local _lv_seq = self:wait(conditions)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.ir = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth(logicview.eq(logicview.len(conditions), 2)) then
      if logicview.truth((self.matched & 2)) then
        self.state = "IDLE"
      end
    end
    _table.insert(self.edges, self.samplenum)
    if logicview.truth((logicview.len(self.edges) < 2)) then
      goto continue_1
    end
    delta = ((logicview.idx(self.edges, (-1)) - logicview.idx(self.edges, (-2))) / self.halfbit)
    delta = logicview.tointeger(logicview.add(delta, 0.5))
    _table.insert(self.deltas, delta)
    if logicview.truth((logicview.len(self.deltas) < 2)) then
      goto continue_1
    end
    if logicview.truth(logicview.eq(logicview.slice(self.deltas, (-2), nil, nil), { 6, 2 })) then
      self.state = "SYNC"
      num_edges = 0
      self.bits = {  }
      if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "auto")) then
        value = 1
      else
        value = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-high")) then return self.ir else return (1 - self.ir) end end)()
      end
      _table.insert(self.bits, { logicview.idx(self.edges, (-3)), logicview.idx(self.edges, (-1)), 8, value })
      self.invert = logicview.eq(self.ir, 0)
      self:putb(logicview.idx(self.bits, (-1)), { 0, { logicview.pymod("%d", value) } })
    end
    if logicview.truth(logicview.eq(logicview.pymod(num_edges, 2), 0)) then
      if logicview.truth((function()
  local _v
  _v = logicview.contains({ 1, 2, 3 }, logicview.idx(self.deltas, (-2)))
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ 1, 2, 3, 6 }, logicview.idx(self.deltas, (-1)))
  return _v
end)()) then
        self.state = "DATA"
        if logicview.truth((not logicview.eq(logicview.idx(self.deltas, (-2)), logicview.idx(self.deltas, (-1))))) then
          logicview.list_insert(self.edges, (-1), logicview.add(logicview.idx(self.edges, (-2)), logicview.mul(logicview.idx(self.deltas, (-2)), self.halfbit)))
          total = logicview.idx(self.deltas, (-1))
          logicview.setidx(self.deltas, (-1), logicview.idx(self.deltas, (-2)))
          _table.insert(self.deltas, (total - logicview.idx(self.deltas, (-1))))
          _table.insert(self.bits, { logicview.idx(self.edges, (-4)), logicview.idx(self.edges, (-2)), logicview.mul(logicview.idx(self.deltas, (-2)), 2), value })
          num_edges = logicview.add(num_edges, 1)
        else
          _table.insert(self.bits, { logicview.idx(self.edges, (-3)), logicview.idx(self.edges, (-1)), logicview.mul(logicview.idx(self.deltas, (-1)), 2), value })
        end
        self:putb(logicview.idx(self.bits, (-1)), { 0, { logicview.pymod("%d", value) } })
      end
    end
    if logicview.truth((logicview.len(self.bits) > 0)) then
      self:handle_bit()
      if logicview.truth(logicview.eq(self.state, "IDLE")) then
        self:handle_package()
      end
    end
    if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "auto")) then
      value = (function() if logicview.truth(self.invert) then return self.ir else return (1 - self.ir) end end)()
    else
      value = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return self.ir else return (1 - self.ir) end end)()
    end
    num_edges = logicview.add(num_edges, 1)
    ::continue_1::
  end
end

return _decoder
