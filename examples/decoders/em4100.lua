-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Benjamin Larsson <benjamin@southpole.se>

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
local SamplerateError, Decoder
local _decoder

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "em4100",
  name = "EM4100",
  longname = "RFID EM4100",
  desc = "EM4100 100-150kHz RFID protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IC", "RFID" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-high", values = { "active-low", "active-high" } }), logicview.dict({ id = "datarate", desc = "Data rate", default = 64, values = { 64, 32, 16 } }), logicview.dict({ id = "coilfreq", desc = "Coil frequency", default = 125000, values = {  } }) },
  annotations = { { "bit", "Bit" }, { "header", "Header" }, { "version-customer", "Version/customer" }, { "data", "Data" }, { "rowparity-ok", "Row parity OK" }, { "rowparity-err", "Row parity error" }, { "colparity-ok", "Column parity OK" }, { "colparity-err", "Column parity error" }, { "stopbit", "Stop bit" }, { "tag", "Tag" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6, 7, 8 } }, { "tags", "Tags", { 9 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.oldpin = nil
  self.last_samplenum = nil
  self.lastlast_samplenum = nil
  self.last_edge = 0
  self.bit_width = 0
  self.halfbit_limit = 0
  self.oldpp = 0
  self.oldpl = 0
  self.oldsamplenum = 0
  self.last_bit_pos = 0
  self.ss_first = 0
  self.first_one = 0
  self.state = "HEADER"
  self.data = 0
  self.data_bits = 0
  self.ss_data = 0
  self.data_parity = 0
  self.payload_cnt = 0
  self.data_col_parity = { 0, 0, 0, 0, 0, 0 }
  self.col_parity = { 0, 0, 0, 0, 0, 0 }
  self.tag = 0
  self.all_row_parity_ok = true
  self.col_parity_pos = {  }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
  self.bit_width = logicview.mul((self.samplerate / logicview.idx(self.options, "coilfreq")), logicview.idx(self.options, "datarate"))
  self.halfbit_limit = logicview.add((self.bit_width / 2), (self.bit_width / 4))
  self.polarity = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return 0 else return 1 end end)()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putbit(self, bit, ss, es)
  local s, c, i, all_col_parity_ok
  self:put(ss, es, self.out_ann, { 0, { _tostring(bit) } })
  if logicview.truth(logicview.eq(self.state, "HEADER")) then
    if logicview.truth(logicview.eq(bit, 1)) then
      if logicview.truth((self.first_one > 0)) then
        self.first_one = logicview.add(self.first_one, 1)
      end
      if logicview.truth(logicview.eq(self.first_one, 9)) then
        self:put(self.ss_first, es, self.out_ann, { 1, { "Header", "Head", "He", "H" } })
        self.first_one = 0
        self.state = "PAYLOAD"
        return
      end
      if logicview.truth(logicview.eq(self.first_one, 0)) then
        self.first_one = 1
        self.ss_first = ss
      end
    end
    if logicview.truth(logicview.eq(bit, 0)) then
      self.first_one = 0
    end
    return
  end
  if logicview.truth(logicview.eq(self.state, "PAYLOAD")) then
    self.payload_cnt = logicview.add(self.payload_cnt, 1)
    if logicview.truth(logicview.eq(self.data_bits, 0)) then
      self.ss_data = ss
      self.data = 0
      self.data_parity = 0
    end
    self.data_bits = logicview.add(self.data_bits, 1)
    if logicview.truth(logicview.eq(self.data_bits, 5)) then
      s = (function() if logicview.truth((self.payload_cnt <= 10)) then return "Version/customer" else return "Data" end end)()
      c = (function() if logicview.truth((self.payload_cnt <= 10)) then return 2 else return 3 end end)()
      self:put(self.ss_data, ss, self.out_ann, { c, { logicview.add(s, logicview.pymod(": %X", self.data)), logicview.pymod("%X", self.data) } })
      s = (function() if logicview.truth(logicview.eq(self.data_parity, bit)) then return "OK" else return "ERROR" end end)()
      c = (function() if logicview.truth(logicview.eq(s, "OK")) then return 4 else return 5 end end)()
      if logicview.truth(logicview.eq(s, "ERROR")) then
        self.all_row_parity_ok = false
      end
      self:put(ss, es, self.out_ann, { c, { logicview.add("Row parity: ", s), logicview.add("RP: ", s), "RP", "R" } })
      self.tag = ((self.tag << 4) | self.data)
      self.data_bits = 0
      if logicview.truth(logicview.eq(self.payload_cnt, 50)) then
        self.state = "TRAILER"
        self.payload_cnt = 0
      end
    end
    self.data_parity = (self.data_parity ~ bit)
    logicview.setidx(self.data_col_parity, self.data_bits, (logicview.idx(self.data_col_parity, self.data_bits) ~ bit))
    self.data = ((self.data << 1) | bit)
    return
  end
  if logicview.truth(logicview.eq(self.state, "TRAILER")) then
    self.payload_cnt = logicview.add(self.payload_cnt, 1)
    if logicview.truth(logicview.eq(self.data_bits, 0)) then
      self.ss_data = ss
      self.data = 0
      self.data_parity = 0
    end
    self.data_bits = logicview.add(self.data_bits, 1)
    logicview.setidx(self.col_parity, self.data_bits, bit)
    _table.insert(self.col_parity_pos, { ss, es })
    if logicview.truth(logicview.eq(self.data_bits, 5)) then
      self:put(ss, es, self.out_ann, { 8, { "Stop bit", "SB", "S" } })
      for _lv_i in logicview.range(1, 5) do
        i = _lv_i
        s = (function() if logicview.truth(logicview.eq(logicview.idx(self.data_col_parity, i), logicview.idx(self.col_parity, i))) then return "OK" else return "ERROR" end end)()
        c = (function() if logicview.truth(logicview.eq(s, "OK")) then return 6 else return 7 end end)()
        self:put(logicview.idx(logicview.idx(self.col_parity_pos, (i - 1)), 0), logicview.idx(logicview.idx(self.col_parity_pos, (i - 1)), 1), self.out_ann, { c, { logicview.pymod("Column parity %d: %s", { i, s }), logicview.pymod("CP%d: %s", { i, s }), logicview.pymod("CP%d", i), "C" } })
        ::continue_1::
      end
      all_col_parity_ok = logicview.eq(logicview.slice(self.data_col_parity, 1, 5, nil), logicview.slice(self.col_parity, 1, 5, nil))
      if logicview.truth((function()
  local _v
  _v = all_col_parity_ok
  if not logicview.truth(_v) then return _v end
  _v = self.all_row_parity_ok
  return _v
end)()) then
        self:put(self.ss_first, es, self.out_ann, { 9, { logicview.pymod("Tag: %010X", self.tag), "Tag", "T" } })
      end
      self.tag = 0
      self.data_bits = 0
      if logicview.truth(logicview.eq(self.payload_cnt, 5)) then
        self.state = "HEADER"
        self.payload_cnt = 0
        self.data_col_parity = { 0, 0, 0, 0, 0, 0 }
        self.col_parity = { 0, 0, 0, 0, 0, 0 }
        self.col_parity_pos = {  }
        self.all_row_parity_ok = true
      end
    end
  end
end
function _decoder.manchester_decode(self, pl, pp, pin)
  local bit, es, ss
  bit = (self.oldpin ~ self.polarity)
  if logicview.truth((pl > self.halfbit_limit)) then
    es = logicview.tointeger((self.samplenum - (pl / 2)))
    if logicview.truth((self.oldpl > self.halfbit_limit)) then
      ss = logicview.tointeger((self.oldsamplenum - (self.oldpl / 2)))
    else
      ss = logicview.tointeger((self.oldsamplenum - self.oldpl))
    end
    self:putbit(bit, ss, es)
    self.last_bit_pos = logicview.tointeger((self.samplenum - (pl / 2)))
  else
    es = logicview.tointeger(self.samplenum)
    if logicview.truth((self.oldpl > self.halfbit_limit)) then
      ss = logicview.tointeger((self.oldsamplenum - (self.oldpl / 2)))
      self:putbit(bit, ss, es)
      self.last_bit_pos = logicview.tointeger(self.samplenum)
    elseif logicview.truth((self.last_bit_pos <= (self.oldsamplenum - self.oldpl))) then
      ss = logicview.tointeger((self.oldsamplenum - self.oldpl))
      self:putbit(bit, ss, es)
      self.last_bit_pos = logicview.tointeger(self.samplenum)
    end
  end
end
function _decoder.decode(self)
  local pin, pl, pp
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  do
    local _lv_seq = self:wait()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    pin = logicview.idx(_lv_seq, 0)
  end
  self.oldpin = pin
  self.last_samplenum = self.samplenum
  self.lastlast_samplenum = self.samplenum
  self.last_edge = self.samplenum
  self.oldpl = 0
  self.oldpp = 0
  self.oldsamplenum = 0
  self.last_bit_pos = 0
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      pin = logicview.idx(_lv_seq, 0)
    end
    pl = (self.samplenum - self.oldsamplenum)
    pp = pin
    self:manchester_decode(pl, pp, pin)
    self.oldpl = pl
    self.oldpp = pp
    self.oldsamplenum = self.samplenum
    self.oldpin = pin
    ::continue_2::
  end
end

return _decoder
