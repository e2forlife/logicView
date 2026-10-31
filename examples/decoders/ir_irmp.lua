-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2014 Gump Yang <gump.yang@gmail.com>
-- Copyright (C) 2019 Rene Staffen
-- Copyright (C) 2020-2021 Gerhard Sittig <gerhard.sittig@gmx.net>

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
local irmp_library, SamplerateError, LibraryError, Decoder
local _decoder

irmp_library = { IrmpLibrary = function() _error({ _exc = 'Exception', args = { 'IRMP native library is not available' } }, 0) end }
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
LibraryError = function(msg)
  local text = _tostring(msg or "LibraryError")
  return _setmetatable({ _exc = "LibraryError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "ir_irmp",
  name = "IR IRMP",
  longname = "IR IRMP",
  desc = "IRMP infrared remote control multi protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "IR" },
  channels = { logicview.dict({ id = "ir", name = "IR", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "polarity", desc = "Polarity", default = "active-low", values = { "active-low", "active-high" } }) },
  annotations = { { "packet", "Packet" } },
  annotation_rows = { { "packets", "IR Packets", { 0 } } },
  binary = {  }
}
function _decoder.putframe(self, data)
  local nr, name, addr, cmd, repeat_, release, ss, es, rep_txts, rel_txts, flag_txts, zoom, flg, txts
  nr = logicview.idx(data, "proto_nr")
  name = logicview.idx(data, "proto_name")
  addr = logicview.idx(data, "address")
  cmd = logicview.idx(data, "command")
  repeat_ = logicview.idx(data, "repeat")
  release = logicview.idx(data, "release")
  ss = logicview.mul(logicview.idx(data, "start"), self.rate_factor)
  es = logicview.mul(logicview.idx(data, "end"), self.rate_factor)
  rep_txts = { "repeat", "rep", "r" }
  rel_txts = { "release", "rel", "R" }
  flag_txts = logicview.mul({ nil }, logicview.len(rep_txts))
  for _lv_i in logicview.range(logicview.len(flag_txts)) do
    zoom = _lv_i
    logicview.setidx(flag_txts, zoom, {  })
    if logicview.truth(repeat_) then
      _table.insert(logicview.idx(flag_txts, zoom), logicview.idx(rep_txts, zoom))
    end
    if logicview.truth(release) then
      _table.insert(logicview.idx(flag_txts, zoom), logicview.idx(rel_txts, zoom))
    end
    ::continue_1::
  end
  flag_txts = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(flag_txts) do
    t = _lv_item
    _lv_out[#_lv_out + 1] = (function()
  local _v
  _v = logicview.join(" ", t)
  if logicview.truth(_v) then return _v end
  _v = "-"
  return _v
end)()
  end
  return _lv_out
end)()
  flg = flag_txts
  txts = { ("Protocol: ") .. (_tostring(name)) .. (" (") .. (_tostring(nr)) .. ("), Address 0x") .. (logicview.format(addr, "04x")) .. (", Command: 0x") .. (logicview.format(cmd, "04x")) .. (", Flags: ") .. (_tostring(logicview.idx(flg, 0))), ("P: ") .. (_tostring(name)) .. (" (") .. (_tostring(nr)) .. ("), Addr: 0x") .. (logicview.format(addr, "x")) .. (", Cmd: 0x") .. (logicview.format(cmd, "x")) .. (", Flg: ") .. (_tostring(logicview.idx(flg, 1))), ("P: ") .. (_tostring(nr)) .. (" A: 0x") .. (logicview.format(addr, "x")) .. (" C: 0x") .. (logicview.format(cmd, "x")) .. (" F: ") .. (_tostring(logicview.idx(flg, 1))), ("C:") .. (logicview.format(cmd, "x")) .. (" A:") .. (logicview.format(addr, "x")) .. (" ") .. (_tostring(logicview.idx(flg, 2))), ("C:") .. (logicview.format(cmd, "x")) }
  self:put(ss, es, self.out_ann, { 0, txts })
end
function _decoder.__init__(self)
  self.irmp = nil
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.decode(self)
  local e, txt, lib_rate, active, ir, data
  if logicview.truth((not logicview.truth(self.irmp))) then
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        self.irmp = irmp_library.IrmpLibrary()
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if true then
          e = _err
          txt = logicview.idx(e.args, 0)
          _error(LibraryError(txt), 0)
        end
      end
    end
  end
  if logicview.truth((not logicview.truth(self.irmp))) then
    _error(LibraryError("Cannot access IRMP library."), 0)
  end
  if logicview.truth((not logicview.truth(self.samplerate))) then
    _error(SamplerateError("Cannot decode without samplerate."), 0)
  end
  lib_rate = self.irmp:get_sample_rate()
  if logicview.truth((not logicview.truth(lib_rate))) then
    _error(LibraryError("Cannot determine IRMP library's samplerate."), 0)
  end
  if logicview.truth(logicview.pymod(self.samplerate, lib_rate)) then
    _error(SamplerateError(logicview.pyformat("Capture samplerate must be multiple of library samplerate ({})", { lib_rate }, logicview.dict({}))), 0)
  end
  self.rate_factor = logicview.tointeger((self.samplerate / lib_rate))
  active = (function() if logicview.truth(logicview.eq(logicview.idx(self.options, "polarity"), "active-low")) then return 0 else return 1 end end)()
  do
    local _lv_seq = self:wait()
    if _type(_lv_seq) == 'function' then
      local _lv_built = {}
      for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
      _lv_seq = _lv_built
    end
    ir = logicview.idx(_lv_seq, 0)
  end
  self.irmp:reset_state()
  while true do
    if logicview.truth(logicview.eq(active, 1)) then
      ir = (1 - ir)
    end
    if logicview.truth(self.irmp:add_one_sample(ir)) then
      data = self.irmp:get_result_data()
      self:putframe(data)
    end
    do
      local _lv_seq = self:wait({ logicview.dict({ skip = self.rate_factor }) })
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ir = logicview.idx(_lv_seq, 0)
    end
    ::continue_2::
  end
end

return _decoder
