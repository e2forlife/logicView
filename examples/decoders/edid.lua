-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2012 Bert Vermeulen <bert@biot.com>

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
local os, EDID_HEADER, OFF_VENDOR, OFF_VERSION, OFF_BASIC, OFF_CHROM, OFF_EST_TIMING, OFF_STD_TIMING, OFF_DET_TIMING, OFF_NUM_EXT, OFF_CHECKSUM, est_modes, xy_ratio, ANN_FIELDS, ANN_SECTIONS, Decoder
local _decoder

os = { path = { join = function(...) return _table.concat({...}, '/') end, exists = function() return false end, dirname = function(p) return p end } }
EDID_HEADER = { 0, 255, 255, 255, 255, 255, 255, 0 }
OFF_VENDOR = 8
OFF_VERSION = 18
OFF_BASIC = 20
OFF_CHROM = 25
OFF_EST_TIMING = 35
OFF_STD_TIMING = 38
OFF_DET_TIMING = 54
OFF_NUM_EXT = 126
OFF_CHECKSUM = 127
est_modes = { "720x400@70Hz", "720x400@88Hz", "640x480@60Hz", "640x480@67Hz", "640x480@72Hz", "640x480@75Hz", "800x600@56Hz", "800x600@60Hz", "800x600@72Hz", "800x600@75Hz", "832x624@75Hz", "1024x768@87Hz(i)", "1024x768@60Hz", "1024x768@70Hz", "1024x768@75Hz", "1280x1024@75Hz", "1152x870@75Hz" }
xy_ratio = { { 16, 10 }, { 4, 3 }, { 5, 4 }, { 16, 9 } }
ANN_FIELDS = 0
ANN_SECTIONS = 1
_decoder = {
  api_version = 3,
  id = "edid",
  name = "EDID",
  longname = "Extended Display Identification Data",
  desc = "Data structure describing display device capabilities.",
  license = "gplv3+",
  inputs = { "i2c" },
  outputs = {  },
  tags = { "Display", "Memory", "PC" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "fields", "EDID structure fields" }, { "sections", "EDID structure sections" } },
  annotation_rows = { { "sections", "Sections", { 1 } }, { "fields", "Fields", { 0 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  self.state = nil
  self.cnt = 0
  self.sn = {  }
  self.cache = {  }
  self.offset = 0
  self.extension = 0
  self.ext_sn = { {  } }
  self.ext_cache = { {  } }
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local cmd, s, t, ext, l, checksum, i, csstr, cache, sn, v, support, n, dtd_last
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      cmd = logicview.idx(_lv_seq, 0)
      data = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(cmd, "ADDRESS WRITE")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data, 80)
  return _v
end)()) then
      self.state = "offset"
      self.ss = ss
      return
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(cmd, "ADDRESS READ")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(data, 80)
  return _v
end)()) then
      if logicview.truth((self.extension > 0)) then
        self.state = "extensions"
        s = _tostring(self.extension)
        t = { logicview.add("Extension: ", s), logicview.add("X: ", s), s }
      else
        self.state = "header"
        t = { "EDID" }
      end
      self:put(ss, es, self.out_ann, { ANN_SECTIONS, t })
      return
    end
    if logicview.truth((function()
  local _v
  _v = logicview.eq(cmd, "DATA WRITE")
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "offset")
  return _v
end)()) then
      self.offset = data
      self.extension = logicview.floordiv(self.offset, 128)
      self.cnt = logicview.pymod(self.offset, 128)
      if logicview.truth((self.extension > 0)) then
        ext = (self.extension - 1)
        l = logicview.len(logicview.idx(self.ext_sn, ext))
        self.sn = logicview.add(logicview.slice(logicview.idx(self.ext_sn, ext), 0, self.cnt, nil), logicview.mul({ 0 }, _math.max(0, (self.cnt - l))))
        self.cache = logicview.add(logicview.slice(logicview.idx(self.ext_cache, ext), 0, self.cnt, nil), logicview.mul({ 0 }, _math.max(0, (self.cnt - l))))
      else
        l = logicview.len(self.sn)
        self.sn = logicview.add(logicview.slice(self.sn, 0, self.cnt, nil), logicview.mul({ 0 }, _math.max(0, (self.cnt - l))))
        self.cache = logicview.add(logicview.slice(self.cache, 0, self.cnt, nil), logicview.mul({ 0 }, _math.max(0, (self.cnt - l))))
      end
      ss = (function() if logicview.truth(self.ss) then return self.ss else return ss end end)()
      s = _tostring(data)
      t = { logicview.add("Offset: ", s), logicview.add("O: ", s), s }
      self:put(ss, es, self.out_ann, { ANN_SECTIONS, t })
      return
    end
    if logicview.truth((not logicview.eq(cmd, "DATA READ"))) then
      return
    end
    self.cnt = logicview.add(self.cnt, 1)
    if logicview.truth((self.extension > 0)) then
      _table.insert(logicview.idx(self.ext_sn, (self.extension - 1)), { ss, es })
      _table.insert(logicview.idx(self.ext_cache, (self.extension - 1)), data)
    else
      _table.insert(self.sn, { ss, es })
      _table.insert(self.cache, data)
    end
    if logicview.truth((function()
  local _v
  _v = (self.state == nil)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(self.state, "header")
  return _v
end)()) then
      if logicview.truth((self.cnt >= OFF_VENDOR)) then
        if logicview.truth(logicview.eq(logicview.slice(self.cache, (-8), nil, nil), EDID_HEADER)) then
          self.sn = logicview.slice(self.sn, (-8), nil, nil)
          self.cache = logicview.slice(self.cache, (-8), nil, nil)
          self.cnt = 8
          self.state = "edid"
          self:put(logicview.idx(logicview.idx(self.sn, 0), 0), es, self.out_ann, { ANN_SECTIONS, { "Header" } })
          self:put(logicview.idx(logicview.idx(self.sn, 0), 0), es, self.out_ann, { ANN_FIELDS, { "Header pattern" } })
        end
      end
    elseif logicview.truth(logicview.eq(self.state, "edid")) then
      if logicview.truth(logicview.eq(self.cnt, OFF_VERSION)) then
        self:decode_vid((-10))
        self:decode_pid((-8))
        self:decode_serial((-6))
        self:decode_mfrdate((-2))
        self:put(logicview.idx(logicview.idx(self.sn, OFF_VENDOR), 0), es, self.out_ann, { ANN_SECTIONS, { "Vendor/product" } })
      elseif logicview.truth(logicview.eq(self.cnt, OFF_BASIC)) then
        self:put(logicview.idx(logicview.idx(self.sn, OFF_VERSION), 0), es, self.out_ann, { ANN_SECTIONS, { "EDID Version" } })
        self:put(logicview.idx(logicview.idx(self.sn, OFF_VERSION), 0), logicview.idx(logicview.idx(self.sn, OFF_VERSION), 1), self.out_ann, { ANN_FIELDS, { logicview.pymod("Version %d", logicview.idx(self.cache, (-2))) } })
        self:put(logicview.idx(logicview.idx(self.sn, logicview.add(OFF_VERSION, 1)), 0), logicview.idx(logicview.idx(self.sn, logicview.add(OFF_VERSION, 1)), 1), self.out_ann, { ANN_FIELDS, { logicview.pymod("Revision %d", logicview.idx(self.cache, (-1))) } })
      elseif logicview.truth(logicview.eq(self.cnt, OFF_CHROM)) then
        self:put(logicview.idx(logicview.idx(self.sn, OFF_BASIC), 0), es, self.out_ann, { ANN_SECTIONS, { "Basic display" } })
        self:decode_basicdisplay((-5))
      elseif logicview.truth(logicview.eq(self.cnt, OFF_EST_TIMING)) then
        self:put(logicview.idx(logicview.idx(self.sn, OFF_CHROM), 0), es, self.out_ann, { ANN_SECTIONS, { "Color characteristics" } })
        self:decode_chromaticity((-10))
      elseif logicview.truth(logicview.eq(self.cnt, OFF_STD_TIMING)) then
        self:put(logicview.idx(logicview.idx(self.sn, OFF_EST_TIMING), 0), es, self.out_ann, { ANN_SECTIONS, { "Established timings" } })
        self:decode_est_timing((-3))
      elseif logicview.truth(logicview.eq(self.cnt, OFF_DET_TIMING)) then
        self:put(logicview.idx(logicview.idx(self.sn, OFF_STD_TIMING), 0), es, self.out_ann, { ANN_SECTIONS, { "Standard timings" } })
        self:decode_std_timing((self.cnt - 16))
      elseif logicview.truth(logicview.eq(self.cnt, OFF_NUM_EXT)) then
        self:decode_descriptors((-72))
      elseif logicview.truth(logicview.eq(self.cnt, OFF_CHECKSUM)) then
        self:put(ss, es, self.out_ann, { 0, { logicview.pymod("Extensions present: %d", logicview.idx(self.cache, (self.cnt - 1))) } })
      elseif logicview.truth(logicview.eq(self.cnt, logicview.add(OFF_CHECKSUM, 1))) then
        checksum = 0
        for _lv_i in logicview.range(128) do
          i = _lv_i
          checksum = logicview.add(checksum, logicview.idx(self.cache, i))
          ::continue_1::
        end
        if logicview.truth(logicview.eq(logicview.pymod(checksum, 256), 0)) then
          csstr = "OK"
        else
          csstr = "WRONG!"
        end
        self:put(ss, es, self.out_ann, { 0, { logicview.pymod("Checksum: %d (%s)", { logicview.idx(self.cache, (self.cnt - 1)), csstr }) } })
        self.state = "extensions"
      end
    elseif logicview.truth(logicview.eq(self.state, "extensions")) then
      cache = logicview.idx(self.ext_cache, (self.extension - 1))
      sn = logicview.idx(self.ext_sn, (self.extension - 1))
      v = logicview.idx(cache, (self.cnt - 1))
      if logicview.truth(logicview.eq(self.cnt, 1)) then
        if logicview.truth(logicview.eq(v, 2)) then
          self:put(ss, es, self.out_ann, { 1, { "Extensions Tag", "Tag" } })
        else
          self:put(ss, es, self.out_ann, { 1, { "Bad Tag" } })
        end
      elseif logicview.truth(logicview.eq(self.cnt, 2)) then
        self:put(ss, es, self.out_ann, { 1, { "Version" } })
        self:put(ss, es, self.out_ann, { 0, { _tostring(v) } })
      elseif logicview.truth(logicview.eq(self.cnt, 3)) then
        self:put(ss, es, self.out_ann, { 1, { "DTD offset" } })
        self:put(ss, es, self.out_ann, { 0, { _tostring(v) } })
      elseif logicview.truth(logicview.eq(self.cnt, 4)) then
        self:put(ss, es, self.out_ann, { 1, { "Format support | DTD count" } })
        support = logicview.pyformat("Underscan: {0}, {1} Audio, YCbCr: {2}", { (function() if logicview.truth((v & 128)) then return "yes" else return "no" end end)(), (function() if logicview.truth((v & 64)) then return "Basic" else return "No" end end)(), logicview.idx({ "None", "422", "444", "422+444" }, ((v & 48) >> 4)) }, logicview.dict({}))
        self:put(ss, es, self.out_ann, { 0, { logicview.pyformat("{0}, DTDs: {1}", { support, (v & 15) }, logicview.dict({})) } })
      elseif logicview.truth((self.cnt <= logicview.idx(cache, 2))) then
        if logicview.truth(logicview.eq(self.cnt, logicview.idx(cache, 2))) then
          self:put(logicview.idx(logicview.idx(sn, 4), 0), es, self.out_ann, { 1, { "Data block collection" } })
          self:decode_data_block_collection(logicview.slice(cache, 4, nil, nil), logicview.slice(sn, 4, nil, nil))
        end
      elseif logicview.truth(logicview.eq(logicview.pymod((self.cnt - logicview.idx(cache, 2)), 18), 0)) then
        n = ((self.cnt - logicview.idx(cache, 2)) / 18)
        if logicview.truth((n <= (logicview.idx(cache, 3) & 15))) then
          self:put(logicview.idx(logicview.idx(sn, (self.cnt - 18)), 0), es, self.out_ann, { 1, { "DTD" } })
          self:decode_descriptors((-18))
        end
      elseif logicview.truth(logicview.eq(self.cnt, 127)) then
        dtd_last = logicview.add(logicview.idx(cache, 2), logicview.mul((logicview.idx(cache, 3) & 15), 18))
        self:put(logicview.idx(logicview.idx(sn, dtd_last), 0), es, self.out_ann, { 1, { "Padding" } })
      elseif logicview.truth(logicview.eq(self.cnt, 128)) then
        checksum = logicview.pymod(logicview.sum(cache), 256)
        self:put(ss, es, self.out_ann, { 0, { logicview.pymod("Checksum: %d (%s)", { logicview.idx(cache, (self.cnt - 1)), (function() if logicview.truth(checksum) then return "Wrong" else return "OK" end end)() }) } })
      end
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
function _decoder.ann_field(self, start, end_, annotation)
  local sn
  annotation = (function() if logicview.truth(logicview.is_a(annotation, "list")) then return annotation else return { annotation } end end)()
  sn = (function() if logicview.truth(self.extension) then return logicview.idx(self.ext_sn, (self.extension - 1)) else return self.sn end end)()
  self:put(logicview.idx(logicview.idx(sn, start), 0), logicview.idx(logicview.idx(sn, end_), 1), self.out_ann, { ANN_FIELDS, annotation })
end
function _decoder.lookup_pnpid(self, pnpid)
  local pnpid_file, line
  pnpid_file = logicview.join(os.path, os.path:dirname(__file__))
  if logicview.truth(os.path:exists(pnpid_file)) then
    for _lv_item in logicview.iter(_error('file access is not available'):readlines()) do
      line = _lv_item
      if logicview.truth(logicview.eq(logicview.find(line, logicview.add(pnpid, ";")), 0)) then
        return logicview.strip(logicview.slice(line, 4, nil, nil))
      end
      ::continue_2::
    end
  end
  return ""
end
function _decoder.decode_vid(self, offset)
  local pnpid, vendor
  pnpid = _string.char(logicview.add(64, ((logicview.idx(self.cache, offset) & 124) >> 2)))
  pnpid = logicview.add(pnpid, _string.char(logicview.add(64, (((logicview.idx(self.cache, offset) & 3) << 3) | ((logicview.idx(self.cache, logicview.add(offset, 1)) & 224) >> 5)))))
  pnpid = logicview.add(pnpid, _string.char(logicview.add(64, (logicview.idx(self.cache, logicview.add(offset, 1)) & 31))))
  vendor = self:lookup_pnpid(pnpid)
  if logicview.truth(vendor) then
    pnpid = logicview.add(pnpid, logicview.pymod(" (%s)", vendor))
  end
  self:ann_field(offset, logicview.add(offset, 1), pnpid)
end
function _decoder.decode_pid(self, offset)
  local pidstr
  pidstr = logicview.pymod("Product 0x%.2x%.2x", { logicview.idx(self.cache, logicview.add(offset, 1)), logicview.idx(self.cache, offset) })
  self:ann_field(offset, logicview.add(offset, 1), pidstr)
end
function _decoder.decode_serial(self, offset)
  local serialnum, serialstr, is_alnum, i, serial
  serialnum = logicview.add(logicview.add(logicview.add((logicview.idx(self.cache, logicview.add(offset, 3)) << 24), (logicview.idx(self.cache, logicview.add(offset, 2)) << 16)), (logicview.idx(self.cache, logicview.add(offset, 1)) << 8)), logicview.idx(self.cache, offset))
  serialstr = ""
  is_alnum = true
  for _lv_i in logicview.range(4) do
    i = _lv_i
    if logicview.truth((not logicview.truth(_string.char(logicview.idx(self.cache, (logicview.add(offset, 3) - i))):isalnum()))) then
      is_alnum = false
      break
    end
    serialstr = logicview.add(serialstr, _string.char(logicview.idx(self.cache, (logicview.add(offset, 3) - i))))
    ::continue_3::
  end
  serial = (function() if logicview.truth(is_alnum) then return serialstr else return _tostring(serialnum) end end)()
  self:ann_field(offset, logicview.add(offset, 3), logicview.add("Serial ", serial))
end
function _decoder.decode_mfrdate(self, offset)
  local datestr
  datestr = ""
  if logicview.truth(logicview.idx(self.cache, offset)) then
    datestr = logicview.add(datestr, logicview.pymod("week %d, ", logicview.idx(self.cache, offset)))
  end
  datestr = logicview.add(datestr, _tostring(logicview.add(1990, logicview.idx(self.cache, logicview.add(offset, 1)))))
  if logicview.truth(datestr) then
    self:ann_field(offset, logicview.add(offset, 1), { logicview.add("Manufactured ", datestr), datestr })
  end
end
function _decoder.decode_basicdisplay(self, offset)
  local vid, sls, syncs, sizestr, gamma, fs, dpms, dt, dtstr, gft
  vid = logicview.idx(self.cache, offset)
  if logicview.truth((vid & 128)) then
    self:ann_field(offset, offset, "Video input: VESA DFP 1.")
  else
    sls = ((vid & 60) >> 5)
    self:ann_field(offset, offset, logicview.pymod("Signal level standard: %.2x", sls))
    if logicview.truth((vid & 16)) then
      self:ann_field(offset, offset, "Blank-to-black setup expected")
    end
    syncs = ""
    if logicview.truth((vid & 8)) then
      syncs = logicview.add(syncs, "separate syncs, ")
    end
    if logicview.truth((vid & 4)) then
      syncs = logicview.add(syncs, "composite syncs, ")
    end
    if logicview.truth((vid & 2)) then
      syncs = logicview.add(syncs, "sync on green, ")
    end
    if logicview.truth((vid & 1)) then
      syncs = logicview.add(syncs, "Vsync serration required, ")
    end
    if logicview.truth(syncs) then
      self:ann_field(offset, offset, logicview.pymod("Supported syncs: %s", logicview.slice(syncs, nil, (-2), nil)))
    end
  end
  if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(self.cache, logicview.add(offset, 1)), 0))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(self.cache, logicview.add(offset, 2)), 0))
  return _v
end)()) then
    sizestr = logicview.pymod("%dx%dcm", { logicview.idx(self.cache, logicview.add(offset, 1)), logicview.idx(self.cache, logicview.add(offset, 2)) })
    self:ann_field(logicview.add(offset, 1), logicview.add(offset, 2), logicview.add("Physical size: ", sizestr))
  end
  if logicview.truth((not logicview.eq(logicview.idx(self.cache, logicview.add(offset, 3)), 255))) then
    gamma = (logicview.add(logicview.idx(self.cache, logicview.add(offset, 3)), 100) / 100)
    self:ann_field(logicview.add(offset, 3), logicview.add(offset, 3), logicview.pymod("Gamma: %1.2f", gamma))
  end
  fs = logicview.idx(self.cache, logicview.add(offset, 4))
  dpms = ""
  if logicview.truth((fs & 128)) then
    dpms = logicview.add(dpms, "standby, ")
  end
  if logicview.truth((fs & 64)) then
    dpms = logicview.add(dpms, "suspend, ")
  end
  if logicview.truth((fs & 32)) then
    dpms = logicview.add(dpms, "active off, ")
  end
  if logicview.truth(dpms) then
    self:ann_field(logicview.add(offset, 4), logicview.add(offset, 4), logicview.pymod("DPMS support: %s", logicview.slice(dpms, nil, (-2), nil)))
  end
  dt = ((fs & 24) >> 3)
  dtstr = ""
  if logicview.truth(logicview.eq(dt, 0)) then
    dtstr = "Monochrome"
  elseif logicview.truth(logicview.eq(dt, 1)) then
    dtstr = "RGB color"
  elseif logicview.truth(logicview.eq(dt, 2)) then
    dtstr = "non-RGB multicolor"
  end
  if logicview.truth(dtstr) then
    self:ann_field(logicview.add(offset, 4), logicview.add(offset, 4), logicview.pymod("Display type: %s", dtstr))
  end
  if logicview.truth((fs & 4)) then
    self:ann_field(logicview.add(offset, 4), logicview.add(offset, 4), "Color space: standard sRGB")
  end
  self.have_preferred_timing = logicview.eq((fs & 2), 2)
  if logicview.truth((fs & 1)) then
    gft = ""
  else
    gft = "not "
  end
  self:ann_field(logicview.add(offset, 4), logicview.add(offset, 4), logicview.pymod("Generalized timing formula: %ssupported", gft))
end
function _decoder.convert_color(self, value)
  local outval, i
  outval = 0.0
  for _lv_i in logicview.range(10) do
    i = _lv_i
    if logicview.truth((value & 1)) then
      outval = logicview.add(outval, (2 ^ (-(10 - i))))
    end
    value = (value >> 1)
    ::continue_4::
  end
  return outval
end
function _decoder.decode_chromaticity(self, offset)
  local redx, redy, greenx, greeny, bluex, bluey, whitex, whitey
  redx = logicview.add((logicview.idx(self.cache, logicview.add(offset, 2)) << 2), ((logicview.idx(self.cache, offset) & 192) >> 6))
  redy = logicview.add((logicview.idx(self.cache, logicview.add(offset, 3)) << 2), ((logicview.idx(self.cache, offset) & 48) >> 4))
  self:ann_field(offset, logicview.add(offset, 9), logicview.pymod("Chromacity red: X %1.3f, Y %1.3f", { self:convert_color(redx), self:convert_color(redy) }))
  greenx = logicview.add((logicview.idx(self.cache, logicview.add(offset, 4)) << 2), ((logicview.idx(self.cache, offset) & 12) >> 6))
  greeny = logicview.add((logicview.idx(self.cache, logicview.add(offset, 5)) << 2), ((logicview.idx(self.cache, offset) & 3) >> 4))
  self:ann_field(offset, logicview.add(offset, 9), logicview.pymod("Chromacity green: X %1.3f, Y %1.3f", { self:convert_color(greenx), self:convert_color(greeny) }))
  bluex = logicview.add((logicview.idx(self.cache, logicview.add(offset, 6)) << 2), ((logicview.idx(self.cache, logicview.add(offset, 1)) & 192) >> 6))
  bluey = logicview.add((logicview.idx(self.cache, logicview.add(offset, 7)) << 2), ((logicview.idx(self.cache, logicview.add(offset, 1)) & 48) >> 4))
  self:ann_field(offset, logicview.add(offset, 9), logicview.pymod("Chromacity blue: X %1.3f, Y %1.3f", { self:convert_color(bluex), self:convert_color(bluey) }))
  whitex = logicview.add((logicview.idx(self.cache, logicview.add(offset, 8)) << 2), ((logicview.idx(self.cache, logicview.add(offset, 1)) & 12) >> 6))
  whitey = logicview.add((logicview.idx(self.cache, logicview.add(offset, 9)) << 2), ((logicview.idx(self.cache, logicview.add(offset, 1)) & 3) >> 4))
  self:ann_field(offset, logicview.add(offset, 9), logicview.pymod("Chromacity white: X %1.3f, Y %1.3f", { self:convert_color(whitex), self:convert_color(whitey) }))
end
function _decoder.decode_est_timing(self, offset)
  local bitmap, modestr, i
  bitmap = logicview.add(logicview.add((logicview.idx(self.cache, offset) << 9), (logicview.idx(self.cache, logicview.add(offset, 1)) << 1)), ((logicview.idx(self.cache, logicview.add(offset, 2)) & 128) >> 7))
  modestr = ""
  for _lv_i in logicview.range(17) do
    i = _lv_i
    if logicview.truth((bitmap & (1 << (16 - i)))) then
      modestr = logicview.add(modestr, logicview.add(logicview.idx(est_modes, i), ", "))
    end
    ::continue_5::
  end
  if logicview.truth(modestr) then
    self:ann_field(offset, logicview.add(offset, 2), logicview.pymod("Supported established modes: %s", logicview.slice(modestr, nil, (-2), nil)))
  end
end
function _decoder.decode_std_timing(self, offset)
  local modestr, i, x, ratio, ratio_x, ratio_y, y, refresh
  modestr = ""
  for _lv_i in logicview.range(0, 16, 2) do
    i = _lv_i
    if logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(self.cache, logicview.add(offset, i)), 1)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(self.cache, logicview.add(logicview.add(offset, i), 1)), 1)
  return _v
end)()) then
      goto continue_6
    end
    x = logicview.mul(logicview.add(logicview.idx(self.cache, logicview.add(offset, i)), 31), 8)
    ratio = ((logicview.idx(self.cache, logicview.add(logicview.add(offset, i), 1)) & 192) >> 6)
    do
      local _lv_seq = logicview.idx(xy_ratio, ratio)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ratio_x = logicview.idx(_lv_seq, 0)
      ratio_y = logicview.idx(_lv_seq, 1)
    end
    y = logicview.mul((x / ratio_x), ratio_y)
    refresh = logicview.add((logicview.idx(self.cache, logicview.add(logicview.add(offset, i), 1)) & 63), 60)
    modestr = logicview.add(modestr, logicview.pymod("%dx%d@%dHz, ", { x, y, refresh }))
    ::continue_6::
  end
  if logicview.truth(modestr) then
    self:ann_field(offset, logicview.add(offset, 15), logicview.pymod("Supported standard modes: %s", logicview.slice(modestr, nil, (-2), nil)))
  end
end
function _decoder.decode_detailed_timing(self, cache, sn, offset, is_first)
  local section, pixclock, horiz_active, horiz_blank, vert_active, vert_blank, horiz_sync_off, horiz_sync_pw, vert_sync_off, vert_sync_pw, syncs, horiz_size, vert_size, horiz_border, vert_border, features, stereo, sync, sync2, posneg
  if logicview.truth((function()
  local _v
  _v = is_first
  if not logicview.truth(_v) then return _v end
  _v = self.have_preferred_timing
  return _v
end)()) then
    section = "Preferred"
  else
    section = "Detailed"
  end
  section = logicview.add(section, " timing descriptor")
  self:put(logicview.idx(logicview.idx(sn, 0), 0), logicview.idx(logicview.idx(sn, 17), 1), self.out_ann, { ANN_SECTIONS, { section } })
  pixclock = ((_tonumber(logicview.add((logicview.idx(cache, 1) << 8), logicview.idx(cache, 0))) or 0) / 100)
  self:ann_field(offset, logicview.add(offset, 1), logicview.pymod("Pixel clock: %.2f MHz", pixclock))
  horiz_active = logicview.add(((logicview.idx(cache, 4) & 240) << 4), logicview.idx(cache, 2))
  horiz_blank = logicview.add(((logicview.idx(cache, 4) & 15) << 8), logicview.idx(cache, 3))
  self:ann_field(logicview.add(offset, 2), logicview.add(offset, 4), logicview.pymod("Horizontal active: %d, blanking: %d", { horiz_active, horiz_blank }))
  vert_active = logicview.add(((logicview.idx(cache, 7) & 240) << 4), logicview.idx(cache, 5))
  vert_blank = logicview.add(((logicview.idx(cache, 7) & 15) << 8), logicview.idx(cache, 6))
  self:ann_field(logicview.add(offset, 5), logicview.add(offset, 7), logicview.pymod("Vertical active: %d, blanking: %d", { vert_active, vert_blank }))
  horiz_sync_off = logicview.add(((logicview.idx(cache, 11) & 192) << 2), logicview.idx(cache, 8))
  horiz_sync_pw = logicview.add(((logicview.idx(cache, 11) & 48) << 4), logicview.idx(cache, 9))
  vert_sync_off = logicview.add(((logicview.idx(cache, 11) & 12) << 2), ((logicview.idx(cache, 10) & 240) >> 4))
  vert_sync_pw = logicview.add(((logicview.idx(cache, 11) & 3) << 4), (logicview.idx(cache, 10) & 15))
  syncs = { horiz_sync_off, horiz_sync_pw, vert_sync_off, vert_sync_pw }
  self:ann_field(logicview.add(offset, 8), logicview.add(offset, 11), { logicview.pymod("Horizontal sync offset: %d, pulse width: %d, Vertical sync offset: %d, pulse width: %d", syncs), logicview.pymod("HSync off: %d, pw: %d, VSync off: %d, pw: %d", syncs) })
  horiz_size = logicview.add(((logicview.idx(cache, 14) & 240) << 4), logicview.idx(cache, 12))
  vert_size = logicview.add(((logicview.idx(cache, 14) & 15) << 8), logicview.idx(cache, 13))
  self:ann_field(logicview.add(offset, 12), logicview.add(offset, 14), logicview.pymod("Physical size: %dx%dmm", { horiz_size, vert_size }))
  horiz_border = logicview.idx(cache, 15)
  self:ann_field(logicview.add(offset, 15), logicview.add(offset, 15), logicview.pymod("Horizontal border: %d pixels", horiz_border))
  vert_border = logicview.idx(cache, 16)
  self:ann_field(logicview.add(offset, 16), logicview.add(offset, 16), logicview.pymod("Vertical border: %d lines", vert_border))
  features = "Flags: "
  if logicview.truth((logicview.idx(cache, 17) & 128)) then
    features = logicview.add(features, "interlaced, ")
  end
  stereo = ((logicview.idx(cache, 17) & 96) >> 5)
  if logicview.truth(stereo) then
    if logicview.truth((logicview.idx(cache, 17) & 1)) then
      features = logicview.add(features, "2-way interleaved stereo (")
      features = logicview.add(features, logicview.idx({ "right image on even lines", "left image on even lines", "side-by-side" }, (stereo - 1)))
      features = logicview.add(features, "), ")
    else
      features = logicview.add(features, "field sequential stereo (")
      features = logicview.add(features, logicview.idx({ "right image on sync=1", "left image on sync=1", "4-way interleaved" }, (stereo - 1)))
      features = logicview.add(features, "), ")
    end
  end
  sync = ((logicview.idx(cache, 17) & 24) >> 3)
  sync2 = ((logicview.idx(cache, 17) & 6) >> 1)
  posneg = { "negative", "positive" }
  features = logicview.add(features, "sync type ")
  if logicview.truth(logicview.eq(sync, 0)) then
    features = logicview.add(features, "analog composite (serrate on RGB)")
  elseif logicview.truth(logicview.eq(sync, 1)) then
    features = logicview.add(features, "bipolar analog composite (serrate on RGB)")
  elseif logicview.truth(logicview.eq(sync, 2)) then
    features = logicview.add(features, logicview.add(logicview.add("digital composite (serrate on composite polarity ", logicview.idx(posneg, (sync2 & 1))), ")"))
  elseif logicview.truth(logicview.eq(sync, 3)) then
    features = logicview.add(features, "digital separate (")
    features = logicview.add(features, logicview.add("Vsync polarity ", logicview.idx(posneg, ((sync2 & 2) >> 1))))
    features = logicview.add(features, logicview.add(", Hsync polarity ", logicview.idx(posneg, (sync2 & 1))))
    features = logicview.add(features, ")")
  end
  features = logicview.add(features, ", ")
  self:ann_field(logicview.add(offset, 17), logicview.add(offset, 17), logicview.slice(features, nil, (-2), nil))
end
function _decoder.decode_descriptor(self, cache, offset)
  local tag, sn, text
  tag = logicview.idx(cache, 3)
  self:ann_field(offset, logicview.add(offset, 1), "Flag")
  self:ann_field(logicview.add(offset, 2), logicview.add(offset, 2), "Flag (reserved)")
  self:ann_field(logicview.add(offset, 3), logicview.add(offset, 3), logicview.pyformat("Tag: {0:X}", { tag }, logicview.dict({})))
  self:ann_field(logicview.add(offset, 4), logicview.add(offset, 4), "Flag")
  sn = (function() if logicview.truth(self.extension) then return logicview.idx(self.ext_sn, (self.extension - 1)) else return self.sn end end)()
  if logicview.truth(logicview.eq(tag, 255)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Serial number" } })
    text = logicview.bytes(logicview.slice(logicview.slice(cache, 5, nil, nil), nil, 13, nil))
    self:ann_field(logicview.add(offset, 5), logicview.add(offset, 17), logicview.strip(text))
  elseif logicview.truth(logicview.eq(tag, 254)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Text" } })
    text = logicview.bytes(logicview.slice(logicview.slice(cache, 5, nil, nil), nil, 13, nil))
    self:ann_field(logicview.add(offset, 5), logicview.add(offset, 17), logicview.strip(text))
  elseif logicview.truth(logicview.eq(tag, 252)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Monitor name" } })
    text = logicview.bytes(logicview.slice(logicview.slice(cache, 5, nil, nil), nil, 13, nil))
    self:ann_field(logicview.add(offset, 5), logicview.add(offset, 17), logicview.strip(text))
  elseif logicview.truth(logicview.eq(tag, 253)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Monitor range limits" } })
    self:ann_field(logicview.add(offset, 5), logicview.add(offset, 5), { logicview.pyformat("Minimum vertical rate: {0}Hz", { logicview.idx(cache, 5) }, logicview.dict({})), logicview.pyformat("VSync >= {0}Hz", { logicview.idx(cache, 5) }, logicview.dict({})) })
    self:ann_field(logicview.add(offset, 6), logicview.add(offset, 6), { logicview.pyformat("Maximum vertical rate: {0}Hz", { logicview.idx(cache, 6) }, logicview.dict({})), logicview.pyformat("VSync <= {0}Hz", { logicview.idx(cache, 6) }, logicview.dict({})) })
    self:ann_field(logicview.add(offset, 7), logicview.add(offset, 7), { logicview.pyformat("Minimum horizontal rate: {0}kHz", { logicview.idx(cache, 7) }, logicview.dict({})), logicview.pyformat("HSync >= {0}kHz", { logicview.idx(cache, 7) }, logicview.dict({})) })
    self:ann_field(logicview.add(offset, 8), logicview.add(offset, 8), { logicview.pyformat("Maximum horizontal rate: {0}kHz", { logicview.idx(cache, 8) }, logicview.dict({})), logicview.pyformat("HSync <= {0}kHz", { logicview.idx(cache, 8) }, logicview.dict({})) })
    self:ann_field(logicview.add(offset, 9), logicview.add(offset, 9), { logicview.pyformat("Maximum pixel clock: {0}MHz", { logicview.mul(logicview.idx(cache, 9), 10) }, logicview.dict({})), logicview.pyformat("PixClk <= {0}MHz", { logicview.mul(logicview.idx(cache, 9), 10) }, logicview.dict({})) })
    if logicview.truth(logicview.eq(logicview.idx(cache, 10), 2)) then
      self:ann_field(logicview.add(offset, 10), logicview.add(offset, 10), { "Secondary timing formula supported", "2nd GTF: yes" })
      self:ann_field(logicview.add(offset, 11), logicview.add(offset, 17), { "GTF" })
    else
      self:ann_field(logicview.add(offset, 10), logicview.add(offset, 10), { "Secondary timing formula unsupported", "2nd GTF: no" })
      self:ann_field(logicview.add(offset, 11), logicview.add(offset, 17), { "Padding" })
    end
  elseif logicview.truth(logicview.eq(tag, 251)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Additional color point data" } })
  elseif logicview.truth(logicview.eq(tag, 250)) then
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Additional standard timing definitions" } })
  else
    self:put(logicview.idx(logicview.idx(sn, offset), 0), logicview.idx(logicview.idx(sn, logicview.add(offset, 17)), 1), self.out_ann, { ANN_SECTIONS, { "Unknown descriptor" } })
  end
end
function _decoder.decode_descriptors(self, offset)
  local cache, sn, i
  cache = (function() if logicview.truth(self.extension) then return logicview.idx(self.ext_cache, (self.extension - 1)) else return self.cache end end)()
  sn = (function() if logicview.truth(self.extension) then return logicview.idx(self.ext_sn, (self.extension - 1)) else return self.sn end end)()
  for _lv_i in logicview.range(offset, 0, 18) do
    i = _lv_i
    if logicview.truth((function()
  local _v
  _v = (not logicview.eq(logicview.idx(cache, i), 0))
  if logicview.truth(_v) then return _v end
  _v = (not logicview.eq(logicview.idx(cache, logicview.add(i, 1)), 0))
  return _v
end)()) then
      self:decode_detailed_timing(logicview.slice(cache, i, nil, nil), logicview.slice(sn, i, nil, nil), i, logicview.eq(i, offset))
    elseif logicview.truth((function()
  local _v
  _v = logicview.eq(logicview.idx(cache, logicview.add(i, 2)), 0)
  if logicview.truth(_v) then return _v end
  _v = logicview.eq(logicview.idx(cache, logicview.add(i, 4)), 0)
  return _v
end)()) then
      self:decode_descriptor(logicview.slice(cache, i, nil, nil), i)
    end
    ::continue_7::
  end
end
function _decoder.decode_data_block(self, tag, cache, sn)
  local codes, ext_codes, code, ext_len, aformats, rates, aformat, sup_rates, data, ouis, oui, speakers, sup_speakers, ext_code
  codes = logicview.dict({ [0] = { "0: Reserved" }, [1] = { "1: Audio Data Block", "Audio" }, [2] = { "2: Video Data Block", "Video" }, [3] = { "3: Vendor Specific Data Block", "VSDB" }, [4] = { "4: Speacker Allocation Data Block", "SADB" }, [5] = { "5: VESA DTC Data Block", "DTC" }, [6] = { "6: Reserved" }, [7] = { "7: Extended", "Ext" } })
  ext_codes = logicview.dict({ [0] = { "0: Video Capability Data Block", "VCDB" }, [1] = { "1: Vendor Specific Video Data Block", "VSVDB" }, [17] = { "17: Vendor Specific Audio Data Block", "VSADB" } })
  if logicview.truth((tag < 7)) then
    code = logicview.idx(codes, tag)
    ext_len = 0
    if logicview.truth(logicview.eq(tag, 1)) then
      aformats = logicview.dict({ [1] = "1 (LPCM)" })
      rates = { "192", "176", "96", "88", "48", "44", "32" }
      aformat = (logicview.idx(cache, 1) >> 3)
      sup_rates = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(0, 8) do
    i = _lv_i
    if logicview.truth(((1 << i) & logicview.idx(cache, 2))) then
    _lv_out[#_lv_out + 1] = i
  end
    end
  return _lv_out
end)()
      data = logicview.pyformat("Format: {0} Channels: {1}", { logicview.dget(aformats, aformat, aformat), logicview.add((logicview.idx(cache, 1) & 7), 1) }, logicview.dict({}))
      data = logicview.add(data, logicview.add(" Rates: ", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(sup_rates) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(rates, (6 - i))
  end
  return _lv_out
end)())))
      data = logicview.add(data, logicview.pyformat(" Extra: [{0:02X}]", { logicview.idx(cache, 3) }, logicview.dict({})))
    elseif logicview.truth(logicview.eq(tag, 2)) then
      data = "VIC: "
      data = logicview.add(data, logicview.join(", ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(cache, 1, nil, nil)) do
    v = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{0}{1}", { (v & 127), logicview.idx({ "", " (Native)" }, (v >> 7)) }, logicview.dict({}))
  end
  return _lv_out
end)()))
    elseif logicview.truth(logicview.eq(tag, 3)) then
      ouis = logicview.dict({ ["\x00\x0c\x03"] = "HDMI Licensing, LLC" })
      oui = logicview.bytes(logicview.slice(cache, 3, 0, (-1)))
      ouis = logicview.dget(ouis, oui, nil)
      data = logicview.add("OUI: ", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(oui) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{0:02X}", { x }, logicview.dict({}))
  end
  return _lv_out
end)()))
      data = logicview.add(data, (function() if logicview.truth(ouis) then return logicview.pyformat(" ({0})", { ouis }, logicview.dict({})) else return "" end end)())
      data = logicview.add(data, logicview.pyformat(", PhyAddr: {0}.{1}.{2}.{3}", { (logicview.idx(cache, 4) >> 4), (logicview.idx(cache, 4) & 15), (logicview.idx(cache, 5) >> 4), (logicview.idx(cache, 5) & 15) }, logicview.dict({})))
      data = logicview.add(data, logicview.add(logicview.add(", [", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(cache, 6, nil, nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{0:02X}", { x }, logicview.dict({}))
  end
  return _lv_out
end)())), "]"))
    elseif logicview.truth(logicview.eq(tag, 4)) then
      speakers = { "FL/FR", "LFE", "FC", "RL/RR", "RC", "FLC/FRC", "RLC/RRC", "FLW/FRW", "FLH/FRH", "TC", "FCH" }
      sup_speakers = logicview.add(logicview.idx(cache, 1), (logicview.idx(cache, 2) << 8))
      sup_speakers = (function()
  local _lv_out = {}
  for _lv_i in logicview.range(0, 8) do
    i = _lv_i
    if logicview.truth(((1 << i) & sup_speakers)) then
    _lv_out[#_lv_out + 1] = i
  end
    end
  return _lv_out
end)()
      data = logicview.add("Speakers: ", logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(sup_speakers) do
    i = _lv_item
    _lv_out[#_lv_out + 1] = logicview.idx(speakers, i)
  end
  return _lv_out
end)()))
    else
      data = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(cache, 1, nil, nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{0:02X}", { x }, logicview.dict({}))
  end
  return _lv_out
end)())
    end
  else
    ext_len = 1
    ext_code = logicview.dget(ext_codes, logicview.idx(cache, 1), { "Unknown", "?" })
    code = (function() local _t = {}; for _item in logicview.iter({ logicview.idx(codes, 7), { ", ", ": " }, ext_code }) do end; local _n = 0; for _i = 1, math.huge do local _row = {}; local _stop = false; for _k = 1, 3 do local _src = ({ logicview.idx(codes, 7), { ", ", ": " }, ext_code })[_k]; local _v = logicview.idx(_src, _i - 1); if _v == nil then _stop = true; break end; _row[_k] = _v end; if _stop then break end; _t[#_t + 1] = _row end; return _t end)()
    code = (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(code) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.join("", x)
  end
  return _lv_out
end)()
    data = logicview.join(" ", (function()
  local _lv_out = {}
  for _lv_item in logicview.iter(logicview.slice(cache, 2, nil, nil)) do
    x = _lv_item
    _lv_out[#_lv_out + 1] = logicview.pyformat("{0:02X}", { x }, logicview.dict({}))
  end
  return _lv_out
end)())
  end
  self:put(logicview.idx(logicview.idx(sn, 0), 0), logicview.idx(logicview.idx(sn, logicview.add(0, ext_len)), 1), self.out_ann, { ANN_FIELDS, code })
  self:put(logicview.idx(logicview.idx(sn, logicview.add(1, ext_len)), 0), logicview.idx(logicview.idx(sn, (logicview.len(cache) - 1)), 1), self.out_ann, { ANN_FIELDS, { data } })
end
function _decoder.decode_data_block_collection(self, cache, sn)
  local offset, length, tag
  offset = 0
  while logicview.truth((offset < logicview.len(cache))) do
    length = (logicview.add(1, logicview.idx(cache, offset)) & 31)
    tag = (logicview.idx(cache, offset) >> 5)
    self:decode_data_block(tag, logicview.slice(cache, offset, logicview.add(offset, length), nil), logicview.slice(sn, offset, nil, nil))
    offset = logicview.add(offset, length)
    ::continue_8::
  end
end

return _decoder
