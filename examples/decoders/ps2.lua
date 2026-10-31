-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Daniel Schulte <trilader@schroedingers-bit.net>
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
local namedtuple, Ann, Bit, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIT = logicview.idx(_lv_seq, 0)
  Ann.HSTART = logicview.idx(_lv_seq, 1)
  Ann.DSTART = logicview.idx(_lv_seq, 2)
  Ann.STOP = logicview.idx(_lv_seq, 3)
  Ann.PARITY_OK = logicview.idx(_lv_seq, 4)
  Ann.PARITY_ERR = logicview.idx(_lv_seq, 5)
  Ann.DATA = logicview.idx(_lv_seq, 6)
  Ann.WORD = logicview.idx(_lv_seq, 7)
  Ann.ACK = logicview.idx(_lv_seq, 8)
end
Bit = (function() local _f = "val ss es"; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
_decoder = {
  api_version = 3,
  id = "ps2",
  name = "PS/2",
  longname = "PS/2",
  desc = "PS/2 keyboard/mouse interface.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PC" },
  channels = { logicview.dict({ id = "clk", name = "Clock", desc = "Clock line" }), logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "HtoD_Clock", desc = "HtoD_Clock", default = "rise", values = { "rise", "fall" } }), logicview.dict({ id = "DtoH_Clock", desc = "DtoH_Clock", default = "fall", values = { "fall", "rise" } }) },
  annotations = { { "207", "bit", "Bit" }, { "109", "HSTART", "HSTART" }, { "50", "DSTART", "DSTART" }, { "1000", "stop-bit", "Stop bit" }, { "7", "parity-ok", "Parity OK bit" }, { "1000", "parity-err", "Parity error bit" }, { "40", "data-bit", "Data bit" }, { "65", "word", "Word" }, { "75", "ACK", "ACK" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6, 7, 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bits = {  }
  self.samplenum = 0
  self.bitcount = 0
  self.state = "NULL"
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  self.HtoDss = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.HtoD = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "HtoD_Clock"), "rise")) then return 1 else return 0 end end)()
  self.DtoH = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "DtoH_Clock"), "fall")) then return 1 else return 0 end end)()
end
function _decoder.putb(self, bit, ann_idx)
  local b
  b = logicview.idx(self.bits, bit)
  self:put(b.ss, b.es, self.out_ann, { ann_idx, { _tostring(b.val) } })
end
function _decoder.putx(self, bit, ann)
  self:put(logicview.idx(self.bits, bit).ss, logicview.idx(self.bits, bit).es, self.out_ann, ann)
end
function _decoder.handle_bits(self, datapin)
  local clock_pin, b, word, i, parity_ok
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.bitcount, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(datapin, 1)
  return _v
end)()) then
    self.state = "HtoD"
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clock_pin = logicview.idx(_lv_seq, 0)
      datapin = logicview.idx(_lv_seq, 1)
    end
  end
  _table.insert(self.bits, Bit(datapin, self.samplenum, self.samplenum))
  if logicview.truth((self.bitcount > 0)) then
    b = logicview.idx(self.bits, (self.bitcount - 1))
    logicview.setidx(self.bits, (self.bitcount - 1), Bit(b.val, b.ss, self.samplenum))
  end
  if logicview.truth(logicview.eq(self.bitcount, 11)) then
    self.bitwidth = (logicview.idx(self.bits, 1).es - logicview.idx(self.bits, 2).es)
    b = logicview.idx(self.bits, (-1))
    logicview.setidx(self.bits, (-1), Bit(b.val, b.ss, logicview.add(b.es, self.bitwidth)))
  end
  if logicview.truth((self.bitcount < 11)) then
    self.bitcount = logicview.add(self.bitcount, 1)
    return
  end
  word = 0
  for _lv_i in logicview.range(8) do
    i = _lv_i
    word = (word | (logicview.idx(self.bits, logicview.add(i, 1)).val << i))
    ::continue_1::
  end
  parity_ok = logicview.eq(logicview.pymod(logicview.add(logicview.count(logicview.bin(word), "1"), logicview.idx(self.bits, 9).val), 2), 1)
  for _lv_i in logicview.range(11) do
    i = _lv_i
    self:putb(i, Ann.BIT)
    ::continue_2::
  end
  if logicview.truth(logicview.eq(self.state, "HtoD")) then
    self:putx(0, { Ann.HSTART, { "Host Start", "HStart", "HS" } })
  end
  if logicview.truth(logicview.eq(self.state, "DtoH")) then
    self:putx(0, { Ann.DSTART, { "Device Start", "Device", "DS" } })
  end
  self:put(logicview.idx(self.bits, 1).ss, logicview.idx(self.bits, 8).es, self.out_ann, { Ann.WORD, { logicview.pymod("Data: %02x", word), logicview.pymod("D: %02x", word), logicview.pymod("%02x", word) } })
  if logicview.truth(parity_ok) then
    self:putx(9, { Ann.PARITY_OK, { "Parity OK", "Par OK", "P" } })
  else
    self:putx(9, { Ann.PARITY_ERR, { "Parity error", "Par err", "PE" } })
  end
  self:putx(10, { Ann.STOP, { "Stop bit", "Stop", "St", "T" } })
  do
    local _lv_a0, _lv_a1 = {  }, 0
    self.bits = _lv_a0
    self.bitcount = _lv_a1
  end
  logicview.eq(self.state, "NULL")
end
function _decoder.decode(self)
  local clock_pin, data_pin
  while true do
    if logicview.truth(logicview.eq(self.bitcount, 0)) then
      if logicview.truth(self.HtoDss) then
        self.state = "HtoD"
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "r", [1] = "l" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        self:handle_bits(data_pin)
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
      else
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "f", [1] = "r" }), logicview.dict({ [0] = "f", [1] = "f" }), logicview.dict({ [0] = "f", [1] = "h" }), logicview.dict({ [0] = "f", [1] = "l" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth((self.matched & (1 << 0))) then
          goto continue_3
        end
        if logicview.truth((self.matched & (1 << 1))) then
          self.state = "HtoD"
          do
            local _lv_seq = self:wait(logicview.dict({ [0] = "r", [1] = "l" }))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            clock_pin = logicview.idx(_lv_seq, 0)
            data_pin = logicview.idx(_lv_seq, 1)
          end
          self:handle_bits(data_pin)
          do
            local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            clock_pin = logicview.idx(_lv_seq, 0)
            data_pin = logicview.idx(_lv_seq, 1)
          end
        end
        if logicview.truth((self.matched & (1 << 2))) then
          self.state = "HtoD"
          do
            local _lv_seq = self:wait(logicview.dict({ [0] = "r", [1] = "l" }))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            clock_pin = logicview.idx(_lv_seq, 0)
            data_pin = logicview.idx(_lv_seq, 1)
          end
          self:handle_bits(data_pin)
          do
            local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            clock_pin = logicview.idx(_lv_seq, 0)
            data_pin = logicview.idx(_lv_seq, 1)
          end
        end
        if logicview.truth((self.matched & (1 << 3))) then
          self.state = "DtoH"
          self:handle_bits(data_pin)
        end
      end
    end
    if logicview.truth(logicview.eq(self.state, "HtoD")) then
      if logicview.truth(self.HtoD) then
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
      else
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
      end
      self:handle_bits(data_pin)
      if logicview.truth(logicview.eq(self.bitcount, 10)) then
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        self:handle_bits(data_pin)
      end
      if logicview.truth(logicview.eq(self.bitcount, 11)) then
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        self:handle_bits(data_pin)
        self.ss = self.samplenum
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        self.es = self.samplenum
        self:put(self.ss, self.es, self.out_ann, { Ann.ACK, { "ACK", "ACK", "ACK", "A" } })
        self.HtoDss = 0
      end
    end
    if logicview.truth(logicview.eq(self.state, "DtoH")) then
      if logicview.truth(self.DtoH) then
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
      else
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
      end
      self:handle_bits(data_pin)
      if logicview.truth(logicview.eq(self.bitcount, 11)) then
        do
          local _lv_seq = self:wait({ logicview.dict({ [1] = "f" }), logicview.dict({ [0] = "r" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          clock_pin = logicview.idx(_lv_seq, 0)
          data_pin = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth((self.matched & (1 << 0))) then
          self:handle_bits(data_pin)
          self.HtoDss = 1
        end
        if logicview.truth((self.matched & (1 << 1))) then
          self:handle_bits(data_pin)
          self.HtoDss = 0
        end
      end
    end
    ::continue_3::
  end
end

return _decoder
