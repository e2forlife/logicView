-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: Pirate

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
local SamplerateError, ann_byte, ann_bit, ann_bit_stuff, ann_desc_header, ann_desc_model_id, ann_desc_type, ann_desc_range_check, ann_desc_fail_safe, ann_desc_country_code, ann_desc_bind, ann_desc_flag2, ann_desc_channes, ann_desc_rsrv, ann_desc_eu_plus, ann_desc_disable_sport, ann_desc_powerlevel, ann_desc_rx_highchan, ann_desc_telemetry_off, ann_desc_external_antena, ann_desc_crc, ann_debug, state_wait_header, state_rx_model_id, state_rx_type, state_rx_range_check, state_rx_fail_safe, state_rx_country_code, state_rx_bind, state_rx_flag2, state_rx_channels, state_rx_rsrv2, state_rx_euplus, state_rx_disable_sport, state_rx_powerlevel, state_rx_highchan, state_rx_telemetry_off, state_rx_external_antena, state_rx_crc, state_rx_stop, state_error, PXX_HEADER, PXX_SEND_BIND, PXX_SEND_FAILSAFE, PXX_SEND_RANGECHECK, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(21) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_byte = logicview.idx(_lv_seq, 0)
  ann_bit = logicview.idx(_lv_seq, 1)
  ann_bit_stuff = logicview.idx(_lv_seq, 2)
  ann_desc_header = logicview.idx(_lv_seq, 3)
  ann_desc_model_id = logicview.idx(_lv_seq, 4)
  ann_desc_type = logicview.idx(_lv_seq, 5)
  ann_desc_range_check = logicview.idx(_lv_seq, 6)
  ann_desc_fail_safe = logicview.idx(_lv_seq, 7)
  ann_desc_country_code = logicview.idx(_lv_seq, 8)
  ann_desc_bind = logicview.idx(_lv_seq, 9)
  ann_desc_flag2 = logicview.idx(_lv_seq, 10)
  ann_desc_channes = logicview.idx(_lv_seq, 11)
  ann_desc_rsrv = logicview.idx(_lv_seq, 12)
  ann_desc_eu_plus = logicview.idx(_lv_seq, 13)
  ann_desc_disable_sport = logicview.idx(_lv_seq, 14)
  ann_desc_powerlevel = logicview.idx(_lv_seq, 15)
  ann_desc_rx_highchan = logicview.idx(_lv_seq, 16)
  ann_desc_telemetry_off = logicview.idx(_lv_seq, 17)
  ann_desc_external_antena = logicview.idx(_lv_seq, 18)
  ann_desc_crc = logicview.idx(_lv_seq, 19)
  ann_debug = logicview.idx(_lv_seq, 20)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(19) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  state_wait_header = logicview.idx(_lv_seq, 0)
  state_rx_model_id = logicview.idx(_lv_seq, 1)
  state_rx_type = logicview.idx(_lv_seq, 2)
  state_rx_range_check = logicview.idx(_lv_seq, 3)
  state_rx_fail_safe = logicview.idx(_lv_seq, 4)
  state_rx_country_code = logicview.idx(_lv_seq, 5)
  state_rx_bind = logicview.idx(_lv_seq, 6)
  state_rx_flag2 = logicview.idx(_lv_seq, 7)
  state_rx_channels = logicview.idx(_lv_seq, 8)
  state_rx_rsrv2 = logicview.idx(_lv_seq, 9)
  state_rx_euplus = logicview.idx(_lv_seq, 10)
  state_rx_disable_sport = logicview.idx(_lv_seq, 11)
  state_rx_powerlevel = logicview.idx(_lv_seq, 12)
  state_rx_highchan = logicview.idx(_lv_seq, 13)
  state_rx_telemetry_off = logicview.idx(_lv_seq, 14)
  state_rx_external_antena = logicview.idx(_lv_seq, 15)
  state_rx_crc = logicview.idx(_lv_seq, 16)
  state_rx_stop = logicview.idx(_lv_seq, 17)
  state_error = logicview.idx(_lv_seq, 18)
end
PXX_HEADER = 126
PXX_SEND_BIND = 1
PXX_SEND_FAILSAFE = (1 << 4)
PXX_SEND_RANGECHECK = (1 << 5)
_decoder = {
  api_version = 3,
  id = "pxx1",
  name = "PXX1",
  longname = "PXX1 modulation",
  desc = "FrSky PXX1(R9M) Protcol",
  license = "Pirate",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PXX1" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "byte", "Byte" }, { "bit", "Bit" }, { "bit_stuff", "BitStuff" }, { "start_header", "Start Header" }, { "model_id", "Model ID" }, { "type", "Type" }, { "range_check", "RangeCheck" }, { "fail_safe", "FailSafe" }, { "country_code", "CountryCode" }, { "bind", "Bind" }, { "flags2", "Flags2" }, { "channels", "Channels" }, { "reserved", "Reserved" }, { "is_euplpus", "EU-PLUS" }, { "disable_sport", "Disable SPort" }, { "power_level", "Power Level" }, { "rx_highchan", "Receive Hight Channel" }, { "telemetry_off", "Telemetry Off" }, { "external_antena", "ExternalAntena" }, { "CRC", "CRC" } },
  annotation_rows = { { "bytes", "Bytes", { 0 } }, { "bits", "Bits", { 1, 2 } }, { "desc", "Description", { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 } } },
  binary = { { "raw", "RAW file" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_chain = nil
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
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
function _decoder.breakRX(self)
  self.cur_bit = 0
  self.byte = 0
  self.byte_cnt = 0
  self.bit_stuffing = false
  self.nible = {  }
  self.state_word = 0
  self.state_bit = 0
  self.state = state_wait_header
end
function _decoder.addByte(self, value)
  self:put(self.byte_start, self.es_block, self.out_ann, { ann_byte, { logicview.pymod("%02X", value) } })
  if logicview.truth(logicview.eq(value, 126)) then
    self.bit_one_cnt = 0
  end
  self.byte_cnt = logicview.add(self.byte_cnt, 1)
  if logicview.truth((self.byte_cnt > 18)) then
    self.bit_stuffing = false
  end
end
function _decoder.addBit(self, value)
  local bstuff, chans, is_upper, out, ch1, ch2, x
  bstuff = 0
  if logicview.truth(logicview.eq(self.cur_bit, 0)) then
    self.byte_start = self.ss_block
  end
  if logicview.truth(logicview.eq(self.state_bit, 0)) then
    self.state_word_start = self.ss_block
  end
  self.bit_one_cnt = logicview.add(self.bit_one_cnt, 1)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.bit_stuffing, false)
  if logicview.truth(_v) then return _v end
  _v = (self.bit_one_cnt < 6)
  return _v
end)()) then
    self.byte = (self.byte << 1)
    self.byte = (self.byte | value)
    self.cur_bit = logicview.add(self.cur_bit, 1)
    self:put(self.ss_block, self.es_block, self.out_ann, { ann_bit, { logicview.pymod("%X", value) } })
    self.state_word = (self.state_word << 1)
    self.state_word = (self.state_word | value)
    self.state_bit = logicview.add(self.state_bit, 1)
  else
    bstuff = 1
    self:put(self.ss_block, self.es_block, self.out_ann, { ann_bit_stuff, { logicview.pymod("%s", "S") } })
  end
  if logicview.truth(logicview.eq(value, 0)) then
    self.bit_one_cnt = 0
  end
  if logicview.truth(logicview.eq(self.cur_bit, 8)) then
    self:addByte(self.byte)
    self.cur_bit = 0
    self.byte = 0
  end
  if logicview.truth(logicview.eq(self.state, state_wait_header)) then
    if logicview.truth(logicview.eq(self.state_bit, 8)) then
      if logicview.truth(logicview.eq(self.state_word, PXX_HEADER)) then
        self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_header, { logicview.pymod("%s", "Start Header") } })
        self.state = state_rx_model_id
        self.state_bit = 0
        self.bit_stuffing = true
        self.state_word = 0
      else
        self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_header, { logicview.pymod("%s", "Header error") } })
        self.state = state_error
      end
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_model_id)) then
    if logicview.truth(logicview.eq(self.state_bit, 8)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_model_id, { logicview.pymod("Model ID: %d", self.state_word) } })
      self.state = state_rx_type
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_type)) then
    if logicview.truth(logicview.eq(self.state_bit, 2)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_type, { logicview.pymod("Type: %s", logicview.idx(self.transmit_type, self.state_word)) } })
      self.state = state_rx_range_check
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_range_check)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_range_check, { logicview.pymod("Range Check: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "On" else return "Off" end end)()) } })
      self.state = state_rx_fail_safe
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_fail_safe)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_fail_safe, { logicview.pymod("FailSafe: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "On" else return "Off" end end)()) } })
      self.state = state_rx_country_code
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_country_code)) then
    if logicview.truth(logicview.eq(self.state_bit, 3)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_country_code, { logicview.pymod("CountryCode: %u", self.state_word) } })
      self.state = state_rx_bind
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_bind)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_bind, { logicview.pymod("Bind: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "On" else return "Off" end end)()) } })
      self.state = state_rx_flag2
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_flag2)) then
    if logicview.truth(logicview.eq(self.state_bit, 8)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_flag2, { logicview.pymod("Flag2: %u", self.state_word) } })
      self.state = state_rx_channels
      self.nible = {  }
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_channels)) then
    if logicview.truth((function()
  local _v
  _v = logicview.eq(bstuff, 0)
  if not logicview.truth(_v) then return _v end
  _v = (self.state_bit > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.pymod(self.state_bit, 4), 0)
  return _v
end)()) then
      _table.insert(self.nible, self.state_word)
      self.state_word = 0
    end
    if logicview.truth(logicview.eq(self.state_bit, 96)) then
      chans = {  }
      is_upper = false
      out = ""
      while logicview.truth((logicview.len(self.nible) > 0)) do
        ch1 = (((logicview.idx(self.nible, 3) << 8) | (logicview.idx(self.nible, 1) << 4)) | logicview.idx(self.nible, 0))
        ch2 = (((logicview.idx(self.nible, 4) << 8) | (logicview.idx(self.nible, 5) << 4)) | logicview.idx(self.nible, 2))
        out = logicview.add(out, logicview.pymod("%04u %04u", { ch1, ch2 }))
        for _lv_i in logicview.range(0, 6) do
          x = _lv_i
          logicview.list_pop(self.nible, 0)
          ::continue_2::
        end
        if logicview.truth((logicview.len(self.nible) > 0)) then
          out = logicview.add(out, " ")
        end
        if logicview.truth((ch1 > 2048)) then
          is_upper = true
        end
        ::continue_1::
      end
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_channes, { logicview.pymod("Channels %s: [%s]", { (function() if logicview.truth(logicview.eq(is_upper, false)) then return "(1-8)" else return "(9-16)" end end)(), out }) } })
      self.state_bit = 0
      self.state_word = 0
      self.state = state_rx_rsrv2
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_rsrv2)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_rsrv, { "Reserved" } })
      self.state = state_rx_euplus
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_euplus)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_eu_plus, { logicview.pymod("EUPlus: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "Yes" else return "No" end end)()) } })
      self.state = state_rx_disable_sport
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_disable_sport)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_disable_sport, { logicview.pymod("SPort: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "Disabled" else return "Enable" end end)()) } })
      self.state = state_rx_powerlevel
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_powerlevel)) then
    if logicview.truth(logicview.eq(self.state_bit, 2)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_powerlevel, { logicview.pymod("PowerLevel: %u", self.state_word) } })
      self.state = state_rx_highchan
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_highchan)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_rx_highchan, { logicview.pymod("RX HighChannel: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "Yes" else return "No" end end)()) } })
      self.state = state_rx_telemetry_off
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_telemetry_off)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_telemetry_off, { logicview.pymod("Telemetry: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "Off" else return "On" end end)()) } })
      self.state = state_rx_external_antena
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_external_antena)) then
    if logicview.truth(logicview.eq(self.state_bit, 1)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_external_antena, { logicview.pymod("ExternalAntena: %s", (function() if logicview.truth(logicview.eq(self.state_word, 1)) then return "Yes" else return "No" end end)()) } })
      self.state = state_rx_crc
      self.state_bit = 0
      self.state_word = 0
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_crc)) then
    if logicview.truth(logicview.eq(self.state_bit, 16)) then
      self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_crc, { logicview.pymod("CRC: 0x%04X", self.state_word) } })
      self.state = state_rx_stop
      self.state_bit = 0
      self.state_word = 0
      self.bit_stuff = false
    end
  end
  if logicview.truth(logicview.eq(self.state, state_rx_stop)) then
    if logicview.truth(logicview.eq(self.state_bit, 8)) then
      if logicview.truth(logicview.eq(self.state_word, PXX_HEADER)) then
        self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_header, { logicview.pymod("%s", "Stop Header") } })
        self.state = state_wait_header
        self.state_bit = 0
        self.state_word = 0
      else
        self:put(self.state_word_start, self.es_block, self.out_ann, { ann_desc_header, { logicview.pymod("%s", "Header error") } })
        self.state = state_error
      end
    end
  end
end
function _decoder.decode(self)
  local num_cycles, average, start_samplenum, end_samplenum, period, duty, ratio, period_t
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  num_cycles = 0
  average = 0
  self:wait(logicview.dict({ [0] = "f" }))
  self.first_samplenum = self.samplenum
  while true do
    start_samplenum = self.samplenum
    self:wait(logicview.dict({ [0] = "r" }))
    end_samplenum = self.samplenum
    self:wait(logicview.dict({ [0] = "f" }))
    self.ss_block = start_samplenum
    self.es_block = self.samplenum
    period = (self.samplenum - start_samplenum)
    duty = (end_samplenum - start_samplenum)
    ratio = (_tonumber((duty / period)) or 0)
    period_t = (_tonumber((period / self.samplerate)) or 0)
    if logicview.truth((function()
  local _v
  _v = (period_t >= 2.3e-05)
  if not logicview.truth(_v) then return _v end
  _v = (period_t <= 2.5e-05)
  return _v
end)()) then
      self:addBit(1)
    end
    if logicview.truth((function()
  local _v
  _v = (period_t >= 1.5e-05)
  if not logicview.truth(_v) then return _v end
  _v = (period_t <= 1.7e-05)
  return _v
end)()) then
      self:addBit(0)
    end
    if logicview.truth((period_t >= 4e-05)) then
      self.es_block = logicview.add(self.ss_block, logicview.tointeger(logicview.mul((self.samplerate / 1000000), 16)))
      self:addBit(0)
      self:breakRX()
    end
    ::continue_3::
  end
end

return _decoder
