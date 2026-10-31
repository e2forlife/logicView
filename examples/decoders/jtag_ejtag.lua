-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Vladislav Ivanov <vlad.ivanov@lab-systems.ru>

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
local bin2int, Instruction, State, ControlReg, Ann, ejtag_insn, ejtag_reg, ejtag_control_reg, ejtag_state_map, RegData, LastData, PraccState, regs_items, Decoder
local _decoder

bin2int = logicview.bin2int
Instruction = {}
Instruction.__index = Instruction
Instruction.IDCODE = 1
Instruction.IMPCODE = 3
Instruction.ADDRESS = 8
Instruction.DATA = 9
Instruction.CONTROL = 10
Instruction.ALL = 11
Instruction.EJTAGBOOT = 12
Instruction.NORMALBOOT = 13
Instruction.FASTDATA = 14
Instruction.TCBCONTROLA = 16
Instruction.TCBCONTROLB = 17
Instruction.TCBDATA = 18
Instruction.TCBCONTROLC = 19
Instruction.PCSAMPLE = 20
Instruction.TCBCONTROLD = 21
Instruction.TCBCONTROLE = 22
State = {}
State.__index = State
State.RESET = 0
State.DEVICE_ID = 1
State.IMPLEMENTATION = 2
State.DATA = 3
State.ADDRESS = 4
State.CONTROL = 5
State.FASTDATA = 6
State.PC_SAMPLE = 7
State.BYPASS = 8
ControlReg = {}
ControlReg.__index = ControlReg
ControlReg.PRACC = (1 << 18)
ControlReg.PRNW = (1 << 19)
Ann = {}
Ann.__index = Ann
Ann.INSTRUCTION = 0
Ann.REGISTER = 1
Ann.CONTROL_FIELD_IN = 10
Ann.CONTROL_FIELD_OUT = 11
Ann.PRACC = 12
ejtag_insn = logicview.dict({ [0] = { "Free", "Boundary scan" }, [1] = { "IDCODE", "Select Device Identification (ID) register" }, [2] = { "Free", "Boundary scan" }, [3] = { "IMPCODE", "Select Implementation register" }, [8] = { "ADDRESS", "Select Address register" }, [9] = { "DATA", "Select Data register" }, [10] = { "CONTROL", "Select EJTAG Control register" }, [11] = { "ALL", "Select the Address, Data and EJTAG Control registers" }, [12] = { "EJTAGBOOT", "Fetch code from the debug exception vector after reset" }, [13] = { "NORMALBOOT", "Execute the reset handler after reset" }, [14] = { "FASTDATA", "Select the Data and Fastdata registers" }, [15] = { "Reserved", "Reserved" }, [16] = { "TCBCONTROLA", "Select the control register TCBTraceControl" }, [17] = { "TCBCONTROLB", "Selects trace control block register B" }, [18] = { "TCBDATA", "Access the registers specified by TCBCONTROLB" }, [19] = { "TCBCONTROLC", "Select trace control block register C" }, [20] = { "PCSAMPLE", "Select the PCsample register" }, [21] = { "TCBCONTROLD", "Select trace control block register D" }, [22] = { "TCBCONTROLE", "Select trace control block register E" }, [23] = { "FDC", "Select Fast Debug Channel" }, [28] = { "Free", "Boundary scan" } })
ejtag_reg = logicview.dict({ [0] = "RESET", [1] = "DEVICE_ID", [2] = "IMPLEMENTATION", [3] = "DATA", [4] = "ADDRESS", [5] = "CONTROL", [6] = "FASTDATA", [7] = "PC_SAMPLE", [8] = "BYPASS" })
ejtag_control_reg = { { 31, 31, "Rocc", { { "No reset ocurred", "Reset ocurred" }, { "Acknowledge reset", "No effect" } } }, { 30, 29, "Psz", { { "Access: byte", "Access: halfword", "Access: word", "Access: triple" } } }, { 23, 23, "VPED", { { "VPE disabled", "VPE enabled" } } }, { 22, 22, "Doze", { { "Processor is not in low-power mode", "Processor is in low-power mode" } } }, { 21, 21, "Halt", { { "Internal system bus clock is running", "Internal system bus clock is stopped" } } }, { 20, 20, "Per Rst", { { "No peripheral reset applied", "Peripheral reset applied" }, { "Deassert peripheral reset", "Assert peripheral reset" } } }, { 19, 19, "PRn W", { { "Read processor access", "Write processor access" } } }, { 18, 18, "Pr Acc", { { "No pending processor access", "Pending processor access" }, { "Finish processor access", "Don't finish processor access" } } }, { 16, 16, "Pr Rst", { { "No processor reset applied", "Processor reset applied" }, { "Deassert processor reset", "Assert system reset" } } }, { 15, 15, "Prob En", { { "Probe will not serve processor accesses", "Probe will service processor accesses" } } }, { 14, 14, "Prob Trap", { { "Default location", "DMSEG fetch" }, { "Set to default location", "Set to DMSEG fetch" } } }, { 13, 13, "ISA On Debug", { { "MIPS32/MIPS64 ISA", "microMIPS ISA" }, { "Set to MIPS32/MIPS64 ISA", "Set to microMIPS ISA" } } }, { 12, 12, "EJTAG Brk", { { "No pending debug interrupt", "Pending debug interrupt" }, { "No effect", "Request debug interrupt" } } }, { 3, 3, "DM", { { "Not in debug mode", "In debug mode" } } } }
ejtag_state_map = logicview.dict({ [Instruction.IDCODE] = State.DEVICE_ID, [Instruction.IMPCODE] = State.IMPLEMENTATION, [Instruction.DATA] = State.DATA, [Instruction.ADDRESS] = State.ADDRESS, [Instruction.CONTROL] = State.CONTROL, [Instruction.FASTDATA] = State.FASTDATA })
RegData = {}
RegData.__index = RegData
function RegData.__init__(self)
  self.ss = nil
  self.es = nil
  self.data = nil
end
function RegData.new(...)
  local self = _setmetatable({}, RegData)
  RegData.__init__(self, ...)
  return self
end
LastData = {}
LastData.__index = LastData
function LastData.__init__(self)
  self.data_in = RegData.new()
  self.data_out = RegData.new()
end
function LastData.new(...)
  local self = _setmetatable({}, LastData)
  LastData.__init__(self, ...)
  return self
end
PraccState = {}
PraccState.__index = PraccState
function PraccState.reset(self)
  self.address_in = nil
  self.address_out = nil
  self.data_in = nil
  self.data_out = nil
  self.write = false
  self.ss = 0
  self.es = 0
end
function PraccState.__init__(self)
  self:reset()
end
function PraccState.new(...)
  local self = _setmetatable({}, PraccState)
  PraccState.__init__(self, ...)
  return self
end
regs_items = logicview.dict({ ann = logicview.copy((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.copy((function() local _t = {}; for _, _v in _pairs(ejtag_reg) do _t[#_t + 1] = _v end; return _t end)())) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = logicview.copy({ _string.lower(s), s })
  end
  return _lv_out
end)()), rows_range = logicview.copy((function() local _t = {}; for _v in logicview.range(1, logicview.add(1, 9)) do _t[#_t + 1] = _v end; return _t end)()) })
_decoder = {
  api_version = 3,
  id = "jtag_ejtag",
  name = "JTAG / EJTAG",
  longname = "Joint Test Action Group / EJTAG (MIPS)",
  desc = "MIPS EJTAG protocol.",
  license = "gplv2+",
  inputs = { "jtag" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "instruction", "Instruction" }, { "reset", "RESET" }, { "device_id", "DEVICE_ID" }, { "implementation", "IMPLEMENTATION" }, { "data", "DATA" }, { "address", "ADDRESS" }, { "control", "CONTROL" }, { "fastdata", "FASTDATA" }, { "pc_sample", "PC_SAMPLE" }, { "bypass", "BYPASS" }, { "control_field_in", "Control field in" }, { "control_field_out", "Control field out" }, { "pracc", "PrAcc" } },
  annotation_rows = { { "instructions", "Instructions", { 0 } }, { "regs", "Registers", { 1, 2, 3, 4, 5, 6, 7, 8, 9 } }, { "control_fields_in", "Control fields in", { 10 } }, { "control_fields_out", "Control fields out", { 11 } }, { "pracc", "PrAcc", { 12 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = State.RESET
  self.pracc_state = PraccState.new()
end
function _decoder.put_current(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.put_at(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.select_reg(self, ir_value)
  self.state = logicview.dget(ejtag_state_map, ir_value, State.RESET)
end
function _decoder.parse_pracc(self)
  local control_in, control_out, ss, es, pracc_write, s
  control_in = bin2int(logicview.idx(logicview.idx(logicview.idx(self.last_data, "in"), "data"), 0))
  control_out = bin2int(logicview.idx(logicview.idx(logicview.idx(self.last_data, "out"), "data"), 0))
  if logicview.truth((not logicview.truth((function()
  local _v
  _v = (not logicview.truth((control_in & ControlReg.PRACC)))
  if not logicview.truth(_v) then return _v end
  _v = (control_out & ControlReg.PRACC)
  return _v
end)()))) then
    return
  end
  do
    local _lv_a0, _lv_a1 = self.pracc_state.ss, self.pracc_state.es
    ss = _lv_a0
    es = _lv_a1
  end
  pracc_write = (not logicview.eq((control_out & ControlReg.PRNW), 0))
  s = "PrAcc: "
  s = logicview.add(s, (function() if logicview.truth(pracc_write) then return "Store" else return "Load/Fetch" end end)())
  if logicview.truth(pracc_write) then
    if logicview.truth((self.pracc_state.address_out ~= nil)) then
      s = logicview.add(s, logicview.add(", A:", logicview.pyformat(" 0x{:08X}", { self.pracc_state.address_out }, logicview.dict({}))))
    end
    if logicview.truth((self.pracc_state.data_out ~= nil)) then
      s = logicview.add(s, logicview.add(", D:", logicview.pyformat(" 0x{:08X}", { self.pracc_state.data_out }, logicview.dict({}))))
    end
  else
    if logicview.truth((self.pracc_state.address_out ~= nil)) then
      s = logicview.add(s, logicview.add(", A:", logicview.pyformat(" 0x{:08X}", { self.pracc_state.address_out }, logicview.dict({}))))
    end
    if logicview.truth((self.pracc_state.data_in ~= nil)) then
      s = logicview.add(s, logicview.add(", D:", logicview.pyformat(" 0x{:08X}", { self.pracc_state.data_in }, logicview.dict({}))))
    end
  end
  self.pracc_state:reset()
  self:put_at(ss, es, { Ann.PRACC, { s } })
end
function _decoder.parse_control_reg(self, ann)
  local reg_write, control_bit_positions, data_select, control_data, field, start_bit, end_bit, comment, value_descriptions, ss, es, value_str, value_index, short_desc, long_desc
  reg_write = logicview.eq(ann, Ann.CONTROL_FIELD_IN)
  control_bit_positions = {  }
  data_select = (function() if logicview.truth(reg_write) then return "in" else return "out" end end)()
  control_bit_positions = logicview.idx(logicview.idx(logicview.idx(self.last_data, data_select), "data"), 1)
  control_data = logicview.idx(logicview.idx(logicview.idx(self.last_data, data_select), "data"), 0)
  for _lv_item in logicview.iter(ejtag_control_reg) do
    field = _lv_item
    start_bit = (31 - logicview.idx(field, 1))
    end_bit = (31 - logicview.idx(field, 0))
    comment = logicview.idx(field, 2)
    value_descriptions = {  }
    if logicview.truth(reg_write) then
      if logicview.truth((logicview.len(logicview.idx(field, 3)) < 2)) then
        goto continue_1
      end
      value_descriptions = logicview.idx(logicview.idx(field, 3), 1)
    else
      value_descriptions = logicview.idx(logicview.idx(field, 3), 0)
    end
    ss = logicview.idx(logicview.idx(control_bit_positions, start_bit), 0)
    es = logicview.idx(logicview.idx(control_bit_positions, end_bit), 1)
    value_str = logicview.slice(control_data, end_bit, logicview.add(start_bit, 1), nil)
    value_index = bin2int(value_str)
    short_desc = logicview.add(logicview.add(comment, ": "), value_str)
    long_desc = (function() if logicview.truth((logicview.len(value_descriptions) > value_index)) then return logicview.idx(value_descriptions, value_index) else return "?" end end)()
    self:put_at(ss, es, { ann, { long_desc, short_desc } })
    ::continue_1::
  end
end
function _decoder.check_last_data(self)
  if logicview.truth((not logicview.truth((self["last_data"] ~= nil)))) then
    self.last_data = logicview.dict({ ["in"] = logicview.dict({  }), out = logicview.dict({  }) })
  end
end
function _decoder.handle_fastdata(self, val, ann)
  local spracc_write_desc, spracc_read_desc, bitstring, bit_sample_pos, fastdata_state, data, fastdata_bit_pos, data_pos, ss_fastdata, es_fastdata, ss_data, es_data, display_data, spracc_display_data
  spracc_write_desc = logicview.dict({ [0] = { "0", "SPrAcc: 0", "Request completion of Fastdata access" }, [1] = { "1", "SPrAcc: 1", "No effect" } })
  spracc_read_desc = logicview.dict({ [0] = { "0", "SPrAcc: 0", "Fastdata access failure" }, [1] = { "1", "SPrAcc: 1", "Successful completion of Fastdata access" } })
  bitstring = logicview.idx(val, 0)
  bit_sample_pos = logicview.idx(val, 1)
  fastdata_state = logicview.idx(bitstring, 32)
  data = bin2int(logicview.slice(bitstring, 0, 32, nil))
  fastdata_bit_pos = logicview.idx(bit_sample_pos, 32)
  data_pos = { logicview.idx(logicview.idx(bit_sample_pos, 31), 0), logicview.idx(logicview.idx(bit_sample_pos, 0), 1) }
  do
    local _lv_seq = fastdata_bit_pos
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    ss_fastdata = logicview.idx(_lv_seq, 0)
    es_fastdata = logicview.idx(_lv_seq, 1)
  end
  do
    local _lv_seq = data_pos
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    ss_data = logicview.idx(_lv_seq, 0)
    es_data = logicview.idx(_lv_seq, 1)
  end
  display_data = { ann, { logicview.pyformat("0x{:08X}", { data }, logicview.dict({})) } }
  spracc_display_data = {  }
  if logicview.truth(logicview.eq(ann, Ann.CONTROL_FIELD_IN)) then
    spracc_display_data = { ann, logicview.idx(spracc_write_desc, logicview.tointeger(fastdata_state)) }
  elseif logicview.truth(logicview.eq(ann, Ann.CONTROL_FIELD_OUT)) then
    spracc_display_data = { ann, logicview.idx(spracc_read_desc, logicview.tointeger(fastdata_state)) }
  end
  self:put_at(ss_fastdata, es_fastdata, spracc_display_data)
  self:put_at(ss_data, es_data, display_data)
end
function _decoder.handle_dr_tdi(self, val)
  local value
  value = bin2int(logicview.idx(val, 0))
  self:check_last_data()
  logicview.setidx(self.last_data, "in", logicview.dict({ ss = self.ss, es = self.es, data = val }))
  do
    local _lv_a0, _lv_a1 = self.ss, self.es
    self.pracc_state.ss = _lv_a0
    self.pracc_state.es = _lv_a1
  end
  if logicview.truth(logicview.eq(self.state, State.ADDRESS)) then
    self.pracc_state.address_in = value
  elseif logicview.truth(logicview.eq(self.state, State.DATA)) then
    self.pracc_state.data_in = value
  elseif logicview.truth(logicview.eq(self.state, State.FASTDATA)) then
    self:handle_fastdata(val, Ann.CONTROL_FIELD_IN)
  end
end
function _decoder.handle_dr_tdo(self, val)
  local value
  value = bin2int(logicview.idx(val, 0))
  self:check_last_data()
  logicview.setidx(self.last_data, "out", logicview.dict({ ss = self.ss, es = self.es, data = val }))
  if logicview.truth(logicview.eq(self.state, State.ADDRESS)) then
    self.pracc_state.address_out = value
  elseif logicview.truth(logicview.eq(self.state, State.DATA)) then
    self.pracc_state.data_out = value
  elseif logicview.truth(logicview.eq(self.state, State.FASTDATA)) then
    self:handle_fastdata(val, Ann.CONTROL_FIELD_OUT)
  end
end
function _decoder.handle_ir_tdi(self, val)
  local code, hexval, insn, s_short, s_long
  code = bin2int(logicview.idx(val, 0))
  hexval = logicview.pyformat("0x{:02X}", { code }, logicview.dict({}))
  if logicview.truth(logicview.contains(ejtag_insn, code)) then
    insn = logicview.idx(ejtag_insn, code)
    s_short = logicview.idx(insn, 0)
    s_long = logicview.add(logicview.add(logicview.add(logicview.add(logicview.add(logicview.idx(insn, 0), ": "), logicview.idx(insn, 1)), " ("), hexval), ")")
    self:put_current({ Ann.INSTRUCTION, { s_long, s_short } })
  else
    self:put_current({ Ann.INSTRUCTION, { hexval, logicview.pyformat("IR TDI ({})", { hexval }, logicview.dict({})) } })
  end
  self:select_reg(code)
end
function _decoder.handle_new_state(self, new_state)
  local reg_name, ann_index, display_data, control_bit_positions, bit_count, error_display
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(new_state, "UPDATE-DR"))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self["last_data"] ~= nil)))
  return _v
end)()) then
    return
  end
  if logicview.truth(logicview.eq(self.state, State.RESET)) then
    return
  end
  reg_name = logicview.idx(ejtag_reg, self.state)
  ann_index = logicview.add(Ann.REGISTER, self.state)
  display_data = { ann_index, { reg_name } }
  self:put_at(logicview.idx(logicview.idx(self.last_data, "in"), "ss"), logicview.idx(logicview.idx(self.last_data, "in"), "es"), display_data)
  if logicview.truth(logicview.eq(self.state, State.CONTROL)) then
    control_bit_positions = logicview.idx(logicview.idx(logicview.idx(self.last_data, "in"), "data"), 1)
    bit_count = logicview.len(control_bit_positions)
    if logicview.truth((not logicview.eq(bit_count, 32))) then
      error_display = { Ann.REGISTER, { "Error: length != 32" } }
      self:put_at(logicview.idx(logicview.idx(self.last_data, "in"), "ss"), logicview.idx(logicview.idx(self.last_data, "in"), "es"), error_display)
      return
    end
    self:parse_control_reg(Ann.CONTROL_FIELD_IN)
    self:parse_control_reg(Ann.CONTROL_FIELD_OUT)
    self:parse_pracc()
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, val
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      val = logicview.idx(_lv_seq, 1)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(cmd, "IR TDI")) then
      self:handle_ir_tdi(val)
    elseif logicview.truth(logicview.eq(cmd, "DR TDI")) then
      self:handle_dr_tdi(val)
    elseif logicview.truth(logicview.eq(cmd, "DR TDO")) then
      self:handle_dr_tdo(val)
    elseif logicview.truth(logicview.eq(cmd, "NEW STATE")) then
      self:handle_new_state(val)
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
