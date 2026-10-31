-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Kevin Redon <kingkevin@cuvoodoo.info>
-- Copyright (C) 2017 Soeren Apel <soeren@apelpie.net>

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
local commands_2432, commands_2433, family_codes, crc16, Decoder
local _decoder

commands_2432 = logicview.dict({ [15] = "Write scratchpad", [170] = "Read scratchpad", [85] = "Copy scratchpad", [240] = "Read memory", [90] = "Load first secret", [51] = "Compute next secret", [165] = "Read authenticated page" })
commands_2433 = logicview.dict({ [15] = "Write scratchpad", [170] = "Read scratchpad", [85] = "Copy scratchpad", [240] = "Read memory" })
family_codes = logicview.dict({ [51] = { "DS2432", commands_2432 }, [35] = { "DS2433", commands_2433 } })
crc16 = function(byte_array)
  local reverse, crc, byte, bit
  reverse = 40961
  crc = 0
  for _lv_item in logicview.iter(byte_array) do
    byte = _lv_item
    for _lv_i in logicview.range(8) do
      bit = _lv_i
      if logicview.truth(((byte ~ crc) & 1)) then
        crc = ((crc >> 1) ~ reverse)
      else
        crc = (crc >> 1)
      end
      byte = (byte >> 1)
      ::continue_2::
    end
    ::continue_1::
  end
  crc = (crc ~ 65535)
  return crc
end
_decoder = {
  api_version = 3,
  id = "ds243x",
  name = "DS243x",
  longname = "Maxim DS2432/3",
  desc = "Maxim DS243x series 1-Wire EEPROM protocol.",
  license = "gplv2+",
  inputs = { "onewire_network" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text", "Human-readable text" } },
  annotation_rows = {  },
  binary = { { "mem_read", "Data read from memory" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bytes = {  }
  self.family_code = nil
  self.family = ""
  self.commands = commands_2432
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local code, val, s, mac, bdata
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      code = logicview.idx(_lv_seq, 0)
      val = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(code, "RESET/PRESENCE")) then
      do
        local _lv_a0, _lv_a1 = ss, es
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putx({ 0, { logicview.pymod("Reset/presence: %s", (function() if logicview.truth(val) then return "true" else return "false" end end)()) } })
      self.bytes = {  }
    elseif logicview.truth(logicview.eq(code, "ROM")) then
      do
        local _lv_a0, _lv_a1 = ss, es
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self.family_code = (val & 255)
      s = nil
      if logicview.truth(logicview.contains(family_codes, self.family_code)) then
        do
          local _lv_seq = logicview.idx(family_codes, (val & 255))
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          self.family = logicview.idx(_lv_seq, 0)
          self.commands = logicview.idx(_lv_seq, 1)
        end
        s = logicview.pymod("is 0x%02x, %s detected", { self.family_code, self.family })
      else
        s = logicview.pymod("0x%02x unknown", self.family_code)
      end
      self:putx({ 0, { logicview.pymod("ROM: 0x%016x (%s)", { val, logicview.add("family code ", s) }), logicview.pymod("ROM: 0x%016x (%s)", { val, self.family }) } })
      self.bytes = {  }
    elseif logicview.truth(logicview.eq(code, "DATA")) then
      _table.insert(self.bytes, val)
      if logicview.truth(logicview.eq(1, logicview.len(self.bytes))) then
        do
          local _lv_a0, _lv_a1 = ss, es
          self.ss = _lv_a0
          self.es = _lv_a1
        end
        if logicview.truth((not logicview.contains(self.commands, val))) then
          self:putx({ 0, { logicview.pymod("Unrecognized command: 0x%02x", val) } })
        else
          self:putx({ 0, { logicview.pymod("Function command: %s (0x%02x)", { logicview.idx(self.commands, val), val }) } })
        end
      elseif logicview.truth(logicview.eq(15, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.pymod("Target address: 0x%04x", logicview.add((logicview.idx(self.bytes, 2) << 8), logicview.idx(self.bytes, 1))) } })
        elseif logicview.truth(logicview.eq(4, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(11, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("Data: ", logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 3, 11, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())) } })
        elseif logicview.truth(logicview.eq(12, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(13, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("CRC: ", (function() if logicview.truth(logicview.eq(crc16(logicview.slice(self.bytes, 0, 11, nil)), logicview.add(logicview.idx(self.bytes, 11), (logicview.idx(self.bytes, 12) << 8)))) then return "ok" else return "error" end end)()) } })
        end
      elseif logicview.truth(logicview.eq(170, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.pymod("Target address: 0x%04x", logicview.add((logicview.idx(self.bytes, 2) << 8), logicview.idx(self.bytes, 1))) } })
        elseif logicview.truth(logicview.eq(4, logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self:putx({ 0, { logicview.pymod("Data status (E/S): 0x%02x", logicview.idx(self.bytes, 3)) } })
        elseif logicview.truth(logicview.eq(5, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(12, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("Data: ", logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 4, 12, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())) } })
        elseif logicview.truth(logicview.eq(13, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(14, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("CRC: ", (function() if logicview.truth(logicview.eq(crc16(logicview.slice(self.bytes, 0, 12, nil)), logicview.add(logicview.idx(self.bytes, 12), (logicview.idx(self.bytes, 13) << 8)))) then return "ok" else return "error" end end)()) } })
        end
      elseif logicview.truth(logicview.eq(90, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(4, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("Authorization pattern (TA1, TA2, E/S): ", logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 1, 4, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())) } })
        elseif logicview.truth((4 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth((function()
  local _v
  _v = logicview.eq(170, logicview.idx(self.bytes, (-1)))
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(85, logicview.idx(self.bytes, (-1)))
  return _v
end)()) then
            self:putx({ 0, { "End of operation" } })
          end
        end
      elseif logicview.truth(logicview.eq(51, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.pymod("Target address: 0x%04x", logicview.add((logicview.idx(self.bytes, 2) << 8), logicview.idx(self.bytes, 1))) } })
        elseif logicview.truth((3 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth((function()
  local _v
  _v = logicview.eq(170, logicview.idx(self.bytes, (-1)))
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(85, logicview.idx(self.bytes, (-1)))
  return _v
end)()) then
            self:putx({ 0, { "End of operation" } })
          end
        end
      elseif logicview.truth(logicview.eq(85, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(4, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("Authorization pattern (TA1, TA2, E/S): ", logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 1, 4, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())) } })
        elseif logicview.truth(logicview.eq(5, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(24, logicview.len(self.bytes))) then
          self.es = es
          mac = logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 4, 24, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())
          self:putx({ 0, { logicview.add("Message authentication code: ", mac), logicview.add("MAC: ", mac) } })
        elseif logicview.truth((24 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth((function()
  local _v
  _v = logicview.eq(170, logicview.idx(self.bytes, (-1)))
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(85, logicview.idx(self.bytes, (-1)))
  return _v
end)()) then
            self:putx({ 0, { "Operation succeeded" } })
          elseif logicview.truth(logicview.eq(0, logicview.idx(self.bytes, (-1)))) then
            self:putx({ 0, { "Operation failed" } })
          end
        end
      elseif logicview.truth(logicview.eq(165, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.pymod("Target address: 0x%04x", logicview.add((logicview.idx(self.bytes, 2) << 8), logicview.idx(self.bytes, 1))) } })
        elseif logicview.truth(logicview.eq(4, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(35, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("Data: ", logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 3, 35, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())) } })
        elseif logicview.truth(logicview.eq(36, logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self:putx({ 0, { logicview.add("Padding: ", (function() if logicview.truth(logicview.eq(255, logicview.idx(self.bytes, (-1)))) then return "ok" else return "error" end end)()) } })
        elseif logicview.truth(logicview.eq(37, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(38, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("CRC: ", (function() if logicview.truth(logicview.eq(crc16(logicview.slice(self.bytes, 0, 36, nil)), logicview.add(logicview.idx(self.bytes, 36), (logicview.idx(self.bytes, 37) << 8)))) then return "ok" else return "error" end end)()) } })
        elseif logicview.truth(logicview.eq(39, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(58, logicview.len(self.bytes))) then
          self.es = es
          mac = logicview.join(",", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytes, 38, 58, nil)) do
    n = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(n, "#04x")
  end
  return _lv_out
end)())
          self:putx({ 0, { logicview.add("Message authentication code: ", mac), logicview.add("MAC: ", mac) } })
        elseif logicview.truth(logicview.eq(59, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(60, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.add("MAC CRC: ", (function() if logicview.truth(logicview.eq(crc16(logicview.slice(self.bytes, 38, 58, nil)), logicview.add(logicview.idx(self.bytes, 58), (logicview.idx(self.bytes, 59) << 8)))) then return "ok" else return "error" end end)()) } })
        elseif logicview.truth((60 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth((function()
  local _v
  _v = logicview.eq(170, logicview.idx(self.bytes, (-1)))
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(85, logicview.idx(self.bytes, (-1)))
  return _v
end)()) then
            self:putx({ 0, { "Operation completed" } })
          end
        end
      elseif logicview.truth(logicview.eq(240, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          self:putx({ 0, { logicview.pymod("Target address: 0x%04x", logicview.add((logicview.idx(self.bytes, 2) << 8), logicview.idx(self.bytes, 1))) } })
        elseif logicview.truth((3 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self:putx({ 0, { logicview.pymod("Data: 0x%02x", logicview.idx(self.bytes, (-1))) } })
          bdata = logicview.to_bytes(logicview.idx(self.bytes, (-1)), 1, 'big')
          self:put(ss, es, self.out_binary, { 0, bdata })
        end
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
