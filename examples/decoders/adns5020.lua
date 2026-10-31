-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Karl Palsson <karlp@tweak.net.au>
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
local regs, Decoder
local _decoder

regs = logicview.dict({ [0] = "Product_ID", [1] = "Revision_ID", [2] = "Motion", [3] = "Delta_X", [4] = "Delta_Y", [5] = "SQUAL", [6] = "Shutter_Upper", [7] = "Shutter_Lower", [8] = "Maximum_Pixel", [9] = "Pixel_Sum", [10] = "Minimum_Pixel", [11] = "Pixel_Grab", [13] = "Mouse_Control", [58] = "Chip_Reset", [63] = "Inv_Rev_ID", [99] = "Motion_Burst" })
_decoder = {
  api_version = 3,
  id = "adns5020",
  name = "ADNS-5020",
  longname = "Avago ADNS-5020",
  desc = "Bidirectional optical mouse sensor protocol.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "IC", "PC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "read", "Register read commands" }, { "write", "Register write commands" }, { "warning", "Warnings" } },
  annotation_rows = { { "read", "Read", { 0 } }, { "write", "Write", { 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self.mosi_bytes = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.put_warn(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 2, { msg } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, mosi, miso, cmd, arg, write, reg, reg_desc
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
  _v = logicview.eq(cs_old, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 1)
  return _v
end)()) then
        if logicview.truth((not logicview.contains({ 0, 2 }, logicview.len(self.mosi_bytes)))) then
          self:put_warn({ self.ss_cmd, es }, "Misplaced CS#!")
          self.mosi_bytes = {  }
        end
      end
      return
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_seq = logicview.slice(data, 1, nil, nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      mosi = logicview.idx(_lv_seq, 0)
      miso = logicview.idx(_lv_seq, 1)
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
    if logicview.truth((not logicview.eq(logicview.len(self.mosi_bytes), 2))) then
      return
    end
    self.es_cmd = es
    do
      local _lv_seq = self.mosi_bytes
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      arg = logicview.idx(_lv_seq, 1)
    end
    write = (cmd & 128)
    reg = (cmd & 127)
    reg_desc = logicview.dget(regs, reg, logicview.pymod("Reserved %#x", reg))
    if logicview.truth((reg > 99)) then
      reg_desc = "Unknown"
    end
    if logicview.truth(write) then
      self:putx({ 1, { logicview.pymod("%s: {$}", reg_desc), logicview.pymod("@%02X", arg) } })
    else
      self:putx({ 0, { logicview.pymod("%s: {$}", reg_desc), logicview.pymod("@%02X", arg) } })
    end
    self.mosi_bytes = {  }
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
