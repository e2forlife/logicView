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
local bitpack, ceil, floor, _with_ann_carrier, _with_ann_sync_loss, PIN_DATA, ANN_CARRIER_BUSY, ANN_CARRIER_IDLE, ANN_PAD_BIT, ANN_LOW_BIT, ANN_DATA_BIT, ANN_SHORT_DATA, ANN_SYNC_LOSS, ANN_DATA_BYTE, ANN_FRAME_INIT, ANN_FRAME_BYTES, ANN_FRAME_WAIT, SamplerateError, Decoder
local _decoder

bitpack = logicview.bitpack
ceil = _math.ceil
floor = _math.floor
_with_ann_carrier = false
_with_ann_sync_loss = false
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(1) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  PIN_DATA = logicview.idx(_lv_seq, 0)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(11) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_CARRIER_BUSY = logicview.idx(_lv_seq, 0)
  ANN_CARRIER_IDLE = logicview.idx(_lv_seq, 1)
  ANN_PAD_BIT = logicview.idx(_lv_seq, 2)
  ANN_LOW_BIT = logicview.idx(_lv_seq, 3)
  ANN_DATA_BIT = logicview.idx(_lv_seq, 4)
  ANN_SHORT_DATA = logicview.idx(_lv_seq, 5)
  ANN_SYNC_LOSS = logicview.idx(_lv_seq, 6)
  ANN_DATA_BYTE = logicview.idx(_lv_seq, 7)
  ANN_FRAME_INIT = logicview.idx(_lv_seq, 8)
  ANN_FRAME_BYTES = logicview.idx(_lv_seq, 9)
  ANN_FRAME_WAIT = logicview.idx(_lv_seq, 10)
end
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "pjdl",
  name = "PJDL",
  longname = "Padded Jittering Data Link",
  desc = "PJDL, a single wire serial link layer for PJON.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "pjon_link" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "data", name = "DATA", desc = "Single wire data" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "mode", desc = "Communication mode", default = 1, values = { 1, 2, 3, 4 } }), logicview.dict({ id = "idle_add_us", desc = "Added idle time (us)", default = 4, values = {  } }) },
  annotations = { { "cs_busy", "Carrier busy" }, { "cs_idle", "Carrier idle" }, { "bit_pad", "Pad bit" }, { "bit_low", "Low bit" }, { "bit_data", "Data bit" }, { "bit_short", "Short data" }, { "sync_loss", "Sync loss" }, { "byte", "Data byte" }, { "frame_init", "Frame init" }, { "frame_bytes", "Frame bytes" }, { "frame_wait", "Frame wait" } },
  annotation_rows = { { "carriers", "Carriers", { 0, 1 } }, { "bits", "Bits", { 2, 3, 4, 5 } }, { "bytes", "Bytes", { 8, 7, 10 } }, { "frames", "Frames", { 9 } }, { "warns", "Warnings", { 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self:reset_state()
end
function _decoder.reset_state(self)
  self.carrier_want_idle = true
  self.carrier_is_busy = false
  self.carrier_is_idle = false
  self.carrier_idle_ss = nil
  self.carrier_busy_ss = nil
  self.syncpad_fall_ss = nil
  self.edges = nil
  self.symbols = nil
  self.sync_pads = nil
  self.data_bits = nil
  self.frame_bytes = nil
  self.short_bits = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self:span_prepare()
  end
end
function _decoder.putg(self, ss, es, data)
  local cls
  cls = logicview.idx(data, 0)
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(_with_ann_carrier))
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ ANN_CARRIER_BUSY, ANN_CARRIER_IDLE }, cls)
  return _v
end)()) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(_with_ann_sync_loss))
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains({ ANN_SYNC_LOSS }, cls)
  return _v
end)()) then
    return
  end
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putpy(self, ss, es, ptype, pdata)
  self:put(ss, es, self.out_python, { ptype, pdata })
end
function _decoder.symbols_clear(self)
  local syms
  syms = (function()
  local _v
  _v = self.symbols
  if logicview.truth(_v) then return _v end
  _v = {  }
  return _v
end)()
  self.symbols = {  }
  return syms
end
function _decoder.symbols_append(self, ss, es, symbol, data)
  if data == nil then data = nil end
  local item
  if logicview.truth((self.symbols == nil)) then
    self.symbols = {  }
  end
  item = { ss, es, symbol, data }
  _table.insert(self.symbols, item)
end
function _decoder.symbols_get_last(self, count)
  if count == nil then count = nil end
  local items
  if logicview.truth((not logicview.truth(self.symbols))) then
    return nil
  end
  if logicview.truth((count == nil)) then
    count = 1
  end
  if logicview.truth((logicview.len(self.symbols) < count)) then
    return nil
  end
  items = logicview.slice(self.symbols, (-count), nil, nil)
  if logicview.truth(logicview.eq(count, 1)) then
    items = logicview.idx(items, 0)
  end
  return items
end
function _decoder.symbols_update_last(self, ss, es, symbol, data)
  if data == nil then data = nil end
  local item
  if logicview.truth((not logicview.truth(self.symbols))) then
    return nil
  end
  item = logicview.copy(logicview.idx(self.symbols, (-1)))
  if logicview.truth((ss ~= nil)) then
    logicview.setidx(item, 0, ss)
  end
  if logicview.truth((es ~= nil)) then
    logicview.setidx(item, 1, es)
  end
  if logicview.truth((symbol ~= nil)) then
    logicview.setidx(item, 2, symbol)
  end
  if logicview.truth((data ~= nil)) then
    logicview.setidx(item, 3, data)
  end
  logicview.setidx(self.symbols, (-1), logicview.copy(item))
end
function _decoder.symbols_has_prev(self, want_items)
  local sym_off, idx, want_item
  if logicview.truth((not logicview.truth(logicview.is_a(want_items, { "list", "tuple" })))) then
    want_items = { want_items }
  end
  if logicview.truth((self.symbols == nil)) then
    return false
  end
  if logicview.truth((logicview.len(self.symbols) < logicview.len(want_items))) then
    return false
  end
  sym_off = (logicview.len(self.symbols) - logicview.len(want_items))
  for _lv_i, _lv_v in logicview.enumerate(want_items) do
    idx = _lv_i
    want_item = _lv_v
    if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(self.symbols, logicview.add(sym_off, idx)), 2), want_item))) then
      return false
    end
    ::continue_1::
  end
  return true
end
function _decoder.symbols_collapse(self, count, symbol, data, squeeze)
  if data == nil then data = nil end
  if squeeze == nil then squeeze = nil end
  local last_data, ss, es, item
  if logicview.truth((self.symbols == nil)) then
    return nil
  end
  if logicview.truth((logicview.len(self.symbols) < count)) then
    return nil
  end
  do
    local _lv_a0, _lv_a1 = logicview.slice(self.symbols, nil, (-count), nil), logicview.slice(self.symbols, (-count), nil, nil)
    self.symbols = _lv_a0
    last_data = _lv_a1
  end
  while logicview.truth((function()
  local _v
  _v = squeeze
  if not logicview.truth(_v) then return _v end
  _v = self.symbols
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(self.symbols, (-1)), 2), squeeze)
  return _v
end)()) do
    logicview.list_insert(last_data, 0, logicview.list_pop(self.symbols))
    ::continue_2::
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(last_data, 0), 0), logicview.idx(logicview.idx(last_data, (-1)), 1)
    ss = _lv_a0
    es = _lv_a1
  end
  if logicview.truth((data == nil)) then
    data = last_data
  end
  item = { ss, es, symbol, data }
  _table.insert(self.symbols, item)
end
function _decoder.frame_flush(self)
  local syms, text, data, sym, b, ss, es
  syms = self:symbols_clear()
  while logicview.truth((function()
  local _v
  _v = syms
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(syms, 0), 2), "IDLE")
  return _v
end)()) do
    logicview.list_pop(syms, 0)
    ::continue_3::
  end
  while logicview.truth((function()
  local _v
  _v = syms
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(syms, (-1)), 2), "IDLE")
  return _v
end)()) do
    logicview.list_pop(syms, (-1))
    ::continue_4::
  end
  if logicview.truth((not logicview.truth(syms))) then
    return
  end
  text = {  }
  data = {  }
  for _lv_item in logicview.iter(syms) do
    sym = _lv_item
    if logicview.truth(logicview.eq(logicview.idx(sym, 2), "FRAME_INIT")) then
      _table.insert(text, "INIT")
      _table.insert(data, "INIT")
      goto continue_5
    end
    if logicview.truth(logicview.eq(logicview.idx(sym, 2), "SYNC_PAD")) then
      if logicview.truth((function()
  local _v
  _v = (not logicview.truth(text))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(text, (-1)), "SYNC"))
  return _v
end)()) then
        _table.insert(text, "SYNC")
        _table.insert(data, "SYNC")
      end
      goto continue_5
    end
    if logicview.truth(logicview.eq(logicview.idx(sym, 2), "DATA_BYTE")) then
      b = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.idx(sym, 3)) do
    bit = _lv_item
    if logicview.truth(logicview.eq(logicview.idx(bit, 2), "DATA_BIT")) then
    _lv_out[#_lv_out + 1] = logicview.idx(bit, 3)
  end
    end
  return _lv_out
end)()
      b = bitpack(b)
      _table.insert(text, logicview.pyformat("{:02x}", { b }, logicview.dict({})))
      _table.insert(data, b)
      goto continue_5
    end
    if logicview.truth(logicview.eq(logicview.idx(sym, 2), "SHORT_BIT")) then
      if logicview.truth((function()
  local _v
  _v = (not logicview.truth(text))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(text, (-1)), "SHORT"))
  return _v
end)()) then
        _table.insert(text, "SHORT")
        _table.insert(data, "SHORT")
      end
      goto continue_5
    end
    if logicview.truth(logicview.eq(logicview.idx(sym, 2), "WAIT_ACK")) then
      _table.insert(text, "WAIT")
      _table.insert(data, "WAIT")
      goto continue_5
    end
    ::continue_5::
  end
  text = logicview.join(" ", text)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(syms, 0), 0), logicview.idx(logicview.idx(syms, (-1)), 1)
    ss = _lv_a0
    es = _lv_a1
  end
  self:putg(ss, es, { ANN_FRAME_BYTES, { text } })
  self:putpy(ss, es, "FRAME_DATA", data)
end
function _decoder.carrier_flush(self)
  local ss, es
  if logicview.truth(self.carrier_busy_ss) then
    do
      local _lv_a0, _lv_a1 = self.carrier_busy_ss, self.samplenum
      ss = _lv_a0
      es = _lv_a1
    end
    self:putg(ss, es, { ANN_CARRIER_BUSY, { "BUSY" } })
  end
  if logicview.truth(self.carrier_idle_ss) then
    do
      local _lv_a0, _lv_a1 = self.carrier_idle_ss, self.samplenum
      ss = _lv_a0
      es = _lv_a1
    end
    ss = logicview.add(ss, logicview.tointeger(self.idle_width))
    if logicview.truth((ss < es)) then
      self:putg(ss, es, { ANN_CARRIER_IDLE, { "IDLE" } })
    end
  end
end
function _decoder.carrier_set_idle(self, on, ss, es)
  if logicview.truth(on) then
    if logicview.truth((not logicview.truth(self.carrier_idle_ss))) then
      self.carrier_idle_ss = logicview.tointeger(ss)
    end
    if logicview.truth((not logicview.truth(self:symbols_has_prev("IDLE")))) then
      self:symbols_append(ss, ss, "IDLE")
    end
    self:symbols_update_last(nil, es, nil)
    self:frame_flush()
    self:reset_state()
    self.carrier_is_idle = true
    self.carrier_want_idle = false
    return
  end
  if logicview.truth(self:symbols_has_prev("IDLE")) then
    self:symbols_update_last(nil, es, nil)
  end
  self:carrier_flush()
  self.carrier_is_idle = false
  self.carrier_idle_ss = nil
end
function _decoder.carrier_set_busy(self, on, snum)
  self.carrier_is_busy = on
  if logicview.truth(on) then
    self.carrier_is_idle = nil
    if logicview.truth((not logicview.truth(self.carrier_busy_ss))) then
      self.carrier_busy_ss = snum
    end
    return
  end
  if logicview.truth(self.carrier_busy_ss) then
    self:putg(self.carrier_busy_ss, snum, { ANN_CARRIER_BUSY, { "BUSY" } })
  end
  self.carrier_busy_ss = nil
  self.carrier_is_busy = false
end
function _decoder.carrier_check(self, level, snum)
  local span
  if logicview.truth(level) then
    self:carrier_set_idle(false, snum, snum)
    self:carrier_set_busy(true, snum)
    return
  end
  if logicview.truth((not logicview.truth(self.carrier_idle_ss))) then
    self.carrier_idle_ss = logicview.tointeger(snum)
  end
  span = (snum - self.carrier_idle_ss)
  if logicview.truth((span >= self.byte_width)) then
    self:carrier_set_busy(false, snum)
  end
  if logicview.truth((span >= self.idle_width)) then
    self:carrier_set_idle(true, logicview.add(self.carrier_idle_ss, self.idle_width), snum)
  end
end
function _decoder.span_prepare(self)
  local mode_times, _get_range
  mode_times = logicview.idx(self.mode_times, logicview.idx(self.options, "mode"))
  mode_times = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(mode_times) do
    t = _lv_item
    _lv_out[#_lv_out + 1] = logicview.mul(t, 1.0)
  end
  return _lv_out
end)()
  do
    local _lv_seq = mode_times
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    self.data_width = logicview.idx(_lv_seq, 0)
    self.pad_width = logicview.idx(_lv_seq, 1)
  end
  self.byte_width = logicview.add(self.pad_width, logicview.mul(9, self.data_width))
  self.add_idle_width = logicview.idx(self.options, "idle_add_us")
  self.idle_width = logicview.add(self.byte_width, self.add_idle_width)
  self.usec_width = (self.samplerate / 1000000.0)
  self.hold_high_width = logicview.mul(logicview.mul(9, self.time_tol_abs), self.usec_width)
  _get_range = function(width)
    local reladd, absadd, lower, upper
    reladd = (self.time_tol_perc / 100)
    absadd = self.time_tol_abs
    lower = _math.min(logicview.mul(width, (1 - reladd)), (width - absadd))
    upper = _math.max(logicview.mul(width, logicview.add(1, reladd)), logicview.add(width, absadd))
    lower = floor(logicview.mul(lower, self.usec_width))
    upper = ceil(logicview.mul(upper, self.usec_width))
    return { lower, logicview.add(upper, 1) }
  end
  self.data_bit_1_range = _get_range(logicview.mul(self.data_width, 1))
  self.data_bit_2_range = _get_range(logicview.mul(self.data_width, 2))
  self.data_bit_3_range = _get_range(logicview.mul(self.data_width, 3))
  self.data_bit_4_range = _get_range(logicview.mul(self.data_width, 4))
  self.short_data_range = _get_range((self.data_width / 4))
  self.pad_bit_range = _get_range(self.pad_width)
  self.data_width = logicview.mul(self.data_width, self.usec_width)
  self.pad_width = logicview.mul(self.pad_width, self.usec_width)
  self.byte_width = logicview.mul(self.byte_width, self.usec_width)
  self.idle_width = logicview.mul(self.idle_width, self.usec_width)
  self.lookahead_width = logicview.tointeger(logicview.mul(4, self.data_width))
end
function _decoder.span_snum_to_us(self, count)
  return (count / self.usec_width)
end
function _decoder.span_is_pad(self, span)
  return logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)
end
function _decoder.span_is_data(self, span)
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)) then
    return 1
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)) then
    return 2
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)) then
    return 3
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)) then
    return 4
  end
  return false
end
function _decoder.span_is_short(self, span)
  return logicview.contains((function() local _t = {}; for _v in logicview.range() do _t[#_t + 1] = _v end; return _t end)(), span)
end
function _decoder.wait_until(self, want)
  local diff, pins
  want = logicview.tointeger(want)
  while true do
    diff = _math.max((want - self.samplenum), 1)
    pins = self:wait({ logicview.dict({ [PIN_DATA] = "e" }), logicview.dict({ skip = diff }) })
    self:carrier_check(logicview.idx(pins, PIN_DATA), self.samplenum)
    if logicview.truth((self.samplenum >= want)) then
      return pins
    end
    ::continue_6::
  end
end
function _decoder.decode(self)
  local curr_level, last_snum, bit_level, edge_seen, curr_snum, span, is_pad, is_data, is_short, ss, es, texts, took_low, next_snum, sync_pad_seq, frame_init_seq, keep, wait_ack_seq, fast_cont, bit_field, bit_ss, bit_idx, bit_es, bit_snum, end_snum, hold, data_byte, byte_seq, sync_resp_seq
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.samplerate))
  if logicview.truth(_v) then return _v end
  _v = (self.samplerate < 1000000.0)
  return _v
end)()) then
    _error(SamplerateError("Need a samplerate of at least 1MSa/s"), 0)
  end
  while true do
    if logicview.truth((not logicview.truth(self.edges))) then
      do
        local _lv_seq = self:wait(logicview.dict({ [PIN_DATA] = "l" }))
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        curr_level = logicview.idx(_lv_seq, 0)
      end
      self:carrier_check(curr_level, self.samplenum)
      self.edges = { self.samplenum }
      goto continue_7
    end
    last_snum = self.samplenum
    do
      local _lv_seq = self:wait({ logicview.dict({ [PIN_DATA] = "e" }), logicview.dict({ skip = self.lookahead_width }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      curr_level = logicview.idx(_lv_seq, 0)
    end
    self:carrier_check(curr_level, self.samplenum)
    bit_level = curr_level
    edge_seen = (self.matched & 1)
    if logicview.truth(edge_seen) then
      bit_level = (1 - bit_level)
    end
    if logicview.truth((not logicview.truth(self.edges))) then
      self.edges = { self.samplenum }
      goto continue_7
    end
    _table.insert(self.edges, self.samplenum)
    curr_snum = self.samplenum
    span = (logicview.idx(self.edges, (-1)) - logicview.idx(self.edges, (-2)))
    is_pad = (function()
  local _v
  _v = bit_level
  if not logicview.truth(_v) then return _v end
  _v = self:span_is_pad(span)
  return _v
end)()
    is_data = self:span_is_data(span)
    is_short = (function()
  local _v
  _v = bit_level
  if not logicview.truth(_v) then return _v end
  _v = self:span_is_short(span)
  return _v
end)()
    if logicview.truth(is_pad) then
      do
        local _lv_a0, _lv_a1 = logicview.idx(self.edges, (-2)), curr_snum
        ss = _lv_a0
        es = _lv_a1
      end
      texts = { "PAD", logicview.pyformat("{:d}", { bit_level }, logicview.dict({})) }
      self:putg(ss, es, { ANN_PAD_BIT, texts })
      self:symbols_append(ss, es, "PAD_BIT", bit_level)
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      self:putpy(ss, es, "PAD_BIT", bit_level)
      goto continue_7
    end
    if logicview.truth(is_short) then
      do
        local _lv_a0, _lv_a1 = last_snum, curr_snum
        ss = _lv_a0
        es = _lv_a1
      end
      texts = { "SHORT", logicview.pyformat("{:d}", { bit_level }, logicview.dict({})) }
      self:putg(ss, es, { ANN_SHORT_DATA, texts })
      self:symbols_append(ss, es, "SHORT_BIT", bit_level)
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      self:putpy(ss, es, "SHORT_BIT", bit_level)
      goto continue_7
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(bit_level))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.symbols))
  if not logicview.truth(_v) then return _v end
  _v = self.carrier_want_idle
  return _v
end)()) then
      goto continue_7
    end
    if logicview.truth((not logicview.truth(bit_level))) then
      if logicview.truth(self:symbols_has_prev("DATA_BYTE")) then
        goto continue_7
      end
      if logicview.truth(self:symbols_has_prev("SHORT_BIT")) then
        goto continue_7
      end
      if logicview.truth(self:symbols_has_prev("WAIT_ACK")) then
        goto continue_7
      end
    end
    took_low = false
    if logicview.truth((function()
  local _v
  _v = is_data
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(bit_level))
  if not logicview.truth(_v) then return _v end
  _v = self:symbols_has_prev("PAD_BIT")
  return _v
end)()) then
      took_low = true
      is_data = (is_data - 1)
      next_snum = logicview.tointeger(logicview.add(last_snum, self.data_width))
      do
        local _lv_a0, _lv_a1 = last_snum, next_snum
        ss = _lv_a0
        es = _lv_a1
      end
      texts = { "ZERO", logicview.pyformat("{:d}", { bit_level }, logicview.dict({})) }
      self:putg(ss, es, { ANN_LOW_BIT, texts })
      self:symbols_append(ss, es, "ZERO_BIT", bit_level)
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      self:putpy(ss, es, "DATA_BIT", bit_level)
      self.data_fall_time = last_snum
      last_snum = next_snum
    end
    sync_pad_seq = { "PAD_BIT", "ZERO_BIT" }
    if logicview.truth(self:symbols_has_prev(sync_pad_seq)) then
      self:symbols_collapse(logicview.len(sync_pad_seq), "SYNC_PAD")
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      self:putpy(ss, es, "SYNC_PAD", true)
      self.data_bits = {  }
    end
    frame_init_seq = logicview.mul(3, { "SYNC_PAD" })
    if logicview.truth(self:symbols_has_prev(frame_init_seq)) then
      self:symbols_collapse(logicview.len(frame_init_seq), "FRAME_INIT")
      if logicview.truth((logicview.len(self.symbols) > 1)) then
        keep = logicview.list_pop(self.symbols, (-1))
        self:frame_flush()
        logicview.list_clear(self.symbols)
        _table.insert(self.symbols, keep)
      end
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      texts = { "FRAME INIT", "INIT", "I" }
      self:putg(ss, es, { ANN_FRAME_INIT, texts })
      self:putpy(ss, es, "FRAME_INIT", true)
      self.frame_bytes = {  }
    end
    wait_ack_seq = { "SHORT_BIT", "SYNC_PAD" }
    if logicview.truth(self:symbols_has_prev(wait_ack_seq)) then
      self:symbols_collapse(logicview.len(wait_ack_seq), "WAIT_ACK")
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      texts = { "WAIT for sync response", "WAIT response", "WAIT", "W" }
      self:putg(ss, es, { ANN_FRAME_WAIT, texts })
      self:putpy(ss, es, "SYNC_RESP_WAIT", true)
    end
    if logicview.truth((function()
  local _v
  _v = took_low
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_data))
  return _v
end)()) then
      goto continue_7
    end
    if logicview.truth((not logicview.truth(is_data))) then
      fast_cont = (function()
  local _v
  _v = edge_seen
  if not logicview.truth(_v) then return _v end
  _v = curr_level
  return _v
end)()
      do
        local _lv_a0, _lv_a1 = last_snum, curr_snum
        ss = _lv_a0
        es = _lv_a1
      end
      texts = { "failed pulse length check", "pulse length", "length" }
      self:putg(ss, es, { ANN_SYNC_LOSS, texts })
      self:frame_flush()
      self:carrier_flush()
      self:reset_state()
      if logicview.truth(fast_cont) then
        self.edges = { self.samplenum }
      end
      goto continue_7
    end
    if logicview.truth((not logicview.truth(self:symbols_has_prev("SYNC_PAD")))) then
      fast_cont = (function()
  local _v
  _v = edge_seen
  if not logicview.truth(_v) then return _v end
  _v = curr_level
  return _v
end)()
      self:frame_flush()
      self:carrier_flush()
      self:reset_state()
      if logicview.truth(fast_cont) then
        self.edges = { self.samplenum }
      end
      goto continue_7
    end
    bit_field = {  }
    bit_ss = logicview.add(self.data_fall_time, self.data_width)
    for _lv_i in logicview.range(8) do
      bit_idx = _lv_i
      bit_es = logicview.add(bit_ss, self.data_width)
      bit_snum = (logicview.add(bit_es, bit_ss) / 2)
      if logicview.truth((bit_snum > self.samplenum)) then
        do
          local _lv_seq = self:wait_until(bit_snum)
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          bit_level = logicview.idx(_lv_seq, 0)
        end
      end
      do
        local _lv_a0, _lv_a1 = ceil(bit_ss), floor(bit_es)
        ss = _lv_a0
        es = _lv_a1
      end
      texts = { logicview.pyformat("{:d}", { bit_level }, logicview.dict({})) }
      self:putg(ss, es, { ANN_DATA_BIT, texts })
      self:symbols_append(ss, es, "DATA_BIT", bit_level)
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      self:putpy(ss, es, "DATA_BIT", bit_level)
      _table.insert(bit_field, bit_level)
      if logicview.truth((self.data_bits ~= nil)) then
        _table.insert(self.data_bits, bit_level)
      end
      bit_ss = bit_es
      ::continue_8::
    end
    end_snum = bit_es
    do
      local _lv_seq = self:wait_until(end_snum)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      curr_level = logicview.idx(_lv_seq, 0)
    end
    curr_snum = self.samplenum
    if logicview.truth(curr_level) then
      hold = self.hold_high_width
      do
        local _lv_seq = self:wait({ logicview.dict({ [PIN_DATA] = "l" }), logicview.dict({ skip = logicview.tointeger(hold) }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        curr_level = logicview.idx(_lv_seq, 0)
      end
      self:carrier_check(curr_level, self.samplenum)
      if logicview.truth((self.matched & 2)) then
        _table.insert(self.edges, curr_snum)
        curr_level = (1 - curr_level)
      end
      curr_snum = self.samplenum
    end
    data_byte = bitpack(bit_field)
    if logicview.truth((self.data_bits ~= nil)) then
      data_byte = bitpack(self.data_bits)
      logicview.list_clear(self.data_bits)
      if logicview.truth((self.frame_bytes ~= nil)) then
        _table.insert(self.frame_bytes, data_byte)
      end
    end
    byte_seq = logicview.add({ "SYNC_PAD" }, logicview.mul(8, { "DATA_BIT" }))
    if logicview.truth(self:symbols_has_prev(byte_seq)) then
      self:symbols_collapse(logicview.len(byte_seq), "DATA_BYTE")
      do
        local _lv_seq = logicview.slice(self:symbols_get_last(), nil, 2, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ss = logicview.idx(_lv_seq, 0)
        es = logicview.idx(_lv_seq, 1)
      end
      texts = { logicview.pyformat("{:02x}", { data_byte }, logicview.dict({})) }
      self:putg(ss, es, { ANN_DATA_BYTE, texts })
      self:putpy(ss, es, "DATA_BYTE", data_byte)
    end
    sync_resp_seq = logicview.add({ "WAIT_ACK" }, { "DATA_BYTE" })
    if logicview.truth(self:symbols_has_prev(sync_resp_seq)) then
      self:frame_flush()
    end
    ::continue_7::
  end
end

return _decoder
