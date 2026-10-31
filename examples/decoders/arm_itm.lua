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
local string, subprocess, re, ARM_EXCEPTIONS, Decoder
local _decoder

string = logicview.dict({ hexdigits = '0123456789abcdefABCDEF', digits = '0123456789', ascii_lowercase = 'abcdefghijklmnopqrstuvwxyz', ascii_uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ascii_letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', whitespace = ' \t\n\r\v\f' })
subprocess = { CalledProcessError = 'CalledProcessError', check_output = function() _error({ _exc = 'CalledProcessError', args = { 'disassembler is not available' } }, 0) end, check_call = function() _error('external programs are not available') end }
re = logicview.re
ARM_EXCEPTIONS = logicview.dict({ [0] = "Thread", [1] = "Reset", [2] = "NMI", [3] = "HardFault", [4] = "MemManage", [5] = "BusFault", [6] = "UsageFault", [11] = "SVCall", [12] = "Debug Monitor", [14] = "PendSV", [15] = "SysTick" })
_decoder = {
  api_version = 3,
  id = "arm_itm",
  name = "ARM ITM",
  longname = "ARM Instrumentation Trace Macroblock",
  desc = "ARM Cortex-M / ARMv7m ITM trace protocol.",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "objdump", desc = "objdump path", default = "arm-none-eabi-objdump", values = {  } }), logicview.dict({ id = "objdump_opts", desc = "objdump options", default = "-lSC", values = {  } }), logicview.dict({ id = "elffile", desc = ".elf path", default = "", values = {  } }) },
  annotations = { { "trace", "Trace information" }, { "timestamp", "Timestamp" }, { "software", "Software message" }, { "dwt_event", "DWT event" }, { "dwt_watchpoint", "DWT watchpoint" }, { "dwt_exc", "Exception trace" }, { "dwt_pc", "Program counter" }, { "mode_thread", "Current mode: thread" }, { "mode_irq", "Current mode: IRQ" }, { "mode_exc", "Current mode: Exception" }, { "location", "Current location" }, { "function", "Current function" } },
  annotation_rows = { { "trace", "Trace information", { 0, 1 } }, { "software", "Software trace", { 2 } }, { "dwt_event", "DWT event", { 3 } }, { "dwt_watchpoint", "DWT watchpoint", { 4 } }, { "dwt_exc", "Exception trace", { 5 } }, { "dwt_pc", "Program counter", { 6 } }, { "mode", "Current mode", { 7, 8, 9 } }, { "location", "Current location", { 10 } }, { "function", "Current function", { 11 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.buf = {  }
  self.syncbuf = {  }
  self.swpackets = logicview.dict({  })
  self.prevsample = 0
  self.dwt_timestamp = 0
  self.current_mode = nil
  self.file_lookup = logicview.dict({  })
  self.func_lookup = logicview.dict({  })
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self:load_objdump()
end
function _decoder.load_objdump(self)
  local opts, disasm, instpat, filepat, funcpat, prev_file, prev_func, line, m, addr
  if logicview.truth((not logicview.truth((function()
  local _v
  _v = logicview.idx(self.options, "objdump")
  if not logicview.truth(_v) then return _v end
  _v = logicview.idx(self.options, "elffile")
  return _v
end)()))) then
    return
  end
  opts = { logicview.idx(self.options, "objdump") }
  opts = logicview.add(opts, logicview.split(logicview.idx(self.options, "objdump_opts"), nil, nil))
  opts = logicview.add(opts, { logicview.idx(self.options, "elffile") })
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      disasm = subprocess.check_output(opts)
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "CalledProcessError") then
        return
      else
        _error(_err, 0)
      end
    end
  end
  disasm = disasm
  instpat = re.compile("\\s*([0-9a-fA-F]+):\t+([0-9a-fA-F ]+)\t+([a-zA-Z][^;]+)\\s*;?.*")
  filepat = re.compile("[^\\s]+[/\\\\]([a-zA-Z0-9._-]+:[0-9]+)(?:\\s.*)?")
  funcpat = re.compile("[0-9a-fA-F]+\\s*<([^>]+)>:.*")
  prev_file = ""
  prev_func = ""
  for _lv_item in logicview.iter(logicview.split(disasm, "\n", nil)) do
    line = _lv_item
    m = instpat:match(line)
    if logicview.truth(m) then
      addr = logicview.tointeger(m:group(1), 16)
      logicview.setidx(self.file_lookup, addr, prev_file)
      logicview.setidx(self.func_lookup, addr, prev_func)
    else
      m = funcpat:match(line)
      if logicview.truth(m) then
        prev_func = m:group(1)
      else
        m = filepat:match(line)
        if logicview.truth(m) then
          prev_file = m:group(1)
        end
      end
    end
    ::continue_1::
  end
end
function _decoder.get_packet_type(self, byte)
  if logicview.truth(logicview.eq((byte & 127), 0)) then
    return "sync"
  elseif logicview.truth(logicview.eq(byte, 112)) then
    return "overflow"
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq((byte & 15), 0)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq((byte & 240), 0))
  return _v
end)()) then
    return "timestamp"
  elseif logicview.truth(logicview.eq((byte & 15), 8)) then
    return "sw_extension"
  elseif logicview.truth(logicview.eq((byte & 15), 12)) then
    return "hw_extension"
  elseif logicview.truth(logicview.eq((byte & 15), 4)) then
    return "reserved"
  elseif logicview.truth(logicview.eq((byte & 4), 0)) then
    return "software"
  else
    return "hardware"
  end
end
function _decoder.mode_change(self, new_mode)
  local start, mode, ann_idx
  if logicview.truth((self.current_mode ~= nil)) then
    do
      local _lv_seq = self.current_mode
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      start = logicview.idx(_lv_seq, 0)
      mode = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.startswith(mode, "Thread")) then
      ann_idx = 7
    elseif logicview.truth(logicview.startswith(mode, "IRQ")) then
      ann_idx = 8
    else
      ann_idx = 9
    end
    self:put(start, self.startsample, self.out_ann, { ann_idx, { mode } })
  end
  if logicview.truth((new_mode == nil)) then
    self.current_mode = nil
  else
    self.current_mode = { self.startsample, new_mode }
  end
end
function _decoder.location_change(self, pc)
  local new_loc, new_func, ss, es
  new_loc = logicview.dget(self.file_lookup, pc, nil)
  new_func = logicview.dget(self.func_lookup, pc, nil)
  ss = self.startsample
  es = self.prevsample
  if logicview.truth((new_loc ~= nil)) then
    self:put(ss, es, self.out_ann, { 10, { new_loc } })
  end
  if logicview.truth((new_func ~= nil)) then
    self:put(ss, es, self.out_ann, { 11, { new_func } })
  end
end
function _decoder.fallback(self, buf)
  local ptype
  ptype = self:get_packet_type(logicview.idx(buf, 0))
  return { 0, { logicview.add(logicview.pymod("Unhandled %s: ", ptype), logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(buf) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02x", b)
  end
  return _lv_out
end)())) } }
end
function _decoder.handle_overflow(self, buf)
  return { 0, { "Overflow" } }
end
function _decoder.handle_hardware(self, buf)
  local plen, pid, text, excnum, event, excstr, pc, comp, what, data, addr, offset
  plen = logicview.idx({ 0, 1, 2, 4 }, (logicview.idx(buf, 0) & 3))
  pid = (logicview.idx(buf, 0) >> 3)
  if logicview.truth((not logicview.eq(logicview.len(buf), logicview.add(plen, 1)))) then
    return nil
  end
  if logicview.truth(logicview.eq(pid, 0)) then
    text = "DWT events:"
    if logicview.truth((logicview.idx(buf, 1) & 32)) then
      text = logicview.add(text, " Cyc")
    end
    if logicview.truth((logicview.idx(buf, 1) & 16)) then
      text = logicview.add(text, " Fold")
    end
    if logicview.truth((logicview.idx(buf, 1) & 8)) then
      text = logicview.add(text, " LSU")
    end
    if logicview.truth((logicview.idx(buf, 1) & 4)) then
      text = logicview.add(text, " Sleep")
    end
    if logicview.truth((logicview.idx(buf, 1) & 2)) then
      text = logicview.add(text, " Exc")
    end
    if logicview.truth((logicview.idx(buf, 1) & 1)) then
      text = logicview.add(text, " CPI")
    end
    return { 3, { text } }
  elseif logicview.truth(logicview.eq(pid, 1)) then
    excnum = (((logicview.idx(buf, 2) & 1) << 8) | logicview.idx(buf, 1))
    event = (logicview.idx(buf, 2) >> 4)
    excstr = logicview.dget(ARM_EXCEPTIONS, excnum, logicview.pymod("IRQ %d", (excnum - 16)))
    if logicview.truth(logicview.eq(event, 1)) then
      self:mode_change(excstr)
      return { 5, { logicview.add("Enter: ", excstr), logicview.add("E ", excstr) } }
    elseif logicview.truth(logicview.eq(event, 2)) then
      self:mode_change(nil)
      return { 5, { logicview.add("Exit: ", excstr), logicview.add("X ", excstr) } }
    elseif logicview.truth(logicview.eq(event, 3)) then
      self:mode_change(excstr)
      return { 5, { logicview.add("Resume: ", excstr), logicview.add("R ", excstr) } }
    end
  elseif logicview.truth(logicview.eq(pid, 2)) then
    pc = (((logicview.idx(buf, 1) | (logicview.idx(buf, 2) << 8)) | (logicview.idx(buf, 3) << 16)) | (logicview.idx(buf, 4) << 24))
    self:location_change(pc)
    return { 6, { logicview.pymod("PC: 0x%08x", pc) } }
  elseif logicview.truth(logicview.eq((logicview.idx(buf, 0) & 196), 132)) then
    comp = ((logicview.idx(buf, 0) & 48) >> 4)
    what = (function() if logicview.truth(logicview.eq((logicview.idx(buf, 0) & 8), 0)) then return "Read" else return "Write" end end)()
    if logicview.truth(logicview.eq(plen, 1)) then
      data = logicview.pymod("0x%02x", logicview.idx(buf, 1))
    elseif logicview.truth(logicview.eq(plen, 2)) then
      data = logicview.pymod("0x%04x", (logicview.idx(buf, 1) | (logicview.idx(buf, 2) << 8)))
    else
      data = logicview.pymod("0x%08x", (((logicview.idx(buf, 1) | (logicview.idx(buf, 2) << 8)) | (logicview.idx(buf, 3) << 16)) | (logicview.idx(buf, 4) << 24)))
    end
    return { 4, { logicview.pymod("Watchpoint %d: %s data %s", { comp, what, data }), logicview.pymod("WP%d: %s %s", { comp, logicview.idx(what, 0), data }) } }
  elseif logicview.truth(logicview.eq((logicview.idx(buf, 0) & 207), 71)) then
    comp = ((logicview.idx(buf, 0) & 48) >> 4)
    addr = (((logicview.idx(buf, 1) | (logicview.idx(buf, 2) << 8)) | (logicview.idx(buf, 3) << 16)) | (logicview.idx(buf, 4) << 24))
    self:location_change(addr)
    return { 4, { logicview.pymod("Watchpoint %d: PC 0x%08x", { comp, addr }), logicview.pymod("WP%d: PC 0x%08x", { comp, addr }) } }
  elseif logicview.truth(logicview.eq((logicview.idx(buf, 0) & 207), 78)) then
    comp = ((logicview.idx(buf, 0) & 48) >> 4)
    offset = (logicview.idx(buf, 1) | (logicview.idx(buf, 2) << 8))
    return { 4, { logicview.pymod("Watchpoint %d: address 0x????%04x", { comp, offset }), logicview.pymod("WP%d: A 0x%04x", { comp, offset }) } }
  end
  return self:fallback(buf)
end
function _decoder.handle_software(self, buf)
  local plen, pid
  plen = logicview.idx({ 0, 1, 2, 4 }, (logicview.idx(buf, 0) & 3))
  pid = (logicview.idx(buf, 0) >> 3)
  if logicview.truth((not logicview.eq(logicview.len(buf), logicview.add(plen, 1)))) then
    return nil
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(plen, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains(string.printable, _string.char(logicview.idx(buf, 1)))
  return _v
end)()) then
    self:add_delayed_sw(pid, _string.char(logicview.idx(buf, 1)))
    return {  }
  end
  self:push_delayed_sw()
  if logicview.truth(logicview.eq(plen, 1)) then
    return { 2, { logicview.pymod("%d: 0x%02x", { pid, logicview.idx(buf, 1) }) } }
  elseif logicview.truth(logicview.eq(plen, 2)) then
    return { 2, { logicview.pymod("%d: 0x%02x%02x", { pid, logicview.idx(buf, 2), logicview.idx(buf, 1) }) } }
  elseif logicview.truth(logicview.eq(plen, 4)) then
    return { 2, { logicview.pymod("%d: 0x%02x%02x%02x%02x", { pid, logicview.idx(buf, 4), logicview.idx(buf, 3), logicview.idx(buf, 2), logicview.idx(buf, 1) }) } }
  end
end
function _decoder.handle_timestamp(self, buf)
  local tc, ts, msg
  if logicview.truth((not logicview.eq((logicview.idx(buf, (-1)) & 128), 0))) then
    return nil
  end
  if logicview.truth(logicview.eq((logicview.idx(buf, 0) & 128), 0)) then
    tc = 0
    ts = (logicview.idx(buf, 0) >> 4)
  else
    tc = ((logicview.idx(buf, 0) & 48) >> 4)
    ts = (logicview.idx(buf, 1) & 127)
    if logicview.truth((logicview.len(buf) > 2)) then
      ts = (ts | ((logicview.idx(buf, 2) & 127) << 7))
    end
    if logicview.truth((logicview.len(buf) > 3)) then
      ts = (ts | ((logicview.idx(buf, 3) & 127) << 14))
    end
    if logicview.truth((logicview.len(buf) > 4)) then
      ts = (ts | ((logicview.idx(buf, 4) & 127) << 21))
    end
  end
  self.dwt_timestamp = logicview.add(self.dwt_timestamp, ts)
  if logicview.truth(logicview.eq(tc, 0)) then
    msg = "(exact)"
  elseif logicview.truth(logicview.eq(tc, 1)) then
    msg = "(timestamp delayed)"
  elseif logicview.truth(logicview.eq(tc, 2)) then
    msg = "(event delayed)"
  elseif logicview.truth(logicview.eq(tc, 3)) then
    msg = "(event and timestamp delayed)"
  end
  return { 1, { logicview.pymod("Timestamp: %d %s", { self.dwt_timestamp, msg }) } }
end
function _decoder.add_delayed_sw(self, pid, c)
  if logicview.truth((logicview.dget(self.swpackets, pid, nil) ~= nil)) then
    logicview.setidx(logicview.idx(self.swpackets, pid), 1, self.prevsample)
    logicview.setidx(logicview.idx(self.swpackets, pid), 2, logicview.add(logicview.idx(logicview.idx(self.swpackets, pid), 2), c))
  else
    logicview.setidx(self.swpackets, pid, { self.startsample, self.prevsample, c })
  end
end
function _decoder.push_delayed_sw(self)
  local pid, packet, ss, prevtime, text
  for _lv_k, _lv_v in _pairs(self.swpackets) do
    pid = _lv_k
    packet = _lv_v
    if logicview.truth((packet == nil)) then
      goto continue_2
    end
    do
      local _lv_seq = packet
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      prevtime = logicview.idx(_lv_seq, 1)
      text = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(((self.prevsample - prevtime) > logicview.mul(16, self.byte_len))) then
      self:put(ss, prevtime, self.out_ann, { 2, { logicview.pymod("%d: \"%s\"", { pid, text }) } })
      logicview.setidx(self.swpackets, pid, nil)
    end
    ::continue_2::
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata, func
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
    if logicview.truth(((ss - self.prevsample) > logicview.mul(16, self.byte_len))) then
      self:push_delayed_sw()
      self.buf = {  }
    end
    self.prevsample = es
    _table.insert(self.buf, logicview.idx(pdata, 0))
    if logicview.truth(logicview.eq(logicview.len(self.buf), 1)) then
      self.startsample = ss
    end
    self.syncbuf = logicview.add(logicview.slice(self.syncbuf, (-5), nil, nil), { logicview.idx(pdata, 0) })
    if logicview.truth(logicview.eq(self.syncbuf, { 0, 0, 0, 0, 0, 128 })) then
      self.buf = self.syncbuf
    end
    ptype = self:get_packet_type(logicview.idx(self.buf, 0))
    if logicview.truth((self[logicview.add("handle_", ptype)] ~= nil)) then
      func = (function() local _v = self[logicview.add("handle_", ptype)]; if _v == nil then return nil end; return _v end)()
      data = func(self.buf)
    else
      data = self:fallback(self.buf)
    end
    if logicview.truth((data ~= nil)) then
      if logicview.truth(data) then
        self:put(self.startsample, es, self.out_ann, data)
      end
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
