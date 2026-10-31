-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Kevin Redon <kingkevin@cuvoodoo.info>
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
local namedtuple, PyPacket, Packet, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
PyPacket = (function() local _f = "ss es si so"; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
Packet = (function() local _f = "samplenum matched cs sk si so"; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
_decoder = {
  api_version = 3,
  id = "microwire",
  name = "Microwire",
  longname = "Microwire",
  desc = "3-wire, half-duplex, synchronous serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "microwire" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "cs", name = "CS", desc = "Chip select" }), logicview.dict({ id = "sk", name = "SK", desc = "Clock" }), logicview.dict({ id = "si", name = "SI", desc = "Slave in" }), logicview.dict({ id = "so", name = "SO", desc = "Slave out" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "start-bit", "Start bit" }, { "si-bit", "SI bit" }, { "so-bit", "SO bit" }, { "status-check-ready", "Status check ready" }, { "status-check-busy", "Status check busy" }, { "warning", "Warning" } },
  annotation_rows = { { "si-bits", "SI bits", { 0, 1 } }, { "so-bits", "SO bits", { 2 } }, { "status", "Status", { 3, 4 } }, { "warnings", "Warnings", { 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self)
  local cs, sk, si, so, packet, edge, status_check, change, start_samplenum, bit_so, bit_start, bit_si, start_bit, pydata
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cs = logicview.idx(_lv_seq, 0)
      sk = logicview.idx(_lv_seq, 1)
      si = logicview.idx(_lv_seq, 2)
      so = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth(sk) then
      self:put(self.samplenum, self.samplenum, self.out_ann, { 5, { "Clock should be low on start", "Clock high on start", "Clock high", "SK high" } })
      sk = 0
    end
    packet = {  }
    while logicview.truth(cs) do
      _table.insert(packet, Packet(self.samplenum, self.matched, cs, sk, si, so))
      edge = (function() if logicview.truth(logicview.eq(sk, 0)) then return "r" else return "f" end end)()
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "l" }), logicview.dict({ [1] = edge }), logicview.dict({ [3] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cs = logicview.idx(_lv_seq, 0)
        sk = logicview.idx(_lv_seq, 1)
        si = logicview.idx(_lv_seq, 2)
        so = logicview.idx(_lv_seq, 3)
      end
      ::continue_2::
    end
    _table.insert(packet, Packet(self.samplenum, self.matched, cs, sk, si, so))
    status_check = true
    for _lv_item in logicview.iter(packet) do
      change = _lv_item
      if logicview.truth((function()
  local _v
  _v = (change.matched & (1 << 1))
  if not logicview.truth(_v) then return _v end
  _v = change.sk
  return _v
end)()) then
        if logicview.truth(change.si) then
          status_check = false
        end
        break
      end
      ::continue_3::
    end
    if logicview.truth(status_check) then
      start_samplenum = logicview.idx(packet, 0).samplenum
      bit_so = logicview.idx(packet, 0).so
      for _lv_item in logicview.iter(packet) do
        change = _lv_item
        if logicview.truth((change.matched & (1 << 2))) then
          if logicview.truth((function()
  local _v
  _v = logicview.eq(bit_so, 0)
  if not logicview.truth(_v) then return _v end
  _v = change.so
  return _v
end)()) then
            self:put(start_samplenum, change.samplenum, self.out_ann, { 4, { "Busy", "B" } })
          end
          start_samplenum = change.samplenum
          bit_so = change.so
        end
        ::continue_4::
      end
      if logicview.truth(logicview.eq(bit_so, 0)) then
        self:put(start_samplenum, logicview.idx(packet, (-1)).samplenum, self.out_ann, { 4, { "Busy", "B" } })
      else
        self:put(start_samplenum, logicview.idx(packet, (-1)).samplenum, self.out_ann, { 3, { "Ready", "R" } })
      end
    else
      bit_start = 0
      bit_si = 0
      bit_so = 0
      start_bit = true
      pydata = {  }
      for _lv_item in logicview.iter(packet) do
        change = _lv_item
        if logicview.truth((change.matched & (1 << 1))) then
          if logicview.truth(change.sk) then
            if logicview.truth((bit_start > 0)) then
              if logicview.truth(start_bit) then
                if logicview.truth(logicview.eq(bit_si, 0)) then
                  self:put(bit_start, change.samplenum, self.out_ann, { 5, { "Start bit not high", "Start bit low" } })
                else
                  self:put(bit_start, change.samplenum, self.out_ann, { 0, { "Start bit", "S" } })
                end
                start_bit = false
              else
                self:put(bit_start, change.samplenum, self.out_ann, { 1, { logicview.pymod("SI bit: %d", bit_si), logicview.pymod("SI: %d", bit_si), logicview.pymod("%d", bit_si) } })
                self:put(bit_start, change.samplenum, self.out_ann, { 2, { logicview.pymod("SO bit: %d", bit_so), logicview.pymod("SO: %d", bit_so), logicview.pymod("%d", bit_so) } })
                _table.insert(pydata, PyPacket(bit_start, change.samplenum, bit_si, bit_so))
              end
            end
            bit_start = change.samplenum
            bit_si = change.si
          else
            bit_so = change.so
          end
        elseif logicview.truth((function()
  local _v
  _v = (change.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(change.cs, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(change.sk, 0)
  return _v
end)()) then
          self:put(bit_start, change.samplenum, self.out_ann, { 1, { logicview.pymod("SI bit: %d", bit_si), logicview.pymod("SI: %d", bit_si), logicview.pymod("%d", bit_si) } })
          self:put(bit_start, change.samplenum, self.out_ann, { 2, { logicview.pymod("SO bit: %d", bit_so), logicview.pymod("SO: %d", bit_so), logicview.pymod("%d", bit_so) } })
          _table.insert(pydata, PyPacket(bit_start, change.samplenum, bit_si, bit_so))
        end
        ::continue_5::
      end
      self:put(logicview.idx(packet, 0).samplenum, logicview.idx(packet, (logicview.len(packet) - 1)).samplenum, self.out_python, pydata)
    end
    ::continue_1::
  end
end

return _decoder
