-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2012-2015 Uwe Hermann <uwe@hermann-uwe.de>

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
local ir, bs_ir, cm3_idcode, cm3_idcode_ver, cm3_idcode_part, jedec_id, jtag_idcode, ack_val, dp_reg, apb_ap_reg, decode_device_id_code, data_in, data_out, Decoder
local _decoder

ir = logicview.dict({ ["1111"] = { "BYPASS", 1 }, ["1110"] = { "IDCODE", 32 }, ["1010"] = { "DPACC", 35 }, ["1011"] = { "APACC", 35 }, ["1000"] = { "ABORT", 35 } })
bs_ir = logicview.dict({ ["11111"] = { "BYPASS", 1 } })
cm3_idcode = 1000342647
cm3_idcode_ver = logicview.dict({ [3] = "JTAG-DP", [2] = "SW-DP" })
cm3_idcode_part = logicview.dict({ [47616] = "JTAG-DP", [47632] = "SW-DP" })
jedec_id = logicview.dict({ [5] = logicview.dict({ [59] = "ARM Ltd." }) })
jtag_idcode = logicview.dict({ [104931393] = "Low-density device, rev. A", [104923201] = "Medium-density device, rev. A", [373358657] = "Medium-density device, rev. B/Z/Y", [104939585] = "High-density device, rev. A/Z/Y", [105054273] = "XL-density device, rev. A", [104955969] = "Connectivity-line device, rev. A/Z" })
ack_val = logicview.dict({ ["001"] = "WAIT", ["010"] = "OK/FAULT" })
dp_reg = logicview.dict({ ["00"] = "Reserved", ["01"] = "DP CTRL/STAT", ["10"] = "DP SELECT", ["11"] = "DP RDBUFF" })
apb_ap_reg = logicview.dict({ [0] = { "CSW", "Control/status word" }, [4] = { "TAR", "Transfer address" }, [12] = { "DRW", "Data read/write" }, [16] = { "BD0", "Banked data 0" }, [20] = { "BD1", "Banked data 1" }, [24] = { "BD2", "Banked data 2" }, [28] = { "BD3", "Banked data 3" }, [34359738368] = { "ROM", "Debug ROM address" }, [252] = { "IDR", "Identification register" } })
decode_device_id_code = function(bits)
  local id_hex, ver, part, ids, manuf
  id_hex = logicview.pymod("0x%x", logicview.tointeger(logicview.add("0b", bits), 2))
  ver = logicview.dget(cm3_idcode_ver, logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-32), (-28), nil)), 2), "UNKNOWN")
  part = logicview.dget(cm3_idcode_part, logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-28), (-12), nil)), 2), "UNKNOWN")
  ids = logicview.dget(jedec_id, logicview.add(logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-12), (-8), nil)), 2), 1), logicview.dict({  }))
  manuf = logicview.dget(ids, logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-7), (-1), nil)), 2), "UNKNOWN")
  return { id_hex, manuf, ver, part }
end
data_in = function(instruction, bits)
  local data, a, rnw, data_hex, r, reg
  do
    local _lv_a0, _lv_a1, _lv_a2 = logicview.slice(bits, nil, (-3), nil), logicview.slice(bits, (-3), (-1), nil), logicview.idx(bits, (-1))
    data = _lv_a0
    a = _lv_a1
    rnw = _lv_a2
  end
  data_hex = logicview.pymod("0x%x", logicview.tointeger(logicview.add("0b", data), 2))
  r = (function() if logicview.truth(logicview.eq(rnw, "1")) then return "Read request" else return "Write request" end end)()
  reg = (function() if logicview.truth(logicview.eq(instruction, "DPACC")) then return logicview.idx(dp_reg, a) else return a end end)()
  return logicview.pymod("New transaction: DATA: %s, A: %s, RnW: %s", { data_hex, reg, r })
end
data_out = function(bits)
  local data, ack, data_hex, ack_meaning
  do
    local _lv_a0, _lv_a1 = logicview.slice(bits, nil, (-3), nil), logicview.slice(bits, (-3), nil, nil)
    data = _lv_a0
    ack = _lv_a1
  end
  data_hex = logicview.pymod("0x%x", logicview.tointeger(logicview.add("0b", data), 2))
  ack_meaning = logicview.dget(ack_val, ack, "Reserved")
  return logicview.pymod("Previous transaction result: DATA: %s, ACK: %s", { data_hex, ack_meaning })
end
_decoder = {
  api_version = 3,
  id = "jtag_stm32",
  name = "JTAG / STM32",
  longname = "Joint Test Action Group / ST STM32",
  desc = "ST STM32-specific JTAG protocol.",
  license = "gplv2+",
  inputs = { "jtag" },
  outputs = {  },
  tags = { "Debug/trace" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "item", "Item" }, { "field", "Field" }, { "command", "Command" }, { "warning", "Warning" } },
  annotation_rows = { { "items", "Items", { 0 } }, { "fields", "Fields", { 1 } }, { "commands", "Commands", { 2 } }, { "warnings", "Warnings", { 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "IDLE"
  self.samplenums = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putf(self, s, e, data)
  self:put(logicview.idx(logicview.idx(self.samplenums, s), 0), logicview.idx(logicview.idx(self.samplenums, e), 1), self.out_ann, data)
end
function _decoder.handle_reg_bypass(self, cmd, bits)
  self:putx({ 0, { logicview.add("BYPASS: ", bits) } })
end
function _decoder.handle_reg_idcode(self, cmd, bits)
  local id_hex, manuf, ver, part, cc, ic
  bits = logicview.slice(bits, 1, nil, nil)
  do
    local _lv_seq = decode_device_id_code(bits)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    id_hex = logicview.idx(_lv_seq, 0)
    manuf = logicview.idx(_lv_seq, 1)
    ver = logicview.idx(_lv_seq, 2)
    part = logicview.idx(_lv_seq, 3)
  end
  cc = logicview.pymod("0x%x", logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-12), (-8), nil)), 2))
  ic = logicview.pymod("0x%x", logicview.tointeger(logicview.add("0b", logicview.slice(bits, (-7), (-1), nil)), 2))
  self:putf(0, 0, { 1, { "Reserved", "Res", "R" } })
  self:putf(8, 11, { 0, { logicview.pymod("Continuation code: %s", cc), "CC", "C" } })
  self:putf(1, 7, { 0, { logicview.pymod("Identity code: %s", ic), "IC", "I" } })
  self:putf(1, 11, { 1, { logicview.pymod("Manufacturer: %s", manuf), "Manuf", "M" } })
  self:putf(12, 27, { 1, { logicview.pymod("Part: %s", part), "Part", "P" } })
  self:putf(28, 31, { 1, { logicview.pymod("Version: %s", ver), "Version", "V" } })
  self:putf(32, 32, { 1, { "BYPASS (BS TAP)", "BS", "B" } })
  self:putx({ 2, { logicview.pymod("IDCODE: %s (%s: %s/%s)", decode_device_id_code(bits)) } })
end
function _decoder.handle_reg_dpacc(self, cmd, bits)
  local s
  bits = logicview.slice(bits, 1, nil, nil)
  s = (function() if logicview.truth(logicview.eq(cmd, "DR TDI")) then return data_in("DPACC", bits) else return data_out(bits) end end)()
  self:putx({ 2, { s } })
end
function _decoder.handle_reg_apacc(self, cmd, bits)
  local s
  bits = logicview.slice(bits, 1, nil, nil)
  s = (function() if logicview.truth(logicview.eq(cmd, "DR TDI")) then return data_in("APACC", bits) else return data_out(bits) end end)()
  self:putx({ 2, { s } })
end
function _decoder.handle_reg_abort(self, cmd, bits)
  local a, s
  bits = logicview.slice(bits, 1, nil, nil)
  a = (function() if logicview.truth(logicview.eq(logicview.idx(bits, 0), "1")) then return "" else return "No " end end)()
  s = logicview.pymod("DAPABORT = %s: %sDAP abort generated", { logicview.idx(bits, 0), a })
  self:putx({ 2, { s } })
  if logicview.truth((not logicview.eq(logicview.slice(bits, nil, (-1), nil), logicview.mul("0", 31)))) then
    self:putx({ 3, { "WARNING: DAPABORT[31:1] reserved!" } })
  end
end
function _decoder.handle_reg_unknown(self, cmd, bits)
  bits = logicview.slice(bits, 1, nil, nil)
  self:putx({ 2, { logicview.pymod("Unknown instruction: %s", bits) } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, val, bstap_ir, handle_reg
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      val = logicview.idx(_lv_seq, 1)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth((not logicview.eq(cmd, "NEW STATE"))) then
      do
        local _lv_seq = val
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        val = logicview.idx(_lv_seq, 0)
        self.samplenums = logicview.idx(_lv_seq, 1)
      end
      logicview.list_reverse(self.samplenums)
    end
    if logicview.truth(logicview.eq(cmd, "IR TDI")) then
      self.state = logicview.idx(logicview.dget(ir, logicview.slice(val, 5, 9, nil), { "UNKNOWN", 0 }), 0)
      bstap_ir = logicview.idx(logicview.dget(bs_ir, logicview.slice(val, nil, 5, nil), { "UNKNOWN", 0 }), 0)
      self:putf(4, 8, { 1, { logicview.add("IR (BS TAP): ", bstap_ir) } })
      self:putf(0, 3, { 1, { logicview.add("IR (M3 TAP): ", self.state) } })
      self:putx({ 2, { logicview.pymod("IR: %s", self.state) } })
    end
    if logicview.truth(logicview.eq(self.state, "BYPASS")) then
      if logicview.truth((not logicview.eq(cmd, "DR TDI"))) then
        return
      end
      handle_reg = (function() local _v = self[logicview.pymod("handle_reg_%s", _string.lower(self.state))]; if _v == nil then return nil end; return _v end)()
      handle_reg(cmd, val)
      self.state = "IDLE"
    elseif logicview.truth(logicview.contains({ "IDCODE", "ABORT", "UNKNOWN" }, self.state)) then
      if logicview.truth((not logicview.eq(cmd, "DR TDO"))) then
        return
      end
      handle_reg = (function() local _v = self[logicview.pymod("handle_reg_%s", _string.lower(self.state))]; if _v == nil then return nil end; return _v end)()
      handle_reg(cmd, val)
      self.state = "IDLE"
    elseif logicview.truth(logicview.contains({ "DPACC", "APACC" }, self.state)) then
      if logicview.truth((not logicview.contains({ "DR TDI", "DR TDO" }, cmd))) then
        return
      end
      handle_reg = (function() local _v = self[logicview.pymod("handle_reg_%s", _string.lower(self.state))]; if _v == nil then return nil end; return _v end)()
      handle_reg(cmd, val)
      if logicview.truth(logicview.eq(cmd, "DR TDO")) then
        self.state = "IDLE"
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
