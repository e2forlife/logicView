-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2011 Gareth McMullin <gareth@blacksphere.co.nz>
-- Copyright (C) 2012-2013 Uwe Hermann <uwe@hermann-uwe.de>
-- Copyright (C) 2019 DreamSourceLab <support@dreamsourcelab.com>

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
local symbols, bitrates, sym_annotation, SamplerateError, Decoder
local _decoder

symbols = logicview.dict({ ["low-speed"] = logicview.dict({ [logicview.tkey(0, 0)] = "SE0", [logicview.tkey(1, 0)] = "K", [logicview.tkey(0, 1)] = "J", [logicview.tkey(1, 1)] = "SE1" }), ["full-speed"] = logicview.dict({ [logicview.tkey(0, 0)] = "SE0", [logicview.tkey(1, 0)] = "J", [logicview.tkey(0, 1)] = "K", [logicview.tkey(1, 1)] = "SE1" }), automatic = logicview.dict({ [logicview.tkey(0, 0)] = "SE0", [logicview.tkey(1, 0)] = "FS_J", [logicview.tkey(0, 1)] = "LS_J", [logicview.tkey(1, 1)] = "SE1" }), ["low-speed-rp"] = logicview.dict({ [logicview.tkey(0, 0)] = "SE0", [logicview.tkey(1, 0)] = "J", [logicview.tkey(0, 1)] = "K", [logicview.tkey(1, 1)] = "SE1" }) })
bitrates = logicview.dict({ ["low-speed"] = 1500000, ["low-speed-rp"] = 1500000, ["full-speed"] = 12000000, automatic = nil })
sym_annotation = logicview.dict({ J = { 0, { "J" } }, K = { 1, { "K" } }, SE0 = { 2, { "SE0", "0" } }, SE1 = { 3, { "SE1", "1" } } })
SamplerateError = function(msg)
  local text = _tostring(msg or "SamplerateError")
  return _setmetatable({ _exc = "SamplerateError", args = { text } }, { __tostring = function() return text end })
end
_decoder = {
  api_version = 3,
  id = "usb_signalling",
  name = "USB signalling",
  longname = "Universal Serial Bus (LS/FS) signalling",
  desc = "USB (low-speed/full-speed) signalling protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = { "usb_signalling" },
  tags = { "PC" },
  channels = { logicview.dict({ id = "dp", name = "D+", desc = "USB D+ signal" }), logicview.dict({ id = "dm", name = "D-", desc = "USB D- signal" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "signalling", desc = "Signalling", default = "automatic", values = { "automatic", "full-speed", "low-speed" } }) },
  annotations = { { "sym-j", "J symbol" }, { "sym-k", "K symbol" }, { "sym-se0", "SE0 symbol" }, { "sym-se1", "SE1 symbol" }, { "sop", "Start of packet (SOP)" }, { "eop", "End of packet (EOP)" }, { "bit", "Bit" }, { "stuffbit", "Stuff bit" }, { "error", "Error" }, { "keep-alive", "Low-speed keep-alive" }, { "reset", "Reset" } },
  annotation_rows = { { "bits", "Bits", { 4, 5, 6, 7, 8, 9, 10 } }, { "symbols", "Symbols", { 0, 1, 2, 3 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
  self.oldsym = "J"
  self.ss_block = nil
  self.samplenum = 0
  self.bitrate = nil
  self.bitwidth = nil
  self.samplepos = nil
  self.samplenum_target = nil
  self.samplenum_edge = nil
  self.samplenum_lastedge = 0
  self.edgepins = nil
  self.consecutive_ones = 0
  self.bits = nil
  self.state = "IDLE"
end
function _decoder.start(self)
  self.out_python = self:register(logicview.OUTPUT_PYTHON)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
    self.signalling = logicview.idx(self.options, "signalling")
    self:update_bitrate()
  end
end
function _decoder.update_bitrate(self)
  if logicview.truth((not logicview.eq(self.signalling, "automatic"))) then
    self.bitrate = logicview.idx(bitrates, self.signalling)
    self.bitwidth = ((_tonumber(self.samplerate) or 0) / (_tonumber(self.bitrate) or 0))
  end
end
function _decoder.putpx(self, data)
  local s
  s = self.samplenum_edge
  self:put(s, s, self.out_python, data)
end
function _decoder.putx(self, data)
  local s
  s = self.samplenum_edge
  self:put(s, s, self.out_ann, data)
end
function _decoder.putpm(self, data)
  local e
  e = self.samplenum_edge
  self:put(self.ss_block, e, self.out_python, data)
end
function _decoder.putm(self, data)
  local e
  e = self.samplenum_edge
  self:put(self.ss_block, e, self.out_ann, data)
end
function _decoder.putpb(self, data)
  local s, e
  do
    local _lv_a0, _lv_a1 = self.samplenum_lastedge, self.samplenum_edge
    s = _lv_a0
    e = _lv_a1
  end
  self:put(s, e, self.out_python, data)
end
function _decoder.putb(self, data)
  local s, e
  do
    local _lv_a0, _lv_a1 = self.samplenum_lastedge, self.samplenum_edge
    s = _lv_a0
    e = _lv_a1
  end
  self:put(s, e, self.out_ann, data)
end
function _decoder.set_new_target_samplenum(self)
  self.samplepos = logicview.add(self.samplepos, self.bitwidth)
  self.samplenum_target = logicview.tointeger(self.samplepos)
  self.samplenum_lastedge = self.samplenum_edge
  self.samplenum_edge = logicview.tointeger((self.samplepos - (self.bitwidth / 2)))
end
function _decoder.wait_for_sop(self, sym)
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(sym, "K"))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.oldsym, "J"))
  return _v
end)()) then
    return
  end
  self.consecutive_ones = 0
  self.bits = ""
  self:update_bitrate()
  self.samplepos = logicview.add((self.samplenum - (self.bitwidth / 2)), 0.5)
  self:set_new_target_samplenum()
  self:putpx({ "SOP", nil })
  self:putx({ 4, { "SOP", "S" } })
  self.state = "GET BIT"
end
function _decoder.handle_bit(self, b)
  if logicview.truth(logicview.eq(self.consecutive_ones, 6)) then
    if logicview.truth(logicview.eq(b, "0")) then
      self:putpb({ "STUFF BIT", nil })
      self:putb({ 7, { "Stuff bit: 0", "SB: 0", "0" } })
      self.consecutive_ones = 0
    else
      self:putpb({ "ERR", nil })
      self:putb({ 8, { "Bit stuff error", "BS ERR", "B" } })
      self.state = "IDLE"
    end
  else
    self:putpb({ "BIT", b })
    self:putb({ 6, { logicview.pymod("%s", b) } })
    if logicview.truth(logicview.eq(b, "1")) then
      self.consecutive_ones = logicview.add(self.consecutive_ones, 1)
    else
      self.consecutive_ones = 0
    end
  end
end
function _decoder.get_eop(self, sym)
  self:set_new_target_samplenum()
  self:putpb({ "SYM", sym })
  self:putb(logicview.idx(sym_annotation, sym))
  self.oldsym = sym
  if logicview.truth(logicview.eq(sym, "SE0")) then
  elseif logicview.truth(logicview.eq(sym, "J")) then
    self:putpm({ "EOP", nil })
    self:putm({ 5, { "EOP", "E" } })
    self.state = "WAIT IDLE"
  else
    self:putpm({ "ERR", nil })
    self:putm({ 8, { "EOP Error", "EErr", "E" } })
    self.state = "IDLE"
  end
end
function _decoder.get_bit(self, sym)
  local b, edgesym
  self:set_new_target_samplenum()
  b = (function() if logicview.truth((not logicview.eq(self.oldsym, sym))) then return "0" else return "1" end end)()
  self.oldsym = sym
  if logicview.truth(logicview.eq(sym, "SE0")) then
    self.state = "GET EOP"
    self.ss_block = self.samplenum_lastedge
  else
    self:handle_bit(b)
  end
  self:putpb({ "SYM", sym })
  self:putb(logicview.idx(sym_annotation, sym))
  if logicview.truth((logicview.len(self.bits) <= 16)) then
    self.bits = logicview.add(self.bits, b)
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.len(self.bits), 16)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.bits, "0000000100111100")
  return _v
end)()) then
    self:putpx({ "EOP", nil })
    self.state = "IDLE"
    self.signalling = "low-speed-rp"
    self:update_bitrate()
    self.oldsym = "J"
  end
  if logicview.truth(logicview.eq(b, "0")) then
    edgesym = logicview.idx(logicview.idx(symbols, self.signalling), logicview.copy(self.edgepins))
    if logicview.truth((not logicview.contains({ "SE0", "SE1" }, edgesym))) then
      if logicview.truth(logicview.eq(edgesym, sym)) then
        self.bitwidth = (self.bitwidth - logicview.mul(0.001, self.bitwidth))
        self.samplepos = (self.samplepos - logicview.mul(0.01, self.bitwidth))
      else
        self.bitwidth = logicview.add(self.bitwidth, logicview.mul(0.001, self.bitwidth))
        self.samplepos = logicview.add(self.samplepos, logicview.mul(0.01, self.bitwidth))
      end
    end
  end
end
function _decoder.handle_idle(self, sym)
  local se0_length
  self.samplenum_edge = self.samplenum
  se0_length = ((_tonumber((self.samplenum - self.samplenum_lastedge)) or 0) / self.samplerate)
  if logicview.truth((se0_length > 2.5e-06)) then
    self:putpb({ "RESET", nil })
    self:putb({ 10, { "Reset", "Res", "R" } })
    self.signalling = logicview.idx(self.options, "signalling")
  elseif logicview.truth((function()
  local _v
  _v = (se0_length > 1.2e-06)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.signalling, "low-speed")
  return _v
end)()) then
    self:putpb({ "KEEP ALIVE", nil })
    self:putb({ 9, { "Keep-alive", "KA", "A" } })
  end
  if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(self.options, "signalling"), "automatic")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(sym, "FS_J")
  return _v
end)()) then
    self.signalling = "full-speed"
  elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(self.options, "signalling"), "automatic")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(sym, "LS_J")
  return _v
end)()) then
    self.signalling = "low-speed"
  else
    self.signalling = logicview.idx(self.options, "signalling")
  end
  self:update_bitrate()
  self.oldsym = "J"
  self.state = "IDLE"
end
function _decoder.decode(self)
  local dp, dm, sym
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
    dp = logicview.idx(_lv_seq, 0)
    dm = logicview.idx(_lv_seq, 1)
  end
  sym = logicview.idx(logicview.idx(symbols, logicview.idx(self.options, "signalling")), logicview.tkey(dp, dm))
  self:handle_idle(sym)
  while true do
    if logicview.truth(logicview.eq(self.state, "IDLE")) then
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ [1] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dp = logicview.idx(_lv_seq, 0)
        dm = logicview.idx(_lv_seq, 1)
      end
      sym = logicview.idx(logicview.idx(symbols, self.signalling), logicview.tkey(dp, dm))
      if logicview.truth(logicview.eq(sym, "SE0")) then
        self.samplenum_lastedge = self.samplenum
        self.state = "WAIT IDLE"
      else
        self:wait_for_sop(sym)
      end
      self.edgepins = { dp, dm }
    elseif logicview.truth(logicview.contains({ "GET BIT", "GET EOP" }, self.state)) then
      if logicview.truth((self.samplenum_edge > self.samplenum)) then
        do
          local _lv_seq = self:wait({ logicview.dict({ skip = (self.samplenum_edge - self.samplenum) }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          dp = logicview.idx(_lv_seq, 0)
          dm = logicview.idx(_lv_seq, 1)
        end
        self.edgepins = { dp, dm }
      end
      if logicview.truth((self.samplenum_target > self.samplenum)) then
        do
          local _lv_seq = self:wait({ logicview.dict({ skip = (self.samplenum_target - self.samplenum) }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          dp = logicview.idx(_lv_seq, 0)
          dm = logicview.idx(_lv_seq, 1)
        end
      end
      sym = logicview.idx(logicview.idx(symbols, self.signalling), logicview.tkey(dp, dm))
      if logicview.truth(logicview.eq(self.state, "GET BIT")) then
        self:get_bit(sym)
      elseif logicview.truth(logicview.eq(self.state, "GET EOP")) then
        self:get_eop(sym)
      end
    elseif logicview.truth(logicview.eq(self.state, "WAIT IDLE")) then
      do
        local _lv_seq = self:wait()
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        dp = logicview.idx(_lv_seq, 0)
        dm = logicview.idx(_lv_seq, 1)
      end
      while logicview.truth((function()
  local _v
  _v = (not logicview.truth(dp))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(dm))
  return _v
end)()) do
        do
          local _lv_seq = self:wait({ logicview.dict({ [0] = "h" }), logicview.dict({ [1] = "h" }) })
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          dp = logicview.idx(_lv_seq, 0)
          dm = logicview.idx(_lv_seq, 1)
        end
        ::continue_2::
      end
      if logicview.truth(((self.samplenum - self.samplenum_lastedge) > 1)) then
        sym = logicview.idx(logicview.idx(symbols, logicview.idx(self.options, "signalling")), logicview.tkey(dp, dm))
        self:handle_idle(sym)
      else
        sym = logicview.idx(logicview.idx(symbols, self.signalling), logicview.tkey(dp, dm))
        self:wait_for_sop(sym)
      end
      self.edgepins = { dp, dm }
    end
    ::continue_1::
  end
end

return _decoder
