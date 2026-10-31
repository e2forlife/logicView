-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2010-2016 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2023 DreamSourceLab <support@dreamsourcelab.com>

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
local proto, Decoder
local _decoder

proto = logicview.dict({ SSC = { 0, "Sequence Start Condition", "SSC" }, SA = { 1, "Slave Address", "SA" }, ERW = { 2, "Extended Register Write", "ERW" }, ERR = { 3, "Extended Register Read", "ERR" }, ERWL = { 4, "Extended Register Write Long", "ERWL" }, ERRL = { 5, "Extended Register Read Long", "ERRL" }, RW = { 6, "Register Write", "RW" }, RR = { 7, "Register Read", "RR" }, R0W = { 8, "Register 0 Write", "R0W" }, BC = { 9, "Byte", "BC" }, P = { 10, "Parity", "P" }, ADDRESS = { 11, "Address", "A" }, BP = { 12, "Bus Pack", "BP" }, DATA = { 13, "Data ", "DATA" }, CMD_WARNINGS = { 14, "Command Warnings", "CMD_WARN" }, BIC = { 15, "Bus Idle Condition ", "BIC" }, BC_WARNINGS = { 16, "BC Warnings", "BC_WARN" }, IJE = { 17, "Illegal Jump Edge", "IJE_WAEN" }, PW = { 18, "Parity warnings", "P_WAEN" } })
_decoder = {
  api_version = 3,
  id = "mipi_rffe",
  name = "MIPI_RFFE",
  longname = "RF Front-End Control Interface",
  desc = "Two-wire, single-master, serial bus.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "mipi_rffe" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "sclk", name = "SCLK", desc = "Serial clock line" }), logicview.dict({ id = "sdata", name = "SDATA", desc = "Serial data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "error_display", desc = "Error display options", default = "display", values = { "display", "not_display" } }) },
  annotations = { { "7", "ssc", "Sequence Start Condition" }, { "6", "sa", "Slave Address" }, { "1", "erw", "Extended register write" }, { "5", "err", "Extended register read" }, { "0", "erwl", "Extended register write long" }, { "112", "errl", "Extended register read long" }, { "111", "rw", "Register write" }, { "110", "rr", "Register read" }, { "109", "r0w", "Register 0 write" }, { "108", "bc", "Byte" }, { "7", "p", "Parity" }, { "75", "address", "Address" }, { "70", "bp", "Bus pack" }, { "65", "data", "DATA" }, { "1000", "Command warnings", "Command warnings" }, { "50", "Bus Idle Condition ", "Bus Idle Condition " }, { "1000", "BC warnings", "BC warnings" }, { "1000", "Illegal Jump Edge", "IJE_WAEN" }, { "1000", "Parity warnings", "Parity warnings" } },
  annotation_rows = { { "command-data", "Command/Data", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15 } }, { "warnings", "Warnings", { 14, 16, 17, 18 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_chain = (-1)
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  self.bitcount = 0
  self.databyte = 0
  self.state = "FIND SSC"
  self.extended = (-1)
  self.cmdkey = "NULL"
  self.BC = 0
  self.bits = 0
  self.Pcount = 0
  self.BPcount = 0
  self.ADDcount = 0
  self.BPss = 0
  self.SSCs = 0
  self.Pes = 0
  self.sdata = (-1)
  self.Pdata = (-1)
  self.parity = false
  self.isWrite = false
  self.isLong = false
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self._display = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "error_display"), "display")) then return 1 else return 0 end end)()
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.Parity(self)
  self.parity = true
  if logicview.truth(logicview.eq(self.Pcount, 1)) then
    if logicview.truth(logicview.eq(self.cmdkey, "ERW")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(0, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "ERR")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(2, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "ERWL")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(6, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "ERRL")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(7, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "RW")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(2, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "RR")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(3, (2 ^ logicview.add(self.Pkey, 1))))
    end
    if logicview.truth(logicview.eq(self.cmdkey, "R0W")) then
      self.Pdata = logicview.add(self.Pdata, logicview.mul(1, (2 ^ logicview.add(self.Pkey, 1))))
    end
  end
  while logicview.truth(self.Pdata) do
    self.parity = (not logicview.truth(self.parity))
    self.Pdata = (self.Pdata & (self.Pdata - 1))
    ::continue_1::
  end
  do
    local _lv_chain = 0
    self.Pdata = _lv_chain
    self.Pkey = _lv_chain
  end
end
function _decoder.handle_BP(self, cmd, state)
  self.ss = self.Pes
  self.es = self.samplenum
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = state
end
function _decoder.handle(self, cmd, state, key, key0)
  local key1, sclk, sdata, d
  key1 = key
  if logicview.truth((key > 7)) then
    key = 7
  end
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.DATAss = self.samplenum
  end
  if logicview.truth((self.bitcount < key)) then
    while true do
      if logicview.truth(self._display) then
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sclk = logicview.idx(_lv_seq, 0)
          sdata = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth((self.matched & (1 << 0))) then
          self.databyte = (self.databyte << 1)
          self.databyte = (self.databyte | sdata)
          break
        end
        if logicview.truth((self.matched & (1 << 1))) then
          self.ss = self.samplenum
          do
            local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            sclk = logicview.idx(_lv_seq, 0)
            sdata = logicview.idx(_lv_seq, 1)
          end
          if logicview.truth((self.matched & (1 << 0))) then
            self.es = self.samplenum
            self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
            self.databyte = (self.databyte << 1)
            self.databyte = (self.databyte | sdata)
            break
          end
          if logicview.truth((self.matched & (1 << 1))) then
            self.es = self.samplenum
            self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
          end
        end
      else
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sclk = logicview.idx(_lv_seq, 0)
          sdata = logicview.idx(_lv_seq, 1)
        end
        self.databyte = (self.databyte << 1)
        self.databyte = (self.databyte | sdata)
        break
      end
      ::continue_2::
    end
    self.bitcount = logicview.add(self.bitcount, 1)
    return
  end
  while true do
    if logicview.truth(self._display) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        sclk = logicview.idx(_lv_seq, 0)
        sdata = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((self.matched & (1 << 0))) then
        self.databyte = (self.databyte << 1)
        self.databyte = (self.databyte | sdata)
        break
      end
      if logicview.truth((self.matched & (1 << 1))) then
        self.ss = self.samplenum
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sclk = logicview.idx(_lv_seq, 0)
          sdata = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth((self.matched & (1 << 0))) then
          self.es = self.samplenum
          self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
          self.databyte = (self.databyte << 1)
          self.databyte = (self.databyte | sdata)
          break
        end
        if logicview.truth((self.matched & (1 << 1))) then
          self.es = self.samplenum
          self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
        end
      end
    else
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        sclk = logicview.idx(_lv_seq, 0)
        sdata = logicview.idx(_lv_seq, 1)
      end
      self.databyte = (self.databyte << 1)
      self.databyte = (self.databyte | sdata)
      break
    end
    ::continue_3::
  end
  self:wait(logicview.dict({ [0] = "r" }))
  d = self.databyte
  self.ss = self.DATAss
  self.es = self.samplenum
  if logicview.truth((not logicview.eq(cmd, "P"))) then
    self.Pdata = d
    self.Pkey = key
  end
  if logicview.truth(logicview.eq(cmd, "BC")) then
    self.BC = logicview.add(d, 1)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "ERW")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "ERR")
  return _v
end)()) then
      if logicview.truth((function()
  local _v
  _v = (self.BC < 1)
  if logicview.truth(_v) then return _v end
  _v = (self.BC > 16)
  return _v
end)()) then
        self:putx({ logicview.idx(logicview.idx(proto, "BC_WARNINGS"), 0), logicview.slice(logicview.idx(proto, "BC_WARNINGS"), 1, nil, nil) })
        self.databyte = 0
        self:init()
        return
      end
    elseif logicview.truth((function()
  local _v
  _v = (self.BC < 1)
  if logicview.truth(_v) then return _v end
  _v = (self.BC > 8)
  return _v
end)()) then
      self:putx({ logicview.idx(logicview.idx(proto, "BC_WARNINGS"), 0), logicview.slice(logicview.idx(proto, "BC_WARNINGS"), 1, nil, nil) })
      self.databyte = 0
      self:init()
      return
    end
  end
  if logicview.truth(logicview.eq(cmd, "P")) then
    self.Pes = self.samplenum
    if logicview.truth(self._display) then
      self:Parity()
      if logicview.truth((not logicview.eq(self.parity, d))) then
        self:putx({ logicview.idx(logicview.idx(proto, "PW"), 0), logicview.slice(logicview.idx(proto, "PW"), 1, nil, nil) })
      end
    end
    self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), { logicview.pymod("%s: %d", { logicview.idx(logicview.idx(proto, cmd), 1), d }), logicview.pymod("%s: %d", { logicview.idx(logicview.idx(proto, cmd), 2), d }), logicview.pymod("%d", d) } })
    do
      local _lv_chain = 0
      self.bitcount = _lv_chain
      self.databyte = _lv_chain
    end
    self.state = state
    return
  end
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), { logicview.pymod("%s[%d:%d]: %02X", { logicview.idx(logicview.idx(proto, cmd), 1), key1, key0, d }), logicview.pymod("%s[%d:%d]: %02X", { logicview.idx(logicview.idx(proto, cmd), 2), key1, key0, d }), logicview.pymod("%02X", d) } })
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  if logicview.truth(logicview.eq(cmd, "DATA")) then
    self.bits = (self.bits - 8)
  end
  self.state = state
end
function _decoder.handle_CMD(self)
  local sclk, sdata
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.DATAss = self.samplenum
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      sclk = logicview.idx(_lv_seq, 0)
      sdata = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(sdata) then
      self:wait(logicview.dict({ [0] = "r" }))
      self:cmdset("R0W", "FIND DATA")
      return
    end
  end
  if logicview.truth(logicview.eq(self.bitcount, 1)) then
    if logicview.truth(self.sdata) then
      self.extended = 0
    else
      self.extended = 1
    end
  end
  if logicview.truth(logicview.eq(self.bitcount, 2)) then
    if logicview.truth((not logicview.truth(self.extended))) then
      if logicview.truth(self.sdata) then
        self:cmdset("RR", "FIND ADDRESS")
        return
      else
        self:cmdset("RW", "FIND ADDRESS")
        return
      end
    elseif logicview.truth(self.sdata) then
      self.isWrite = false
    else
      self.isWrite = true
    end
  end
  if logicview.truth(logicview.eq(self.bitcount, 3)) then
    if logicview.truth(self.extended) then
      if logicview.truth((not logicview.truth(self.sdata))) then
        if logicview.truth((not logicview.truth(self.isWrite))) then
          self:cmdset("ERR", "FIND BTEY_COUNT")
          return
        else
          self:cmdset("ERW", "FIND BTEY_COUNT")
          return
        end
      end
    else
      self.ss = self.DATAss
      self.es = self.samplenum
      self:putx({ logicview.idx(logicview.idx(proto, "CMD_WARNINGS"), 0), logicview.slice(logicview.idx(proto, "CMD_WARNINGS"), 1, nil, nil) })
      self:init()
      return
    end
  end
  if logicview.truth(logicview.eq(self.bitcount, 4)) then
    if logicview.truth(self.sdata) then
      self:cmdset("ERRL", "FIND BTEY_COUNT")
      return
    else
      self:cmdset("ERWL", "FIND BTEY_COUNT")
      return
    end
  end
  if logicview.truth(logicview.eq(self.bitcount, 4)) then
    if logicview.truth(self.sdata) then
      self:cmdset("ERRL", "FIND BTEY_COUNT")
      return
    else
      self:cmdset("ERWL", "FIND BTEY_COUNT")
      return
    end
  end
  if logicview.truth((self.bitcount < 4)) then
    while true do
      if logicview.truth(self._display) then
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sclk = logicview.idx(_lv_seq, 0)
          self.sdata = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth((self.matched & (1 << 0))) then
          break
        end
        if logicview.truth((self.matched & (1 << 1))) then
          self.ss = self.samplenum
          do
            local _lv_seq = self:wait({ logicview.dict({ [0] = "f" }), logicview.dict({ [0] = "l", [1] = "e" }) })
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            sclk = logicview.idx(_lv_seq, 0)
            self.sdata = logicview.idx(_lv_seq, 1)
          end
          if logicview.truth((self.matched & (1 << 0))) then
            self.es = self.samplenum
            self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
            break
          end
          if logicview.truth((self.matched & (1 << 1))) then
            self.es = self.samplenum
            self:putx({ logicview.idx(logicview.idx(proto, "IJE"), 0), logicview.slice(logicview.idx(proto, "IJE"), 1, nil, nil) })
          end
        end
      else
        do
          local _lv_seq = self:wait(logicview.dict({ [0] = "f" }))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sclk = logicview.idx(_lv_seq, 0)
          self.sdata = logicview.idx(_lv_seq, 1)
        end
        break
      end
      ::continue_4::
    end
    self:wait(logicview.dict({ [0] = "r" }))
    self.bitcount = logicview.add(self.bitcount, 1)
  end
end
function _decoder.cmdset(self, cmd, state)
  self.ss = self.DATAss
  self.es = self.samplenum
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = state
  self.bitcount = 0
  self.extended = (-1)
  self.cmdkey = cmd
end
function _decoder.initBP(self, sclk, sdata, state, key)
  self:handle_BP("BP", state)
  self.state = state
  if logicview.truth(key) then
    self:init()
  end
end
function _decoder.init(self)
  self.cmdkey = "NULL"
  self.ADDcount = 0
  self.Pcount = 0
  self.BPcount = 0
  self.BC = 0
  self.bitcount = 0
  self.Pes = 0
  self.state = "FIND SSC"
end
function _decoder.decode(self)
  local sclk, sdata, key
  while true do
    if logicview.truth(logicview.eq(self.state, "FIND SSC")) then
      self:wait(logicview.dict({ [0] = "l", [1] = "r" }))
      self.BPss = self.samplenum
      self:wait({ logicview.dict({ [0] = "h" }), logicview.dict({ [0] = "l", [1] = "f" }) })
      if logicview.truth((self.matched & (1 << 0))) then
        goto continue_5
      end
      if logicview.truth((self.matched & (1 << 1))) then
        self:wait({ logicview.dict({ [0] = "l", [1] = "e" }), logicview.dict({ [0] = "r" }) })
        if logicview.truth((self.matched & (1 << 0))) then
          goto continue_5
        end
        if logicview.truth((self.matched & (1 << 1))) then
          do
            local _lv_a0, _lv_a1 = self.BPss, self.samplenum
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self:putx({ logicview.idx(logicview.idx(proto, "SSC"), 0), logicview.slice(logicview.idx(proto, "SSC"), 1, nil, nil) })
          self.state = "FIND SLAVE ADDRESS"
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND SLAVE ADDRESS")) then
      self:handle("SA", "FIND COMMAND", 3, 0)
    elseif logicview.truth(logicview.eq(self.state, "FIND COMMAND")) then
      self:handle_CMD()
    elseif logicview.truth(logicview.eq(self.state, "FIND BTEY_COUNT")) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "ERW")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "ERR")
  return _v
end)()) then
        self:handle("BC", "FIND PARITY", 3, 0)
      else
        self:handle("BC", "FIND PARITY", 2, 0)
      end
      self.bits = logicview.mul(self.BC, 8)
    elseif logicview.truth(logicview.eq(self.state, "FIND ADDRESS")) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "RW")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "RR")
  return _v
end)()) then
        self:handle("ADDRESS", "FIND PARITY", 4, 0)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "ERR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "ERW")
  return _v
end)()) then
        self:handle("ADDRESS", "FIND PARITY", 7, 0)
      elseif logicview.truth(logicview.eq(self.Pcount, 1)) then
        self:handle("ADDRESS", "FIND PARITY", 15, 8)
      else
        self:handle("ADDRESS", "FIND PARITY", 7, 0)
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND DATA")) then
      if logicview.truth(logicview.eq(self.cmdkey, "R0W")) then
        self:handle("DATA", "FIND PARITY", 6, 0)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "RW")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "RR")
  return _v
end)()) then
        self:handle("DATA", "FIND PARITY", 7, 0)
      else
        self:handle("DATA", "FIND PARITY", (self.bits - 1), (self.bits - 8))
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND PARITY")) then
      self.Pcount = logicview.add(self.Pcount, 1)
      self:handle("P", "NULL", 0, 0)
      if logicview.truth(logicview.eq(self.cmdkey, "R0W")) then
        self.state = "FIND BUS_PARK"
      elseif logicview.truth(logicview.eq(self.cmdkey, "ERW")) then
        if logicview.truth(logicview.eq(self.Pcount, 1)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 2)) then
          self.state = "FIND DATA"
        elseif logicview.truth(logicview.eq(self.Pcount, logicview.add(self.BC, 2))) then
          self.state = "FIND BUS_PARK"
          goto continue_5
        elseif logicview.truth((self.Pcount > 2)) then
          self.state = "FIND DATA"
        end
      elseif logicview.truth(logicview.eq(self.cmdkey, "ERR")) then
        if logicview.truth(logicview.eq(self.Pcount, 1)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 2)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND BUS_PARK"
            self.BPcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, logicview.add(self.BC, 2))) then
          self.BPcount = 2
          self.state = "FIND BUS_PARK"
          goto continue_5
        elseif logicview.truth((self.Pcount > 2)) then
          self.state = "FIND DATA"
        end
      elseif logicview.truth(logicview.eq(self.cmdkey, "ERWL")) then
        if logicview.truth(logicview.eq(self.Pcount, 1)) then
          do
            local _lv_a0, _lv_a1 = 2, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 2)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 3)) then
          self.state = "FIND DATA"
        elseif logicview.truth(logicview.eq(self.Pcount, logicview.add(self.BC, 3))) then
          self.state = "FIND BUS_PARK"
          goto continue_5
        elseif logicview.truth((self.Pcount > 3)) then
          self.state = "FIND DATA"
        end
      elseif logicview.truth(logicview.eq(self.cmdkey, "ERRL")) then
        if logicview.truth(logicview.eq(self.Pcount, 1)) then
          do
            local _lv_a0, _lv_a1 = 2, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 2)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND ADDRESS"
            self.ADDcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, 3)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND BUS_PARK"
            self.BPcount = _lv_a0
            self.state = _lv_a1
          end
        elseif logicview.truth(logicview.eq(self.Pcount, logicview.add(self.BC, 3))) then
          self.BPcount = 2
          self.state = "FIND BUS_PARK"
          goto continue_5
        elseif logicview.truth((self.Pcount > 3)) then
          self.state = "FIND DATA"
        end
      elseif logicview.truth(logicview.eq(self.cmdkey, "RW")) then
        if logicview.truth(logicview.eq(self.Pcount, 1)) then
          self.state = "FIND DATA"
        elseif logicview.truth(logicview.eq(self.Pcount, 2)) then
          do
            local _lv_a0, _lv_a1 = 1, "FIND BUS_PARK"
            self.BPcount = _lv_a0
            self.state = _lv_a1
          end
        end
      elseif logicview.truth(logicview.eq(self.cmdkey, "RR")) then
        self.state = "FIND BUS_PARK"
        self.BPcount = (function() if logicview.truth(logicview.eq(self.Pcount, 1)) then return 1 else return 2 end end)()
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND BUS_PARK")) then
      do
        local _lv_seq = self:wait(logicview.dict({ [0] = "l", [1] = "l" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        sclk = logicview.idx(_lv_seq, 0)
        sdata = logicview.idx(_lv_seq, 1)
      end
      self.ss = self.samplenum
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.cmdkey, "ERR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "ERRL")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.cmdkey, "RR")
  return _v
end)()) then
        key = (function() if logicview.truth(logicview.eq(self.BPcount, 1)) then return 0 else return 1 end end)()
        self:initBP(sclk, sdata, "FIND DATA", key)
      else
        self:initBP(sclk, sdata, "FIND SSC", 1)
      end
    end
    ::continue_5::
  end
end

return _decoder
