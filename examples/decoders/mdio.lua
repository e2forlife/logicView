-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: bsd
-- Copyright (C) 2016 Elias Oenal <sigrok@eliasoenal.com>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>

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
  id = "mdio",
  name = "MDIO",
  longname = "Management Data Input/Output",
  desc = "MII management bus between MAC and PHY.",
  license = "bsd",
  inputs = { "logic" },
  outputs = { "mdio" },
  tags = { "Networking" },
  channels = { logicview.dict({ id = "mdc", name = "MDC", desc = "Clock" }), logicview.dict({ id = "mdio", name = "MDIO", desc = "Data" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "show_debug_bits", desc = "Show debug bits", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "read_edge", desc = "read edge", default = "falling", values = { "rising", "falling" } }) },
  annotations = { { "bit-val", "Bit value" }, { "bit-num", "Bit number" }, { "frame", "Frame" }, { "frame-idle", "Bus idle state" }, { "frame-error", "Frame error" }, { "decode", "Decode" } },
  annotation_rows = { { "bit-val", "Bit value", { 0 } }, { "bit-num", "Bit number", { 1 } }, { "frame", "Frame", { 2, 3 } }, { "frame-error", "Frame error", { 4 } }, { "decode", "Decode", { 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.illegal_bus = 0
  self.samplenum = (-1)
  self.clause45_addr = (-1)
  self:reset_decoder_state()
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putbit(self, mdio, ss, es)
  self:put(ss, es, self.out_ann, { 0, { logicview.pymod("%d", mdio) } })
  if logicview.truth(logicview.eq(logicview.idx(self.options, "show_debug_bits"), "yes")) then
    self:put(ss, es, self.out_ann, { 1, { logicview.pymod("%d", (self.bitcount - 1)), logicview.pymod("%d", logicview.pymod((self.bitcount - 1), 10)) } })
  end
end
function _decoder.putff(self, data)
  self:put(self.ss_frame_field, self.samplenum, self.out_ann, data)
end
function _decoder.putdata(self)
  local decoded_min, is_read, decoded_ext
  self:put(self.ss_frame_field, logicview.idx(logicview.idx(self.mdiobits, 0), 2), self.out_ann, { 2, { logicview.pymod("DATA: %04X", self.data), "DATA", "D" } })
  if logicview.truth((function()
  local _v
  _v = self.clause45
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.opcode, 0)
  return _v
end)()) then
    self.clause45_addr = self.data
  end
  if logicview.truth((function()
  local _v
  _v = (self.opcode > 0)
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self.clause45))
  return _v
end)()) then
    decoded_min = ""
    if logicview.truth((function()
  local _v
  _v = self.clause45
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.clause45_addr, (-1)))
  return _v
end)()) then
      decoded_min = logicview.add(decoded_min, logicview.pyformat(str, { logicview.pymod("ADDR: %04X ", self.clause45_addr) }, logicview.dict({})))
    elseif logicview.truth(self.clause45) then
      decoded_min = logicview.add(decoded_min, logicview.pyformat(str, { "ADDR: UKWN " }, logicview.dict({})))
    end
    if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = self.clause45
  if not logicview.truth(_v) then return _v end
  _v = (self.opcode > 1)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.truth(self.clause45))
  if not logicview.truth(_v) then return _v end
  _v = self.opcode
  return _v
end)()
  return _v
end)()) then
      decoded_min = logicview.add(decoded_min, logicview.pyformat(str, { logicview.pymod("READ:  %04X", self.data) }, logicview.dict({})))
      is_read = 1
    else
      decoded_min = logicview.add(decoded_min, logicview.pyformat(str, { logicview.pymod("WRITE: %04X", self.data) }, logicview.dict({})))
      is_read = 0
    end
    decoded_ext = logicview.pyformat(str, { logicview.pymod(" %s: %02d", { (function() if logicview.truth(self.clause45) then return "PRTAD" else return "PHYAD" end end)(), self.portad }) }, logicview.dict({}))
    decoded_ext = logicview.add(decoded_ext, logicview.pyformat(str, { logicview.pymod(" %s: %02d", { (function() if logicview.truth(self.clause45) then return "DEVAD" else return "REGAD" end end)(), self.devad }) }, logicview.dict({})))
    if logicview.truth((function()
  local _v
  _v = self.ta_invalid
  if logicview.truth(_v) then return _v end
  _v = self.op_invalid
  return _v
end)()) then
      decoded_ext = logicview.add(decoded_ext, " ERROR")
    end
    self:put(self.ss_frame, logicview.idx(logicview.idx(self.mdiobits, 0), 2), self.out_ann, { 5, { logicview.add(decoded_min, decoded_ext), decoded_min } })
    self:put(self.ss_frame, logicview.idx(logicview.idx(self.mdiobits, 0), 2), self.out_python, { { logicview.truth(self.clause45), logicview.tointeger(self.clause45_addr), logicview.truth(is_read), logicview.tointeger(self.portad), logicview.tointeger(self.devad), logicview.tointeger(self.data) } })
  end
  if logicview.truth((function()
  local _v
  _v = self.clause45
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.opcode, 2)
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.clause45_addr, (-1)))
  return _v
end)()) then
    self.clause45_addr = logicview.add(self.clause45_addr, 1)
  end
end
function _decoder.reset_decoder_state(self)
  self.mdiobits = {  }
  self.bitcount = (-1)
  self.opcode = (-1)
  self.clause45 = 0
  self.ss_frame = (-1)
  self.ss_frame_field = (-1)
  self.preamble_len = 0
  self.ta_invalid = (-1)
  self.op_invalid = ""
  self.portad = (-1)
  self.portad_bits = 5
  self.devad = (-1)
  self.devad_bits = 5
  self.data = (-1)
  self.data_bits = 16
  self.state = "PRE"
  self.is_read = true
end
function _decoder.state_PRE(self, mdio)
  if logicview.truth(self.illegal_bus) then
    if logicview.truth(logicview.eq(mdio, 0)) then
      return
    else
      self.illegal_bus = 0
      self:put(self.ss_illegal, self.samplenum, self.out_ann, { 4, { "ILLEGAL BUS STATE", "ILL" } })
      self.ss_frame = self.samplenum
    end
  end
  if logicview.truth(logicview.eq(self.ss_frame, (-1))) then
    self.ss_frame = self.samplenum
  end
  if logicview.truth(logicview.eq(mdio, 1)) then
    self.preamble_len = logicview.add(self.preamble_len, 1)
  end
  if logicview.truth((self.preamble_len > 16)) then
    if logicview.truth((self.preamble_len >= logicview.add(10000, 32))) then
      self:put(self.ss_frame, logicview.idx(logicview.idx(self.mdiobits, 32), 1), self.out_ann, { 3, { logicview.pymod("IDLE #%d", (self.preamble_len - 32)), "IDLE", "I" } })
      self.ss_frame = logicview.idx(logicview.idx(self.mdiobits, 32), 1)
      self.preamble_len = 32
      do
        local _lv_t = self.mdiobits
        local _lv_head = logicview.slice(_lv_t, 0, 33, 1)
        local _lv_tail = logicview.slice(_lv_t, (-1), nil, 1)
        logicview.list_clear(_lv_t)
        logicview.extend(_lv_t, _lv_head)
        logicview.extend(_lv_t, _lv_tail)
      end
    end
    if logicview.truth(logicview.eq(mdio, 0)) then
      if logicview.truth((self.preamble_len < 32)) then
        self.ss_frame = logicview.idx(logicview.idx(self.mdiobits, self.preamble_len), 1)
        self:put(self.ss_frame, self.samplenum, self.out_ann, { 4, { "SHORT PREAMBLE", "SHRT PRE" } })
      elseif logicview.truth((self.preamble_len > 32)) then
        self.ss_frame = logicview.idx(logicview.idx(self.mdiobits, 32), 1)
        self:put(logicview.idx(logicview.idx(self.mdiobits, self.preamble_len), 1), logicview.idx(logicview.idx(self.mdiobits, 32), 1), self.out_ann, { 3, { logicview.pymod("IDLE #%d", (self.preamble_len - 32)), "IDLE", "I" } })
        self.preamble_len = 32
      else
        self.ss_frame = logicview.idx(logicview.idx(self.mdiobits, 32), 1)
      end
      self:put(self.ss_frame, self.samplenum, self.out_ann, { 2, { logicview.pymod("PRE #%d", self.preamble_len), "PRE", "P" } })
      self.ss_frame_field = self.samplenum
      self.state = "ST"
    end
  elseif logicview.truth(logicview.eq(mdio, 0)) then
    self.ss_illegal = self.ss_frame
    self.illegal_bus = 1
  end
end
function _decoder.state_ST(self, mdio)
  if logicview.truth(logicview.eq(mdio, 0)) then
    self.clause45 = 1
  end
  self.state = "OP"
end
function _decoder.state_OP(self, mdio)
  local st
  if logicview.truth(logicview.eq(self.opcode, (-1))) then
    if logicview.truth(self.clause45) then
      st = { "ST (Clause 45)", "ST 45" }
    else
      st = { "ST (Clause 22)", "ST 22" }
    end
    self:putff({ 2, logicview.add(st, { "ST", "S" }) })
    self.ss_frame_field = self.samplenum
    if logicview.truth(mdio) then
      self.opcode = 2
    else
      self.opcode = 0
    end
  elseif logicview.truth(self.clause45) then
    self.state = "PRTAD"
    self.opcode = logicview.add(self.opcode, mdio)
  else
    if logicview.truth(logicview.eq(mdio, self.opcode)) then
      self.op_invalid = "invalid for Clause 22"
    end
    self.state = "PRTAD"
  end
end
function _decoder.state_PRTAD(self, mdio)
  local op
  if logicview.truth(logicview.eq(self.portad, (-1))) then
    self.portad = 0
    if logicview.truth(self.clause45) then
      if logicview.truth(logicview.eq(self.opcode, 0)) then
        op = { "OP: ADDR", "OP: A" }
      elseif logicview.truth(logicview.eq(self.opcode, 1)) then
        op = { "OP: WRITE", "OP: W" }
        self.is_read = false
      elseif logicview.truth(logicview.eq(self.opcode, 2)) then
        op = { "OP: READINC", "OP: RI" }
        self.is_read = true
      elseif logicview.truth(logicview.eq(self.opcode, 3)) then
        op = { "OP: READ", "OP: R" }
        self.is_read = true
      end
    else
      op = (function() if logicview.truth(self.opcode) then return { "OP: READ", "OP: R" } else return { "OP: WRITE", "OP: W" } end end)()
      self.is_read = (function() if logicview.truth(self.opcode) then return true else return false end end)()
    end
    self:putff({ 2, logicview.add(op, { "OP", "O" }) })
    if logicview.truth(self.op_invalid) then
      self:putff({ 4, { logicview.pymod("OP %s", self.op_invalid), "OP", "O" } })
    end
    self.ss_frame_field = self.samplenum
  end
  self.portad_bits = (self.portad_bits - 1)
  self.portad = (self.portad | (mdio << self.portad_bits))
  if logicview.truth((not logicview.truth(self.portad_bits))) then
    self.state = "DEVAD"
  end
end
function _decoder.state_DEVAD(self, mdio)
  local prtad
  if logicview.truth(logicview.eq(self.devad, (-1))) then
    self.devad = 0
    if logicview.truth(self.clause45) then
      prtad = { logicview.pymod("PRTAD: %02d", self.portad), "PRT", "P" }
    else
      prtad = { logicview.pymod("PHYAD: %02d", self.portad), "PHY", "P" }
    end
    self:putff({ 2, prtad })
    self.ss_frame_field = self.samplenum
  end
  self.devad_bits = (self.devad_bits - 1)
  self.devad = (self.devad | (mdio << self.devad_bits))
  if logicview.truth((not logicview.truth(self.devad_bits))) then
    self.state = "TA"
  end
end
function _decoder.state_TA(self, mdio)
  local regad
  if logicview.truth(logicview.eq(self.ta_invalid, (-1))) then
    self.ta_invalid = ""
    if logicview.truth(self.clause45) then
      regad = { logicview.pymod("DEVAD: %02d", self.devad), "DEV", "D" }
    else
      regad = { logicview.pymod("REGAD: %02d", self.devad), "REG", "R" }
    end
    self:putff({ 2, regad })
    self.ss_frame_field = self.samplenum
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(mdio, 1))
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (function()
  local _v
  _v = self.clause45
  if not logicview.truth(_v) then return _v end
  _v = (self.opcode < 2)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = (not logicview.truth(self.clause45))
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.opcode, 0)
  return _v
end)()
  return _v
end)()
  return _v
end)()) then
      self.ta_invalid = " invalid (bit1)"
    end
  else
    if logicview.truth((not logicview.eq(mdio, 0))) then
      if logicview.truth(self.ta_invalid) then
        self.ta_invalid = " invalid (bit1 and bit2)"
      else
        self.ta_invalid = " invalid (bit2)"
      end
    end
    self.state = "DATA"
  end
end
function _decoder.state_DATA(self, mdio)
  if logicview.truth(logicview.eq(self.data, (-1))) then
    self.data = 0
    self:putff({ 2, { "TA", "T" } })
    if logicview.truth(self.ta_invalid) then
      self:putff({ 4, { logicview.pymod("TA%s", self.ta_invalid), "TA", "T" } })
    end
    self.ss_frame_field = self.samplenum
  end
  self.data_bits = (self.data_bits - 1)
  self.data = (self.data | (mdio << self.data_bits))
  if logicview.truth((not logicview.truth(self.data_bits))) then
    logicview.setidx(logicview.idx(self.mdiobits, 0), 2, logicview.add(logicview.idx(logicview.idx(self.mdiobits, 0), 1), self:quartile_cycle_length()))
    self.bitcount = logicview.add(self.bitcount, 1)
    self:putbit(logicview.idx(logicview.idx(self.mdiobits, 0), 0), logicview.idx(logicview.idx(self.mdiobits, 0), 1), logicview.idx(logicview.idx(self.mdiobits, 0), 2))
    self:putdata()
    self:reset_decoder_state()
  end
end
function _decoder.process_state(self, argument, mdio)
  local method_name, method
  method_name = logicview.add("state_", _tostring(argument))
  method = (function() local _v = self[method_name]; if _v == nil then return nil end; return _v end)()
  return method(mdio)
end
function _decoder.quartile_cycle_length(self)
  local bitlen, i
  bitlen = {  }
  for _lv_i in logicview.range(1, 49) do
    i = _lv_i
    _table.insert(bitlen, (logicview.idx(logicview.idx(self.mdiobits, i), 2) - logicview.idx(logicview.idx(self.mdiobits, i), 1)))
    ::continue_1::
  end
  bitlen = logicview.sorted(bitlen, nil)
  return logicview.idx(bitlen, 12)
end
function _decoder.handle_bit(self, mdio)
  self.bitcount = logicview.add(self.bitcount, 1)
  logicview.list_insert(self.mdiobits, 0, { mdio, self.samplenum, (-1) })
  if logicview.truth((self.bitcount > 0)) then
    logicview.setidx(logicview.idx(self.mdiobits, 1), 2, self.samplenum)
    self:putbit(logicview.idx(logicview.idx(self.mdiobits, 1), 0), logicview.idx(logicview.idx(self.mdiobits, 1), 1), logicview.idx(logicview.idx(self.mdiobits, 1), 2))
  end
  self:process_state(self.state, mdio)
end
function _decoder.decode(self)
  local find_flags, flag_dex, read_edge, mdc, mdio
  find_flags = { logicview.dict({ [0] = "r" }), logicview.dict({ [0] = "f" }) }
  flag_dex = 0
  read_edge = logicview.idx(logicview.idx(self.options, "read_edge"), 0)
  while true do
    do
      local _lv_seq = self:wait(logicview.idx(find_flags, flag_dex))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      mdc = logicview.idx(_lv_seq, 0)
      mdio = logicview.idx(_lv_seq, 1)
    end
    self:handle_bit(mdio)
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "DATA")
  if not logicview.truth(_v) then return _v end
  _v = self.is_read
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(read_edge, "f")
  return _v
end)()) then
      flag_dex = 1
    else
      flag_dex = 0
    end
    ::continue_2::
  end
end

return _decoder
