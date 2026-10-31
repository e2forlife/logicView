-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011-2014 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2016 Gerhard Sittig <gerhard.sittig@gmx.net>
-- Copyright (C) 2023 DreamSourceLab <support@dreamsourcelab.com>

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
local namedtuple, Ann, Bit, PDI, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(15) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIT = logicview.idx(_lv_seq, 0)
  Ann.START = logicview.idx(_lv_seq, 1)
  Ann.DATA = logicview.idx(_lv_seq, 2)
  Ann.PARITY_OK = logicview.idx(_lv_seq, 3)
  Ann.PARITY_ERR = logicview.idx(_lv_seq, 4)
  Ann.STOP_OK = logicview.idx(_lv_seq, 5)
  Ann.STOP_ERR = logicview.idx(_lv_seq, 6)
  Ann.BREAK = logicview.idx(_lv_seq, 7)
  Ann.OPCODE = logicview.idx(_lv_seq, 8)
  Ann.DATA_PROG = logicview.idx(_lv_seq, 9)
  Ann.DATA_DEV = logicview.idx(_lv_seq, 10)
  Ann.PDI_BREAK = logicview.idx(_lv_seq, 11)
  Ann.ENABLE = logicview.idx(_lv_seq, 12)
  Ann.DISABLE = logicview.idx(_lv_seq, 13)
  Ann.COMMAND = logicview.idx(_lv_seq, 14)
end
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(1) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.BIN_BYTES = logicview.idx(_lv_seq, 0)
end
Bit = (function() local _f = "val ss es"; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
PDI = {}
PDI.__index = PDI
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(8) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  PDI.OP_LDS = logicview.idx(_lv_seq, 0)
  PDI.OP_LD = logicview.idx(_lv_seq, 1)
  PDI.OP_STS = logicview.idx(_lv_seq, 2)
  PDI.OP_ST = logicview.idx(_lv_seq, 3)
  PDI.OP_LDCS = logicview.idx(_lv_seq, 4)
  PDI.OP_REPEAT = logicview.idx(_lv_seq, 5)
  PDI.OP_STCS = logicview.idx(_lv_seq, 6)
  PDI.OP_KEY = logicview.idx(_lv_seq, 7)
end
PDI.pointer_format_nice = { "*(ptr)", "*(ptr++)", "ptr", "ptr++ (rsv)" }
PDI.pointer_format_terse = { "*p", "*p++", "p", "(rsv)" }
PDI.ctrl_reg_name = logicview.dict({ [0] = "status", [1] = "reset", [2] = "ctrl" })
_decoder = {
  api_version = 3,
  id = "avr_pdi",
  name = "AVR PDI",
  longname = "Atmel Program and Debug Interface",
  desc = "Atmel ATxmega Program and Debug Interface (PDI) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = { logicview.dict({ id = "reset", name = "RESET", desc = "RESET / PDI_CLK" }), logicview.dict({ id = "data", name = "DATA", desc = "PDI_DATA" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "uart-bit", "UART bit" }, { "start-bit", "Start bit" }, { "data-bit", "Data bit" }, { "parity-ok", "Parity OK bit" }, { "parity-err", "Parity error bit" }, { "stop-ok", "Stop OK bit" }, { "stop-err", "Stop error bit" }, { "break", "BREAK condition" }, { "opcode", "Instruction opcode" }, { "data-prog", "Programmer data" }, { "data-dev", "Device data" }, { "pdi-break", "BREAK at PDI level" }, { "enable", "Enable PDI" }, { "disable", "Disable PDI" }, { "cmd-data", "PDI command with data" } },
  annotation_rows = { { "uart_bits", "UART bits", { 0 } }, { "uart_fields", "UART fields", { 1, 2, 3, 4, 5, 6, 7 } }, { "pdi_fields", "PDI fields", { 8, 9, 10, 11 } }, { "pdi_cmds", "PDI Cmds", { 12, 13, 14 } } },
  binary = { { "bytes", "PDI protocol bytes" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self:clear_state()
end
function _decoder.clear_state(self)
  self.ss_last_fall = nil
  self.data_sample = nil
  self.ss_curr_fall = nil
  self.bits = {  }
  self.zero_count = 0
  self.zero_ss = nil
  self.break_ss = nil
  self.break_es = nil
  self:clear_insn()
end
function _decoder.clear_insn(self)
  self.insn_rep_count = 0
  self.insn_opcode = nil
  self.insn_dat_bytes = {  }
  self.insn_dat_count = 0
  self.insn_ss_data = nil
  self.cmd_ss = nil
  self.cmd_insn_parts_nice = {  }
  self.cmd_insn_parts_terse = {  }
  self.insn_write_counts = 0
  self.insn_read_counts = 0
  self.width_addr = 0
  self.width_data = 0
  self.ptr_txt = nil
  self.ptr_txt_terse = nil
  self.reg_num = nil
  self.reg_txt = nil
  self.reg_txt_terse = nil
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
function _decoder.put_ann_bit(self, bit_nr, ann_idx)
  local b
  b = logicview.idx(self.bits, bit_nr)
  self:put(b.ss, b.es, self.out_ann, { ann_idx, { _tostring(b.val) } })
end
function _decoder.put_ann_data(self, bit_nr, ann_data)
  local b
  b = logicview.idx(self.bits, bit_nr)
  self:put(b.ss, b.es, self.out_ann, ann_data)
end
function _decoder.put_ann_row_val(self, ss, es, row, value)
  self:put(ss, es, self.out_ann, { row, value })
end
function _decoder.put_bin_bytes(self, ss, es, row, value)
  self:put(ss, es, self.out_binary, { row, value })
end
function _decoder.handle_byte(self, ss, es, byteval)
  local is_break, opcode, arg30, arg32, arg10, mnemonics, data_ss, data_es, data_ann, data_txt_digits, data_txt_hex, data_txt_prefix, data_txts, cmd_es, cmd_txt_nice, cmd_txt_terse, cmd_txts, count, save_rep_count
  is_break = (byteval == nil)
  if logicview.truth(is_break) then
    _table.insert(self.cmd_insn_parts_nice, "BREAK")
    _table.insert(self.cmd_insn_parts_terse, "BRK")
    self.insn_rep_count = 0
  end
  if logicview.truth((function()
  local _v
  _v = (self.insn_opcode == nil)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_break))
  return _v
end)()) then
    opcode = ((byteval & 224) >> 5)
    arg30 = (byteval & 15)
    arg32 = ((byteval & 12) >> 2)
    arg10 = (byteval & 3)
    self.insn_opcode = opcode
    self.cmd_ss = ss
    mnemonics = nil
    if logicview.truth(logicview.eq(opcode, PDI.OP_LDS)) then
      self.width_addr = logicview.add(arg32, 1)
      self.width_data = logicview.add(arg10, 1)
      self.insn_write_counts = 1
      self.insn_read_counts = 1
      mnemonics = { logicview.pyformat("Insn: LDS a{:d}, m{:d}", { self.width_addr, self.width_data }, logicview.dict({})), logicview.pyformat("LDS a{:d}, m{:d}", { self.width_addr, self.width_data }, logicview.dict({})), "LDS" }
      self.cmd_insn_parts_nice = { "LDS" }
      self.cmd_insn_parts_terse = { "LDS" }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_LD)) then
      self.ptr_txt = logicview.idx(PDI.pointer_format_nice, arg32)
      self.ptr_txt_terse = logicview.idx(PDI.pointer_format_terse, arg32)
      self.width_data = logicview.add(arg10, 1)
      self.insn_write_counts = 0
      self.insn_read_counts = 1
      if logicview.truth(self.insn_rep_count) then
        self.insn_read_counts = logicview.mul(self.insn_rep_count, self.insn_read_counts)
        self.insn_rep_count = 0
      end
      mnemonics = { logicview.pyformat("Insn: LD {:s} m{:d}", { self.ptr_txt, self.width_data }, logicview.dict({})), logicview.pyformat("LD {:s} m{:d}", { self.ptr_txt, self.width_data }, logicview.dict({})), "LD" }
      self.cmd_insn_parts_nice = { "LD", self.ptr_txt }
      self.cmd_insn_parts_terse = { "LD", self.ptr_txt_terse }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_STS)) then
      self.width_addr = logicview.add(arg32, 1)
      self.width_data = logicview.add(arg10, 1)
      self.insn_write_counts = 2
      self.insn_read_counts = 0
      mnemonics = { logicview.pyformat("Insn: STS a{:d}, i{:d}", { self.width_addr, self.width_data }, logicview.dict({})), logicview.pyformat("STS a{:d}, i{:d}", { self.width_addr, self.width_data }, logicview.dict({})), "STS" }
      self.cmd_insn_parts_nice = { "STS" }
      self.cmd_insn_parts_terse = { "STS" }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_ST)) then
      self.ptr_txt = logicview.idx(PDI.pointer_format_nice, arg32)
      self.ptr_txt_terse = logicview.idx(PDI.pointer_format_terse, arg32)
      self.width_data = logicview.add(arg10, 1)
      self.insn_write_counts = 1
      self.insn_read_counts = 0
      if logicview.truth(self.insn_rep_count) then
        self.insn_write_counts = logicview.mul(self.insn_rep_count, self.insn_write_counts)
        self.insn_rep_count = 0
      end
      mnemonics = { logicview.pyformat("Insn: ST {:s} i{:d}", { self.ptr_txt, self.width_data }, logicview.dict({})), logicview.pyformat("ST {:s} i{:d}", { self.ptr_txt, self.width_data }, logicview.dict({})), "ST" }
      self.cmd_insn_parts_nice = { "ST", self.ptr_txt }
      self.cmd_insn_parts_terse = { "ST", self.ptr_txt_terse }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_LDCS)) then
      self.reg_num = arg30
      self.reg_txt = logicview.dget(PDI.ctrl_reg_name, self.reg_num, logicview.pyformat("r{:d}", { self.reg_num }, logicview.dict({})))
      self.reg_txt_terse = logicview.pyformat("{:d}", { self.reg_num }, logicview.dict({}))
      self.insn_write_counts = 0
      self.insn_read_counts = 1
      self.width_data = 1
      mnemonics = { logicview.pyformat("Insn: LDCS {:s}, m1", { self.reg_txt }, logicview.dict({})), logicview.pyformat("LDCS {:s}, m1", { self.reg_txt }, logicview.dict({})), "LDCS" }
      self.cmd_insn_parts_nice = { "LDCS", self.reg_txt }
      self.cmd_insn_parts_terse = { "LDCS", self.reg_txt_terse }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_STCS)) then
      self.reg_num = arg30
      self.reg_txt = logicview.dget(PDI.ctrl_reg_name, self.reg_num, logicview.pyformat("r{:d}", { self.reg_num }, logicview.dict({})))
      self.reg_txt_terse = logicview.pyformat("{:d}", { self.reg_num }, logicview.dict({}))
      self.width_data = 1
      self.insn_write_counts = 1
      self.insn_read_counts = 0
      mnemonics = { logicview.pyformat("Insn: STCS {:s}, i1", { self.reg_txt }, logicview.dict({})), logicview.pyformat("STCS {:s}, i1", { self.reg_txt }, logicview.dict({})), "STCS" }
      self.cmd_insn_parts_nice = { "STCS", self.reg_txt }
      self.cmd_insn_parts_terse = { "STCS", self.reg_txt_terse }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_REPEAT)) then
      self.width_data = logicview.add(arg10, 1)
      self.insn_write_counts = 1
      self.insn_read_counts = 0
      mnemonics = { logicview.pyformat("Insn: REPEAT i{:d}", { self.width_data }, logicview.dict({})), logicview.pyformat("REPEAT i{:d}", { self.width_data }, logicview.dict({})), "REP" }
      self.cmd_insn_parts_nice = { "REPEAT" }
      self.cmd_insn_parts_terse = { "REP" }
    elseif logicview.truth(logicview.eq(opcode, PDI.OP_KEY)) then
      self.width_data = 8
      mnemonics = { logicview.pyformat("Insn: KEY i{:d}", { self.width_data }, logicview.dict({})), logicview.pyformat("KEY i{:d}", { self.width_data }, logicview.dict({})), "KEY" }
      self.cmd_insn_parts_nice = { "KEY" }
      self.cmd_insn_parts_terse = { "KEY" }
    end
    self:put_ann_row_val(ss, es, Ann.OPCODE, mnemonics)
    self.insn_dat_bytes = {  }
    if logicview.truth((not logicview.eq(self.insn_write_counts, 0))) then
      if logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDS)) then
        self.insn_dat_count = self.width_addr
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_STS)) then
        if logicview.truth(logicview.eq(self.insn_write_counts, 2)) then
          self.insn_dat_count = self.width_addr
        elseif logicview.truth(logicview.eq(self.insn_write_counts, 1)) then
          self.insn_dat_count = self.width_data
        end
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_ST)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_STCS)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_REPEAT)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_KEY)) then
        self.insn_dat_count = self.width_data
      end
      return
    end
    if logicview.truth((not logicview.eq(self.insn_read_counts, 0))) then
      if logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDS)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LD)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDCS)) then
        self.insn_dat_count = self.width_data
      end
      return
    end
  end
  if logicview.truth((function()
  local _v
  _v = self.insn_dat_count
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_break))
  return _v
end)()) then
    if logicview.truth((not logicview.truth(self.insn_dat_bytes))) then
      self.insn_ss_data = ss
    end
    _table.insert(self.insn_dat_bytes, byteval)
    self.insn_dat_count = (self.insn_dat_count - 1)
    if logicview.truth(self.insn_dat_count) then
      return
    end
    data_ss = self.insn_ss_data
    data_es = es
    if logicview.truth((not logicview.eq(self.insn_write_counts, 0))) then
      data_ann = Ann.DATA_PROG
      self.insn_write_counts = (self.insn_write_counts - 1)
    elseif logicview.truth((not logicview.eq(self.insn_read_counts, 0))) then
      data_ann = Ann.DATA_DEV
      self.insn_read_counts = (self.insn_read_counts - 1)
    end
    logicview.list_reverse(self.insn_dat_bytes)
    data_txt_digits = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.insn_dat_bytes) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{:02x}", { b }, logicview.dict({}))
  end
  return _lv_out
end)())
    data_txt_hex = logicview.add("0x", data_txt_digits)
    data_txt_prefix = logicview.add("Data: ", data_txt_hex)
    data_txts = { data_txt_prefix, data_txt_hex, data_txt_digits }
    self.insn_dat_bytes = {  }
    self:put_ann_row_val(data_ss, data_es, data_ann, data_txts)
    _table.insert(self.cmd_insn_parts_nice, data_txt_hex)
    _table.insert(self.cmd_insn_parts_terse, data_txt_digits)
    if logicview.truth((not logicview.eq(self.insn_write_counts, 0))) then
      if logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDS)) then
        self.insn_dat_count = self.width_addr
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_STS)) then
        if logicview.truth(logicview.eq(self.insn_write_counts, 2)) then
          self.insn_dat_count = self.width_addr
        elseif logicview.truth(logicview.eq(self.insn_write_counts, 1)) then
          self.insn_dat_count = self.width_data
        end
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_ST)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_STCS)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_REPEAT)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(opcode, PDI.OP_KEY)) then
        self.insn_dat_count = self.width_data
      end
      return
    end
    if logicview.truth((not logicview.eq(self.insn_read_counts, 0))) then
      if logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDS)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LD)) then
        self.insn_dat_count = self.width_data
      elseif logicview.truth(logicview.eq(self.insn_opcode, PDI.OP_LDCS)) then
        self.insn_dat_count = self.width_data
      end
      return
    end
  end
  if logicview.truth(logicview.eq(self.cmd_ss, nil)) then
    self:printlog("self.cmd_ss is null")
    return
  end
  cmd_es = es
  cmd_txt_nice = logicview.join(" ", self.cmd_insn_parts_nice)
  cmd_txt_terse = logicview.join(" ", self.cmd_insn_parts_terse)
  cmd_txts = { cmd_txt_nice, cmd_txt_terse }
  self:put_ann_row_val(self.cmd_ss, cmd_es, Ann.COMMAND, cmd_txts)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.insn_opcode, PDI.OP_REPEAT)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(is_break))
  return _v
end)()) then
    count = logicview.tointeger(logicview.idx(self.cmd_insn_parts_nice, (-1)), 0)
    self.insn_rep_count = count
  end
  save_rep_count = self.insn_rep_count
  self:clear_insn()
  self.insn_rep_count = save_rep_count
end
function _decoder.handle_bits(self, ss, es, bitval)
  local ann_class_text, put_uart_field, frame_bitcount, bits_num, start_bit, data_val, data_text, parity_bit, stop_bit, parity_ok, stop_ok, valid_frame, idx, byte_ss, byte_es
  ann_class_text = logicview.dict({ [Ann.START] = { "Start bit", "Start", "S" }, [Ann.PARITY_OK] = { "Parity OK", "Par OK", "P" }, [Ann.PARITY_ERR] = { "Parity error", "Par ERR", "PE" }, [Ann.STOP_OK] = { "Stop bit", "Stop", "T" }, [Ann.STOP_ERR] = { "Stop bit error", "Stop ERR", "TE" }, [Ann.BREAK] = { "Break condition", "BREAK", "BRK" } })
  put_uart_field = function(bitpos, annclass)
    self:put_ann_data(bitpos, { annclass, logicview.idx(ann_class_text, annclass) })
  end
  frame_bitcount = logicview.add(logicview.add(logicview.add(1, 8), 1), 1)
  if logicview.truth(logicview.eq(bitval, 1)) then
    self.zero_count = 0
  elseif logicview.truth(logicview.eq(bitval, 0)) then
    if logicview.truth((not logicview.truth(self.zero_count))) then
      self.zero_ss = ss
    end
    self.zero_count = logicview.add(self.zero_count, 1)
    if logicview.truth(logicview.eq(self.zero_count, frame_bitcount)) then
      self.break_ss = self.zero_ss
    end
  end
  if logicview.truth((self.break_ss ~= nil)) then
    if logicview.truth(logicview.eq(bitval, 0)) then
      self.break_es = es
      return
    end
    if logicview.truth(logicview.eq(self.break_es, nil)) then
      self:printlog("self.break_es is null.")
      return
    end
    self:put(self.break_ss, self.break_es, self.out_ann, { Ann.BREAK, logicview.idx(ann_class_text, Ann.BREAK) })
    self:handle_byte(self.break_ss, self.break_es, nil)
    self.break_ss = nil
    self.break_es = nil
    self.bits = {  }
    return
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.truth(self.bits))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(bitval, 1)
  return _v
end)()) then
    return
  end
  _table.insert(self.bits, Bit(bitval, ss, es))
  if logicview.truth((logicview.len(self.bits) < frame_bitcount)) then
    return
  end
  bits_num = logicview.sum((function()
  local _lv_out = {}
  for _lv_i, _lv_v in logicview.enumerate(self.bits) do
    pos = _lv_i
    b = _lv_v
    _lv_out[#_lv_out + 1] = (b.val << pos)
  end
  return _lv_out
end)())
  if logicview.truth(false) then
    if logicview.truth(logicview.eq(bits_num, 0)) then
      self.break_ss = logicview.idx(self.bits, 0).ss
      self.break_es = es
      self.bits = {  }
      return
    end
  end
  start_bit = (bits_num & 1)
  bits_num = (bits_num >> 1)
  data_val = (bits_num & 255)
  bits_num = (bits_num >> 8)
  data_text = logicview.pyformat("{:02x}", { data_val }, logicview.dict({}))
  parity_bit = (bits_num & 1)
  bits_num = (bits_num >> 1)
  stop_bit = (bits_num & 1)
  bits_num = (bits_num >> 1)
  parity_ok = logicview.eq(logicview.pymod(logicview.add(logicview.count(logicview.bin(data_val), "1"), parity_bit), 2), 0)
  stop_ok = logicview.eq(stop_bit, 1)
  valid_frame = (function()
  local _v
  _v = parity_ok
  if not logicview.truth(_v) then return _v end
  _v = stop_ok
  return _v
end)()
  for _lv_i in logicview.range(frame_bitcount) do
    idx = _lv_i
    self:put_ann_bit(idx, Ann.BIT)
    ::continue_1::
  end
  put_uart_field(0, Ann.START)
  self:put(logicview.idx(self.bits, 1).ss, logicview.idx(self.bits, 8).es, self.out_ann, { Ann.DATA, { logicview.add("Data: ", data_text), logicview.add("D: ", data_text), data_text } })
  put_uart_field(9, (function() if logicview.truth(parity_ok) then return Ann.PARITY_OK else return Ann.PARITY_ERR end end)())
  put_uart_field(10, (function() if logicview.truth(stop_ok) then return Ann.STOP_OK else return Ann.STOP_ERR end end)())
  if logicview.truth(valid_frame) then
    do
      local _lv_a0, _lv_a1 = logicview.idx(self.bits, 0).ss, logicview.idx(self.bits, (-1)).es
      byte_ss = _lv_a0
      byte_es = _lv_a1
    end
    self:put_bin_bytes(byte_ss, byte_es, Ann.BIN_BYTES, logicview.bytes({ data_val }))
    self:handle_byte(byte_ss, byte_es, data_val)
  end
  self.bits = {  }
end
function _decoder.handle_clk_edge(self, clock_pin, data_pin)
  local bit_ss, bit_es, bit_val
  if logicview.truth(logicview.eq(clock_pin, 1)) then
    self.data_sample = data_pin
    return
  end
  self.ss_last_fall = self.ss_curr_fall
  self.ss_curr_fall = self.samplenum
  if logicview.truth((self.ss_last_fall == nil)) then
    return
  end
  do
    local _lv_a0, _lv_a1 = self.ss_last_fall, self.ss_curr_fall
    bit_ss = _lv_a0
    bit_es = _lv_a1
  end
  bit_val = self.data_sample
  self:handle_bits(bit_ss, bit_es, bit_val)
end
function _decoder.decode(self)
  local clock_pin, data_pin
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clock_pin = logicview.idx(_lv_seq, 0)
      data_pin = logicview.idx(_lv_seq, 1)
    end
    self:handle_clk_edge(clock_pin, data_pin)
    ::continue_2::
  end
end

return _decoder
