-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2013 Uwe Hermann <uwe@hermann-uwe.de>

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
local RX, TX, Decoder
local _decoder

RX = 0
TX = 1
_decoder = {
  api_version = 3,
  id = "pan1321",
  name = "PAN1321",
  longname = "Panasonic PAN1321",
  desc = "Bluetooth RF module with Serial Port Profile (SPP).",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text-verbose", "Human-readable text (verbose)" }, { "text", "Human-readable text" }, { "warnings", "Human-readable warnings" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.cmd = { "", "" }
  self.ss_block = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.handle_host_command(self, rxtx, s)
  local p, x, onoff, l, d, b, pin, name
  if logicview.truth(logicview.startswith(s, "AT+JAAC")) then
    p = logicview.slice(s, logicview.add(logicview.find(s, "="), 1), nil, nil)
    if logicview.truth((not logicview.contains({ "0", "1" }, p))) then
      self:putx({ 2, { logicview.pymod("Warning: Invalid JAAC parameter \"%s\"", p) } })
      return
    end
    x = (function() if logicview.truth(logicview.eq(p, "1")) then return "Auto" else return "Don't auto" end end)()
    self:putx({ 0, { logicview.pymod("%s-accept new connections", x) } })
    self:putx({ 1, { logicview.pymod("%s-accept connections", x) } })
  elseif logicview.truth(logicview.startswith(s, "AT+JPRO")) then
    p = logicview.slice(s, logicview.add(logicview.find(s, "="), 1), nil, nil)
    if logicview.truth((not logicview.contains({ "0", "1" }, p))) then
      self:putx({ 2, { logicview.pymod("Warning: Invalid JPRO parameter \"%s\"", p) } })
      return
    end
    onoff = (function() if logicview.truth(logicview.eq(p, "0")) then return "off" else return "on" end end)()
    x = (function() if logicview.truth(logicview.eq(p, "0")) then return "Leaving" else return "Entering" end end)()
    self:putx({ 0, { logicview.pymod("%s production mode", x) } })
    self:putx({ 1, { logicview.pymod("Production mode = %s", onoff) } })
  elseif logicview.truth(logicview.startswith(s, "AT+JRES")) then
    if logicview.truth((not logicview.eq(s, "AT+JRES"))) then
      self:putx({ 2, { "Warning: Invalid JRES usage." } })
      return
    end
    self:putx({ 0, { "Triggering a software reset" } })
    self:putx({ 1, { "Reset" } })
  elseif logicview.truth(logicview.startswith(s, "AT+JSDA")) then
    do
      local _lv_seq = logicview.split(logicview.slice(s, logicview.add(logicview.find(s, "="), 1), nil, nil), ",", nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      l = logicview.idx(_lv_seq, 0)
      d = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((not logicview.truth(l:isnumeric()))) then
      self:putx({ 2, { logicview.pymod("Warning: Invalid data length \"%s\".", l) } })
    end
    if logicview.truth((not logicview.eq(logicview.tointeger(l), logicview.len(d)))) then
      self:putx({ 2, { logicview.pymod("Warning: Data length mismatch (%d != %d).", { logicview.tointeger(l), logicview.len(d) }) } })
    end
    b = logicview.slice(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(d) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02x ", _string.byte(c))
  end
  return _lv_out
end)()), nil, (-1), nil)
    self:putx({ 0, { logicview.pymod("Sending %d data bytes: %s", { logicview.tointeger(l), b }) } })
    self:putx({ 1, { logicview.pymod("Send %d = %s", { logicview.tointeger(l), b }) } })
  elseif logicview.truth(logicview.startswith(s, "AT+JSEC")) then
    pin = logicview.slice(s, (-4), nil, nil)
    self:putx({ 0, { logicview.add(logicview.add("Host set the Bluetooth PIN to \"", pin), "\"") } })
    self:putx({ 1, { logicview.add("PIN = ", pin) } })
  elseif logicview.truth(logicview.startswith(s, "AT+JSLN")) then
    name = logicview.slice(s, logicview.add(logicview.find(s, ","), 1), nil, nil)
    self:putx({ 0, { logicview.add(logicview.add("Host set the Bluetooth name to \"", name), "\"") } })
    self:putx({ 1, { logicview.add("BT name = ", name) } })
  else
    self:putx({ 0, { logicview.pymod("Host sent unsupported command: %s", s) } })
    self:putx({ 1, { logicview.pymod("Unsupported command: %s", s) } })
  end
end
function _decoder.handle_device_reply(self, rxtx, s)
  local error
  if logicview.truth(logicview.eq(s, "ROK")) then
    self:putx({ 0, { "Device initialized correctly" } })
    self:putx({ 1, { "Init" } })
  elseif logicview.truth(logicview.eq(s, "OK")) then
    self:putx({ 0, { "Device acknowledged last command" } })
    self:putx({ 1, { "ACK" } })
  elseif logicview.truth(logicview.startswith(s, "ERR")) then
    error = logicview.slice(s, logicview.add(logicview.find(s, "="), 1), nil, nil)
    self:putx({ 0, { logicview.add("Device sent error code ", error) } })
    self:putx({ 1, { logicview.add("ERR = ", error) } })
  else
    self:putx({ 0, { logicview.pymod("Device sent an unknown reply: %s", s) } })
    self:putx({ 1, { logicview.pymod("Unknown reply: %s", s) } })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata
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
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    pdata = logicview.idx(pdata, 0)
    if logicview.truth(logicview.eq(logicview.idx(self.cmd, rxtx), "")) then
      self.ss_block = ss
    end
    logicview.setidx(self.cmd, rxtx, logicview.add(logicview.idx(self.cmd, rxtx), _string.char(pdata)))
    if logicview.truth((not logicview.eq(logicview.slice(logicview.idx(self.cmd, rxtx), (-2), nil, nil), "\r\n"))) then
      return
    end
    self.es_block = es
    if logicview.truth(logicview.eq(rxtx, RX)) then
      self:handle_device_reply(rxtx, logicview.slice(logicview.idx(self.cmd, rxtx), nil, (-2), nil))
    elseif logicview.truth(logicview.eq(rxtx, TX)) then
      self:handle_host_command(rxtx, logicview.slice(logicview.idx(self.cmd, rxtx), nil, (-2), nil))
    end
    logicview.setidx(self.cmd, rxtx, "")
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
