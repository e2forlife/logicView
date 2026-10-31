-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2018 Steve R <steversig@virginmedia.com>

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
local Decoder, sensor, sensor_checksum, dir_table
local _decoder

sensor = logicview.dict({ ["1984"] = { { "WGR800" }, "Wind" }, ["1994"] = { { "WGR800" }, "Wind" }, ["1A2D"] = { { "THGR228N" }, "Temp_Hum1" }, ["1A3D"] = { { "THGR918" }, "" }, ["1D20"] = { { "THGN123N", "THGR122NX", "THGN123N", "THGR228N" }, "Temp_Hum" }, ["1D30"] = { { "THGN500", "THGN132N" }, "" }, ["2914"] = { { "PCR800" }, "Rain" }, ["2A19"] = { { "PCR800" }, "Rain1" }, ["2A1D"] = { { "RGR918" }, "Rain" }, ["2D10"] = { { "RGR968", "PGR968 " }, "Rain1" }, ["3A0D"] = { { "STR918", "WGR918" }, "Wind" }, ["5A5D"] = { { "BTHR918" }, "" }, ["5A6D"] = { { "BTHR918N" }, "Temp_Hum_Baro" }, ["5D53"] = { { "BTHGN129" }, "Baro" }, ["5D60"] = { { "BTHR968" }, "Temp_Hum_Baro" }, C844 = { { "THWR800" }, "Temp" }, CC13 = { { "RTGR328N" }, "Temp_Hum" }, CC23 = { { "THGR328N" }, "Temp_Hum" }, CD39 = { { "RTHR328N" }, "Temp" }, D874 = { { "UVN800" }, "UV1" }, EA4C = { { "THWR288A" }, "Temp" }, EC40 = { { "THN132N", "THR238NF" }, "Temp" }, EC70 = { { "UVR128" }, "UV" }, F824 = { { "THGN800", "THGN801", "THGR810" }, "Temp_Hum" }, F8B4 = { { "THGR810" }, "Temp_Hum" } })
sensor_checksum = logicview.dict({ ["1D20"] = { "v3", "THGR228N" }, ["5D60"] = { "v3", "BTHR918N" }, EC40 = { "v3", "THN132N" } })
dir_table = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW", "N" }

_decoder = {
  api_version = 3,
  id = "ook_oregon",
  name = "Oregon",
  longname = "Oregon Scientific",
  desc = "Oregon Scientific weather sensor protocol.",
  license = "gplv2+",
  inputs = { "ook" },
  outputs = {  },
  tags = { "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "unknown", desc = "Unknown type is", default = "Unknown", values = { "Unknown", "Temp", "Temp_Hum", "Temp_Hum1", "Temp_Hum_Baro", "Temp_Hum_Baro1", "UV", "UV1", "Wind", "Rain", "Rain1" } }) },
  annotations = { { "bit", "Bit" }, { "field", "Field" }, { "l2", "Level 2" }, { "pre", "Preamble" }, { "syn", "Sync" }, { "id", "SensorID" }, { "ch", "Channel" }, { "roll", "Rolling code" }, { "f1", "Flags1" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "fields", "Fields", { 1, 3, 4 } }, { "l2", "Level 2", { 2 } } },
  binary = { { "data-hex", "Hex data" } }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.decoded = {  }
  self.skip = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
  self.unknown = logicview.idx(self.options, "unknown")
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.dump_oregon_hex(self, start, finish)
  local nib, hexstring, x, s
  nib = self.decoded_nibbles
  hexstring = ""
  for _lv_item in logicview.iter(nib) do
    x = _lv_item
    hexstring = logicview.add(hexstring, (function() if logicview.truth((not logicview.eq(logicview.idx(x, 3), ""))) then return _tostring(logicview.idx(x, 3)) else return " " end end)())
    ::continue_1::
  end
  s = logicview.add(logicview.add(logicview.add(logicview.add("Oregon ", self.ver), " \""), _string.upper(hexstring)), "\"\n")
  self:put(start, finish, self.out_binary, { 0, logicview.bytes((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = _string.byte(c)
  end
  return _lv_out
end)()) })
end
function _decoder.oregon_put_pre_and_sync(self, len_pream, len_sync, ver)
  local ook
  ook = self.decoded
  self.decode_pos = len_pream
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, self.decode_pos), 0)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self:putx({ 1, { logicview.add(logicview.add("Oregon ", ver), " Preamble"), logicview.add(ver, " Preamble"), logicview.add(ver, " Pre"), ver } })
  self.decode_pos = logicview.add(self.decode_pos, len_sync)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(ook, len_pream), 0), logicview.idx(logicview.idx(ook, self.decode_pos), 0)
    self.ss = _lv_a0
    self.es = _lv_a1
  end
  self:putx({ 1, { "Sync", "Syn", "S" } })
  self.decoded = logicview.slice(self.decoded, self.decode_pos, nil, nil)
  self.ookstring = logicview.slice(self.ookstring, self.decode_pos, nil, nil)
  self.ver = ver
end
function _decoder.oregon(self)
  local ook, i, preamble, data, error_message
  self.ookstring = ""
  self.decode_pos = 0
  ook = self.decoded
  for _lv_i in logicview.range(logicview.len(ook)) do
    i = _lv_i
    self.ookstring = logicview.add(self.ookstring, logicview.idx(logicview.idx(ook, i), 2))
    ::continue_2::
  end
  if logicview.truth(logicview.contains(logicview.slice(self.ookstring, nil, 40, nil), "10011001")) then
    do
      local _lv_seq = logicview.split(self.ookstring, "10011001", 1)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      preamble = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = (logicview.len(data) > 0)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(preamble) > 16)
  return _v
end)()) then
      self:oregon_put_pre_and_sync(logicview.len(preamble), 8, "v2.1")
      self:oregon_v2()
    end
  elseif logicview.truth(logicview.contains(logicview.slice(self.ookstring, nil, 17, nil), "E1100")) then
    do
      local _lv_seq = logicview.split(self.ookstring, "E1100", 1)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      preamble = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = (logicview.len(data) > 0)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(preamble) <= 12)
  return _v
end)()) then
      self:oregon_put_pre_and_sync(logicview.len(preamble), 5, "v1")
      self:oregon_v1()
    end
  elseif logicview.truth(logicview.contains(logicview.slice(self.ookstring, nil, 28, nil), "0101")) then
    do
      local _lv_seq = logicview.split(self.ookstring, "0101", 1)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      preamble = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = (logicview.len(data) > 0)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(preamble) > 12)
  return _v
end)()) then
      self:oregon_put_pre_and_sync(logicview.len(preamble), 4, "v3")
      self:oregon_v3()
    end
  elseif logicview.truth((logicview.len(self.ookstring) > 16)) then
    error_message = "Not Oregon or wrong preamble"
    do
      local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, (logicview.len(ook) - 1)), 1)
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    self:putx({ 1, { error_message } })
  end
end
function _decoder.oregon_v1(self)
  local ook
  ook = self.decoded
  self.decode_pos = 0
  self.decoded_nibbles = {  }
  if logicview.truth((logicview.len(self.decoded) >= 32)) then
    self:oregon_put_nib("RollingCode", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 3)), 1), 4)
    self:oregon_put_nib("Ch", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 3)), 1), 4)
    self:oregon_put_nib("Temp", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 15)), 1), 16)
    self:oregon_put_nib("Checksum", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 7)), 1), 8)
    self:dump_oregon_hex(logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, (logicview.len(ook) - 1)), 1))
    self:oregon_temp(2)
    self:oregon_channel(1)
    self:oregon_battery(2)
    self:oregon_checksum_v1()
  end
end
function _decoder.oregon_v2(self)
  local i
  self.decode_pos = 0
  self.ookstring = logicview.slice(self.ookstring, 1, nil, 2)
  for _lv_i in logicview.range(logicview.len(self.decoded)) do
    i = _lv_i
    if logicview.truth(logicview.eq(logicview.pymod(i, 2), 1)) then
      logicview.setidx(logicview.idx(self.decoded, i), 0, logicview.idx(logicview.idx(self.decoded, (i - 1)), 0))
    end
    ::continue_3::
  end
  self.decoded = logicview.slice(self.decoded, 1, nil, 2)
  self:oregon_v3()
end
function _decoder.oregon_nibbles(self, ookstring)
  local num_nibbles, nibbles, i, nibble
  num_nibbles = logicview.tointeger((logicview.len(ookstring) / 4))
  nibbles = {  }
  for _lv_i in logicview.range(num_nibbles) do
    i = _lv_i
    nibble = logicview.slice(ookstring, logicview.mul(4, i), logicview.add(logicview.mul(4, i), 4), nil)
    nibble = logicview.slice(nibble, nil, nil, (-1))
    _table.insert(nibbles, nibble)
    ::continue_4::
  end
  return nibbles
end
function _decoder.oregon_put_nib(self, label, start, finish, numbits)
  local param, result, i, ss, es
  param = logicview.slice(self.ookstring, self.decode_pos, logicview.add(self.decode_pos, numbits), nil)
  param = self:oregon_nibbles(param)
  if logicview.truth(logicview.contains(logicview.join("", param), "E")) then
    result = ""
  else
    result = logicview.slice(logicview.hex(logicview.tointeger(logicview.join("", param), 2)), 2, nil, nil)
    if logicview.truth((logicview.len(result) < (numbits / 4))) then
      result = logicview.add(logicview.mul("0", (logicview.tointeger((numbits / 4)) - logicview.len(result))), result)
    end
  end
  if logicview.truth((not logicview.eq(label, ""))) then
    label = logicview.add(label, ": ")
  end
  self:put(start, finish, self.out_ann, { 1, { logicview.add(label, result), result } })
  if logicview.truth(logicview.eq(label, "")) then
    label = logicview.tointeger((self.decode_pos / 4))
  end
  for _lv_i in logicview.range(logicview.len(param)) do
    i = _lv_i
    ss = logicview.idx(logicview.idx(self.decoded, logicview.add(self.decode_pos, logicview.mul(4, i))), 0)
    es = logicview.idx(logicview.idx(self.decoded, logicview.add(logicview.add(self.decode_pos, logicview.mul(4, i)), 3)), 1)
    result = (function() if logicview.truth(logicview.contains(logicview.idx(param, i), "E")) then return "" else return logicview.slice(logicview.hex(logicview.tointeger(logicview.idx(param, i), 2)), 2, nil, nil) end end)()
    _table.insert(self.decoded_nibbles, { ss, es, label, result })
    ::continue_5::
  end
  self.decode_pos = logicview.add(self.decode_pos, numbits)
end
function _decoder.oregon_v3(self)
  local ook, rem_nibbles, i, error_message
  self.decode_pos = 0
  self.decoded_nibbles = {  }
  ook = self.decoded
  if logicview.truth((logicview.len(self.decoded) >= 32)) then
    self:oregon_put_nib("SensorID", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 16)), 0), 16)
    self:oregon_put_nib("Ch", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 3)), 1), 4)
    self:oregon_put_nib("RollingCode", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 7)), 1), 8)
    self:oregon_put_nib("Flags1", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 3)), 1), 4)
    rem_nibbles = logicview.floordiv(logicview.len(logicview.slice(self.ookstring, self.decode_pos, nil, nil)), 4)
    for _lv_i in logicview.range(rem_nibbles) do
      i = _lv_i
      self:oregon_put_nib("", logicview.idx(logicview.idx(ook, self.decode_pos), 0), logicview.idx(logicview.idx(ook, logicview.add(self.decode_pos, 3)), 1), 4)
      ::continue_6::
    end
    self:dump_oregon_hex(logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, (logicview.len(ook) - 1)), 1))
    self:oregon_level2()
  else
    error_message = "Too short to decode"
    self:put(logicview.idx(logicview.idx(ook, 0), 0), logicview.idx(logicview.idx(ook, (-1)), 1), self.out_ann, { 1, { error_message } })
  end
end
function _decoder.oregon_put_l2_param(self, offset, digits, dec_point, pre_label, label)
  local nib, result, out_string, i, es
  nib = self.decoded_nibbles
  result = 0
  out_string = logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(nib, offset, logicview.add(offset, digits), nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = _tostring(logicview.idx(x, 3))
  end
  return _lv_out
end)())
  if logicview.truth(logicview.eq(logicview.len(out_string), digits)) then
    for _lv_i in logicview.range(dec_point, 0, (-1)) do
      i = _lv_i
      result = logicview.add(result, (logicview.tointeger(logicview.idx(logicview.idx(nib, (logicview.add(offset, dec_point) - i)), 3), 16) / (10 ^ i)))
      ::continue_7::
    end
    for _lv_i in logicview.range(dec_point, digits) do
      i = _lv_i
      result = logicview.add(result, logicview.mul(logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.add(offset, i)), 3), 16), (10 ^ (i - dec_point))))
      ::continue_8::
    end
    result = logicview.pymod("%g", result)
  else
    result = ""
  end
  es = logicview.idx(logicview.idx(nib, (logicview.add(offset, digits) - 1)), 1)
  if logicview.truth(logicview.eq(label, "℃")) then
    es = logicview.idx(logicview.idx(nib, logicview.add(offset, digits)), 1)
  end
  self:put(logicview.idx(logicview.idx(nib, offset), 0), es, self.out_ann, { 2, { logicview.add(logicview.add(pre_label, result), label), result } })
end
function _decoder.oregon_temp(self, offset)
  local nib, temp_sign
  nib = self.decoded_nibbles
  if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(nib, logicview.add(offset, 3)), 3), ""))) then
    temp_sign = _tostring(logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.add(offset, 3)), 3), 16))
    temp_sign = (function() if logicview.truth((not logicview.eq(temp_sign, "0"))) then return "-" else return "+" end end)()
  else
    temp_sign = "?"
  end
  self:oregon_put_l2_param(offset, 3, 1, temp_sign, "℃")
end
function _decoder.oregon_baro(self, offset)
  local nib, baro
  nib = self.decoded_nibbles
  baro = ""
  if logicview.truth((not logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(nib, logicview.add(offset, 2)), 3), "")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(nib, logicview.add(offset, 1)), 3), "")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(nib, offset), 3), "")
  return _v
end)()))) then
    baro = _tostring(logicview.add(logicview.tointeger(logicview.add(logicview.idx(logicview.idx(nib, logicview.add(offset, 1)), 3), logicview.idx(logicview.idx(nib, offset), 3)), 16), 856))
  end
  self:put(logicview.idx(logicview.idx(nib, offset), 0), logicview.idx(logicview.idx(nib, logicview.add(offset, 3)), 1), self.out_ann, { 2, { logicview.add(baro, " mb"), baro } })
end
function _decoder.oregon_wind_dir(self, offset)
  local nib, w_dir, w_compass
  nib = self.decoded_nibbles
  if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(nib, offset), 3), ""))) then
    w_dir = logicview.tointeger(logicview.mul(logicview.tointeger(logicview.idx(logicview.idx(nib, offset), 3), 16), 22.5))
    w_compass = logicview.idx(dir_table, math.floor((logicview.add(w_dir, 11.25) / 22.5)))
    self:put(logicview.idx(logicview.idx(nib, offset), 0), logicview.idx(logicview.idx(nib, offset), 1), self.out_ann, { 2, { logicview.add(logicview.add(logicview.add(w_compass, " ("), _tostring(w_dir)), "°)"), w_compass } })
  end
end
function _decoder.oregon_channel(self, offset)
  local nib, channel, ch, bit_pos
  nib = self.decoded_nibbles
  channel = ""
  if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(nib, offset), 3), ""))) then
    ch = logicview.tointeger(logicview.idx(logicview.idx(nib, offset), 3), 16)
    if logicview.truth((not logicview.eq(self.ver, "v3"))) then
      if logicview.truth((not logicview.eq(ch, 0))) then
        bit_pos = 0
        while logicview.truth(logicview.eq((ch & 1), 0)) do
          bit_pos = logicview.add(bit_pos, 1)
          ch = (ch >> 1)
          ::continue_9::
        end
        if logicview.truth(logicview.eq(self.ver, "v2.1")) then
          bit_pos = logicview.add(bit_pos, 1)
        end
        channel = _tostring(bit_pos)
      end
    elseif logicview.truth(logicview.eq(self.ver, "v3")) then
      channel = _tostring(ch)
    end
  end
  if logicview.truth((not logicview.eq(channel, ""))) then
    self:put(logicview.idx(logicview.idx(nib, offset), 0), logicview.idx(logicview.idx(nib, offset), 1), self.out_ann, { 2, { logicview.add("Ch ", channel), channel } })
  end
end
function _decoder.oregon_battery(self, offset)
  local nib, batt
  nib = self.decoded_nibbles
  batt = "OK"
  if logicview.truth((not logicview.eq(logicview.idx(logicview.idx(nib, offset), 3), ""))) then
    if logicview.truth(logicview.eq(((logicview.tointeger(logicview.idx(logicview.idx(nib, offset), 3), 16) >> 2) & 1), 1)) then
      batt = "Low"
    end
    self:put(logicview.idx(logicview.idx(nib, offset), 0), logicview.idx(logicview.idx(nib, offset), 1), self.out_ann, { 2, { logicview.add("Batt ", batt), batt } })
  end
end
function _decoder.oregon_level2(self)
  local nib, nl, sensor_type, names
  nib = self.decoded_nibbles
  self.sensor_id = _string.upper(logicview.add(logicview.add(logicview.add(logicview.idx(logicview.idx(nib, 0), 3), logicview.idx(logicview.idx(nib, 1), 3)), logicview.idx(logicview.idx(nib, 2), 3)), logicview.idx(logicview.idx(nib, 3), 3)))
  do
    local _lv_seq = logicview.dget(sensor, self.sensor_id, { { "Unknown" }, "Unknown" })
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    nl = logicview.idx(_lv_seq, 0)
    sensor_type = logicview.idx(_lv_seq, 1)
  end
  names = logicview.join(",", nl)
  if logicview.truth((function()
  local _v
  _v = logicview.eq(sensor_type, "Unknown")
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.unknown, "Unknown"))
  return _v
end)()) then
    sensor_type = self.unknown
  end
  self:put(logicview.idx(logicview.idx(nib, 0), 0), logicview.idx(logicview.idx(nib, 3), 1), self.out_ann, { 2, { logicview.add(logicview.add(names, " - "), sensor_type), names, logicview.idx(nl, 0) } })
  self:oregon_channel(4)
  self:oregon_battery(7)
  if logicview.truth(logicview.eq(sensor_type, "Rain")) then
    self:oregon_put_l2_param(8, 4, 2, "", " in/hr")
    self:oregon_put_l2_param(12, 6, 3, "Total ", " in")
    self:oregon_checksum(18)
  end
  if logicview.truth(logicview.eq(sensor_type, "Rain1")) then
    self:oregon_put_l2_param(8, 3, 1, "", " mm/hr")
    self:oregon_put_l2_param(11, 5, 1, "Total ", " mm")
    self:oregon_checksum(18)
  end
  if logicview.truth(logicview.eq(sensor_type, "Temp")) then
    self:oregon_temp(8)
    self:oregon_checksum(12)
  end
  if logicview.truth(logicview.eq(sensor_type, "Temp_Hum_Baro")) then
    self:oregon_temp(8)
    self:oregon_put_l2_param(12, 2, 0, "Hum ", "%")
    self:oregon_baro(15)
    self:oregon_checksum(19)
  end
  if logicview.truth(logicview.eq(sensor_type, "Temp_Hum_Baro1")) then
    self:oregon_temp(8)
    self:oregon_put_l2_param(12, 2, 0, "Hum ", "%")
    self:oregon_baro(14)
  end
  if logicview.truth(logicview.eq(sensor_type, "Temp_Hum")) then
    self:oregon_temp(8)
    self:oregon_put_l2_param(12, 2, 0, "Hum ", "%")
    self:oregon_checksum(15)
  end
  if logicview.truth(logicview.eq(sensor_type, "Temp_Hum1")) then
    self:oregon_temp(8)
    self:oregon_put_l2_param(12, 2, 0, "Hum ", "%")
    self:oregon_checksum(14)
  end
  if logicview.truth(logicview.eq(sensor_type, "UV")) then
    self:oregon_put_l2_param(8, 2, 0, "", "")
  end
  if logicview.truth(logicview.eq(sensor_type, "UV1")) then
    self:oregon_put_l2_param(11, 2, 0, "", "")
  end
  if logicview.truth(logicview.eq(sensor_type, "Wind")) then
    self:oregon_wind_dir(8)
    self:oregon_put_l2_param(11, 3, 1, "Gust ", " m/s")
    self:oregon_put_l2_param(14, 3, 1, "Speed ", " m/s")
    self:oregon_checksum(17)
  end
end
function _decoder.oregon_put_checksum(self, nibbles, checksum)
  local nib, result, rx_check, details
  nib = self.decoded_nibbles
  result = "BAD"
  if logicview.truth((logicview.add(nibbles, 1) < logicview.len(nib))) then
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(logicview.idx(nib, logicview.add(nibbles, 1)), 3), ""))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(logicview.idx(nib, nibbles), 3), ""))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(checksum, (-1)))
  return _v
end)()) then
      if logicview.truth((not logicview.eq(self.ver, "v1"))) then
        if logicview.truth(logicview.eq(checksum, logicview.add(logicview.mul(logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.add(nibbles, 1)), 3), 16), 16), logicview.tointeger(logicview.idx(logicview.idx(nib, nibbles), 3), 16)))) then
          result = "OK"
        end
      elseif logicview.truth(logicview.eq(checksum, logicview.add(logicview.mul(logicview.tointeger(logicview.idx(logicview.idx(nib, nibbles), 3), 16), 16), logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.add(nibbles, 1)), 3), 16)))) then
        result = "OK"
      end
    end
    rx_check = _string.upper(logicview.add(logicview.idx(logicview.idx(nib, logicview.add(nibbles, 1)), 3), logicview.idx(logicview.idx(nib, nibbles), 3)))
    details = logicview.pymod("%s Calc %s Rx %s ", { result, _string.upper(logicview.slice(logicview.hex(checksum), 2, nil, nil)), rx_check })
    self:put(logicview.idx(logicview.idx(nib, nibbles), 0), logicview.idx(logicview.idx(nib, logicview.add(nibbles, 1)), 1), self.out_ann, { 2, { logicview.add("Checksum ", details), result } })
  end
end
function _decoder.oregon_checksum(self, nibbles)
  local checksum, i, nibble, chk_ver, comment
  checksum = 0
  for _lv_i in logicview.range(nibbles) do
    i = _lv_i
    nibble = logicview.slice(self.ookstring, logicview.mul(i, 4), logicview.add(logicview.mul(i, 4), 4), nil)
    nibble = logicview.slice(nibble, nil, nil, (-1))
    if logicview.truth(logicview.contains(nibble, "E")) then
      checksum = (-1)
      break
    end
    checksum = logicview.add(checksum, logicview.tointeger(nibble, 2))
    if logicview.truth((checksum > 255)) then
      checksum = (checksum - 255)
    end
    ::continue_10::
  end
  do
    local _lv_seq = logicview.dget(sensor_checksum, self.sensor_id, { "Unknown", "Unknown" })
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    chk_ver = logicview.idx(_lv_seq, 0)
    comment = logicview.idx(_lv_seq, 1)
  end
  if logicview.truth((not logicview.eq(chk_ver, "Unknown"))) then
    self.ver = chk_ver
  end
  if logicview.truth(logicview.eq(self.ver, "v2.1")) then
    checksum = (checksum - 10)
  end
  self:oregon_put_checksum(nibbles, checksum)
end
function _decoder.oregon_checksum_v1(self)
  local nib, checksum, i
  nib = self.decoded_nibbles
  checksum = 0
  for _lv_i in logicview.range(3) do
    i = _lv_i
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(logicview.idx(nib, logicview.mul(2, i)), 3), "")
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(logicview.idx(nib, logicview.add(logicview.mul(2, i), 1)), 3), "")
  return _v
end)()) then
      checksum = (-1)
      break
    end
    checksum = logicview.add(checksum, (((logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.mul(2, i)), 3), 16) & 15) << 4) | (logicview.tointeger(logicview.idx(logicview.idx(nib, logicview.add(logicview.mul(2, i), 1)), 3), 16) & 15)))
    if logicview.truth((checksum > 255)) then
      checksum = (checksum - 255)
    end
    ::continue_11::
  end
  self:oregon_put_checksum(6, checksum)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    self.decoded = data
    self:oregon()
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
