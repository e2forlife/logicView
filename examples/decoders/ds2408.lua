-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Mariusz Bialonczyk <manio@skyboo.net>

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
local command, Decoder
local _decoder

command = logicview.dict({ [240] = "Read PIO Registers", [245] = "Channel Access Read", [90] = "Channel Access Write", [204] = "Write Conditional Search Register", [195] = "Reset Activity Latches", [60] = "Disable Test Mode" })
_decoder = {
  api_version = 3,
  id = "ds2408",
  name = "DS2408",
  longname = "Maxim DS2408",
  desc = "1-Wire 8-channel addressable switch.",
  license = "gplv2+",
  inputs = { "onewire_network" },
  outputs = {  },
  tags = { "Embedded/industrial", "IC" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text", "Human-readable text" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bytes = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local code, val, family_code
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
      family_code = (val & 255)
      self:putx({ 0, { logicview.pymod("ROM: 0x%016x (family code 0x%02x)", { val, family_code }) } })
      self.bytes = {  }
    elseif logicview.truth(logicview.eq(code, "DATA")) then
      _table.insert(self.bytes, val)
      if logicview.truth(logicview.eq(1, logicview.len(self.bytes))) then
        do
          local _lv_a0, _lv_a1 = ss, es
          self.ss = _lv_a0
          self.es = _lv_a1
        end
        if logicview.truth((not logicview.contains(command, val))) then
          self:putx({ 0, { logicview.pymod("Unrecognized command: 0x%02x", val) } })
        else
          self:putx({ 0, { logicview.pymod("%s (0x%02x)", { logicview.idx(command, val), val }) } })
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
        end
      elseif logicview.truth(logicview.eq(245, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth((2 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self:putx({ 0, { logicview.pymod("PIO sample: 0x%02x", logicview.idx(self.bytes, (-1))) } })
        end
      elseif logicview.truth(logicview.eq(90, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth(logicview.eq(3, logicview.len(self.bytes))) then
          self.es = es
          if logicview.truth(logicview.eq(logicview.idx(self.bytes, (-1)), (logicview.idx(self.bytes, (-2)) ~ 255))) then
            self:putx({ 0, { logicview.pymod("Data: 0x%02x (bit-inversion correct: 0x%02x)", { logicview.idx(self.bytes, (-2)), logicview.idx(self.bytes, (-1)) }) } })
          else
            self:putx({ 0, { logicview.pymod("Data error: second byte (0x%02x) is not bit-inverse of first (0x%02x)", { logicview.idx(self.bytes, (-1)), logicview.idx(self.bytes, (-2)) }) } })
          end
        elseif logicview.truth((3 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth(logicview.eq(170, logicview.idx(self.bytes, (-1)))) then
            self:putx({ 0, { "Success" } })
          elseif logicview.truth(logicview.eq(255, logicview.idx(self.bytes, (-1)))) then
            self:putx({ 0, { "Fail New State" } })
          end
        end
      elseif logicview.truth(logicview.eq(204, logicview.idx(self.bytes, 0))) then
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
        end
      elseif logicview.truth(logicview.eq(195, logicview.idx(self.bytes, 0))) then
        if logicview.truth(logicview.eq(2, logicview.len(self.bytes))) then
          self.ss = ss
        elseif logicview.truth((2 < logicview.len(self.bytes))) then
          do
            local _lv_a0, _lv_a1 = ss, es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          if logicview.truth(logicview.eq(170, logicview.idx(self.bytes, (-1)))) then
            self:putx({ 0, { "Success" } })
          else
            self:putx({ 0, { "Invalid byte" } })
          end
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
