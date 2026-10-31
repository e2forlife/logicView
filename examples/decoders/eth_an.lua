-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2021 Quard <2014500726@smail.xtu.edu.cn>

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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "eth_auto_negotiation",
  name = "ETH_AN",
  longname = "ETH Auto Negotiation",
  desc = "ETH Auto Negotiation protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "eth_an" },
  tags = { "PC" },
  channels = { logicview.dict({ id = "dp", name = "TX+", desc = "ETH TX+ signal" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "data", "FLP data" }, { "format", "format describe" }, { "bitd", "Bit desc" }, { "bit", "Bit" }, { "NLP", "Normal link pulses" } },
  annotation_rows = { { "data", "Data", { 0 } }, { "format", "Format", { 1 } }, { "bitd", "Bit desc", { 2 } }, { "bit", "Bit", { 3 } }, { "NLP", "NLP", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  do
    local _lv_chain = 0
    self.pre_ss = _lv_chain
    self.pre_es = _lv_chain
  end
  self.last_vaild_ss = 0
  self.samplerate = nil
  self.samplenum = 0
  self.hex = 0
  self.pre_hex = 0
  self.index = 0
  self.data_list = {  }
  self.state = "base page"
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.changeState(self)
  if logicview.truth((not logicview.eq(self.pre_hex, self.hex))) then
    if logicview.truth(logicview.eq(self.state, "base page")) then
      if logicview.truth(logicview.eq(((self.hex >> 14) & 3), 3)) then
        self.state = "base page ack"
      end
    elseif logicview.truth(logicview.eq(self.state, "base page ack")) then
      self.state = "next page"
    elseif logicview.truth(logicview.eq(self.state, "next page")) then
      if logicview.truth(logicview.eq(((self.hex >> 14) & 3), 1)) then
        self.state = "next page ack"
      end
    elseif logicview.truth(logicview.eq(self.state, "next page ack")) then
      self.state = "base page"
    end
  end
end
function _decoder.decodeTiming(self)
  local length, temp_length
  self:wait(logicview.dict({ [0] = "r" }))
  self.ss = self.samplenum
  self:wait(logicview.dict({ [0] = "e" }))
  self.es = self.samplenum
  length = ((_tonumber((self.es - self.ss)) or 0) / self.samplerate)
  if logicview.truth((function()
  local _v
  _v = (length <= 1e-05)
  if not logicview.truth(_v) then return _v end
  _v = (length >= 1e-06)
  return _v
end)()) then
    self:put(self.ss, self.es, self.out_ann, { 4, { "NLP" } })
    temp_length = (self.ss - self.last_vaild_ss)
    length = ((_tonumber(temp_length) or 0) / self.samplerate)
    self.last_vaild_ss = self.ss
    if logicview.truth((function()
  local _v
  _v = (length <= 7e-05)
  if not logicview.truth(_v) then return _v end
  _v = (length >= 6e-05)
  return _v
end)()) then
      self.hex = (self.hex | (1 << self.index))
      _table.insert(self.data_list, logicview.dict({ start = self.ss, ["end"] = self.es, ["Pre start"] = self.pre_ss, ["Pre end"] = self.pre_es }))
      self.index = logicview.add(self.index, 1)
      self.last_vaild_ss = 0
    elseif logicview.truth((function()
  local _v
  _v = (length <= 0.00014)
  if not logicview.truth(_v) then return _v end
  _v = (length >= 0.00012)
  return _v
end)()) then
      _table.insert(self.data_list, logicview.dict({ start = (self.ss - (temp_length >> 1)), ["end"] = (self.es - (temp_length >> 1)), ["Pre start"] = self.pre_ss, ["Pre end"] = self.pre_es }))
      self.index = logicview.add(self.index, 1)
    end
    self.pre_ss = self.ss
    self.pre_es = self.es
  end
end
function _decoder.decodeBasePage(self)
  local base_page_ta_dict, type_desc, i
  base_page_ta_dict = logicview.dict({ [5] = "10BaseT-HD", [6] = "10BaseT-FD", [7] = "100BaseTX-HD", [8] = "100BaseTX-FD", [9] = "100BaseT4", [10] = "FC", [11] = "AsyFC", [12] = "Reserved", [13] = "RF", [14] = "ACK", [15] = "NP" })
  if logicview.truth(logicview.eq((self.hex & 31), 1)) then
    type_desc = "802.3"
  elseif logicview.truth(logicview.eq((self.hex & 31), 2)) then
    type_desc = "802.9"
  else
    type_desc = "unknow"
  end
  for _lv_i in logicview.range(16) do
    i = _lv_i
    self:put(logicview.idx(logicview.idx(self.data_list, i), "Pre start"), logicview.idx(logicview.idx(self.data_list, i), "end"), self.out_ann, { 3, { _tostring(logicview.hex(((self.hex >> i) & 1))) } })
    if logicview.truth(logicview.contains((function() local _t = {}; for _k in _pairs(base_page_ta_dict) do _t[#_t + 1] = _k end; return _t end)(), i)) then
      self:put(logicview.idx(logicview.idx(self.data_list, i), "Pre start"), logicview.idx(logicview.idx(self.data_list, i), "end"), self.out_ann, { 2, { logicview.idx(base_page_ta_dict, i) } })
    end
    ::continue_1::
  end
  self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 15), "end"), self.out_ann, { 0, { logicview.add("base page:", _tostring(logicview.hex(self.hex))) } })
  self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 4), "end"), self.out_ann, { 1, { logicview.add("Selector field:", _tostring(logicview.hex((self.hex & 31)))) } })
  self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 4), "end"), self.out_ann, { 2, { type_desc } })
  self:put(logicview.idx(logicview.idx(self.data_list, 5), "Pre start"), logicview.idx(logicview.idx(self.data_list, 12), "end"), self.out_ann, { 1, { logicview.add("Technology ability field:", _tostring(logicview.hex(((self.hex >> 5) & 255)))) } })
  self:put(logicview.idx(logicview.idx(self.data_list, 13), "Pre start"), logicview.idx(logicview.idx(self.data_list, 15), "end"), self.out_ann, { 1, { logicview.add("Other fields:", _tostring(logicview.hex(((self.hex >> 13) & 7)))) } })
end
function _decoder.decodeNextPage(self)
  local next_page_ta_dict, next_page_ot_dict, mp, i
  next_page_ta_dict = logicview.dict({ [0] = "1000BaseT M/S CFG EN", [1] = "1000BaseT M/S CFG Vale", [2] = "Port type", [3] = "1000BaseT-FD", [4] = "1000BaseT-HD", [5] = "10GBaseT-FD", [6] = "10GBaseT M/S CFG EN", [7] = "10GBaseT M/S CFG Vale", [8] = "Reserved", [9] = "Reserved", [10] = "Reserved" })
  next_page_ot_dict = logicview.dict({ [11] = "T", [12] = "ACK2", [13] = "MP", [14] = "ACK", [15] = "NP" })
  if logicview.truth(logicview.eq(((self.hex >> 13) & 1), 1)) then
    mp = "Technology ability field:"
  else
    mp = "Unformatted code field:"
  end
  for _lv_i in logicview.range(16) do
    i = _lv_i
    self:put(logicview.idx(logicview.idx(self.data_list, i), "Pre start"), logicview.idx(logicview.idx(self.data_list, i), "end"), self.out_ann, { 3, { _tostring(logicview.hex(((self.hex >> i) & 1))) } })
    if logicview.truth(logicview.contains((function() local _t = {}; for _k in _pairs(next_page_ot_dict) do _t[#_t + 1] = _k end; return _t end)(), i)) then
      self:put(logicview.idx(logicview.idx(self.data_list, i), "Pre start"), logicview.idx(logicview.idx(self.data_list, i), "end"), self.out_ann, { 2, { logicview.idx(next_page_ot_dict, i) } })
    end
    if logicview.truth(logicview.eq(mp, "Technology ability field:")) then
      if logicview.truth(logicview.contains((function() local _t = {}; for _k in _pairs(next_page_ta_dict) do _t[#_t + 1] = _k end; return _t end)(), i)) then
        self:put(logicview.idx(logicview.idx(self.data_list, i), "Pre start"), logicview.idx(logicview.idx(self.data_list, i), "end"), self.out_ann, { 2, { logicview.idx(next_page_ta_dict, i) } })
      end
    end
    ::continue_2::
  end
  self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 15), "end"), self.out_ann, { 0, { logicview.add("next page:", _tostring(logicview.hex(self.hex))) } })
  self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 10), "end"), self.out_ann, { 1, { logicview.add(mp, _tostring(logicview.hex((self.hex & 2047)))) } })
  if logicview.truth(logicview.eq(mp, "Unformatted code field:")) then
    self:put(logicview.idx(logicview.idx(self.data_list, 0), "Pre start"), logicview.idx(logicview.idx(self.data_list, 10), "end"), self.out_ann, { 2, { "Master-Slave seed value (MSB)" } })
  end
  self:put(logicview.idx(logicview.idx(self.data_list, 11), "Pre start"), logicview.idx(logicview.idx(self.data_list, 15), "end"), self.out_ann, { 1, { logicview.add("Other fields:", _tostring(logicview.hex(((self.hex >> 11) & 31)))) } })
end
function _decoder.updateOnceDecode(self)
  self.pre_hex = self.hex
  self.data_list = {  }
  self.index = 0
  self.hex = 0
end
function _decoder.decode(self)
  while true do
    self:decodeTiming()
    if logicview.truth(logicview.eq(self.index, 16)) then
      self:changeState()
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "base page")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "base page ack")
  return _v
end)()) then
        self:decodeBasePage()
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "next page")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "next page ack")
  return _v
end)()) then
        self:decodeNextPage()
      end
      self:updateOnceDecode()
    end
    ::continue_3::
  end
end

return _decoder
