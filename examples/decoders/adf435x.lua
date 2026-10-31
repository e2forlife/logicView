-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2017 Joel Holdsworth <joel@airwebreathe.org.uk>

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
local bitpack_lsb, disabled_enabled, output_power, regs, ANN_REG, ANN_WARN, Decoder
local _decoder

bitpack_lsb = logicview.bitpack_lsb
disabled_enabled = function(v)
  return logicview.idx({ "Disabled", "Enabled" }, v)
end
output_power = function(v)
  return logicview.pyformat("{:+d}dBm", { logicview.idx({ (-4), (-1), 2, 5 }, v) }, logicview.dict({}))
end
regs = logicview.dict({ [0] = { { 3, 12, "FRAC" }, { 15, 16, "INT", nil, (function(v) return (function() if logicview.truth((v < 23)) then return "Not Allowed" else return nil end end)() end) } }, [1] = { { 3, 12, "MOD" }, { 15, 12, "Phase" }, { 27, 1, "Prescalar", (function(v) return logicview.idx({ "4/5", "8/9" }, v) end) }, { 28, 1, "Phase Adjust", (function(v) return logicview.idx({ "Off", "On" }, v) end) } }, [2] = { { 3, 1, "Counter Reset", disabled_enabled }, { 4, 1, "Charge Pump Three-State", disabled_enabled }, { 5, 1, "Power-Down", disabled_enabled }, { 6, 1, "PD Polarity", (function(v) return logicview.idx({ "Negative", "Positive" }, v) end) }, { 7, 1, "LDP", (function(v) return logicview.idx({ "10ns", "6ns" }, v) end) }, { 8, 1, "LDF", (function(v) return logicview.idx({ "FRAC-N", "INT-N" }, v) end) }, { 9, 4, "Charge Pump Current Setting", (function(v) return logicview.pyformat("{curr:0.2f}mA @ 5.1kΩ", {  }, logicview.dict({ curr = logicview.idx({ 0.31, 0.63, 0.94, 1.25, 1.56, 1.88, 2.19, 2.5, 2.81, 3.13, 3.44, 3.75, 4.06, 4.38, 4.69, 5.0 }, v) })) end) }, { 13, 1, "Double Buffer", disabled_enabled }, { 14, 10, "R Counter" }, { 24, 1, "RDIV2", disabled_enabled }, { 25, 1, "Reference Doubler", disabled_enabled }, { 26, 3, "MUXOUT", (function(v) return logicview.pyformat("{text}", {  }, logicview.dict({ text = logicview.idx({ "Three-State Output", "DVdd", "DGND", "R Counter Output", "N Divider Output", "Analog Lock Detect", "Digital Lock Detect", "Reserved" }, v) })) end) }, { 29, 2, "Low Noise and Low Spur Modes", (function(v) return logicview.pyformat("{text}", {  }, logicview.dict({ text = logicview.idx({ "Low Noise Mode", "Reserved", "Reserved", "Low Spur Mode" }, v) })) end) } }, [3] = { { 3, 12, "Clock Divider" }, { 15, 2, "Clock Divider Mode", (function(v) return logicview.pyformat("{text}", {  }, logicview.dict({ text = logicview.idx({ "Clock Divider Off", "Fast Lock Enable", "Resync Enable", "Reserved" }, v) })) end) }, { 18, 1, "CSR Enable", disabled_enabled }, { 21, 1, "Charge Cancellation", disabled_enabled }, { 22, 1, "ABP", (function(v) return logicview.idx({ "6ns (FRAC-N)", "3ns (INT-N)" }, v) end) }, { 23, 1, "Band Select Clock Mode", (function(v) return logicview.idx({ "Low", "High" }, v) end) } }, [4] = { { 3, 2, "Output Power", output_power }, { 5, 1, "Output Enable", disabled_enabled }, { 6, 2, "AUX Output Power", output_power }, { 8, 1, "AUX Output Select", (function(v) return logicview.idx({ "Divided Output", "Fundamental" }, v) end) }, { 9, 1, "AUX Output Enable", disabled_enabled }, { 10, 1, "MTLD", disabled_enabled }, { 11, 1, "VCO Power-Down", (function(v) return logicview.pyformat("VCO Powered {ud}", {  }, logicview.dict({ ud = (function() if logicview.truth(v) then return "Down" else return "Up" end end)() })) end) }, { 12, 8, "Band Select Clock Divider" }, { 20, 3, "RF Divider Select", (function(v) return logicview.pyformat("÷{:d}", { (2 ^ v) }, logicview.dict({})) end) }, { 23, 1, "Feedback Select", (function(v) return logicview.idx({ "Divided", "Fundamental" }, v) end) } }, [5] = { { 22, 2, "LD Pin Mode", (function(v) return logicview.pyformat("{text}", {  }, logicview.dict({ text = logicview.idx({ "Low", "Digital Lock Detect", "Low", "High" }, v) })) end) } } })
do
  local _lv_seq = (function() local _t = {}; for _v in logicview.range(2) do _t[#_t + 1] = _v end; return _t end)()
  if _type(_lv_seq) == 'function' then
    local _lv_built = {}
    for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
    _lv_seq = _lv_built
  end
  ANN_REG = logicview.idx(_lv_seq, 0)
  ANN_WARN = logicview.idx(_lv_seq, 1)
end
_decoder = {
  api_version = 3,
  id = "adf435x",
  name = "ADF435x",
  longname = "Analog Devices ADF4350/1",
  desc = "Wideband synthesizer with integrated VCO.",
  license = "gplv3+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Clock/timing", "IC", "Wireless/RF" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "write", "Register write" }, { "warning", "Warnings" } },
  annotation_rows = { { "writes", "Register writes", { 0 } }, { "warnings", "Warnings", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.bits = {  }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putg(self, ss, es, cls, data)
  self:put(ss, es, self.out_ann, { cls, data })
end
function _decoder.decode_bits(self, offset, width)
  local bits, ss, es, value
  bits = logicview.slice(logicview.slice(self.bits, offset, nil, nil), nil, width, nil)
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(bits, (-1)), 1), logicview.idx(logicview.idx(bits, 0), 2)
    ss = _lv_a0
    es = _lv_a1
  end
  value = bitpack_lsb(bits, 0)
  return { value, { ss, es } }
end
function _decoder.decode_field(self, name, offset, width, parser, checker)
  if parser == nil then parser = nil end
  if checker == nil then checker = nil end
  local val, ss, es, formatted, text, warn
  do
    local _lv_seq = self:decode_bits(offset, width)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    val = logicview.idx(_lv_seq, 0)
    do
      local _lv_sub = logicview.idx(_lv_seq, 1)
      ss = logicview.idx(_lv_sub, 0)
      es = logicview.idx(_lv_sub, 1)
    end
  end
  formatted = (function() if logicview.truth(parser) then return parser(val) else return logicview.pyformat("{}", { val }, logicview.dict({})) end end)()
  if logicview.truth((formatted ~= nil)) then
    text = { logicview.pyformat("{name}: {val}", {  }, logicview.dict({ name = name, val = formatted })) }
  else
    text = { logicview.pyformat("{name}", {  }, logicview.dict({ name = name })) }
  end
  if logicview.truth(text) then
    self:putg(ss, es, ANN_REG, text)
  end
  warn = (function() if logicview.truth(checker) then return checker(val) else return nil end end)()
  if logicview.truth(warn) then
    text = { logicview.pyformat("{}", { warn }, logicview.dict({})) }
    self:putg(ss, es, ANN_WARN, text)
  end
end
function _decoder.decode_word(self, ss, es, bits)
  local count, text, reg_addr, reg_ss, reg_es, field_descs, field_desc, parser, checker, start, name
  count = logicview.len(self.bits)
  if logicview.truth((not logicview.eq(count, 32))) then
    text = { logicview.pyformat("Frame error: Bit count: want 32, got {}", { count }, logicview.dict({})), "Frame error: Bit count", "Frame error" }
    self:putg(ss, es, ANN_WARN, text)
    return
  end
  logicview.list_reverse(self.bits)
  do
    local _lv_seq = self:decode_bits(0, 3)
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    reg_addr = logicview.idx(_lv_seq, 0)
    do
      local _lv_sub = logicview.idx(_lv_seq, 1)
      reg_ss = logicview.idx(_lv_sub, 0)
      reg_es = logicview.idx(_lv_sub, 1)
    end
  end
  text = { logicview.pyformat("Register: {addr}", {  }, logicview.dict({ addr = reg_addr })), logicview.pyformat("Reg: {addr}", {  }, logicview.dict({ addr = reg_addr })), logicview.pyformat("[{addr}]", {  }, logicview.dict({ addr = reg_addr })) }
  self:putg(reg_ss, reg_es, ANN_REG, text)
  field_descs = logicview.dget(regs, reg_addr, nil)
  if logicview.truth((not logicview.truth(field_descs))) then
    return
  end
  for _lv_item in logicview.iter(field_descs) do
    field_desc = _lv_item
    parser = nil
    checker = nil
    if logicview.truth(logicview.eq(logicview.len(field_desc), 3)) then
      do
        local _lv_seq = field_desc
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        start = logicview.idx(_lv_seq, 0)
        count = logicview.idx(_lv_seq, 1)
        name = logicview.idx(_lv_seq, 2)
      end
    elseif logicview.truth(logicview.eq(logicview.len(field_desc), 4)) then
      do
        local _lv_seq = field_desc
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        start = logicview.idx(_lv_seq, 0)
        count = logicview.idx(_lv_seq, 1)
        name = logicview.idx(_lv_seq, 2)
        parser = logicview.idx(_lv_seq, 3)
      end
    elseif logicview.truth(logicview.eq(logicview.len(field_desc), 5)) then
      do
        local _lv_seq = field_desc
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        start = logicview.idx(_lv_seq, 0)
        count = logicview.idx(_lv_seq, 1)
        name = logicview.idx(_lv_seq, 2)
        parser = logicview.idx(_lv_seq, 3)
        checker = logicview.idx(_lv_seq, 4)
      end
    else
      return
    end
    self:decode_field(name, start, count, parser, checker)
    ::continue_1::
  end
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, _, mosi_bits, miso_bits, msb_bits
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      _ = logicview.idx(_lv_seq, 1)
      _ = logicview.idx(_lv_seq, 2)
    end
    if logicview.truth(logicview.eq(ptype, "TRANSFER")) then
      self:decode_word(ss, es, self.bits)
      logicview.list_clear(self.bits)
    end
    if logicview.truth(logicview.eq(ptype, "BITS")) then
      do
        local _lv_seq = data
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        _ = logicview.idx(_lv_seq, 0)
        mosi_bits = logicview.idx(_lv_seq, 1)
        miso_bits = logicview.idx(_lv_seq, 2)
      end
      msb_bits = logicview.copy(mosi_bits)
      logicview.list_reverse(msb_bits)
      logicview.extend(self.bits, msb_bits)
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
