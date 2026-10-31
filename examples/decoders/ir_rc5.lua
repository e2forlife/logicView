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
local SamplerateError, Decoder, system, digits, command
local _decoder

system = logicview.dict({ [0] = { "TV receiver 1", "TV1" }, [1] = { "TV receiver 2", "TV2" }, [2] = { "Teletext", "Txt" }, [3] = { "Extension to TV1 and TV2", "Ext TV1/TV2" }, [4] = { "LaserVision player", "LV" }, [5] = { "Video cassette recorder 1", "VCR1" }, [6] = { "Video cassette recorder 2", "VCR2" }, [7] = { "Experimental", "Exp" }, [8] = { "Satellite TV receiver 1", "Sat1" }, [9] = { "Extension to VCR1 and VCR2", "Ext VCR1/VCR2" }, [10] = { "Satellite TV receiver 2", "Sat2" }, [12] = { "Compact disc video player", "CD-Video" }, [13] = { "Camcorder", "Cam" }, [14] = { "Photo on compact disc player", "CD-Photo" }, [16] = { "Audio preamplifier 1", "Preamp1" }, [17] = { "Radio tuner", "Tuner" }, [18] = { "Analog cassette recoder 1", "Rec1" }, [19] = { "Audio preamplifier 2", "Preamp2" }, [20] = { "Compact disc player", "CD" }, [21] = { "Audio stack or record player", "Combi" }, [22] = { "Audio satellite", "Sat" }, [23] = { "Analog cassette recoder 2", "Rec2" }, [26] = { "Compact disc recorder", "CD-R" }, [29] = { "Lighting 1", "Light1" }, [30] = { "Lighting 2", "Light2" }, [31] = { "Telephone", "Phone" } })
digits = logicview.dict({ [0] = { "0", "0" }, [1] = { "1", "1" }, [2] = { "2", "2" }, [3] = { "3", "3" }, [4] = { "4", "4" }, [5] = { "5", "5" }, [6] = { "6", "6" }, [7] = { "7", "7" }, [8] = { "8", "8" }, [9] = { "9", "9" } })
command = logicview.dict({ TV = logicview.dict(logicview.add(logicview.copy((function() local _t = {}; for _k, _v in _pairs(digits) do _t[#_t + 1] = {_k, _v} end; return _t end)()), logicview.copy((function() local _t = {}; for _k, _v in _pairs(logicview.dict({ [10] = { "-/--", "-/--" }, [11] = { "Channel/program", "Ch/P" }, [12] = { "Standby", "StBy" }, [13] = { "Mute", "M" }, [14] = { "Personal preferences", "PP" }, [15] = { "Display", "Disp" }, [16] = { "Volume up", "Vol+" }, [17] = { "Volume down", "Vol-" }, [18] = { "Brightness up", "Br+" }, [19] = { "Brightness down", "Br-" }, [20] = { "Saturation up", "S+" }, [21] = { "Saturation down", "S-" }, [32] = { "Program up", "P+" }, [33] = { "Program down", "P-" } })) do _t[#_t + 1] = {_k, _v} end; return _t end)()))), VCR = logicview.dict(logicview.add(logicview.copy((function() local _t = {}; for _k, _v in _pairs(digits) do _t[#_t + 1] = {_k, _v} end; return _t end)()), logicview.copy((function() local _t = {}; for _k, _v in _pairs(logicview.dict({ [10] = { "-/--", "-/--" }, [12] = { "Standby", "StBy" }, [32] = { "Program up", "P+" }, [33] = { "Program down", "P-" }, [50] = { "Fast rewind", "FRW" }, [52] = { "Fast forward", "FFW" }, [53] = { "Play", "Pl" }, [54] = { "Stop", "St" }, [55] = { "Recording", "Rec" } })) do _t[#_t + 1] = {_k, _v} end; return _t end)()))) })

SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "ir_rc5",
  name = "IR RC-5",
  longname = "IR RC-5",
  desc = "RC-5 infrared remote control protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IR" },
  channels = { logicview.dict({ id = "ir", name = "IR", desc = "IR data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-low", values = { "active-low", "active-high" } }), logicview.dict({ id = "protocol", desc = "Protocol type", default = "standard", values = { "standard", "extended" } }) },
  annotations = { { "bit", "Bit" }, { "startbit1", "Startbit 1" }, { "startbit2", "Startbit 2" }, { "togglebit-0", "Toggle bit 0" }, { "togglebit-1", "Toggle bit 1" }, { "address", "Address" }, { "command", "Command" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 2, 3, 4, 5, 6 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  do
    local _lv_a0, _lv_a1, _lv_a2 = {  }, {  }, {  }
    self.edges = _lv_a0
    self.bits = _lv_a1
    self.ss_es_bits = _lv_a2
  end
  self.state = "IDLE"
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.next_edge = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return "l" else return "h" end end)()
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.halfbit = logicview.tointeger((logicview.mul(self.samplerate, 0.00178) / 2.0))
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
function _decoder.handle_bits(self)
  local a, c, b, i, ss, es, s, ann_idx, x, inverted_bit6, cmd_type
  do
    local _lv_a0, _lv_a1, _lv_a2 = 0, 0, self.bits
    a = _lv_a0
    c = _lv_a1
    b = _lv_a2
  end
  for _lv_i in logicview.range(14) do
    i = _lv_i
    if logicview.truth(logicview.eq(i, 0)) then
      ss = _math.max(0, (logicview.idx(logicview.idx(self.bits, 0), 0) - self.halfbit))
    else
      ss = logicview.idx(logicview.idx(self.ss_es_bits, (i - 1)), 1)
    end
    es = logicview.add(logicview.idx(logicview.idx(self.bits, i), 0), self.halfbit)
    _table.insert(self.ss_es_bits, { ss, es })
    self:putb(i, i, { 0, { logicview.pymod("%d", logicview.idx(logicview.idx(self.bits, i), 1)) } })
    ::continue_1::
  end
  s = { logicview.pymod("Startbit1: %d", logicview.idx(logicview.idx(b, 0), 1)), logicview.pymod("SB1: %d", logicview.idx(logicview.idx(b, 0), 1)), "SB1", "S1", "S" }
  self:putb(0, 0, { 1, s })
  ann_idx = 2
  s = { logicview.pymod("Startbit2: %d", logicview.idx(logicview.idx(b, 1), 1)), logicview.pymod("SB2: %d", logicview.idx(logicview.idx(b, 1), 1)), "SB2", "S2", "S" }
  if logicview.truth(logicview.eq(logicview.idx(self.options, "protocol"), "extended")) then
    s = { logicview.pymod("CMD[6]#: %d", logicview.idx(logicview.idx(b, 1), 1)), logicview.pymod("C6#: %d", logicview.idx(logicview.idx(b, 1), 1)), "C6#", "C#", "C" }
    ann_idx = 6
  end
  self:putb(1, 1, { ann_idx, s })
  s = { logicview.pymod("Togglebit: %d", logicview.idx(logicview.idx(b, 2), 1)), logicview.pymod("Toggle: %d", logicview.idx(logicview.idx(b, 2), 1)), logicview.pymod("TB: %d", logicview.idx(logicview.idx(b, 2), 1)), "TB", "T" }
  self:putb(2, 2, { (function() if logicview.truth(logicview.eq(logicview.idx(logicview.idx(b, 2), 1), 0)) then return 3 else return 4 end end)(), s })
  for _lv_i in logicview.range(5) do
    i = _lv_i
    a = (a | (logicview.idx(logicview.idx(b, logicview.add(3, i)), 1) << (4 - i)))
    ::continue_2::
  end
  x = logicview.dget(system, a, { "Unknown", "Unk" })
  s = { logicview.pymod("Address: %d (%s)", { a, logicview.idx(x, 0) }), logicview.pymod("Addr: %d (%s)", { a, logicview.idx(x, 1) }), logicview.pymod("Addr: %d", a), logicview.pymod("A: %d", a), "A" }
  self:putb(3, 7, { 5, s })
  for _lv_i in logicview.range(6) do
    i = _lv_i
    c = (c | (logicview.idx(logicview.idx(b, logicview.add(8, i)), 1) << (5 - i)))
    ::continue_3::
  end
  if logicview.truth(logicview.eq(logicview.idx(self.options, "protocol"), "extended")) then
    inverted_bit6 = (function() if logicview.truth(logicview.eq(logicview.idx(logicview.idx(b, 1), 1), 0)) then return 1 else return 0 end end)()
    c = (c | (inverted_bit6 << 6))
  end
  cmd_type = (function() if logicview.truth(logicview.contains({ "VCR1", "VCR2" }, logicview.idx(x, 1))) then return "VCR" else return "TV" end end)()
  x = logicview.dget(logicview.idx(command, cmd_type), c, { "Unknown", "Unk" })
  s = { logicview.pymod("Command: %d (%s)", { c, logicview.idx(x, 0) }), logicview.pymod("Cmd: %d (%s)", { c, logicview.idx(x, 1) }), logicview.pymod("Cmd: %d", c), logicview.pymod("C: %d", c), "C" }
  self:putb(8, 13, { 6, s })
end
function _decoder.edge_type(self)
  local distance, s, l, margin
  distance = (self.samplenum - logicview.idx(self.edges, (-1)))
  do
    local _lv_a0, _lv_a1, _lv_a2 = self.halfbit, logicview.mul(self.halfbit, 2), logicview.tointeger((self.halfbit / 2))
    s = _lv_a0
    l = _lv_a1
    margin = _lv_a2
  end
  if logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range((l - margin), logicview.add(logicview.add(l, margin), 1)) do _t[#_t + 1] = _v end; return _t end)(), distance)) then
    return "l"
  elseif logicview.truth(logicview.contains((function() local _t = {}; for _v in logicview.range((s - margin), logicview.add(logicview.add(s, margin), 1)) do _t[#_t + 1] = _v end; return _t end)(), distance)) then
    return "s"
  else
    return "e"
  end
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
  local bit, edge
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = self.next_edge }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      self.ir = logicview.idx(_lv_seq, 0)
    end
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      bit = 1
      _table.insert(self.edges, self.samplenum)
      _table.insert(self.bits, { self.samplenum, bit })
      self.state = "MID1"
      self.next_edge = (function() if logicview.truth(self.ir) then return "l" else return "h" end end)()
      goto continue_4
    end
    edge = self:edge_type()
    if logicview.truth(logicview.eq(edge, "e")) then
      self:reset_decoder_state()
      goto continue_4
    end
    if logicview.truth(logicview.eq(self.state, "MID1")) then
      self.state = (function() if logicview.truth(logicview.eq(edge, "s")) then return "START1" else return "MID0" end end)()
      bit = (function() if logicview.truth(logicview.eq(edge, "s")) then return nil else return 0 end end)()
    elseif logicview.truth(logicview.eq(self.state, "MID0")) then
      self.state = (function() if logicview.truth(logicview.eq(edge, "s")) then return "START0" else return "MID1" end end)()
      bit = (function() if logicview.truth(logicview.eq(edge, "s")) then return nil else return 1 end end)()
    elseif logicview.truth(logicview.eq(self.state, "START1")) then
      if logicview.truth(logicview.eq(edge, "s")) then
        self.state = "MID1"
      end
      bit = (function() if logicview.truth(logicview.eq(edge, "s")) then return 1 else return nil end end)()
    elseif logicview.truth(logicview.eq(self.state, "START0")) then
      if logicview.truth(logicview.eq(edge, "s")) then
        self.state = "MID0"
      end
      bit = (function() if logicview.truth(logicview.eq(edge, "s")) then return 0 else return nil end end)()
    end
    _table.insert(self.edges, self.samplenum)
    if logicview.truth((bit ~= nil)) then
      _table.insert(self.bits, { self.samplenum, bit })
    end
    if logicview.truth(logicview.eq(logicview.len(self.bits), 14)) then
      self:handle_bits()
      self:reset_decoder_state()
    end
    self.next_edge = (function() if logicview.truth(self.ir) then return "l" else return "h" end end)()
    ::continue_4::
  end
end

return _decoder
