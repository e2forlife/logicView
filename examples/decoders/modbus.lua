-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2015 Bart de Waal <bart@waalamo.com>
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
local ceil, RX, TX, rxtx_channels, No_more_data, Data, Modbus_ADU, Modbus_ADU_SC, Modbus_ADU_CS, Decoder
local _decoder

ceil = _math.ceil
RX = 0
TX = 1
rxtx_channels = { "RX", "TX" }
No_more_data = function(msg)
  local text = _tostring(msg or "No_more_data")
  return _setmetatable({ _exc = "No_more_data", args = { text } }, { __tostring = function() return text end })
end
Data = {}
Data.__index = Data
function Data.__init__(self, start, end_, data)
  self.start = start
  self["end"] = end_
  self.data = data
end
function Data.new(...)
  local self = _setmetatable({}, Data)
  Data.__init__(self, ...)
  return self
end
Modbus_ADU = {}
Modbus_ADU.__index = Modbus_ADU
function Modbus_ADU.__init__(self, parent, start, write_channel, annotation_prefix)
  self.data = {  }
  self.parent = parent
  self.start = start
  self.last_read = start
  self.write_channel = write_channel
  self.last_byte_put = (-1)
  self.annotation_prefix = annotation_prefix
  self.minimum_length = 4
  self.startNewFrame = false
  self.hasError = false
end
function Modbus_ADU.add_data(self, start, end_, data)
  local ptype, rxtx, pdata
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
  self.last_read = end_
  if logicview.truth(logicview.eq(ptype, "DATA")) then
    _table.insert(self.data, Data.new(start, end_, logicview.idx(pdata, 0)))
    self:parse()
  end
end
function Modbus_ADU.puti(self, byte_to_put, annotation, message)
  if logicview.truth((byte_to_put > (logicview.len(self.data) - 1))) then
    _error(No_more_data, 0)
  end
  if logicview.truth(logicview.eq(annotation, "error")) then
    self.hasError = true
  end
  if logicview.truth((byte_to_put > self.last_byte_put)) then
    self.parent:puta(logicview.idx(self.data, logicview.add(self.last_byte_put, 1)).start, logicview.idx(self.data, byte_to_put)["end"], logicview.add(self.annotation_prefix, annotation), message)
    self.last_byte_put = byte_to_put
    _error(No_more_data, 0)
  end
end
function Modbus_ADU.putl(self, annotation, message, maximum)
  if maximum == nil then maximum = nil end
  local last_byte_address
  last_byte_address = (logicview.len(self.data) - 1)
  if logicview.truth((function()
  local _v
  _v = (maximum ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = (last_byte_address > maximum)
  return _v
end)()) then
    return
  end
  self:puti(last_byte_address, annotation, logicview.pyformat(message, { logicview.idx(self.data, (-1)).data }, logicview.dict({})))
end
function Modbus_ADU.close(self, message_overflow)
  local data
  data = self.data
  if logicview.truth((logicview.len(data) < self.minimum_length)) then
    if logicview.truth(logicview.eq(logicview.len(data), 0)) then
      return
    end
    self.parent:puta(logicview.idx(data, self.last_byte_put)["end"], message_overflow, logicview.add(self.annotation_prefix, "error"), "Message too short or not finished")
    self.hasError = true
  end
  if logicview.truth((function()
  local _v
  _v = self.hasError
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(self.parent.options, "scchannel"), logicview.idx(self.parent.options, "cschannel")))
  return _v
end)()) then
    self.parent:puta(logicview.idx(data, 0).start, logicview.idx(data, (-1))["end"], "error-indication", "Frame contains error")
  end
  if logicview.truth((logicview.len(data) > 256)) then
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        self:puti((logicview.len(data) - 1), "error", "Modbus data frames are limited to 256 bytes")
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if (_type(_err) == 'table' and _err._exc == "No_more_data") then
        else
          _error(_err, 0)
        end
      end
    end
  end
end
function Modbus_ADU.check_crc(self, byte_to_put)
  local crc_byte1, crc_byte2, data
  do
    local _lv_seq = self:calc_crc(byte_to_put)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    crc_byte1 = logicview.idx(_lv_seq, 0)
    crc_byte2 = logicview.idx(_lv_seq, 1)
  end
  data = self.data
  if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(data, (-2)).data, crc_byte1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(data, (-1)).data, crc_byte2)
  return _v
end)()) then
    self:puti(byte_to_put, "crc", "CRC correct")
  else
    self:puti(byte_to_put, "error", logicview.pyformat("CRC should be {} {}", { crc_byte1, crc_byte2 }, logicview.dict({})))
  end
end
function Modbus_ADU.half_word(self, start)
  if logicview.truth((logicview.add(start, 1) > (logicview.len(self.data) - 1))) then
    _error(No_more_data, 0)
  end
  return logicview.add(logicview.mul(logicview.idx(self.data, start).data, 256), logicview.idx(self.data, logicview.add(start, 1)).data)
end
function Modbus_ADU.calc_crc(self, last_byte)
  local result, magic_number, byte, i, LSB, byte1, byte2
  if logicview.truth((last_byte < 3)) then
    _error(Exception("Could not calculate CRC: message too short"), 0)
  end
  result = 65535
  magic_number = 40961
  for _lv_item in logicview.iter(logicview.slice(self.data, nil, (last_byte - 1), nil)) do
    byte = _lv_item
    result = (result ~ byte.data)
    for _lv_i in logicview.range(8) do
      i = _lv_i
      LSB = (result & 1)
      result = (result >> 1)
      if logicview.truth(LSB) then
        result = (result ~ magic_number)
      end
      ::continue_2::
    end
    ::continue_1::
  end
  byte1 = (result & 255)
  byte2 = ((result & 65280) >> 8)
  return { byte1, byte2 }
end
function Modbus_ADU.parse_write_single_coil(self)
  local address, raw_value, value
  self.minimum_length = 8
  self:puti(1, "function", "Function 5: Write Single Coil")
  address = self:half_word(2)
  self:puti(3, "address", logicview.pyformat("Address 0x{:X} / {:d}", { address, logicview.add(address, 10000) }, logicview.dict({})))
  raw_value = self:half_word(4)
  value = "Invalid Coil Value"
  if logicview.truth(logicview.eq(raw_value, 0)) then
    value = "Coil Value OFF"
  elseif logicview.truth(logicview.eq(raw_value, 65280)) then
    value = "Coil Value ON"
  end
  self:puti(5, "data", value)
  self:check_crc(7)
end
function Modbus_ADU.parse_write_single_register(self)
  local address, value, value_formatted
  self.minimum_length = 8
  self:puti(1, "function", "Function 6: Write Single Register")
  address = self:half_word(2)
  self:puti(3, "address", logicview.pyformat("Address 0x{:X} / {:d}", { address, logicview.add(address, 30000) }, logicview.dict({})))
  value = self:half_word(4)
  value_formatted = logicview.pyformat("Register Value 0x{0:X} / {0:d}", { value }, logicview.dict({}))
  self:puti(5, "data", value_formatted)
  self:check_crc(7)
end
function Modbus_ADU.parse_diagnostics(self)
  local diag_subfunction, subfunction, subfunction_name, diagnostic_data
  self.minimum_length = 8
  self:puti(1, "function", "Function 8: Diagnostics")
  diag_subfunction = logicview.dict({ [0] = "Return Query data", [1] = "Restart Communications Option", [2] = "Return Diagnostics Register", [3] = "Change ASCII Input Delimiter", [4] = "Force Listen Only Mode", [10] = "Clear Counters and Diagnostic Register", [11] = "Return Bus Message Count", [12] = "Return Bus Communication Error Count", [13] = "Return Bus Exception Error Count", [14] = "Return Slave Message Count", [15] = "Return Slave No Response Count", [16] = "Return Slave NAK Count", [17] = "Return Slave Busy Count", [18] = "Return Bus Character Overrun Count", [20] = "Return Overrun Counter and Flag" })
  subfunction = self:half_word(2)
  subfunction_name = logicview.dget(diag_subfunction, subfunction, "Reserved subfunction")
  self:puti(3, "data", logicview.pyformat("Subfunction {}: {}", { subfunction, subfunction_name }, logicview.dict({})))
  diagnostic_data = self:half_word(4)
  self:puti(5, "data", logicview.pyformat("Data Field: {0} / 0x{0:04X}", { diagnostic_data }, logicview.dict({})))
  self:check_crc(7)
end
function Modbus_ADU.parse_mask_write_register(self)
  local data, address, and_mask_1, and_mask_2, or_mask_1, or_mask_2
  self.minimum_length = 10
  data = self.data
  self:puti(1, "function", "Function 22: Mask Write Register")
  address = self:half_word(2)
  self:puti(3, "address", logicview.pyformat("Address 0x{:X} / {:d}", { address, logicview.add(address, 30001) }, logicview.dict({})))
  self:half_word(4)
  and_mask_1 = logicview.idx(data, 4).data
  and_mask_2 = logicview.idx(data, 5).data
  self:puti(5, "data", logicview.pyformat("AND mask: {:08b} {:08b}", { and_mask_1, and_mask_2 }, logicview.dict({})))
  self:half_word(6)
  or_mask_1 = logicview.idx(data, 6).data
  or_mask_2 = logicview.idx(data, 7).data
  self:puti(7, "data", logicview.pyformat("OR mask: {:08b} {:08b}", { or_mask_1, or_mask_2 }, logicview.dict({})))
  self:check_crc(9)
end
function Modbus_ADU.parse_not_implemented(self)
  local function_, functionname
  function_ = logicview.idx(self.data, 1).data
  functionname = logicview.idx(logicview.dict({ [20] = "Read File Record", [21] = "Write File Record", [24] = "Read FIFO Queue", [43] = "Read Device Identification/Encapsulated Interface Transport" }), function_)
  self:puti(1, "function", logicview.pyformat("Function {}: {} (not supported)", { function_, functionname }, logicview.dict({})))
  self:putl("data", "This function is not currently supported")
end
function Modbus_ADU.new(...)
  local self = _setmetatable({}, Modbus_ADU)
  Modbus_ADU.__init__(self, ...)
  return self
end
Modbus_ADU_SC = {}
Modbus_ADU_SC.__index = Modbus_ADU_SC
_setmetatable(Modbus_ADU_SC, { __index = Modbus_ADU })
function Modbus_ADU_SC.parse(self)
  local data, server_id, message, function_
  data = self.data
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      server_id = logicview.idx(data, 0).data
      if logicview.truth(((1 <= server_id) and (server_id <= 247))) then
        message = logicview.pyformat("Slave ID: {}", { server_id }, logicview.dict({}))
      else
        message = "Slave ID {} is invalid"
      end
      self:puti(0, "server-id", message)
      function_ = logicview.idx(data, 1).data
      if logicview.truth((function()
  local _v
  _v = logicview.eq(function_, 1)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(function_, 2)
  return _v
end)()) then
        self:parse_read_bits()
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(function_, 3)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(function_, 4)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(function_, 23)
  return _v
end)()) then
        self:parse_read_registers()
      elseif logicview.truth(logicview.eq(function_, 5)) then
        self:parse_write_single_coil()
      elseif logicview.truth(logicview.eq(function_, 6)) then
        self:parse_write_single_register()
      elseif logicview.truth(logicview.eq(function_, 7)) then
        self:parse_read_exception_status()
      elseif logicview.truth(logicview.eq(function_, 8)) then
        self:parse_diagnostics()
      elseif logicview.truth(logicview.eq(function_, 11)) then
        self:parse_get_comm_event_counter()
      elseif logicview.truth(logicview.eq(function_, 12)) then
        self:parse_get_comm_event_log()
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(function_, 15)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(function_, 16)
  return _v
end)()) then
        self:parse_write_multiple()
      elseif logicview.truth(logicview.eq(function_, 17)) then
        self:parse_report_server_id()
      elseif logicview.truth(logicview.eq(function_, 22)) then
        self:parse_mask_write_register()
      elseif logicview.truth(logicview.contains({ 21, 21, 24, 43 }, function_)) then
        self:parse_not_implemented()
      elseif logicview.truth((function_ > 128)) then
        self:parse_error()
      else
        self:puti(1, "error", logicview.pyformat("Unknown function: {}", { logicview.idx(data, 1).data }, logicview.dict({})))
        self:putl("error", "Unknown function")
      end
      self:putl("error", "Message too long")
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "No_more_data") then
      else
        _error(_err, 0)
      end
    end
  end
end
function Modbus_ADU_SC.parse_read_bits(self)
  local data, function_, bytecount
  self.mimumum_length = 5
  data = self.data
  function_ = logicview.idx(data, 1).data
  if logicview.truth(logicview.eq(function_, 1)) then
    self:puti(1, "function", "Function 1: Read Coils")
  else
    self:puti(1, "function", "Function 2: Read Discrete Inputs")
  end
  bytecount = logicview.idx(self.data, 2).data
  self.minimum_length = logicview.add(5, bytecount)
  self:puti(2, "length", logicview.pyformat("Byte count: {}", { bytecount }, logicview.dict({})))
  self:putl("data", "{:08b}", logicview.add(bytecount, 2))
  self:check_crc(logicview.add(bytecount, 4))
end
function Modbus_ADU_SC.parse_read_registers(self)
  local data, function_, bytecount, register_value
  self.mimumum_length = 5
  data = self.data
  function_ = logicview.idx(data, 1).data
  if logicview.truth(logicview.eq(function_, 3)) then
    self:puti(1, "function", "Function 3: Read Holding Registers")
  elseif logicview.truth(logicview.eq(function_, 4)) then
    self:puti(1, "function", "Function 4: Read Input Registers")
  elseif logicview.truth(logicview.eq(function_, 23)) then
    self:puti(1, "function", "Function 23: Read/Write Multiple Registers")
  end
  bytecount = logicview.idx(self.data, 2).data
  self.minimum_length = logicview.add(5, bytecount)
  if logicview.truth(logicview.eq(logicview.pymod(bytecount, 2), 0)) then
    self:puti(2, "length", logicview.pyformat("Byte count: {}", { bytecount }, logicview.dict({})))
  else
    self:puti(2, "error", logicview.pyformat("Error: Odd byte count ({})", { bytecount }, logicview.dict({})))
  end
  if logicview.truth(logicview.eq(logicview.pymod(logicview.len(data), 2), 1)) then
    register_value = self:half_word((-2))
    self:putl("data", logicview.pyformat("0x{0:04X} / {0}", { register_value }, logicview.dict({})), logicview.add(bytecount, 2))
  else
    _error(No_more_data, 0)
  end
  self:check_crc(logicview.add(bytecount, 4))
end
function Modbus_ADU_SC.parse_read_exception_status(self)
  local exception_status
  self.mimumum_length = 5
  self:puti(1, "function", "Function 7: Read Exception Status")
  exception_status = logicview.idx(self.data, 2).data
  self:puti(2, "data", logicview.pyformat("Exception status: {:08b}", { exception_status }, logicview.dict({})))
  self:check_crc(4)
end
function Modbus_ADU_SC.parse_get_comm_event_counter(self)
  local status, count
  self.mimumum_length = 8
  self:puti(1, "function", "Function 11: Get Comm Event Counter")
  status = self:half_word(2)
  if logicview.truth(logicview.eq(status, 0)) then
    self:puti(3, "data", "Status: not busy")
  elseif logicview.truth(logicview.eq(status, 65535)) then
    self:puti(3, "data", "Status: busy")
  else
    self:puti(3, "error", logicview.pyformat("Bad status: 0x{:04X}", { status }, logicview.dict({})))
  end
  count = self:half_word(4)
  self:puti(5, "data", logicview.pyformat("Event Count: {}", { count }, logicview.dict({})))
  self:check_crc(7)
end
function Modbus_ADU_SC.parse_get_comm_event_log(self)
  local data, bytecount, status, event_count, message_count
  self.mimumum_length = 11
  self:puti(1, "function", "Function 12: Get Comm Event Log")
  data = self.data
  bytecount = logicview.idx(data, 2).data
  self:puti(2, "length", logicview.pyformat("Bytecount: {}", { bytecount }, logicview.dict({})))
  self.mimumum_length = logicview.add(5, bytecount)
  status = self:half_word(3)
  if logicview.truth(logicview.eq(status, 0)) then
    self:puti(4, "data", "Status: not busy")
  elseif logicview.truth(logicview.eq(status, 65535)) then
    self:puti(4, "data", "Status: busy")
  else
    self:puti(4, "error", logicview.pyformat("Bad status: 0x{:04X}", { status }, logicview.dict({})))
  end
  event_count = self:half_word(5)
  self:puti(6, "data", logicview.pyformat("Event Count: {}", { event_count }, logicview.dict({})))
  message_count = self:half_word(7)
  self:puti(8, "data", logicview.pyformat("Message Count: {}", { message_count }, logicview.dict({})))
  self:putl("data", logicview.pyformat("Event: 0x{:02X}", { logicview.idx(data, (-1)).data }, logicview.dict({})), logicview.add(bytecount, 2))
  self:check_crc(logicview.add(bytecount, 4))
end
function Modbus_ADU_SC.parse_write_multiple(self)
  local function_, data_unit, max_outputs, long_address_offset, starting_address, address_name, quantity_of_outputs
  self.mimumum_length = 8
  function_ = logicview.idx(self.data, 1).data
  if logicview.truth(logicview.eq(function_, 15)) then
    data_unit = "Coils"
    max_outputs = 1968
    long_address_offset = 10001
  elseif logicview.truth(logicview.eq(function_, 16)) then
    data_unit = "Registers"
    max_outputs = 123
    long_address_offset = 30001
  end
  self:puti(1, "function", logicview.pyformat("Function {}: Write Multiple {}", { function_, data_unit }, logicview.dict({})))
  starting_address = self:half_word(2)
  address_name = logicview.add(long_address_offset, starting_address)
  self:puti(3, "address", logicview.pyformat("Start at address 0x{:X} / {:d}", { starting_address, address_name }, logicview.dict({})))
  quantity_of_outputs = self:half_word(4)
  if logicview.truth((quantity_of_outputs <= max_outputs)) then
    self:puti(5, "data", logicview.pyformat("Write {} {}", { quantity_of_outputs, data_unit }, logicview.dict({})))
  else
    self:puti(5, "error", logicview.pyformat("Bad value: {} {}. Max is {}", { quantity_of_outputs, data_unit, max_outputs }, logicview.dict({})))
  end
  self:check_crc(7)
end
function Modbus_ADU_SC.parse_report_server_id(self)
  local data, bytecount, run_indicator_status
  self.mimumum_length = 7
  data = self.data
  self:puti(1, "function", "Function 17: Report Server ID")
  bytecount = logicview.idx(data, 2).data
  self:puti(2, "length", logicview.pyformat("Data is {} bytes long", { bytecount }, logicview.dict({})))
  self:puti(3, "data", logicview.pyformat("serverID: {}", { logicview.idx(data, 3).data }, logicview.dict({})))
  run_indicator_status = logicview.idx(data, 4).data
  if logicview.truth(logicview.eq(run_indicator_status, 0)) then
    self:puti(4, "data", "Run Indicator status: Off")
  elseif logicview.truth(logicview.eq(run_indicator_status, 255)) then
    self:puti(4, "data", "Run Indicator status: On")
  else
    self:puti(4, "error", logicview.pyformat("Bad Run Indicator status: 0x{:X}", { run_indicator_status }, logicview.dict({})))
  end
  self:putl("data", logicview.pyformat("Device specific data: {}, \"{}\"", { logicview.idx(data, (-1)).data, _string.char(logicview.idx(data, (-1)).data) }, logicview.dict({})), logicview.add(2, bytecount))
  self:check_crc(logicview.add(4, bytecount))
end
function Modbus_ADU_SC.parse_error(self)
  local functioncode, functions, functionname, error, errorcodes, errorname
  self.mimumum_length = 5
  functioncode = (logicview.idx(self.data, 1).data - 128)
  functions = logicview.dict({ [1] = "Read Coils", [2] = "Read Discrete Inputs", [3] = "Read Holding Registers", [4] = "Read Input Registers", [5] = "Write Single Coil", [6] = "Write Single Register", [7] = "Read Exception Status", [8] = "Diagnostic", [11] = "Get Com Event Counter", [12] = "Get Com Event Log", [15] = "Write Multiple Coils", [16] = "Write Multiple Registers", [17] = "Report Slave ID", [20] = "Read File Record", [21] = "Write File Record", [22] = "Mask Write Register", [23] = "Read/Write Multiple Registers", [24] = "Read FIFO Queue", [43] = "Read Device Identification/Encapsulated Interface Transport" })
  functionname = logicview.pyformat("{}: {}", { functioncode, logicview.dget(functions, functioncode, "Unknown function") }, logicview.dict({}))
  self:puti(1, "function", logicview.pyformat("Error for function {}", { functionname }, logicview.dict({})))
  error = logicview.idx(self.data, 2).data
  errorcodes = logicview.dict({ [1] = "Illegal Function", [2] = "Illegal Data Address", [3] = "Illegal Data Value", [4] = "Slave Device Failure", [5] = "Acknowledge", [6] = "Slave Device Busy", [8] = "Memory Parity Error", [10] = "Gateway Path Unavailable", [11] = "Gateway Target Device failed to respond" })
  errorname = logicview.pyformat("{}: {}", { error, logicview.dget(errorcodes, error, "Unknown") }, logicview.dict({}))
  self:puti(2, "data", logicview.pyformat("Error {}", { errorname }, logicview.dict({})))
  self:check_crc(4)
end
function Modbus_ADU_SC.new(...)
  local self = _setmetatable({}, Modbus_ADU_SC)
  return self
end
Modbus_ADU_CS = {}
Modbus_ADU_CS.__index = Modbus_ADU_CS
_setmetatable(Modbus_ADU_CS, { __index = Modbus_ADU })
function Modbus_ADU_CS.parse(self)
  local data, server_id, message, function_
  data = self.data
  do
    local _lv_return = false
    local _lv_value = nil
    local _ok, _err = _pcall(function()
      server_id = logicview.idx(data, 0).data
      message = ""
      if logicview.truth(logicview.eq(server_id, 0)) then
        message = "Broadcast message"
      elseif logicview.truth(((1 <= server_id) and (server_id <= 247))) then
        message = logicview.pyformat("Slave ID: {}", { server_id }, logicview.dict({}))
      elseif logicview.truth(((248 <= server_id) and (server_id <= 255))) then
        message = logicview.pyformat("Slave ID: {} (reserved address)", { server_id }, logicview.dict({}))
      end
      self:puti(0, "server-id", message)
      function_ = logicview.idx(data, 1).data
      if logicview.truth((function()
  local _v
  _v = (function_ >= 1)
  if not logicview.truth(_v) then return _v end
  _v = (function_ <= 4)
  return _v
end)()) then
        self:parse_read_data_command()
      end
      if logicview.truth(logicview.eq(function_, 5)) then
        self:parse_write_single_coil()
      end
      if logicview.truth(logicview.eq(function_, 6)) then
        self:parse_write_single_register()
      end
      if logicview.truth(logicview.contains({ 7, 11, 12, 17 }, function_)) then
        self:parse_single_byte_request()
      elseif logicview.truth(logicview.eq(function_, 8)) then
        self:parse_diagnostics()
      end
      if logicview.truth(logicview.contains({ 15, 16 }, function_)) then
        self:parse_write_multiple()
      elseif logicview.truth(logicview.eq(function_, 22)) then
        self:parse_mask_write_register()
      elseif logicview.truth(logicview.eq(function_, 23)) then
        self:parse_read_write_registers()
      elseif logicview.truth(logicview.contains({ 21, 21, 24, 43 }, function_)) then
        self:parse_not_implemented()
      else
        self:puti(1, "error", logicview.pyformat("Unknown function: {}", { logicview.idx(data, 1).data }, logicview.dict({})))
        self:putl("error", "Unknown function")
      end
      self:putl("error", "Message too long")
    end)
    if _lv_return then return _lv_value end
    if not _ok then
      if (_type(_err) == 'table' and _err._exc == "No_more_data") then
      else
        _error(_err, 0)
      end
    end
  end
end
function Modbus_ADU_CS.parse_read_data_command(self)
  local data, function_, functionname, starting_address, address_name
  data = self.data
  self.minimum_length = 8
  function_ = logicview.idx(data, 1).data
  functionname = logicview.idx(logicview.dict({ [1] = "Read Coils", [2] = "Read Discrete Inputs", [3] = "Read Holding Registers", [4] = "Read Input Registers" }), function_)
  self:puti(1, "function", logicview.pyformat("Function {}: {}", { function_, functionname }, logicview.dict({})))
  starting_address = self:half_word(2)
  address_name = logicview.add(logicview.add(logicview.mul(10000, function_), 1), starting_address)
  self:puti(3, "address", logicview.pyformat("Start at address 0x{:X} / {:d}", { starting_address, address_name }, logicview.dict({})))
  self:puti(5, "length", logicview.pyformat("Read {:d} units of data", { self:half_word(4) }, logicview.dict({})))
  self:check_crc(7)
end
function Modbus_ADU_CS.parse_single_byte_request(self)
  local function_, function_name
  function_ = logicview.idx(self.data, 1).data
  function_name = logicview.idx(logicview.dict({ [7] = "Read Exception Status", [11] = "Get Comm Event Counter", [12] = "Get Comm Event Log", [17] = "Report Slave ID" }), function_)
  self:puti(1, "function", logicview.pyformat("Function {}: {}", { function_, function_name }, logicview.dict({})))
  self:check_crc(3)
end
function Modbus_ADU_CS.parse_write_multiple(self)
  local function_, data_unit, max_outputs, ratio_bytes_data, long_address_offset, starting_address, address_name, quantity_of_outputs, proper_bytecount, bytecount
  self.mimumum_length = 9
  function_ = logicview.idx(self.data, 1).data
  if logicview.truth(logicview.eq(function_, 15)) then
    data_unit = "Coils"
    max_outputs = 1968
    ratio_bytes_data = (1 / 8)
    long_address_offset = 10001
  elseif logicview.truth(logicview.eq(function_, 16)) then
    data_unit = "Registers"
    max_outputs = 123
    ratio_bytes_data = 2
    long_address_offset = 30001
  end
  self:puti(1, "function", logicview.pyformat("Function {}: Write Multiple {}", { function_, data_unit }, logicview.dict({})))
  starting_address = self:half_word(2)
  address_name = logicview.add(long_address_offset, starting_address)
  self:puti(3, "address", logicview.pyformat("Start at address 0x{:X} / {:d}", { starting_address, address_name }, logicview.dict({})))
  quantity_of_outputs = self:half_word(4)
  if logicview.truth((quantity_of_outputs <= max_outputs)) then
    self:puti(5, "length", logicview.pyformat("Write {} {}", { quantity_of_outputs, data_unit }, logicview.dict({})))
  else
    self:puti(5, "error", logicview.pyformat("Bad value: {} {}. Max is {}", { quantity_of_outputs, data_unit, max_outputs }, logicview.dict({})))
  end
  proper_bytecount = ceil(logicview.mul(quantity_of_outputs, ratio_bytes_data))
  bytecount = logicview.idx(self.data, 6).data
  if logicview.truth(logicview.eq(bytecount, proper_bytecount)) then
    self:puti(6, "length", logicview.pyformat("Byte count: {}", { bytecount }, logicview.dict({})))
  else
    self:puti(6, "error", logicview.pyformat("Bad byte count, is {}, should be {}", { bytecount, proper_bytecount }, logicview.dict({})))
  end
  self.mimumum_length = logicview.add(bytecount, 9)
  self:putl("data", "Value 0x{:X}", logicview.add(6, bytecount))
  self:check_crc(logicview.add(bytecount, 8))
end
function Modbus_ADU_CS.parse_read_file_record(self)
  local data, bytecount, current_byte, step, file_number, record_number, records_to_read
  self:puti(1, "function", "Function 20: Read file records")
  data = self.data
  bytecount = logicview.idx(data, 2).data
  self.minimum_length = logicview.add(5, bytecount)
  if logicview.truth(((7 <= bytecount) and (bytecount <= 245))) then
    self:puti(2, "length", logicview.pyformat("Request is {} bytes long", { bytecount }, logicview.dict({})))
  else
    self:puti(2, "error", logicview.pyformat("Request claims to be {} bytes long, legal values are between 7 and 247", { bytecount }, logicview.dict({})))
  end
  current_byte = (logicview.len(data) - 1)
  if logicview.truth((current_byte <= logicview.add(bytecount, 2))) then
    step = logicview.pymod((current_byte - 3), 7)
    if logicview.truth(logicview.eq(step, 0)) then
      if logicview.truth(logicview.eq(logicview.idx(data, current_byte).data, 6)) then
        self:puti(current_byte, "data", "Start sub-request")
      else
        self:puti(current_byte, "error", "First byte of subrequest should be 0x06")
      end
    elseif logicview.truth(logicview.eq(step, 1)) then
      _error(No_more_data, 0)
    elseif logicview.truth(logicview.eq(step, 2)) then
      file_number = self:half_word((current_byte - 1))
      self:puti(current_byte, "data", logicview.pyformat("Read File number {}", { file_number }, logicview.dict({})))
    elseif logicview.truth(logicview.eq(step, 3)) then
      _error(No_more_data, 0)
    elseif logicview.truth(logicview.eq(step, 4)) then
      record_number = self:half_word((current_byte - 1))
      self:puti(current_byte, "address", logicview.pyformat("Read from record number {}", { record_number }, logicview.dict({})))
    elseif logicview.truth(logicview.eq(step, 5)) then
      _error(No_more_data, 0)
    elseif logicview.truth(logicview.eq(step, 6)) then
      records_to_read = self:half_word((current_byte - 1))
      self:puti(current_byte, "length", logicview.pyformat("Read {} records", { records_to_read }, logicview.dict({})))
    end
  end
  self:check_crc(logicview.add(4, bytecount))
end
function Modbus_ADU_CS.parse_read_write_registers(self)
  local starting_address, address_name, quantity_of_outputs, proper_bytecount, bytecount
  self.minimum_length = 13
  self:puti(1, "function", "Function 23: Read/Write Multiple Registers")
  starting_address = self:half_word(2)
  address_name = logicview.add(30001, starting_address)
  self:puti(3, "address", logicview.pyformat("Read starting at address 0x{:X} / {:d}", { starting_address, address_name }, logicview.dict({})))
  self:puti(5, "length", logicview.pyformat("Read {:d} units of data", { self:half_word(4) }, logicview.dict({})))
  starting_address = self:half_word(6)
  self:puti(7, "address", logicview.pyformat("Write starting at address 0x{:X} / {:d}", { starting_address, address_name }, logicview.dict({})))
  quantity_of_outputs = self:half_word(8)
  self:puti(9, "length", logicview.pyformat("Write {} registers", { quantity_of_outputs }, logicview.dict({})))
  proper_bytecount = logicview.mul(quantity_of_outputs, 2)
  bytecount = logicview.idx(self.data, 10).data
  if logicview.truth(logicview.eq(bytecount, proper_bytecount)) then
    self:puti(10, "length", logicview.pyformat("Byte count: {}", { bytecount }, logicview.dict({})))
  else
    self:puti(10, "error", logicview.pyformat("Bad byte count, is {}, should be {}", { bytecount, proper_bytecount }, logicview.dict({})))
  end
  self.mimumum_length = logicview.add(bytecount, 13)
  self:putl("data", "Data, value 0x{:02X}", logicview.add(10, bytecount))
  self:check_crc(logicview.add(bytecount, 12))
end
function Modbus_ADU_CS.new(...)
  local self = _setmetatable({}, Modbus_ADU_CS)
  return self
end
_decoder = {
  api_version = 3,
  id = "modbus",
  name = "Modbus",
  longname = "Modbus RTU over RS232/RS485",
  desc = "Modbus RTU protocol for industrial applications.",
  license = "gplv3+",
  inputs = { "uart" },
  outputs = { "modbus" },
  tags = { "Embedded/industrial" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "scchannel", desc = "Server -> client channel", default = "RX", values = { "RX", "TX" } }), logicview.dict({ id = "cschannel", desc = "Client -> server channel", default = "TX", values = { "RX", "TX" } }), logicview.dict({ id = "framegap", desc = "Inter-frame bit gap", default = 28, values = {  } }) },
  annotations = { { "sc-server-id", "SC server ID" }, { "sc-function", "SC function" }, { "sc-crc", "SC CRC" }, { "sc-address", "SC address" }, { "sc-data", "SC data" }, { "sc-length", "SC length" }, { "sc-error", "SC error" }, { "cs-server-id", "CS server ID" }, { "cs-function", "CS function" }, { "cs-crc", "CS CRC" }, { "cs-address", "CS address" }, { "cs-data", "CS data" }, { "cs-length", "CS length" }, { "cs-error", "CS error" }, { "error-indication", "Error indication" } },
  annotation_rows = { { "sc", "Server->client", { 0, 1, 2, 3, 4, 5, 6 } }, { "cs", "Client->server", { 7, 8, 9, 10, 11, 12, 13 } }, { "error-indicators", "Errors in frame", { 14 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.ADUSc = nil
  self.ADUCs = nil
  self.bitlength = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.puta(self, start, end_, ann_str, message)
  local ann
  ann = (function() if _type((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.annotations) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(s, 0)
  end
  return _lv_out
end)()) == 'string' then local _n = logicview.find((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.annotations) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(s, 0)
  end
  return _lv_out
end)(), ann_str); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.annotations) do
    s = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(s, 0)
  end
  return _lv_out
end)(), ann_str) end)()
  self:put(start, end_, self.out_ann, { ann, { message } })
end
function _decoder.decode_adu(self, ss, es, data, direction)
  local ptype, rxtx, pdata, ADU
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
  if logicview.truth((self.bitlength == nil)) then
    if logicview.truth((function()
  local _v
  _v = logicview.eq(ptype, "STARTBIT")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(ptype, "STOPBIT")
  return _v
end)()) then
      self.bitlength = (es - ss)
    else
      return
    end
  end
  if logicview.truth(logicview.eq(direction, "Sc")) then
    if logicview.truth((function()
  local _v
  _v = (self.ADUSc == nil)
  if logicview.truth(_v) then return _v end
  _v = self.ADUSc.startNewFrame
  return _v
end)()) then
      self.ADUSc = Modbus_ADU_SC.new(self, ss, TX, "sc-")
    end
    ADU = self.ADUSc
  end
  if logicview.truth(logicview.eq(direction, "Cs")) then
    if logicview.truth((function()
  local _v
  _v = (self.ADUCs == nil)
  if logicview.truth(_v) then return _v end
  _v = self.ADUCs.startNewFrame
  return _v
end)()) then
      self.ADUCs = Modbus_ADU_CS.new(self, ss, TX, "cs-")
    end
    ADU = self.ADUCs
  end
  if logicview.truth(((ss - ADU.last_read) <= logicview.mul(self.bitlength, logicview.idx(self.options, "framegap")))) then
    ADU:add_data(ss, es, data)
  else
    if logicview.truth((logicview.len(ADU.data) > 0)) then
      ADU:close(logicview.add(logicview.idx(ADU.data, (-1))["end"], logicview.mul(self.bitlength, 3)))
    end
    ADU.startNewFrame = true
    self:decode_adu(ss, es, data, direction)
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata
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
    if logicview.truth((not logicview.contains({ "STARTBIT", "DATA", "STOPBIT" }, ptype))) then
      return
    end
    if logicview.truth(logicview.eq(logicview.idx(rxtx_channels, rxtx), logicview.idx(self.options, "scchannel"))) then
      self:decode_adu(ss, es, data, "Sc")
    end
    if logicview.truth(logicview.eq(logicview.idx(rxtx_channels, rxtx), logicview.idx(self.options, "cschannel"))) then
      self:decode_adu(ss, es, data, "Cs")
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
