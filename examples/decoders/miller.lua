-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Christoph Rackwitz <christoph.rackwitz@rwth-aachen.de>

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
local roundto, Decoder
local _decoder

roundto = function(x, k)
  if k == nil then k = 1.0 end
  return logicview.mul((function() local _n = (x / k); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)(), k)
end
_decoder = {
  api_version = 3,
  id = "miller",
  name = "Miller",
  longname = "Miller encoding",
  desc = "Miller encoding protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Encoding" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data signal" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "baudrate", desc = "Baud rate", default = 106000, values = {  } }), logicview.dict({ id = "edge", desc = "Edge", default = "falling", values = { "rising", "falling", "either" } }) },
  annotations = { { "bit", "Bit" }, { "bitstring", "Bitstring" } },
  annotation_rows = { { "bit", "Bit", { 0 } }, { "bitstring", "Bitstring", { 1 } } },
  binary = { { "raw", "Raw binary" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.decode_bits(self)
  return logicview.generator(function()
    local timeunit, edgetype, prevedge, prevbit, expectedstart, got_timeout, sampledelta, timedelta
    timeunit = (self.samplerate / logicview.idx(self.options, "baudrate"))
    edgetype = logicview.idx(logicview.idx(self.options, "edge"), 0)
    self:wait(logicview.dict({ [0] = edgetype }))
    prevedge = self.samplenum
    prevbit = 0
    _coroutine.yield({ 0, prevedge, logicview.add(prevedge, timeunit) })
    expectedstart = logicview.add(self.samplenum, timeunit)
    while true do
      self:wait({ logicview.dict({ [0] = edgetype }), logicview.dict({ skip = logicview.tointeger(logicview.mul(3, timeunit)) }) })
      got_timeout = (self.matched & (1 << 1))
      sampledelta = (self.samplenum - prevedge)
      prevedge = self.samplenum
      timedelta = roundto((sampledelta / timeunit), 0.5)
      if logicview.truth(logicview.eq(prevbit, 0)) then
        if logicview.truth(logicview.eq(timedelta, 1.0)) then
          _coroutine.yield({ 0, self.samplenum, logicview.add(self.samplenum, timeunit) })
          prevbit = 0
          expectedstart = logicview.add(self.samplenum, timeunit)
        elseif logicview.truth(logicview.eq(timedelta, 1.5)) then
          _coroutine.yield({ 1, expectedstart, logicview.add(self.samplenum, logicview.mul(0.5, timeunit)) })
          prevbit = 1
          expectedstart = logicview.add(self.samplenum, logicview.mul(timeunit, 0.5))
        elseif logicview.truth((timedelta >= 2.0)) then
          _coroutine.yield(nil)
        else
          _coroutine.yield({ false, (self.samplenum - sampledelta), self.samplenum })
          break
        end
      else
        if logicview.truth((timedelta <= 0.5)) then
          _coroutine.yield({ false, (self.samplenum - sampledelta), self.samplenum })
          break
        end
        if logicview.truth(logicview.eq(timedelta, 1.0)) then
          _coroutine.yield({ 1, expectedstart, logicview.add(self.samplenum, logicview.mul(0.5, timeunit)) })
          prevbit = 1
          expectedstart = logicview.add(self.samplenum, logicview.mul(0.5, timeunit))
        elseif logicview.truth(logicview.eq(timedelta, 1.5)) then
          _coroutine.yield({ 0, expectedstart, self.samplenum })
          _coroutine.yield({ 0, self.samplenum, logicview.add(self.samplenum, timeunit) })
          prevbit = 0
          expectedstart = logicview.add(self.samplenum, timeunit)
        elseif logicview.truth(logicview.eq(timedelta, 2.0)) then
          _coroutine.yield({ 0, expectedstart, logicview.add(expectedstart, timeunit) })
          _coroutine.yield({ 1, (self.samplenum - logicview.mul(0.5, timeunit)), logicview.add(self.samplenum, logicview.mul(0.5, timeunit)) })
          prevbit = 1
          expectedstart = logicview.add(self.samplenum, logicview.mul(timeunit, 0.5))
        else
          _coroutine.yield({ 0, expectedstart, logicview.add(expectedstart, timeunit) })
          _coroutine.yield(nil)
          break
        end
      end
      ::continue_1::
    end
  end)
end
function _decoder.decode_run(self)
  local numbits, bitvalue, bitstring, stringstart, stringend, bit, value, ss, es, numbytes, bytestring
  numbits = 0
  bitvalue = 0
  bitstring = ""
  stringstart = nil
  stringend = nil
  for _lv_item in logicview.iter(self:decode_bits()) do
    bit = _lv_item
    if logicview.truth((bit == nil)) then
      break
    end
    do
      local _lv_seq = bit
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      value = logicview.idx(_lv_seq, 0)
      ss = logicview.idx(_lv_seq, 1)
      es = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(_rawequal(value, false)) then
      self:put(logicview.tointeger(ss), logicview.tointeger(es), self.out_ann, { 1, { "ERROR" } })
    else
      self:put(logicview.tointeger(ss), logicview.tointeger(es), self.out_ann, { 0, { logicview.pyformat("{}", { value }, logicview.dict({})) } })
    end
    if logicview.truth(_rawequal(value, false)) then
      numbits = 0
      break
    end
    if logicview.truth((stringstart == nil)) then
      stringstart = ss
    end
    stringend = es
    bitvalue = (bitvalue | (value << numbits))
    numbits = logicview.add(numbits, 1)
    bitstring = logicview.add(bitstring, logicview.pyformat("{}", { value }, logicview.dict({})))
    if logicview.truth(logicview.eq(logicview.pymod(numbits, 4), 0)) then
      bitstring = logicview.add(bitstring, " ")
    end
    ::continue_2::
  end
  if logicview.truth((not logicview.truth(numbits))) then
    return
  end
  self:put(logicview.tointeger(stringstart), logicview.tointeger(stringend), self.out_ann, { 1, { logicview.pyformat("{}", { bitstring }, logicview.dict({})) } })
  numbytes = logicview.add(logicview.floordiv(numbits, 8), (logicview.pymod(numbits, 8) > 0))
  bytestring = logicview.to_bytes(bitvalue, numbytes, "little")
  self:put(logicview.tointeger(stringstart), logicview.tointeger(stringend), self.out_binary, { 0, bytestring })
end
function _decoder.decode(self)
  while true do
    self:decode_run()
    ::continue_3::
  end
end

return _decoder
