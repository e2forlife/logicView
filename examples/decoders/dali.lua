-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Jeremy Swanson <jeremy@rakocontrols.com>

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
local SamplerateError, Decoder, extended_commands, dali_commands, dali_device_type8
local _decoder

extended_commands = logicview.dict({ [161] = { "Terminate special processes", "Terminate" }, [163] = { "DTR = DATA", "DTR" }, [165] = { "INITIALISE", "INIT" }, [167] = { "RANDOMISE", "RAND" }, [169] = { "COMPARE", "COMP" }, [171] = { "WITHDRAW", "WDRAW" }, [177] = { "SET SEARCH H", "SAH" }, [179] = { "SET SEARCH M", "SAM" }, [181] = { "SET SEARCH L", "SAL" }, [183] = { "Program Short Address", "ProgSA" }, [185] = { "Verify Short Address", "VfySA" }, [187] = { "Query Short Address", "QryShort" }, [189] = { "Physical Selection", "PysSel" }, [193] = { "Enable Device Type X", "EnTyp" }, [195] = { "DTR1 = DATA", "DTR1" }, [197] = { "DTR2 = DATA", "DTR2" }, [199] = { "Write Memory Location", "WRI" } })
dali_commands = logicview.dict({ [0] = { "Immediate Off", "IOFF" }, [1] = { "Up 200ms", "Up" }, [2] = { "Down 200ms", "Down" }, [3] = { "Step Up", "Step+" }, [4] = { "Step Down", "Step-" }, [5] = { "Recall Maximum Level", "Recall Max" }, [6] = { "Recall Minimum Level", "Recall Min" }, [7] = { "Step down and off", "Down Off" }, [8] = { "Step ON and UP", "On Up" }, [32] = { "Reset", "Rst" }, [33] = { "Store Dim Level in DTR", "Level -> DTR" }, [42] = { "Store DTR as Max Level", "DTR->Max" }, [43] = { "Store DTR as Min Level", "DTR->Min" }, [44] = { "Store DTR as Fail Level", "DTR->Fail" }, [45] = { "Store DTR as Power On Level", "DTR->Poweron" }, [46] = { "Store DTR as Fade Time", "DTR->Fade" }, [47] = { "Store DTR as Fade Rate", "DTR->Rate" }, [128] = { "Store DTR as Short Address", "DTR->Add" }, [129] = { "Enable Memory Write", "WEn" }, [144] = { "Query Status", "Status" }, [145] = { "Query Ballast", "Ballast" }, [146] = { "Query Lamp Failure", "LmpFail" }, [147] = { "Query Power On", "Power On" }, [148] = { "Query Limit Error", "Limit Err" }, [149] = { "Query Reset", "Reset State" }, [150] = { "Query Missing Short Address", "NoSrt" }, [151] = { "Query Version", "Ver" }, [152] = { "Query DTR", "GetDTR" }, [153] = { "Query Device Type", "Type" }, [154] = { "Query Physical Minimum", "PhysMin" }, [155] = { "Query Power Fail", "PowerFailed" }, [156] = { "Query DTR1", "GetDTR1" }, [157] = { "Query DTR2", "GetDTR2" }, [160] = { "Query Level", "GetLevel" }, [161] = { "Query Max Level", "GetMax" }, [162] = { "Query Min Level", "GetMin" }, [163] = { "Query Power On", "GetPwrOn" }, [164] = { "Query Fail Level", "GetFail" }, [165] = { "Query Fade Rate", "GetRate" }, [166] = { "Query Power Fail", "PwrFail" }, [192] = { "Query Groups 0-7", "GetGrpsL" }, [193] = { "Query Groups 7-15", "GetGrpsH" }, [194] = { "Query BRNH", "BRNH" }, [195] = { "Query BRNM", "BRNM" }, [196] = { "Query BRNL", "BRNL" }, [197] = { "Query Memory", "GetMem" } })
dali_device_type8 = logicview.dict({ [224] = { "Set Temp X-Y Coordinate", "Set X-Y" }, [226] = { "Activate Colour Set point", "Activate SetPoint" }, [231] = { "Set Colour Temperature Tc", "DTRs->ColTemp" }, [249] = { "Query Features", "QryFeats" }, [250] = { "Query Current Setpoint Colour", "GetSetPoint" } })

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "dali",
  name = "DALI",
  longname = "Digital Addressable Lighting Interface",
  desc = "Digital Addressable Lighting Interface (DALI) protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial", "Lighting" },
  channels = { logicview.dict({ id = "dali", name = "DALI", desc = "DALI data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-low", values = { "active-low", "active-high" } }) },
  annotations = { { "bit", "Bit" }, { "startbit", "Startbit" }, { "sbit", "Select bit" }, { "ybit", "Individual or group" }, { "address", "Address" }, { "command", "Command" }, { "reply", "Reply data" }, { "raw", "Raw data" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "raw", "Raw data", { 7 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.samplenum = nil
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.bits = _lv_a1
    self.ss_es_bits = _lv_a2
  end
  self.state = "IDLE"
  self.dev_type = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.old_dali = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return 1 else return 0 end end)()
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.halfbit = logicview.tointeger((logicview.mul(self.samplerate, 0.0008333) / 2.0))
  end
end
function _decoder.putb(self, bit1, bit2, data)
  local ss, es
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(self.ss_es_bits, bit1), 0), logicview.idx(logicview.idx(self.ss_es_bits, bit2), 1)
    ss = _lv_a0
    es = _lv_a1
  end
  self:put(ss, es, self.out_ann, data)
end
function _decoder.handle_bits(self, length)
  local a, c, f, g, b, i, ss, es, s, x, un, ln
  do
    local _lv_a0, _lv_a1, _lv_a2, _lv_a3, _lv_a4 = 0, 0, 0, 0, self.bits
    a = _lv_a0
    c = _lv_a1
    f = _lv_a2
    g = _lv_a3
    b = _lv_a4
  end
  for _lv_i in logicview.range(length) do
    i = _lv_i
    if logicview.truth(logicview.eq(i, 0)) then
      ss = _math.max(0, logicview.idx(logicview.idx(self.bits, 0), 0))
    else
      ss = logicview.idx(logicview.idx(self.ss_es_bits, (i - 1)), 1)
    end
    es = logicview.add(logicview.idx(logicview.idx(self.bits, i), 0), logicview.mul(self.halfbit, 2))
    _table.insert(self.ss_es_bits, { ss, es })
    self:putb(i, i, { 0, { logicview.pymod("%d", logicview.idx(logicview.idx(self.bits, i), 1)) } })
    ::continue_1::
  end
  s = { logicview.pymod("Startbit: %d", logicview.idx(logicview.idx(b, 0), 1)), logicview.pymod("ST: %d", logicview.idx(logicview.idx(b, 0), 1)), "ST", "S", "S" }
  self:putb(0, 0, { 1, s })
  self:putb(0, 0, { 7, s })
  for _lv_i in logicview.range(8) do
    i = _lv_i
    f = (f | (logicview.idx(logicview.idx(b, logicview.add(1, i)), 1) << (7 - i)))
    ::continue_2::
  end
  if logicview.truth(logicview.eq(length, 9)) then
    s = { logicview.pymod("Reply: %02X", f), logicview.pymod("Rply: %02X", f), logicview.pymod("Rep: %02X", f), logicview.pymod("R: %02X", f), "R" }
    self:putb(1, 8, { 7, s })
    s = { logicview.pymod("Reply: %d", f), logicview.pymod("Rply: %d", f), logicview.pymod("Rep: %d", f), logicview.pymod("R: %d", f), "R" }
    self:putb(1, 8, { 6, s })
    return
  end
  for _lv_i in logicview.range(8) do
    i = _lv_i
    c = (c | (logicview.idx(logicview.idx(b, logicview.add(9, i)), 1) << (7 - i)))
    ::continue_3::
  end
  s = { logicview.pymod("Raw data: %02X", f), logicview.pymod("Raw: %02X", f), logicview.pymod("Raw: %02X", f), logicview.pymod("R: %02X", f), "R" }
  self:putb(1, 8, { 7, s })
  s = { logicview.pymod("Raw data: %02X", c), logicview.pymod("Raw: %02X", c), logicview.pymod("Raw: %02X", c), logicview.pymod("R: %02X", c), "R" }
  self:putb(9, 16, { 7, s })
  if logicview.truth(logicview.eq(logicview.idx(logicview.idx(b, 8), 1), 1)) then
    s = { "Command", "Comd", "COM", "CO", "C" }
  else
    s = { "Arc Power Level", "Arc Pwr", "ARC", "AC", "A" }
  end
  self:putb(8, 8, { 1, s })
  if logicview.truth((f >= 254)) then
    s = { "BROADCAST", "Brdcast", "BC", "B", "B" }
    self:putb(1, 7, { 5, s })
  elseif logicview.truth((f >= 160)) then
    if logicview.truth(logicview.eq(f, 193)) then
      self.dev_type = (-1)
    end
    x = logicview.dget(extended_commands, f, { "Unknown", "Unk" })
    s = { logicview.pymod("Extended Command: %02X (%s)", { f, logicview.idx(x, 0) }), logicview.pymod("XC: %02X (%s)", { f, logicview.idx(x, 1) }), logicview.pymod("XC: %02X", f), logicview.pymod("X: %02X", f), "X" }
    self:putb(1, 8, { 5, s })
  elseif logicview.truth((f >= 128)) then
    s = { logicview.pymod("YBit: %d", logicview.idx(logicview.idx(b, 1), 1)), logicview.pymod("YB: %d", logicview.idx(logicview.idx(b, 1), 1)), "YB", "Y", "Y" }
    self:putb(1, 1, { 3, s })
    g = ((f & 127) >> 1)
    s = { logicview.pymod("Group address: %d", g), logicview.pymod("Group: %d", g), logicview.pymod("GP: %d", g), logicview.pymod("G: %d", g), "G" }
    self:putb(2, 7, { 4, s })
  else
    s = { logicview.pymod("YBit: %d", logicview.idx(logicview.idx(b, 1), 1)), logicview.pymod("YB: %d", logicview.idx(logicview.idx(b, 1), 1)), "YB", "Y", "Y" }
    self:putb(1, 1, { 3, s })
    a = (f >> 1)
    s = { logicview.pymod("Short address: %d", a), logicview.pymod("Addr: %d", a), logicview.pymod("Addr: %d", a), logicview.pymod("A: %d", a), "A" }
    self:putb(2, 7, { 4, s })
  end
  if logicview.truth((function()
  local _v
  _v = (f >= 160)
  if not logicview.truth(_v) then return _v end
  _v = (f < 254)
  return _v
end)()) then
    if logicview.truth(logicview.eq(self.dev_type, (-1))) then
      self.dev_type = c
      s = { logicview.pymod("Type: %d", c), logicview.pymod("Typ: %d", c), logicview.pymod("Typ: %d", c), logicview.pymod("T: %d", c), "D" }
    else
      self.dev_type = nil
      s = { logicview.pymod("Data: %d", c), logicview.pymod("Dat: %d", c), logicview.pymod("Dat: %d", c), logicview.pymod("D: %d", c), "D" }
    end
  elseif logicview.truth(logicview.eq(logicview.idx(logicview.idx(b, 8), 1), 1)) then
    un = (c & 240)
    ln = (c & 15)
    if logicview.truth(logicview.eq(un, 16)) then
      x = { logicview.pymod("Recall Scene %d", ln), logicview.pymod("SC %d", ln) }
    elseif logicview.truth(logicview.eq(un, 64)) then
      x = { logicview.pymod("Store DTR as Scene %d", ln), logicview.pymod("SC %d = DTR", ln) }
    elseif logicview.truth(logicview.eq(un, 80)) then
      x = { logicview.pymod("Delete Scene %d", ln), logicview.pymod("DEL SC %d", ln) }
    elseif logicview.truth(logicview.eq(un, 96)) then
      x = { logicview.pymod("Add to Group %d", ln), logicview.pymod("Grp %d Add", ln) }
    elseif logicview.truth(logicview.eq(un, 112)) then
      x = { logicview.pymod("Remove from Group %d", ln), logicview.pymod("Grp %d Del", ln) }
    elseif logicview.truth(logicview.eq(un, 176)) then
      x = { logicview.pymod("Query Scene %d Level", ln), logicview.pymod("Sc %d Level", ln) }
    elseif logicview.truth((c >= 224)) then
      if logicview.truth(logicview.eq(self.dev_type, 8)) then
        x = logicview.dget(dali_device_type8, c, { "Unknown App", "Unk" })
      else
        x = { logicview.pymod("Application Specific Command %d", c), logicview.pymod("App Cmd %d", c) }
      end
    else
      x = logicview.dget(dali_commands, c, { "Unknown", "Unk" })
    end
    s = { logicview.pymod("Command: %d (%s)", { c, logicview.idx(x, 0) }), logicview.pymod("Com: %d (%s)", { c, logicview.idx(x, 1) }), logicview.pymod("Com: %d", c), logicview.pymod("C: %d", c), "C" }
  else
    s = { logicview.pymod("Arc Power Level: %d", c), logicview.pymod("Level: %d", c), logicview.pymod("Lev: %d", c), logicview.pymod("L: %d", c), "L" }
  end
  self:putb(9, 16, { 5, s })
end
function _decoder.reset_decoder_state(self)
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.bits = _lv_a1
    self.ss_es_bits = _lv_a2
  end
  self.state = "IDLE"
end
function _decoder.decode(self)
  local bit, dali
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  bit = 0
  while true do
    do
      local _lv_seq = self:wait()
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      dali = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-high")) then
      dali = (dali ~ 1)
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      if logicview.truth(logicview.eq(self.old_dali, dali)) then
        goto continue_4
      end
      _table.insert(self.edges, self.samplenum)
      self.state = "PHASE0"
      self.old_dali = dali
      goto continue_4
    end
    if logicview.truth((not logicview.eq(self.old_dali, dali))) then
      _table.insert(self.edges, self.samplenum)
    elseif logicview.truth(logicview.eq(self.samplenum, logicview.add(logicview.idx(self.edges, (-1)), logicview.tointeger(logicview.mul(self.halfbit, 1.5))))) then
      _table.insert(self.edges, (self.samplenum - logicview.tointeger(logicview.mul(self.halfbit, 0.5))))
    else
      goto continue_4
    end
    bit = self.old_dali
    if logicview.truth(logicview.eq(self.state, "PHASE0")) then
      self.phase0 = bit
      self.state = "PHASE1"
    elseif logicview.truth(logicview.eq(self.state, "PHASE1")) then
      if logicview.truth((function()
  local _v
  _v = logicview.eq(bit, 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.phase0, 1)
  return _v
end)()) then
        if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.len(self.bits), 17)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.bits), 9)
  return _v
end)()) then
          self:handle_bits(logicview.len(self.bits))
        end
        self:reset_decoder_state()
        goto continue_4
      else
        _table.insert(self.bits, { logicview.idx(self.edges, (-3)), bit })
        self.state = "PHASE0"
      end
    end
    self.old_dali = dali
    ::continue_4::
  end
end

return _decoder
