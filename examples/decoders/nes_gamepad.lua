-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2019 Stephan Thiele <stephan.thiele@mailbox.org>

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
local Decoder
local _decoder

_decoder = {
  api_version = 3,
  id = "nes_gamepad",
  name = "NES gamepad",
  longname = "Nintendo Entertainment System gamepad",
  desc = "NES gamepad button states.",
  license = "gplv2+",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Retro computing" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "variant", desc = "Gamepad variant", default = "Standard gamepad", values = { "Standard gamepad" } }) },
  annotations = { { "button", "Button state" }, { "no-press", "No button press" }, { "not-connected", "Gamepad unconnected" } },
  annotation_rows = { { "buttons", "Button states", { 0 } }, { "no-presses", "No button presses", { 1 } }, { "not-connected-vals", "Gamepad unconnected", { 2 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.variant = nil
  self.ss_block = nil
  self.es_block = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.variant = logicview.idx(self.options, "variant")
end
function _decoder.putx(self, data)
  self:put(self.ss_block, self.es_block, self.out_ann, data)
end
function _decoder.handle_data(self, value)
  local buttons, bits, button_str, b, button_index, button_is_pressed
  if logicview.truth(logicview.eq(value, 255)) then
    self:putx({ 1, { "No button is pressed" } })
    return
  end
  if logicview.truth(logicview.eq(value, 0)) then
    self:putx({ 2, { "Gamepad is not connected" } })
    return
  end
  buttons = { "A", "B", "Select", "Start", "North", "South", "West", "East" }
  bits = logicview.format(value, "08b")
  button_str = ""
  for _lv_i, _lv_v in logicview.enumerate(bits) do
    b = {_lv_i, _lv_v}
    button_index = logicview.idx(b, 0)
    button_is_pressed = logicview.eq(logicview.idx(b, 1), "0")
    if logicview.truth(button_is_pressed) then
      if logicview.truth((not logicview.eq(button_str, ""))) then
        button_str = logicview.add(button_str, " + ")
      end
      button_str = logicview.add(button_str, logicview.idx(buttons, button_index))
    end
    ::continue_1::
  end
  self:putx({ 0, { logicview.pymod("%s", button_str) } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, mosi, miso
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      mosi = logicview.idx(_lv_seq, 1)
      miso = logicview.idx(_lv_seq, 2)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss_block = _lv_a0
      self.es_block = _lv_a1
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    self:handle_data(miso)
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
