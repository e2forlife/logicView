-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: mit
-- Copyright (C) 2020 Jorge Solla Rubiales <jorgesolla@gmail.com>
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
local SrdIntEnum, CFG_REGS, CHN_CFG, STAT_REG, Ann, Decoder
local _decoder

CFG_REGS = logicview.dict({ [0] = { logicview.dict({ name = "CH_NO", stbit = 7, nbits = 8 }) }, [1] = { logicview.dict({ name = "AUTO_RETRAN", stbit = 5, nbits = 1, opts = logicview.dict({ [0] = "No retransmission", [1] = "Retransmission of data packet" }) }), logicview.dict({ name = "RX_RED_PWR", stbit = 4, nbits = 1, opts = logicview.dict({ [0] = "Normal operation", [1] = "Reduced power" }) }), logicview.dict({ name = "PA_PWR", stbit = 3, nbits = 2, opts = logicview.dict({ [0] = "-10 dBm", [1] = "-2 dBm", [2] = "+6 dBm", [3] = "+10 dBm" }) }), logicview.dict({ name = "HFREQ_PLL", stbit = 1, nbits = 1, opts = logicview.dict({ [0] = "433 MHz", [1] = "868 / 915 MHz" }) }), logicview.dict({ name = "CH_NO_8", stbit = 0, nbits = 1 }) }, [2] = { logicview.dict({ name = "TX_AFW (TX addr width)", stbit = 6, nbits = 3 }), logicview.dict({ name = "RX_AFW (RX addr width)", stbit = 2, nbits = 3 }) }, [3] = { logicview.dict({ name = "RW_PW (RX payload width)", stbit = 5, nbits = 6 }) }, [4] = { logicview.dict({ name = "TX_PW (TX payload width)", stbit = 5, nbits = 6 }) }, [5] = { logicview.dict({ name = "RX_ADDR_0", stbit = 7, nbits = 8 }) }, [6] = { logicview.dict({ name = "RX_ADDR_1", stbit = 7, nbits = 8 }) }, [7] = { logicview.dict({ name = "RX_ADDR_2", stbit = 7, nbits = 8 }) }, [8] = { logicview.dict({ name = "RX_ADDR_3", stbit = 7, nbits = 8 }) }, [9] = { logicview.dict({ name = "CRC_MODE", stbit = 7, nbits = 1, opts = logicview.dict({ [0] = "8 CRC check bit", [1] = "16 CRC check bit" }) }), logicview.dict({ name = "CRC_EN", stbit = 6, nbits = 1, opts = logicview.dict({ [0] = "Disabled", [1] = "Enabled" }) }), logicview.dict({ name = "XOR", stbit = 5, nbits = 3, opts = logicview.dict({ [0] = "4 MHz", [1] = "8 MHz", [2] = "12 MHz", [3] = "16 MHz", [4] = "20 MHz" }) }), logicview.dict({ name = "UP_CLK_EN", stbit = 2, nbits = 1, opts = logicview.dict({ [0] = "No external clock signal avail.", [1] = "External clock signal enabled" }) }), logicview.dict({ name = "UP_CLK_FREQ", stbit = 1, nbits = 2, opts = logicview.dict({ [0] = "4 MHz", [1] = "2 MHz", [2] = "1 MHz", [3] = "500 kHz" }) }) } })
CHN_CFG = { logicview.dict({ name = "PA_PWR", stbit = 3, nbits = 2, opts = logicview.dict({ [0] = "-10 dBm", [1] = "-2 dBm", [2] = "+6 dBm", [3] = "+10 dBm" }) }), logicview.dict({ name = "HFREQ_PLL", stbit = 1, nbits = 1, opts = logicview.dict({ [0] = "433 MHz", [1] = "868 / 915 MHz" }) }) }
STAT_REG = { logicview.dict({ name = "AM", stbit = 7, nbits = 1 }), logicview.dict({ name = "DR", stbit = 5, nbits = 1 }) }
Ann = logicview.int_enum(logicview.split("CMD REG_WR REG_RD TX RX RESP WARN", ' '))
_decoder = {
  api_version = 3,
  id = "nrf905",
  name = "nRF905",
  longname = "Nordic Semiconductor nRF905",
  desc = "433/868/933MHz transceiver chip.",
  license = "mit",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "cmd", "Command sent to the device" }, { "reg-write", "Config register written to the device" }, { "reg-read", "Config register read from the device" }, { "tx-data", "Payload sent to the device" }, { "rx-data", "Payload read from the device" }, { "resp", "Response to commands received from the device" }, { "warning", "Warning" } },
  annotation_rows = { { "commands", "Commands", { 0 } }, { "responses", "Responses", { 5 } }, { "registers", "Registers", { 1, 2 } }, { "tx", "Transmitted data", { 3 } }, { "rx", "Received data", { 4 } }, { "warnings", "Warnings", { 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self.cs_asserted = false
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bytes = _lv_a0
    self.miso_bytes = _lv_a1
  end
  self.cmd_samples = logicview.dict({ ss = 0, es = 0 })
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.extract_bits(self, byte, start_bit, num_bits)
  local begin, end_, binary
  begin = (7 - start_bit)
  end_ = logicview.add(begin, num_bits)
  if logicview.truth((function()
  local _v
  _v = (begin < 0)
  if logicview.truth(_v) then return _v end
  _v = (end_ > 8)
  return _v
end)()) then
    return 0
  end
  binary = logicview.slice(logicview.format(byte, "08b"), begin, end_, nil)
  return logicview.tointeger(binary, 2)
end
function _decoder.extract_vars(self, reg_vars, reg_value)
  local data, var, var_value, opt
  data = ""
  for _lv_item in logicview.iter(reg_vars) do
    var = _lv_item
    var_value = self:extract_bits(reg_value, logicview.idx(var, "stbit"), logicview.idx(var, "nbits"))
    data = logicview.add(data, logicview.add(logicview.add(logicview.idx(var, "name"), " = "), _tostring(var_value)))
    opt = ""
    if logicview.truth(logicview.contains(var, "opts")) then
      opt = logicview.dget(logicview.idx(var, "opts"), var_value, "unknown")
      data = logicview.add(data, logicview.add(logicview.add(" (", opt), ")"))
    end
    if logicview.truth((not logicview.eq((function() if _type(reg_vars) == 'string' then local _n = logicview.find(reg_vars, var); if _n < 0 then _error('missing') end; return _n end; return logicview.list_index(reg_vars, var) end)(), (logicview.len(reg_vars) - 1)))) then
      data = logicview.add(data, " | ")
    end
    ::continue_1::
  end
  return data
end
function _decoder.parse_config_register(self, addr, value, is_write)
  local reg_value, data, reg_vars, ann
  reg_value = logicview.idx(value, 0)
  data = logicview.add(logicview.add("CFG_REG[", logicview.hex(addr)), "] -> ")
  if logicview.truth(logicview.contains(CFG_REGS, addr)) then
    reg_vars = logicview.idx(CFG_REGS, addr)
  else
    self:put(logicview.idx(value, 1), logicview.idx(value, 2), self.out_ann, { Ann.WARN, { "Invalid reg. addr" } })
    return
  end
  data = logicview.add(data, self:extract_vars(reg_vars, reg_value))
  ann = (function() if logicview.truth(is_write) then return Ann.REG_WR else return Ann.REG_RD end end)()
  self:put(logicview.idx(value, 1), logicview.idx(value, 2), self.out_ann, { ann, { data } })
end
function _decoder.parse_config_registers(self, addr, registers, is_write)
  local i, reg_addr
  i = 0
  while logicview.truth((i < logicview.len(registers))) do
    reg_addr = logicview.add(i, addr)
    if logicview.truth((reg_addr <= 9)) then
      self:parse_config_register(reg_addr, logicview.idx(registers, i), is_write)
    end
    i = logicview.add(i, 1)
    ::continue_2::
  end
end
function _decoder.dump_cmd_bytes(self, prefix, cmd_bytes, ann)
  local ss, es, data, byte
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(cmd_bytes, 1), 1), 0
    ss = _lv_a0
    es = _lv_a1
  end
  data = ""
  for _lv_item in logicview.iter(logicview.slice(cmd_bytes, 1, nil, nil)) do
    byte = _lv_item
    data = logicview.add(data, logicview.add(logicview.format(logicview.idx(byte, 0), "02X"), " "))
    es = logicview.idx(byte, 2)
    ::continue_3::
  end
  self:put(ss, es, self.out_ann, { ann, { logicview.add(prefix, "{$}"), logicview.add("@", data) } })
end
function _decoder.handle_WC(self)
  local start_addr
  start_addr = (logicview.idx(logicview.idx(self.mosi_bytes, 0), 0) & 15)
  if logicview.truth((start_addr > 9)) then
    return
  end
  self:parse_config_registers(start_addr, logicview.slice(self.mosi_bytes, 1, nil, nil), true)
end
function _decoder.handle_RC(self)
  local start_addr
  start_addr = (logicview.idx(logicview.idx(self.mosi_bytes, 0), 0) & 15)
  if logicview.truth((start_addr > 9)) then
    return
  end
  self:parse_config_registers(start_addr, logicview.slice(self.miso_bytes, 1, nil, nil), false)
end
function _decoder.handle_WTP(self)
  self:dump_cmd_bytes("Write TX payload.: ", self.mosi_bytes, Ann.TX)
end
function _decoder.handle_RTP(self)
  self:dump_cmd_bytes("Read TX payload: ", self.miso_bytes, Ann.RESP)
end
function _decoder.handle_WTA(self)
  self:dump_cmd_bytes("Write TX addr: ", self.mosi_bytes, Ann.REG_WR)
end
function _decoder.handle_RTA(self)
  self:dump_cmd_bytes("Read TX addr: ", self.miso_bytes, Ann.RESP)
end
function _decoder.handle_RRP(self)
  self:dump_cmd_bytes("Read RX payload: ", self.miso_bytes, Ann.RX)
end
function _decoder.handle_CC(self)
  local cmd, dta, channel, data
  do
    local _lv_a0, _lv_a1 = logicview.idx(self.mosi_bytes, 0), logicview.idx(self.mosi_bytes, 1)
    cmd = _lv_a0
    dta = _lv_a1
  end
  channel = logicview.add(((logicview.idx(cmd, 0) & 1) << 8), logicview.idx(dta, 0))
  data = self:extract_vars(CHN_CFG, logicview.idx(cmd, 0))
  data = logicview.add(data, logicview.add("| CHN = ", _tostring(channel)))
  self:put(logicview.idx(logicview.idx(self.mosi_bytes, 0), 1), logicview.idx(logicview.idx(self.mosi_bytes, 1), 2), self.out_ann, { Ann.REG_WR, { data } })
end
function _decoder.handle_STAT(self)
  local status
  status = logicview.add("STAT = ", self:extract_vars(STAT_REG, logicview.idx(logicview.idx(self.miso_bytes, 0), 0)))
  self:put(logicview.idx(logicview.idx(self.miso_bytes, 0), 1), logicview.idx(logicview.idx(self.miso_bytes, 0), 2), self.out_ann, { Ann.REG_RD, { status } })
end
function _decoder.process_cmd(self)
  local cmd, cmd_name, cmd_hnd, byte
  do
    local _lv_a0, _lv_a1, _lv_a2 = "", "", nil
    cmd = _lv_a0
    cmd_name = _lv_a1
    cmd_hnd = _lv_a2
  end
  for _lv_item in logicview.iter(self.mosi_bytes) do
    byte = _lv_item
    cmd = logicview.add(cmd, logicview.add(logicview.hex(logicview.idx(byte, 0)), " "))
    ::continue_4::
  end
  cmd = logicview.idx(logicview.idx(self.mosi_bytes, 0), 0)
  if logicview.truth(logicview.eq((cmd & 240), 0)) then
    do
      local _lv_a0, _lv_a1 = "CMD: W_CONFIG (WC)", self.handle_WC
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq((cmd & 240), 16)) then
    do
      local _lv_a0, _lv_a1 = "CMD: R_CONFIG (RC)", self.handle_RC
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq(cmd, 32)) then
    do
      local _lv_a0, _lv_a1 = "CMD: W_TX_PAYLOAD (WTP)", self.handle_WTP
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq(cmd, 33)) then
    do
      local _lv_a0, _lv_a1 = "CMD: R_TX_PAYLOAD (RTP)", self.handle_RTP
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq(cmd, 34)) then
    do
      local _lv_a0, _lv_a1 = "CMD: W_TX_ADDRESS (WTA)", self.handle_WTA
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq(cmd, 35)) then
    do
      local _lv_a0, _lv_a1 = "CMD: R_TX_ADDRESS (RTA)", self.handle_RTA
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq(cmd, 36)) then
    do
      local _lv_a0, _lv_a1 = "CMD: R_RX_PAYLOAD (RRP)", self.handle_RRP
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  elseif logicview.truth(logicview.eq((cmd & 240), 128)) then
    do
      local _lv_a0, _lv_a1 = "CMD: CHANNEL_CONFIG (CC)", self.handle_CC
      cmd_name = _lv_a0
      cmd_hnd = _lv_a1
    end
  end
  self:put(logicview.idx(self.cmd_samples, "ss"), logicview.idx(self.cmd_samples, "es"), self.out_ann, { Ann.CMD, { cmd_name } })
  self:handle_STAT()
  if logicview.truth((cmd_hnd ~= nil)) then
    cmd_hnd()
  end
end
function _decoder.set_cs_status(self, sample, asserted)
  if logicview.truth(logicview.eq(self.cs_asserted, asserted)) then
    return
  end
  if logicview.truth(asserted) then
    logicview.setidx(self.cmd_samples, "ss", sample)
    logicview.setidx(self.cmd_samples, "es", (-1))
  else
    logicview.setidx(self.cmd_samples, "es", sample)
  end
  self.cs_asserted = asserted
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, data1, data2, mosi, miso
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
      if logicview.truth((function()
  local _v
  _v = (data1 == nil)
  if not logicview.truth(_v) then return _v end
  _v = (data2 == nil)
  return _v
end)()) then
        self.requirements_met = false
        _error(ChannelError("CS# pin required."), 0)
      end
      if logicview.truth((function()
  local _v
  _v = (data1 == nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data2, 0)
  return _v
end)()) then
        self:set_cs_status(ss, true)
      elseif logicview.truth((function()
  local _v
  _v = (data1 == nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data2, 1)
  return _v
end)()) then
        self:set_cs_status(ss, false)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(data1, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data2, 0)
  return _v
end)()) then
        self:set_cs_status(ss, true)
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(data1, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data2, 1)
  return _v
end)()) then
        self:set_cs_status(ss, false)
        if logicview.truth(logicview.len(self.mosi_bytes)) then
          self:process_cmd()
          self:reset()
        end
      end
    elseif logicview.truth(logicview.eq(ptype, "DATA")) then
      if logicview.truth(_rawequal(self.cs_asserted, false)) then
        return
      end
      do
        local _lv_a0, _lv_a1 = data1, data2
        mosi = _lv_a0
        miso = _lv_a1
      end
      if logicview.truth((function()
  local _v
  _v = (miso == nil)
  if logicview.truth(_v) then return _v end
  _v = (mosi == nil)
  return _v
end)()) then
        _error(ChannelError("Both MISO and MOSI pins required."), 0)
      end
      _table.insert(self.mosi_bytes, { mosi, ss, es })
      _table.insert(self.miso_bytes, { miso, ss, es })
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
