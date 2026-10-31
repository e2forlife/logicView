-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2020 Analog Devices Inc.
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
local SrdIntEnum, WORD_SIZE, Channel, Operation, BitType, Bit, Ann, St, Decoder, error_messages, rate_code, fifo_modes, operations, number_bytes, registers
local _decoder

error_messages = logicview.dict({ interrupt = { "Interrupt" }, undesirable = { "Undesirable behavior" }, dis_single = { "Disable single tap" }, dis_double = { "Disable double tap" }, dis_single_double = { "Disable single/double tap" } })
rate_code = logicview.dict({ [0] = 0.1, [1] = 0.2, [2] = 0.39, [3] = 0.78, [4] = 1.56, [5] = 3.13, [6] = 6.25, [7] = 12.5, [8] = 25, [9] = 50, [10] = 100, [11] = 200, [12] = 400, [13] = 800, [14] = 1600, [15] = 3200 })
fifo_modes = logicview.dict({ [0] = "Bypass", [1] = "FIFO", [2] = "Stream", [3] = "Trigger" })
operations = logicview.dict({ [0] = { "WRITE REG", "WRITE", "W" }, [1] = { "READ REG", "READ", "R" } })
number_bytes = logicview.dict({ [0] = { "SINGLE BYTE", "SING BYTE", "1 BYTE", "1B" }, [1] = { "MULTIPLE BYTES", "MULTI BYTES", "n*BYTES", "n*B" } })
registers = logicview.dict({ [0] = { "DEVID", "DID", "ID" }, [29] = { "THRESH_TAP", "TH_TAP", "TH_T" }, [30] = { "OFSX", "OFX" }, [31] = { "OFSY", "OFY" }, [32] = { "OFSZ", "OFZ" }, [33] = { "DUR" }, [34] = { "Latent", "Lat" }, [35] = { "Window", "Win" }, [36] = { "THRESH_ACT", "TH_ACT", "TH_A" }, [37] = { "THRESH_INACT", "TH_INACT", "TH_I" }, [38] = { "TIME_INACT", "TI_INACT", "TI_I" }, [39] = { "ACT_INACT_CTL", "ACT_I_CTL", "A_I_C" }, [40] = { "THRESH_FF", "TH_FF" }, [41] = { "TIME_FF", "TI_FF" }, [42] = { "TAP_AXES", "TAP_AX", "TP_AX" }, [43] = { "ACT_TAP_STATUS", "ACT_TAP_STAT", "ACT_TP_ST", "A_T_S" }, [44] = { "BW_RATE", "BW_R" }, [45] = { "POWER_CTL", "PW_CTL", "PW_C" }, [46] = { "INT_ENABLE", "INT_EN", "I_EN" }, [47] = { "INT_MAP", "I_M" }, [48] = { "INT_SOURCE", "INT_SRC", "I_SRC", "I_S" }, [49] = { "DATA_FORMAT", "DATA_FRM", "D_FRM", "D_F" }, [50] = { "DATAX0", "DX0", "X0" }, [51] = { "DATAX1", "DX1", "X1" }, [52] = { "DATAY0", "DY0", "Y0" }, [53] = { "DATAY1", "DY1", "Y1" }, [54] = { "DATAZ0", "DZ0", "Z0" }, [55] = { "DATAZ1", "DZ1", "Z1" }, [56] = { "FIFO_CTL", "FIF_CT", "F_C" }, [57] = { "FIFO_STATUS", "FIFO_STAT", "FIF_ST", "F_S" } })

WORD_SIZE = 8
Channel = {}
Channel.__index = Channel
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Channel.MISO = logicview.idx(_lv_seq, 0)
  Channel.MOSI = logicview.idx(_lv_seq, 1)
end
Operation = {}
Operation.__index = Operation
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Operation.READ = logicview.idx(_lv_seq, 0)
  Operation.WRITE = logicview.idx(_lv_seq, 1)
end
BitType = {}
BitType.__index = BitType
BitType.ENABLE = logicview.dict({ [1] = { "Enable %s", "En %s", "%s " }, [0] = { "Disable %s", "Dis %s", "!%s " } })
BitType.SOURCE = logicview.dict({ [1] = { "Involve %s", "Inv %s", "%s" }, [0] = { "Not involve %s", "Not inv %s", "!%s" } })
BitType.INTERRUPT = logicview.dict({ [1] = { "INT2 %s", "I2: %s " }, [0] = { "INT1 %s", "I1:%s " } })
BitType.AC_DC = logicview.dict({ [1] = { "%s ac", "ac" }, [0] = { "%s dc", "dc" } })
BitType.UNUSED = logicview.dict({ [1] = { "N/A" }, [0] = { "N/A" } })
BitType.OTHER = 0
Bit = {}
Bit.__index = Bit
function Bit.__init__(self, name, type, values)
  if values == nil then values = nil end
  self.value = 0
  self.name = name
  self.type = type
  self.values = values
end
function Bit.set_value(self, value)
  self.value = value
end
function Bit.get_bit_annotation(self)
  local annotation, index
  if logicview.truth(logicview.eq(self.type, BitType.OTHER)) then
    annotation = logicview.copy(logicview.idx(self.values, self.value))
  else
    annotation = logicview.copy(logicview.idx(self.type, self.value))
  end
  for _lv_i in logicview.range(logicview.len(annotation)) do
    index = _lv_i
    if logicview.truth(logicview.contains(logicview.idx(annotation, index), "%s")) then
      logicview.setidx(annotation, index, _tostring(logicview.pymod(logicview.idx(annotation, index), self.name)))
    end
    ::continue_1::
  end
  return annotation
end
function Bit.new(...)
  local self = _setmetatable({}, Bit)
  Bit.__init__(self, ...)
  return self
end
Ann = logicview.int_enum(logicview.split("READ WRITE MB REG_ADDRESS REG_DATA WARNING", ' '))
St = logicview.int_enum(logicview.split("IDLE ADDRESS_BYTE DATA", ' '))
_decoder = {
  api_version = 3,
  id = "adxl345",
  name = "ADXL345",
  longname = "Analog Devices ADXL345",
  desc = "Analog Devices ADXL345 3-axis accelerometer.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "read", "Read" }, { "write", "Write" }, { "mb", "Multiple bytes" }, { "reg-address", "Register address" }, { "reg-data", "Register data" }, { "warning", "Warning" } },
  annotation_rows = { { "reg", "Registers", { 0, 1, 2, 3 } }, { "data", "Data", { 4, 5 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi = _lv_a0
    self.miso = _lv_a1
  end
  self.reg = {  }
  self.operation = nil
  self.address = 0
  self.data = (-1)
  self.state = St.IDLE
  do
    local _lv_a0, _lv_a1 = (-1), (-1)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self.samples_per_bit = 0
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putb(self, data, index)
  local start
  start = logicview.add(self.ss, logicview.mul(self.samples_per_bit, index))
  self:put(start, logicview.add(start, self.samples_per_bit), self.out_ann, data)
end
function _decoder.putbs(self, data, start_index, stop_index)
  local start, stop
  start_index = self:reverse_bit_index(start_index, WORD_SIZE)
  stop_index = self:reverse_bit_index(stop_index, WORD_SIZE)
  start = logicview.add(self.ss, logicview.mul(self.samples_per_bit, start_index))
  stop = logicview.add(start, logicview.mul(self.samples_per_bit, logicview.add((stop_index - start_index), 1)))
  self:put(start, stop, self.out_ann, data)
end
function _decoder.handle_reg_with_scaling_factor(self, data, factor, name, unit, error_msg)
  local result
  if logicview.truth((function()
  local _v
  _v = logicview.eq(data, 0)
  if not logicview.truth(_v) then return _v end
  _v = (error_msg ~= nil)
  return _v
end)()) then
    self:putx({ Ann.WARNING, error_msg })
  else
    result = (logicview.mul(data, factor) / 1000)
    self:putx({ Ann.REG_DATA, { logicview.pymod("%s: %f %s", { name, result, unit }), logicview.pymod("%f %s", { result, unit }) } })
  end
end
function _decoder.handle_reg_bit_msg(self, bit, index, en_msg, dis_msg)
  self:putb({ Ann.REG_DATA, { (function() if logicview.truth(bit) then return en_msg else return dis_msg end end)() } }, index)
end
function _decoder.interpret_bits(self, data, bits)
  local bits_values, offset, index, bit
  bits_values = {  }
  for _lv_i in logicview.range(8) do
    offset = _lv_i
    logicview.list_insert(bits_values, 0, ((data & (1 << offset)) >> offset))
    ::continue_2::
  end
  for _lv_i in logicview.range(logicview.len(bits)) do
    index = _lv_i
    if logicview.truth((logicview.idx(bits, index) == nil)) then
      goto continue_3
    end
    bit = logicview.idx(bits, index)
    bit:set_value(logicview.idx(bits_values, index))
    self:putb({ Ann.REG_DATA, bit:get_bit_annotation() }, index)
    ::continue_3::
  end
  return logicview.copy(logicview.reversed(bits_values))
end
function _decoder.reverse_bit_index(self, index, word_size)
  return ((word_size - index) - 1)
end
function _decoder.get_decimal_number(self, bits, start_index, stop_index)
  local number, interval, index, offset, bit
  number = 0
  interval = (function() local _t = {}; for _v in logicview.range(start_index, logicview.add(stop_index, 1), 1) do _t[#_t + 1] = _v end; return _t end)()
  for _lv_z0, _lv_z1 in logicview.zip(interval, (function() local _t = {}; for _v in logicview.range(logicview.len(interval)) do _t[#_t + 1] = _v end; return _t end)()) do
    index = _lv_z0
    offset = _lv_z1
    bit = logicview.idx(bits, index)
    number = (number | (bit << offset))
    ::continue_4::
  end
  return number
end
function _decoder.get_axis_value(self, data, axis)
  if logicview.truth((not logicview.eq(self.data, (-1)))) then
    data = (data << 8)
    self.data = (self.data | data)
    self:put(self.start_index, self.es, self.out_ann, { Ann.REG_DATA, { logicview.pymod("%s: 0x%04X", { axis, self.data }), _tostring(data) } })
    self.data = (-1)
  else
    self:putx({ Ann.REG_DATA, { _tostring(data) } })
  end
end
function _decoder.handle_reg_0x1d(self, data)
  self:handle_reg_with_scaling_factor(data, 62.5, "Threshold", "g", logicview.idx(error_messages, "undesirable"))
end
function _decoder.handle_reg_0x1e(self, data)
  self:handle_reg_with_scaling_factor(data, 15.6, "OFSX", "g", nil)
end
function _decoder.handle_reg_0x1f(self, data)
  self:handle_reg_with_scaling_factor(data, 15.6, "OFSY", "g", nil)
end
function _decoder.handle_reg_0x20(self, data)
  self:handle_reg_with_scaling_factor(data, 15.6, "OFSZ", "g", nil)
end
function _decoder.handle_reg_0x21(self, data)
  self:handle_reg_with_scaling_factor(data, 0.625, "Duration", "s", logicview.idx(error_messages, "dis_single_double"))
end
function _decoder.handle_reg_0x22(self, data)
  self:handle_reg_with_scaling_factor(data, 1.25, "Latency", "s", logicview.idx(error_messages, "dis_double"))
end
function _decoder.handle_reg_0x23(self, data)
  self:handle_reg_with_scaling_factor(data, 1.25, "Window", "s", logicview.idx(error_messages, "dis_double"))
end
function _decoder.handle_reg_0x24(self, data)
  self:handle_reg_0x1d(data)
end
function _decoder.handle_reg_0x25(self, data)
  self:handle_reg_0x1d(data)
end
function _decoder.handle_reg_0x26(self, data)
  self:handle_reg_with_scaling_factor(data, 1000, "Time", "s", logicview.idx(error_messages, "interrupt"))
end
function _decoder.handle_reg_0x27(self, data)
  local bits
  bits = { Bit.new("ACT", BitType.AC_DC), Bit.new("ACT_X", BitType.ENABLE), Bit.new("ACT_Y", BitType.ENABLE), Bit.new("ACT_Z", BitType.ENABLE), Bit.new("INACT", BitType.AC_DC), Bit.new("INACT_X", BitType.ENABLE), Bit.new("INACT_Y", BitType.ENABLE), Bit.new("INACT_Z", BitType.ENABLE) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x28(self, data)
  self:handle_reg_0x1d(data)
end
function _decoder.handle_reg_0x29(self, data)
  self:handle_reg_with_scaling_factor(data, 5, "Time", "s", logicview.idx(error_messages, "undesirable"))
end
function _decoder.handle_reg_0x2a(self, data)
  local bits
  bits = { Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Suppressed", "Suppr", "S" }, [0] = { "Unsuppressed", "Unsuppr", "Uns" } })), Bit.new("TAP_X", BitType.ENABLE), Bit.new("TAP_Y", BitType.ENABLE), Bit.new("TAP_Z", BitType.ENABLE) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x2b(self, data)
  local bits
  bits = { Bit.new("", BitType.UNUSED), Bit.new("ACT_X", BitType.SOURCE), Bit.new("ACT_Y", BitType.SOURCE), Bit.new("ACT_Z", BitType.SOURCE), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Asleep", "Asl" }, [0] = { "Not asleep", "Not asl", "!Asl" } })), Bit.new("TAP_X", BitType.SOURCE), Bit.new("TAP_Y", BitType.SOURCE), Bit.new("TAP_Z", BitType.SOURCE) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x2c(self, data)
  local bits, bits_values, start_index, stop_index, rate
  bits = { Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Reduce power", "Reduce pw", "Red pw" }, [0] = { "Normal operation", "Normal op", "Norm op" } })) }
  bits_values = self:interpret_bits(data, bits)
  do
    local _lv_a0, _lv_a1 = 0, 3
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  rate = self:get_decimal_number(bits_values, start_index, stop_index)
  self:putbs({ Ann.REG_DATA, { logicview.pymod("%f", logicview.idx(rate_code, rate)) } }, stop_index, start_index)
end
function _decoder.handle_reg_0x2d(self, data)
  local bits, bits_values, start_index, stop_index, wakeup, frequency
  bits = { Bit.new("", BitType.UNUSED), Bit.new("", BitType.UNUSED), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Link" }, [0] = { "Unlink" } })), Bit.new("AUTO_SLEEP", BitType.ENABLE), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Measurement mode", "Measurement", "Meas" }, [0] = { "Standby mode", "Standby" } })), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Sleep mode", "Sleep", "Slp" }, [0] = { "Normal mode", "Normal", "Nrm" } })) }
  bits_values = self:interpret_bits(data, bits)
  do
    local _lv_a0, _lv_a1 = 0, 1
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  wakeup = self:get_decimal_number(bits_values, start_index, stop_index)
  frequency = (2 ^ ((~wakeup) & 3))
  self:putbs({ Ann.REG_DATA, { logicview.pymod("%d Hz", frequency) } }, stop_index, start_index)
end
function _decoder.handle_reg_0x2e(self, data)
  local bits
  bits = { Bit.new("DATA_READY", BitType.ENABLE), Bit.new("SINGLE_TAP", BitType.ENABLE), Bit.new("DOUBLE_TAP", BitType.ENABLE), Bit.new("Activity", BitType.ENABLE), Bit.new("Inactivity", BitType.ENABLE), Bit.new("FREE_FALL", BitType.ENABLE), Bit.new("Watermark", BitType.ENABLE), Bit.new("Overrun", BitType.ENABLE) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x2f(self, data)
  local bits
  bits = { Bit.new("DATA_READY", BitType.INTERRUPT), Bit.new("SINGLE_TAP", BitType.INTERRUPT), Bit.new("DOUBLE_TAP", BitType.INTERRUPT), Bit.new("Activity", BitType.INTERRUPT), Bit.new("Inactivity", BitType.INTERRUPT), Bit.new("FREE_FALL", BitType.INTERRUPT), Bit.new("Watermark", BitType.INTERRUPT), Bit.new("Overrun", BitType.INTERRUPT) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x30(self, data)
  local bits
  bits = { Bit.new("DATA_READY", BitType.SOURCE), Bit.new("SINGLE_TAP", BitType.SOURCE), Bit.new("DOUBLE_TAP", BitType.SOURCE), Bit.new("Activity", BitType.SOURCE), Bit.new("Inactivity", BitType.SOURCE), Bit.new("FREE_FALL", BitType.SOURCE), Bit.new("Watermark", BitType.SOURCE), Bit.new("Overrun", BitType.SOURCE) }
  self:interpret_bits(data, bits)
end
function _decoder.handle_reg_0x31(self, data)
  local bits, bits_values, start_index, stop_index, range_g, result
  bits = { Bit.new("SELF_TEST", BitType.ENABLE), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "3-wire SPI", "3-SPI" }, [0] = { "4-wire SPI", "4-SPI" } })), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "INT ACT LOW", "INT LOW" }, [0] = { "INT ACT HIGH", "INT HIGH" } })), Bit.new("", BitType.UNUSED), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Full resolution", "Full res" }, [0] = { "10-bit mode", "10-bit" } })), Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "MSB mode", "MSB" }, [0] = { "LSB mode", "LSB" } })) }
  bits_values = self:interpret_bits(data, bits)
  do
    local _lv_a0, _lv_a1 = 0, 1
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  range_g = self:get_decimal_number(bits_values, start_index, stop_index)
  result = (2 ^ logicview.add(range_g, 1))
  self:putbs({ Ann.REG_DATA, { logicview.pymod("+/-%d g", result) } }, stop_index, start_index)
end
function _decoder.handle_reg_0x32(self, data)
  self.data = data
  self:putx({ Ann.REG_DATA, { _tostring(data) } })
end
function _decoder.handle_reg_0x33(self, data)
  self:get_axis_value(data, "X")
end
function _decoder.handle_reg_0x34(self, data)
  self:handle_reg_0x32(data)
end
function _decoder.handle_reg_0x35(self, data)
  self:get_axis_value(data, "Y")
end
function _decoder.handle_reg_0x36(self, data)
  self:handle_reg_0x32(data)
end
function _decoder.handle_reg_0x37(self, data)
  self:get_axis_value(data, "Z")
end
function _decoder.handle_reg_0x38(self, data)
  local bits, bits_values, start_index, stop_index, fifo, samples
  bits = { nil, nil, Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Trig-INT2", "INT2" }, [0] = { "Trig-INT1", "INT1" } })) }
  bits_values = self:interpret_bits(data, bits)
  do
    local _lv_a0, _lv_a1 = 6, 7
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  fifo = self:get_decimal_number(bits_values, start_index, stop_index)
  self:putbs({ Ann.REG_DATA, { logicview.idx(fifo_modes, fifo) } }, stop_index, start_index)
  do
    local _lv_a0, _lv_a1 = 0, 4
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  samples = self:get_decimal_number(bits_values, start_index, stop_index)
  self:putbs({ Ann.REG_DATA, { logicview.pymod("Samples: %d", samples), logicview.pymod("%d", samples) } }, stop_index, start_index)
end
function _decoder.handle_reg_0x39(self, data)
  local bits, bits_values, start_index, stop_index, entries
  bits = { Bit.new("", BitType.OTHER, logicview.dict({ [1] = { "Triggered", "Trigg" }, [0] = { "Not triggered", "Not trigg" } })), Bit.new("", BitType.UNUSED) }
  bits_values = self:interpret_bits(data, bits)
  do
    local _lv_a0, _lv_a1 = 0, 5
    start_index = _lv_a0
    stop_index = _lv_a1
  end
  entries = self:get_decimal_number(bits_values, start_index, stop_index)
  self:putbs({ Ann.REG_DATA, { logicview.pymod("Entries: %d", entries), logicview.pymod("%d", entries) } }, stop_index, start_index)
end
function _decoder.get_bit(self, channel)
  local mosi_bit, miso_bit
  if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(channel, Channel.MOSI)
  if not logicview.truth(_v) then return _v end
  _v = (self.mosi == nil)
  return _v
end)()
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(channel, Channel.MISO)
  if not logicview.truth(_v) then return _v end
  _v = (self.miso == nil)
  return _v
end)()
  return _v
end)()) then
    _error(Exception("No available data"), 0)
  end
  do
    local _lv_a0, _lv_a1 = 0, 0
    mosi_bit = _lv_a0
    miso_bit = _lv_a1
  end
  if logicview.truth((self.miso ~= nil)) then
    if logicview.truth((logicview.len(self.mosi) < 0)) then
      _error(Exception("No available data"), 0)
    end
    miso_bit = logicview.list_pop(self.miso, 0)
  end
  if logicview.truth((self.miso ~= nil)) then
    if logicview.truth((logicview.len(self.miso) < 0)) then
      _error(Exception("No available data"), 0)
    end
    mosi_bit = logicview.list_pop(self.mosi, 0)
  end
  if logicview.truth(logicview.eq(channel, Channel.MOSI)) then
    return mosi_bit
  end
  return miso_bit
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, op_bit, mb_bit, start_sample, addr_bit, i, reg_value, reg_bit, offset, mask, handle_reg
    ptype = logicview.idx(data, 0)
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      do
        local _lv_seq = logicview.slice(data, 1, nil, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cs_old = logicview.idx(_lv_seq, 0)
        cs_new = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((function()
  local _v
  _v = (cs_old ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_old, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 0)
  return _v
end)()) then
        do
          local _lv_a0, _lv_a1 = ss, es
          self.ss = _lv_a0
          self.es = _lv_a1
        end
        self.state = St.ADDRESS_BYTE
      else
        self.state = St.IDLE
      end
    elseif logicview.truth(logicview.eq(ptype, "BITS")) then
      if logicview.truth((logicview.idx(data, 1) ~= nil)) then
        self.mosi = logicview.copy(logicview.reversed(logicview.idx(data, 1)))
      end
      if logicview.truth((logicview.idx(data, 2) ~= nil)) then
        self.miso = logicview.copy(logicview.reversed(logicview.idx(data, 2)))
      end
      if logicview.truth((function()
  local _v
  _v = (self.mosi == nil)
  if not logicview.truth(_v) then return _v end
  _v = (self.miso == nil)
  return _v
end)()) then
        return
      end
      if logicview.truth(logicview.eq(self.state, St.ADDRESS_BYTE)) then
        op_bit = self:get_bit(Channel.MOSI)
        self:put(logicview.idx(op_bit, 1), logicview.idx(op_bit, 2), self.out_ann, { (function() if logicview.truth(logicview.idx(op_bit, 0)) then return Ann.READ else return Ann.WRITE end end)(), logicview.idx(operations, logicview.idx(op_bit, 0)) })
        self.operation = (function() if logicview.truth(logicview.idx(op_bit, 0)) then return Operation.READ else return Operation.WRITE end end)()
        mb_bit = self:get_bit(Channel.MOSI)
        self:put(logicview.idx(mb_bit, 1), logicview.idx(mb_bit, 2), self.out_ann, { Ann.MB, logicview.idx(number_bytes, logicview.idx(mb_bit, 0)) })
        self.address = 0
        start_sample = logicview.idx(logicview.idx(self.mosi, 0), 1)
        addr_bit = {  }
        for _lv_i in logicview.range(6) do
          i = _lv_i
          addr_bit = self:get_bit(Channel.MOSI)
          self.address = (self.address | logicview.idx(addr_bit, 0))
          self.address = (self.address << 1)
          ::continue_5::
        end
        self.address = (self.address >> 1)
        self:put(start_sample, logicview.idx(addr_bit, 2), self.out_ann, { Ann.REG_ADDRESS, { "ADDRESS: {$}", "ADDR: {$}", "{$}", logicview.pymod("@%02X", self.address) } })
        self.ss = (-1)
        self.state = St.DATA
      elseif logicview.truth(logicview.eq(self.state, St.DATA)) then
        logicview.extend(self.reg, (function() if logicview.truth(logicview.eq(self.operation, Operation.WRITE)) then return self.mosi else return self.miso end end)())
        do
          local _lv_a0, _lv_a1 = {  }, {  }
          self.mosi = _lv_a0
          self.miso = _lv_a1
        end
        if logicview.truth(logicview.eq(self.ss, (-1))) then
          do
            local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.reg, 0), 1), es
            self.ss = _lv_a0
            self.es = _lv_a1
          end
          self.samples_per_bit = (logicview.idx(logicview.idx(self.reg, 0), 2) - self.ss)
        end
        if logicview.truth((logicview.len(self.reg) < 8)) then
          return
        else
          reg_value = 0
          reg_bit = {  }
          for _lv_i in logicview.range(7, (-1), (-1)) do
            offset = _lv_i
            reg_bit = logicview.list_pop(self.reg, 0)
            mask = (logicview.idx(reg_bit, 0) << offset)
            reg_value = (reg_value | mask)
            ::continue_6::
          end
          if logicview.truth((function()
  local _v
  _v = (self.address < 0)
  if logicview.truth(_v) then return _v end
  _v = (self.address > 57)
  return _v
end)()) then
            return
          end
          if logicview.truth(logicview.contains({ 50, 52, 54 }, self.address)) then
            self.start_index = self.ss
          end
          if logicview.truth(((29 > self.address) and (self.address >= 0))) then
            self:put(self.ss, logicview.idx(reg_bit, 2), self.out_ann, { Ann.REG_ADDRESS, { _tostring(self.address) } })
            self:put(self.ss, logicview.idx(reg_bit, 2), self.out_ann, { Ann.REG_DATA, { _tostring(reg_value) } })
          else
            self:put(self.ss, logicview.idx(reg_bit, 2), self.out_ann, { Ann.REG_ADDRESS, logicview.idx(registers, self.address) })
            handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.address)]; if _v == nil then return nil end; return _v end)()
            handle_reg(reg_value)
          end
          self.reg = {  }
          self.address = logicview.add(self.address, 1)
          self.ss = (-1)
        end
      end
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
