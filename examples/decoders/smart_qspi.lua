-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011 Gareth McMullin <gareth@blacksphere.co.nz>
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local namedtuple, floor, ceil, Enum, Data, spi_mode, process_enum, process_text, process_mode, process_info, READ_ADDRESS, READ_3B_ADDRESS, READ_4B_ADDRESS, READ_ADDRESS_DUAL, READ_3B_ADDRESS_DUAL, READ_4B_ADDRESS_DUAL, READ_ADDRESS_QUAD, READ_3B_ADDRESS_QUAD, READ_4B_ADDRESS_QUAD, READ_BYTE_SINGLE, READ_BYTE_DUAL, READ_BYTE_QUAD, READ_BYTE_SINGLE_CONTINUOUS, READ_BYTE_DUAL_CONTINUOUS, READ_BYTE_QUAD_CONTINUOUS, READ_MODE_BITS_DUAL, READ_MODE_BITS_QUAD, WRITE_BYTE_SINGLE, WRITE_BYTE_QUAD_CONTINUOUS, DUMMY_CYCLE, DUMMY_CYCLE_8BIT, DUMMY_CYCLE_8BIT_QUAD, command, ChannelError, Decoder
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
namedtuple = collections.namedtuple
floor = _math.floor
ceil = _math.ceil
Data = (function() local _f = { "ss", "es", "val" }; if _type(_f) == 'string' then _f = logicview.split(_f, ' ') end; return logicview.namedtuple(_f) end)()
spi_mode = logicview.dict({ [logicview.tkey(0, 0)] = 0, [logicview.tkey(0, 1)] = 1, [logicview.tkey(1, 0)] = 2, [logicview.tkey(1, 1)] = 3 })
process_enum = {}
process_enum.__index = process_enum
process_enum.COMMAND = 0
process_enum.WRITE_BYTE = 1
process_enum.WRITE_BYTE_CONTINUOUS = 2
process_enum.READ_BYTE = 3
process_enum.READ_BYTE_CONTINUOUS = 4
process_enum.CONTINUOUS_READ_MODE_BITS = 5
process_enum.ADDRESS_BY_MODE = 6
process_enum.ADDRESS_24BIT = 7
process_enum.ADDRESS_32BIT = 8
process_enum.DUMMY_BY_MODE = 9
process_enum.DUMMY_8BIT = 10
process_enum.DUMMY_32BIT = 11
process_enum.DUMMY_40BIT = 12
process_text = logicview.dict({ [process_enum.COMMAND] = { "Command", "CMD" }, [process_enum.WRITE_BYTE] = { "Write Data", "WD" }, [process_enum.WRITE_BYTE_CONTINUOUS] = { "Write Data", "WD" }, [process_enum.READ_BYTE] = { "Read Data", "RD" }, [process_enum.READ_BYTE_CONTINUOUS] = { "Read Data", "RD" }, [process_enum.ADDRESS_24BIT] = { "24-Bit Address", "AD" }, [process_enum.ADDRESS_32BIT] = { "32-Bit Address", "AD" }, [process_enum.CONTINUOUS_READ_MODE_BITS] = { "Continuous Read Mode bits", "M" } })
process_mode = {}
process_mode.__index = process_mode
process_mode.SINGLE = 0
process_mode.DUAL = 1
process_mode.QUAD = 2
process_info = {}
process_info.__index = process_info
function process_info.__init__(self, enum, mode)
  self.enum = enum
  self.mode = mode
end
function process_info.__eq(self, other)
  if logicview.truth(logicview.is_a(other, self.__class__)) then
    return (function()
  local _v
  _v = logicview.eq(self.enum, other.enum)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.mode, other.mode)
  return _v
end)()
  end
  return false
end
function process_info.new(...)
  local self = _setmetatable({}, process_info)
  process_info.__init__(self, ...)
  return self
end
READ_ADDRESS = process_info.new(process_enum.ADDRESS_BY_MODE, process_mode.SINGLE)
READ_3B_ADDRESS = process_info.new(process_enum.ADDRESS_24BIT, process_mode.SINGLE)
READ_4B_ADDRESS = process_info.new(process_enum.ADDRESS_32BIT, process_mode.SINGLE)
READ_ADDRESS_DUAL = process_info.new(process_enum.ADDRESS_BY_MODE, process_mode.DUAL)
READ_3B_ADDRESS_DUAL = process_info.new(process_enum.ADDRESS_24BIT, process_mode.DUAL)
READ_4B_ADDRESS_DUAL = process_info.new(process_enum.ADDRESS_32BIT, process_mode.DUAL)
READ_ADDRESS_QUAD = process_info.new(process_enum.ADDRESS_BY_MODE, process_mode.QUAD)
READ_3B_ADDRESS_QUAD = process_info.new(process_enum.ADDRESS_24BIT, process_mode.DUAL)
READ_4B_ADDRESS_QUAD = process_info.new(process_enum.ADDRESS_32BIT, process_mode.QUAD)
READ_BYTE_SINGLE = process_info.new(process_enum.READ_BYTE, process_mode.SINGLE)
READ_BYTE_DUAL = process_info.new(process_enum.READ_BYTE, process_mode.DUAL)
READ_BYTE_QUAD = process_info.new(process_enum.READ_BYTE, process_mode.QUAD)
READ_BYTE_SINGLE_CONTINUOUS = process_info.new(process_enum.READ_BYTE_CONTINUOUS, process_mode.SINGLE)
READ_BYTE_DUAL_CONTINUOUS = process_info.new(process_enum.READ_BYTE_CONTINUOUS, process_mode.DUAL)
READ_BYTE_QUAD_CONTINUOUS = process_info.new(process_enum.READ_BYTE_CONTINUOUS, process_mode.QUAD)
READ_MODE_BITS_DUAL = process_info.new(process_enum.CONTINUOUS_READ_MODE_BITS, process_mode.DUAL)
READ_MODE_BITS_QUAD = process_info.new(process_enum.CONTINUOUS_READ_MODE_BITS, process_mode.QUAD)
WRITE_BYTE_SINGLE = process_info.new(process_enum.WRITE_BYTE, process_mode.SINGLE)
WRITE_BYTE_QUAD_CONTINUOUS = process_info.new(process_enum.WRITE_BYTE_CONTINUOUS, process_mode.QUAD)
DUMMY_CYCLE = process_info.new(process_enum.DUMMY_BY_MODE, process_mode.SINGLE)
DUMMY_CYCLE_8BIT = process_info.new(process_enum.DUMMY_8BIT, process_mode.SINGLE)
DUMMY_CYCLE_8BIT_QUAD = process_info.new(process_enum.DUMMY_8BIT, process_mode.QUAD)
command = logicview.dict({ [6] = { "Write Enable", "WREN", {  } }, [4] = { "Write Disable", "WRDI", {  } }, [80] = { "Write Enable for Volatile Status Register", "WRENFVSR", {  } }, [5] = { "Read Status Register", "RDSR", { READ_BYTE_SINGLE } }, [53] = { "Read Status Register", "RDSR", { READ_BYTE_SINGLE } }, [21] = { "Read Status Register", "RDSR", { READ_BYTE_SINGLE } }, [1] = { "Write Status Register", "WRSR", { WRITE_BYTE_SINGLE } }, [49] = { "Write Status Register", "WRSR", { WRITE_BYTE_SINGLE } }, [17] = { "Write Status Register", "WRSR", { WRITE_BYTE_SINGLE } }, [200] = { "Read Extended Register", "RER", { READ_BYTE_SINGLE } }, [197] = { "Write Extended Register", "WER", { WRITE_BYTE_SINGLE } }, [3] = { "Read Data Bytes", "READ", { READ_ADDRESS, READ_BYTE_SINGLE_CONTINUOUS } }, [19] = { "Read Data Bytes", "4READ", { READ_4B_ADDRESS, READ_BYTE_SINGLE_CONTINUOUS } }, [11] = { "Read Data Bytes at Higher Speed", "Fast Read", { READ_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_SINGLE_CONTINUOUS } }, [12] = { "Read Data Bytes at Higher Speed", "4Fast Read", { READ_4B_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_SINGLE_CONTINUOUS } }, [59] = { "Dual Output Fast Read", "DOFR", { READ_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_DUAL_CONTINUOUS } }, [60] = { "Dual Output Fast Read", "4DOFR", { READ_4B_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_DUAL_CONTINUOUS } }, [107] = { "Quad Output Fast Read", "QOFR", { READ_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_QUAD_CONTINUOUS } }, [108] = { "Quad Output Fast Read", "4QOFR", { READ_4B_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_QUAD_CONTINUOUS } }, [187] = { "Dual I/O Fast Read", "DIOFR", { READ_ADDRESS_DUAL, READ_MODE_BITS_DUAL, READ_BYTE_DUAL_CONTINUOUS } }, [188] = { "Dual I/O Fast Read", "4DIOFR", { READ_4B_ADDRESS_DUAL, READ_MODE_BITS_DUAL, READ_BYTE_DUAL_CONTINUOUS } }, [235] = { "Quad I/O Fast Read", "QIOFR", { READ_ADDRESS_QUAD, READ_MODE_BITS_QUAD, DUMMY_CYCLE_8BIT_QUAD, DUMMY_CYCLE_8BIT_QUAD, READ_BYTE_QUAD_CONTINUOUS } }, [236] = { "Quad I/O Fast Read", "4QIOFR", { READ_4B_ADDRESS_QUAD, READ_MODE_BITS_QUAD, DUMMY_CYCLE_8BIT_QUAD, DUMMY_CYCLE_8BIT_QUAD, READ_BYTE_QUAD_CONTINUOUS } }, [119] = { "Set Burst with Wrap", "SBWW", { DUMMY_CYCLE_8BIT_QUAD, DUMMY_CYCLE_8BIT_QUAD, DUMMY_CYCLE_8BIT_QUAD, READ_BYTE_QUAD_CONTINUOUS } }, [2] = { "Page Program", "PP", logicview.add({ READ_ADDRESS }, logicview.mul({ WRITE_BYTE_SINGLE }, 256)) }, [18] = { "Page Program", "4PP", logicview.add({ READ_4B_ADDRESS }, logicview.mul({ WRITE_BYTE_SINGLE }, 256)) }, [50] = { "Quad Page Program", "QPP", logicview.add({ READ_ADDRESS }, { WRITE_BYTE_QUAD_CONTINUOUS }) }, [52] = { "Quad Page Program", "4QPP", logicview.add({ READ_4B_ADDRESS }, { WRITE_BYTE_QUAD_CONTINUOUS }) }, [32] = { "Sector Erase", "SE", { READ_ADDRESS } }, [33] = { "Sector Erase", "4SE", { READ_4B_ADDRESS } }, [82] = { "32KB Block Erase", "BE32", { READ_ADDRESS } }, [92] = { "32KB Block Erase", "4BE32", { READ_4B_ADDRESS } }, [216] = { "64KB Block Erase", "BE64", { READ_ADDRESS } }, [220] = { "64KB Block Erase", "4BE64", { READ_4B_ADDRESS } }, [96] = { "Chip Erase", "CE", {  } }, [199] = { "Chip Erase", "CE", {  } }, [185] = { "Deep Power-Down", "DP", {  } }, [75] = { "Read Unique ID", "RUID", { DUMMY_CYCLE, READ_BYTE_SINGLE_CONTINUOUS } }, [183] = { "Enter 4-Byte Address Mode", "EN4BADM", {  } }, [233] = { "Exit 4-Byte Address Mode", "EX4BADM", {  } }, [48] = { "Clear SR Flags", "CLSRF", {  } }, [171] = { "Release from Deep Power-Down and Read Device ID", "RDI", {  } }, [144] = { "Read Manufacture ID/ Device ID", "REMS", { READ_3B_ADDRESS, READ_BYTE_SINGLE, READ_BYTE_SINGLE } }, [146] = { "Read Manufacture ID/ Device ID Dual I/O", "REMS", { READ_3B_ADDRESS_DUAL, READ_MODE_BITS_DUAL, READ_BYTE_DUAL_CONTINUOUS } }, [148] = { "Read Manufacture ID/ Device ID Quad I/O", "REMS", { READ_3B_ADDRESS_QUAD, READ_MODE_BITS_QUAD, DUMMY_CYCLE_8BIT_QUAD, DUMMY_CYCLE_8BIT_QUAD, READ_BYTE_QUAD_CONTINUOUS } }, [159] = { "Read Identification", "RDID", { READ_BYTE_SINGLE_CONTINUOUS } }, [117] = { "Program/Erase Suspend", "PES", {  } }, [122] = { "Program/Erase Resume", "PER", {  } }, [68] = { "Erase Security Registers", "ESR", { READ_ADDRESS } }, [66] = { "Program Security Registers", "PSR", logicview.add({ READ_ADDRESS }, logicview.mul({ WRITE_BYTE_SINGLE }, 256)) }, [72] = { "Read Security Registers", "RSR", { READ_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_SINGLE_CONTINUOUS } }, [102] = { "Enable Reset", "ENRE", {  } }, [153] = { "Reset", "RE", {  } }, [90] = { "Read Serial Flash Discoverable Parameter", "RSFDP", { READ_3B_ADDRESS, DUMMY_CYCLE_8BIT, READ_BYTE_SINGLE_CONTINUOUS } } })
ChannelError = function(msg)
  local text = _tostring(msg or "ChannelError")
  return _setmetatable({ _exc = "ChannelError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "smart_qspi",
  name = "Smart QSPI",
  longname = "Quad Serial Peripheral Interface",
  desc = "Full-duplex, synchronous, serial bus.compatible with Dual SPI and Quad SPI interfaces.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "spi" },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "clk", name = "CLK", desc = "Clock" }), logicview.dict({ id = "io0", name = "IO0", desc = "Data i/o 0" }) },
  optional_channels = { logicview.dict({ id = "io1", name = "IO1", desc = "Data i/o 1" }), logicview.dict({ id = "io2", name = "IO2", desc = "Data i/o 2" }), logicview.dict({ id = "io3", name = "IO3", desc = "Data i/o 3" }), logicview.dict({ id = "cs", name = "CS#", desc = "Chip-select" }) },
  options = { logicview.dict({ id = "cs_polarity", desc = "CS# polarity", default = "active-low", values = { "active-low", "active-high" } }), logicview.dict({ id = "cpol", desc = "Clock polarity (CPOL)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "cpha", desc = "Clock phase (CPHA)", default = 0, values = { 0, 1 } }), logicview.dict({ id = "bitorder", desc = "Bit order", default = "msb-first", values = { "msb-first", "lsb-first" } }), logicview.dict({ id = "ads", desc = "Adress Mode", default = "24-Bit Address", values = { "32-Bit Address", "24-Bit Address" } }), logicview.dict({ id = "frame", desc = "Frame Decoder", default = "no", values = { "yes", "no" } }), logicview.dict({ id = "twolinesmode", desc = "TwoLinesMode", default = "spi", values = { "spi", "dspi", "qspi" } }), logicview.dict({ id = "invalidlevel", desc = "Keep high or low as invalid", default = "both", values = { "both", "low", "high" } }) },
  annotations = { { "6", "data-transfer", "data transfer" }, { "108", "Quad data", "Q-Data" }, { "108", "Dual data", "D-Data" }, { "106", "d0", "IO0 data" }, { "106", "d1", "IO1 data" }, { "106", "d2", "IO2 data" }, { "106", "d3", "IO3 data" }, { "1000", "other", "Human-readable warnings" } },
  annotation_rows = { { "data-transfer", "data transfer", { 0 } }, { "Quad data", "Q-Data", { 1 } }, { "Dual data", "D-Data", { 2 } }, { "d0", "D0", { 3 } }, { "d1", "D1", { 4 } }, { "d2", "D2", { 5 } }, { "d3", "D3", { 6 } }, { "Other", "Other", { 7 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.bitcount = 0
  self.data = 0
  self.bits = {  }
  self.io0bits = {  }
  self.io1bits = {  }
  self.io2bits = {  }
  self.io3bits = {  }
  self.io0bytes = {  }
  self.io1bytes = {  }
  self.io2bytes = {  }
  self.io3bytes = {  }
  self.io0data = 0
  self.io1data = 0
  self.io2data = 0
  self.io3data = 0
  self.command = 0
  self.state_count = 0
  self.ads = false
  self.diagram = {  }
  self.ss = 0
  self.count = 0
  self.bits_data = 0
  self.ss_block = (-1)
  self.samplenum = (-1)
  self.ss_transfer = (-1)
  self.cs_was_deasserted = false
  do
    local _lv_chain = nil
    self.have_cs = _lv_chain
    self.have_io1 = _lv_chain
    self.have_io3 = _lv_chain
  end
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.out_bitrate = self:register(logicview.OUTPUT_META, "Bitrate")
  self.bw = logicview.floordiv(logicview.add(8, 7), 8)
  self.spiModeSet = _string.lower(logicview.idx(self.options, "twolinesmode"))
  self.invalidlevelSet = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "invalidlevel"), "high")) then return 255 else return 0 end end)()
  self.ads = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "ads"), "24-Bit Address")) then return false else return true end end)()
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.bit_width = ((_tonumber(self.samplerate) or 0) / (_tonumber(115200) or 0))
  end
end
function _decoder.putw(self, data)
  self:put(self.ss_block, self.samplenum, self.out_ann, data)
end
function _decoder.putgse(self, ss, es, data)
  self:put(ss, es, self.out_ann, data)
end
function _decoder.putg(self, data)
  local s, halfbit
  do
    local _lv_a0, _lv_a1 = self.samplenum, (self.bit_width / 2.0)
    s = _lv_a0
    halfbit = _lv_a1
  end
  self:put((s - floor(halfbit)), logicview.add(s, ceil(halfbit)), self.out_ann, data)
end
function _decoder.puttext(self, ss, es, state, data)
  self:put(ss, es, self.out_ann, { 0, { logicview.pymod("%s : 0x%02x", { logicview.idx(logicview.idx(process_text, state), 0), data }), logicview.pymod("%s : 0x%02x", { logicview.idx(logicview.idx(process_text, state), 1), data }), logicview.pymod("0x%02X", data) } })
end
function _decoder.putdummy(self, ss, es)
  self:put(ss, es, self.out_ann, { 0, { "Dummy Cycles", "Dummy", "D" } })
end
function _decoder.putcmd(self, ss, es)
  self:put(ss, es, self.out_ann, { 0, { logicview.pymod("%s(0x%02x)", { logicview.idx(logicview.idx(command, self.io0data), 0), self.io0data }), logicview.pymod("%s(0x%02x)", { logicview.idx(logicview.idx(command, self.io0data), 1), self.io0data }), logicview.pymod("%s", logicview.idx(logicview.idx(command, self.io0data), 1)) } })
end
function _decoder.checkinvalidlevel(self, data)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "invalidlevel"), "both")) then
    return (function()
  local _v
  _v = logicview.eq(data, 255)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(data, 0)
  return _v
end)()
  elseif logicview.truth(logicview.eq(logicview.idx(self.options, "invalidlevel"), "high")) then
    return logicview.eq(data, 255)
  else
    return logicview.eq(data, 0)
  end
end
function _decoder.putdata(self, frame)
  local data0, data1, data2, data3, ss, es, bo, spiMode, qdata, ddata, i, j, qss, qes, dataTemp, dss, des, cur_state, size, origin_data
  data0 = self.io0data
  data1 = self.io1data
  data2 = (function() if logicview.truth(self.have_io3) then return self.io2data else return nil end end)()
  data3 = (function() if logicview.truth(self.have_io3) then return self.io3data else return nil end end)()
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.io0bits, (-1)), 1), logicview.idx(logicview.idx(self.io0bits, 0), 2)
    ss = _lv_a0
    es = _lv_a1
  end
  if logicview.truth(frame) then
    if logicview.truth(self.have_io3) then
      _table.insert(self.io2bytes, Data())
      _table.insert(self.io3bytes, Data())
    end
    if logicview.truth(self.have_io1) then
      _table.insert(self.io1bytes, Data())
    end
    _table.insert(self.io0bytes, Data())
  end
  bo = logicview.idx(self.options, "bitorder")
  if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = (function()
  local _v
  _v = self:checkinvalidlevel(data2)
  if logicview.truth(_v) then return _v end
  _v = self:checkinvalidlevel(data3)
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = self.have_io3
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = self:checkinvalidlevel(data1)
  if not logicview.truth(_v) then return _v end
  _v = self.have_io1
  return _v
end)()
  return _v
end)()) then
    spiMode = self.spiModeSet
  elseif logicview.truth(self.have_io3) then
    spiMode = "qspi"
  else
    spiMode = "spi"
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(spiMode, "qspi")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(spiMode, "dspi")
  return _v
end)()) then
    qdata = {  }
    ddata = {  }
    if logicview.truth((function()
  local _v
  _v = self.have_io1
  if not logicview.truth(_v) then return _v end
  _v = self.have_io3
  return _v
end)()) then
      for _lv_i in logicview.range(4) do
        i = _lv_i
        self.data = 0
        for _lv_i in logicview.range(2) do
          j = _lv_i
          self.data = (self.data | logicview.idx(logicview.idx(self.io3bits, (((-1) - logicview.mul(i, 2)) - j)), 0))
          self.data = (self.data << 1)
          self.data = (self.data | logicview.idx(logicview.idx(self.io2bits, (((-1) - logicview.mul(i, 2)) - j)), 0))
          self.data = (self.data << 1)
          self.data = (self.data | logicview.idx(logicview.idx(self.io1bits, (((-1) - logicview.mul(i, 2)) - j)), 0))
          self.data = (self.data << 1)
          self.data = (self.data | logicview.idx(logicview.idx(self.io0bits, (((-1) - logicview.mul(i, 2)) - j)), 0))
          if logicview.truth((j < 1)) then
            self.data = (self.data << 1)
          end
          ::continue_2::
        end
        do
          local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.io0bits, ((-1) - logicview.mul(i, 2))), 1), logicview.idx(logicview.idx(self.io0bits, ((-2) - logicview.mul(i, 2))), 2)
          qss = _lv_a0
          qes = _lv_a1
        end
        if logicview.truth((not logicview.truth(logicview.eq(bo, "msb-first")))) then
          dataTemp = (((240 & self.data) >> 4) | ((15 & self.data) << 4))
          self.data = dataTemp
        end
        _table.insert(qdata, { self.data, qss, qes })
        self:put(qss, qes, self.out_ann, { 1, { logicview.pymod("@%02X", self.data) } })
        ::continue_1::
      end
    end
    if logicview.truth(self.have_io1) then
      for _lv_i in logicview.range(2) do
        i = _lv_i
        self.data = 0
        for _lv_i in logicview.range(4) do
          j = _lv_i
          self.data = (self.data | logicview.idx(logicview.idx(self.io1bits, (((-1) - logicview.mul(i, 4)) - j)), 0))
          self.data = (self.data << 1)
          self.data = (self.data | logicview.idx(logicview.idx(self.io0bits, (((-1) - logicview.mul(i, 4)) - j)), 0))
          if logicview.truth((j < 3)) then
            self.data = (self.data << 1)
          end
          ::continue_4::
        end
        do
          local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.io0bits, ((-1) - logicview.mul(i, 4))), 1), logicview.idx(logicview.idx(self.io0bits, ((-4) - logicview.mul(i, 4))), 2)
          dss = _lv_a0
          des = _lv_a1
        end
        if logicview.truth((not logicview.truth(logicview.eq(bo, "msb-first")))) then
          dataTemp = (((240 & self.data) >> 4) | ((15 & self.data) << 4))
          self.data = dataTemp
        end
        _table.insert(ddata, { self.data, dss, des })
        self:put(dss, des, self.out_ann, { 2, { logicview.pymod("@%02X", self.data) } })
        ::continue_3::
      end
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.command, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.contains(command, self.io0data)
  return _v
end)()) then
      self:putcmd(ss, es)
      if logicview.truth(logicview.eq(self.io0data, 183)) then
        self.ads = true
      elseif logicview.truth(logicview.eq(self.io0data, 233)) then
        self.ads = false
      end
      if logicview.truth((not logicview.eq(logicview.len(logicview.idx(logicview.idx(command, self.io0data), 2)), 0))) then
        self.command = self.io0data
        self.diagram = logicview.idx(logicview.idx(command, self.command), 2)
      end
    elseif logicview.truth((not logicview.eq(self.command, 0))) then
      cur_state = logicview.idx(self.diagram, self.state_count)
      do
        local _lv_a0, _lv_a1 = 0, 1
        i = _lv_a0
        size = _lv_a1
      end
      if logicview.truth(logicview.eq(cur_state.mode, process_mode.DUAL)) then
        size = 2
      elseif logicview.truth(logicview.eq(cur_state.mode, process_mode.QUAD)) then
        size = 4
      end
      while logicview.truth((i < size)) do
        if logicview.truth(logicview.eq(size, 1)) then
          if logicview.truth((function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.READ_BYTE)
  if not logicview.truth(_v) then return _v end
  _v = self.have_io1
  return _v
end)()) then
            origin_data = { (self.io1data & 255), ss, es }
          else
            origin_data = { (self.io0data & 255), ss, es }
          end
        elseif logicview.truth(logicview.eq(size, 2)) then
          origin_data = logicview.idx(ddata, i)
          logicview.setidx(origin_data, 0, (logicview.idx(origin_data, 0) & 255))
        elseif logicview.truth(logicview.eq(size, 4)) then
          origin_data = logicview.idx(qdata, i)
          logicview.setidx(origin_data, 0, (logicview.idx(origin_data, 0) & 255))
        end
        i = logicview.add(i, 1)
        if logicview.truth((function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_BY_MODE)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_24BIT)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_32BIT)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.DUMMY_BY_MODE)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.DUMMY_8BIT)
  return _v
end)()) then
          if logicview.truth(logicview.eq(cur_state.enum, process_enum.ADDRESS_BY_MODE)) then
            cur_state.enum = (function() if logicview.truth(logicview.eq(self.ads, false)) then return process_enum.ADDRESS_24BIT else return process_enum.ADDRESS_32BIT end end)()
          elseif logicview.truth(logicview.eq(cur_state.enum, process_enum.DUMMY_BY_MODE)) then
            cur_state.enum = (function() if logicview.truth(logicview.eq(self.ads, false)) then return process_enum.DUMMY_32BIT else return process_enum.DUMMY_40BIT end end)()
          end
          if logicview.truth(logicview.eq(self.count, 0)) then
            self.ss = ss
          end
          self.bits_data = (self.bits_data | logicview.idx(origin_data, 0))
          self.count = logicview.add(self.count, 1)
          if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_24BIT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.count, 3)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_32BIT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.count, 4)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.DUMMY_8BIT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.count, 1)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.DUMMY_32BIT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.count, 4)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.DUMMY_40BIT)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.count, 5)
  return _v
end)()
  return _v
end)()) then
            if logicview.truth((function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_24BIT)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.ADDRESS_32BIT)
  return _v
end)()) then
              self:puttext(self.ss, logicview.idx(origin_data, 2), cur_state.enum, self.bits_data)
            else
              self:putdummy(self.ss, logicview.idx(origin_data, 2))
            end
            self.ss = 0
            self.count = 0
            self.bits_data = 0
            self.state_count = logicview.add(self.state_count, 1)
            if logicview.truth((self.state_count < logicview.len(self.diagram))) then
              cur_state = logicview.idx(self.diagram, self.state_count)
            end
          else
            self.bits_data = (self.bits_data << 8)
          end
        elseif logicview.truth((function()
  local _v
  _v = logicview.eq(cur_state.enum, process_enum.WRITE_BYTE)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.READ_BYTE)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.READ_BYTE_CONTINUOUS)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.WRITE_BYTE_CONTINUOUS)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(cur_state.enum, process_enum.CONTINUOUS_READ_MODE_BITS)
  return _v
end)()) then
          self:puttext(logicview.idx(origin_data, 1), logicview.idx(origin_data, 2), cur_state.enum, logicview.idx(origin_data, 0))
          if logicview.truth((function()
  local _v
  _v = (not logicview.eq(cur_state.enum, process_enum.READ_BYTE_CONTINUOUS))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(cur_state.enum, process_enum.WRITE_BYTE_CONTINUOUS))
  return _v
end)()) then
            self.state_count = logicview.add(self.state_count, 1)
            if logicview.truth((self.state_count < logicview.len(self.diagram))) then
              cur_state = logicview.idx(self.diagram, self.state_count)
            end
          end
        end
        if logicview.truth((self.state_count >= logicview.len(self.diagram))) then
          self.command = 0
          self.diagram = {  }
          self.state_count = 0
          break
        end
        ::continue_5::
      end
    end
  end
end
function _decoder.reset_decoder_state(self)
  self.io0data = 0
  self.io1data = (function() if logicview.truth(self.have_io1) then return 0 else return nil end end)()
  self.io2data = (function() if logicview.truth(self.have_io3) then return 0 else return nil end end)()
  self.io3data = (function() if logicview.truth(self.have_io3) then return 0 else return nil end end)()
  self.io0bits = {  }
  self.io1bits = (function() if logicview.truth(self.have_io1) then return {  } else return nil end end)()
  self.io2bits = (function() if logicview.truth(self.have_io3) then return {  } else return nil end end)()
  self.io3bits = (function() if logicview.truth(self.have_io3) then return {  } else return nil end end)()
  self.bitcount = 0
end
function _decoder.cs_asserted(self, cs)
  local active_low
  active_low = logicview.eq(logicview.idx(self.options, "cs_polarity"), "active-low")
  return (function() if logicview.truth(active_low) then return logicview.eq(cs, 0) else return logicview.eq(cs, 1) end end)()
end
function _decoder.handle_bit(self, datapins, clk, cs, frame)
  local ws, bo, es, elapsed, bitrate
  if logicview.truth(logicview.eq(self.bitcount, 0)) then
    self.ss_block = self.samplenum
    self.cs_was_deasserted = (function() if logicview.truth(self.have_cs) then return (not logicview.truth(self:cs_asserted(cs))) else return false end end)()
  end
  ws = 8
  bo = logicview.idx(self.options, "bitorder")
  if logicview.truth(logicview.eq(bo, "msb-first")) then
    self.io0data = (self.io0data | (logicview.idx(datapins, 3) << ((ws - 1) - self.bitcount)))
  else
    self.io0data = (self.io0data | (logicview.idx(datapins, 3) << self.bitcount))
  end
  if logicview.truth(self.have_io1) then
    if logicview.truth(logicview.eq(bo, "msb-first")) then
      self.io1data = (self.io1data | (logicview.idx(datapins, 2) << ((ws - 1) - self.bitcount)))
    else
      self.io1data = (self.io1data | (logicview.idx(datapins, 2) << self.bitcount))
    end
  end
  if logicview.truth(self.have_io3) then
    if logicview.truth(logicview.eq(bo, "msb-first")) then
      self.io2data = (self.io2data | (logicview.idx(datapins, 1) << ((ws - 1) - self.bitcount)))
      self.io3data = (self.io3data | (logicview.idx(datapins, 0) << ((ws - 1) - self.bitcount)))
    else
      self.io2data = (self.io2data | (logicview.idx(datapins, 1) << self.bitcount))
      self.io3data = (self.io3data | (logicview.idx(datapins, 0) << self.bitcount))
    end
  end
  es = self.samplenum
  if logicview.truth((self.bitcount > 0)) then
    es = logicview.add(es, (self.samplenum - logicview.idx(logicview.idx(self.io0bits, 0), 1)))
  end
  logicview.list_insert(self.io0bits, 0, { logicview.idx(datapins, 3), self.samplenum, es })
  if logicview.truth(self.have_io1) then
    logicview.list_insert(self.io1bits, 0, { logicview.idx(datapins, 2), self.samplenum, es })
  end
  if logicview.truth(self.have_io3) then
    logicview.list_insert(self.io2bits, 0, { logicview.idx(datapins, 1), self.samplenum, es })
    logicview.list_insert(self.io3bits, 0, { logicview.idx(datapins, 0), self.samplenum, es })
  end
  if logicview.truth((self.bitcount > 0)) then
    logicview.setidx(logicview.idx(self.io0bits, 1), 2, self.samplenum)
    if logicview.truth(self.have_io1) then
      logicview.setidx(logicview.idx(self.io1bits, 1), 2, self.samplenum)
    end
    if logicview.truth(self.have_io3) then
      logicview.setidx(logicview.idx(self.io2bits, 1), 2, self.samplenum)
      logicview.setidx(logicview.idx(self.io3bits, 1), 2, self.samplenum)
    end
  end
  self.bitcount = logicview.add(self.bitcount, 1)
  if logicview.truth((not logicview.eq(self.bitcount, ws))) then
    return
  end
  self:putdata(frame)
  if logicview.truth(self.samplerate) then
    elapsed = (1 / (_tonumber(self.samplerate) or 0))
    elapsed = logicview.mul(elapsed, logicview.add((self.samplenum - self.ss_block), 1))
    bitrate = logicview.tointeger(logicview.mul((1 / elapsed), ws))
    self:put(self.ss_block, self.samplenum, self.out_bitrate, bitrate)
  end
  if logicview.truth((function()
  local _v
  _v = self.have_cs
  if not logicview.truth(_v) then return _v end
  _v = self.cs_was_deasserted
  return _v
end)()) then
    self:putw({ 6, { "CS# was deasserted during this data word!" } })
  end
  self:reset_decoder_state()
end
function _decoder.find_clk_edge(self, datapins, clk, cs, first, frame)
  local oldcs
  if logicview.truth((function()
  local _v
  _v = self.have_cs
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = first
  if logicview.truth(_v) then return _v end
  _v = (self.matched & (1 << self.have_cs))
  return _v
end)()
  return _v
end)()) then
    oldcs = (function() if logicview.truth(first) then return nil else return (1 - cs) end end)()
    self:put(self.samplenum, self.samplenum, self.out_python, { "CS-CHANGE", oldcs, cs })
    if logicview.truth(frame) then
      if logicview.truth(self:cs_asserted(cs)) then
        self.ss_transfer = self.samplenum
        self.io0bytes = {  }
        self.io1bytes = {  }
        self.io2bytes = {  }
        self.io3bytes = {  }
      elseif logicview.truth((not logicview.eq(self.ss_transfer, (-1)))) then
        self:put(self.ss_transfer, self.samplenum, self.out_python, { "TRANSFER", self.io0bytes, self.io1bytes, self.io2bytes, self.io3bytes })
      end
    end
    self.command = 0
    self.diagram = {  }
    self.state_count = 0
    self.ss = 0
    self.count = 0
    self.bits_data = 0
    self:reset_decoder_state()
  end
  if logicview.truth((function()
  local _v
  _v = self.have_cs
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(self:cs_asserted(cs)))
  return _v
end)()) then
    return
  end
  if logicview.truth((function()
  local _v
  _v = first
  if logicview.truth(_v) then return _v end
  _v = (not logicview.truth((self.matched & (1 << 0))))
  return _v
end)()) then
    return
  end
  self:handle_bit(datapins, clk, cs, frame)
end
function _decoder.decode(self)
  local frame, mode, wait_cond, clk, d0, d1, d2, d3, cs, d
  if logicview.truth((not logicview.truth(self:has_channel(0)))) then
    _error(ChannelError("CLK pin required."), 0)
  end
  if logicview.truth((not logicview.truth(self:has_channel(1)))) then
    _error(ChannelError("io0 pin required."), 0)
  end
  self.have_io1 = self:has_channel(2)
  self.have_io3 = (self:has_channel(3) & self:has_channel(4))
  self.have_cs = self:has_channel(5)
  if logicview.truth((not logicview.truth(self.have_cs))) then
    self:put(0, 0, self.out_python, { "CS-CHANGE", nil, nil })
  end
  frame = logicview.eq(logicview.idx(self.options, "frame"), "yes")
  mode = logicview.idx(spi_mode, logicview.tkey(logicview.idx(self.options, "cpol"), logicview.idx(self.options, "cpha")))
  if logicview.truth((function()
  local _v
  _v = logicview.eq(mode, 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(mode, 3)
  return _v
end)()) then
    wait_cond = { logicview.dict({ [0] = "r" }) }
  else
    wait_cond = { logicview.dict({ [0] = "f" }) }
  end
  if logicview.truth(self.have_cs) then
    self.have_cs = logicview.len(wait_cond)
    _table.insert(wait_cond, logicview.dict({ [5] = "e" }))
  end
  do
    local _lv_seq = self:wait(logicview.dict({  }))
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    clk = logicview.idx(_lv_seq, 0)
    d0 = logicview.idx(_lv_seq, 1)
    d1 = logicview.idx(_lv_seq, 2)
    d2 = logicview.idx(_lv_seq, 3)
    d3 = logicview.idx(_lv_seq, 4)
    cs = logicview.idx(_lv_seq, 5)
  end
  d = { d3, d2, d1, d0 }
  self:find_clk_edge(d, clk, cs, true, frame)
  while true do
    do
      local _lv_seq = self:wait(wait_cond)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      clk = logicview.idx(_lv_seq, 0)
      d0 = logicview.idx(_lv_seq, 1)
      d1 = logicview.idx(_lv_seq, 2)
      d2 = logicview.idx(_lv_seq, 3)
      d3 = logicview.idx(_lv_seq, 4)
      cs = logicview.idx(_lv_seq, 5)
    end
    d = { d3, d2, d1, d0 }
    self:find_clk_edge(d, clk, cs, false, frame)
    ::continue_6::
  end
end

return _decoder
