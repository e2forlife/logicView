-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: BSD
-- Copyright (C) 2018 Elias Oenal <sigrok@eliasoenal.com>

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
local MODULE_ID, Decoder
local _decoder

MODULE_ID = logicview.dict({ [0] = "Unknown or unspecified", [1] = "GBIC", [2] = "Module/connector soldered to motherboard", [3] = "SFP", [4] = "300 pin XSBI", [5] = "XENPAK", [6] = "XFP", [7] = "XFF", [8] = "XFP-E", [9] = "XPAK", [10] = "X2", [11] = "DWDM-SFP", [12] = "QSFP", [13] = "QSFP+", [14] = "CFP", [15] = "CXP (TBD)", [17] = "CFP2", [18] = "CFP4" })
_decoder = {
  api_version = 3,
  id = "cfp",
  name = "CFP",
  longname = "100 Gigabit C form-factor pluggable",
  desc = "100 Gigabit C form-factor pluggable (CFP) protocol.",
  license = "BSD",
  inputs = { "mdio" },
  outputs = {  },
  tags = { "Networking" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "register", "Register" }, { "decode", "Decode" } },
  annotation_rows = { { "registers", "Registers", { 0 } }, { "decodes", "Decodes", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local clause45, clause45_addr, is_read, portad, devad, reg
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    for _lv_item in logicview.iter(data) do
      clause45 = logicview.idx(_lv_item, 0)
      clause45_addr = logicview.idx(_lv_item, 1)
      is_read = logicview.idx(_lv_item, 2)
      portad = logicview.idx(_lv_item, 3)
      devad = logicview.idx(_lv_item, 4)
      reg = logicview.idx(_lv_item, 5)
      if logicview.truth((not logicview.truth(is_read))) then
        goto continue_1
      end
      if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(32768, logicview.add(32895, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "CFP NVR 1: Basic ID register", "NVR1" } })
        if logicview.truth(logicview.eq(clause45_addr, 32768)) then
          self:putx({ 1, { logicview.pymod("Module identifier: %s", logicview.dget(MODULE_ID, reg, "Reserved")) } })
        end
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(32896, logicview.add(33023, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "CFP NVR 2: Extended ID register", "NVR2" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(33024, logicview.add(33151, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "CFP NVR 3: Network lane specific register", "NVR3" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(33152, logicview.add(33279, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "CFP NVR 4", "NVR4" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(33792, logicview.add(33919, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "Vendor NVR 1: Vendor data register", "V-NVR1" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(33920, logicview.add(34047, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "Vendor NVR 2: Vendor data register", "V-NVR2" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(34816, logicview.add(34943, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "User NVR 1: User data register", "U-NVR1" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(34944, logicview.add(35071, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "User NVR 2: User data register", "U-NVR2" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(40960, logicview.add(41087, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "CFP Module VR 1: CFP Module level control and DDM register", "Mod-VR1" } })
      elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range(41088, logicview.add(41215, 1)) do _t[#_t + 1] = _v end; return _t end)(), clause45_addr)) then
        self:putx({ 0, { "MLG VR 1: MLG Management Interface register", "MLG-VR1" } })
      end
      ::continue_1::
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
