-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Josef Gajdusek <atx@atx.name>

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
local operator, collections, reduce, end_codes, SamplerateError, calc_checksum, bits_to_uint, Decoder
local _decoder

operator = { itemgetter = function(i) return function(row) return logicview.idx(row, i) end end }
collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
reduce = function(fn, seq, init)
  local acc, start_at = init, 1
  if acc == nil then acc = seq[1]; start_at = 2 end
  for _i = start_at, #seq do acc = fn(acc, seq[_i]) end
  return acc
end
end_codes = { "Unknown", "Charge Complete", "Internal Fault", "Over Temperature", "Over Voltage", "Over Current", "Battery Failure", "Reconfigure", "No Response" }
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
calc_checksum = function(packet)
  return reduce(operator.xor, logicview.slice(packet, nil, (-1), nil))
end
bits_to_uint = function(bits)
  return reduce((function(i, v) return ((i >> 1) | (v << (logicview.len(bits) - 1))) end), bits, 0)
end
_decoder = {
  api_version = 3,
  id = "qi",
  name = "Qi",
  longname = "Qi charger protocol",
  desc = "Protocol used by Qi receiver.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial", "Wireless/RF" },
  channels = { logicview.dict({ id = "qi", name = "Qi", desc = "Demodulated Qi data line" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bits", "Bits" }, { "bytes-errors", "Bit errors" }, { "bytes-start", "Start bits" }, { "bytes-info", "Info bits" }, { "bytes-data", "Data bytes" }, { "packets-data", "Packet data" }, { "packets-checksum-ok", "Packet checksum" }, { "packets-checksum-err", "Packet checksum" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "bytes", "Bytes", { 1, 2, 3, 4 } }, { "packets", "Packets", { 5, 6, 7 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self:reset_variables()
end
function _decoder.reset_variables(self)
  self.counter = 0
  self.prev = nil
  self.state = "IDLE"
  self.lastbit = 0
  self.bytestart = 0
  self.deq = collections.deque()
  self.bits = {  }
  self.bitsi = { 0 }
  self.bytesi = {  }
  self.packet = {  }
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.bit_width = ((_tonumber(self.samplerate) or 0) / 2000.0)
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self:reset_variables()
end
function _decoder.packet_len(self, byte)
  if logicview.truth(((0 <= byte) and (byte <= 31))) then
    return logicview.tointeger(logicview.add(1, ((byte - 0) / 32)))
  end
  if logicview.truth(((32 <= byte) and (byte <= 127))) then
    return logicview.tointeger(logicview.add(2, ((byte - 32) / 16)))
  end
  if logicview.truth(((128 <= byte) and (byte <= 223))) then
    return logicview.tointeger(logicview.add(8, ((byte - 128) / 8)))
  end
  if logicview.truth(((224 <= byte) and (byte <= 255))) then
    return logicview.tointeger(logicview.add(20, ((byte - 224) / 4)))
  end
end
function _decoder.in_tolerance(self, l)
  return ((logicview.mul(0.75, self.bit_width) < l) and (l < logicview.mul(1.25, self.bit_width)))
end
function _decoder.putp(self, data)
  self:put(logicview.idx(self.bytesi, 0), logicview.idx(self.bytesi, (-1)), self.out_ann, { 5, data })
end
function _decoder.process_packet(self)
  local reason, val, powerclass, maxpower, prop, count, winsize, winoff, version, mancode, devid, edevid
  if logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 1)) then
    self:putp({ logicview.pymod("Signal Strength: %d", logicview.idx(self.packet, 1)), logicview.pymod("SS: %d", logicview.idx(self.packet, 1)), "SS" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 2)) then
    reason = (function() if logicview.truth((logicview.idx(self.packet, 1) < logicview.len(end_codes))) then return logicview.idx(end_codes, logicview.idx(self.packet, 1)) else return "Reserved" end end)()
    self:putp({ logicview.pymod("End Power Transfer: %s", reason), logicview.pymod("EPT: %s", reason), "EPT" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 3)) then
    val = (function() if logicview.truth((logicview.idx(self.packet, 1) < 128)) then return logicview.idx(self.packet, 1) else return ((logicview.idx(self.packet, 1) & 127) - 128) end end)()
    self:putp({ logicview.pymod("Control Error: %d", val), logicview.pymod("CE: %d", val), "CE" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 4)) then
    self:putp({ logicview.pymod("Received Power: %d", logicview.idx(self.packet, 1)), logicview.pymod("RP: %d", logicview.idx(self.packet, 1)), "RP" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 5)) then
    self:putp({ logicview.pymod("Charge Status: %d", logicview.idx(self.packet, 1)), logicview.pymod("CS: %d", logicview.idx(self.packet, 1)), "CS" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 6)) then
    self:putp({ logicview.pymod("Power Control Hold-off: %dms", logicview.idx(self.packet, 1)), logicview.pymod("PCH: %d", logicview.idx(self.packet, 1)), "PCH" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 81)) then
    powerclass = ((logicview.idx(self.packet, 1) & 192) >> 7)
    maxpower = (logicview.idx(self.packet, 1) & 63)
    prop = ((logicview.idx(self.packet, 3) & 128) >> 7)
    count = (logicview.idx(self.packet, 3) & 7)
    winsize = ((logicview.idx(self.packet, 4) & 248) >> 3)
    winoff = (logicview.idx(self.packet, 4) & 7)
    self:putp({ logicview.pymod("Configuration: Power Class = %d, Maximum Power = %d, Prop = %d,Count = %d, Window Size = %d, Window Offset = %d", { powerclass, maxpower, prop, count, winsize, winoff }), logicview.pymod("C: PC = %d MP = %d P = %d C = %d WS = %d WO = %d", { powerclass, maxpower, prop, count, winsize, winoff }), "Configuration", "C" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 113)) then
    version = logicview.pymod("%d.%d", { ((logicview.idx(self.packet, 1) & 240) >> 4), (logicview.idx(self.packet, 1) & 15) })
    mancode = logicview.pymod("%02x%02x", { logicview.idx(self.packet, 2), logicview.idx(self.packet, 3) })
    devid = logicview.pymod("%02x%02x%02x%02x", { (logicview.idx(self.packet, 4) & (~128)), logicview.idx(self.packet, 5), logicview.idx(self.packet, 6), logicview.idx(self.packet, 7) })
    self:putp({ logicview.pymod("Identification: Version = %s, Manufacturer = %s, Device = %s", { version, mancode, devid }), logicview.pymod("ID: %s %s %s", { version, mancode, devid }), "ID" })
  elseif logicview.truth(logicview.eq(logicview.idx(self.packet, 0), 129)) then
    edevid = logicview.pymod("%02x%02x%02x%02x%02x%02x%02x%02x", logicview.slice(self.packet, 1, (-1), nil))
    self:putp({ logicview.pymod("Extended Identification: %s", edevid), logicview.pymod("EI: %s", edevid), "EI" })
  elseif logicview.truth(logicview.contains({ 24, 25, 40, 41, 56, 72, 88, 104, 120, 133, 164, 196, 226 }, logicview.idx(self.packet, 0))) then
    self:putp({ "Proprietary", "P" })
  else
    self:putp({ "Unknown", "?" })
  end
  self:put(logicview.idx(self.bytesi, (-1)), self.samplenum, self.out_ann, (function() if logicview.truth(logicview.eq(calc_checksum(self.packet), logicview.idx(self.packet, (-1)))) then return { 6, { "Checksum OK", "OK" } } else return { 6, { "Checksum error", "ERR" } } end end)())
end
function _decoder.process_byte(self)
  local databits, data, parity
  self:put(self.bytestart, logicview.idx(self.bitsi, 0), self.out_ann, (function() if logicview.truth(logicview.eq(logicview.idx(self.bits, 0), 0)) then return { 2, { "Start bit", "Start", "S" } } else return { 1, { "Start error", "Start err", "SE" } } end end)())
  databits = logicview.slice(self.bits, 1, 9, nil)
  data = bits_to_uint(databits)
  parity = reduce((function(i, v) return logicview.pymod(logicview.add(i, v), 2) end), databits, 1)
  self:put(logicview.idx(self.bitsi, 0), logicview.idx(self.bitsi, 8), self.out_ann, { 4, { logicview.pymod("%02x", data) } })
  self:put(logicview.idx(self.bitsi, 8), logicview.idx(self.bitsi, 9), self.out_ann, (function() if logicview.truth(logicview.eq(logicview.idx(self.bits, 9), parity)) then return { 3, { "Parity bit", "Parity", "P" } } else return { 1, { "Parity error", "Parity err", "PE" } } end end)())
  self:put(logicview.idx(self.bitsi, 9), logicview.idx(self.bitsi, 10), self.out_ann, (function() if logicview.truth(logicview.eq(logicview.idx(self.bits, 10), 1)) then return { 3, { "Stop bit", "Stop", "S" } } else return { 1, { "Stop error", "Stop err", "SE" } } end end)())
  _table.insert(self.bytesi, self.bytestart)
  _table.insert(self.packet, data)
  if logicview.truth(logicview.eq(logicview.add(self:packet_len(logicview.idx(self.packet, 0)), 2), logicview.len(self.packet))) then
    self:process_packet()
    logicview.list_clear(self.bytesi)
    logicview.list_clear(self.packet)
  end
end
function _decoder.add_bit(self, bit)
  _table.insert(self.bits, bit)
  _table.insert(self.bitsi, self.samplenum)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "IDLE")
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(self.bits) >= 5)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.slice(self.bits, (-5), nil, nil), { 1, 1, 1, 1, 0 })
  return _v
end)()) then
    self.state = "DATA"
    self.bytestart = logicview.idx(self.bitsi, (-2))
    self.bits = { 0 }
    self.bitsi = { self.samplenum }
    logicview.list_clear(self.packet)
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(self.state, "DATA")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.len(self.bits), 11)
  return _v
end)()) then
    self:process_byte()
    self.bytestart = self.samplenum
    logicview.list_clear(self.bits)
    logicview.list_clear(self.bitsi)
  end
  if logicview.truth((not logicview.eq(self.state, "IDLE"))) then
    self:put(self.lastbit, self.samplenum, self.out_ann, { 0, { logicview.pymod("%d", bit) } })
  end
  self.lastbit = self.samplenum
end
function _decoder.handle_transition(self, l, htl)
  _table.insert(self.deq, l)
  if logicview.truth((function()
  local _v
  _v = (logicview.len(self.deq) >= 2)
  if not logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = self:in_tolerance(logicview.add(logicview.idx(self.deq, (-1)), logicview.idx(self.deq, (-2))))
  if logicview.truth(_v) then return _v end
  _v = (function()
  local _v
  _v = htl
  if not logicview.truth(_v) then return _v end
  _v = self:in_tolerance(logicview.mul(l, 2))
  if not logicview.truth(_v) then return _v end
  _v = (logicview.idx(self.deq, (-2)) > logicview.mul(1.25, self.bit_width))
  return _v
end)()
  return _v
end)()
  return _v
end)()) then
    self:add_bit(1)
    logicview.list_clear(self.deq)
  elseif logicview.truth(self:in_tolerance(l)) then
    self:add_bit(0)
    logicview.list_clear(self.deq)
  elseif logicview.truth((l > logicview.mul(1.25, self.bit_width))) then
    self.state = "IDLE"
    logicview.list_clear(self.bytesi)
    logicview.list_clear(self.packet)
    logicview.list_clear(self.bits)
    logicview.list_clear(self.bitsi)
  end
end
function _decoder.decode(self)
  local qi, prev
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  do
    local _lv_seq = self:wait()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    qi = logicview.idx(_lv_seq, 0)
  end
  self:handle_transition(self.samplenum, logicview.eq(qi, 0))
  while true do
    prev = self.samplenum
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "e" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      qi = logicview.idx(_lv_seq, 0)
    end
    self:handle_transition((self.samplenum - prev), logicview.eq(qi, 0))
    ::continue_1::
  end
end

return _decoder
