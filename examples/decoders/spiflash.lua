-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011-2016 Uwe Hermann <uwe@hermann-uwe.de>
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
local L, Ann, cmd_annotation_classes, decode_dual_bytes, decode_status_reg, Decoder, OrderedDict, cmds, device_name, chips
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
OrderedDict = collections.OrderedDict
cmds = OrderedDict({ { 1, { "WRSR", "Write status register" } }, { 2, { "PP", "Page program" } }, { 3, { "READ", "Read data" } }, { 4, { "WRDI", "Write disable" } }, { 5, { "RDSR", "Read status register" } }, { 6, { "WREN", "Write enable" } }, { 11, { "FAST/READ", "Fast read data" } }, { 32, { "SE", "Sector erase" } }, { 43, { "RDSCUR", "Read security register" } }, { 47, { "WRSCUR", "Write security register" } }, { 53, { "RDSR2", "Read status register 2" } }, { 96, { "CE", "Chip erase" } }, { 112, { "ESRY", "Enable SO to output RY/BY#" } }, { 128, { "DSRY", "Disable SO to output RY/BY#" } }, { 130, { "WRITE1", "Main memory page program through buffer 1 with built-in erase" } }, { 133, { "WRITE2", "Main memory page program through buffer 2 with built-in erase" } }, { 144, { "REMS", "Read electronic manufacturer & device ID" } }, { 159, { "RDID", "Read identification" } }, { 171, { "RDP/RES", "Release from deep powerdown / Read electronic ID" } }, { 173, { "CP", "Continuously program mode" } }, { 177, { "ENSO", "Enter secured OTP" } }, { 185, { "DP", "Deep power down" } }, { 187, { "2READ", "2x I/O read" } }, { 193, { "EXSO", "Exit secured OTP" } }, { 199, { "CE2", "Chip erase" } }, { 215, { "STATUS", "Status register read" } }, { 216, { "BE", "Block erase" } }, { 239, { "REMS2", "Read ID for 2x I/O mode" } } })
device_name = logicview.dict({ adesto = logicview.dict({ [0] = "AT45Dxxx family, standard series" }), fidelix = logicview.dict({ [21] = "FM25Q32" }), macronix = logicview.dict({ [20] = "MX25L1605D", [21] = "MX25L3205D", [22] = "MX25L6405D" }), winbond = logicview.dict({ [19] = "W25Q80DV" }) })
chips = logicview.dict({ adesto_at45db161e = logicview.dict({ vendor = "Adesto", model = "AT45DB161E", res_id = 255, rems_id = 65535, rems2_id = 65535, rdid_id = 133781520640, page_size = 528, sector_size = logicview.mul(128, 1024), block_size = logicview.mul(4, 1024) }), fidelix_fm25q32 = logicview.dict({ vendor = "FIDELIX", model = "FM25Q32", res_id = 21, rems_id = 41237, rems2_id = 41237, rdid_id = 10567702, page_size = 256, sector_size = logicview.mul(4, 1024), block_size = logicview.mul(64, 1024) }), macronix_mx25l1605d = logicview.dict({ vendor = "Macronix", model = "MX25L1605D", res_id = 20, rems_id = 49684, rems2_id = 49684, rdid_id = 12722197, page_size = 256, sector_size = logicview.mul(4, 1024), block_size = logicview.mul(64, 1024) }), macronix_mx25l3205d = logicview.dict({ vendor = "Macronix", model = "MX25L3205D", res_id = 21, rems_id = 49685, rems2_id = 49685, rdid_id = 12722198, page_size = 256, sector_size = logicview.mul(4, 1024), block_size = logicview.mul(64, 1024) }), macronix_mx25l6405d = logicview.dict({ vendor = "Macronix", model = "MX25L6405D", res_id = 22, rems_id = 49686, rems2_id = 49686, rdid_id = 12722199, page_size = 256, sector_size = logicview.mul(4, 1024), block_size = logicview.mul(64, 1024) }), winbond_w25q80dv = logicview.dict({ vendor = "Winbond", model = "W25Q80DV", res_id = 19, rems_id = 61203, rems2_id = 65535, rdid_id = 15679508, page_size = 256, sector_size = logicview.mul(4, 1024), block_size = logicview.mul(64, 1024) }) })

L = logicview.len(cmds)
Ann = {}
Ann.__index = Ann
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(logicview.add(L, 3)) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  Ann.WRSR = logicview.idx(_lv_seq, 0)
  Ann.PP = logicview.idx(_lv_seq, 1)
  Ann.READ = logicview.idx(_lv_seq, 2)
  Ann.WRDI = logicview.idx(_lv_seq, 3)
  Ann.RDSR = logicview.idx(_lv_seq, 4)
  Ann.WREN = logicview.idx(_lv_seq, 5)
  Ann.FAST_READ = logicview.idx(_lv_seq, 6)
  Ann.SE = logicview.idx(_lv_seq, 7)
  Ann.RDSCUR = logicview.idx(_lv_seq, 8)
  Ann.WRSCUR = logicview.idx(_lv_seq, 9)
  Ann.RDSR2 = logicview.idx(_lv_seq, 10)
  Ann.CE = logicview.idx(_lv_seq, 11)
  Ann.ESRY = logicview.idx(_lv_seq, 12)
  Ann.DSRY = logicview.idx(_lv_seq, 13)
  Ann.WRITE1 = logicview.idx(_lv_seq, 14)
  Ann.WRITE2 = logicview.idx(_lv_seq, 15)
  Ann.REMS = logicview.idx(_lv_seq, 16)
  Ann.RDID = logicview.idx(_lv_seq, 17)
  Ann.RDP_RES = logicview.idx(_lv_seq, 18)
  Ann.CP = logicview.idx(_lv_seq, 19)
  Ann.ENSO = logicview.idx(_lv_seq, 20)
  Ann.DP = logicview.idx(_lv_seq, 21)
  Ann.READ2X = logicview.idx(_lv_seq, 22)
  Ann.EXSO = logicview.idx(_lv_seq, 23)
  Ann.CE2 = logicview.idx(_lv_seq, 24)
  Ann.STATUS = logicview.idx(_lv_seq, 25)
  Ann.BE = logicview.idx(_lv_seq, 26)
  Ann.REMS2 = logicview.idx(_lv_seq, 27)
  Ann.BIT = logicview.idx(_lv_seq, 28)
  Ann.FIELD = logicview.idx(_lv_seq, 29)
  Ann.WARN = logicview.idx(_lv_seq, 30)
end
cmd_annotation_classes = function()
  return logicview.copy((function()
  local _lv_out = {}
  for _, _lv_v in _pairs(cmds) do
    cmd = _lv_v
    _lv_out[#_lv_out + 1] = logicview.copy({ _string.lower(logicview.idx(cmd, 0)), logicview.idx(cmd, 1) })
  end
  return _lv_out
end)())
end
decode_dual_bytes = function(sio0, sio1)
  local combine_byte
  combine_byte = function(even, odd)
    local result, bit
    result = 0
    for _lv_i in logicview.range(4) do
      bit = _lv_i
      if logicview.truth((even & (1 << bit))) then
        result = (result | (1 << logicview.mul(bit, 2)))
      end
      if logicview.truth((odd & (1 << bit))) then
        result = (result | (1 << logicview.add(logicview.mul(bit, 2), 1)))
      end
      ::continue_1::
    end
    return result
  end
  return { combine_byte((sio0 >> 4), (sio1 >> 4)), combine_byte(sio0, sio1) }
end
decode_status_reg = function(data)
  local s, ret
  s = (function() if logicview.truth((data & (1 << 0))) then return "W" else return "No w" end end)()
  ret = logicview.pymod("%srite operation in progress.\n", s)
  s = (function() if logicview.truth((data & (1 << 1))) then return "" else return "not " end end)()
  ret = logicview.add(ret, logicview.pymod("Internal write enable latch is %sset.\n", s))
  ret = logicview.add(ret, logicview.pymod("Block protection bits (BP3-BP0): 0x%x.\n", ((data & 60) >> 2)))
  s = (function() if logicview.truth((data & (1 << 6))) then return "" else return "not " end end)()
  ret = logicview.add(ret, logicview.pymod("Device is %sin continuously program mode (CP mode).\n", s))
  s = (function() if logicview.truth((data & (1 << 7))) then return "not " else return "" end end)()
  ret = logicview.add(ret, logicview.pymod("Status register writes are %sallowed.\n", s))
  return ret
end
_decoder = {
  api_version = 3,
  id = "spiflash",
  name = "SPI flash",
  longname = "SPI flash chips",
  desc = "xx25 series SPI (NOR) flash chip protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "chip", desc = "Chip", default = "adesto_at45db161e", values = { "adesto_at45db161e", "fidelix_fm25q32", "macronix_mx25l1605d", "macronix_mx25l3205d", "macronix_mx25l6405d", "winbond_w25q80dv" } }), logicview.dict({ id = "format", desc = "Data format", default = "hex", values = { "hex", "ascii" } }) },
  annotations = { { "wrsr", "Write status register" }, { "pp", "Page program" }, { "read", "Read data" }, { "wrdi", "Write disable" }, { "rdsr", "Read status register" }, { "wren", "Write enable" }, { "fast/read", "Fast read data" }, { "se", "Sector erase" }, { "rdscur", "Read security register" }, { "wrscur", "Write security register" }, { "rdsr2", "Read status register 2" }, { "ce", "Chip erase" }, { "esry", "Enable SO to output RY/BY#" }, { "dsry", "Disable SO to output RY/BY#" }, { "write1", "Main memory page program through buffer 1 with built-in erase" }, { "write2", "Main memory page program through buffer 2 with built-in erase" }, { "rems", "Read electronic manufacturer & device ID" }, { "rdid", "Read identification" }, { "rdp/res", "Release from deep powerdown / Read electronic ID" }, { "cp", "Continuously program mode" }, { "enso", "Enter secured OTP" }, { "dp", "Deep power down" }, { "2read", "2x I/O read" }, { "exso", "Exit secured OTP" }, { "ce2", "Chip erase" }, { "status", "Status register read" }, { "be", "Block erase" }, { "rems2", "Read ID for 2x I/O mode" }, { "bit", "Bit" }, { "field", "Field" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 28 } }, { "fields", "Fields", { 29 } }, { "commands", "Commands", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 } }, { "warnings", "Warnings", { 30 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  local get_handler
  self.device_id = (-1)
  self.on_end_transaction = nil
  self:end_current_transaction()
  self.writestate = 0
  get_handler = function(cmd)
    local s
    s = logicview.pymod("handle_%s", logicview.replace(_string.lower(logicview.idx(logicview.idx(cmds, cmd), 0)), "/", "_", nil))
    return (function() local _v = self[s]; if _v == nil then return nil end; return _v end)()
  end
  self.cmd_handlers = logicview.dict((function()
  local _lv_out = {}
  for _lv_k, _ in _pairs(cmds) do
    cmd = _lv_k
    _lv_out[#_lv_out + 1] = { cmd, get_handler(cmd) }
  end
  return _lv_out
end)())
end
function _decoder.end_current_transaction(self)
  if logicview.truth((self.on_end_transaction ~= nil)) then
    self:on_end_transaction()
    self.on_end_transaction = nil
  end
  self.state = nil
  self.cmdstate = 1
  self.addr = 0
  self.data = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.chip = logicview.idx(chips, logicview.idx(self.options, "chip"))
  self.vendor = logicview.idx(logicview.split(logicview.idx(self.options, "chip"), "_", nil), 0)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putf(self, data)
  self:put(self.ss_field, self.es_field, self.out_ann, data)
end
function _decoder.putc(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.device(self)
  return logicview.dget(logicview.idx(device_name, self.vendor), self.device_id, "Unknown")
end
function _decoder.vendor_device(self)
  return logicview.pymod("%s %s", { logicview.idx(self.chip, "vendor"), self:device() })
end
function _decoder.cmd_ann_list(self)
  local x, s
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(cmds, self.state), 0), logicview.idx(logicview.idx(cmds, self.state), 1)
    x = _lv_a0
    s = _lv_a1
  end
  return { logicview.pymod("Command: %s (%s)", { s, x }), logicview.pymod("Command: %s", s), logicview.pymod("Cmd: %s", s), logicview.pymod("Cmd: %s", x), x }
end
function _decoder.cmd_vendor_dev_list(self)
  local c, d
  do
    local _lv_a0, _lv_a1 = logicview.idx(cmds, self.state), logicview.pymod("Device = %s", self:vendor_device())
    c = _lv_a0
    d = _lv_a1
  end
  return { logicview.pymod("%s (%s): %s", { logicview.idx(c, 1), logicview.idx(c, 0), d }), logicview.pymod("%s: %s", { logicview.idx(c, 1), d }), logicview.pymod("%s: %s", { logicview.idx(c, 0), d }), d, self:vendor_device() }
end
function _decoder.emit_cmd_byte(self)
  self.ss_cmd = self.ss
  self:putx({ Ann.FIELD, self:cmd_ann_list() })
  self.addr = 0
end
function _decoder.emit_addr_bytes(self, mosi)
  local b
  self.addr = (self.addr | (mosi << logicview.mul((4 - self.cmdstate), 8)))
  b = (logicview.mul((3 - (self.cmdstate - 2)), 8) - 1)
  self:putx({ Ann.BIT, { logicview.pymod("Address bits %d..%d: {$}", { b, (b - 7) }), logicview.pymod("Addr bits %d..%d: {$}", { b, (b - 7) }), logicview.pymod("Addr bits %d..%d", { b, (b - 7) }), logicview.pymod("A%d..A%d", { b, (b - 7) }), logicview.pymod("@%02X", mosi) } })
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.ss_field = self.ss
  end
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.es_field = self.es
    self:putf({ Ann.FIELD, { "Address: {$}", "Addr: {$}", "{$}", logicview.pymod("@%06x", self.addr) } })
  end
end
function _decoder.handle_wren(self, mosi, miso)
  self:putx({ Ann.WREN, self:cmd_ann_list() })
  self.writestate = 1
end
function _decoder.handle_wrdi(self, mosi, miso)
  self:putx({ Ann.WRDI, self:cmd_ann_list() })
  self.writestate = 0
end
function _decoder.handle_rdid(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self:putx({ Ann.FIELD, { "Manufacturer ID: {$}", logicview.pymod("@%02x", miso) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self:putx({ Ann.FIELD, { "Memory type: {$}", logicview.pymod("@%02x", miso) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.device_id = miso
    self:putx({ Ann.FIELD, { "Device ID: {$}", logicview.pymod("@%02x", miso) } })
  end
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.es_cmd = self.es
    self:putc({ Ann.RDID, self:cmd_vendor_dev_list() })
    self.state = nil
  else
    self.cmdstate = logicview.add(self.cmdstate, 1)
  end
end
function _decoder.handle_rdsr(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth((self.cmdstate >= 2)) then
    self.es_cmd = self.es
    self:putx({ Ann.BIT, { decode_status_reg(miso) } })
    self:putx({ Ann.FIELD, { "Status register" } })
    self:putc({ Ann.RDSR, self:cmd_ann_list() })
    self.writestate = (function() if logicview.truth((miso & (1 << 1))) then return 1 else return 0 end end)()
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_rdsr2(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth((self.cmdstate >= 2)) then
    self.es_cmd = self.es
    self:putx({ Ann.BIT, { decode_status_reg(miso) } })
    self:putx({ Ann.FIELD, { "Status register 2" } })
    self:putc({ Ann.RDSR2, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_wrsr(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self:putx({ Ann.BIT, { decode_status_reg(mosi) } })
    self:putx({ Ann.FIELD, { "Status register 1" } })
    self.writestate = (function() if logicview.truth((miso & (1 << 1))) then return 1 else return 0 end end)()
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self:putx({ Ann.BIT, { decode_status_reg(mosi) } })
    self:putx({ Ann.FIELD, { "Status register 2" } })
    self.es_cmd = self.es
    self:putc({ Ann.WRSR, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_read(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:emit_addr_bytes(mosi)
  elseif logicview.truth((self.cmdstate >= 5)) then
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 5)) then
      self.ss_field = self.ss
      self.on_end_transaction = (function() return self:output_data_block("Data", Ann.READ) end)
    end
    _table.insert(self.data, miso)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_write_common(self, mosi, miso, ann)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
    if logicview.truth(logicview.eq(self.writestate, 0)) then
      self:putc({ Ann.WARN, { "Warning: WREN might be missing" } })
    end
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:emit_addr_bytes(mosi)
  elseif logicview.truth((self.cmdstate >= 5)) then
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 5)) then
      self.ss_field = self.ss
      self.on_end_transaction = (function() return self:output_data_block("Data", ann) end)
    end
    _table.insert(self.data, mosi)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_write1(self, mosi, miso)
  self:handle_write_common(mosi, miso, Ann.WRITE1)
end
function _decoder.handle_write2(self, mosi, miso)
  self:handle_write_common(mosi, miso, Ann.WRITE2)
end
function _decoder.handle_fast_read(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:emit_addr_bytes(mosi)
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self:putx({ Ann.BIT, { "Dummy byte: {$}", logicview.pymod("@%02x", mosi) } })
  elseif logicview.truth((self.cmdstate >= 6)) then
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 6)) then
      self.ss_field = self.ss
      self.on_end_transaction = (function() return self:output_data_block("Data", Ann.FAST_READ) end)
    end
    _table.insert(self.data, miso)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_2read(self, mosi, miso)
  local b1, b2
  if logicview.truth((not logicview.eq(self.cmdstate, 1))) then
    do
      local _lv_seq = decode_dual_bytes(mosi, miso)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      b1 = logicview.idx(_lv_seq, 0)
      b2 = logicview.idx(_lv_seq, 1)
    end
  end
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self:emit_addr_bytes(b1)
    self.cmdstate = 3
    self:emit_addr_bytes(b2)
  elseif logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self:emit_addr_bytes(b1)
    self.cmdstate = 5
    self:putx({ Ann.BIT, { "Dummy byte: {$}", logicview.pymod("@%02x", b2) } })
  elseif logicview.truth((self.cmdstate >= 6)) then
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 6)) then
      self.ss_field = self.ss
      self.on_end_transaction = (function() return self:output_data_block("Data", Ann.READ2X) end)
    end
    _table.insert(self.data, b1)
    _table.insert(self.data, b2)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_status(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
    self.on_end_transaction = (function() return self:putc({ Ann.STATUS, { logicview.idx(logicview.idx(cmds, self.state), 1) } }) end)
  else
    self.es_cmd = self.es
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 2)) then
      self.ss_field = self.ss
    end
    self:putx({ Ann.BIT, { logicview.pymod("Status register byte %d: {$}", { logicview.add(logicview.pymod(self.cmdstate, 2), 1), logicview.pymod("@%02x", miso) }) } })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_se(self, mosi, miso)
  local d
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
    if logicview.truth(logicview.eq(self.writestate, 0)) then
      self:putx({ Ann.WARN, { "Warning: WREN might be missing" } })
    end
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:emit_addr_bytes(mosi)
  end
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.es_cmd = self.es
    d = { logicview.pymod("Erase sector %d ({$})", self.addr), logicview.pymod("@%06x", self.addr) }
    self:putc({ Ann.SE, d })
    if logicview.truth((not logicview.eq(logicview.pymod(self.addr, 4096), 0))) then
      self:putc({ Ann.WARN, { "Warning: Invalid sector address!" } })
    end
    self.state = nil
  else
    self.cmdstate = logicview.add(self.cmdstate, 1)
  end
end
function _decoder.handle_be(self, mosi, miso)
end
function _decoder.handle_ce(self, mosi, miso)
  self:putx({ Ann.CE, self:cmd_ann_list() })
  if logicview.truth(logicview.eq(self.writestate, 0)) then
    self:putx({ Ann.WARN, { "Warning: WREN might be missing" } })
  end
end
function _decoder.handle_ce2(self, mosi, miso)
  self:putx({ Ann.CE2, self:cmd_ann_list() })
  if logicview.truth(logicview.eq(self.writestate, 0)) then
    self:putx({ Ann.WARN, { "Warning: WREN might be missing" } })
  end
end
function _decoder.handle_pp(self, mosi, miso)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:emit_addr_bytes(mosi)
  elseif logicview.truth((self.cmdstate >= 5)) then
    self.es_field = self.es
    if logicview.truth(logicview.eq(self.cmdstate, 5)) then
      self.ss_field = self.ss
      self.on_end_transaction = (function() return self:output_data_block("Data", Ann.PP) end)
    end
    _table.insert(self.data, mosi)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_cp(self, mosi, miso)
end
function _decoder.handle_dp(self, mosi, miso)
end
function _decoder.handle_rdp_res(self, mosi, miso)
  local d
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.contains({ 2, 3, 4 }, self.cmdstate)) then
    self:putx({ Ann.FIELD, { "Dummy byte: {$}", logicview.pymod("@%02x", mosi) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.es_cmd = self.es
    self.device_id = miso
    self:putx({ Ann.FIELD, { logicview.pymod("Device ID: %s", self:device()) } })
    d = logicview.pymod("Device = %s", self:vendor_device())
    self:putc({ Ann.RDP_RES, self:cmd_vendor_dev_list() })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_rems(self, mosi, miso)
  local d, id_
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
  elseif logicview.truth(logicview.contains({ 2, 3 }, self.cmdstate)) then
    self:putx({ Ann.FIELD, { "Dummy byte: {$}", logicview.pymod("@%02X", mosi) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.manufacturer_id_first = (function() if logicview.truth(logicview.eq(mosi, 0)) then return true else return false end end)()
    d = (function() if logicview.truth(logicview.eq(mosi, 0)) then return "manufacturer" else return "device" end end)()
    self:putx({ Ann.FIELD, { logicview.pymod("Master wants %s ID first", d) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.ids = { miso }
    d = (function() if logicview.truth(self.manufacturer_id_first) then return "Manufacturer" else return "Device" end end)()
    self:putx({ Ann.FIELD, { logicview.pymod("%s ID: {$}", d), logicview.pymod("@%02X", miso) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 6)) then
    _table.insert(self.ids, miso)
    d = (function() if logicview.truth(self.manufacturer_id_first) then return "Device" else return "Manufacturer" end end)()
    self:putx({ Ann.FIELD, { logicview.pymod("%s ID: {$}", d), logicview.pymod("@%02X", miso) } })
  end
  if logicview.truth(logicview.eq(self.cmdstate, 6)) then
    id_ = (function() if logicview.truth(self.manufacturer_id_first) then return logicview.idx(self.ids, 1) else return logicview.idx(self.ids, 0) end end)()
    self.device_id = id_
    self.es_cmd = self.es
    self:putc({ Ann.REMS, self:cmd_vendor_dev_list() })
    self.state = nil
  else
    self.cmdstate = logicview.add(self.cmdstate, 1)
  end
end
function _decoder.handle_rems2(self, mosi, miso)
end
function _decoder.handle_enso(self, mosi, miso)
end
function _decoder.handle_exso(self, mosi, miso)
end
function _decoder.handle_rdscur(self, mosi, miso)
end
function _decoder.handle_wrscur(self, mosi, miso)
end
function _decoder.handle_esry(self, mosi, miso)
end
function _decoder.handle_dsry(self, mosi, miso)
end
function _decoder.output_data_block(self, label, idx)
  local s
  self.es_cmd = self.es
  if logicview.truth(logicview.eq(logicview.idx(self.options, "format"), "hex")) then
    s = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(self.data) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02x", b)
  end
  return _lv_out
end)())
  else
    s = logicview.join("", (function() local _t = {}; for _, _v in logicview.iter(self.data) do _t[#_t + 1] = chr(_v) end; return _t end)())
  end
  self:putf({ Ann.FIELD, { logicview.pymod("%s (%d bytes)", { label, logicview.len(self.data) }) } })
  self:putc({ idx, { logicview.pymod("%s (addr {$}, %d bytes): %s", { logicview.idx(logicview.idx(cmds, self.state), 1), logicview.len(self.data), s }), logicview.pymod("@%06x", self.addr) } })
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
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      self:end_current_transaction()
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    if logicview.truth((self.state == nil)) then
      self.state = mosi
      self.cmdstate = 1
    end
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        logicview.idx(self.cmd_handlers, self.state)(mosi, miso)
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if (_type(_err) == 'table' and _err._exc == "KeyError") then
          self:putx({ Ann.BIT, { "Unknown command: {$}", logicview.pymod("@%02x", mosi) } })
          self.state = nil
        else
          _error(_err, 0)
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
