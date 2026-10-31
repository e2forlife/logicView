-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Max Weller
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
local re, ann_cmdbit, ann_databit, ann_cmd, ann_data, ann_warning, Decoder
local _decoder

re = logicview.re
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(5) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_cmdbit = logicview.idx(_lv_seq, 0)
  ann_databit = logicview.idx(_lv_seq, 1)
  ann_cmd = logicview.idx(_lv_seq, 2)
  ann_data = logicview.idx(_lv_seq, 3)
  ann_warning = logicview.idx(_lv_seq, 4)
end
_decoder = {
  api_version = 3,
  id = "sda2506",
  name = "SDA2506",
  longname = "Siemens SDA 2506-5",
  desc = "Serial nonvolatile 1-Kbit EEPROM.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "d", name = "DATA", desc = "Data" }), logicview.dict({ id = "ce", name = "CE#", desc = "Chip-enable" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "cmdbit", "Command bit" }, { "databit", "Data bit" }, { "cmd", "Command" }, { "data", "Data byte" }, { "warnings", "Human-readable warnings" } },
  annotation_rows = { { "bits", "Bits", { 0, 1 } }, { "commands", "Commands", { 2 } }, { "data", "Data", { 3 } }, { "warnings", "Warnings", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self.samplerate = nil
  self:reset()
end
function _decoder.reset(self)
  self.cmdbits = {  }
  self.databits = {  }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putbit(self, ss, es, typ, value)
  self:put(ss, es, self.out_ann, { typ, { logicview.pymod("%s", value) } })
end
function _decoder.putdata(self, ss, es)
  local value, i
  value = 0
  for _lv_i in logicview.range(8) do
    i = _lv_i
    value = ((value << 1) | logicview.idx(self.databits, i))
    ::continue_1::
  end
  self:put(ss, es, self.out_ann, { ann_data, { logicview.pymod("%02X", value) } })
end
function _decoder.decode_bits(self, offset, width)
  local out, i
  out = 0
  for _lv_i in logicview.range(width) do
    i = _lv_i
    out = ((out << 1) | logicview.idx(logicview.idx(self.cmdbits, logicview.add(offset, i)), 0))
    ::continue_2::
  end
  return { out, logicview.idx(logicview.idx(self.cmdbits, (logicview.add(offset, width) - 1)), 1), logicview.idx(logicview.idx(self.cmdbits, offset), 2) }
end
function _decoder.decode_field(self, name, offset, width)
  local val, ss, es
  do
    local _lv_seq = self:decode_bits(offset, width)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    val = logicview.idx(_lv_seq, 0)
    ss = logicview.idx(_lv_seq, 1)
    es = logicview.idx(_lv_seq, 2)
  end
  self:put(ss, es, self.out_ann, { ann_data, { logicview.pymod("%s: %02X", { name, val }) } })
  return val
end
function _decoder.decode(self)
  local clk, d, ce, bitstart, addr, ss, es, data, cmdstart, val, ex
  while true do
    do
      local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ [2] = "e" }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      d = logicview.idx(_lv_seq, 1)
      ce = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ce, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 1)
  return _v
end)()) then
      bitstart = self.samplenum
      self:wait(logicview.dict({ [0] = "f" }))
      self.cmdbits = logicview.add({ { d, bitstart, self.samplenum } }, self.cmdbits)
      if logicview.truth((logicview.len(self.cmdbits) > 24)) then
        self.cmdbits = logicview.slice(self.cmdbits, 0, 24, nil)
      end
      self:putbit(bitstart, self.samplenum, ann_cmdbit, d)
    elseif logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 0))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ce, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(clk, 0)
  return _v
end)()) then
      bitstart = self.samplenum
      do
        local _lv_seq = self:wait({ logicview.dict({ skip = logicview.tointeger(logicview.mul(2.5, (1000000.0 / self.samplerate))) }), logicview.dict({ [0] = "r" }), logicview.dict({ [2] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        clk = logicview.idx(_lv_seq, 0)
        d = logicview.idx(_lv_seq, 1)
        ce = logicview.idx(_lv_seq, 2)
      end
      if logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 2))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & 3)))
  return _v
end)()) then
        self:wait({ logicview.dict({ [0] = "r" }), logicview.dict({ [2] = "e" }) })
      end
      if logicview.truth(logicview.eq(logicview.len(self.databits), 0)) then
        self.datastart = bitstart
      end
      self.databits = logicview.add({ d }, self.databits)
      self:putbit(bitstart, self.samplenum, ann_databit, d)
      if logicview.truth(logicview.eq(logicview.len(self.databits), 8)) then
        self:putdata(self.datastart, self.samplenum)
        self.databits = {  }
      end
    elseif logicview.truth((function()
  local _v
  _v = (self.matched & (1 << 1))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(ce, 0)
  return _v
end)()) then
      do
        local _lv_return = false
        local _lv_value = nil
        local _ok, _err = _pcall(function()
          self:decode_field("addr", 1, 7)
          self:decode_field("CB", 0, 1)
          if logicview.truth(logicview.eq(logicview.idx(logicview.idx(self.cmdbits, 0), 0), 0)) then
            self:decode_field("read", 1, 7)
            self:put(logicview.idx(logicview.idx(self.cmdbits, 7), 1), self.samplenum, self.out_ann, { ann_cmd, { "read" } })
          elseif logicview.truth(logicview.eq(d, 0)) then
            self:decode_field("data", 8, 8)
            do
              local _lv_seq = self:decode_bits(1, 7)
              if _type(_lv_seq) == 'function' then
                local _lv_built = {}
                for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
                _lv_seq = _lv_built
              end
              addr = logicview.idx(_lv_seq, 0)
              ss = logicview.idx(_lv_seq, 1)
              es = logicview.idx(_lv_seq, 2)
            end
            do
              local _lv_seq = self:decode_bits(8, 8)
              if _type(_lv_seq) == 'function' then
                local _lv_built = {}
                for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
                _lv_seq = _lv_built
              end
              data = logicview.idx(_lv_seq, 0)
              ss = logicview.idx(_lv_seq, 1)
              es = logicview.idx(_lv_seq, 2)
            end
            cmdstart = self.samplenum
            self:wait(logicview.dict({ [2] = "r" }))
            self:put(cmdstart, self.samplenum, self.out_ann, { ann_cmd, { logicview.pymod("Write to %02X: %02X", { addr, data }) } })
          else
            do
              local _lv_seq = self:decode_bits(1, 7)
              if _type(_lv_seq) == 'function' then
                local _lv_built = {}
                for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
                _lv_seq = _lv_built
              end
              val = logicview.idx(_lv_seq, 0)
              ss = logicview.idx(_lv_seq, 1)
              es = logicview.idx(_lv_seq, 2)
            end
            cmdstart = self.samplenum
            self:wait(logicview.dict({ [2] = "r" }))
            self:put(cmdstart, self.samplenum, self.out_ann, { ann_cmd, { logicview.pymod("Erase: %02X", val) } })
          end
          self.databits = {  }
        end)
        if _lv_return then return _lv_value end
        if not _ok then
          if true then
            ex = _err
            self:reset()
          end
        end
      end
    end
    ::continue_3::
  end
end

return _decoder
