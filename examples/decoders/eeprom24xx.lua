-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Uwe Hermann <uwe@hermann-uwe.de>

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
local Decoder, chips
local _decoder

chips = logicview.dict({ generic = logicview.dict({ vendor = "", model = "Generic", size = 128, page_size = 8, page_wraparound = true, addr_bytes = 1, addr_pins = 3, max_speed = 400 }), microchip_24aa65 = logicview.dict({ vendor = "Microchip", model = "24AA65", size = logicview.mul(8, 1024), page_size = 64, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 400 }), microchip_24lc65 = logicview.dict({ vendor = "Microchip", model = "24LC65", size = logicview.mul(8, 1024), page_size = 64, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 400 }), microchip_24c65 = logicview.dict({ vendor = "Microchip", model = "24C65", size = logicview.mul(8, 1024), page_size = 64, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 400 }), microchip_24aa64 = logicview.dict({ vendor = "Microchip", model = "24AA64", size = logicview.mul(8, 1024), page_size = 32, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 400 }), microchip_24lc64 = logicview.dict({ vendor = "Microchip", model = "24LC64", size = logicview.mul(8, 1024), page_size = 32, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 400 }), microchip_24aa02uid = logicview.dict({ vendor = "Microchip", model = "24AA02UID", size = 256, page_size = 8, page_wraparound = true, addr_bytes = 1, addr_pins = 0, max_speed = 400 }), microchip_24aa025uid = logicview.dict({ vendor = "Microchip", model = "24AA025UID", size = 256, page_size = 16, page_wraparound = true, addr_bytes = 1, addr_pins = 3, max_speed = 400 }), microchip_24aa025uid_sot23 = logicview.dict({ vendor = "Microchip", model = "24AA025UID (SOT-23)", size = 256, page_size = 16, page_wraparound = true, addr_bytes = 1, addr_pins = 2, max_speed = 400 }), onsemi_cat24c256 = logicview.dict({ vendor = "ON Semiconductor", model = "CAT24C256", size = logicview.mul(32, 1024), page_size = 64, page_wraparound = true, addr_bytes = 2, addr_pins = 3, max_speed = 1000 }), onsemi_cat24m01 = logicview.dict({ vendor = "ON Semiconductor", model = "CAT24M01", size = logicview.mul(128, 1024), page_size = 256, page_wraparound = true, addr_bytes = 2, addr_pins = 2, max_speed = 1000 }), siemens_slx_24c01 = logicview.dict({ vendor = "Siemens", model = "SLx 24C01", size = 128, page_size = 8, page_wraparound = true, addr_bytes = 1, addr_pins = 0, max_speed = 400 }), siemens_slx_24c02 = logicview.dict({ vendor = "Siemens", model = "SLx 24C02", size = 256, page_size = 8, page_wraparound = true, addr_bytes = 1, addr_pins = 0, max_speed = 400 }), st_m24c01 = logicview.dict({ vendor = "ST", model = "M24C01", size = 128, page_size = 16, page_wraparound = true, addr_bytes = 1, addr_pins = 3, max_speed = 400 }), st_m24c02 = logicview.dict({ vendor = "ST", model = "M24C02", size = 256, page_size = 16, page_wraparound = true, addr_bytes = 1, addr_pins = 3, max_speed = 400 }), xicor_x24c02 = logicview.dict({ vendor = "Xicor", model = "X24C02", size = 256, page_size = 4, page_wraparound = true, addr_bytes = 1, addr_pins = 3, max_speed = 100 }) })

_decoder = {
  api_version = 3,
  id = "eeprom24xx",
  name = "24xx EEPROM",
  longname = "24xx I²C EEPROM",
  desc = "24xx series I²C EEPROM protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "IC", "Memory" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "chip", desc = "Chip", default = "generic", values = { "generic", "microchip_24aa65", "microchip_24lc65", "microchip_24c65", "microchip_24aa64", "microchip_24lc64", "microchip_24aa02uid", "microchip_24aa025uid", "microchip_24aa025uid_sot23", "onsemi_cat24c256", "onsemi_cat24m01", "siemens_slx_24c01", "siemens_slx_24c02", "st_m24c01", "st_m24c02", "xicor_x24c02" } }), logicview.dict({ id = "addr_counter", desc = "Initial address counter value", default = 0, values = {  } }) },
  annotations = { { "warnings", "Warnings" }, { "control-code", "Control code" }, { "address-pin", "Address pin (A0/A1/A2)" }, { "rw-bit", "Read/write bit" }, { "word-addr-byte", "Word address byte" }, { "data-byte", "Data byte" }, { "control-word", "Control word" }, { "word-addr", "Word address" }, { "data", "Data" }, { "byte-write", "Byte write" }, { "page-write", "Page write" }, { "cur-addr-read", "Current address read" }, { "random-read", "Random read" }, { "seq-random-read", "Sequential random read" }, { "seq-cur-addr-read", "Sequential current address read" }, { "ack-polling", "Acknowledge polling" }, { "set-bank-addr", "Set bank address" }, { "read-bank-addr", "Read bank address" }, { "set-wp", "Set write protection" }, { "clear-all-wp", "Clear all write protection" }, { "read-wp", "Read write protection status" } },
  annotation_rows = { { "bits-bytes", "Bits/bytes", { 1, 2, 3, 4, 5 } }, { "fields", "Fields", { 6, 7, 8 } }, { "ops", "Operations", { 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 } }, { "warnings", "Warnings", { 0 } } },
  binary = { { "binary", "Binary" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self:reset_variables()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.chip = logicview.idx(chips, logicview.idx(self.options, "chip"))
  self.addr_counter = logicview.idx(self.options, "addr_counter")
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.putbin(self, data)
  self:put(self.ss_block, self.es_block, self.out_binary, data)
end
function _decoder.putbits(self, bit1, bit2, bits, data)
  self:put(logicview.idx(logicview.idx(bits, bit1), 1), logicview.idx(logicview.idx(bits, bit2), 2), self.out_ann, data)
end
function _decoder.reset_variables(self)
  self.state = "WAIT FOR START"
  self.packets = {  }
  self.bytebuf = {  }
  self.is_cur_addr_read = false
  self.is_random_access_read = false
  self.is_seq_random_read = false
  self.is_byte_write = false
  self.is_page_write = false
end
function _decoder.packet_append(self)
  _table.insert(self.packets, { self.ss, self.es, self.cmd, self.databyte, self.bits })
  if logicview.truth(logicview.contains({ "DATA READ", "DATA WRITE" }, self.cmd)) then
    _table.insert(self.bytebuf, self.databyte)
  end
end
function _decoder.hexbytes(self, idx)
  return logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(self.bytebuf, idx, nil, nil)) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%02X", b)
  end
  return _lv_out
end)())
end
function _decoder.put_control_word(self, bits)
  local s, i, s1, s2
  s = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.reversed(logicview.slice(bits, 4, nil, nil))) do
    b = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%d", logicview.idx(b, 0))
  end
  return _lv_out
end)())
  self:putbits(7, 4, bits, { 1, { logicview.add("Control code bits: ", s), logicview.add("Control code: ", s), logicview.add("Ctrl code: ", s), "Ctrl code", "Ctrl", "C" } })
  for _lv_item in logicview.iter(logicview.reversed((function() local _t = {}; for _v in logicview.range(logicview.idx(self.chip, "addr_pins")) do _t[#_t + 1] = _v end; return _t end)())) do
    i = _lv_item
    self:putbits(logicview.add(i, 1), logicview.add(i, 1), bits, { 2, { logicview.pymod("Address bit %d: %d", { i, logicview.idx(logicview.idx(bits, logicview.add(i, 1)), 0) }), logicview.pymod("Addr bit %d", i), logicview.pymod("A%d", i), "A" } })
    ::continue_1::
  end
  s1 = (function() if logicview.truth(logicview.eq(logicview.idx(logicview.idx(bits, 0), 0), 1)) then return "read" else return "write" end end)()
  s2 = (function() if logicview.truth(logicview.eq(logicview.idx(logicview.idx(bits, 0), 0), 1)) then return "R" else return "W" end end)()
  self:putbits(0, 0, bits, { 3, { logicview.add("R/W bit: ", s1), "R/W", "RW", s2 } })
  self:putbits(7, 0, bits, { 6, { "Control word", "Control", "CW", "C" } })
end
function _decoder.put_word_addr(self, p)
  local a
  if logicview.truth(logicview.eq(logicview.idx(self.chip, "addr_bytes"), 1)) then
    a = logicview.idx(logicview.idx(p, 1), 3)
    self:put(logicview.idx(logicview.idx(p, 1), 0), logicview.idx(logicview.idx(p, 1), 1), self.out_ann, { 4, { logicview.pymod("Word address byte: %02X", a), logicview.pymod("Word addr byte: %02X", a), logicview.pymod("Addr: %02X", a), logicview.pymod("A: %02X", a), logicview.pymod("%02X", a) } })
    self:put(logicview.idx(logicview.idx(p, 1), 0), logicview.idx(logicview.idx(p, 1), 1), self.out_ann, { 7, { "Word address", "Word addr", "Addr", "A" } })
    self.addr_counter = a
  else
    a = logicview.idx(logicview.idx(p, 1), 3)
    self:put(logicview.idx(logicview.idx(p, 1), 0), logicview.idx(logicview.idx(p, 1), 1), self.out_ann, { 4, { logicview.pymod("Word address high byte: %02X", a), logicview.pymod("Word addr high byte: %02X", a), logicview.pymod("Addr high: %02X", a), logicview.pymod("AH: %02X", a), logicview.pymod("%02X", a) } })
    a = logicview.idx(logicview.idx(p, 2), 3)
    self:put(logicview.idx(logicview.idx(p, 2), 0), logicview.idx(logicview.idx(p, 2), 1), self.out_ann, { 4, { logicview.pymod("Word address low byte: %02X", a), logicview.pymod("Word addr low byte: %02X", a), logicview.pymod("Addr low: %02X", a), logicview.pymod("AL: %02X", a), logicview.pymod("%02X", a) } })
    self:put(logicview.idx(logicview.idx(p, 1), 0), logicview.idx(logicview.idx(p, 2), 1), self.out_ann, { 7, { "Word address", "Word addr", "Addr", "A" } })
    self.addr_counter = ((logicview.idx(logicview.idx(p, 1), 3) << 8) | logicview.idx(logicview.idx(p, 2), 3))
  end
end
function _decoder.put_data_byte(self, p)
  local s
  if logicview.truth(logicview.eq(logicview.idx(self.chip, "addr_bytes"), 1)) then
    s = logicview.pymod("%02X", self.addr_counter)
  else
    s = logicview.pymod("%04X", self.addr_counter)
  end
  self:put(logicview.idx(p, 0), logicview.idx(p, 1), self.out_ann, { 5, { logicview.pymod("Data byte %s: %02X", { s, logicview.idx(p, 3) }), logicview.pymod("Data byte: %02X", logicview.idx(p, 3)), logicview.pymod("Byte: %02X", logicview.idx(p, 3)), logicview.pymod("DB: %02X", logicview.idx(p, 3)), logicview.pymod("%02X", logicview.idx(p, 3)) } })
end
function _decoder.put_data_bytes(self, idx, cls, s)
  local p, a
  for _lv_item in logicview.iter(logicview.slice(self.packets, idx, nil, nil)) do
    p = _lv_item
    self:put_data_byte(p)
    self.addr_counter = logicview.add(self.addr_counter, 1)
    ::continue_2::
  end
  self:put(logicview.idx(logicview.idx(self.packets, idx), 0), logicview.idx(logicview.idx(self.packets, (-1)), 1), self.out_ann, { 8, { "Data", "D" } })
  a = _string.upper(logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.split(s, nil, nil)) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pymod("%s", logicview.idx(c, 0))
  end
  return _lv_out
end)()))
  self:putb({ cls, { logicview.pymod("%s (%s): %s", { s, self:addr_and_len(), self:hexbytes(logicview.idx(self.chip, "addr_bytes")) }), logicview.pymod("%s (%s)", { s, self:addr_and_len() }), s, a, logicview.idx(s, 0) } })
  self:putbin({ 0, logicview.bytes(logicview.slice(self.bytebuf, logicview.idx(self.chip, "addr_bytes"), nil, nil)) })
end
function _decoder.addr_and_len(self)
  local a, num_data_bytes, d
  if logicview.truth(logicview.eq(logicview.idx(self.chip, "addr_bytes"), 1)) then
    a = logicview.pymod("%02X", logicview.idx(self.bytebuf, 0))
  else
    a = logicview.pymod("%02X%02X", logicview.copy(logicview.slice(self.bytebuf, nil, 2, nil)))
  end
  num_data_bytes = (logicview.len(self.bytebuf) - logicview.idx(self.chip, "addr_bytes"))
  d = logicview.pymod("%d bytes", num_data_bytes)
  if logicview.truth((num_data_bytes <= 1)) then
    d = logicview.slice(d, nil, (-1), nil)
  end
  return logicview.pymod("addr=%s, %s", { a, d })
end
function _decoder.decide_on_seq_or_rnd_read(self)
  if logicview.truth((logicview.len(self.bytebuf) < 2)) then
    self:reset_variables()
    return
  end
  if logicview.truth(logicview.eq(logicview.len(self.bytebuf), 2)) then
    self.is_random_access_read = true
  else
    self.is_seq_random_read = true
  end
end
function _decoder.put_operation(self)
  local idx, intitial_addr, num_bytes_to_write, page1, page2
  idx = logicview.add(1, logicview.idx(self.chip, "addr_bytes"))
  if logicview.truth(self.is_byte_write) then
    self:put_word_addr(self.packets)
    self:put_data_bytes(idx, 9, "Byte write")
  elseif logicview.truth(self.is_page_write) then
    self:put_word_addr(self.packets)
    intitial_addr = self.addr_counter
    self:put_data_bytes(idx, 10, "Page write")
    num_bytes_to_write = logicview.len(logicview.slice(self.packets, idx, nil, nil))
    if logicview.truth((num_bytes_to_write > logicview.idx(self.chip, "page_size"))) then
      self:putb({ 0, { logicview.pymod("Warning: Wrote %d bytes but page size is only %d bytes!", { num_bytes_to_write, logicview.idx(self.chip, "page_size") }) } })
    end
    page1 = logicview.tointeger((intitial_addr / logicview.idx(self.chip, "page_size")))
    page2 = logicview.tointeger(((self.addr_counter - 1) / logicview.idx(self.chip, "page_size")))
    if logicview.truth((not logicview.eq(page1, page2))) then
      self:putb({ 0, { logicview.pymod("Warning: Page write crossed page boundary from page %d to %d!", { page1, page2 }) } })
    end
  elseif logicview.truth(self.is_cur_addr_read) then
    self:put_data_byte(logicview.idx(self.packets, 1))
    self:put(logicview.idx(logicview.idx(self.packets, 1), 0), logicview.idx(logicview.idx(self.packets, (-1)), 1), self.out_ann, { 8, { "Data", "D" } })
    self:putb({ 11, { logicview.pymod("Current address read: %02X", logicview.idx(self.bytebuf, 0)), "Current address read", "Cur addr read", "CAR", "C" } })
    self:putbin({ 0, logicview.bytes({ logicview.idx(self.bytebuf, 0) }) })
    self.addr_counter = logicview.add(self.addr_counter, 1)
  elseif logicview.truth(self.is_random_access_read) then
    self:put_control_word(logicview.idx(logicview.idx(self.packets, idx), 4))
    self:put_word_addr(self.packets)
    self:put_data_bytes(logicview.add(idx, 1), 12, "Random access read")
  elseif logicview.truth(self.is_seq_random_read) then
    self:put_control_word(logicview.idx(logicview.idx(self.packets, idx), 4))
    self:put_word_addr(self.packets)
    self:put_data_bytes(logicview.add(idx, 1), 13, "Sequential random read")
  end
end
function _decoder.handle_wait_for_start(self)
  if logicview.truth((not logicview.contains({ "START", "START REPEAT" }, self.cmd))) then
    return
  end
  self.ss_block = self.ss
  self.state = "GET CONTROL WORD"
end
function _decoder.handle_get_control_word(self)
  if logicview.truth((not logicview.contains({ "ADDRESS READ", "ADDRESS WRITE" }, self.cmd))) then
    self:reset_variables()
    return
  end
  self:packet_append()
  self:put_control_word(self.bits)
  self.state = logicview.pymod("%s GET ACK NACK AFTER CONTROL WORD", logicview.idx(self.cmd, 8))
end
function _decoder.handle_r_get_ack_nack_after_control_word(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "R GET WORD ADDR OR BYTE"
  elseif logicview.truth(logicview.eq(self.cmd, "NACK")) then
    self.es_block = self.es
    self:putb({ 0, { "Warning: No reply from slave!" } })
    self:reset_variables()
  else
    self:reset_variables()
  end
end
function _decoder.handle_r_get_word_addr_or_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "STOP")) then
    self.es_block = self.es
    self:putb({ 0, { "Warning: Slave replied, but master aborted!" } })
    self:reset_variables()
    return
  elseif logicview.truth((not logicview.eq(self.cmd, "DATA READ"))) then
    self:reset_variables()
    return
  end
  self:packet_append()
  self.state = "R GET ACK NACK AFTER WORD ADDR OR BYTE"
end
function _decoder.handle_r_get_ack_nack_after_word_addr_or_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "R GET RESTART"
  elseif logicview.truth(logicview.eq(self.cmd, "NACK")) then
    self.is_cur_addr_read = true
    self.state = "GET STOP AFTER LAST BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r_get_restart(self)
  if logicview.truth(logicview.eq(self.cmd, "RESTART")) then
    self.state = "R READ BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r_read_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "DATA READ")) then
    self:packet_append()
    self.state = "R GET ACK NACK AFTER BYTE WAS READ"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r_get_ack_nack_after_byte_was_read(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "R READ BYTE"
  elseif logicview.truth(logicview.eq(self.cmd, "NACK")) then
    self.state = "GET STOP AFTER LAST BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_w_get_ack_nack_after_control_word(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "W GET WORD ADDR"
  elseif logicview.truth(logicview.eq(self.cmd, "NACK")) then
    self.es_block = self.es
    self:putb({ 0, { "Warning: No reply from slave!" } })
    self:reset_variables()
  else
    self:reset_variables()
  end
end
function _decoder.handle_w_get_word_addr(self)
  if logicview.truth(logicview.eq(self.cmd, "STOP")) then
    self.es_block = self.es
    self:putb({ 0, { "Warning: Slave replied, but master aborted!" } })
    self:reset_variables()
    return
  elseif logicview.truth((not logicview.eq(self.cmd, "DATA WRITE"))) then
    self:reset_variables()
    return
  end
  self:packet_append()
  self.state = "W GET ACK AFTER WORD ADDR"
end
function _decoder.handle_w_get_ack_after_word_addr(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "W DETERMINE EEPROM READ OR WRITE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_w_determine_eeprom_read_or_write(self)
  if logicview.truth(logicview.eq(self.cmd, "START REPEAT")) then
    self.state = "R2 GET CONTROL WORD"
  elseif logicview.truth(logicview.eq(self.cmd, "DATA WRITE")) then
    self:packet_append()
    self.state = "W GET ACK NACK AFTER BYTE WAS WRITTEN"
  else
    self:reset_variables()
  end
end
function _decoder.handle_w_write_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "DATA WRITE")) then
    self:packet_append()
    self.state = "W GET ACK NACK AFTER BYTE WAS WRITTEN"
  elseif logicview.truth(logicview.eq(self.cmd, "STOP")) then
    if logicview.truth((logicview.len(self.bytebuf) < 2)) then
      self:reset_variables()
      return
    end
    self.es_block = self.es
    if logicview.truth(logicview.eq(logicview.len(self.bytebuf), 2)) then
      self.is_byte_write = true
    else
      self.is_page_write = true
    end
    self:put_operation()
    self:reset_variables()
  elseif logicview.truth(logicview.eq(self.cmd, "START REPEAT")) then
    self.state = "R2 GET CONTROL WORD"
  else
    self:reset_variables()
  end
end
function _decoder.handle_w_get_ack_nack_after_byte_was_written(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "W WRITE BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r2_get_control_word(self)
  if logicview.truth(logicview.eq(self.cmd, "ADDRESS READ")) then
    self:packet_append()
    self.state = "R2 GET ACK AFTER ADDR READ"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r2_get_ack_after_addr_read(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "R2 READ BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_r2_read_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "DATA READ")) then
    self:packet_append()
    self.state = "R2 GET ACK NACK AFTER BYTE WAS READ"
  elseif logicview.truth(logicview.eq(self.cmd, "STOP")) then
    self:decide_on_seq_or_rnd_read()
    self.es_block = self.es
    self:putb({ 0, { "Warning: STOP expected after a NACK (not ACK)" } })
    self:put_operation()
    self:reset_variables()
  else
    self:reset_variables()
  end
end
function _decoder.handle_r2_get_ack_nack_after_byte_was_read(self)
  if logicview.truth(logicview.eq(self.cmd, "ACK")) then
    self.state = "R2 READ BYTE"
  elseif logicview.truth(logicview.eq(self.cmd, "NACK")) then
    self:decide_on_seq_or_rnd_read()
    self.state = "GET STOP AFTER LAST BYTE"
  else
    self:reset_variables()
  end
end
function _decoder.handle_get_stop_after_last_byte(self)
  if logicview.truth(logicview.eq(self.cmd, "STOP")) then
    self.es_block = self.es
    self:put_operation()
    self:reset_variables()
  elseif logicview.truth(logicview.eq(self.cmd, "START REPEAT")) then
    self.es_block = self.es
    self:putb({ 0, { "Warning: STOP expected (not RESTART)" } })
    self:put_operation()
    self:reset_variables()
    self.ss_block = self.ss
    self.state = "GET CONTROL WORD"
  else
    self:reset_variables()
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local s, handle_state
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.cmd = logicview.idx(_lv_seq, 0)
      self.databyte = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(self.cmd, "BITS")) then
      self.bits = self.databyte
      return
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    s = logicview.pymod("handle_%s", logicview.replace(_string.lower(self.state), " ", "_", nil))
    handle_state = (function() local _v = self[s]; if _v == nil then return nil end; return _v end)()
    handle_state()
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
