-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2015 Petteri Aimonen <jpa@sigrok.mail.kapsi.fi>

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
  id = "stepper_motor",
  name = "Stepper motor",
  longname = "Stepper motor position / speed",
  desc = "Absolute position and movement speed from step/dir.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Embedded/industrial" },
  channels = { logicview.dict({ id = "step", name = "Step", desc = "Step pulse" }), logicview.dict({ id = "dir", name = "Direction", desc = "Direction select" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "unit", desc = "Unit", default = "steps", values = { "steps", "mm" } }), logicview.dict({ id = "steps_per_mm", desc = "Steps per mm", default = 100.0, values = {  } }) },
  annotations = { { "speed", "Speed" }, { "position", "Position" } },
  annotation_rows = { { "speed", "Speed", { 0 } }, { "position", "Position", { 1 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.oldstep = nil
  self.ss_prev_step = nil
  self.pos = 0
  self.prev_speed = nil
  self.prev_pos = nil
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  if logicview.truth(logicview.eq(logicview.idx(self.options, "unit"), "steps")) then
    self.scale = 1
    self.format = "%0.0f"
    self.unit = "steps"
  else
    self.scale = logicview.idx(self.options, "steps_per_mm")
    self.format = "%0.2f"
    self.unit = "mm"
  end
end
function _decoder.step(self, ss, direction)
  local delta, speed, speed_txt, pos_txt
  if logicview.truth((self.ss_prev_step ~= nil)) then
    if logicview.truth(self.samplerate) then
      delta = (ss - self.ss_prev_step)
      speed = ((self.samplerate / delta) / self.scale)
      speed_txt = logicview.pymod(self.format, speed)
      self:put(self.ss_prev_step, ss, self.out_ann, { 0, { logicview.add(logicview.add(logicview.add(speed_txt, " "), self.unit), "/s"), speed_txt } })
    end
    pos_txt = logicview.pymod(self.format, (self.pos / self.scale))
    self:put(self.ss_prev_step, ss, self.out_ann, { 1, { logicview.add(logicview.add(pos_txt, " "), self.unit), pos_txt } })
  end
  self.pos = logicview.add(self.pos, (function() if logicview.truth(direction) then return 1 else return (-1) end end)())
  self.ss_prev_step = ss
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.decode(self)
  local step, direction
  while true do
    do
      local _lv_seq = self:wait(logicview.dict({ [0] = "r" }))
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      step = logicview.idx(_lv_seq, 0)
      direction = logicview.idx(_lv_seq, 1)
    end
    self:step(self.samplenum, direction)
    ::continue_1::
  end
end

return _decoder
