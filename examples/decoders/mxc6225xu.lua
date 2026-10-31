-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012 Uwe Hermann <uwe@hermann-uwe.de>

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
local status, Decoder
local _decoder

status = logicview.dict({ sh = logicview.dict({ [0] = "none", [1] = "shake left", [2] = "shake right", [3] = "undefined" }), ori = logicview.dict({ [0] = "vertical in upright orientation", [1] = "rotated 90 degrees clockwise", [2] = "vertical in inverted orientation", [3] = "rotated 90 degrees counterclockwise" }), shth = logicview.dict({ [0] = "0.5g", [1] = "1.0g", [2] = "1.5g", [3] = "2.0g" }), shc = logicview.dict({ [0] = "16", [1] = "32", [2] = "64", [3] = "128" }), orc = logicview.dict({ [0] = "16", [1] = "32", [2] = "64", [3] = "128" }) })
_decoder = {
  api_version = 3,
  id = "mxc6225xu",
  name = "MXC6225XU",
  longname = "MEMSIC MXC6225XU",
  desc = "Digital Thermal Orientation Sensor (DTOS) protocol.",
  license = "gplv2+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "IC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "text", "Human-readable text" } },
  annotation_rows = {  },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.handle_reg_0x00(self, b)
  self:putx({ 0, { logicview.pymod("XOUT: %d", b) } })
end
function _decoder.handle_reg_0x01(self, b)
  self:putx({ 0, { logicview.pymod("YOUT: %d", b) } })
end
function _decoder.handle_reg_0x02(self, b)
  local int_val, s, ann, sh, tilt, ori, or_val
  int_val = ((b >> 7) & 1)
  s = (function() if logicview.truth(logicview.eq(int_val, 0)) then return "unchanged and no" else return "changed or" end end)()
  ann = logicview.pymod("INT = %d: Orientation %s shake event occurred\n", { int_val, s })
  sh = ((((b >> 6) & 1) << 1) | ((b >> 5) & 1))
  ann = logicview.add(ann, logicview.pymod("SH[1:0] = %s: Shake event: %s\n", { logicview.slice(logicview.bin(sh), 2, nil, nil), logicview.idx(logicview.idx(status, "sh"), sh) }))
  tilt = ((b >> 4) & 1)
  s = (function() if logicview.truth(logicview.eq(tilt, 0)) then return "" else return "not " end end)()
  ann = logicview.add(ann, logicview.pymod("TILT = %d: Orientation measurement is %svalid\n", { tilt, s }))
  ori = ((((b >> 3) & 1) << 1) | ((b >> 2) & 1))
  ann = logicview.add(ann, logicview.pymod("ORI[1:0] = %s: %s\n", { logicview.slice(logicview.bin(ori), 2, nil, nil), logicview.idx(logicview.idx(status, "ori"), ori) }))
  or_val = ((((b >> 1) & 1) << 1) | ((b >> 0) & 1))
  ann = logicview.add(ann, logicview.pymod("OR[1:0] = %s: %s\n", { logicview.slice(logicview.bin(or_val), 2, nil, nil), logicview.idx(logicview.idx(status, "ori"), or_val) }))
  self:putx({ 0, { ann } })
end
function _decoder.handle_reg_0x03(self, b)
  local pd, s, ann, shm, shth, shc, orc
  pd = ((b >> 7) & 1)
  s = (function() if logicview.truth(logicview.eq(pd, 0)) then return "Do not power down" else return "Power down" end end)()
  ann = logicview.pymod("PD = %d: %s the device (into a low-power state)\n", { pd, s })
  shm = ((b >> 6) & 1)
  ann = logicview.pymod("SHM = %d: Set shake mode to %d\n", { shm, shm })
  shth = ((((b >> 5) & 1) << 1) | ((b >> 4) & 1))
  ann = logicview.add(ann, logicview.pymod("SHTH[1:0] = %s: Set shake threshold to %s\n", { logicview.slice(logicview.bin(shth), 2, nil, nil), logicview.idx(logicview.idx(status, "shth"), shth) }))
  shc = ((((b >> 3) & 1) << 1) | ((b >> 2) & 1))
  ann = logicview.add(ann, logicview.pymod("SHC[1:0] = %s: Set shake count to %s readings\n", { logicview.slice(logicview.bin(shc), 2, nil, nil), logicview.idx(logicview.idx(status, "shc"), shc) }))
  orc = ((((b >> 1) & 1) << 1) | ((b >> 0) & 1))
  ann = logicview.add(ann, logicview.pymod("ORC[1:0] = %s: Set orientation count to %s readings\n", { logicview.slice(logicview.bin(orc), 2, nil, nil), logicview.idx(logicview.idx(status, "orc"), orc) }))
  self:putx({ 0, { ann } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, databyte, handle_reg
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
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth((not logicview.eq(cmd, "START"))) then
        return
      end
      self.state = "GET SLAVE ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET SLAVE ADDR")) then
      if logicview.truth((not logicview.eq(cmd, "ADDRESS WRITE"))) then
        return
      end
      self.state = "GET REG ADDR"
    elseif logicview.truth(logicview.eq(self.state, "GET REG ADDR")) then
      if logicview.truth((not logicview.eq(cmd, "DATA WRITE"))) then
        return
      end
      self.reg = databyte
      self.state = "WRITE REGS"
    elseif logicview.truth(logicview.eq(self.state, "WRITE REGS")) then
      if logicview.truth(logicview.eq(cmd, "START REPEAT")) then
        self.state = "READ REGS"
        return
      end
      if logicview.truth(logicview.eq(cmd, "DATA WRITE")) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
        self.reg = logicview.add(self.reg, 1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
      else
      end
    elseif logicview.truth(logicview.eq(self.state, "READ REGS")) then
      if logicview.truth(logicview.eq(cmd, "ADDRESS READ")) then
        self.state = "READ REGS2"
        return
      else
      end
    elseif logicview.truth(logicview.eq(self.state, "READ REGS2")) then
      if logicview.truth(logicview.eq(cmd, "DATA READ")) then
        handle_reg = (function() local _v = self[logicview.pymod("handle_reg_0x%02x", self.reg)]; if _v == nil then return nil end; return _v end)()
        handle_reg(databyte)
        self.reg = logicview.add(self.reg, 1)
      elseif logicview.truth(logicview.eq(cmd, "STOP")) then
        self.state = "IDLE"
      else
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
