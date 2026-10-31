-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: mit
-- Copyright (C) 2019 Jiahao Li <reg@ljh.me>
-- Copyright (C) 2022 DreamSourceLab <support@dreamsourcelab.com>

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
local OPCODE_MASK, REG_ADDR_MASK, OPCODE_HANDLERS, ANN_RCR, ANN_RBM, ANN_WCR, ANN_WBM, ANN_BFS, ANN_BFC, ANN_SRC, ANN_DATA, ANN_REG_ADDR, ANN_WARNING, REG_ADDR_ECON1, BIT_ECON1_BSEL0, BIT_ECON1_BSEL1, Decoder, REGS
local _decoder

REGS = { { "ERDPTL", "ERDPTH", "EWRPTL", "EWRPTH", "ETXSTL", "ETXSTH", "ETXNDL", "ETXNDH", "ERXSTL", "ERXSTH", "ERXNDL", "ERXNDH", "ERXRDPTL", "ERXRDPTH", "ERXWRPTL", "ERXWRPTH", "EDMASTL", "EDMASTH", "EDMANDL", "EDMANDH", "EDMADSTL", "EDMADSTH", "EDMACSL", "EDMACSH", "—", "—", "Reserved", "EIE", "EIR", "ESTAT", "ECON2", "ECON1" }, { "EHT0", "EHT1", "EHT2", "EHT3", "EHT4", "EHT5", "EHT6", "EHT7", "EPMM0", "EPMM1", "EPMM2", "EPMM3", "EPMM4", "EPMM5", "EPMM6", "EPMM7", "EPMCSL", "EPMCSH", "—", "—", "EPMOL", "EPMOH", "Reserved", "Reserved", "ERXFCON", "EPKTCNT", "Reserved", "EIE", "EIR", "ESTAT", "ECON2", "ECON1" }, { "MACON1", "Reserved", "MACON3", "MACON4", "MABBIPG", "—", "MAIPGL", "MAIPGH", "MACLCON1", "MACLCON2", "MAMXFLL", "MAMXFLH", "Reserved", "Reserved", "Reserved", "—", "Reserved", "Reserved", "MICMD", "—", "MIREGADR", "Reserved", "MIWRL", "MIWRH", "MIRDL", "MIRDH", "Reserved", "EIE", "EIR", "ESTAT", "ECON2", "ECON1" }, { "MAADR5", "MAADR6", "MAADR3", "MAADR4", "MAADR1", "MAADR2", "EBSTSD", "EBSTCON", "EBSTCSL", "EBSTCSH", "MISTAT", "—", "—", "—", "—", "—", "—", "—", "EREVID", "—", "—", "ECOCON", "Reserved", "EFLOCON", "EPAUSL", "EPAUSH", "Reserved", "EIE", "EIR", "ESTAT", "ECON2", "ECON1" } }

OPCODE_MASK = 224
REG_ADDR_MASK = 31
OPCODE_HANDLERS = logicview.dict({ [0] = "_process_rcr", [32] = "_process_rbm", [64] = "_process_wcr", [96] = "_process_wbm", [128] = "_process_bfs", [160] = "_process_bfc", [224] = "_process_src" })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(10) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_RCR = logicview.idx(_lv_seq, 0)
  ANN_RBM = logicview.idx(_lv_seq, 1)
  ANN_WCR = logicview.idx(_lv_seq, 2)
  ANN_WBM = logicview.idx(_lv_seq, 3)
  ANN_BFS = logicview.idx(_lv_seq, 4)
  ANN_BFC = logicview.idx(_lv_seq, 5)
  ANN_SRC = logicview.idx(_lv_seq, 6)
  ANN_DATA = logicview.idx(_lv_seq, 7)
  ANN_REG_ADDR = logicview.idx(_lv_seq, 8)
  ANN_WARNING = logicview.idx(_lv_seq, 9)
end
REG_ADDR_ECON1 = 31
BIT_ECON1_BSEL0 = 1
BIT_ECON1_BSEL1 = 2
_decoder = {
  api_version = 3,
  id = "enc28j60",
  name = "ENC28J60",
  longname = "Microchip ENC28J60",
  desc = "Microchip ENC28J60 10Base-T Ethernet controller protocol.",
  license = "mit",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Embedded/industrial", "Networking" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "rcr", "Read Control Register" }, { "rbm", "Read Buffer Memory" }, { "wcr", "Write Control Register" }, { "wbm", "Write Buffer Memory" }, { "bfs", "Bit Field Set" }, { "bfc", "Bit Field Clear" }, { "src", "System Reset Command" }, { "data", "Data" }, { "reg-addr", "Register Address" }, { "warning", "Warning" } },
  annotation_rows = { { "commands", "Commands", { 0, 1, 2, 3, 4, 5, 6 } }, { "fields", "Fields", { 7, 8 } }, { "warnings", "Warnings", { 9 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.mosi = {  }
  self.miso = {  }
  self.ranges = {  }
  self.cmd_ss = nil
  self.cmd_es = nil
  self.range_ss = nil
  self.range_es = nil
  self.active = false
  self.bsel0 = nil
  self.bsel1 = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putc(self, data)
  self:put(self.cmd_ss, self.cmd_es, self.out_ann, data)
end
function _decoder.putr(self, data)
  self:put(self.range_ss, self.range_es, self.out_ann, data)
end
function _decoder._process_command(self)
  local header, opcode
  if logicview.truth(logicview.eq(logicview.len(self.mosi), 0)) then
    self.active = false
    return
  end
  header = logicview.idx(self.mosi, 0)
  opcode = (header & OPCODE_MASK)
  if logicview.truth((not logicview.contains(OPCODE_HANDLERS, opcode))) then
    self:_put_command_warning("Unknown opcode.")
    self.active = false
    return
  end
  (function() local _v = self[logicview.idx(OPCODE_HANDLERS, opcode)]; if _v == nil then return nil end; return _v end)()()
  self.active = false
end
function _decoder._get_register_name(self, reg_addr)
  local bank
  if logicview.truth((function()
  local _v
  _v = (self.bsel0 == nil)
  if logicview.truth(_v) then return _v end
  _v = (self.bsel1 == nil)
  return _v
end)()) then
    return nil
  else
    bank = logicview.add((self.bsel1 << 1), self.bsel0)
    return logicview.idx(logicview.idx(REGS, bank), reg_addr)
  end
end
function _decoder._put_register_header(self)
  local reg_addr, reg_name
  reg_addr = (logicview.idx(self.mosi, 0) & REG_ADDR_MASK)
  reg_name = self:_get_register_name(reg_addr)
  do
    local _lv_a0, _lv_a1 = self.cmd_ss, logicview.idx(logicview.idx(self.ranges, 1), 0)
    self.range_ss = _lv_a0
    self.range_es = _lv_a1
  end
  if logicview.truth((reg_name == nil)) then
    self:putr({ ANN_REG_ADDR, { "Reg Bank ? Addr {$}", "?:{$}", logicview.pymod("@%02X", reg_addr) } })
    self:putr({ ANN_WARNING, { "Warning: Register bank not known yet.", "Warning" } })
  else
    self:putr({ ANN_REG_ADDR, { logicview.pyformat("Reg {0}", { reg_name }, logicview.dict({})), logicview.pyformat("{0}", { reg_name }, logicview.dict({})) } })
    if logicview.truth((function()
  local _v
  _v = logicview.eq(reg_name, "-")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(reg_name, "Reserved")
  return _v
end)()) then
      self:putr({ ANN_WARNING, { "Warning: Invalid register accessed.", "Warning" } })
    end
  end
end
function _decoder._put_data_byte(self, data, byte_index, binary)
  if binary == nil then binary = false end
  self.range_ss = logicview.idx(logicview.idx(self.ranges, byte_index), 0)
  if logicview.truth(logicview.eq(byte_index, (logicview.len(self.mosi) - 1))) then
    self.range_es = self.cmd_es
  else
    self.range_es = logicview.idx(logicview.idx(self.ranges, logicview.add(byte_index, 1)), 0)
  end
  if logicview.truth(binary) then
    self:putr({ ANN_DATA, { logicview.pyformat("Data 0b{0:08b}", { data }, logicview.dict({})), logicview.pyformat("{0:08b}", { data }, logicview.dict({})) } })
  else
    self:putr({ ANN_DATA, { "Data {$}", "{S}", logicview.pymod("@%02X", data) } })
  end
end
function _decoder._put_command_warning(self, reason)
  self:putc({ ANN_WARNING, { logicview.pyformat("Warning: {0}", { reason }, logicview.dict({})), "Warning" } })
end
function _decoder._process_rcr(self)
  local reg_name
  self:putc({ ANN_RCR, { "Read Control Register", "RCR" } })
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.len(self.mosi), 2))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.len(self.mosi), 3))
  return _v
end)()) then
    self:_put_command_warning("Invalid command length.")
    return
  end
  self:_put_register_header()
  reg_name = self:_get_register_name((logicview.idx(self.mosi, 0) & REG_ADDR_MASK))
  if logicview.truth((reg_name == nil)) then
  else
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(reg_name, 0), "M")
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.len(self.mosi), 3))
  return _v
end)()) then
      self:_put_command_warning(logicview.add("Attempting to read a MAC/MII ", "register without using the dummy byte."))
      return
    end
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(reg_name, 0), "M"))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.len(self.mosi), 2))
  return _v
end)()) then
      self:_put_command_warning(logicview.add("Attempting to read a non-MAC/MII ", "register using the dummy byte."))
      return
    end
  end
  if logicview.truth(logicview.eq(logicview.len(self.mosi), 2)) then
    self:_put_data_byte(logicview.idx(self.miso, 1), 1)
  else
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.ranges, 1), 0), logicview.idx(logicview.idx(self.ranges, 2), 0)
      self.range_ss = _lv_a0
      self.range_es = _lv_a1
    end
    self:putr({ ANN_DATA, { "Dummy Byte", "Dummy" } })
    self:_put_data_byte(logicview.idx(self.miso, 2), 2)
  end
end
function _decoder._process_rbm(self)
  local i
  if logicview.truth((not logicview.eq(logicview.idx(self.mosi, 0), 58))) then
    self:_put_command_warning("Invalid header byte.")
    return
  end
  self:putc({ ANN_RBM, { logicview.pyformat("Read Buffer Memory: Length {0}", { (logicview.len(self.mosi) - 1) }, logicview.dict({})), "RBM" } })
  for _lv_i in logicview.range(1, logicview.len(self.miso)) do
    i = _lv_i
    self:_put_data_byte(logicview.idx(self.miso, i), i)
    ::continue_1::
  end
end
function _decoder._process_wcr(self)
  self:putc({ ANN_WCR, { "Write Control Register", "WCR" } })
  if logicview.truth((not logicview.eq(logicview.len(self.mosi), 2))) then
    self:_put_command_warning("Invalid command length.")
    return
  end
  self:_put_register_header()
  self:_put_data_byte(logicview.idx(self.mosi, 1), 1)
  if logicview.truth(logicview.eq((logicview.idx(self.mosi, 0) & REG_ADDR_MASK), REG_ADDR_ECON1)) then
    self.bsel0 = ((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL0) >> 0)
    self.bsel1 = ((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL1) >> 1)
  end
end
function _decoder._process_wbm(self)
  local i
  if logicview.truth((not logicview.eq(logicview.idx(self.mosi, 0), 122))) then
    self:_put_command_warning("Invalid header byte.")
    return
  end
  self:putc({ ANN_WBM, { logicview.pyformat("Write Buffer Memory: Length {0}", { (logicview.len(self.mosi) - 1) }, logicview.dict({})), "WBM" } })
  for _lv_i in logicview.range(1, logicview.len(self.mosi)) do
    i = _lv_i
    self:_put_data_byte(logicview.idx(self.mosi, i), i)
    ::continue_2::
  end
end
function _decoder._process_bfc(self)
  self:putc({ ANN_BFC, { "Bit Field Clear", "BFC" } })
  if logicview.truth((not logicview.eq(logicview.len(self.mosi), 2))) then
    self:_put_command_warning("Invalid command length.")
    return
  end
  self:_put_register_header()
  self:_put_data_byte(logicview.idx(self.mosi, 1), 1, true)
  if logicview.truth(logicview.eq((logicview.idx(self.mosi, 0) & REG_ADDR_MASK), REG_ADDR_ECON1)) then
    if logicview.truth((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL0)) then
      self.bsel0 = 0
    end
    if logicview.truth((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL1)) then
      self.bsel1 = 0
    end
  end
end
function _decoder._process_bfs(self)
  self:putc({ ANN_BFS, { "Bit Field Set", "BFS" } })
  if logicview.truth((not logicview.eq(logicview.len(self.mosi), 2))) then
    self:_put_command_warning("Invalid command length.")
    return
  end
  self:_put_register_header()
  self:_put_data_byte(logicview.idx(self.mosi, 1), 1, true)
  if logicview.truth(logicview.eq((logicview.idx(self.mosi, 0) & REG_ADDR_MASK), REG_ADDR_ECON1)) then
    if logicview.truth((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL0)) then
      self.bsel0 = 1
    end
    if logicview.truth((logicview.idx(self.mosi, 1) & BIT_ECON1_BSEL1)) then
      self.bsel1 = 1
    end
  end
end
function _decoder._process_src(self)
  self:putc({ ANN_SRC, { "System Reset Command", "SRC" } })
  if logicview.truth((not logicview.eq(logicview.len(self.mosi), 1))) then
    self:_put_command_warning("Invalid command length.")
    return
  end
  self.bsel0 = 0
  self.bsel1 = 0
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, data1, data2, new_cs, mosi, miso
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      data1 = logicview.idx(_lv_seq, 1)
      data2 = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      new_cs = data2
      if logicview.truth(logicview.eq(new_cs, 0)) then
        self.active = true
        self.cmd_ss = ss
        self.mosi = {  }
        self.miso = {  }
        self.ranges = {  }
      elseif logicview.truth(logicview.eq(new_cs, 1)) then
        if logicview.truth(self.active) then
          self.cmd_es = es
          self:_process_command()
        end
      end
    elseif logicview.truth(logicview.eq(ptype, "DATA")) then
      do
        local _lv_a0, _lv_a1 = data1, data2
        mosi = _lv_a0
        miso = _lv_a1
      end
      _table.insert(self.mosi, mosi)
      _table.insert(self.miso, miso)
      _table.insert(self.ranges, { ss, es })
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
