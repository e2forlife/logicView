-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Uli Huber
-- Copyright (C) 2020 Soeren Apel

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
local ann_bit, ann_stat_bit, ann_type, ann_command, ann_parameter, ann_parity, ann_pos, ann_status, ann_warning, frame_type_none, frame_type_command, frame_type_16bit_pos, frame_type_18bit_pos, Decoder
local _decoder

do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ann_bit = logicview.idx(_lv_seq, 0)
  ann_stat_bit = logicview.idx(_lv_seq, 1)
  ann_type = logicview.idx(_lv_seq, 2)
  ann_command = logicview.idx(_lv_seq, 3)
  ann_parameter = logicview.idx(_lv_seq, 4)
  ann_parity = logicview.idx(_lv_seq, 5)
  ann_pos = logicview.idx(_lv_seq, 6)
  ann_status = logicview.idx(_lv_seq, 7)
  ann_warning = logicview.idx(_lv_seq, 8)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(4) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  frame_type_none = logicview.idx(_lv_seq, 0)
  frame_type_command = logicview.idx(_lv_seq, 1)
  frame_type_16bit_pos = logicview.idx(_lv_seq, 2)
  frame_type_18bit_pos = logicview.idx(_lv_seq, 3)
end
_decoder = {
  api_version = 3,
  id = "xy2-100",
  name = "XY2-100",
  longname = "XY2-100(E) and XY-200(E) galvanometer protocol",
  desc = "Serial protocol for galvanometer positioning in laser systems",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "sync", name = "SYNC", desc = "Sync" }), logicview.dict({ id = "data", name = "DATA", desc = "X, Y or Z axis data" }) },
  optional_channels = { logicview.dict({ id = "status", name = "STAT", desc = "X, Y or Z axis status" }) },
  options = {  },
  annotations = { { "bit", "Data Bit" }, { "stat_bit", "Status Bit" }, { "type", "Frame Type" }, { "command", "Command" }, { "parameter", "Parameter" }, { "parity", "Parity" }, { "position", "Position" }, { "status", "Status" }, { "warning", "Human-readable warnings" } },
  annotation_rows = { { "bits", "Data Bits", { 0 } }, { "stat_bits", "Status Bits", { 1 } }, { "data", "Data", { 2, 3, 4, 5 } }, { "positions", "Positions", { 6 } }, { "statuses", "Statuses", { 7 } }, { "warnings", "Warnings", { 8 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self.samplerate = nil
  self:reset()
end
function _decoder.reset(self)
  self.bits = {  }
  self.stat_bits = {  }
  self.stat_skip_bit = true
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.put_ann(self, ss, es, ann_class, value)
  self:put(ss, es, self.out_ann, { ann_class, value })
end
function _decoder.process_bit(self, sync, bit_ss, bit_es, bit_value)
  local parity, ss, es, value, par_ss, par_es, par_value, parity_even, parity_odd, type_1_value, type_3_value, type, parity_status, type_ss, type_es, pos, count, cmd, cmd_es, param
  self:put_ann(bit_ss, bit_es, ann_bit, { logicview.pymod("%d", bit_value) })
  _table.insert(self.bits, { bit_ss, bit_es, bit_value })
  if logicview.truth(logicview.eq(sync, 0)) then
    if logicview.truth((logicview.len(self.bits) < 20)) then
      self:put_ann(logicview.idx(logicview.idx(self.bits, 0), 0), bit_es, ann_warning, { "Not enough data bits" })
      self:reset()
      return
    end
    parity = 0
    for _lv_item in logicview.iter(logicview.slice(self.bits, nil, (-1), nil)) do
      ss = logicview.idx(_lv_item, 0)
      es = logicview.idx(_lv_item, 1)
      value = logicview.idx(_lv_item, 2)
      parity = (parity ~ value)
      ::continue_1::
    end
    do
      local _lv_seq = logicview.idx(self.bits, 19)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      par_ss = logicview.idx(_lv_seq, 0)
      par_es = logicview.idx(_lv_seq, 1)
      par_value = logicview.idx(_lv_seq, 2)
    end
    parity_even = 0
    parity_odd = 0
    if logicview.truth(logicview.eq(par_value, parity)) then
      parity_even = 1
    else
      parity_odd = 1
    end
    type_1_value = logicview.idx(logicview.idx(self.bits, 0), 2)
    type_3_value = (((logicview.idx(logicview.idx(self.bits, 0), 2) << 2) | (logicview.idx(logicview.idx(self.bits, 1), 2) << 1)) | logicview.idx(logicview.idx(self.bits, 2), 2))
    type = frame_type_none
    parity_status = { "X", "Unknown" }
    type_ss = logicview.idx(logicview.idx(self.bits, 0), 0)
    type_es = logicview.idx(logicview.idx(self.bits, 2), 1)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(type_1_value, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(parity_odd, 1)
  return _v
end)()) then
      type = frame_type_18bit_pos
      type_es = logicview.idx(logicview.idx(self.bits, 0), 1)
      self:put_ann(logicview.idx(logicview.idx(self.bits, 0), 0), bit_es, ann_warning, { "Careful: 18-bit position frames with wrong parity and command frames with wrong parity cannot be identified" })
    elseif logicview.truth(logicview.eq(type_3_value, 1)) then
      type = frame_type_16bit_pos
      if logicview.truth(logicview.eq(parity_even, 1)) then
        parity_status = { "OK" }
      else
        parity_status = { "NOK" }
        self:put_ann(logicview.idx(logicview.idx(self.bits, 0), 0), bit_es, ann_warning, { "Parity error", "PE" })
      end
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(type_3_value, 7)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(parity_even, 1)
  return _v
end)()) then
      type = frame_type_command
      self:put_ann(logicview.idx(logicview.idx(self.bits, 0), 0), bit_es, ann_warning, { "Careful: 18-bit position frames with wrong parity and command frames with wrong parity cannot be identified" })
    else
      self:put_ann(logicview.idx(logicview.idx(self.bits, 0), 0), bit_es, ann_warning, { "Error", "Unknown command or parity error" })
      self:reset()
      return
    end
    if logicview.truth(logicview.eq(type, frame_type_16bit_pos)) then
      self:put_ann(type_ss, type_es, ann_type, { "16 bit Position Frame", "16 bit Pos", "Pos", "P" })
    end
    if logicview.truth(logicview.eq(type, frame_type_18bit_pos)) then
      self:put_ann(type_ss, type_es, ann_type, { "18 bit Position Frame", "18 bit Pos", "Pos", "P" })
    end
    if logicview.truth(logicview.eq(type, frame_type_command)) then
      self:put_ann(type_ss, type_es, ann_type, { "Command Frame", "Command", "C" })
    end
    self:put_ann(par_ss, par_es, ann_parity, parity_status)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(type, frame_type_16bit_pos)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(type, frame_type_18bit_pos)
  return _v
end)()) then
      pos = 0
      if logicview.truth(logicview.eq(type, frame_type_16bit_pos)) then
        count = 15
        for _lv_item in logicview.iter(logicview.slice(self.bits, 3, 19, nil)) do
          ss = logicview.idx(_lv_item, 0)
          es = logicview.idx(_lv_item, 1)
          value = logicview.idx(_lv_item, 2)
          pos = (pos | (value << count))
          count = (count - 1)
          ::continue_2::
        end
        pos = (function() if logicview.truth((pos < 32768)) then return pos else return (pos - 65536) end end)()
      else
        count = 17
        for _lv_item in logicview.iter(logicview.slice(self.bits, 3, 19, nil)) do
          ss = logicview.idx(_lv_item, 0)
          es = logicview.idx(_lv_item, 1)
          value = logicview.idx(_lv_item, 2)
          pos = (pos | (value << count))
          count = (count - 1)
          ::continue_3::
        end
        pos = (function() if logicview.truth((pos < 131072)) then return pos else return (pos - 262144) end end)()
      end
      self:put_ann(type_es, par_ss, ann_pos, { logicview.pymod("%d", pos) })
    end
    if logicview.truth(logicview.eq(type, frame_type_command)) then
      count = 7
      cmd = 0
      cmd_es = 0
      for _lv_item in logicview.iter(logicview.slice(self.bits, 3, 11, nil)) do
        ss = logicview.idx(_lv_item, 0)
        es = logicview.idx(_lv_item, 1)
        value = logicview.idx(_lv_item, 2)
        cmd = (cmd | (value << count))
        count = (count - 1)
        cmd_es = es
        ::continue_4::
      end
      self:put_ann(type_es, cmd_es, ann_command, { logicview.pymod("Command 0x%X", cmd), logicview.pymod("Cmd 0x%X", cmd), logicview.pymod("0x%X", cmd) })
      count = 7
      param = 0
      for _lv_item in logicview.iter(logicview.slice(self.bits, 11, 19, nil)) do
        ss = logicview.idx(_lv_item, 0)
        es = logicview.idx(_lv_item, 1)
        value = logicview.idx(_lv_item, 2)
        param = (param | (value << count))
        count = (count - 1)
        ::continue_5::
      end
      self:put_ann(cmd_es, par_ss, ann_parameter, { logicview.pymod("Parameter 0x%X / %d", { param, param }), logicview.pymod("0x%X / %d", { param, param }), logicview.pymod("0x%X", param) })
    end
    self:reset()
  end
end
function _decoder.process_stat_bit(self, sync, bit_ss, bit_es, bit_value)
  local stat_ss, stat_es, status, count, ss, es, value
  if logicview.truth(self.stat_skip_bit) then
    self.stat_skip_bit = false
    return
  end
  self:put_ann(bit_ss, bit_es, ann_stat_bit, { logicview.pymod("%d", bit_value) })
  _table.insert(self.stat_bits, { bit_ss, bit_es, bit_value })
  if logicview.truth((function()
  local _v
  _v = logicview.eq(sync, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.stat_bits), 19)
  return _v
end)()) then
    stat_ss = logicview.idx(logicview.idx(self.stat_bits, 0), 0)
    stat_es = logicview.idx(logicview.idx(self.stat_bits, 18), 1)
    status = 0
    count = 18
    for _lv_item in logicview.iter(self.stat_bits) do
      ss = logicview.idx(_lv_item, 0)
      es = logicview.idx(_lv_item, 1)
      value = logicview.idx(_lv_item, 2)
      status = (status | (value << count))
      count = (count - 1)
      ::continue_6::
    end
    self:put_ann(stat_ss, stat_es, ann_status, { logicview.pymod("Status 0x%X", status), logicview.pymod("0x%X", status) })
  end
end
function _decoder.decode(self)
  local bit_ss, bit_es, bit_value, stat_ss, stat_es, stat_value, sync_value, has_stat, clk, sync, data, stat
  bit_ss = nil
  bit_es = nil
  bit_value = 0
  stat_ss = nil
  stat_es = nil
  stat_value = 0
  sync_value = 0
  has_stat = self:has_channel(3)
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      sync = logicview.idx(_lv_seq, 1)
      data = logicview.idx(_lv_seq, 2)
      stat = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth(logicview.eq(clk, 1)) then
      stat_value = stat
      bit_es = self.samplenum
      if logicview.truth(bit_ss) then
        self:process_bit(sync_value, bit_ss, bit_es, bit_value)
      end
      bit_ss = self.samplenum
    else
      bit_value = data
      sync_value = sync
      stat_es = self.samplenum
      if logicview.truth((function()
  local _v
  _v = stat_ss
  if not logicview.truth(_v) then return _v end
  _v = has_stat
  return _v
end)()) then
        self:process_stat_bit(sync_value, stat_ss, stat_es, stat_value)
      end
      stat_ss = self.samplenum
    end
    ::continue_7::
  end
end

return _decoder
