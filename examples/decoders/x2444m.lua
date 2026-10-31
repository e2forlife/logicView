-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Stefan Petersen <spe@ciellt.se>
-- Copyright (C) 2022 DreamSourceLab <support@dreamsourcelab.com>

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
local re, registers, Decoder
local _decoder

re = logicview.re
registers = logicview.dict({ [128] = { "WRDS", 0, (function(_) return "" end) }, [129] = { "STO", 1, (function(_) return "" end) }, [130] = { "SLEEP", 2, (function(_) return "" end) }, [131] = { "WRITE", 3, (function(v) return logicview.pymod("0x%x", v) end) }, [132] = { "WREN", 4, (function(_) return "" end) }, [133] = { "RCL", 5, (function(_) return "" end) }, [134] = { "READ", 6, (function(v) return logicview.pymod("0x%x", v) end) }, [135] = { "READ", 7, (function(v) return logicview.pymod("0x%x", v) end) } })
_decoder = {
  api_version = 3,
  id = "x2444m",
  name = "X2444M/P",
  longname = "Xicor X2444M/P",
  desc = "Xicor X2444M/P nonvolatile static RAM protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "wrds", "Write disable" }, { "sto", "Store RAM data in EEPROM" }, { "sleep", "Enter sleep mode" }, { "write", "Write data into RAM" }, { "wren", "Write enable" }, { "rcl", "Recall EEPROM data into RAM" }, { "read", "Data read from RAM" }, { "read", "Data read from RAM" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.cs_start = 0
  self.cs_asserted = false
  self.cmd_digit = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putreadwrite(self, ss, es, reg, idx, addr, value)
  self:put(ss, es, self.out_ann, { idx, { logicview.pymod("%s: %s => {$}", { reg, addr }), logicview.pymod("%s: %s => {$}", { logicview.idx(reg, 0), addr }), logicview.idx(reg, 0), logicview.pymod("@%04x", value) } })
end
function _decoder.putcmd(self, ss, es, reg, idx)
  self:put(ss, es, self.out_ann, { idx, { reg, logicview.idx(reg, 0) } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso, name, idx, decoder, value
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "DATA")) then
      if logicview.truth((not logicview.truth(self.cs_asserted))) then
        return
      end
      if logicview.truth(logicview.eq(self.cmd_digit, 0)) then
        self.addr = mosi
        self.addr_start = ss
      elseif logicview.truth((self.cmd_digit > 0)) then
        self.read_value = logicview.add((self.read_value << 8), miso)
        self.write_value = logicview.add((self.write_value << 8), mosi)
      end
      self.cmd_digit = logicview.add(self.cmd_digit, 1)
    elseif logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      self.cs_asserted = logicview.eq(miso, 1)
      if logicview.truth((not logicview.truth(self.cs_asserted))) then
        if logicview.truth(logicview.eq(self.cmd_digit, 1)) then
          do
            local _lv_seq = logicview.idx(registers, (self.addr & 135))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            name = logicview.idx(_lv_seq, 0)
            idx = logicview.idx(_lv_seq, 1)
            decoder = logicview.idx(_lv_seq, 2)
          end
          self:putcmd(self.addr_start, es, name, idx)
        elseif logicview.truth((self.cmd_digit > 1)) then
          do
            local _lv_seq = logicview.idx(registers, (self.addr & 135))
            if _type(_lv_seq) == 'function' then
              local _lv_built = {}
              for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
              _lv_seq = _lv_built
            end
            name = logicview.idx(_lv_seq, 0)
            idx = logicview.idx(_lv_seq, 1)
            decoder = logicview.idx(_lv_seq, 2)
          end
          if logicview.truth(logicview.eq(name, "READ")) then
            value = self.read_value
          elseif logicview.truth(logicview.eq(name, "WRITE")) then
            value = self.write_value
          else
            value = 0
          end
          self:putreadwrite(self.addr_start, es, name, idx, decoder(((self.addr >> 3) & 15)), value)
        end
      end
      if logicview.truth(self.cs_asserted) then
        self.cs_start = ss
        self.cmd_digit = 0
        self.read_value = 0
        self.write_value = 0
      end
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
