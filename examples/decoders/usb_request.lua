-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Stefan Brüns <stefan.bruens@rwth-aachen.de>

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
local struct, SamplerateError, pcap_usb_pkt, Decoder
local _decoder

struct = logicview.struct
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
pcap_usb_pkt = {}
pcap_usb_pkt.__index = pcap_usb_pkt
pcap_usb_pkt.h = "\x00\x00\x00\x00"
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x43")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x03")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x2d")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x3c")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
pcap_usb_pkt.h = logicview.add(pcap_usb_pkt.h, "\x00\x00\x00\x00")
function pcap_usb_pkt.__init__(self, req, ts, is_submit)
  self.header = logicview.bytes(pcap_usb_pkt.h)
  self.data = ""
  self:set_urbid(logicview.idx(req, "id"))
  self:set_urbtype((function() if logicview.truth(is_submit) then return "S" else return "C" end end)())
  self:set_timestamp(ts)
  self:set_addr_ep(logicview.idx(req, "addr"), logicview.idx(req, "ep"))
  if logicview.truth(logicview.contains({ "SETUP IN", "SETUP OUT" }, logicview.idx(req, "type"))) then
    self:set_transfertype(2)
    self:set_setup(logicview.idx(req, "setup_data"))
  end
  if logicview.truth(logicview.contains("BULK IN", logicview.idx(req, "type"))) then
    self:set_addr_ep(logicview.idx(req, "addr"), (128 | logicview.idx(req, "ep")))
  end
  self:set_data(logicview.idx(req, "data"))
end
function pcap_usb_pkt.set_urbid(self, urbid)
  self.header = (function() local _t, _mid = self.header, struct.pack(">I", urbid); local _head = logicview.slice(_t, 0, 4, 1); local _tail = logicview.slice(_t, 8, nil, 1); if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; return _head .. _mid .. _tail end; logicview.list_clear(_t); logicview.extend(_t, _head); if _type(_mid) == 'string' then local _bytes = {}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()
end
function pcap_usb_pkt.set_urbtype(self, urbtype)
  logicview.setidx(self.header, 8, _string.byte(urbtype))
end
function pcap_usb_pkt.set_transfertype(self, transfertype)
  logicview.setidx(self.header, 9, transfertype)
end
function pcap_usb_pkt.set_addr_ep(self, addr, ep)
  logicview.setidx(self.header, 11, addr)
  logicview.setidx(self.header, 10, ep)
end
function pcap_usb_pkt.set_timestamp(self, ts)
  self.timestamp = ts
  self.header = (function() local _t, _mid = self.header, struct.pack(">I", logicview.idx(ts, 0)); local _head = logicview.slice(_t, 0, 20, 1); local _tail = logicview.slice(_t, 24, nil, 1); if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; return _head .. _mid .. _tail end; logicview.list_clear(_t); logicview.extend(_t, _head); if _type(_mid) == 'string' then local _bytes = {}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()
  self.header = (function() local _t, _mid = self.header, struct.pack(">I", logicview.idx(ts, 1)); local _head = logicview.slice(_t, 0, 24, 1); local _tail = logicview.slice(_t, 28, nil, 1); if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; return _head .. _mid .. _tail end; logicview.list_clear(_t); logicview.extend(_t, _head); if _type(_mid) == 'string' then local _bytes = {}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()
end
function pcap_usb_pkt.set_data(self, data)
  self.data = data
  logicview.setidx(self.header, 15, 0)
  self.header = (function() local _t, _mid = self.header, struct.pack(">I", logicview.len(data)); local _head = logicview.slice(_t, 0, 36, 1); local _tail = logicview.slice(_t, 40, nil, 1); if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; return _head .. _mid .. _tail end; logicview.list_clear(_t); logicview.extend(_t, _head); if _type(_mid) == 'string' then local _bytes = {}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()
end
function pcap_usb_pkt.set_setup(self, data)
  logicview.setidx(self.header, 14, 0)
  self.header = (function() local _t, _mid = self.header, data; local _head = logicview.slice(_t, 0, 40, 1); local _tail = logicview.slice(_t, 48, nil, 1); if _type(_t) == 'string' then if _type(_mid) ~= 'string' then _mid = logicview.bytes(_mid) end; return _head .. _mid .. _tail end; logicview.list_clear(_t); logicview.extend(_t, _head); if _type(_mid) == 'string' then local _bytes = {}; for _i = 1, #_mid do _bytes[_i] = _mid:byte(_i) end; logicview.extend(_t, _bytes) else logicview.extend(_t, _mid) end; logicview.extend(_t, _tail); return _t end)()
end
function pcap_usb_pkt.packet(self)
  return logicview.add(logicview.bytes(self.header), logicview.bytes(self.data))
end
function pcap_usb_pkt.record_header(self)
  local secs, usecs, h
  do
    local _lv_seq = self.timestamp
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    secs = logicview.idx(_lv_seq, 0)
    usecs = logicview.idx(_lv_seq, 1)
  end
  h = struct.pack(">I", secs)
  h = logicview.add(h, struct.pack(">I", usecs))
  h = logicview.add(h, struct.pack(">I", logicview.len(self)))
  h = logicview.add(h, struct.pack(">I", logicview.len(self)))
  return h
end
function pcap_usb_pkt.__len(self)
  return logicview.add(64, logicview.len(self.data))
end
function pcap_usb_pkt.new(...)
  local self = _setmetatable({}, pcap_usb_pkt)
  pcap_usb_pkt.__init__(self, ...)
  return self
end
_decoder = {
  api_version = 3,
  id = "usb_request",
  name = "USB request",
  longname = "Universal Serial Bus (LS/FS) transaction/request",
  desc = "USB (low-speed/full-speed) transaction/request protocol.",
  license = "gplv2+",
  inputs = { "usb_packet" },
  outputs = { "usb_request" },
  tags = { "PC" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "in_request_start", desc = "Start IN requests on", default = "submit", values = { "submit", "first-ack" } }) },
  annotations = { { "request-setup-read", "Setup: Device-to-host" }, { "request-setup-write", "Setup: Host-to-device" }, { "request-bulk-read", "Bulk: Device-to-host" }, { "request-bulk-write", "Bulk: Host-to-device" }, { "error", "Unexpected packet" } },
  annotation_rows = { { "request-setup", "USB SETUP", { 0, 1 } }, { "request-in", "USB BULK IN", { 2 } }, { "request-out", "USB BULK OUT", { 3 } }, { "errors", "Errors", { 4 } } },
  binary = { { "pcap", "PCAP format" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.request = logicview.dict({  })
  self.request_id = 0
  self.transaction_state = "IDLE"
  self.ss_transaction = nil
  self.es_transaction = nil
  self.transaction_ep = nil
  self.transaction_addr = nil
  self.wrote_pcap_header = false
end
function _decoder.putr(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putb(self, ts, data)
  self:put(ts, ts, self.out_binary, data)
end
function _decoder.pcap_global_header(self)
  local h
  h = "\xa1\xb2\xc3\xd4"
  h = logicview.add(h, "\x00\x02")
  h = logicview.add(h, "\x00\x04")
  h = logicview.add(h, "\x00\x00\x00\x00")
  h = logicview.add(h, "\x00\x00\x00\x00")
  h = logicview.add(h, "\xff\xff\xff\xff")
  h = logicview.add(h, "\x00\x00\x00\xdc")
  return h
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    if logicview.truth(self.samplerate) then
      self.secs_per_sample = ((_tonumber(1) or 0) / (_tonumber(self.samplerate) or 0))
    end
  end
end
function _decoder.start(self)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.in_request_start = logicview.idx(self.options, "in_request_start")
end
function _decoder.handle_transfer(self)
  local request_started, request_end, ep, addr, request
  request_started = 0
  request_end = logicview.contains({ "ACK", "STALL", "timeout" }, self.handshake)
  ep = self.transaction_ep
  addr = self.transaction_addr
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.transaction_type, "SETUP")
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains(self.request, { addr, ep })
  return _v
end)()) then
    request = logicview.idx(self.request, logicview.tkey(addr, ep))
    if logicview.truth(logicview.contains({ "SETUP IN", "SETUP OUT" }, logicview.idx(request, "type"))) then
      logicview.setidx(request, "es", self.ss_transaction)
      self:handle_request(0, 1)
    end
  end
  if logicview.truth((not logicview.truth(logicview.contains(self.request, { addr, ep })))) then
    logicview.setidx(self.request, logicview.tkey(addr, ep), logicview.dict({ setup_data = {  }, data = {  }, type = nil, ss = self.ss_transaction, es = nil, ss_data = nil, id = self.request_id, addr = addr, ep = ep }))
    self.request_id = logicview.add(self.request_id, 1)
    request_started = 1
  end
  request = logicview.idx(self.request, logicview.tkey(addr, ep))
  if logicview.truth(request_end) then
    logicview.setidx(request, "es", self.es_transaction)
    logicview.setidx(request, "handshake", self.handshake)
  end
  if logicview.truth((function()
  local _v
  _v = logicview.contains({ nil, "BULK IN" }, logicview.idx(request, "type"))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "IN")
  return _v
end)()) then
    logicview.setidx(request, "type", "BULK IN")
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.len(logicview.idx(request, "data")), 0)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.transaction_data) > 0)
  return _v
end)()) then
      logicview.setidx(request, "ss_data", self.ss_transaction)
    end
    logicview.setidx(request, "data", logicview.add(logicview.idx(request, "data"), self.transaction_data))
    self:handle_request(request_started, request_end)
  elseif logicview.truth((function()
  local _v
  _v = logicview.contains({ nil, "BULK OUT" }, logicview.idx(request, "type"))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "OUT")
  return _v
end)()) then
    logicview.setidx(request, "type", "BULK OUT")
    if logicview.truth(logicview.eq(self.handshake, "ACK")) then
      logicview.setidx(request, "data", logicview.add(logicview.idx(request, "data"), self.transaction_data))
    end
    self:handle_request(request_started, request_end)
  elseif logicview.truth((function()
  local _v
  _v = (logicview.idx(request, "type") == nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "SETUP")
  return _v
end)()) then
    logicview.setidx(request, "setup_data", self.transaction_data)
    logicview.setidx(request, "wLength", logicview.idx(struct.unpack("<H", logicview.bytes(logicview.slice(self.transaction_data, 6, 8, nil))), 0))
    if logicview.truth((logicview.idx(self.transaction_data, 0) & 128)) then
      logicview.setidx(request, "type", "SETUP IN")
      self:handle_request(1, 0)
    else
      logicview.setidx(request, "type", "SETUP OUT")
      self:handle_request(logicview.eq(logicview.idx(request, "wLength"), 0), 0)
    end
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(request, "type"), "SETUP IN")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "IN")
  return _v
end)()) then
    logicview.setidx(request, "data", logicview.add(logicview.idx(request, "data"), self.transaction_data))
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(request, "type"), "SETUP OUT")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "OUT")
  return _v
end)()) then
    if logicview.truth(logicview.eq(self.handshake, "ACK")) then
      logicview.setidx(request, "data", logicview.add(logicview.idx(request, "data"), self.transaction_data))
    end
    if logicview.truth(logicview.eq(logicview.idx(request, "wLength"), logicview.len(logicview.idx(request, "data")))) then
      self:handle_request(1, 0)
    end
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(request, "type"), "SETUP IN")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "OUT")
  return _v
end)()) then
    self:handle_request(0, request_end)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(request, "type"), "SETUP OUT")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.transaction_type, "IN")
  return _v
end)()) then
    self:handle_request(0, request_end)
  else
    return
  end
  return
end
function _decoder.ts_from_samplenum(self, sample)
  local ts
  ts = logicview.mul((_tonumber(sample) or 0), self.secs_per_sample)
  return { logicview.tointeger(ts), logicview.tointeger(logicview.mul(logicview.pymod(ts, 1.0), 1000000.0)) }
end
function _decoder.write_pcap_header(self)
  if logicview.truth((not logicview.truth(self.wrote_pcap_header))) then
    self:put(0, 0, self.out_binary, { 0, self:pcap_global_header() })
    self.wrote_pcap_header = true
  end
end
function _decoder.request_summary(self, request)
  local s, b
  s = "["
  if logicview.truth(logicview.contains({ "SETUP IN", "SETUP OUT" }, logicview.idx(request, "type"))) then
    for _lv_item in logicview.iter(logicview.idx(request, "setup_data")) do
      b = _lv_item
      s = logicview.add(s, logicview.pymod(" %02X", b))
      ::continue_1::
    end
    s = logicview.add(s, " ][")
  end
  for _lv_item in logicview.iter(logicview.idx(request, "data")) do
    b = _lv_item
    s = logicview.add(s, logicview.pymod(" %02X", b))
    ::continue_2::
  end
  s = logicview.add(s, logicview.pymod(" ] : %s", logicview.idx(request, "handshake")))
  return s
end
function _decoder.handle_request(self, request_start, request_end)
  local ep, addr, request, ss, es, ss_data, ts, pkt, summary
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(request_start, 1))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(request_end, 1))
  return _v
end)()) then
    return
  end
  self:write_pcap_header()
  ep = self.transaction_ep
  addr = self.transaction_addr
  request = logicview.idx(self.request, logicview.tkey(addr, ep))
  do
    local _lv_a0, _lv_a1, _lv_a2 = logicview.idx(request, "ss"), logicview.idx(request, "es"), logicview.idx(request, "ss_data")
    ss = _lv_a0
    es = _lv_a1
    ss_data = _lv_a2
  end
  if logicview.truth(logicview.eq(self.in_request_start, "submit")) then
    ss_data = ss
  end
  if logicview.truth(logicview.eq(request_start, 1)) then
    ts = self:ts_from_samplenum(ss)
    pkt = pcap_usb_pkt.new(request, ts, true)
    self:putb(ss, { 0, pkt:record_header() })
    self:putb(ss, { 0, pkt:packet() })
  end
  if logicview.truth(logicview.eq(request_end, 1)) then
    summary = self:request_summary(request)
    if logicview.truth(logicview.eq(logicview.idx(request, "type"), "SETUP IN")) then
      self:putr(ss, es, { 0, { logicview.pymod("SETUP in: %s", summary) } })
    elseif logicview.truth(logicview.eq(logicview.idx(request, "type"), "SETUP OUT")) then
      self:putr(ss, es, { 1, { logicview.pymod("SETUP out: %s", summary) } })
    elseif logicview.truth(logicview.eq(logicview.idx(request, "type"), "BULK IN")) then
      self:putr(ss_data, es, { 2, { logicview.pymod("BULK in: %s", summary) } })
    elseif logicview.truth(logicview.eq(logicview.idx(request, "type"), "BULK OUT")) then
      self:putr(ss, es, { 3, { logicview.pymod("BULK out: %s", summary) } })
    end
    ts = self:ts_from_samplenum(es)
    pkt = pcap_usb_pkt.new(request, ts, false)
    self:putb(ss, { 0, pkt:record_header() })
    self:putb(ss, { 0, pkt:packet() })
    logicview.setidx(self.request, logicview.tkey(addr, ep), nil)
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, pdata, pcategory, pname, pinfo, transaction_timeout, sync, pid, addr, ep, crc5
    if logicview.truth((not logicview.truth(self.samplerate))) then
      _error(SamplerateError("Cannot decode without samplerate."), 0)
    end
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      pdata = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((not logicview.contains("PACKET", ptype))) then
      return
    end
    do
      local _lv_seq = pdata
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      pcategory = logicview.idx(_lv_seq, 0)
      pname = logicview.idx(_lv_seq, 1)
      pinfo = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(pcategory, "TOKEN")) then
      if logicview.truth(logicview.eq(pname, "SOF")) then
        return
      end
      if logicview.truth(logicview.eq(self.transaction_state, "TOKEN RECEIVED")) then
        transaction_timeout = self.es_transaction
        transaction_timeout = logicview.add(transaction_timeout, logicview.tointeger(((self.es_transaction - self.ss_transaction) / 2)))
        if logicview.truth((ss > transaction_timeout)) then
          self.es_transaction = transaction_timeout
          self.handshake = "timeout"
          self:handle_transfer()
          self.transaction_state = "IDLE"
        end
      end
      if logicview.truth((not logicview.eq(self.transaction_state, "IDLE"))) then
        self:putr(ss, es, { 4, { logicview.pymod("ERR: received %s token in state %s", { pname, self.transaction_state }) } })
        return
      end
      do
        local _lv_seq = pinfo
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        sync = logicview.idx(_lv_seq, 0)
        pid = logicview.idx(_lv_seq, 1)
        addr = logicview.idx(_lv_seq, 2)
        ep = logicview.idx(_lv_seq, 3)
        crc5 = logicview.idx(_lv_seq, 4)
      end
      self.transaction_data = {  }
      self.ss_transaction = ss
      self.es_transaction = es
      self.transaction_state = "TOKEN RECEIVED"
      self.transaction_ep = ep
      if logicview.truth((function()
  local _v
  _v = (ep > 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(pname, "IN")
  return _v
end)()) then
        self.transaction_ep = logicview.add(ep, 128)
      end
      self.transaction_addr = addr
      self.transaction_type = pname
    elseif logicview.truth(logicview.eq(pcategory, "DATA")) then
      if logicview.truth((not logicview.eq(self.transaction_state, "TOKEN RECEIVED"))) then
        self:putr(ss, es, { 4, { logicview.pymod("ERR: received %s token in state %s", { pname, self.transaction_state }) } })
        return
      end
      self.transaction_data = logicview.idx(pinfo, 2)
      self.transaction_state = "DATA RECEIVED"
    elseif logicview.truth(logicview.eq(pcategory, "HANDSHAKE")) then
      if logicview.truth((not logicview.contains({ "TOKEN RECEIVED", "DATA RECEIVED" }, self.transaction_state))) then
        self:putr(ss, es, { 4, { logicview.pymod("ERR: received %s token in state %s", { pname, self.transaction_state }) } })
        return
      end
      self.handshake = pname
      self.transaction_state = "IDLE"
      self.es_transaction = es
      self:handle_transfer()
    elseif logicview.truth(logicview.eq(pname, "PRE")) then
      return
    else
      self:putr(ss, es, { 4, { logicview.pymod("ERR: received unhandled %s token in state %s", { pname, self.transaction_state }) } })
      return
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
