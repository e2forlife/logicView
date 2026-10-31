-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Petteri Aimonen <jpa@sigrok.mail.kapsi.fi>

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
  id = "arm_tpiu",
  name = "ARM TPIU",
  longname = "ARM Trace Port Interface Unit",
  desc = "Filter TPIU formatted trace data into separate streams.",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = { "uart" },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "stream", desc = "Stream index", default = 1, values = {  } }), logicview.dict({ id = "sync_offset", desc = "Initial sync offset", default = 0, values = {  } }) },
  annotations = { { "stream", "Current stream" }, { "data", "Stream data" } },
  annotation_rows = { { "stream", "Current stream", { 0 } }, { "data", "Stream data", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.buf = {  }
  self.syncbuf = {  }
  self.prevsample = 0
  self.stream = 0
  self.ss_stream = nil
  self.bytenum = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.stream_changed(self, ss, stream)
  if logicview.truth((not logicview.eq(self.stream, stream))) then
    if logicview.truth((not logicview.eq(self.stream, 0))) then
      self:put(self.ss_stream, ss, self.out_ann, { 0, { logicview.pymod("Stream %d", self.stream), logicview.pymod("S%d", self.stream) } })
    end
    self.stream = stream
    self.ss_stream = ss
  end
end
function _decoder.emit_byte(self, ss, es, byte)
  if logicview.truth(logicview.eq(self.stream, logicview.idx(self.options, "stream"))) then
    self:put(ss, es, self.out_ann, { 1, { logicview.pymod("0x%02x", byte) } })
    self:put(ss, es, self.out_python, { "DATA", 0, { byte, {  } } })
  end
end
function _decoder.process_frame(self, buf)
  local lowbits, i, delayed_stream_change, lowbit, byte
  lowbits = logicview.idx(logicview.idx(buf, 15), 2)
  for _lv_i in logicview.range(0, 15, 2) do
    i = _lv_i
    delayed_stream_change = nil
    lowbit = ((lowbits >> logicview.floordiv(i, 2)) & 1)
    if logicview.truth((not logicview.eq((logicview.idx(logicview.idx(buf, i), 2) & 1), 0))) then
      if logicview.truth(lowbit) then
        delayed_stream_change = (logicview.idx(logicview.idx(buf, i), 2) >> 1)
      else
        self:stream_changed(logicview.idx(logicview.idx(buf, i), 0), (logicview.idx(logicview.idx(buf, i), 2) >> 1))
      end
    else
      byte = (logicview.idx(logicview.idx(buf, i), 2) | lowbit)
      self:emit_byte(logicview.idx(logicview.idx(buf, i), 0), logicview.idx(logicview.idx(buf, i), 1), byte)
    end
    if logicview.truth((i < 14)) then
      self:emit_byte(logicview.idx(logicview.idx(buf, logicview.add(i, 1)), 0), logicview.idx(logicview.idx(buf, logicview.add(i, 1)), 1), logicview.idx(logicview.idx(buf, logicview.add(i, 1)), 2))
    end
    if logicview.truth((delayed_stream_change ~= nil)) then
      self:stream_changed(logicview.idx(logicview.idx(buf, logicview.add(i, 1)), 1), delayed_stream_change)
    end
    ::continue_1::
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
    self.byte_len = (es - ss)
    if logicview.truth(((ss - self.prevsample) > self.byte_len)) then
      self.buf = {  }
    end
    self.prevsample = es
    _table.insert(self.buf, { ss, es, logicview.idx(pdata, 0) })
    self.bytenum = logicview.add(self.bytenum, 1)
    if logicview.truth((self.bytenum < logicview.idx(self.options, "sync_offset"))) then
      self.buf = {  }
      return
    end
    self.syncbuf = logicview.add(logicview.slice(self.syncbuf, (-3), nil, nil), { logicview.idx(pdata, 0) })
    if logicview.truth(logicview.eq(self.syncbuf, { 255, 255, 255, 127 })) then
      self.buf = {  }
      self.syncbuf = {  }
      return
    end
    if logicview.truth(logicview.eq(logicview.len(self.buf), 16)) then
      self:process_frame(self.buf)
      self.buf = {  }
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
