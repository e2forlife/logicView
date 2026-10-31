-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Stephan Thiele <stephan.thiele@mailbox.org>

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
local LinFsm, Decoder
local _decoder

LinFsm = {}
LinFsm.__index = LinFsm
State = {}
State.__index = State
State.WaitForBreak = "WAIT_FOR_BREAK"
State.Sync = "SYNC"
State.Pid = "PID"
State.Data = "DATA"
State.Checksum = "CHECKSUM"
State.Error = "ERROR"
function LinFsm.transit(self, target_state)
  if logicview.truth((not logicview.truth(self:_transition_allowed(target_state)))) then
    return false
  end
  self.state = target_state
  return true
end
function LinFsm._transition_allowed(self, target_state)
  if logicview.truth(logicview.eq(target_state, LinFsm.State.Error)) then
    return true
  end
  return logicview.contains(logicview.idx(self.allowed_state, self.state), target_state)
end
function LinFsm.reset(self)
  self.state = LinFsm.State.WaitForBreak
end
function LinFsm.__init__(self)
  local a
  a = logicview.dict({})
  logicview.setidx(a, LinFsm.State.WaitForBreak, { LinFsm.State.Sync })
  logicview.setidx(a, LinFsm.State.Sync, { LinFsm.State.Pid })
  logicview.setidx(a, LinFsm.State.Pid, { LinFsm.State.Data })
  logicview.setidx(a, LinFsm.State.Data, { LinFsm.State.Data, LinFsm.State.Checksum })
  logicview.setidx(a, LinFsm.State.Checksum, { LinFsm.State.WaitForBreak })
  logicview.setidx(a, LinFsm.State.Error, { LinFsm.State.Sync })
  self.allowed_state = a
  self.state = nil
  self:reset()
end
function LinFsm.new(...)
  local self = _setmetatable({}, LinFsm)
  LinFsm.__init__(self, ...)
  return self
end
_decoder = {
  api_version = 3,
  id = "lin",
  name = "LIN",
  longname = "Local Interconnect Network",
  desc = "Local Interconnect Network (LIN) protocol.",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Automotive" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "version", desc = "Protocol version", default = 2, values = { 1, 2 } }) },
  annotations = { { "data", "LIN data" }, { "control", "Protocol info" }, { "error", "Error descriptions" }, { "inline_error", "Protocol violations and errors" } },
  annotation_rows = { { "data", "Data", { 0, 1, 3 } }, { "error", "Error", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.fsm = LinFsm.new()
  self.lin_header = {  }
  self.lin_rsp = {  }
  self.lin_version = nil
  self.out_ann = nil
  self.ss_block = nil
  self.es_block = nil
  self.done_break = false
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.lin_version = logicview.idx(self.options, "version")
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.wipe_break_null_byte(self, value)
  if logicview.truth((not logicview.contains({ LinFsm.State.WaitForBreak, LinFsm.State.Error }, self.fsm.state))) then
    if logicview.truth(logicview.len(self.lin_rsp)) then
      value = logicview.idx(logicview.list_pop(self.lin_rsp), 2)
    else
      logicview.list_pop(self.lin_header)
    end
  end
  if logicview.truth((not logicview.eq(value, 0))) then
    self.fsm:transit(LinFsm.State.Error)
    self:handle_error(nil)
    return false
  end
  return true
end
function _decoder.handle_wait_for_break(self, value)
  self:wipe_break_null_byte(value)
end
function _decoder.handle_break(self, value)
  if logicview.truth((not logicview.contains({ LinFsm.State.WaitForBreak, LinFsm.State.Error }, self.fsm.state))) then
    if logicview.truth(self:wipe_break_null_byte(value)) then
      self.fsm:transit(LinFsm.State.Checksum)
      self:handle_checksum()
    end
  end
  self.fsm:reset()
  self.fsm:transit(LinFsm.State.Sync)
  self.done_break = true
  self:putx({ 1, { "Break condition", "Break", "Brk", "B" } })
end
function _decoder.handle_sync(self, value)
  self.fsm:transit(LinFsm.State.Pid)
  _table.insert(self.lin_header, { self.ss_block, self.es_block, value })
end
function _decoder.handle_pid(self, value)
  self.fsm:transit(LinFsm.State.Data)
  _table.insert(self.lin_header, { self.ss_block, self.es_block, value })
end
function _decoder.handle_data(self, value)
  _table.insert(self.lin_rsp, { self.ss_block, self.es_block, value })
end
function _decoder.handle_checksum(self)
  local sync, pid, checksum, id_, parity, expected_parity, parity_valid, ann_class, checksum_valid, b
  sync = (function() if logicview.truth(logicview.len(self.lin_header)) then return logicview.list_pop(self.lin_header, 0) else return nil end end)()
  self:put(logicview.idx(sync, 0), logicview.idx(sync, 1), self.out_ann, { 0, { "Sync", "S" } })
  if logicview.truth((not logicview.eq(logicview.idx(sync, 2), 85))) then
    self:put(logicview.idx(sync, 0), logicview.idx(sync, 1), self.out_ann, { 2, { "Sync is not 0x55", "Not 0x55", "!= 0x55" } })
  end
  pid = (function() if logicview.truth(logicview.len(self.lin_header)) then return logicview.list_pop(self.lin_header, 0) else return nil end end)()
  checksum = (function() if logicview.truth(logicview.len(self.lin_rsp)) then return logicview.list_pop(self.lin_rsp) else return nil end end)()
  if logicview.truth(pid) then
    id_ = (logicview.idx(pid, 2) & 63)
    parity = (logicview.idx(pid, 2) >> 6)
    expected_parity = self:calc_parity(logicview.idx(pid, 2))
    parity_valid = logicview.eq(parity, expected_parity)
    if logicview.truth((not logicview.truth(parity_valid))) then
      self:put(logicview.idx(pid, 0), logicview.idx(pid, 1), self.out_ann, { 2, { logicview.pymod("P != %d", expected_parity) } })
    end
    ann_class = (function() if logicview.truth(parity_valid) then return 0 else return 3 end end)()
    self:put(logicview.idx(pid, 0), logicview.idx(pid, 1), self.out_ann, { ann_class, { logicview.pymod("ID: %02X Parity: %d (%s)", { id_, parity, (function() if logicview.truth(parity_valid) then return "ok" else return "bad" end end)() }), logicview.pymod("ID: 0x%02X", id_), logicview.pymod("I: %d", id_) } })
  end
  if logicview.truth(logicview.len(self.lin_rsp)) then
    checksum_valid = self:checksum_is_valid(logicview.idx(pid, 2), self.lin_rsp, logicview.idx(checksum, 2))
    for _lv_item in logicview.iter(self.lin_rsp) do
      b = _lv_item
      self:put(logicview.idx(b, 0), logicview.idx(b, 1), self.out_ann, { 0, { logicview.pymod("Data: 0x%02X", logicview.idx(b, 2)), logicview.pymod("D: 0x%02X", logicview.idx(b, 2)) } })
      ::continue_1::
    end
    ann_class = (function() if logicview.truth(checksum_valid) then return 0 else return 3 end end)()
    self:put(logicview.idx(checksum, 0), logicview.idx(checksum, 1), self.out_ann, { ann_class, { logicview.pymod("Checksum: 0x%02X", logicview.idx(checksum, 2)), "Checksum", "Chk", "C" } })
    if logicview.truth((not logicview.truth(checksum_valid))) then
      self:put(logicview.idx(checksum, 0), logicview.idx(checksum, 1), self.out_ann, { 2, { "Checksum invalid" } })
    end
  else
  end
  logicview.list_clear(self.lin_header)
  logicview.list_clear(self.lin_rsp)
end
function _decoder.handle_error(self, dummy)
  self:putx({ 3, { "Error", "Err", "E" } })
end
function _decoder.checksum_is_valid(self, pid, data, checksum)
  local id_, d, carry_bits
  if logicview.truth(logicview.eq(self.lin_version, 2)) then
    id_ = (pid & 63)
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(id_, 60))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(id_, 61))
  return _v
end)()) then
      checksum = logicview.add(checksum, pid)
    end
  end
  for _lv_item in logicview.iter(data) do
    d = _lv_item
    checksum = logicview.add(checksum, logicview.idx(d, 2))
    ::continue_2::
  end
  carry_bits = logicview.tointeger((checksum / 256))
  checksum = logicview.add(checksum, carry_bits)
  return logicview.eq((checksum & 255), 255)
end
function _decoder.calc_parity(pid)
  local id_, p0, p1
  id_ = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(8) do
    i = _lv_i
    _lv_out[#_lv_out + 1] = (((pid & 63) >> i) & 1)
  end
  return _lv_out
end)()
  p0 = (((logicview.idx(id_, 0) ~ logicview.idx(id_, 1)) ~ logicview.idx(id_, 2)) ~ logicview.idx(id_, 4))
  p1 = (not logicview.truth((((logicview.idx(id_, 1) ~ logicview.idx(id_, 3)) ~ logicview.idx(id_, 4)) ~ logicview.idx(id_, 5))))
  return ((p0 << 0) | (p1 << 1))
end
function _decoder.end_(self)
  if logicview.truth((function()
  local _v
  _v = self.done_break
  if not logicview.truth(_v) then return _v end
  _v = logicview.len(self.lin_rsp)
  return _v
end)()) then
    self:handle_checksum()
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata, handler
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
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss_block = _lv_a0
      self.es_block = _lv_a1
    end
    if logicview.truth(logicview.eq(ptype, "BREAK")) then
      self:handle_break(pdata)
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    pdata = logicview.idx(pdata, 0)
    handler = (function() local _v = self[logicview.pymod("handle_%s", _string.lower(self.fsm.state))]; if _v == nil then return nil end; return _v end)()
    handler(pdata)
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
