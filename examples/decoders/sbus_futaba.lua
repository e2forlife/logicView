-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2022 Gerhard Sittig <gerhard.sittig@gmx.net>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local bitpack_lsb, Ann, Decoder
local _decoder

bitpack_lsb = logicview.bitpack_lsb
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(7) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.HEADER = logicview.idx(_lv_seq, 0)
  Ann.PROPORTIONAL = logicview.idx(_lv_seq, 1)
  Ann.DIGITAL = logicview.idx(_lv_seq, 2)
  Ann.FRAME_LOST = logicview.idx(_lv_seq, 3)
  Ann.FAILSAFE = logicview.idx(_lv_seq, 4)
  Ann.FOOTER = logicview.idx(_lv_seq, 5)
  Ann.WARN = logicview.idx(_lv_seq, 6)
end
Ann.FLAG_LSB = Ann.FRAME_LOST
_decoder = {
  api_version = 3,
  id = "sbus_futaba",
  name = "SBUS (Futaba)",
  longname = "Futaba SBUS (Serial bus)",
  desc = "Serial bus for hobby remote control by Futaba",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = { "sbus_futaba" },
  tags = { "Remote Control" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "prop_val_min", desc = "Proportional value lower boundary", default = 0, values = {  } }), logicview.dict({ id = "prop_val_max", desc = "Proportional value upper boundary", default = 2047, values = {  } }) },
  annotations = { { "header", "Header" }, { "proportional", "Proportional" }, { "digital", "Digital" }, { "framelost", "Frame Lost" }, { "failsafe", "Failsafe" }, { "footer", "Footer" }, { "warning", "Warning" } },
  annotation_rows = { { "framing", "Framing", { 0, 5, 3, 4 } }, { "channels", "Channels", { 1, 2 } }, { "warnings", "Warnings", { 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self.bits_accum = {  }
  self.sent_fields = nil
  self.msg_complete = nil
  self.failed = nil
  self:reset()
end
function _decoder.reset(self)
  logicview.list_clear(self.bits_accum)
  self.sent_fields = 0
  self.msg_complete = false
  self.failed = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_py = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.putg(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putpy(self, ss, es, data)
  self:put(ss, es, self.out_py, data)
end
function _decoder.get_ss_es_bits(self, bitcount)
  local bits, ss, es
  if logicview.truth((bitcount == nil)) then
    bitcount = logicview.len(self.bits_accum)
  end
  if logicview.truth((logicview.len(self.bits_accum) < bitcount)) then
    return { nil, nil, nil }
  end
  bits = logicview.slice(self.bits_accum, nil, bitcount, nil)
  self.bits_accum = logicview.slice(self.bits_accum, bitcount, nil, nil)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(bits, 0), 1), logicview.idx(logicview.idx(bits, (-1)), 2)
    ss = _lv_a0
    es = _lv_a1
  end
  bits = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(bits) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(b, 0)
  end
  return _lv_out
end)()
  return { ss, es, bits }
end
function _decoder.flush_accum_bits(self)
  local upto, want, ss, es, bits, value, text, idx, ch_nr, flag_names, cls, flg_name
  upto = 0
  if logicview.truth(self.failed) then
    return
  end
  upto = logicview.add(upto, 1)
  want = 8
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    text = { logicview.pyformat("0x{:02x}", { value }, logicview.dict({})) }
    self:putg(ss, es, { Ann.HEADER, text })
    if logicview.truth((not logicview.eq(value, 15))) then
      text = { "Unexpected header", "Header" }
      self:putg(ss, es, { Ann.WARN, text })
    end
    self:putpy(ss, es, { "HEADER", value })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_1::
  end
  upto = logicview.add(upto, 16)
  want = 11
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    text = { logicview.pyformat("{:d}", { value }, logicview.dict({})) }
    self:putg(ss, es, { Ann.PROPORTIONAL, text })
    if logicview.truth((value < logicview.idx(self.options, "prop_val_min"))) then
      text = { "Low proportional value", "Low value", "Low" }
      self:putg(ss, es, { Ann.WARN, text })
    end
    if logicview.truth((value > logicview.idx(self.options, "prop_val_max"))) then
      text = { "High proportional value", "High value", "High" }
      self:putg(ss, es, { Ann.WARN, text })
    end
    idx = (self.sent_fields - (upto - 16))
    ch_nr = logicview.add(1, idx)
    self:putpy(ss, es, { "PROPORTIONAL", { ch_nr, value } })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_2::
  end
  upto = logicview.add(upto, 2)
  want = 1
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    text = { logicview.pyformat("{:d}", { value }, logicview.dict({})) }
    self:putg(ss, es, { Ann.DIGITAL, text })
    idx = (self.sent_fields - (upto - 2))
    ch_nr = logicview.add(17, idx)
    self:putpy(ss, es, { "DIGITAL", { ch_nr, value } })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_3::
  end
  flag_names = { "framelost", "failsafe", "msb" }
  upto = logicview.add(upto, 2)
  want = 1
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    text = { logicview.pyformat("{:d}", { value }, logicview.dict({})) }
    idx = (self.sent_fields - (upto - 2))
    cls = logicview.add(Ann.FLAG_LSB, idx)
    self:putg(ss, es, { cls, text })
    flg_name = logicview.idx(flag_names, idx)
    self:putpy(ss, es, { "FLAG", { flg_name, value } })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_4::
  end
  upto = logicview.add(upto, 1)
  want = 4
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    if logicview.truth((not logicview.eq(value, 0))) then
      text = { "Unexpected MSB flags", "Flags" }
      self:putg(ss, es, { Ann.WARN, text })
    end
    flg_name = logicview.idx(flag_names, (-1))
    self:putpy(ss, es, { "FLAG", { flg_name, value } })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_5::
  end
  upto = logicview.add(upto, 1)
  want = 8
  while logicview.truth((self.sent_fields < upto)) do
    if logicview.truth((logicview.len(self.bits_accum) < want)) then
      return
    end
    do
      local _lv_seq = self:get_ss_es_bits(want)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      bits = logicview.idx(_lv_seq, 2)
    end
    value = bitpack_lsb(bits)
    text = { logicview.pyformat("0x{:02x}", { value }, logicview.dict({})) }
    self:putg(ss, es, { Ann.FOOTER, text })
    if logicview.truth((not logicview.eq(value, 0))) then
      text = { "Unexpected footer", "Footer" }
      self:putg(ss, es, { Ann.WARN, text })
    end
    self:putpy(ss, es, { "FOOTER", value })
    self.sent_fields = logicview.add(self.sent_fields, 1)
    ::continue_6::
  end
  if logicview.truth((self.sent_fields >= upto)) then
    self.msg_complete = true
    self.sent_fields = 0
  end
  if logicview.truth((function()
  local _v
  _v = self.msg_complete
  if not logicview.truth(_v) then return _v end
  _v = self.bits_accum
  return _v
end)()) then
    self.failed = { "Excess data bits", "Excess" }
  end
end
function _decoder.handle_bits(self, ss, es, bits)
  logicview.extend(self.bits_accum, bits)
end
function _decoder.handle_frame(self, ss, es, value, valid)
  if logicview.truth((not logicview.truth(valid))) then
    self.failed = { "Invalid data", "Invalid" }
  end
  self:flush_accum_bits()
end
function _decoder.handle_idle(self, ss, es)
  local _
  if logicview.truth((function()
  local _v
  _v = self.bits_accum
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.failed))
  return _v
end)()) then
    self.failed = { "Unprocessed data bits", "Unprocessed" }
  end
  if logicview.truth((function()
  local _v
  _v = self.bits_accum
  if not logicview.truth(_v) then return _v end
  _v = self.failed
  return _v
end)()) then
    do
      local _lv_seq = self:get_ss_es_bits(nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
    end
    self:putg(ss, es, { Ann.WARN, self.failed })
  end
  self:reset()
end
function _decoder.handle_break(self, ss, es)
  local break_ss, break_es, text
  do
    local _lv_a0, _lv_a1 = ss, es
    break_ss = _lv_a0
    break_es = _lv_a1
  end
  if logicview.truth((not logicview.truth(self.failed))) then
    self.failed = { "BREAK condition", "Break" }
  end
  self:handle_idle(nil, nil)
  text = { "BREAK condition", "Break" }
  self:putg(ss, es, { Ann.WARN, text })
  self:reset()
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata, _, bits, value, valid
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      rxtx = logicview.idx(_lv_seq, 1)
      pdata = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "DATA")) then
      do
        local _lv_seq = pdata
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        _ = logicview.idx(_lv_seq, 0)
        bits = logicview.idx(_lv_seq, 1)
      end
      self:handle_bits(ss, es, bits)
    elseif logicview.truth(logicview.eq(ptype, "FRAME")) then
      do
        local _lv_seq = pdata
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        value = logicview.idx(_lv_seq, 0)
        valid = logicview.idx(_lv_seq, 1)
      end
      self:handle_frame(ss, es, value, valid)
    elseif logicview.truth(logicview.eq(ptype, "IDLE")) then
      self:handle_idle(ss, es)
    elseif logicview.truth(logicview.eq(ptype, "BREAK")) then
      self:handle_break(ss, es)
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
