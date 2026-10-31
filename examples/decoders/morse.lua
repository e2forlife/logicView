-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+
-- Copyright (C) 2017 Christoph Rackwitz <christoph.rackwitz@rwth-aachen.de>

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
local decode_ditdah, encode_ditdah, alphabet, symbols, Decoder
local _decoder

decode_ditdah = function(s)
  return logicview.copy((function()
  local _lv_out = {}
  for _lv_item in logicview.iter(s) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(logicview.dict({ ["-"] = 3, ["."] = 1 }), c)
  end
  return _lv_out
end)())
end
encode_ditdah = function(tpl)
  return logicview.join("", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(tpl) do
    c = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(logicview.dict({ [1] = ".", [3] = "-" }), c)
  end
  return _lv_out
end)())
end
alphabet = logicview.dict({ [".-"] = "a", ["-..."] = "b", ["-.-."] = "c", ["-.."] = "d", ["."] = "e", ["..-.."] = "é", ["..-."] = "f", ["--."] = "g", ["...."] = "h", [".."] = "i", [".---"] = "j", ["-.-"] = "k", [".-.."] = "l", ["--"] = "m", ["-."] = "n", ["---"] = "o", [".--."] = "p", ["--.-"] = "q", [".-."] = "r", ["..."] = "s", ["-"] = "t", ["..-"] = "u", ["...-"] = "v", [".--"] = "w", ["-..-"] = "x", ["-.--"] = "y", ["--.."] = "z", [".----"] = "1", ["..---"] = "2", ["...--"] = "3", ["....-"] = "4", ["....."] = "5", ["-...."] = "6", ["--..."] = "7", ["---.."] = "8", ["----."] = "9", ["-----"] = "0", [".-.-.-"] = ".", ["--..--"] = ",", ["---..."] = ":", ["..--.."] = "?", [".----."] = "’", ["-....-"] = "-", ["-..-."] = "/", ["-.--."] = "(", ["-.--.-"] = ")", [".-..-."] = "“ ”", ["-...-"] = "=", ["...-."] = "UNDERSTOOD", ["........"] = "ERROR", [".-.-."] = "+", [".-..."] = "WAIT", ["...-.-"] = "EOW", ["-.-.-"] = "START", [".--.-."] = "@" })
alphabet = (function()
  local _lv_out = logicview.dict({})
  for _lv_k, _lv_v in _pairs(alphabet) do
    k = _lv_k
    v = _lv_v
    logicview.setidx(_lv_out, decode_ditdah(k), v)
  end
  return _lv_out
end)()
symbols = logicview.dict({ [logicview.tkey(1, 1)] = "*", [logicview.tkey(1, 3)] = "===", [logicview.tkey(0, 1)] = "_", [logicview.tkey(0, 3)] = "__", [logicview.tkey(0, 7)] = "___" })
_decoder = {
  api_version = 3,
  id = "morse",
  name = "Morse",
  longname = "Morse code",
  desc = "Demodulated morse code protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Encoding" },
  channels = { logicview.dict({ id = "data", name = "Data", desc = "Data line" }) },
  optional_channels = {  },
  options = { logicview.dict({ id = "timeunit", desc = "Time unit (guess)", default = 0.1, values = {  } }) },
  annotations = { { "time", "Time" }, { "units", "Units" }, { "symbol", "Symbol" }, { "letter", "Letter" }, { "word", "Word" } },
  annotation_rows = { { "time", "Time", { 0 } }, { "units", "Units", { 1 } }, { "symbol", "Symbol", { 2 } }, { "letter", "Letter", { 3 } }, { "word", "Word", { 4 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.samplerate = nil
end
function _decoder.metadata(self, key, value)
  if logicview.truth(logicview.eq(key, logicview.SRD_CONF_SAMPLERATE)) then
    self.samplerate = value
  end
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
  self.out_binary = self:register(logicview.OUTPUT_BINARY)
end
function _decoder.decode_symbols(self)
  return logicview.generator(function()
    local timeunit, prevtime, val, pval, curtime, dt, units, iunits, error, symbol, thisunit
    timeunit = logicview.idx(self.options, "timeunit")
    self:wait(logicview.dict({ [0] = "r" }))
    prevtime = self.samplenum
    while true do
      do
        local _lv_seq = self:wait({ logicview.dict({ [0] = "e" }), logicview.dict({ skip = logicview.tointeger(logicview.mul(logicview.mul(5, self.samplerate), timeunit)) }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        val = logicview.idx(_lv_seq, 0)
      end
      pval = (1 - val)
      curtime = self.samplenum
      dt = ((curtime - prevtime) / self.samplerate)
      units = (dt / timeunit)
      iunits = logicview.tointeger(_math.max(1, (function() local _n = units; if _n >= 0 then return _math.floor(_n + 0.5) end; return _math.ceil(_n - 0.5) end)()))
      error = _math.abs((units - iunits))
      symbol = { pval, iunits }
      if logicview.truth((self.matched & (1 << 1))) then
        _coroutine.yield(nil)
        goto continue_1
      end
      self:put(prevtime, curtime, self.out_ann, { 0, { logicview.pyformat("{:.3g}", { dt }, logicview.dict({})) } })
      if logicview.truth(logicview.contains(symbols, symbol)) then
        self:put(prevtime, curtime, self.out_ann, { 1, { logicview.pyformat("{:.1f}*{:.3g}", { units, timeunit }, logicview.dict({})) } })
        _coroutine.yield({ prevtime, curtime, symbol })
      else
        self:put(prevtime, curtime, self.out_ann, { 1, { logicview.pyformat("!! {:.1f}*{:.3g} !!", { units, timeunit }, logicview.dict({})) } })
      end
      prevtime = curtime
      thisunit = (dt / iunits)
      timeunit = logicview.add(timeunit, logicview.mul(logicview.mul((thisunit - timeunit), 0.2), _math.max(0, (1 - logicview.mul(2, error)))))
      ::continue_1::
    end
  end)
end
function _decoder.decode_morse(self)
  return logicview.generator(function()
    local sequence, s0, s1, item, do_yield, t0, t1, symbol, sval, sunits
    sequence = {  }
    do
      local _lv_chain = nil
      s0 = _lv_chain
      s1 = _lv_chain
    end
    for _lv_item in logicview.iter(self:decode_symbols()) do
      item = _lv_item
      do_yield = false
      if logicview.truth((item ~= nil)) then
        do
          local _lv_seq = item
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          t0 = logicview.idx(_lv_seq, 0)
          t1 = logicview.idx(_lv_seq, 1)
          symbol = logicview.idx(_lv_seq, 2)
        end
        do
          local _lv_seq = symbol
          if _type(_lv_seq) == 'function' then
            local _lv_built = {}
            for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
            _lv_seq = _lv_built
          end
          sval = logicview.idx(_lv_seq, 0)
          sunits = logicview.idx(_lv_seq, 1)
        end
        if logicview.truth(logicview.eq(sval, 1)) then
          if logicview.truth((s0 == nil)) then
            s0 = t0
          end
          s1 = t1
          sequence = logicview.add(sequence, { sunits })
        elseif logicview.truth((sunits >= 3)) then
          do_yield = true
        end
      else
        do_yield = true
      end
      if logicview.truth(do_yield) then
        if logicview.truth(sequence) then
          _coroutine.yield({ s0, s1, logicview.dget(alphabet, sequence, encode_ditdah(sequence)) })
          sequence = {  }
          do
            local _lv_chain = nil
            s0 = _lv_chain
            s1 = _lv_chain
          end
        end
      end
      if logicview.truth((item == nil)) then
        _coroutine.yield(nil)
      end
      ::continue_2::
    end
  end)
end
function _decoder.decode(self)
  local s0, s1, word, item, do_yield, t0, t1, letter
  if logicview.truth((not logicview.truth(self.samplerate))) then
    self.samplerate = 1.0
  end
  do
    local _lv_chain = nil
    s0 = _lv_chain
    s1 = _lv_chain
  end
  word = ""
  for _lv_item in logicview.iter(self:decode_morse()) do
    item = _lv_item
    do_yield = false
    if logicview.truth((item ~= nil)) then
      do
        local _lv_seq = item
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        t0 = logicview.idx(_lv_seq, 0)
        t1 = logicview.idx(_lv_seq, 1)
        letter = logicview.idx(_lv_seq, 2)
      end
      self:put(t0, t1, self.out_ann, { 3, { letter } })
      if logicview.truth((s0 == nil)) then
        s0 = t0
      end
      s1 = t1
      word = logicview.add(word, letter)
    else
      do_yield = true
    end
    if logicview.truth(do_yield) then
      if logicview.truth(word) then
        self:put(s0, s1, self.out_ann, { 4, { word } })
        word = ""
        do
          local _lv_chain = nil
          s0 = _lv_chain
          s1 = _lv_chain
        end
      end
    end
    ::continue_3::
  end
end

return _decoder
