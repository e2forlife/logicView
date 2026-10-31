-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2010-2016 Uwe Hermann <uwe@hermann-uwe.de>
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
local proto, lp_state, Decoder
local _decoder

proto = logicview.dict({ ["ESC Mode"] = { 0, "Escape mode entry", "ESC" }, BTA = { 1, "Bi-directional Data Lane Turnaround", "BTA" }, DATA = { 2, "Data", "Data" }, STOP = { 3, "Stop", "S" }, LPDT = { 4, "LPDT Command", "LPDT" }, DI = { 5, "Data Identifier", "DI" }, ECC = { 6, "Error Correction Code", "ECC" }, WC = { 7, "Word count", "WC" }, CRC = { 8, "CheckSUM", "CRC" }, ULPS = { 9, "Ultra-Low Power State", "ULPS" }, IDLE = { 10, "Idle", "Idle" } })
lp_state = { "LP-00", "LP-01", "LP-10", "LP-11" }
_decoder = {
  api_version = 3,
  id = "MIPI_DSI",
  name = "MIPI_DSI",
  longname = "MIPI Display Serial Interface",
  desc = "MIPI Display Serial Interface low power communication",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "mipi_dsi" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "D0N", name = "D0N", desc = "LP data 0 neg" }), logicview.dict({ id = "D0P", name = "D0P", desc = "LP data 0 pos" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "111", "LP-00", "LP-00" }, { "110", "LP-01", "LP-01" }, { "109", "LP-10", "LP-10" }, { "108", "LP-11", "LP-11" }, { "7", "EscapeMode", "Escape mode" }, { "6", "BTA", "Bi-directional Data Lane Turnaround" }, { "112", "LPDT", "LPDT" }, { "0", "DI", "Data identifier" }, { "12", "ECC", "ECC" }, { "11", "WC", "Word count" }, { "107", "CRC", "CheckSUM" }, { "5", "Stop", "Stop condition" }, { "1", "Idle", "Idle" } },
  annotation_rows = { { "LPData", "LPData", { 0, 1, 2, 3 } }, { "LP", "LP", { 4, 5, 6, 7, 8, 9, 10 } } },
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
    self.ss_byte = _lv_chain
  end
  self.bitcount = 0
  self.databyte = 0
  self.is_esc_bta = 0
  self.state = "FIND START"
  self.pdu_start = nil
  self.pdu_bits = 0
  self.bits = {  }
  self.findmode_state = "Find Mode state0"
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_bitrate = self:register(logicview.OUTPUT_META, "Bitrate")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putp(self, data)
  self:put(self.ss, self.es, self.out_python, data)
end
function _decoder.putb(self, data)
  self:put(self.ss, self.es, self.out_binary, data)
end
function _decoder.handle_start(self)
  do
    local _lv_a0, _lv_a1 = self.samplenum, self.samplenum
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self.pdu_start = self.samplenum
  self.pdu_bits = 0
  self.state = "FIND MODE"
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  self.findmode_state = "Find Mode state0"
  self.bits = {  }
end
function _decoder.handle_esc_bta(self, d0n, d0p)
  local cmd
  self.es = self.samplenum
  cmd = (function() if logicview.truth(logicview.eq(d0n, 1)) then return "ESC Mode" else return "BTA" end end)()
  self:putp({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  self.bits = {  }
  self.state = "FIND DATA"
  self.ss = self.samplenum
end
function _decoder.handle_stop(self)
  local cmd
  cmd = "STOP"
  self.es = self.samplenum
  self:putp({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), logicview.slice(logicview.idx(proto, cmd), 1, nil, nil) })
  self.state = "FIND START"
  self.is_esc_bta = 0
  self.bits = {  }
end
function _decoder.handle_data(self, d0n, d0p)
  local d, h, cmd
  self.pdu_bits = logicview.add(self.pdu_bits, 1)
  self.databyte = (self.databyte >> 1)
  if logicview.truth(d0p) then
    self.databyte = (self.databyte | 128)
  end
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.ss_byte = self.samplenum
  end
  if logicview.truth((self.bitcount < 7)) then
    self.bitcount = logicview.add(self.bitcount, 1)
    return
  end
  d = self.databyte
  self.es = self.samplenum
  h = logicview.pymod("0x%02X", d)
  cmd = "DATA"
  self:putb({ cmd, nil })
  self:putx({ logicview.idx(logicview.idx(proto, cmd), 0), { h } })
  do
    local _lv_chain = 0
    self.bitcount = _lv_chain
    self.databyte = _lv_chain
  end
  self.bits = {  }
  self.state = "FIND DATA"
  self.ss = self.samplenum
end
function _decoder.decode(self)
  local d0n, d0p
  while true do
    if logicview.truth(logicview.eq(self.state, "FIND START")) then
      self:wait(logicview.dict({ [0] = "f", [1] = "h" }))
      self:handle_start()
    elseif logicview.truth(logicview.eq(self.state, "FIND MODE")) then
      if logicview.truth(logicview.eq(self.findmode_state, "Find Mode state0")) then
        self:wait(logicview.dict({ [0] = "l", [1] = "l" }))
        self.findmode_state = "Find Mode state1"
      elseif logicview.truth(logicview.eq(self.findmode_state, "Find Mode state1")) then
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "h", [1] = "l" }), logicview.dict({ [0] = "l", [1] = "h" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          d0n = logicview.idx(_lv_seq, 0)
          d0p = logicview.idx(_lv_seq, 1)
        end
        self.findmode_state = "Find Mode state2"
      elseif logicview.truth(logicview.eq(self.findmode_state, "Find Mode state2")) then
        self:wait(logicview.dict({ [0] = "l", [1] = "l" }))
        self:handle_esc_bta(d0n, d0p)
      end
    elseif logicview.truth(logicview.eq(self.state, "FIND DATA")) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "h", [1] = "l" }), logicview.dict({ [0] = "l", [1] = "h" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        d0n = logicview.idx(_lv_seq, 0)
        d0p = logicview.idx(_lv_seq, 1)
      end
      self:wait({ logicview.dict({ [0] = "l", [1] = "l" }), logicview.dict({ [0] = "h", [1] = "h" }) })
      if logicview.truth((self.matched & (1 << 0))) then
        self:handle_data(d0n, d0p)
      else
        self:handle_stop()
      end
    end
    ::continue_1::
  end
end

return _decoder
