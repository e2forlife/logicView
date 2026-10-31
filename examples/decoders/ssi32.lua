-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2016 Robert Bosch Car Multimedia GmbH

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
  id = "ssi32",
  name = "SSI32",
  longname = "Synchronous Serial Interface (32bit)",
  desc = "Synchronous Serial Interface (32bit) protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "msgsize", desc = "Message size", default = 64, values = {  } }) },
  annotations = { { "ctrl-tx", "CTRL TX" }, { "ack-tx", "ACK TX" }, { "ctrl-rx", "CTRL RX" }, { "ack-rx", "ACK RX" } },
  annotation_rows = { { "tx", "TX", { 0, 1 } }, { "rx", "RX", { 2, 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self.mosi_bytes = {  }
  self.miso_bytes = {  }
  self.es_array = {  }
  self.rx_size = 0
  self.tx_size = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.reset_data(self)
  self.mosi_bytes = {  }
  self.miso_bytes = {  }
  self.es_array = {  }
end
function _decoder.handle_ack(self)
  self.es_cmd = logicview.idx(self.es_array, 0)
  self:putx({ 1, { logicview.pymod("> ACK:0x%02x", logicview.idx(self.mosi_bytes, 0)) } })
  self:putx({ 3, { logicview.pymod("< ACK:0x%02x", logicview.idx(self.miso_bytes, 0)) } })
end
function _decoder.handle_ctrl(self)
  local mosi, miso
  do
    local _lv_chain = ""
    mosi = _lv_chain
    miso = _lv_chain
  end
  self.tx_size = logicview.idx(self.mosi_bytes, 2)
  self.rx_size = logicview.idx(self.miso_bytes, 2)
  if logicview.truth((self.tx_size > 0)) then
    mosi = logicview.add(", DATA:0x", logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.mosi_bytes, 4, logicview.add(self.tx_size, 4), nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(x, "02x")
  end
  return _lv_out
end)()))
  end
  if logicview.truth((self.rx_size > 0)) then
    miso = logicview.add(", DATA:0x", logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.miso_bytes, 4, logicview.add(self.rx_size, 4), nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.format(x, "02x")
  end
  return _lv_out
end)()))
  end
  self.es_cmd = logicview.idx(self.es_array, logicview.add(self.tx_size, 3))
  self:putx({ 0, { logicview.pymod("> CTRL:0x%02x, LUN:0x%02x, SIZE:0x%02x, CRC:0x%02x%s", { logicview.idx(self.mosi_bytes, 0), logicview.idx(self.mosi_bytes, 1), logicview.idx(self.mosi_bytes, 2), logicview.idx(self.mosi_bytes, 3), mosi }) } })
  self.es_cmd = logicview.idx(self.es_array, logicview.add(self.rx_size, 3))
  self:putx({ 2, { logicview.pymod("< CTRL:0x%02x, LUN:0x%02x, SIZE:0x%02x, CRC:0x%02x%s", { logicview.idx(self.miso_bytes, 0), logicview.idx(self.miso_bytes, 1), logicview.idx(self.miso_bytes, 2), logicview.idx(self.miso_bytes, 3), miso }) } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso
    ptype = logicview.idx(data, 0)
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      self:reset_data()
      return
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_seq = logicview.slice(data, 1, nil, nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      mosi = logicview.idx(_lv_seq, 0)
      miso = logicview.idx(_lv_seq, 1)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 0)) then
      self.ss_cmd = ss
    end
    _table.insert(self.mosi_bytes, mosi)
    _table.insert(self.miso_bytes, miso)
    _table.insert(self.es_array, es)
    if logicview.truth((logicview.idx(self.mosi_bytes, 0) & 128)) then
      if logicview.truth((logicview.len(self.mosi_bytes) < 4)) then
        return
      end
      self:handle_ack()
      self:reset_data()
    else
      if logicview.truth((logicview.len(self.mosi_bytes) < logicview.idx(self.options, "msgsize"))) then
        return
      end
      self:handle_ctrl()
      self:reset_data()
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
