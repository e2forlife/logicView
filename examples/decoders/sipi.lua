-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Soeren Apel <soeren@apelpie.net>

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
local crc_hqx, command_codes, ann_header_tag, ann_header_cmd, ann_header_ch, ann_address, ann_data, ann_crc, ann_warning, Decoder
local _decoder

crc_hqx = logicview.crc_hqx
command_codes = logicview.dict({ [0] = { "Read byte", 4, 0 }, [1] = { "Read 2 byte", 4, 0 }, [2] = { "Read 4 byte", 4, 0 }, [4] = { "Write byte with ACK", 4, 4 }, [5] = { "Write 2 byte with ACK", 4, 4 }, [6] = { "Write 4 byte with ACK", 4, 4 }, [8] = { "ACK", 0, 0 }, [9] = { "NACK (Target Error)", 0, 0 }, [10] = { "Read Answer with ACK", 4, 4 }, [12] = { "Trigger with ACK", 0, 0 }, [18] = { "Read 4-byte JTAG ID", 0, 0 }, [23] = { "Stream 32 byte with ACK", 0, 32 } })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(7) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_header_tag = logicview.idx(_lv_seq, 0)
  ann_header_cmd = logicview.idx(_lv_seq, 1)
  ann_header_ch = logicview.idx(_lv_seq, 2)
  ann_address = logicview.idx(_lv_seq, 3)
  ann_data = logicview.idx(_lv_seq, 4)
  ann_crc = logicview.idx(_lv_seq, 5)
  ann_warning = logicview.idx(_lv_seq, 6)
end
_decoder = {
  api_version = 3,
  id = "sipi",
  name = "SIPI (Zipwire)",
  longname = "NXP SIPI interface",
  desc = "Serial Inter-Processor Interface (SIPI) aka Zipwire, aka HSSL",
  license = "gplv2+",
  inputs = { "lfast" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "header_tag", "Transaction Tag" }, { "header_cmd", "Command Code" }, { "header_ch", "Channel" }, { "address", "Address" }, { "data", "Data" }, { "crc", "CRC" }, { "warning", "Warning" } },
  annotation_rows = { { "fields", "Fields", { 0, 1, 2, 3, 4, 5 } }, { "warnings", "Warnings", { 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.byte_len = 0
  self.frame_len = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.put_ann(self, ss, es, ann_class, value)
  self:put(logicview.tointeger(ss), logicview.tointeger(es), self.out_ann, { ann_class, value })
end
function _decoder.put_header(self, ss_header, es_header, value)
  local ss, es, tag, cmd_id, cmd_name, reserved_bits, ch
  ss = ss_header
  es = logicview.add(ss, logicview.mul(3, self.bit_len))
  tag = ((value & 57344) >> 13)
  self:put_ann(ss, es, ann_header_tag, { logicview.pyformat("{:02X}", { tag }, logicview.dict({})) })
  ss = es
  es = logicview.add(ss, logicview.mul(5, self.bit_len))
  cmd_id = ((value & 7936) >> 8)
  do
    local _lv_seq = logicview.dget(command_codes, cmd_id, { logicview.pyformat("Reserved ({:02X})", { cmd_id }, logicview.dict({})), 0, 0 })
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    cmd_name = logicview.idx(_lv_seq, 0)
    self.addr_len = logicview.idx(_lv_seq, 1)
    self.data_len = logicview.idx(_lv_seq, 2)
  end
  self.frame_len = logicview.add(logicview.add(logicview.add(2, 2), self.addr_len), self.data_len)
  self:put_ann(ss, es, ann_header_cmd, { cmd_name })
  ss = es
  es = logicview.add(ss, logicview.mul(4, self.bit_len))
  reserved_bits = ((value & 240) >> 4)
  if logicview.truth((reserved_bits > 0)) then
    self:put_ann(ss, es, ann_warning, { "Reserved bits #4..7 should be 0" })
  end
  ss = es
  es = logicview.add(ss, logicview.mul(3, self.bit_len))
  ch = ((value & 14) >> 1)
  self:put_ann(ss, es, ann_header_ch, { _tostring(ch) })
  if logicview.truth(logicview.eq((value & 1), 1)) then
    ss = es
    es = logicview.add(ss, self.bit_len)
    self:put_ann(ss, es, ann_warning, { "Reserved bit #0 should be 0" })
  end
end
function _decoder.put_payload(self, data)
  local byte_idx, value_tuple, ss, es, value
  byte_idx = 0
  if logicview.truth((self.addr_len > 0)) then
    for _lv_item in logicview.iter(logicview.slice(data, nil, self.addr_len, nil)) do
      value_tuple = _lv_item
      do
        local _lv_seq = value_tuple
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
        value = logicview.idx(_lv_seq, 2)
      end
      self:put_ann(ss, es, ann_address, { logicview.pyformat("{:02X}", { value }, logicview.dict({})) })
      ::continue_1::
    end
    byte_idx = self.addr_len
  end
  if logicview.truth((self.data_len > 0)) then
    for _lv_item in logicview.iter(logicview.slice(data, byte_idx, nil, nil)) do
      value_tuple = _lv_item
      do
        local _lv_seq = value_tuple
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
        value = logicview.idx(_lv_seq, 2)
      end
      self:put_ann(ss, es, ann_data, { logicview.pyformat("{:02X}", { value }, logicview.dict({})) })
      ::continue_2::
    end
  end
end
function _decoder.put_crc(self, ss, es, crc_value, crc_payload_data)
  local crc_payload, value_tuple, calculated_crc
  crc_payload = {  }
  for _lv_item in logicview.iter(crc_payload_data) do
    value_tuple = _lv_item
    _table.insert(crc_payload, logicview.idx(value_tuple, 2))
    ::continue_3::
  end
  calculated_crc = crc_hqx(logicview.bytes(crc_payload), 65535)
  if logicview.truth(logicview.eq(calculated_crc, crc_value)) then
    self:put_ann(ss, es, ann_crc, { "CRC OK" })
  else
    self:put_ann(ss, es, ann_crc, { logicview.pyformat("Have {:02X} but calculated {:02X}", { crc_value, calculated_crc }, logicview.dict({})) })
    self:put_ann(ss, es, ann_warning, { "CRC mismatch" })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local byte_idx, payload_len
    if logicview.truth(logicview.eq(logicview.len(data), 1)) then
      self:put_ann(ss, es, ann_warning, { "Header too short" })
      return
    end
    self.bit_len = ((logicview.idx(logicview.idx(data, 0), 1) - logicview.idx(logicview.idx(data, 0), 0)) / 8.0)
    byte_idx = 0
    ss = logicview.idx(logicview.idx(data, byte_idx), 0)
    es = logicview.idx(logicview.idx(data, logicview.add(byte_idx, 1)), 1)
    self:put_header(ss, es, logicview.add((logicview.idx(logicview.idx(data, byte_idx), 2) << 8), logicview.idx(logicview.idx(data, logicview.add(byte_idx, 1)), 2)))
    byte_idx = logicview.add(byte_idx, 2)
    payload_len = ((self.frame_len - 2) - 2)
    if logicview.truth((payload_len > 0)) then
      self:put_payload(logicview.slice(data, byte_idx, (-2), nil))
      byte_idx = logicview.add(byte_idx, payload_len)
    end
    ss = logicview.idx(logicview.idx(data, byte_idx), 0)
    es = logicview.idx(logicview.idx(data, logicview.add(byte_idx, 1)), 1)
    if logicview.truth(logicview.eq(byte_idx, (logicview.len(data) - 2))) then
      self:put_crc(ss, es, logicview.add((logicview.idx(logicview.idx(data, byte_idx), 2) << 8), logicview.idx(logicview.idx(data, logicview.add(byte_idx, 1)), 2)), logicview.slice(data, 0, (-2), nil))
    else
      self:put_ann(ss, es, ann_warning, { "CRC incomplete or missing" })
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
