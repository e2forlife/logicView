-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2014 Uwe Hermann <uwe@hermann-uwe.de>

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
local Ann, VENDOR_CODE_ATMEL, Decoder, vendor_code, part
local _decoder

vendor_code = logicview.dict({ [30] = "Atmel", [0] = "Device locked" })
part = logicview.dict({ [logicview.tkey(144, 1)] = "AT90S1200", [logicview.tkey(145, 1)] = "AT90S2313", [logicview.tkey(146, 1)] = "AT90S4414", [logicview.tkey(146, 5)] = "ATmega48", [logicview.tkey(147, 1)] = "AT90S8515", [logicview.tkey(147, 10)] = "ATmega88", [logicview.tkey(148, 6)] = "ATmega168", [logicview.tkey(255, 255)] = "Device code erased, or target missing", [logicview.tkey(1, 2)] = "Device locked" })

Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(15) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.PE = logicview.idx(_lv_seq, 0)
  Ann.RSB0 = logicview.idx(_lv_seq, 1)
  Ann.RSB1 = logicview.idx(_lv_seq, 2)
  Ann.RSB2 = logicview.idx(_lv_seq, 3)
  Ann.CE = logicview.idx(_lv_seq, 4)
  Ann.RFB = logicview.idx(_lv_seq, 5)
  Ann.RHFB = logicview.idx(_lv_seq, 6)
  Ann.REFB = logicview.idx(_lv_seq, 7)
  Ann.RLB = logicview.idx(_lv_seq, 8)
  Ann.REEM = logicview.idx(_lv_seq, 9)
  Ann.RP = logicview.idx(_lv_seq, 10)
  Ann.LPMP = logicview.idx(_lv_seq, 11)
  Ann.WP = logicview.idx(_lv_seq, 12)
  Ann.WARN = logicview.idx(_lv_seq, 13)
  Ann.DEV = logicview.idx(_lv_seq, 14)
end
VENDOR_CODE_ATMEL = 30
_decoder = {
  api_version = 3,
  id = "avr_isp",
  name = "AVR ISP",
  longname = "AVR In-System Programming",
  desc = "Atmel AVR In-System Programming (ISP) protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "pe", "Programming enable" }, { "rsb0", "Read signature byte 0" }, { "rsb1", "Read signature byte 1" }, { "rsb2", "Read signature byte 2" }, { "ce", "Chip erase" }, { "rfb", "Read fuse bits" }, { "rhfb", "Read high fuse bits" }, { "refb", "Read extended fuse bits" }, { "rlb", "Read lock bits" }, { "reem", "Read EEPROM memory" }, { "rp", "Read program memory" }, { "lpmp", "Load program memory page" }, { "wp", "Write program memory" }, { "warning", "Warning" }, { "dev", "Device" } },
  annotation_rows = { { "commands", "Commands", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 } }, { "warnings", "Warnings", { 13 } }, { "devs", "Devices", { 14 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bytes = _lv_a0
    self.miso_bytes = _lv_a1
  end
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  do
    local _lv_a0, _lv_a1, _lv_a2, _lv_a3 = 0, 0, 0, 0
    self.xx = _lv_a0
    self.yy = _lv_a1
    self.zz = _lv_a2
    self.mm = _lv_a3
  end
  self.ss_device = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.handle_cmd_programming_enable(self, cmd, ret)
  self:putx({ Ann.PE, { "Programming enable" } })
  if logicview.truth((not logicview.eq(logicview.slice(ret, 1, 4, nil), { 172, 83, logicview.idx(cmd, 2) }))) then
    self:putx({ Ann.WARN, { "Warning: Unexpected bytes in reply!" } })
  end
end
function _decoder.handle_cmd_read_signature_byte_0x00(self, cmd, ret)
  local v
  self.vendor_code = logicview.idx(ret, 3)
  v = logicview.idx(vendor_code, self.vendor_code)
  self:putx({ Ann.RSB0, { logicview.pymod("Vendor code: 0x%02x (%s)", { logicview.idx(ret, 3), v }) } })
  self.xx = logicview.idx(cmd, 1)
  self.yy = logicview.idx(cmd, 3)
  self.zz = logicview.idx(ret, 0)
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(ret, 1), 48))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 2), logicview.idx(cmd, 1)))
  return _v
end)()) then
    self:putx({ Ann.WARN, { "Warning: Unexpected bytes in reply!" } })
  end
  if logicview.truth((not logicview.eq(self.vendor_code, VENDOR_CODE_ATMEL))) then
    self:putx({ Ann.WARN, { "Warning: Vendor code was not 0x1e (Atmel)!" } })
  end
end
function _decoder.handle_cmd_read_signature_byte_0x01(self, cmd, ret)
  self.part_fam_flash_size = logicview.idx(ret, 3)
  self:putx({ Ann.RSB1, { logicview.pymod("Part family / memory size: 0x%02x", logicview.idx(ret, 3)) } })
  self.mm = logicview.idx(cmd, 3)
  self.ss_device = self.ss_cmd
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(ret, 1), 48))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 2), logicview.idx(cmd, 1)))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 0), self.yy))
  return _v
end)()) then
    self:putx({ Ann.WARN, { "Warning: Unexpected bytes in reply!" } })
  end
end
function _decoder.handle_cmd_read_signature_byte_0x02(self, cmd, ret)
  local p, data
  self.part_number = logicview.idx(ret, 3)
  self:putx({ Ann.RSB2, { logicview.pymod("Part number: 0x%02x", logicview.idx(ret, 3)) } })
  p = logicview.idx(part, logicview.tkey(self.part_fam_flash_size, self.part_number))
  data = { Ann.DEV, { logicview.pymod("Device: Atmel %s", p) } }
  self:put(self.ss_device, self.es_cmd, self.out_ann, data)
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(ret, 1), 48))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 2), self.xx))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 0), self.mm))
  return _v
end)()) then
    self:putx({ Ann.WARN, { "Warning: Unexpected bytes in reply!" } })
  end
  do
    local _lv_a0, _lv_a1, _lv_a2, _lv_a3 = 0, 0, 0, 0
    self.xx = _lv_a0
    self.yy = _lv_a1
    self.zz = _lv_a2
    self.mm = _lv_a3
  end
end
function _decoder.handle_cmd_chip_erase(self, cmd, ret)
  local bit
  self:putx({ Ann.CE, { "Chip erase" } })
  bit = ((logicview.idx(ret, 2) & (1 << 7)) >> 7)
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(ret, 1), 172))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(bit, 1))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(ret, 3), logicview.idx(cmd, 2)))
  return _v
end)()) then
    self:putx({ Ann.WARN, { "Warning: Unexpected bytes in reply!" } })
  end
end
function _decoder.handle_cmd_read_fuse_bits(self, cmd, ret)
  self:putx({ Ann.RFB, { logicview.pymod("Read fuse bits: 0x%02x", logicview.idx(ret, 3)) } })
end
function _decoder.handle_cmd_read_fuse_high_bits(self, cmd, ret)
  self:putx({ Ann.RHFB, { logicview.pymod("Read fuse high bits: 0x%02x", logicview.idx(ret, 3)) } })
end
function _decoder.handle_cmd_read_extended_fuse_bits(self, cmd, ret)
  self:putx({ Ann.REFB, { logicview.pymod("Read extended fuse bits: 0x%02x", logicview.idx(ret, 3)) } })
end
function _decoder.handle_cmd_read_lock_bits(self, cmd, ret)
  self:putx({ Ann.RLB, { logicview.pymod("Read lock bits: 0x%02x", logicview.idx(ret, 3)) } })
end
function _decoder.handle_cmd_read_eeprom_memory(self, cmd, ret)
  local _addr
  _addr = logicview.add(((logicview.idx(cmd, 1) & 1) << 8), logicview.idx(cmd, 2))
  self:putx({ Ann.REEM, { logicview.pymod("Read EEPROM Memory: [0x%03x]: 0x%02x", { _addr, logicview.idx(ret, 3) }) } })
end
function _decoder.handle_cmd_read_program_memory(self, cmd, ret)
  local _HL, _H, _addr
  _HL = "Low"
  _H = "L"
  if logicview.truth((logicview.idx(cmd, 0) & 8)) then
    _HL = "High"
    _H = "H"
  end
  _addr = logicview.add(((logicview.idx(cmd, 1) & 15) << 8), logicview.idx(cmd, 2))
  self:putx({ Ann.RP, { logicview.pymod("Read program memory %s: [0x%03x]: 0x%02x", { _HL, _addr, logicview.idx(ret, 3) }), logicview.pymod("[%03x%s]:%02x", { _addr, _H, logicview.idx(ret, 3) }), logicview.pymod("%02x", logicview.idx(ret, 3)) } })
end
function _decoder.handle_cmd_load_program_memory_page(self, cmd, ret)
  local _HL, _H, _addr
  _HL = "Low"
  _H = "L"
  if logicview.truth((logicview.idx(cmd, 0) & 8)) then
    _HL = "High"
    _H = "H"
  end
  _addr = (logicview.idx(cmd, 2) & 31)
  self:putx({ Ann.LPMP, { logicview.pymod("Load program memory page %s: [0x%03x]: 0x%02x", { _HL, _addr, logicview.idx(cmd, 3) }), logicview.pymod("[%03x%s]=%02x", { _addr, _H, logicview.idx(cmd, 3) }), logicview.pymod("%02x", logicview.idx(cmd, 3)) } })
end
function _decoder.handle_cmd_write_program_memory_page(self, cmd, ret)
  local _addr
  _addr = logicview.add(((logicview.idx(cmd, 1) & 15) << 3), (logicview.idx(cmd, 2) << 5))
  self:putx({ Ann.WP, { logicview.pymod("Write program memory page: 0x%02x", _addr) } })
end
function _decoder.handle_command(self, cmd, ret)
  local c, r
  if logicview.truth(logicview.eq(logicview.slice(cmd, nil, 2, nil), { 172, 83 })) then
    self:handle_cmd_programming_enable(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 172)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((logicview.idx(cmd, 1) & (1 << 7)), (1 << 7))
  return _v
end)()) then
    self:handle_cmd_chip_erase(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.slice(cmd, nil, 3, nil), { 80, 0, 0 })) then
    self:handle_cmd_read_fuse_bits(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.slice(cmd, nil, 3, nil), { 88, 8, 0 })) then
    self:handle_cmd_read_fuse_high_bits(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.slice(cmd, nil, 3, nil), { 80, 8, 0 })) then
    self:handle_cmd_read_extended_fuse_bits(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 48)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cmd, 2), 0)
  return _v
end)()) then
    self:handle_cmd_read_signature_byte_0x00(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 48)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cmd, 2), 1)
  return _v
end)()) then
    self:handle_cmd_read_signature_byte_0x01(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 48)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cmd, 2), 2)
  return _v
end)()) then
    self:handle_cmd_read_signature_byte_0x02(cmd, ret)
  elseif logicview.truth(logicview.eq(logicview.slice(cmd, nil, 2, nil), { 88, 0 })) then
    self:handle_cmd_read_lock_bits(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 160)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((logicview.idx(cmd, 1) & (3 << 6)), (0 << 6))
  return _v
end)()) then
    self:handle_cmd_read_eeprom_memory(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 32)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cmd, 0), 40)
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((logicview.idx(cmd, 1) & 240), 0)
  return _v
end)()) then
    self:handle_cmd_read_program_memory(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 64)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cmd, 0), 72)
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((logicview.idx(cmd, 1) & 240), 0)
  return _v
end)()) then
    self:handle_cmd_load_program_memory_page(cmd, ret)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cmd, 0), 76)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((logicview.idx(cmd, 1) & 240), 0)
  return _v
end)()) then
    self:handle_cmd_write_program_memory_page(cmd, ret)
  else
    c = logicview.pymod("%02x %02x %02x %02x", logicview.copy(cmd))
    r = logicview.pymod("%02x %02x %02x %02x", logicview.copy(ret))
    self:putx({ Ann.WARN, { logicview.pymod("Unknown command: %s (reply: %s)!", { c, r }) } })
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth((not logicview.contains({ "DATA", "BITS" }, ptype))) then
      return
    end
    if logicview.truth(logicview.eq(ptype, "BITS")) then
      do
        local _lv_a0, _lv_a1 = miso, mosi
        self.miso_bits = _lv_a0
        self.mosi_bits = _lv_a1
      end
      return
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 0)) then
      self.ss_cmd = ss
    end
    _table.insert(self.mosi_bytes, mosi)
    _table.insert(self.miso_bytes, miso)
    if logicview.truth((logicview.len(self.mosi_bytes) < 4)) then
      return
    end
    self.es_cmd = es
    self:handle_command(self.mosi_bytes, self.miso_bytes)
    self.mosi_bytes = {  }
    self.miso_bytes = {  }
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
