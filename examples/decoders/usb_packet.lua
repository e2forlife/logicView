-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011 Gareth McMullin <gareth@blacksphere.co.nz>
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>

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
local pids, get_category, ann_index, bitstr_to_num, reverse_number, calc_crc5, calc_crc16, Decoder
local _decoder

pids = logicview.dict({ ["10000111"] = { "OUT", "Address & EP number in host-to-function transaction" }, ["10010110"] = { "IN", "Address & EP number in function-to-host transaction" }, ["10100101"] = { "SOF", "Start-Of-Frame marker & frame number" }, ["10110100"] = { "SETUP", "Address & EP number in host-to-function transaction for SETUP to a control pipe" }, ["11000011"] = { "DATA0", "Data packet PID even" }, ["11010010"] = { "DATA1", "Data packet PID odd" }, ["11100001"] = { "DATA2", "Data packet PID HS, high bandwidth isosynchronous transaction in a microframe" }, ["11110000"] = { "MDATA", "Data packet PID HS for split and high-bandwidth isosynchronous transactions" }, ["01001011"] = { "ACK", "Receiver accepts error-free packet" }, ["01011010"] = { "NAK", "Receiver cannot accept or transmitter cannot send" }, ["01111000"] = { "STALL", "EP halted or control pipe request unsupported" }, ["01101001"] = { "NYET", "No response yet from receiver" }, ["00111100"] = { "PRE", "Host-issued preamble; enables downstream bus traffic to low-speed devices" }, ["00011110"] = { "SPLIT", "HS split transaction token" }, ["00101101"] = { "PING", "HS flow control probe for a bulk/control EP" }, ["00001111"] = { "Reserved", "Reserved PID" } })
get_category = function(pidname)
  if logicview.truth(logicview.contains({ "OUT", "IN", "SOF", "SETUP" }, pidname)) then
    return "TOKEN"
  elseif logicview.truth(logicview.contains({ "DATA0", "DATA1", "DATA2", "MDATA" }, pidname)) then
    return "DATA"
  elseif logicview.truth(logicview.contains({ "ACK", "NAK", "STALL", "NYET" }, pidname)) then
    return "HANDSHAKE"
  else
    return "SPECIAL"
  end
end
ann_index = function(pidname)
  local l
  l = { "OUT", "IN", "SOF", "SETUP", "DATA0", "DATA1", "DATA2", "MDATA", "ACK", "NAK", "STALL", "NYET", "PRE", "ERR", "SPLIT", "PING", "Reserved" }
  if logicview.truth((not logicview.contains(l, pidname))) then
    return 28
  end
  return logicview.add((function() if _type(l) == 'string' then local _n = logicview.find(l, pidname); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(l, pidname) end)(), 11)
end
bitstr_to_num = function(bitstr)
  local l
  if logicview.truth((not logicview.truth(bitstr))) then
    return 0
  end
  l = logicview.copy(bitstr)
  logicview.list_reverse(l)
  return logicview.tointeger(logicview.join("", l), 2)
end
reverse_number = function(num, count)
  local out, i
  out = logicview.copy(logicview.mul(count, "0"))
  for _lv_i in logicview.range(0, count) do
    i = _lv_i
    if logicview.truth(((num >> i) & 1)) then
      logicview.setidx(out, i, "1")
    end
    ::continue_1::
  end
  return logicview.tointeger(logicview.join("", out), 2)
end
calc_crc5 = function(bitstr)
  local poly5, crc5, bit
  poly5 = 37
  crc5 = 31
  for _lv_item in logicview.iter(bitstr) do
    bit = _lv_item
    crc5 = (crc5 << 1)
    if logicview.truth((not logicview.eq(logicview.tointeger(bit), (crc5 >> 5)))) then
      crc5 = (crc5 ~ poly5)
    end
    crc5 = (crc5 & 31)
    ::continue_2::
  end
  crc5 = (crc5 ~ 31)
  return reverse_number(crc5, 5)
end
calc_crc16 = function(bitstr)
  local poly16, crc16, bit
  poly16 = 98309
  crc16 = 65535
  for _lv_item in logicview.iter(bitstr) do
    bit = _lv_item
    crc16 = (crc16 << 1)
    if logicview.truth((not logicview.eq(logicview.tointeger(bit), (crc16 >> 16)))) then
      crc16 = (crc16 ~ poly16)
    end
    crc16 = (crc16 & 65535)
    ::continue_3::
  end
  crc16 = (crc16 ~ 65535)
  return reverse_number(crc16, 16)
end
_decoder = {
  api_version = 3,
  id = "usb_packet",
  name = "USB packet",
  longname = "Universal Serial Bus (LS/FS) packet",
  desc = "USB (low-speed and full-speed) packet protocol.",
  license = "gplv2+",
  inputs = { "usb_signalling" },
  outputs = { "usb_packet" },
  tags = { "PC" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "signalling", desc = "Signalling", default = "full-speed", values = { "full-speed", "low-speed" } }) },
  annotations = { { "sync-ok", "SYNC" }, { "sync-err", "SYNC (error)" }, { "pid", "PID" }, { "framenum", "FRAMENUM" }, { "addr", "ADDR" }, { "ep", "EP" }, { "crc5-ok", "CRC5" }, { "crc5-err", "CRC5 (error)" }, { "data", "DATA" }, { "crc16-ok", "CRC16" }, { "crc16-err", "CRC16 (error)" }, { "packet-out", "Packet: OUT" }, { "packet-in", "Packet: IN" }, { "packet-sof", "Packet: SOF" }, { "packet-setup", "Packet: SETUP" }, { "packet-data0", "Packet: DATA0" }, { "packet-data1", "Packet: DATA1" }, { "packet-data2", "Packet: DATA2" }, { "packet-mdata", "Packet: MDATA" }, { "packet-ack", "Packet: ACK" }, { "packet-nak", "Packet: NAK" }, { "packet-stall", "Packet: STALL" }, { "packet-nyet", "Packet: NYET" }, { "packet-pre", "Packet: PRE" }, { "packet-err", "Packet: ERR" }, { "packet-split", "Packet: SPLIT" }, { "packet-ping", "Packet: PING" }, { "packet-reserved", "Packet: Reserved" }, { "packet-invalid", "Packet: Invalid" } },
  annotation_rows = { { "fields", "Packet fields", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } }, { "packet", "Packets", { 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bits = {  }
  self.packet = {  }
  self.packet_summary = ""
  do
    local _lv_chain = nil
    self.ss = _lv_chain
    self.es = _lv_chain
  end
  do
    local _lv_chain = nil
    self.ss_packet = _lv_chain
    self.es_packet = _lv_chain
  end
  self.state = "WAIT FOR SOP"
end
function _decoder.putpb(self, data)
  self:put(self.ss, self.es, self.out_python, data)
end
function _decoder.putb(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putpp(self, data)
  self:put(self.ss_packet, self.es_packet, self.out_python, data)
end
function _decoder.putp(self, data)
  self:put(self.ss_packet, self.es_packet, self.out_ann, data)
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.handle_packet(self)
  local packet, bit, ss, es, sync, pid, pidname, framenum, addr, ep, crc5, crc5_calc, data, databytes, i, db, crc16, crc16_calc, pcategory, pname, pinfo
  packet = ""
  for _lv_item in logicview.iter(self.bits) do
    bit = logicview.idx(_lv_item, 0)
    ss = logicview.idx(_lv_item, 1)
    es = logicview.idx(_lv_item, 2)
    packet = logicview.add(packet, bit)
    ::continue_4::
  end
  if logicview.truth((logicview.len(packet) < 8)) then
    self:putp({ 28, { "Invalid packet (shorter than 8 bits)" } })
    return
  end
  sync = logicview.slice(packet, nil, logicview.add(7, 1), nil)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 0), 1), logicview.idx(logicview.idx(self.bits, 7), 2)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  if logicview.truth((not logicview.eq(sync, "00000001"))) then
    self:putpb({ "SYNC ERROR", sync })
    self:putb({ 1, { logicview.pymod("SYNC ERROR: %s", sync), logicview.pymod("SYNC ERR: %s", sync), "SYNC ERR", "SE", "S" } })
  else
    self:putpb({ "SYNC", sync })
    self:putb({ 0, { logicview.pymod("SYNC: %s", sync), "SYNC", "S" } })
  end
  _table.insert(self.packet, sync)
  if logicview.truth((logicview.len(packet) < 16)) then
    self:putp({ 28, { "Invalid packet (shorter than 16 bits)" } })
    return
  end
  pid = logicview.slice(packet, 8, logicview.add(15, 1), nil)
  pidname = logicview.idx(logicview.dget(pids, pid, { "UNKNOWN", "Unknown PID" }), 0)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 8), 1), logicview.idx(logicview.idx(self.bits, 15), 2)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self:putpb({ "PID", pidname })
  self:putb({ 2, { logicview.pymod("PID: %s", pidname), pidname, logicview.idx(pidname, 0) } })
  _table.insert(self.packet, pid)
  self.packet_summary = logicview.add(self.packet_summary, pidname)
  if logicview.truth(logicview.contains({ "OUT", "IN", "SOF", "SETUP", "PING" }, pidname)) then
    if logicview.truth((logicview.len(packet) < 32)) then
      self:putp({ 28, { "Invalid packet (shorter than 32 bits)" } })
      return
    end
    if logicview.truth(logicview.eq(pidname, "SOF")) then
      framenum = bitstr_to_num(logicview.slice(packet, 16, logicview.add(26, 1), nil))
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 16), 1), logicview.idx(logicview.idx(self.bits, 26), 2)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putpb({ "FRAMENUM", framenum })
      self:putb({ 3, { logicview.pymod("Frame: %d", framenum), "Frame", "Fr", "F" } })
      _table.insert(self.packet, framenum)
      self.packet_summary = logicview.add(self.packet_summary, logicview.pymod(" %d", framenum))
    else
      addr = bitstr_to_num(logicview.slice(packet, 16, logicview.add(22, 1), nil))
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 16), 1), logicview.idx(logicview.idx(self.bits, 22), 2)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putpb({ "ADDR", addr })
      self:putb({ 4, { logicview.pymod("Address: %d", addr), logicview.pymod("Addr: %d", addr), "Addr", "A" } })
      _table.insert(self.packet, addr)
      self.packet_summary = logicview.add(self.packet_summary, logicview.pymod(" ADDR %d", addr))
      ep = bitstr_to_num(logicview.slice(packet, 23, logicview.add(26, 1), nil))
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 23), 1), logicview.idx(logicview.idx(self.bits, 26), 2)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putpb({ "EP", ep })
      self:putb({ 5, { logicview.pymod("Endpoint: %d", ep), logicview.pymod("EP: %d", ep), "EP", "E" } })
      _table.insert(self.packet, ep)
      self.packet_summary = logicview.add(self.packet_summary, logicview.pymod(" EP %d", ep))
    end
    crc5 = bitstr_to_num(logicview.slice(packet, 27, logicview.add(31, 1), nil))
    crc5_calc = calc_crc5(logicview.slice(packet, 16, 27, nil))
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 27), 1), logicview.idx(logicview.idx(self.bits, 31), 2)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(crc5, crc5_calc)) then
      self:putpb({ "CRC5", crc5 })
      self:putb({ 6, { logicview.pymod("CRC5: 0x%02X", crc5), "CRC5", "C" } })
    else
      self:putpb({ "CRC5 ERROR", crc5 })
      self:putb({ 7, { logicview.pymod("CRC5 ERROR: 0x%02X", crc5), "CRC5 ERR", "CE", "C" } })
    end
    _table.insert(self.packet, crc5)
  elseif logicview.truth(logicview.contains({ "DATA0", "DATA1", "DATA2", "MDATA" }, pidname)) then
    data = logicview.slice(packet, 16, (-16), nil)
    databytes = {  }
    self.packet_summary = logicview.add(self.packet_summary, " [")
    for _lv_i in logicview.range(0, logicview.len(data), 8) do
      i = _lv_i
      db = bitstr_to_num(logicview.slice(data, i, logicview.add(i, 8), nil))
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, logicview.add(16, i)), 1), logicview.idx(logicview.idx(self.bits, logicview.add(23, i)), 2)
        self.ss = _lv_a0
        self.es = _lv_a1
      end
      self:putpb({ "DATABYTE", db })
      self:putb({ 8, { logicview.pymod("Databyte: %02X", db), logicview.pymod("Data: %02X", db), logicview.pymod("DB: %02X", db), logicview.pymod("%02X", db) } })
      _table.insert(databytes, db)
      self.packet_summary = logicview.add(self.packet_summary, logicview.pymod(" %02X", db))
      ::continue_5::
    end
    self.packet_summary = logicview.add(self.packet_summary, " ]")
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, 16), 1), logicview.idx(logicview.idx(self.bits, (-16)), 2)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    self:putpb({ "DATABYTES", databytes })
    _table.insert(self.packet, databytes)
    crc16 = bitstr_to_num(logicview.slice(packet, (-16), nil, nil))
    crc16_calc = calc_crc16(logicview.slice(packet, 16, (-16), nil))
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.bits, (-16)), 1), logicview.idx(logicview.idx(self.bits, (-1)), 2)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(crc16, crc16_calc)) then
      self:putpb({ "CRC16", crc16 })
      self:putb({ 9, { logicview.pymod("CRC16: 0x%04X", crc16), "CRC16", "C" } })
    else
      self:putpb({ "CRC16 ERROR", crc16 })
      self:putb({ 10, { logicview.pymod("CRC16 ERROR: 0x%04X", crc16), "CRC16 ERR", "CE", "C" } })
    end
    _table.insert(self.packet, crc16)
  elseif logicview.truth(logicview.contains({ "ACK", "NAK", "STALL", "NYET", "ERR" }, pidname)) then
  elseif logicview.truth(logicview.contains("PRE", pidname)) then
  else
  end
  do
    local _lv_a0, _lv_a1, _lv_a2 = get_category(pidname), pidname, self.packet
    pcategory = _lv_a0
    pname = _lv_a1
    pinfo = _lv_a2
  end
  self:putpp({ "PACKET", { pcategory, pname, pinfo } })
  self:putp({ ann_index(pidname), { logicview.pymod("%s", self.packet_summary) } })
  do
    local _lv_a0, _lv_a1 = {  }, ""
    self.packet = _lv_a0
    self.packet_summary = _lv_a1
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, pdata
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
    if logicview.truth((not logicview.contains({ "SOP", "BIT", "EOP", "ERR" }, ptype))) then
      return
    end
    if logicview.truth(logicview.eq(self.state, "WAIT FOR SOP")) then
      if logicview.truth((not logicview.eq(ptype, "SOP"))) then
        return
      end
      self.ss_packet = ss
      self.state = "GET BIT"
    elseif logicview.truth(logicview.eq(self.state, "GET BIT")) then
      if logicview.truth(logicview.eq(ptype, "BIT")) then
        _table.insert(self.bits, { pdata, ss, es })
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(ptype, "EOP")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ptype, "ERR")
  return _v
end)()) then
        self.es_packet = es
        self:handle_packet()
        do
          local _lv_a0, _lv_a1 = {  }, ""
          self.packet = _lv_a0
          self.packet_summary = _lv_a1
        end
        do
          local _lv_a0, _lv_a1 = {  }, "WAIT FOR SOP"
          self.bits = _lv_a0
          self.state = _lv_a1
        end
      else
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
