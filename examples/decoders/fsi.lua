-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: agplv3
-- Copyright (C) 2020 Raptor Engineering, LLC <support@raptorengineering.com>

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
local fields, Decoder
local _decoder

fields = logicview.dict({ START = logicview.dict({ [1] = "Start of FSI cycle" }) })
_decoder = {
  api_version = 3,
  id = "fsi",
  name = "FSI",
  longname = "Flexible Service Interface",
  desc = "Protocol for FSI devices on Raptor OpenPOWER systems.",
  license = "agplv3",
  inputs = { "logic" },
  outputs = {  },
  tags = { "PC" },
  channels = { logicview.dict({ id = "data", name = "DATA", desc = "Frame" }), logicview.dict({ id = "clock", name = "CLOCK", desc = "Clock" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "warnings", "Warnings" }, { "start", "Start" }, { "cycle-type", "Cycle type" }, { "direction", "Direction" }, { "addr", "Address" }, { "data", "Data" }, { "commands", "Commands" }, { "crc", "CRC" }, { "turn-around", "TAR" } },
  annotation_rows = { { "data", "Data", { 1, 2, 3, 4, 5, 6, 7, 8 } }, { "warnings", "Warnings", { 0 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self.tar_cycles = 3
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.break_start_sample_number = 0
  self.break_counter = 0
  self.samplenum = 0
  self.samplenum_prev = 0
  self.fsi_data_prev = 0
  self.fsi_data_break_prev = 0
  self.crc_internal = 0
  self.response_received = 0
  self.crc_calculating = 0
  self.busy_seq_count = 0
  self.valid_response = 0
  self.prev_address = logicview.dict({  })
  self.prev_address_valid = logicview.dict({ [0] = false, [1] = false, [2] = false, [3] = false })
  self.ss_block = nil
  self.es_block = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.decode(self)
  local data, clk, fsi_data, fsi_clk, current_sample_number, crc_prev, crc_feedback
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [1] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      data = logicview.idx(_lv_seq, 0)
      clk = logicview.idx(_lv_seq, 1)
    end
    fsi_data = (not logicview.truth(data))
    fsi_clk = clk
    current_sample_number = self.samplenum
    if logicview.truth(fsi_clk) then
      if logicview.truth(logicview.eq(self.fsi_data_break_prev, 1)) then
        self.break_counter = logicview.add(self.break_counter, 1)
        if logicview.truth(logicview.eq(self.break_counter, 256)) then
          self.ss_block = self.break_start_sample_number
          self.es_block = current_sample_number
          self:putb({ 6, { "BREAK" } })
          self.state = "BREAK_TAR_QUEUED"
          self.busy_seq_count = 0
          self.valid_response = 0
          self.prev_address = logicview.dict({  })
          self.prev_address_valid = logicview.dict({ [0] = false, [1] = false, [2] = false, [3] = false })
          self.ss_block = current_sample_number
        end
      else
        if logicview.truth((self.break_counter > 256)) then
          self.es_block = current_sample_number
          self:putb({ 0, { "BREAK asserted in excess of specification cycles" } })
        end
        self.break_start_sample_number = current_sample_number
        self.break_counter = 0
      end
      self.fsi_data_break_prev = fsi_data
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "TAR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RX_SLAVE_ID")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RESPONSE")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RX_DATA")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RX_IPOLL_INTERRUPT_FIELD")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RX_IPOLL_DMA_CONTROL_FIELD")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "RX_IPOLL_DMA_CONTROL_FIELD")
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(self.state, "CRC")
  if not logicview.truth(_v) then return _v end
  _v = self.valid_response
  return _v
end)()
  return _v
end)()) then
      if logicview.truth(fsi_clk) then
        goto continue_1
      end
    elseif logicview.truth((not logicview.truth(fsi_clk))) then
      goto continue_1
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      self.crc_internal = 0
      self.response_received = 0
      if logicview.truth(logicview.eq(self.fsi_data_prev, 1)) then
        self.tx_slave_id = 0
        self.data_count = 2
        self.ss_block = self.samplenum_prev
        self.es_block = current_sample_number
        self:putb({ 1, { "START" } })
        self.ss_block = current_sample_number
        self.crc_calculating = 1
        self.state = "TX_SLAVE_ID"
      end
    elseif logicview.truth(logicview.eq(self.state, "TX_SLAVE_ID")) then
      self.crc_calculating = 1
      if logicview.truth((self.data_count > 0)) then
        self.tx_slave_id = ((self.tx_slave_id >> 1) | (self.fsi_data_prev << 1))
        self.data_count = (self.data_count - 1)
        if logicview.truth(logicview.eq(self.data_count, 0)) then
          self.es_block = current_sample_number
          self:putb({ 5, { logicview.pymod("Slave ID: 0x%01x", self.tx_slave_id) } })
          self.ss_block = current_sample_number
          self.command_count = 0
          self.command_code = 0
          self.command = nil
          self.valid_command = false
          self.state = "COMMAND"
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "COMMAND")) then
      self.crc_calculating = 1
      self.command_code = ((self.command_code << 1) | self.fsi_data_prev)
      self.command_count = logicview.add(self.command_count, 1)
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 3)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 4)
  return _v
end)()) then
        self.command = "ABS_ADR"
        self.valid_command = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 3)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 5)
  return _v
end)()) then
        self.command = "REL_ADR"
        self.valid_command = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 3)
  return _v
end)()) then
        self.command = "SAME_ADR"
        self.valid_command = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 3)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 2)
  return _v
end)()) then
        self.command = "D_POLL"
        self.valid_command = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 3)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 3)
  return _v
end)()) then
        self.command = "E_POLL"
        self.valid_command = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.command_count, 3)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command_code, 1)
  return _v
end)()) then
        self.command = "I_POLL"
        self.valid_command = true
      end
      if logicview.truth((function()
  local _v
  _v = (self.command_count > 7)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.valid_command, true)
  return _v
end)()) then
        if logicview.truth(logicview.eq(self.command_count, 8)) then
          self.es_block = current_sample_number
          self:putb({ 6, { logicview.pymod("Invalid command code: 0x%02x/%d", { self.command_code, self.command_count }) } })
          self:putb({ 0, { logicview.pymod("%s", "Invalid command code") } })
          self.ss_block = current_sample_number
          self.state = "IDLE"
        else
          self.es_block = current_sample_number
          self:putb({ 6, { logicview.pymod("Command: %s (0x%02x/%d)", { self.command, self.command_code, self.command_count }) } })
          self.ss_block = current_sample_number
          if logicview.truth(logicview.eq(self.command, "ABS_ADR")) then
            self.address_length = 21
            self.address_count = 0
            self.address = 0
            self.state = "DIRECTION"
          elseif logicview.truth(logicview.eq(self.command, "REL_ADR")) then
            self.address_length = 8
            self.address_count = 0
            self.address = 0
            self.state = "DIRECTION"
          elseif logicview.truth(logicview.eq(self.command, "SAME_ADR")) then
            self.address_length = 2
            self.address_count = 0
            self.address = 0
            self.state = "DIRECTION"
          elseif logicview.truth(logicview.eq(self.command, "D_POLL")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.command, "E_POLL")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.command, "I_POLL")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          else
            self.state = "IDLE"
          end
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "DIRECTION")) then
      self.crc_calculating = 1
      self.direction = self.fsi_data_prev
      self.es_block = current_sample_number
      if logicview.truth(logicview.eq(self.direction, 1)) then
        self:putb({ 3, { logicview.pymod("Direction: %s", "Read") } })
      else
        self:putb({ 3, { logicview.pymod("Direction: %s", "Write") } })
      end
      self.ss_block = current_sample_number
      if logicview.truth(logicview.eq(self.command, "REL_ADR")) then
        self.state = "REL_ADDRESS_SIGN"
      else
        self.state = "ADDRESS"
      end
    elseif logicview.truth(logicview.eq(self.state, "REL_ADDRESS_SIGN")) then
      self.crc_calculating = 1
      self.relative_address_negative = self.fsi_data_prev
      self.es_block = current_sample_number
      if logicview.truth(logicview.eq(self.relative_address_negative, 1)) then
        self:putb({ 5, { logicview.pymod("Relative address sign: %s", "(-)") } })
      else
        self:putb({ 5, { logicview.pymod("Relative address sign: %s", "(+)") } })
      end
      self.ss_block = current_sample_number
      self.state = "ADDRESS"
    elseif logicview.truth(logicview.eq(self.state, "ADDRESS")) then
      self.crc_calculating = 1
      self.address = ((self.address << 1) | self.fsi_data_prev)
      self.address_count = logicview.add(self.address_count, 1)
      if logicview.truth((self.address_count >= self.address_length)) then
        self.address_raw = self.address
        if logicview.truth(logicview.idx(self.prev_address_valid, self.tx_slave_id)) then
          if logicview.truth(logicview.eq(self.command, "SAME_ADR")) then
            self.address = ((logicview.idx(self.prev_address, self.tx_slave_id) & (~3)) | (self.address_raw & 3))
          elseif logicview.truth(logicview.eq(self.command, "REL_ADR")) then
            if logicview.truth(self.relative_address_negative) then
              self.address = (logicview.idx(self.prev_address, self.tx_slave_id) - (256 - self.address_raw))
            else
              self.address = logicview.add(logicview.idx(self.prev_address, self.tx_slave_id), self.address_raw)
            end
          end
        end
        self.es_block = current_sample_number
        if logicview.truth((function()
  local _v
  _v = logicview.eq(self.command, "SAME_ADR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command, "REL_ADR")
  return _v
end)()) then
          self:putb({ 5, { logicview.pymod("Address: 0x%06x (0x%03x)", { self.address, self.address_raw }) } })
          if logicview.truth((not logicview.truth(logicview.idx(self.prev_address_valid, self.tx_slave_id)))) then
            self:putb({ 0, { logicview.pymod("%s", "Base address for relative address not captured") } })
          end
        else
          self:putb({ 5, { logicview.pymod("Address: 0x%06x", self.address) } })
        end
        self.ss_block = current_sample_number
        self.state = "DATA_SIZE"
      end
    elseif logicview.truth(logicview.eq(self.state, "DATA_SIZE")) then
      self.crc_calculating = 1
      if logicview.truth((function()
  local _v
  _v = self.direction
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq((self.address_raw & 3), 3)
  if not logicview.truth(_v) then return _v end
  _v = self.fsi_data_prev
  return _v
end)()) then
        self.command_code = 63
        self.command_count = 6
        self.command = "TERM"
        self.es_block = current_sample_number
        self:putb({ 6, { logicview.pymod("Command: %s (0x%02x/%d)", { self.command, self.command_code, self.command_count }) } })
        self.ss_block = current_sample_number
        self.direction = 0
        self.busy_seq_count = 0
        self.crc = 0
        self.crc_count = 0
        self.state = "CRC"
      else
        if logicview.truth(logicview.eq(self.fsi_data_prev, 0)) then
          self.data_size = "BYTE"
        elseif logicview.truth(logicview.eq((self.address_raw & 3), 1)) then
          self.data_size = "WORD"
          self.address = ((self.address & (~3)) | 1)
        elseif logicview.truth(logicview.eq((self.address_raw & 1), 0)) then
          self.data_size = "HALF_WORD"
          self.address = (self.address & (~1))
        else
          self.data_size = "UNKNOWN"
        end
        self.es_block = current_sample_number
        if logicview.truth(logicview.eq(self.data_size, "UNKNOWN")) then
          self:putb({ 0, { logicview.pymod("Data Size: %s", "UNKNOWN") } })
          self.state = "IDLE"
        else
          self:putb({ 3, { logicview.pymod("Data Size: %s", self.data_size) } })
          if logicview.truth(logicview.eq(self.direction, 1)) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          else
            self.data = 0
            self.data_count = 0
            if logicview.truth(logicview.eq(self.data_size, "BYTE")) then
              self.data_length = 8
            elseif logicview.truth(logicview.eq(self.data_size, "HALF_WORD")) then
              self.data_length = 16
            elseif logicview.truth(logicview.eq(self.data_size, "WORD")) then
              self.data_length = 32
            else
              self.data_size = nil
            end
            self.state = "TX_DATA"
          end
        end
      end
      self.ss_block = current_sample_number
    elseif logicview.truth(logicview.eq(self.state, "TX_DATA")) then
      self.crc_calculating = 1
      self.data = ((self.data << 1) | self.fsi_data_prev)
      self.data_count = logicview.add(self.data_count, 1)
      if logicview.truth((self.data_count >= self.data_length)) then
        self.es_block = current_sample_number
        if logicview.truth(logicview.eq(self.data_size, "BYTE")) then
          self:putb({ 5, { logicview.pymod("Data: 0x%02x", self.data) } })
        elseif logicview.truth(logicview.eq(self.data_size, "HALF_WORD")) then
          self:putb({ 5, { logicview.pymod("Data: 0x%04x", self.data) } })
        else
          self:putb({ 5, { logicview.pymod("Data: 0x%08x", self.data) } })
        end
        self.ss_block = current_sample_number
        self.crc = 0
        self.crc_count = 0
        self.state = "CRC"
      end
    elseif logicview.truth(logicview.eq(self.state, "CRC")) then
      if logicview.truth(logicview.eq(self.crc_count, 0)) then
        self.computed_crc_tx_end = self.crc_internal
      end
      self.crc_calculating = 1
      self.crc = ((self.crc << 1) | self.fsi_data_prev)
      self.crc_count = logicview.add(self.crc_count, 1)
      if logicview.truth((self.crc_count >= 4)) then
        self.es_block = current_sample_number
        if logicview.truth(logicview.eq(self.crc, self.computed_crc_tx_end)) then
          self:putb({ 7, { logicview.pymod("CRC: 0x%01x (GOOD)", self.crc) } })
          if logicview.truth(self.response_received) then
            if logicview.truth((function()
  local _v
  _v = (function()
  local _v
  _v = logicview.eq(self.command, "ABS_ADR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command, "REL_ADR")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.command, "SAME_ADR")
  return _v
end)()
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = logicview.eq(self.response, "ACK_D")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response, "ACK")
  return _v
end)()
  return _v
end)()) then
              logicview.setidx(self.prev_address, self.tx_slave_id, self.address)
              logicview.setidx(self.prev_address_valid, self.tx_slave_id, true)
            end
          end
        else
          self:putb({ 7, { logicview.pymod("CRC: 0x%01x (BAD)", self.crc) } })
          self:putb({ 0, { logicview.pymod("%s", "Bad CRC") } })
        end
        self.ss_block = current_sample_number
        self.tar_timer = 0
        self.state = "TAR"
        self.timeout_counter = 0
      end
    elseif logicview.truth(logicview.eq(self.state, "BREAK_TAR_QUEUED")) then
      self.tar_timer = 0
      self.state = "BREAK_TAR"
    elseif logicview.truth(logicview.eq(self.state, "BREAK_TAR")) then
      self.tar_timer = logicview.add(self.tar_timer, 1)
      if logicview.truth((self.tar_timer > self.tar_cycles)) then
        self.crc_calculating = 0
        self.crc_internal = 0
        self.es_block = current_sample_number
        self:putb({ 8, { logicview.pymod("%s", "TAR") } })
        self.ss_block = current_sample_number
        self.state = "IDLE"
      end
    elseif logicview.truth(logicview.eq(self.state, "TAR")) then
      self.crc_calculating = 0
      self.crc_internal = 0
      self.tar_timer = logicview.add(self.tar_timer, 1)
      if logicview.truth((self.tar_timer > self.tar_cycles)) then
        if logicview.truth(logicview.eq(self.response_received, 1)) then
          self.response_received = 0
          if logicview.truth(logicview.eq(self.rx_slave_id, self.tx_slave_id)) then
            if logicview.truth(logicview.eq(self.response, "BUSY")) then
              self.busy_seq_count = logicview.add(self.busy_seq_count, 1)
            else
              self.busy_seq_count = 0
            end
            self.state = "IDLE"
          end
        end
        if logicview.truth(logicview.eq(self.timeout_counter, 0)) then
          self.es_block = self.samplenum_prev
          self:putb({ 8, { logicview.pymod("%s", "TAR") } })
          self.ss_block = current_sample_number
        end
        if logicview.truth(logicview.eq(self.fsi_data_prev, 1)) then
          self.crc_calculating = 1
          self.rx_slave_id = 0
          self.data_count = 2
          if logicview.truth(logicview.eq(self.state, "IDLE")) then
            self.state = "TX_SLAVE_ID"
          else
            self.state = "RX_SLAVE_ID"
          end
          self.ss_block = self.samplenum_prev
          self.es_block = current_sample_number
          self:putb({ 1, { "START" } })
          self.ss_block = current_sample_number
        else
          self.timeout_counter = logicview.add(self.timeout_counter, 1)
          if logicview.truth((self.timeout_counter >= 256)) then
            self.es_block = current_sample_number
            self:putb({ 8, { logicview.pymod("%s", "Response timeout") } })
            self:putb({ 0, { logicview.pymod("%s", "Response timeout") } })
            self.state = "IDLE"
          end
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "RX_SLAVE_ID")) then
      self.crc_calculating = 1
      self.response_received = 1
      if logicview.truth((self.data_count > 0)) then
        self.rx_slave_id = ((self.rx_slave_id >> 1) | (self.fsi_data_prev << 1))
        self.data_count = (self.data_count - 1)
        if logicview.truth(logicview.eq(self.data_count, 0)) then
          self.es_block = current_sample_number
          self:putb({ 5, { logicview.pymod("Slave ID: 0x%01x", self.rx_slave_id) } })
          if logicview.truth((not logicview.eq(self.rx_slave_id, self.tx_slave_id))) then
            self:putb({ 0, { logicview.pymod("%s", "Slave ID does not match active transaction") } })
          end
          self.ss_block = current_sample_number
          self.response_count = 0
          self.response_code = 0
          self.response = nil
          self.valid_response = false
          self.state = "RESPONSE"
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "RESPONSE")) then
      self.crc_calculating = 1
      self.response_code = ((self.response_code << 1) | self.fsi_data_prev)
      self.response_count = logicview.add(self.response_count, 1)
      if logicview.truth((function()
  local _v
  _v = logicview.eq(self.command, "I_POLL")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.rx_slave_id, self.tx_slave_id)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_count, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_code, 0)
  return _v
end)()) then
        self.response = "I_POLL_RSP"
        self.valid_response = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.response_count, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_code, 0)
  return _v
end)()) then
        if logicview.truth(logicview.eq(self.direction, 1)) then
          self.response = "ACK_D"
        else
          self.response = "ACK"
        end
        self.valid_response = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.response_count, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_code, 1)
  return _v
end)()) then
        self.response = "BUSY"
        self.valid_response = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.response_count, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_code, 2)
  return _v
end)()) then
        self.response = "ERR_A"
        self.valid_response = true
      elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.response_count, 2)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.response_code, 3)
  return _v
end)()) then
        self.response = "ERR_C"
        self.valid_response = true
      end
      if logicview.truth((function()
  local _v
  _v = (self.response_count > 2)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.valid_response, true)
  return _v
end)()) then
        if logicview.truth(logicview.eq(self.response_count, 8)) then
          self.es_block = current_sample_number
          self:putb({ 6, { logicview.pymod("Invalid response code: 0x%02x/%d", { self.response_code, self.response_count }) } })
          self:putb({ 0, { logicview.pymod("%s", "Invalid response code") } })
          self.ss_block = current_sample_number
          self.state = "IDLE"
        else
          self.es_block = current_sample_number
          self:putb({ 6, { logicview.pymod("Response: %s (0x%02x/%d)", { self.response, self.response_code, self.response_count }) } })
          self.ss_block = current_sample_number
          if logicview.truth(logicview.eq(self.response, "ACK_D")) then
            self.data = 0
            self.data_count = 0
            if logicview.truth(logicview.eq(self.data_size, "BYTE")) then
              self.data_length = 8
            elseif logicview.truth(logicview.eq(self.data_size, "HALF_WORD")) then
              self.data_length = 16
            elseif logicview.truth(logicview.eq(self.data_size, "WORD")) then
              self.data_length = 32
            else
              self.data_size = nil
            end
            self.state = "RX_DATA"
          elseif logicview.truth(logicview.eq(self.response, "ACK")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.response, "BUSY")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.response, "ERR_A")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.response, "ERR_C")) then
            self.crc = 0
            self.crc_count = 0
            self.state = "CRC"
          elseif logicview.truth(logicview.eq(self.response, "I_POLL_RSP")) then
            self.data = 0
            self.data_count = 0
            self.data_length = 2
            self.state = "RX_IPOLL_INTERRUPT_FIELD"
          else
            self.state = "IDLE"
          end
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "RX_DATA")) then
      self.crc_calculating = 1
      self.data = ((self.data << 1) | self.fsi_data_prev)
      self.data_count = logicview.add(self.data_count, 1)
      if logicview.truth((self.data_count >= self.data_length)) then
        self.es_block = current_sample_number
        self:putb({ 5, { logicview.pymod("Data: 0x%08x", self.data) } })
        self.ss_block = current_sample_number
        self.crc = 0
        self.crc_count = 0
        self.state = "CRC"
      end
    elseif logicview.truth(logicview.eq(self.state, "RX_IPOLL_INTERRUPT_FIELD")) then
      self.crc_calculating = 1
      self.data = ((self.data << 1) | self.fsi_data_prev)
      self.data_count = logicview.add(self.data_count, 1)
      if logicview.truth((self.data_count >= self.data_length)) then
        self.es_block = current_sample_number
        self:putb({ 5, { logicview.pymod("Interrupt Field: 0x%01x", self.data) } })
        self.ss_block = current_sample_number
        self.data = 0
        self.data_count = 0
        self.data_length = 3
        self.state = "RX_IPOLL_DMA_CONTROL_FIELD"
      end
    elseif logicview.truth(logicview.eq(self.state, "RX_IPOLL_DMA_CONTROL_FIELD")) then
      self.crc_calculating = 1
      self.data = ((self.data << 1) | self.fsi_data_prev)
      self.data_count = logicview.add(self.data_count, 1)
      if logicview.truth((self.data_count >= self.data_length)) then
        self.es_block = current_sample_number
        self:putb({ 5, { logicview.pymod("DMA Control Field: 0x%01x", self.data) } })
        self.ss_block = current_sample_number
        self.crc = 0
        self.crc_count = 0
        self.state = "CRC"
      end
    end
    crc_prev = self.crc_internal
    if logicview.truth(self.crc_calculating) then
      crc_feedback = ((((crc_prev >> 3) & 1) ~ self.fsi_data_prev) & 1)
    end
    if logicview.truth(self.crc_calculating) then
      self.crc_internal = ((self.crc_internal & (~(1 << 0))) | ((crc_feedback & 1) << 0))
      self.crc_internal = ((self.crc_internal & (~(1 << 1))) | ((((crc_prev & 1) ~ crc_feedback) & 1) << 1))
      self.crc_internal = ((self.crc_internal & (~(1 << 2))) | (((((crc_prev >> 1) & 1) ~ crc_feedback) & 1) << 2))
      self.crc_internal = ((self.crc_internal & (~(1 << 3))) | ((((crc_prev >> 2) & 1) & 1) << 3))
    end
    self.fsi_data_prev = fsi_data
    self.samplenum_prev = current_sample_number
    ::continue_1::
  end
end

return _decoder
