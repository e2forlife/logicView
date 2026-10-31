-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Dave Craig <dcraig@brightsign.biz>

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
local msg_ids, write_items, Decoder
local _decoder

msg_ids = logicview.dict({ [2] = "AKE_Init", [3] = "AKE_Send_Cert", [4] = "AKE_No_stored_km", [5] = "AKE_Stored_km", [7] = "AKE_Send_H_prime", [8] = "AKE_Send_Pairing_Info", [9] = "LC_Init", [10] = "LC_Send_L_prime", [11] = "SKE_Send_Eks", [12] = "RepeaterAuth_Send_ReceiverID_List", [15] = "RepeaterAuth_Send_Ack", [16] = "RepeaterAuth_Stream_Manage", [17] = "RepeaterAuth_Stream_Ready" })
write_items = logicview.dict({ [0] = "1.4 Bksv - Receiver KSV", [8] = "1.4 Ri' - Link Verification", [10] = "1.4 Pj' - Enhanced Link Verification", [16] = "1.4 Aksv - Transmitter KSV", [21] = "1.4 Ainfo - Transmitter KSV", [24] = "1.4 An - Session random number", [32] = "1.4 V'H0", [36] = "1.4 V'H1", [40] = "1.4 V'H2", [44] = "1.4 V'H3", [48] = "1.4 V'H4", [64] = "1.4 Bcaps", [65] = "1.4 Bstatus", [67] = "1.4 KSV FIFO", [80] = "HDCP2Version", [96] = "Write_Message", [112] = "RxStatus", [128] = "Read_Message" })
_decoder = {
  api_version = 3,
  id = "hdcp",
  name = "HDCP",
  longname = "HDCP over HDMI",
  desc = "HDCP protocol over HDMI.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = { "hdcp" },
  tags = { "PC", "Security/crypto" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "message-0x00", "Message 0x00" }, { "message-0x01", "Message 0x01" }, { "message-0x02", "Message 0x02" }, { "message-0x03", "Message 0x03" }, { "message-0x04", "Message 0x04" }, { "message-0x05", "Message 0x05" }, { "message-0x06", "Message 0x06" }, { "message-0x07", "Message 0x07" }, { "message-0x08", "Message 0x08" }, { "message-0x09", "Message 0x09" }, { "message-0x0A", "Message 0x0A" }, { "message-0x0B", "Message 0x0B" }, { "message-0x0C", "Message 0x0C" }, { "message-0x0D", "Message 0x0D" }, { "message-0x0E", "Message 0x0E" }, { "message-0x0F", "Message 0x0F" }, { "message-0x10", "Message 0x10" }, { "message-0x11", "Message 0x11" }, { "summary", "Summary" }, { "warning", "Warning" } },
  annotation_rows = { { "messages", "Messages", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 } }, { "summaries", "Summaries", { 18 } }, { "warnings", "Warnings", { 19 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.stack = {  }
  self.msg = (-1)
  do
    local _lv_chain = 0
    self.ss = _lv_chain
    self.es = _lv_chain
    self.ss_block = _lv_chain
    self.es_block = _lv_chain
  end
  self.init_seq = {  }
  self.valid = 0
  self.type = ""
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putb(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, rxstatus, reauth_req, ready, length, text, bstatus, device_count, max_devs_exceeded, depth, max_cascase_exceeded, hdmi_mode, msg, version
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      databyte = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(cmd, "BITS")) then
      self.bits = databyte
      return
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(logicview.eq(cmd, "START")) then
        self:reset()
        self.ss_block = ss
      elseif logicview.truth((not logicview.eq(cmd, "START REPEAT"))) then
        return
      end
      self.state = "GET SLAVE ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "BUFFER DATA"
        if logicview.truth((not logicview.eq(databyte, 58))) then
          self.state = "IDLE"
        end
      elseif logicview.truth(logicview.eq(cmd, "ADDRESS WRITE")) then
        self.state = "WRITE OFFSET"
        if logicview.truth((not logicview.eq(databyte, 58))) then
          self.state = "IDLE"
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "WRITE OFFSET")) then
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        if logicview.truth(logicview.contains(write_items, databyte)) then
          self.type = logicview.idx(write_items, databyte)
        end
        if logicview.truth(logicview.contains({ 16, 21, 24, 96 }, databyte)) then
          self.state = "BUFFER DATA"
        end
        if logicview.truth(logicview.eq(self.state, "BUFFER DATA")) then
        elseif logicview.truth((not logicview.eq(self.type, ""))) then
          self.state = "IDLE"
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "BUFFER DATA")) then
      if logicview.truth(logicview.contains({ "STOP", "NACK" }, cmd)) then
        self.es_block = es
        self.state = "IDLE"
        if logicview.truth(logicview.eq(self.type, "")) then
          return
        end
        if logicview.truth((not logicview.truth(self.stack))) then
          self:putb({ 18, { logicview.pymod("%s", self.type) } })
          return
        end
        if logicview.truth(logicview.eq(self.type, "RxStatus")) then
          rxstatus = ((logicview.list_pop(self.stack) << 8) | logicview.list_pop(self.stack))
          reauth_req = (not logicview.eq((rxstatus & 2048), 0))
          ready = (not logicview.eq((rxstatus & 1024), 0))
          length = (rxstatus & 1023)
          text = logicview.pymod("%s, reauth %s, ready %s, length %s", { self.type, reauth_req, ready, length })
          self:putb({ 18, { text } })
        elseif logicview.truth(logicview.eq(self.type, "1.4 Bstatus")) then
          bstatus = ((logicview.list_pop(self.stack) << 8) | logicview.list_pop(self.stack))
          device_count = (bstatus & 127)
          max_devs_exceeded = (not logicview.eq((bstatus & 128), 0))
          depth = ((bstatus & 1792) >> 8)
          max_cascase_exceeded = (bstatus & 2048)
          hdmi_mode = (not logicview.eq((bstatus & 4096), 0))
          text = logicview.pymod("%s, %s devices, depth %s, hdmi mode %s", { self.type, device_count, depth, hdmi_mode })
          self:putb({ 18, { text } })
        elseif logicview.truth(logicview.eq(self.type, "Read_Message")) then
          msg = logicview.list_pop(self.stack, 0)
          self:putb({ msg, { logicview.pymod("%s, %s", { self.type, logicview.dget(msg_ids, msg, "Invalid") }) } })
        elseif logicview.truth(logicview.eq(self.type, "Write_Message")) then
          msg = logicview.list_pop(self.stack, 0)
          self:putb({ msg, { logicview.pymod("%s, %s", { self.type, logicview.dget(msg_ids, msg, "Invalid") }) } })
        elseif logicview.truth(logicview.eq(self.type, "HDCP2Version")) then
          version = logicview.list_pop(self.stack, 0)
          if logicview.truth((version & 4)) then
            self:putb({ 18, { "HDCP2" } })
          else
            self:putb({ 18, { "NOT HDCP2" } })
          end
        else
          self:putb({ 18, { logicview.pymod("%s", self.type) } })
        end
      elseif logicview.truth(logicview.eq(cmd, "DATA READ")) then
        _table.insert(self.stack, databyte)
      elseif logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        _table.insert(self.stack, databyte)
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
