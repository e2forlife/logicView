-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Federico Cerutti <federico@ceres-c.it>

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
local bitpack_lsb, Pin, Ann, Bin, Decoder
local _decoder

bitpack_lsb = logicview.bitpack_lsb
Pin = {}
Pin.__index = Pin
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(3) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Pin.RST = logicview.idx(_lv_seq, 0)
  Pin.CLK = logicview.idx(_lv_seq, 1)
  Pin.IO = logicview.idx(_lv_seq, 2)
end
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(13) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.RESET_SYM = logicview.idx(_lv_seq, 0)
  Ann.INTR_SYM = logicview.idx(_lv_seq, 1)
  Ann.START_SYM = logicview.idx(_lv_seq, 2)
  Ann.STOP_SYM = logicview.idx(_lv_seq, 3)
  Ann.BIT_SYM = logicview.idx(_lv_seq, 4)
  Ann.ATR_BYTE = logicview.idx(_lv_seq, 5)
  Ann.CMD_BYTE = logicview.idx(_lv_seq, 6)
  Ann.OUT_BYTE = logicview.idx(_lv_seq, 7)
  Ann.PROC_BYTE = logicview.idx(_lv_seq, 8)
  Ann.ATR_DATA = logicview.idx(_lv_seq, 9)
  Ann.CMD_DATA = logicview.idx(_lv_seq, 10)
  Ann.OUT_DATA = logicview.idx(_lv_seq, 11)
  Ann.PROC_DATA = logicview.idx(_lv_seq, 12)
end
Bin = {}
Bin.__index = Bin
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(1) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Bin.BYTES = logicview.idx(_lv_seq, 0)
end
_decoder = {
  api_version = 3,
  id = "sle44xx",
  name = "SLE 44xx",
  longname = "SLE44xx memory card",
  desc = "SLE 4418/28/32/42 memory card serial protocol",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Memory" },
  channels = { logicview.dict({ id = "rst", name = "RST", desc = "Reset line" }), logicview.dict({ id = "clk", name = "CLK", desc = "Clock line" }), logicview.dict({ id = "io", name = "I/O", desc = "I/O data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "reset_sym", "Reset Symbol" }, { "intr_sym", "Interrupt Symbol" }, { "start_sym", "Start Symbol" }, { "stop_sym", "Stop Symbol" }, { "bit_sym", "Bit Symbol" }, { "atr_byte", "ATR Byte" }, { "cmd_byte", "Command Byte" }, { "out_byte", "Outgoing Byte" }, { "proc_byte", "Processing Byte" }, { "atr_data", "ATR data" }, { "cmd_data", "Command data" }, { "out_data", "Outgoing data" }, { "proc_data", "Processing data" } },
  annotation_rows = { { "symbols", "Symbols", { 0, 1, 2, 3, 4 } }, { "fields", "Fields", { 5, 6, 7, 8 } }, { "operations", "Operations", { 9, 10, 11, 12 } } },
  binary = { { "bytes", "Bytes" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.max_addr = 256
  self.bits = {  }
  self.atr_bytes = {  }
  self.cmd_bytes = {  }
  self.cmd_proc = nil
  self.out_len = nil
  self.out_bytes = {  }
  self.proc_state = nil
  self.state = nil
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.putx(self, ss, es, cls, data)
  self:put(ss, es, self.out_ann, { cls, data })
end
function _decoder.putb(self, ss, es, cls, data)
  self:put(ss, es, self.out_binary, { cls, data })
end
function _decoder.snums_to_usecs(self, snum_count)
  local snums_per_usec, usecs
  if logicview.truth((not logicview.truth(self.samplerate))) then
    return nil
  end
  snums_per_usec = (self.samplerate / 1000000.0)
  usecs = (snum_count / snums_per_usec)
  return usecs
end
function _decoder.lookup_proto_ann_txt(self, key, variables)
  local ann, cls, texts
  ann = logicview.dget(logicview.dict({ RESET_SYM = { Ann.RESET_SYM, "Reset", "R" }, INTR_SYM = { Ann.INTR_SYM, "Interrupt", "Intr", "I" }, START_SYM = { Ann.START_SYM, "Start", "ST", "S" }, STOP_SYM = { Ann.STOP_SYM, "Stop", "SP", "P" }, BIT_SYM = { Ann.BIT_SYM, "{bit}" }, ATR_BYTE = { Ann.ATR_BYTE, "Answer To Reset: {data:02x}", "ATR: {data:02x}", "{data:02x}" }, CMD_BYTE = { Ann.CMD_BYTE, "Command: {data:02x}", "Cmd: {data:02x}", "{data:02x}" }, OUT_BYTE = { Ann.OUT_BYTE, "Outgoing data: {data:02x}", "Data: {data:02x}", "{data:02x}" }, PROC_BYTE = { Ann.PROC_BYTE, "Internal processing: {data:02x}", "Proc: {data:02x}", "{data:02x}" }, ATR_DATA = { Ann.ATR_DATA, "Answer To Reset: {data}", "ATR: {data}", "{data}" }, CMD_DATA = { Ann.CMD_DATA, "Command: {data}", "Cmd: {data}", "{data}" }, OUT_DATA = { Ann.OUT_DATA, "Outgoing: {data}", "Out: {data}", "{data}" }, PROC_DATA = { Ann.PROC_DATA, "Processing: {data}", "Proc: {data}", "{data}" } }), key, nil)
  if logicview.truth((ann == nil)) then
    return { nil, {  } }
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(ann, 0), logicview.slice(ann, 1, nil, nil)
    cls = _lv_a0
    texts = _lv_a1
  end
  texts = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(texts) do
    t = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat(t, {  }, variables)
  end
  return _lv_out
end)()
  return { cls, texts }
end
function _decoder.text_for_accu_bytes(self, accu)
  local ss, es, data, text
  if logicview.truth((not logicview.truth(accu))) then
    return { nil, nil, nil, nil }
  end
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(accu, 0), 1), logicview.idx(logicview.idx(accu, (-1)), 2)
    ss = _lv_a0
    es = _lv_a1
  end
  data = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(accu) do
    a = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(a, 0)
  end
  return _lv_out
end)()
  text = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(data) do
    a = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { a }, logicview.dict({}))
  end
  return _lv_out
end)())
  return { ss, es, data, text }
end
function _decoder.flush_queued(self)
  local key, ss, es, _, text, cls, texts, clk, high, usecs, msecs
  if logicview.truth(self.atr_bytes) then
    key = "ATR_DATA"
    do
      local _lv_seq = self:text_for_accu_bytes(self.atr_bytes)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
      text = logicview.idx(_lv_seq, 3)
    end
    do
      local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({ data = text }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cls = logicview.idx(_lv_seq, 0)
      texts = logicview.idx(_lv_seq, 1)
    end
    self:putx(ss, es, cls, texts)
  end
  if logicview.truth(self.cmd_bytes) then
    key = "CMD_DATA"
    do
      local _lv_seq = self:text_for_accu_bytes(self.cmd_bytes)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
      text = logicview.idx(_lv_seq, 3)
    end
    do
      local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({ data = text }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cls = logicview.idx(_lv_seq, 0)
      texts = logicview.idx(_lv_seq, 1)
    end
    self:putx(ss, es, cls, texts)
  end
  if logicview.truth(self.out_bytes) then
    key = "OUT_DATA"
    do
      local _lv_seq = self:text_for_accu_bytes(self.out_bytes)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
      text = logicview.idx(_lv_seq, 3)
    end
    do
      local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({ data = text }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cls = logicview.idx(_lv_seq, 0)
      texts = logicview.idx(_lv_seq, 1)
    end
    self:putx(ss, es, cls, texts)
  end
  if logicview.truth(self.proc_state) then
    key = "PROC_DATA"
    ss = logicview.idx(self.proc_state, "ss")
    es = logicview.idx(self.proc_state, "es")
    clk = logicview.idx(self.proc_state, "clk")
    high = logicview.idx(self.proc_state, "io1")
    text = logicview.pyformat("{clk} clocks, I/O {high}", {  }, logicview.dict({ clk = clk, high = logicview.tointeger(high) }))
    usecs = self:snums_to_usecs((es - ss))
    if logicview.truth(usecs) then
      msecs = (usecs / 1000)
      text = logicview.pyformat("{msecs:.2f} ms, {text}", {  }, logicview.dict({ msecs = msecs, text = text }))
    end
    do
      local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({ data = text }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cls = logicview.idx(_lv_seq, 0)
      texts = logicview.idx(_lv_seq, 1)
    end
    self:putx(ss, es, cls, texts)
  end
  self.atr_bytes = nil
  self.cmd_bytes = nil
  self.cmd_proc = nil
  self.out_len = nil
  self.out_bytes = nil
  self.proc_state = nil
  self.state = nil
end
function _decoder.handle_reset(self, ss, es, has_clk)
  local key, cls, texts
  self:flush_queued()
  key = logicview.pyformat("{}_SYM", { (function() if logicview.truth(has_clk) then return "RESET" else return "INTR" end end)() }, logicview.dict({}))
  do
    local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({  }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    cls = logicview.idx(_lv_seq, 0)
    texts = logicview.idx(_lv_seq, 1)
  end
  self:putx(ss, es, cls, texts)
  self.bits = {  }
  self.state = (function() if logicview.truth(has_clk) then return "ATR" else return nil end end)()
end
function _decoder.handle_command(self, ss, is_start)
  local key, cls, texts
  if logicview.truth(is_start) then
    self:flush_queued()
  end
  key = logicview.pyformat("{}_SYM", { (function() if logicview.truth(is_start) then return "START" else return "STOP" end end)() }, logicview.dict({}))
  do
    local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({  }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    cls = logicview.idx(_lv_seq, 0)
    texts = logicview.idx(_lv_seq, 1)
  end
  self:putx(ss, ss, cls, texts)
  self.bits = {  }
  self.state = (function() if logicview.truth(is_start) then return "CMD" else return "DATA" end end)()
end
function _decoder.command_check(self, ctrl, addr, data)
  local codes_table, code, dflt_fmt, fmt, texts, length, is_proc
  codes_table = logicview.dict({ [48] = logicview.dict({ fmt = { "read main memory, addr {addr:02x}", "RD-M @{addr:02x}" }, len = (function(ctrl, addr, data) return (self.max_addr - addr) end) }), [49] = logicview.dict({ fmt = { "read security memory", "RD-S" }, len = 4 }), [51] = logicview.dict({ fmt = { "compare verification data, addr {addr:02x}, data {data:02x}", "CMP-V @{addr:02x} ={data:02x}" }, proc = true }), [52] = logicview.dict({ fmt = { "read protection memory, addr {addr:02x}", "RD-P @{addr:02x}" }, len = 4 }), [56] = logicview.dict({ fmt = { "update main memory, addr {addr:02x}, data {data:02x}", "WR-M @{addr:02x} ={data:02x}" }, proc = true }), [57] = logicview.dict({ fmt = { "update security memory, addr {addr:02x}, data {data:02x}", "WR-S @{addr:02x} ={data:02x}" }, proc = true }), [60] = logicview.dict({ fmt = { "write protection memory, addr {addr:02x}, data {data:02x}", "WR-P @{addr:02x} ={data:02x}" }, proc = true }) })
  code = logicview.dget(codes_table, ctrl, logicview.dict({  }))
  dflt_fmt = { "unknown, ctrl {ctrl:02x}, addr {addr:02x}, data {data:02x}", "UNK-{ctrl:02x} @{addr:02x}, ={data:02x}" }
  fmt = logicview.dget(code, "fmt", dflt_fmt)
  if logicview.truth((not logicview.truth(logicview.is_a(fmt, { "list", "tuple" })))) then
    fmt = { fmt }
  end
  texts = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(fmt) do
    f = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat(f, {  }, logicview.dict({ ctrl = ctrl, addr = addr, data = data }))
  end
  return _lv_out
end)()
  length = logicview.dget(code, "len", nil)
  if logicview.truth((_type(length) == 'function')) then
    length = length(ctrl, addr, data)
  end
  is_proc = logicview.dget(code, "proc", false)
  return { texts, length, is_proc }
end
function _decoder.processing_start(self, ss, es, io_high)
  self.proc_state = logicview.dict({ ss = (function()
  local _v
  _v = ss
  if logicview.truth(_v) then return _v end
  _v = es
  return _v
end)(), es = (function()
  local _v
  _v = es
  if logicview.truth(_v) then return _v end
  _v = ss
  return _v
end)(), clk = 0, io1 = logicview.truth(io_high) })
end
function _decoder.processing_update(self, es, clk_inc, io_high)
  if logicview.truth((function()
  local _v
  _v = (es ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (es > logicview.idx(self.proc_state, "es"))
  return _v
end)()) then
    logicview.setidx(self.proc_state, "es", es)
  end
  logicview.setidx(self.proc_state, "clk", logicview.add(logicview.idx(self.proc_state, "clk"), clk_inc))
  if logicview.truth(io_high) then
    logicview.setidx(self.proc_state, "io1", true)
  end
end
function _decoder.handle_data_byte(self, ss, es, data, bits)
  local ctrl, addr, texts, length, proc, cls
  if logicview.truth(logicview.eq(self.state, "ATR")) then
    if logicview.truth((not logicview.truth(self.atr_bytes))) then
      self.atr_bytes = {  }
    end
    _table.insert(self.atr_bytes, { data, ss, es, bits })
    if logicview.truth(logicview.eq(logicview.len(self.atr_bytes), 4)) then
      self:flush_queued()
    end
    return
  end
  if logicview.truth(logicview.eq(self.state, "CMD")) then
    if logicview.truth((not logicview.truth(self.cmd_bytes))) then
      self.cmd_bytes = {  }
    end
    _table.insert(self.cmd_bytes, { data, ss, es, bits })
    if logicview.truth(logicview.eq(logicview.len(self.cmd_bytes), 3)) then
      do
        local _lv_seq = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.cmd_bytes) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(c, 0)
  end
  return _lv_out
end)()
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        ctrl = logicview.idx(_lv_seq, 0)
        addr = logicview.idx(_lv_seq, 1)
        data = logicview.idx(_lv_seq, 2)
      end
      do
        local _lv_seq = self:command_check(ctrl, addr, data)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        texts = logicview.idx(_lv_seq, 0)
        length = logicview.idx(_lv_seq, 1)
        proc = logicview.idx(_lv_seq, 2)
      end
      do
        local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.cmd_bytes, 0), 1), logicview.idx(logicview.idx(self.cmd_bytes, (-1)), 2)
        ss = _lv_a0
        es = _lv_a1
      end
      cls = Ann.CMD_DATA
      self:putx(ss, es, cls, texts)
      self.cmd_bytes = {  }
      self.out_len = length
      self.cmd_proc = logicview.truth(proc)
      self.state = nil
    end
    return
  end
  if logicview.truth(logicview.eq(self.state, "OUT")) then
    if logicview.truth((not logicview.truth(self.out_bytes))) then
      self.out_bytes = {  }
    end
    _table.insert(self.out_bytes, { data, ss, es, bits })
    if logicview.truth((function()
  local _v
  _v = (self.out_len ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.out_bytes), self.out_len)
  return _v
end)()) then
      self:flush_queued()
    end
    return
  end
end
function _decoder.handle_data_bit(self, ss, es, bit)
  local high, cls, texts, bits, data, key
  if logicview.truth(logicview.eq(self.state, "DATA")) then
    if logicview.truth(self.out_len) then
      self.state = "OUT"
    elseif logicview.truth(self.cmd_proc) then
      self.state = "PROC"
      self:processing_start((function()
  local _v
  _v = ss
  if logicview.truth(_v) then return _v end
  _v = es
  return _v
end)(), (function()
  local _v
  _v = es
  if logicview.truth(_v) then return _v end
  _v = ss
  return _v
end)(), logicview.eq(bit, 1))
    else
      self.state = "OUT"
    end
  end
  if logicview.truth(logicview.eq(self.state, "PROC")) then
    high = logicview.eq(bit, 1)
    if logicview.truth((ss ~= nil)) then
      self:processing_update(ss, 0, high)
    end
    if logicview.truth((es ~= nil)) then
      self:processing_update(es, 1, high)
    end
    if logicview.truth(high) then
      self:flush_queued()
    end
    return
  end
  if logicview.truth((ss ~= nil)) then
    _table.insert(self.bits, { bit, ss, (function()
  local _v
  _v = es
  if logicview.truth(_v) then return _v end
  _v = ss
  return _v
end)() })
    return
  end
  if logicview.truth((es == nil)) then
    self.bits = {  }
    return
  end
  if logicview.truth((not logicview.truth(self.bits))) then
    return
  end
  if logicview.truth((bit ~= nil)) then
    logicview.setidx(logicview.idx(self.bits, (-1)), 0, bit)
  end
  logicview.setidx(logicview.idx(self.bits, (-1)), 2, es)
  do
    local _lv_seq = logicview.idx(self.bits, (-1))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    bit = logicview.idx(_lv_seq, 0)
    ss = logicview.idx(_lv_seq, 1)
    es = logicview.idx(_lv_seq, 2)
  end
  do
    local _lv_seq = self:lookup_proto_ann_txt("BIT_SYM", logicview.dict({ bit = bit }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    cls = logicview.idx(_lv_seq, 0)
    texts = logicview.idx(_lv_seq, 1)
  end
  self:putx(ss, es, cls, texts)
  if logicview.truth((logicview.len(self.bits) < 8)) then
    return
  end
  bits = self.bits
  self.bits = {  }
  data = bitpack_lsb(bits, 0)
  ss = logicview.idx(logicview.idx(bits, 0), 1)
  es = logicview.idx(logicview.idx(bits, (-1)), 2)
  key = logicview.pyformat("{}_BYTE", { self.state }, logicview.dict({}))
  do
    local _lv_seq = self:lookup_proto_ann_txt(key, logicview.dict({ data = data }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    cls = logicview.idx(_lv_seq, 0)
    texts = logicview.idx(_lv_seq, 1)
  end
  if logicview.truth(cls) then
    self:putx(ss, es, cls, texts)
  end
  self:putb(ss, es, Bin.BYTES, logicview.bytes({ data }))
  self:handle_data_byte(ss, es, data, bits)
end
function _decoder.check_bit(self, d)
  local v
  v = (self.matched & (1 << d))
  return logicview.eq((v >> d), 1)
end
function _decoder.decode(self)
  local COND_RESET_START, COND_RESET_STOP, COND_RSTCLK_START, COND_RSTCLK_STOP, COND_DATA_START, COND_DATA_STOP, COND_CMD_START, COND_CMD_STOP, COND_PROC_IOH, conditions, ss_reset, es_reset, ss_clk, es_clk, is_outgoing, is_processing, rst, clk, io
  do
    local _lv_seq = (function() local _t = {}; for _v in logicview.range(9) do _t[#_t + 1] = _v end; return _t end)()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    COND_RESET_START = logicview.idx(_lv_seq, 0)
    COND_RESET_STOP = logicview.idx(_lv_seq, 1)
    COND_RSTCLK_START = logicview.idx(_lv_seq, 2)
    COND_RSTCLK_STOP = logicview.idx(_lv_seq, 3)
    COND_DATA_START = logicview.idx(_lv_seq, 4)
    COND_DATA_STOP = logicview.idx(_lv_seq, 5)
    COND_CMD_START = logicview.idx(_lv_seq, 6)
    COND_CMD_STOP = logicview.idx(_lv_seq, 7)
    COND_PROC_IOH = logicview.idx(_lv_seq, 8)
  end
  conditions = { logicview.dict({ [Pin.RST] = "r" }), logicview.dict({ [Pin.RST] = "f" }), logicview.dict({ [Pin.RST] = "h", [Pin.CLK] = "r" }), logicview.dict({ [Pin.RST] = "h", [Pin.CLK] = "f" }), logicview.dict({ [Pin.RST] = "l", [Pin.CLK] = "r" }), logicview.dict({ [Pin.RST] = "l", [Pin.CLK] = "f" }), logicview.dict({ [Pin.CLK] = "h", [Pin.IO] = "f" }), logicview.dict({ [Pin.CLK] = "h", [Pin.IO] = "r" }), logicview.dict({ [Pin.RST] = "l", [Pin.IO] = "r" }) }
  do
    local _lv_chain = nil
    ss_reset = _lv_chain
    es_reset = _lv_chain
    ss_clk = _lv_chain
    es_clk = _lv_chain
  end
  while true do
    is_outgoing = logicview.eq(self.state, "OUT")
    is_processing = logicview.eq(self.state, "PROC")
    do
      local _lv_seq = self:wait(conditions)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      rst = logicview.idx(_lv_seq, 0)
      clk = logicview.idx(_lv_seq, 1)
      io = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(self:check_bit(COND_RESET_START)) then
      self:flush_queued()
      ss_reset = self.samplenum
      do
        local _lv_chain = nil
        es_reset = _lv_chain
        ss_clk = _lv_chain
        es_clk = _lv_chain
      end
      goto continue_1
    end
    if logicview.truth(self:check_bit(COND_RESET_STOP)) then
      es_reset = self.samplenum
      self:handle_reset((function()
  local _v
  _v = ss_reset
  if logicview.truth(_v) then return _v end
  _v = 0
  return _v
end)(), es_reset, (function()
  local _v
  _v = ss_clk
  if not logicview.truth(_v) then return _v end
  _v = es_clk
  return _v
end)())
      do
        local _lv_chain = nil
        ss_reset = _lv_chain
        es_reset = _lv_chain
        ss_clk = _lv_chain
        es_clk = _lv_chain
      end
      goto continue_1
    end
    if logicview.truth(self:check_bit(COND_RSTCLK_START)) then
      ss_clk = self.samplenum
      es_clk = nil
      goto continue_1
    end
    if logicview.truth(self:check_bit(COND_RSTCLK_STOP)) then
      es_clk = self.samplenum
      goto continue_1
    end
    if logicview.truth(self:check_bit(COND_DATA_START)) then
      self:handle_data_bit(self.samplenum, nil, io)
      goto continue_1
    end
    if logicview.truth(self:check_bit(COND_DATA_STOP)) then
      self:handle_data_bit(nil, self.samplenum, nil)
      goto continue_1
    end
    if logicview.truth((function()
  local _v
  _v = is_processing
  if not logicview.truth(_v) then return _v end
  _v = self:check_bit(COND_PROC_IOH)
  return _v
end)()) then
      self:handle_data_bit(self.samplenum, self.samplenum, io)
      goto continue_1
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.truth(is_outgoing))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_processing))
  return _v
end)()) then
      if logicview.truth(self:check_bit(COND_CMD_START)) then
        self:handle_command(self.samplenum, true)
        goto continue_1
      end
      if logicview.truth(self:check_bit(COND_CMD_STOP)) then
        self:handle_command(self.samplenum, false)
        goto continue_1
      end
    end
    ::continue_1::
  end
end

return _decoder
