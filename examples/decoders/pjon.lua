-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Gerhard Sittig <gerhard.sittig@gmx.net>

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
local struct, ANN_RX_INFO, ANN_HDR_CFG, ANN_PKT_LEN, ANN_META_CRC, ANN_TX_INFO, ANN_SVC_ID, ANN_PKT_ID, ANN_ANON_DATA, ANN_PAYLOAD, ANN_END_CRC, ANN_SYN_RSP, ANN_RELATION, ANN_WARN, calc_crc8, calc_crc32, Decoder
local _decoder

struct = logicview.struct
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(13) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_RX_INFO = logicview.idx(_lv_seq, 0)
  ANN_HDR_CFG = logicview.idx(_lv_seq, 1)
  ANN_PKT_LEN = logicview.idx(_lv_seq, 2)
  ANN_META_CRC = logicview.idx(_lv_seq, 3)
  ANN_TX_INFO = logicview.idx(_lv_seq, 4)
  ANN_SVC_ID = logicview.idx(_lv_seq, 5)
  ANN_PKT_ID = logicview.idx(_lv_seq, 6)
  ANN_ANON_DATA = logicview.idx(_lv_seq, 7)
  ANN_PAYLOAD = logicview.idx(_lv_seq, 8)
  ANN_END_CRC = logicview.idx(_lv_seq, 9)
  ANN_SYN_RSP = logicview.idx(_lv_seq, 10)
  ANN_RELATION = logicview.idx(_lv_seq, 11)
  ANN_WARN = logicview.idx(_lv_seq, 12)
end
calc_crc8 = function(data)
  local crc, b, i, odd
  crc = 0
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    crc = (crc ~ b)
    for _lv_i in logicview.range(8) do
      i = _lv_i
      odd = logicview.pymod(crc, 2)
      crc = (crc >> 1)
      if logicview.truth(odd) then
        crc = (crc ~ 151)
      end
      ::continue_2::
    end
    ::continue_1::
  end
  return crc
end
calc_crc32 = function(data)
  local crc, b, i, odd
  crc = 4294967295
  for _lv_item in logicview.iter(data) do
    b = _lv_item
    crc = (crc ~ b)
    for _lv_i in logicview.range(8) do
      i = _lv_i
      odd = logicview.pymod(crc, 2)
      crc = (crc >> 1)
      if logicview.truth(odd) then
        crc = (crc ~ 3988292384)
      end
      ::continue_4::
    end
    ::continue_3::
  end
  crc = (crc ~ 4294967295)
  return crc
end
_decoder = {
  api_version = 3,
  id = "pjon",
  name = "PJON",
  longname = "PJON",
  desc = "The PJON protocol.",
  license = "gplv2+",
  inputs = { "pjon_link" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "rx_info", "Receiver ID" }, { "hdr_cfg", "Header config" }, { "pkt_len", "Packet length" }, { "meta_crc", "Meta CRC" }, { "tx_info", "Sender ID" }, { "port", "Service ID" }, { "pkt_id", "Packet ID" }, { "anon", "Anonymous data" }, { "payload", "Payload" }, { "end_crc", "End CRC" }, { "syn_rsp", "Sync response" }, { "relation", "Relation" }, { "warning", "Warning" } },
  annotation_rows = { { "fields", "Fields", { 0, 1, 2, 3, 4, 5, 7, 8, 9, 10 } }, { "relations", "Relations", { 11 } }, { "warnings", "Warnings", { 12 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self:reset_frame()
end
function _decoder.reset_frame(self)
  self.frame_ss = nil
  self.frame_es = nil
  self.frame_rx_id = nil
  self.frame_tx_id = nil
  self.frame_payload_text = nil
  self.frame_bytes = nil
  self.frame_has_ack = nil
  self.ack_bytes = nil
  self.ann_ss = nil
  self.ann_es = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putg(self, ss, es, ann, data)
  self:put(ss, es, self.out_ann, { ann, data })
end
function _decoder.frame_flush(self)
  local text
  if logicview.truth((not logicview.truth(self.frame_bytes))) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.frame_ss))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.frame_es))
  return _v
end)()) then
    return
  end
  text = {  }
  if logicview.truth((self.frame_rx_id ~= nil)) then
    _table.insert(text, logicview.pyformat("RX {}", { logicview.idx(self.frame_rx_id, (-1)) }, logicview.dict({})))
  end
  if logicview.truth((self.frame_tx_id ~= nil)) then
    _table.insert(text, logicview.pyformat("TX {}", { logicview.idx(self.frame_tx_id, (-1)) }, logicview.dict({})))
  end
  if logicview.truth((self.frame_payload_text ~= nil)) then
    _table.insert(text, logicview.pyformat("DATA {}", { self.frame_payload_text }, logicview.dict({})))
  end
  if logicview.truth((self.frame_has_ack ~= nil)) then
    _table.insert(text, logicview.pyformat("ACK {:02x}", { self.frame_has_ack }, logicview.dict({})))
  end
  if logicview.truth(text) then
    text = logicview.join(" - ", text)
    self:putg(self.frame_ss, self.frame_es, ANN_RELATION, { text })
  end
end
function _decoder.handle_field_get_desc(self, idx)
  if idx == nil then idx = nil end
  local desc
  if logicview.truth((not logicview.truth(self.field_desc))) then
    return nil
  end
  if logicview.truth((idx == nil)) then
    idx = self.field_desc_idx
  end
  if logicview.truth((function()
  local _v
  _v = (idx >= 0)
  if not logicview.truth(_v) then return _v end
  _v = (idx >= logicview.len(self.field_desc))
  return _v
end)()) then
    return nil
  end
  if logicview.truth((function()
  local _v
  _v = (idx < 0)
  if not logicview.truth(_v) then return _v end
  _v = (_math.abs(idx) > logicview.len(self.field_desc))
  return _v
end)()) then
    return nil
  end
  desc = logicview.idx(self.field_desc, idx)
  return desc
end
function _decoder.handle_field_add_desc(self, fmt, hdl, cls)
  if cls == nil then cls = nil end
  local item
  item = logicview.dict({ format = fmt, width = struct.calcsize(fmt), handler = hdl, anncls = cls })
  _table.insert(self.field_desc, item)
end
function _decoder.handle_field_seed_desc(self)
  self.field_desc = {  }
  self:handle_field_add_desc("<B", self.handle_field_rx_id, ANN_RX_INFO)
  self:handle_field_add_desc("<B", self.handle_field_config, ANN_HDR_CFG)
  self.field_desc_idx = 0
  self.field_desc_got = 0
  self.frame_ss = nil
  self.frame_es = nil
  self.frame_rx_id = nil
  self.frame_is_broadcast = nil
  self.frame_tx_id = nil
  self.frame_payload = nil
  self.frame_payload_text = nil
  self.frame_has_ack = nil
end
function _decoder.handle_field_rx_id(self, b)
  local id_txt, texts
  b = logicview.idx(b, 0)
  if logicview.truth(logicview.eq(b, 255)) then
    id_txt = "NA"
  elseif logicview.truth(logicview.eq(b, 0)) then
    id_txt = "BC"
  else
    id_txt = logicview.pyformat("{:d}", { b }, logicview.dict({}))
  end
  texts = { logicview.pyformat("RX_ID {}", { id_txt }, logicview.dict({})), logicview.pyformat("{}", { id_txt }, logicview.dict({})) }
  self.frame_rx_id = { b, id_txt }
  self.frame_is_broadcast = logicview.eq(b, 0)
  return texts
end
function _decoder.handle_field_config(self, b)
  local text, bits, texts, u8_fmt, u16_fmt, u32_fmt, len_fmt, bus_fmt, crc_fmt, pl_fmt, warn_texts, wants_ack
  b = logicview.idx(b, 0)
  self.cfg_shared = (b & (1 << 0))
  self.cfg_tx_info = (b & (1 << 1))
  self.cfg_sync_ack = (b & (1 << 2))
  self.cfg_async_ack = (b & (1 << 3))
  self.cfg_port = (b & (1 << 4))
  self.cfg_crc32 = (b & (1 << 5))
  self.cfg_len16 = (b & (1 << 6))
  self.cfg_pkt_id = (b & (1 << 7))
  text = {  }
  _table.insert(text, (function() if logicview.truth(self.cfg_pkt_id) then return "pkt_id" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_len16) then return "len16" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_crc32) then return "crc32" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_port) then return "svc_id" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_async_ack) then return "ack_mode" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_sync_ack) then return "ack" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_tx_info) then return "tx_info" else return "-" end end)())
  _table.insert(text, (function() if logicview.truth(self.cfg_shared) then return "bus_id" else return "-" end end)())
  text = logicview.join(" ", text)
  bits = logicview.pyformat("{:08b}", { b }, logicview.dict({}))
  texts = { logicview.pyformat("CFG {:s}", { text }, logicview.dict({})), logicview.pyformat("CFG {}", { bits }, logicview.dict({})), bits }
  u8_fmt = ">B"
  u16_fmt = ">H"
  u32_fmt = ">L"
  len_fmt = (function() if logicview.truth(self.cfg_len16) then return u16_fmt else return u8_fmt end end)()
  bus_fmt = ">4B"
  crc_fmt = (function() if logicview.truth(self.cfg_crc32) then return u32_fmt else return u8_fmt end end)()
  self.cfg_overhead = 0
  self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u8_fmt))
  self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u8_fmt))
  self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(len_fmt))
  self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u8_fmt))
  if logicview.truth(self.cfg_shared) then
    self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u32_fmt))
  end
  if logicview.truth(self.cfg_tx_info) then
    if logicview.truth(self.cfg_shared) then
      self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u32_fmt))
    end
    self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u8_fmt))
  end
  if logicview.truth(self.cfg_port) then
    self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u16_fmt))
  end
  if logicview.truth(self.cfg_pkt_id) then
    self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(u16_fmt))
  end
  self.cfg_overhead = logicview.add(self.cfg_overhead, struct.calcsize(crc_fmt))
  self:handle_field_add_desc(len_fmt, self.handle_field_pkt_len, ANN_PKT_LEN)
  self:handle_field_add_desc(u8_fmt, self.handle_field_meta_crc, ANN_META_CRC)
  if logicview.truth(self.cfg_shared) then
    self:handle_field_add_desc(bus_fmt, self.handle_field_rx_bus, ANN_ANON_DATA)
  end
  if logicview.truth(self.cfg_tx_info) then
    if logicview.truth(self.cfg_shared) then
      self:handle_field_add_desc(bus_fmt, self.handle_field_tx_bus, ANN_ANON_DATA)
    end
    self:handle_field_add_desc(u8_fmt, self.handle_field_tx_id, ANN_ANON_DATA)
  end
  if logicview.truth(self.cfg_port) then
    self:handle_field_add_desc(u16_fmt, { "PORT {:d}", "{:d}" }, ANN_ANON_DATA)
  end
  if logicview.truth(self.cfg_pkt_id) then
    self:handle_field_add_desc(u16_fmt, { "PKT {:04x}", "{:04x}" }, ANN_ANON_DATA)
  end
  pl_fmt = logicview.pyformat(">{:d}B", { 0 }, logicview.dict({}))
  self:handle_field_add_desc(pl_fmt, self.handle_field_payload, ANN_PAYLOAD)
  self:handle_field_add_desc(crc_fmt, self.handle_field_end_crc, ANN_END_CRC)
  warn_texts = {  }
  wants_ack = (function()
  local _v
  _v = self.cfg_sync_ack
  if logicview.truth(_v) then return _v end
  _v = self.cfg_async_ack
  return _v
end)()
  if logicview.truth((function()
  local _v
  _v = wants_ack
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.cfg_tx_info))
  return _v
end)()) then
    _table.insert(warn_texts, "ACK request without TX info")
  end
  if logicview.truth((function()
  local _v
  _v = wants_ack
  if not logicview.truth(_v) then return _v end
  _v = self.frame_is_broadcast
  return _v
end)()) then
    _table.insert(warn_texts, "ACK request for broadcast")
  end
  if logicview.truth((function()
  local _v
  _v = self.cfg_sync_ack
  if not logicview.truth(_v) then return _v end
  _v = self.cfg_async_ack
  return _v
end)()) then
    _table.insert(warn_texts, "sync and async ACK request")
  end
  if logicview.truth((function()
  local _v
  _v = self.cfg_len16
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.cfg_crc32))
  return _v
end)()) then
    _table.insert(warn_texts, "extended length needs CRC32")
  end
  if logicview.truth(warn_texts) then
    warn_texts = logicview.join(", ", warn_texts)
    self:putg(self.ann_ss, self.ann_es, ANN_WARN, { warn_texts })
  end
  return texts
end
function _decoder.handle_field_pkt_len(self, b)
  local pkt_len, pl_len, warn_texts, pl_fmt, desc, texts
  b = logicview.idx(b, 0)
  pkt_len = b
  pl_len = (b - self.cfg_overhead)
  warn_texts = {  }
  if logicview.truth((not logicview.contains((function() local _t = {}; for _v in logicview.range(self.cfg_overhead, 65536) do _t[#_t + 1] = _v end; return _t end)(), pkt_len))) then
    _table.insert(warn_texts, "suspicious packet length")
  end
  if logicview.truth((function()
  local _v
  _v = (pkt_len > 15)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.cfg_crc32))
  return _v
end)()) then
    _table.insert(warn_texts, "length above 15 needs CRC32")
  end
  if logicview.truth((pl_len < 1)) then
    _table.insert(warn_texts, "suspicious payload length")
    pl_len = 0
  end
  if logicview.truth(warn_texts) then
    warn_texts = logicview.join(", ", warn_texts)
    self:putg(self.ann_ss, self.ann_es, ANN_WARN, { warn_texts })
  end
  pl_fmt = logicview.pyformat(">{:d}B", { pl_len }, logicview.dict({}))
  desc = self:handle_field_get_desc((-2))
  logicview.setidx(desc, "format", pl_fmt)
  logicview.setidx(desc, "width", struct.calcsize(pl_fmt))
  texts = { logicview.pyformat("LENGTH {:d} (PAYLOAD {:d})", { pkt_len, pl_len }, logicview.dict({})), logicview.pyformat("LEN {:d} (PL {:d})", { pkt_len, pl_len }, logicview.dict({})), logicview.pyformat("{:d} ({:d})", { pkt_len, pl_len }, logicview.dict({})), logicview.pyformat("{:d}", { pkt_len }, logicview.dict({})) }
  return texts
end
function _decoder.handle_field_common_crc(self, have, is_meta)
  local caption, crc_len, crc_bytes, crc_fmt, have_text, warn_texts, data, want, want_text, texts
  caption = (function() if logicview.truth(is_meta) then return "META" else return "END" end end)()
  crc_len = (function() if logicview.truth(is_meta) then return 8 else return (function() if logicview.truth(self.cfg_crc32) then return 32 else return 8 end end)() end end)()
  crc_bytes = logicview.floordiv(crc_len, 8)
  crc_fmt = (function() if logicview.truth(logicview.eq(crc_len, 32)) then return "{:08x}" else return "{:02x}" end end)()
  have_text = logicview.pyformat(crc_fmt, { have }, logicview.dict({}))
  warn_texts = {  }
  data = logicview.slice(self.frame_bytes, nil, (-crc_bytes), nil)
  want = (function() if logicview.truth(logicview.eq(crc_len, 32)) then return calc_crc32(data) else return calc_crc8(data) end end)()
  if logicview.truth((not logicview.eq(want, have))) then
    want_text = logicview.pyformat(crc_fmt, { want }, logicview.dict({}))
    _table.insert(warn_texts, logicview.pyformat("CRC mismatch - want {} have {}", { want_text, have_text }, logicview.dict({})))
  end
  if logicview.truth(warn_texts) then
    warn_texts = logicview.join(", ", warn_texts)
    self:putg(self.ann_ss, self.ann_es, ANN_WARN, { warn_texts })
  end
  texts = { logicview.pyformat("{}_CRC {}", { caption, have_text }, logicview.dict({})), logicview.pyformat("CRC {}", { have_text }, logicview.dict({})), have_text }
  return texts
end
function _decoder.handle_field_meta_crc(self, b)
  b = logicview.idx(b, 0)
  return self:handle_field_common_crc(b, true)
end
function _decoder.handle_field_end_crc(self, b)
  b = logicview.idx(b, 0)
  return self:handle_field_common_crc(b, false)
end
function _decoder.handle_field_common_bus(self, b)
  local bus_id, bus_num, bus_txt
  bus_id = logicview.slice(b, nil, 4, nil)
  bus_num = struct.unpack(">L", logicview.bytes(bus_id))
  bus_txt = logicview.join(".", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(bus_id) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:d}", { b }, logicview.dict({}))
  end
  return _lv_out
end)())
  return { bus_num, bus_txt }
end
function _decoder.handle_field_rx_bus(self, b)
  local bus_num, bus_txt, rx_txt, texts
  do
    local _lv_seq = self:handle_field_common_bus(logicview.slice(b, nil, 4, nil))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    bus_num = logicview.idx(_lv_seq, 0)
    bus_txt = logicview.idx(_lv_seq, 1)
  end
  rx_txt = logicview.pyformat("{} {}", { bus_txt, logicview.idx(self.frame_rx_id, (-1)) }, logicview.dict({}))
  self.frame_rx_id = { bus_num, logicview.idx(self.frame_rx_id, 0), rx_txt }
  texts = { logicview.pyformat("RX_BUS {}", { bus_txt }, logicview.dict({})), bus_txt }
  return texts
end
function _decoder.handle_field_tx_bus(self, b)
  local bus_num, bus_txt, texts
  do
    local _lv_seq = self:handle_field_common_bus(logicview.slice(b, nil, 4, nil))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    bus_num = logicview.idx(_lv_seq, 0)
    bus_txt = logicview.idx(_lv_seq, 1)
  end
  self.frame_tx_id = { bus_num, nil, bus_txt }
  texts = { logicview.pyformat("TX_BUS {}", { bus_txt }, logicview.dict({})), bus_txt }
  return texts
end
function _decoder.handle_field_tx_id(self, b)
  local id_txt, tx_txt, texts
  b = logicview.idx(b, 0)
  id_txt = logicview.pyformat("{:d}", { b }, logicview.dict({}))
  if logicview.truth((self.frame_tx_id == nil)) then
    self.frame_tx_id = { b, id_txt }
  else
    tx_txt = logicview.pyformat("{} {}", { logicview.idx(self.frame_tx_id, (-1)), id_txt }, logicview.dict({}))
    self.frame_tx_id = { logicview.idx(self.frame_tx_id, 0), b, tx_txt }
  end
  texts = { logicview.pyformat("TX_ID {}", { id_txt }, logicview.dict({})), id_txt }
  return texts
end
function _decoder.handle_field_payload(self, b)
  local text, texts
  text = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(b) do
    v = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { v }, logicview.dict({}))
  end
  return _lv_out
end)())
  self.frame_payload = logicview.slice(b, nil, nil, nil)
  self.frame_payload_text = text
  texts = { logicview.pyformat("PAYLOAD {}", { text }, logicview.dict({})), text }
  return texts
end
function _decoder.handle_field_sync_resp(self, b)
  local texts
  self.frame_has_ack = b
  texts = { logicview.pyformat("ACK {:02x}", { b }, logicview.dict({})), logicview.pyformat("{:02x}", { b }, logicview.dict({})) }
  return texts
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, pdata, b, text, desc, width, fmt, raw, values, hdl, cls
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
    if logicview.truth(logicview.eq(ptype, "FRAME_INIT")) then
      self:frame_flush()
      self:reset_frame()
      self.frame_bytes = {  }
      self:handle_field_seed_desc()
      self.frame_ss = ss
      self.frame_es = es
      return
    end
    if logicview.truth(logicview.contains({ "IDLE", "FRAME_DATA" }, ptype)) then
      self:frame_flush()
      self:reset_frame()
      return
    end
    if logicview.truth(logicview.eq(ptype, "SYNC_RESP_WAIT")) then
      self.ack_bytes = {  }
      do
        local _lv_a0, _lv_a1 = nil, nil
        self.ann_ss = _lv_a0
        self.ann_es = _lv_a1
      end
      return
    end
    if logicview.truth(logicview.eq(ptype, "DATA_BYTE")) then
      b = pdata
      self.frame_es = es
      if logicview.truth((self.ack_bytes ~= nil)) then
        if logicview.truth((not logicview.truth(self.ann_ss))) then
          self.ann_ss = ss
        end
        _table.insert(self.ack_bytes, b)
        self.ann_es = es
        text = self:handle_field_sync_resp(b)
        if logicview.truth(text) then
          self:putg(self.ann_ss, self.ann_es, ANN_SYN_RSP, text)
        end
        do
          local _lv_a0, _lv_a1 = nil, nil
          self.ann_ss = _lv_a0
          self.ann_es = _lv_a1
        end
        return
      end
      if logicview.truth((self.frame_bytes ~= nil)) then
        if logicview.truth((not logicview.truth(self.ann_ss))) then
          self.ann_ss = ss
        end
        _table.insert(self.frame_bytes, b)
        self.ann_es = es
        desc = self:handle_field_get_desc()
        if logicview.truth((not logicview.truth(desc))) then
          return
        end
        width = logicview.dget(desc, "width", nil)
        if logicview.truth((not logicview.truth(width))) then
          return
        end
        self.field_desc_got = logicview.add(self.field_desc_got, 1)
        if logicview.truth((not logicview.eq(self.field_desc_got, width))) then
          return
        end
        fmt = logicview.dget(desc, "format", ">B")
        raw = logicview.bytes(logicview.slice(self.frame_bytes, (-width), nil, nil))
        values = struct.unpack(fmt, raw)
        hdl = logicview.dget(desc, "handler", "{!r}")
        if logicview.truth(logicview.is_a(hdl, "str")) then
          text = { logicview.pyformat(hdl, {  }, logicview.dict({})) }
        elseif logicview.truth(logicview.is_a(hdl, { "list", "tuple" })) then
          text = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(hdl) do
    f = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat(f, {  }, logicview.dict({}))
  end
  return _lv_out
end)()
        elseif logicview.truth(hdl) then
          text = hdl(values)
        end
        cls = logicview.dget(desc, "anncls", ANN_ANON_DATA)
        if logicview.truth((function()
  local _v
  _v = (cls ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = text
  return _v
end)()) then
          self:putg(self.ann_ss, self.ann_es, cls, text)
        end
        do
          local _lv_a0, _lv_a1 = nil, nil
          self.ann_ss = _lv_a0
          self.ann_es = _lv_a1
        end
        self.field_desc_idx = logicview.add(self.field_desc_idx, 1)
        self.field_desc_got = 0
        return
      end
      return
    end
    return
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
