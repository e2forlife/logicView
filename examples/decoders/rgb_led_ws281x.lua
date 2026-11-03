-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2016 Vladimir Ermakov <vooon341@gmail.com>
-- Copyright (C) 2021 Michael Miller <makuna@live.com>
-- Copyright (C) 2024 DreamSourceLab <support@dreamsourcelab.com>

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
local reduce, SamplerateError, Decoder
local _decoder

reduce = function(fn, seq, init)
  local acc, start_at = init, 1
  if acc == nil then acc = seq[1]; start_at = 2 end
  for _i = start_at, #seq do acc = fn(acc, seq[_i]) end
  return acc
end
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "rgb_led_ws281x",
  name = "RGB LED WS2812+",
  longname = "RGB LED color decoder",
  desc = "Decodes colors from bus pulses for single wire RGB leds like APA106, WS2811, WS2812, WS2813, SK6812, TM1829, TM1814, and TX1812.",
  license = "gplv3+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Display", "IC" },
  channels = { logicview.dict({ id = "din", name = "DIN", desc = "DIN data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "default_color_order", desc = "Default Color Order", default = "GRB", values = { "GRB", "RGB", "BRG", "RBG", "BGR", "GRBW", "RGBW", "WRGB", "LBGR", "LGRB", "LRGB", "LRBG", "LGBR", "LBRG" } }), logicview.dict({ id = "view_color_order", desc = "View Color Order", default = "GRB", values = { "GRB", "RGB", "BRG", "RBG", "BGR", "GRBW", "RGBW", "WRGB", "LBGR", "LGRB", "LRGB", "LRBG", "LGBR", "LBRG" } }), logicview.dict({ id = "polarity", desc = "Polarity", default = "normal", values = { "normal", "inverted" } }) },
  annotations = { { "bit", "Bit" }, { "reset", "RESET" }, { "rgb", "RGB" }, { "byte", "Byte" } },
  lanes = { { id = "color", name = "RGB LED", channel = "din", channels = { "din" }, classes = { "byte" }, value_field = "value" } },
  annotation_rows = { { "bit", "Bits", { 0, 1 } }, { "rgb", "RGB", { 2 } }, { "byte", "Bytes", { 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = "FIND RESET"
  self.samplerate = nil
  self.ss_packet = nil
  self.ss = nil
  self.es = nil
  self.bits = {  }
  self.bit_ = nil
  self.last_bit_period = nil
  self.colorsize = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.handle_bits(self, samplenum)
  local elems, default_val, view_val, i, default_index
  local count = #self.bits
  if count % 8 == 1 then self.byte_start = self.ss end
  if count > 0 and count % 8 == 0 then
    local byte = 0
    for index = count - 7, count do byte = (byte << 1) | self.bits[index] end
    self:put(self.byte_start, samplenum - 1, self.out_ann, { 3, { logicview.pymod("@%02X", byte) } })
  end
  if logicview.truth(logicview.eq(logicview.len(self.bits), self.colorsize)) then
    elems = reduce((function(a, b) return ((a << 1) | b) end), self.bits)
    default_val = 0
    view_val = 0
    if logicview.truth(logicview.eq(self.colorsize, 24)) then
      for _lv_i in logicview.range(3) do
        i = _lv_i
        default_index = logicview.find(logicview.idx(self.options, "default_color_order"), logicview.idx(logicview.idx(self.options, "view_color_order"), i))
        if logicview.truth(logicview.eq(default_index, 0)) then
          default_val = ((elems & 16711680) >> 16)
        elseif logicview.truth(logicview.eq(default_index, 1)) then
          default_val = ((elems & 65280) >> 8)
        elseif logicview.truth(logicview.eq(default_index, 2)) then
          default_val = (elems & 255)
        end
        if logicview.truth(logicview.eq(i, 0)) then
          view_val = ((default_val << 16) | view_val)
        elseif logicview.truth(logicview.eq(i, 1)) then
          view_val = ((default_val << 8) | view_val)
        elseif logicview.truth(logicview.eq(i, 2)) then
          view_val = (default_val | view_val)
        end
        ::continue_1::
      end
      self:put(self.ss_packet, samplenum - 1, self.out_ann, { 2, { logicview.pymod("%s#%06x", { logicview.idx(self.options, "view_color_order"), view_val }), logicview.pymod("@%06x", view_val) } })
    else
      for _lv_i in logicview.range(4) do
        i = _lv_i
        default_index = logicview.find(logicview.idx(self.options, "default_color_order"), logicview.idx(logicview.idx(self.options, "view_color_order"), i))
        if logicview.truth(logicview.eq(default_index, 0)) then
          default_val = ((elems & 4278190080) >> 24)
        elseif logicview.truth(logicview.eq(default_index, 1)) then
          default_val = ((elems & 16711680) >> 16)
        elseif logicview.truth(logicview.eq(default_index, 2)) then
          default_val = ((elems & 65280) >> 8)
        elseif logicview.truth(logicview.eq(default_index, 3)) then
          default_val = (elems & 255)
        end
        if logicview.truth(logicview.eq(i, 0)) then
          view_val = ((default_val << 24) | view_val)
        elseif logicview.truth(logicview.eq(i, 1)) then
          view_val = ((default_val << 16) | view_val)
        elseif logicview.truth(logicview.eq(i, 2)) then
          view_val = ((default_val << 8) | view_val)
        elseif logicview.truth(logicview.eq(i, 3)) then
          view_val = (default_val | view_val)
        end
        ::continue_2::
      end
      self:put(self.ss_packet, samplenum - 1, self.out_ann, { 2, { logicview.pymod("%s#%08x", { logicview.idx(self.options, "view_color_order"), view_val }), logicview.pymod("@%08x", view_val) } })
    end
    self.bits = {  }
    self.ss_packet = samplenum
  end
end
function _decoder.check_bit_(self, samplenum, terminal)
  local period, tH_samples, tH
  period = (samplenum - self.ss)
  tH_samples = (self.es - self.ss)
  if not terminal then
    self.last_bit_period = period
  elseif self.last_bit_period then
    period = self.last_bit_period
  end
  tH = (tH_samples / self.samplerate)
  if logicview.truth((tH >= 6.25e-07)) then
    self.bit_ = 1
  else
    self.bit_ = (tH_samples / period) > 0.5 and 1 or 0
  end
end
function _decoder.finish_last_bit(self, limit)
  if self.state ~= "BIT FALLING" or not self.es or self.es <= self.ss then return end
  self:check_bit_(limit, true)
  local bit_end = _math.min(limit, self.ss + (self.last_bit_period or (self.es - self.ss)))
  bit_end = _math.max(self.es, bit_end)
  self:put(self.ss, bit_end - 1, self.out_ann, { 0, { logicview.pymod("%d", self.bit_) } })
  _table.insert(self.bits, self.bit_)
  self:handle_bits(bit_end)
end
function _decoder.end_(self)
  self:finish_last_bit(self.last_samplenum + 1)
end
function _decoder.decode(self)
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  if logicview.truth((not logicview.eq(logicview.len(logicview.idx(self.options, "default_color_order")), logicview.len(logicview.idx(self.options, "view_color_order"))))) then
    _error(Exception("default color order len must equal to view color order len"), 0)
  end
  if logicview.truth(logicview.eq(logicview.len(logicview.idx(self.options, "default_color_order")), 4)) then
    self.colorsize = 32
  else
    self.colorsize = 24
  end
  while true do
    if logicview.truth(logicview.eq(self.state, "FIND RESET")) then
      self:wait(logicview.dict({ [0] = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "normal")) then return "l" else return "h" end end)() }))
      self.ss = self.samplenum
      self:wait(logicview.dict({ [0] = "e" }))
      self.es = self.samplenum
      if logicview.truth((((self.es - self.ss) / self.samplerate) > 5e-05)) then
        self.state = "RESET"
      elseif logicview.truth((((self.es - self.ss) / self.samplerate) > 3e-06)) then
        self.bits = {  }
        self.ss = self.samplenum
        self.ss_packet = self.samplenum
        self:wait(logicview.dict({ [0] = "e" }))
        self.state = "BIT FALLING"
      end
    elseif logicview.truth(logicview.eq(self.state, "RESET")) then
      self:put(self.ss, self.es, self.out_ann, { 1, { "RESET", "RST", "R" } })
      self.bits = {  }
      self.ss = self.samplenum
      self.ss_packet = self.samplenum
      self:wait(logicview.dict({ [0] = "e" }))
      self.state = "BIT FALLING"
    elseif logicview.truth(logicview.eq(self.state, "BIT FALLING")) then
      self.es = self.samplenum
      self:wait(logicview.dict({ [0] = "e" }))
      if logicview.truth((((self.samplenum - self.es) / self.samplerate) > 5e-05)) then
        self:finish_last_bit(self.samplenum)
        self.ss = self.es
        self.es = self.samplenum
        self.state = "RESET"
      else
        self.state = "BIT RISING"
      end
    elseif logicview.truth(logicview.eq(self.state, "BIT RISING")) then
      self:check_bit_(self.samplenum)
      self:put(self.ss, self.samplenum, self.out_ann, { 0, { logicview.pymod("%d", self.bit_) } })
      _table.insert(self.bits, self.bit_)
      self:handle_bits(self.samplenum)
      self.ss = self.samplenum
      self:wait(logicview.dict({ [0] = "e" }))
      self.state = "BIT FALLING"
    end
    ::continue_3::
  end
end

return _decoder
