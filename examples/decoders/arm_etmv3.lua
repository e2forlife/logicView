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
local subprocess, re, exc_names, i, parse_varint, parse_uint, parse_exc_info, parse_branch_addr, Decoder
local _decoder

subprocess = { CalledProcessError = 'CalledProcessError', check_output = function() _error({ _exc = 'CalledProcessError', args = { 'disassembler is not available' } }, 0) end, check_call = function() _error('external programs are not available') end }
re = logicview.re
exc_names = { "No exception", "IRQ1", "IRQ2", "IRQ3", "IRQ4", "IRQ5", "IRQ6", "IRQ7", "IRQ0", "UsageFault", "NMI", "SVC", "DebugMon", "MemManage", "PendSV", "SysTick", "Reserved", "Reset", "BusFault", "Reserved", "Reserved" }
for _lv_i in logicview.range(8, 496) do
  i = _lv_i
  _table.insert(exc_names, logicview.pymod("IRQ%d", i))
  ::continue_1::
end
parse_varint = function(bytes_)
  local v, i, b
  v = 0
  for _lv_i, _lv_v in logicview.enumerate(bytes_) do
    i = _lv_i
    b = _lv_v
    v = (v | ((b & 127) << logicview.mul(i, 7)))
    if logicview.truth(logicview.eq((b & 128), 0)) then
      return { v, logicview.add(i, 1) }
    end
    ::continue_2::
  end
  return { v, logicview.len(bytes_) }
end
parse_uint = function(bytes_)
  local v, i, b
  v = 0
  for _lv_i, _lv_v in logicview.enumerate(bytes_) do
    i = _lv_i
    b = _lv_v
    v = (v | (b << logicview.mul(i, 8)))
    ::continue_3::
  end
  return v
end
parse_exc_info = function(bytes_)
  local excv, exclen, ns, exc, cancel, altisa, hyp, resume
  if logicview.truth((logicview.len(bytes_) < 1)) then
    return nil
  end
  do
    local _lv_seq = parse_varint(bytes_)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    excv = logicview.idx(_lv_seq, 0)
    exclen = logicview.idx(_lv_seq, 1)
  end
  if logicview.truth((not logicview.eq((logicview.idx(bytes_, (exclen - 1)) & 128), 0))) then
    return nil
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(exclen, 2)
  if not logicview.truth(_v) then return _v end
  _v = (excv & (1 << 13))
  return _v
end)()) then
    excv = ((excv & 127) | ((excv & 16256) << 7))
  end
  ns = (excv & 1)
  exc = (((excv >> 1) & 15) | ((excv >> 7) & 496))
  cancel = ((excv >> 5) & 1)
  altisa = ((excv >> 6) & 1)
  hyp = ((excv >> 12) & 1)
  resume = ((excv >> 14) & 15)
  return { ns, exc, cancel, altisa, hyp, resume }
end
parse_branch_addr = function(bytes_, ref_addr, cpu_state, branch_enc)
  local addr, addrlen, addr_bits, have_exc_info, exc_info
  do
    local _lv_seq = parse_varint(bytes_)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    addr = logicview.idx(_lv_seq, 0)
    addrlen = logicview.idx(_lv_seq, 1)
  end
  if logicview.truth((not logicview.eq((logicview.idx(bytes_, (addrlen - 1)) & 128), 0))) then
    return nil
  end
  addr_bits = logicview.mul(7, addrlen)
  have_exc_info = false
  if logicview.truth(logicview.eq(branch_enc, "original")) then
    if logicview.truth((function()
  local _v
  _v = logicview.eq(addrlen, 5)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(bytes_, 4) & 64)
  return _v
end)()) then
      have_exc_info = true
    end
  elseif logicview.truth(logicview.eq(branch_enc, "alternative")) then
    addr_bits = (addr_bits - 1)
    if logicview.truth((function()
  local _v
  _v = (addrlen >= 2)
  if not logicview.truth(_v) then return _v end
  _v = (addr & (1 << addr_bits))
  return _v
end)()) then
      have_exc_info = true
      addr = (addr & (~(1 << addr_bits)))
    end
  end
  exc_info = nil
  if logicview.truth(have_exc_info) then
    exc_info = parse_exc_info(logicview.slice(bytes_, addrlen, nil, nil))
    if logicview.truth((exc_info == nil)) then
      return nil
    end
  end
  if logicview.truth(logicview.eq(addrlen, 5)) then
    if logicview.truth(logicview.eq((logicview.idx(bytes_, 4) & 184), 8)) then
      cpu_state = "arm"
    elseif logicview.truth(logicview.eq((logicview.idx(bytes_, 4) & 176), 16)) then
      cpu_state = "thumb"
    elseif logicview.truth(logicview.eq((logicview.idx(bytes_, 4) & 160), 32)) then
      cpu_state = "jazelle"
    else
      _error(NotImplementedError(logicview.pymod("Unhandled branch byte 4: 0x%02x", logicview.idx(bytes_, 4))), 0)
    end
  end
  if logicview.truth(logicview.eq(cpu_state, "arm")) then
    addr = ((addr & 4294967294) << 1)
    addr_bits = logicview.add(addr_bits, 1)
  elseif logicview.truth(logicview.eq(cpu_state, "thumb")) then
    addr = (addr & 4294967294)
  elseif logicview.truth(logicview.eq(cpu_state, "jazelle")) then
    addr = ((addr & 68719476734) >> 1)
    addr_bits = (addr_bits - 1)
  else
    _error(NotImplementedError(logicview.add("Unhandled state: ", cpu_state)), 0)
  end
  if logicview.truth((addrlen < 5)) then
    addr = (addr | (ref_addr & (4294967295 << addr_bits)))
  end
  return { addr, addrlen, cpu_state, exc_info }
end
_decoder = {
  api_version = 3,
  id = "arm_etmv3",
  name = "ARM ETMv3",
  longname = "ARM Embedded Trace Macroblock v3",
  desc = "ARM ETM v3 instruction trace protocol.",
  license = "gplv2+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "objdump", desc = "objdump path", default = "arm-none-eabi-objdump", values = {  } }), logicview.dict({ id = "objdump_opts", desc = "objdump options", default = "-lSC", values = {  } }), logicview.dict({ id = "elffile", desc = ".elf path", default = "", values = {  } }), logicview.dict({ id = "branch_enc", desc = "Branch encoding", default = "alternative", values = { "alternative", "original" } }) },
  annotations = { { "trace", "Trace info" }, { "branch", "Branches" }, { "exception", "Exceptions" }, { "execution", "Instruction execution" }, { "data", "Data access" }, { "pc", "Program counter" }, { "instr_e", "Executed instructions" }, { "instr_n", "Not executed instructions" }, { "source", "Source code" }, { "location", "Current location" }, { "function", "Current function" } },
  annotation_rows = { { "trace", "Trace info", { 0 } }, { "flow", "Code flow", { 1, 2, 3 } }, { "data", "Data access", { 4 } }, { "pc", "Program counter", { 5 } }, { "instruction", "Instructions", { 6, 7 } }, { "source", "Source code", { 8 } }, { "location", "Current location", { 9 } }, { "function", "Current function", { 10 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.buf = {  }
  self.syncbuf = {  }
  self.prevsample = 0
  self.last_branch = 0
  self.cpu_state = "arm"
  self.current_pc = 0
  self.current_loc = nil
  self.current_func = nil
  self.next_instr_lookup = logicview.dict({  })
  self.file_lookup = logicview.dict({  })
  self.func_lookup = logicview.dict({  })
  self.disasm_lookup = logicview.dict({  })
  self.source_lookup = logicview.dict({  })
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self:load_objdump()
end
function _decoder.load_objdump(self)
  local opts, disasm, instpat, branchpat, filepat, funcpat, prev_src, prev_file, prev_func, line, m, addr, raw, disas, ilen, next_n, bm, next_e
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
  branchpat = re.compile("(b|bl|b..|bl..|cbnz|cbz)(?:\\.[wn])?\\s+(?:r[0-9]+,\\s*)?([0-9a-fA-F]+)")
  filepat = re.compile("[^\\s]+[/\\\\]([a-zA-Z0-9._-]+:[0-9]+)(?:\\s.*)?")
  funcpat = re.compile("[0-9a-fA-F]+\\s*<([^>]+)>:.*")
  prev_src = ""
  prev_file = ""
  prev_func = ""
  for _lv_item in logicview.iter(logicview.split(disasm, "\n", nil)) do
    line = _lv_item
    m = instpat:match(line)
    if logicview.truth(m) then
      addr = logicview.tointeger(m:group(1), 16)
      raw = m:group(2)
      disas = logicview.replace(logicview.strip(m:group(3)), "\t", " ", nil)
      logicview.setidx(self.disasm_lookup, addr, disas)
      logicview.setidx(self.source_lookup, addr, prev_src)
      logicview.setidx(self.file_lookup, addr, prev_file)
      logicview.setidx(self.func_lookup, addr, prev_func)
      ilen = logicview.floordiv(logicview.len(logicview.replace(raw, " ", "", nil)), 2)
      next_n = logicview.add(addr, ilen)
      bm = branchpat:match(disas)
      if logicview.truth(bm) then
        next_e = logicview.tointeger(bm:group(2), 16)
      else
        next_e = next_n
      end
      logicview.setidx(self.next_instr_lookup, addr, { next_n, next_e })
    else
      m = funcpat:match(line)
      if logicview.truth(m) then
        prev_func = m:group(1)
        prev_src = nil
      else
        m = filepat:match(line)
        if logicview.truth(m) then
          prev_file = m:group(1)
          prev_src = nil
        else
          prev_src = logicview.strip(line)
        end
      end
    end
    ::continue_4::
  end
end
function _decoder.flush_current_loc(self)
  local ss, es, loc, src
  if logicview.truth((self.current_loc ~= nil)) then
    do
      local _lv_seq = self.current_loc
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      loc = logicview.idx(_lv_seq, 2)
      src = logicview.idx(_lv_seq, 3)
    end
    if logicview.truth(loc) then
      self:put(ss, es, self.out_ann, { 9, { loc } })
    end
    if logicview.truth(src) then
      self:put(ss, es, self.out_ann, { 8, { src } })
    end
    self.current_loc = nil
  end
end
function _decoder.flush_current_func(self)
  local ss, es, func
  if logicview.truth((self.current_func ~= nil)) then
    do
      local _lv_seq = self.current_func
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ss = logicview.idx(_lv_seq, 0)
      es = logicview.idx(_lv_seq, 1)
      func = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(func) then
      self:put(ss, es, self.out_ann, { 10, { func } })
    end
    self.current_func = nil
  end
end
function _decoder.instructions_executed(self, exec_status)
  local tdelta, i, pc, default_next, target_n, target_e, ss, es, new_loc, new_src, new_dis, new_func, a
  if logicview.truth(logicview.eq(logicview.len(exec_status), 0)) then
    return
  end
  tdelta = _math.max(1, ((self.prevsample - self.startsample) / logicview.len(exec_status)))
  for _lv_i, _lv_v in logicview.enumerate(exec_status) do
    i = _lv_i
    exec_status = _lv_v
    pc = self.current_pc
    default_next = (function() if logicview.truth(logicview.eq(self.cpu_state, "thumb")) then return logicview.add(pc, 2) else return logicview.add(pc, 4) end end)()
    do
      local _lv_seq = logicview.dget(self.next_instr_lookup, pc, { default_next, default_next })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      target_n = logicview.idx(_lv_seq, 0)
      target_e = logicview.idx(_lv_seq, 1)
    end
    ss = logicview.add(self.startsample, (function() local _n = logicview.mul(tdelta, i); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)())
    es = logicview.add(self.startsample, (function() local _n = logicview.mul(tdelta, logicview.add(i, 1)); if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)())
    self:put(ss, es, self.out_ann, { 5, { logicview.pymod("PC 0x%08x", pc), logicview.pymod("0x%08x", pc), logicview.pymod("%08x", pc) } })
    new_loc = logicview.dget(self.file_lookup, pc, nil)
    new_src = logicview.dget(self.source_lookup, pc, nil)
    new_dis = logicview.dget(self.disasm_lookup, pc, nil)
    new_func = logicview.dget(self.func_lookup, pc, nil)
    if logicview.truth((self.current_loc ~= nil)) then
      if logicview.truth((function()
  local _v
  _v = (not logicview.eq(new_loc, logicview.idx(self.current_loc, 2)))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(new_src, logicview.idx(self.current_loc, 3)))
  return _v
end)()) then
        self:flush_current_loc()
      end
    end
    if logicview.truth((self.current_loc == nil)) then
      self.current_loc = { ss, es, new_loc, new_src }
    else
      logicview.setidx(self.current_loc, 1, es)
    end
    if logicview.truth((self.current_func ~= nil)) then
      if logicview.truth((not logicview.eq(new_func, logicview.idx(self.current_func, 2)))) then
        self:flush_current_func()
      end
    end
    if logicview.truth((self.current_func == nil)) then
      self.current_func = { ss, es, new_func }
    else
      logicview.setidx(self.current_func, 1, es)
    end
    if logicview.truth(new_dis) then
      if logicview.truth(exec_status) then
        a = { 6, { logicview.add("Executed: ", new_dis), new_dis, logicview.idx(logicview.split(new_dis, nil, nil), 0) } }
      else
        a = { 7, { logicview.add("Not executed: ", new_dis), new_dis, logicview.idx(logicview.split(new_dis, nil, nil), 0) } }
      end
      self:put(ss, es, self.out_ann, a)
    end
    if logicview.truth(exec_status) then
      self.current_pc = target_e
    else
      self.current_pc = target_n
    end
    ::continue_5::
  end
end
function _decoder.get_packet_type(self, byte)
  if logicview.truth(logicview.eq((byte & 1), 1)) then
    return "branch"
  elseif logicview.truth(logicview.eq(byte, 0)) then
    return "a_sync"
  elseif logicview.truth(logicview.eq(byte, 4)) then
    return "cyclecount"
  elseif logicview.truth(logicview.eq(byte, 8)) then
    return "i_sync"
  elseif logicview.truth(logicview.eq(byte, 12)) then
    return "trigger"
  elseif logicview.truth(logicview.contains({ 32, 64, 96 }, (byte & 243))) then
    return "ooo_data"
  elseif logicview.truth(logicview.eq(byte, 80)) then
    return "store_failed"
  elseif logicview.truth(logicview.eq(byte, 112)) then
    return "i_sync"
  elseif logicview.truth(logicview.contains({ 84, 88, 92 }, (byte & 223))) then
    return "ooo_place"
  elseif logicview.truth(logicview.eq(byte, 60)) then
    return "vmid"
  elseif logicview.truth(logicview.eq((byte & 211), 2)) then
    return "data"
  elseif logicview.truth(logicview.eq((byte & 251), 66)) then
    return "timestamp"
  elseif logicview.truth(logicview.eq(byte, 98)) then
    return "data_suppressed"
  elseif logicview.truth(logicview.eq(byte, 102)) then
    return "ignore"
  elseif logicview.truth(logicview.eq((byte & 239), 106)) then
    return "value_not_traced"
  elseif logicview.truth(logicview.eq(byte, 110)) then
    return "context_id"
  elseif logicview.truth(logicview.eq(byte, 118)) then
    return "exception_exit"
  elseif logicview.truth(logicview.eq(byte, 126)) then
    return "exception_entry"
  elseif logicview.truth(logicview.eq((byte & 129), 128)) then
    return "p_header"
  else
    return "unknown"
  end
end
function _decoder.fallback(self, buf)
  local ptype
  ptype = self:get_packet_type(logicview.idx(buf, 0))
  return { 0, { logicview.add(logicview.add(logicview.add("Unhandled ", ptype), ": "), logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(buf) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02x", b)
  end
  return _lv_out
end)())) } }
end
function _decoder.handle_a_sync(self, buf)
  if logicview.truth(logicview.eq(logicview.idx(buf, (-1)), 128)) then
    return { 0, { "Synchronization" } }
  end
end
function _decoder.handle_exception_exit(self, buf)
  return { 2, { "Exception exit" } }
end
function _decoder.handle_exception_entry(self, buf)
  return { 2, { "Exception entry" } }
end
function _decoder.handle_i_sync(self, buf)
  local contextid_bytes, cyclecount, idx, cyclen, infobyte, addr, reasoncode, reason, jazelle, nonsec, altisa, hypervisor, thumb, cycstr
  contextid_bytes = 0
  if logicview.truth((logicview.len(buf) < 6)) then
    return nil
  end
  if logicview.truth(logicview.eq(logicview.idx(buf, 0), 8)) then
    cyclecount = nil
    idx = logicview.add(1, contextid_bytes)
  elseif logicview.truth(logicview.eq(logicview.idx(buf, 0), 112)) then
    do
      local _lv_seq = parse_varint(logicview.slice(buf, 1, 6, nil))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cyclecount = logicview.idx(_lv_seq, 0)
      cyclen = logicview.idx(_lv_seq, 1)
    end
    idx = logicview.add(logicview.add(1, cyclen), contextid_bytes)
  end
  if logicview.truth((logicview.len(buf) <= logicview.add(idx, 4))) then
    return nil
  end
  infobyte = logicview.idx(buf, idx)
  addr = parse_uint(logicview.slice(buf, logicview.add(idx, 1), logicview.add(idx, 5), nil))
  reasoncode = ((infobyte >> 5) & 3)
  reason = logicview.idx({ "Periodic", "Tracing enabled", "After overflow", "Exit from debug" }, reasoncode)
  jazelle = ((infobyte >> 4) & 1)
  nonsec = ((infobyte >> 3) & 1)
  altisa = ((infobyte >> 2) & 1)
  hypervisor = ((infobyte >> 1) & 1)
  thumb = (addr & 1)
  addr = (addr & 4294967294)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(reasoncode, 0)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.current_pc, addr))
  return _v
end)()) then
    self:put(self.startsample, self.prevsample, self.out_ann, { 0, { logicview.pymod("WARN: Unexpected PC change 0x%08x -> 0x%08x", { self.current_pc, addr }) } })
  elseif logicview.truth((not logicview.eq(reasoncode, 0))) then
    self:flush_current_loc()
    self:flush_current_func()
  end
  self.last_branch = addr
  self.current_pc = addr
  if logicview.truth(jazelle) then
    self.cpu_state = "jazelle"
  elseif logicview.truth(thumb) then
    self.cpu_state = "thumb"
  else
    self.cpu_state = "arm"
  end
  cycstr = ""
  if logicview.truth((cyclecount ~= nil)) then
    cycstr = logicview.pymod(", cyclecount %d", cyclecount)
  end
  if logicview.truth((infobyte & 128)) then
    self:put(self.startsample, self.prevsample, self.out_ann, { 0, { "WARN: LSIP I-Sync packet not implemented" } })
  end
  return { 0, { logicview.pymod("I-Sync: %s, PC 0x%08x, %s state%s", { reason, addr, self.cpu_state, cycstr }), logicview.pymod("I-Sync: %s 0x%08x", { reason, addr }) } }
end
function _decoder.handle_trigger(self, buf)
  return { 0, { "Trigger event", "Trigger" } }
end
function _decoder.handle_p_header(self, buf)
  local n, e, i1, i2, txt1, txt2
  if logicview.truth(logicview.eq((logicview.idx(buf, 0) & 131), 128)) then
    n = ((logicview.idx(buf, 0) >> 6) & 1)
    e = ((logicview.idx(buf, 0) >> 2) & 15)
    self:instructions_executed(logicview.add(logicview.mul({ 1 }, e), logicview.mul({ 0 }, n)))
    if logicview.truth(n) then
      return { 3, { logicview.pymod("%d instructions executed, %d skipped due to condition codes", { e, n }), logicview.pymod("%d ins exec, %d skipped", { e, n }), logicview.pymod("%dE,%dN", { e, n }) } }
    else
      return { 3, { logicview.pymod("%d instructions executed", e), logicview.pymod("%d ins exec", e), logicview.pymod("%dE", e) } }
    end
  elseif logicview.truth(logicview.eq((logicview.idx(buf, 0) & 243), 130)) then
    i1 = ((logicview.idx(buf, 0) >> 3) & 1)
    i2 = ((logicview.idx(buf, 0) >> 2) & 1)
    self:instructions_executed({ (not logicview.truth(i1)), (not logicview.truth(i2)) })
    txt1 = { "executed", "skipped" }
    txt2 = { "E", "S" }
    return { 3, { logicview.pymod("Instruction 1 %s, instruction 2 %s", { logicview.idx(txt1, i1), logicview.idx(txt1, i2) }), logicview.pymod("I1 %s, I2 %s", { logicview.idx(txt2, i1), logicview.idx(txt2, i2) }), logicview.pymod("%s,%s", { logicview.idx(txt2, i1), logicview.idx(txt2, i2) }) } }
  else
    return self:fallback(buf)
  end
end
function _decoder.handle_branch(self, buf)
  local brinfo, addr, addrlen, cpu_state, exc_info, txt, annidx, ns, exc, cancel, altisa, hyp, resume
  if logicview.truth((not logicview.eq((logicview.idx(buf, (-1)) & 128), 0))) then
    return nil
  end
  brinfo = parse_branch_addr(buf, self.last_branch, self.cpu_state, logicview.idx(self.options, "branch_enc"))
  if logicview.truth((brinfo == nil)) then
    return nil
  end
  do
    local _lv_seq = brinfo
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    addr = logicview.idx(_lv_seq, 0)
    addrlen = logicview.idx(_lv_seq, 1)
    cpu_state = logicview.idx(_lv_seq, 2)
    exc_info = logicview.idx(_lv_seq, 3)
  end
  self.last_branch = addr
  self.current_pc = addr
  txt = ""
  if logicview.truth((not logicview.eq(cpu_state, self.cpu_state))) then
    txt = logicview.add(txt, logicview.pymod(", to %s state", cpu_state))
    self.cpu_state = cpu_state
  end
  annidx = 1
  if logicview.truth(exc_info) then
    annidx = 2
    do
      local _lv_seq = exc_info
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ns = logicview.idx(_lv_seq, 0)
      exc = logicview.idx(_lv_seq, 1)
      cancel = logicview.idx(_lv_seq, 2)
      altisa = logicview.idx(_lv_seq, 3)
      hyp = logicview.idx(_lv_seq, 4)
      resume = logicview.idx(_lv_seq, 5)
    end
    if logicview.truth(ns) then
      txt = logicview.add(txt, ", to non-secure state")
    end
    if logicview.truth(exc) then
      if logicview.truth((exc < logicview.len(exc_names))) then
        txt = logicview.add(txt, logicview.pymod(", exception %s", logicview.idx(exc_names, exc)))
      else
        txt = logicview.add(txt, logicview.pymod(", exception 0x%02x", exc))
      end
    end
    if logicview.truth(cancel) then
      txt = logicview.add(txt, ", instr cancelled")
    end
    if logicview.truth(altisa) then
      txt = logicview.add(txt, ", to AltISA")
    end
    if logicview.truth(hyp) then
      txt = logicview.add(txt, ", to hypervisor")
    end
    if logicview.truth(resume) then
      txt = logicview.add(txt, logicview.pymod(", instr resume 0x%02x", resume))
    end
  end
  return { annidx, { logicview.pymod("Branch to 0x%08x%s", { addr, txt }), logicview.pymod("B 0x%08x%s", { addr, txt }) } }
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
      self:flush_current_loc()
      self:flush_current_func()
      self.buf = {  }
    end
    self.prevsample = es
    _table.insert(self.buf, logicview.idx(pdata, 0))
    if logicview.truth(logicview.eq(logicview.len(self.buf), 1)) then
      self.startsample = ss
    end
    self.syncbuf = logicview.add(logicview.slice(self.syncbuf, (-4), nil, nil), { logicview.idx(pdata, 0) })
    if logicview.truth(logicview.eq(self.syncbuf, { 0, 0, 0, 0, 128 })) then
      self.buf = self.syncbuf
      self.syncbuf = {  }
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
