-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Steve R <steversig@virginmedia.com>

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
local bitvals, decode_bit, pinlabels, decode_model, Decoder
local _decoder

bitvals = { "0", "1", "f", "U" }
decode_bit = function(edges)
  local lmin, lmax, eqmin, eqmax
  lmin = 2
  lmax = 5
  eqmin = 0.5
  eqmax = 1.5
  if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 1) >= logicview.mul(logicview.idx(edges, 0), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 1) <= logicview.mul(logicview.idx(edges, 0), lmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 2) >= logicview.mul(logicview.idx(edges, 0), eqmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 2) <= logicview.mul(logicview.idx(edges, 0), eqmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 3) >= logicview.mul(logicview.idx(edges, 0), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 3) <= logicview.mul(logicview.idx(edges, 0), lmax))
  return _v
end)()
  return _v
end)()) then
    return "0"
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 0) >= logicview.mul(logicview.idx(edges, 1), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 0) <= logicview.mul(logicview.idx(edges, 1), lmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 0) >= logicview.mul(logicview.idx(edges, 2), eqmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 0) <= logicview.mul(logicview.idx(edges, 2), eqmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 0) >= logicview.mul(logicview.idx(edges, 3), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 0) <= logicview.mul(logicview.idx(edges, 3), lmax))
  return _v
end)()
  return _v
end)()) then
    return "1"
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 1) >= logicview.mul(logicview.idx(edges, 0), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 1) <= logicview.mul(logicview.idx(edges, 0), lmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 2) >= logicview.mul(logicview.idx(edges, 0), lmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 2) <= logicview.mul(logicview.idx(edges, 0), lmax))
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (logicview.idx(edges, 3) >= logicview.mul(logicview.idx(edges, 0), eqmin))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(edges, 3) <= logicview.mul(logicview.idx(edges, 0), eqmax))
  return _v
end)()
  return _v
end)()) then
    return "f"
  else
    return "U"
  end
end
pinlabels = function(bit_count)
  if logicview.truth((bit_count <= 6)) then
    return logicview.pymod("A%i", (bit_count - 1))
  else
    return logicview.pymod("A%i/D%i", { (bit_count - 1), (12 - bit_count) })
  end
end
decode_model = function(model, bits)
  local address, i, button
  if logicview.truth(logicview.eq(model, "maplin_l95ar")) then
    address = "Addr"
    for _lv_i in logicview.range(0, 6) do
      i = _lv_i
      address = logicview.add(address, logicview.add(logicview.pymod(" %i:", logicview.add(i, 1)), (function() if logicview.truth(logicview.eq(logicview.idx(logicview.idx(bits, i), 0), "0")) then return "on" else return "off" end end)()))
      ::continue_1::
    end
    button = "Button"
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 6), 0), "0")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 11), 0), "0")
  return _v
end)()) then
      button = logicview.add(button, " A ON/OFF")
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 7), 0), "0")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 11), 0), "0")
  return _v
end)()) then
      button = logicview.add(button, " B ON/OFF")
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 9), 0), "0")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 11), 0), "0")
  return _v
end)()) then
      button = logicview.add(button, " C ON/OFF")
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 8), 0), "0")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(bits, 11), 0), "0")
  return _v
end)()) then
      button = logicview.add(button, " D ON/OFF")
    else
      button = logicview.add(button, " Unknown")
    end
    return { logicview.pymod("%s", address), logicview.idx(logicview.idx(bits, 0), 1), logicview.idx(logicview.idx(bits, 5), 2), logicview.pymod("%s", button), logicview.idx(logicview.idx(bits, 6), 1), logicview.idx(logicview.idx(bits, 11), 2) }
  end
end
_decoder = {
  api_version = 3,
  id = "rc_encode",
  name = "RC encode",
  longname = "Remote control encoder",
  desc = "PT2262/HX2262/SC5262 remote control encoder protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "IR" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "remote", desc = "Remote", default = "none", values = { "none", "maplin_l95ar" } }) },
  annotations = { { "bit-0", "Bit 0" }, { "bit-1", "Bit 1" }, { "bit-f", "Bit f" }, { "bit-U", "Bit U" }, { "bit-sync", "Bit sync" }, { "pin", "Pin" }, { "code-word-addr", "Code word address" }, { "code-word-data", "Code word data" } },
  annotation_rows = { { "bits", "Bits", { 0, 1, 2, 3, 4 } }, { "pins", "Pins", { 5 } }, { "code-words", "Code words", { 6, 7 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplenumber_last = nil
  self.pulses = {  }
  self.bits = {  }
  self.labels = {  }
  self.bit_count = 0
  self.ss = nil
  self.es = nil
  self.state = "IDLE"
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.model = logicview.idx(self.options, "remote")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self)
  local i, samples, idx
  while true do
    self:wait(logicview.dict({ [0] = "e" }))
    self.state = "DECODING"
    if logicview.truth((not logicview.truth(self.samplenumber_last))) then
      self.samplenumber_last = self.samplenum
      self.ss = self.samplenum
      goto continue_2
    end
    if logicview.truth((self.bit_count < 12)) then
      self.bit_count = logicview.add(self.bit_count, 1)
      for _lv_i in logicview.range(0, 4) do
        i = _lv_i
        if logicview.truth((i > 0)) then
          self:wait(logicview.dict({ [0] = "e" }))
        end
        samples = (self.samplenum - self.samplenumber_last)
        _table.insert(self.pulses, samples)
        self.samplenumber_last = self.samplenum
        ::continue_3::
      end
      self.es = self.samplenum
      _table.insert(self.bits, { decode_bit(self.pulses), self.ss, self.es })
      idx = (function() if _type(bitvals) == 'string' then local _n = logicview.find(bitvals, decode_bit(self.pulses)); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(bitvals, decode_bit(self.pulses)) end)()
      self:putx({ idx, { decode_bit(self.pulses) } })
      self:putx({ 5, { pinlabels(self.bit_count) } })
      self.pulses = {  }
      self.ss = self.samplenum
    else
      if logicview.truth((not logicview.eq(self.model, "none"))) then
        self.labels = decode_model(self.model, self.bits)
        self:put(logicview.idx(self.labels, 1), logicview.idx(self.labels, 2), self.out_ann, { 6, { logicview.idx(self.labels, 0) } })
        self:put(logicview.idx(self.labels, 4), logicview.idx(self.labels, 5), self.out_ann, { 7, { logicview.idx(self.labels, 3) } })
      end
      samples = (self.samplenum - self.samplenumber_last)
      self:wait(logicview.dict({ skip = logicview.mul(8, samples) }))
      self.es = self.samplenum
      self:putx({ 4, { "Sync" } })
      self:reset()
      self.state = "DECODE_TIMEOUT"
    end
    if logicview.truth((not logicview.truth(logicview.eq(self.state, "DECODE_TIMEOUT")))) then
      self.samplenumber_last = self.samplenum
    end
    ::continue_2::
  end
end

return _decoder
