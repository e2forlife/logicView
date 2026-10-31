-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv3+
-- Copyright (C) 2019 Vesa-Pekka Palmu <vpalmu@depili.fi>

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
local ceil, SrdIntEnum, L, RX, TX, Ann, cmd_annotation_classes, Decoder, OrderedDict, cmds, cmds_with_high_bytes
local _decoder

ceil = _math.ceil
collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
OrderedDict = collections.OrderedDict
cmds = OrderedDict({ { 160, { "PAGE", "Jump to page" } }, { 208, { "GBV", "Get byte variable" } }, { 209, { "GWV", "Get word variable" } }, { 210, { "GSV", "Get string variable" } }, { 211, { "GLV", "Get label variable" } }, { 212, { "GRPC", "Get RPC buffer" } }, { 213, { "SBV", "Set byte variable" } }, { 214, { "SWV", "Set word variable" } }, { 215, { "SSV", "Set string variable" } }, { 216, { "RPC", "Invoke RPC" } }, { 217, { "LINE", "Draw line" } }, { 218, { "RECT", "Draw rectangle" } }, { 219, { "FRECT", "Draw filled rectangle" } }, { 220, { "PIXEL", "Draw pixel" } }, { 221, { "GBVA", "Get byte variable array" } }, { 222, { "GWVA", "Get word variable array" } }, { 223, { "SBVA", "Set byte variable array" } }, { 224, { "GBVR", "Get byte variable reply" } }, { 225, { "GWVR", "Get word variable reply" } }, { 226, { "GSVR", "Get string variable reply" } }, { 227, { "GLVR", "Get label variable reply" } }, { 228, { "GRPCR", "Get RPC buffer reply" } }, { 229, { "SBVR", "Set byte variable reply" } }, { 230, { "SWVR", "Set word variable reply" } }, { 231, { "SSVR", "Set string variable reply" } }, { 232, { "RPCR", "Invoke RPC reply" } }, { 233, { "LINER", "Draw line reply" } }, { 234, { "RECTR", "Draw rectangle" } }, { 235, { "FRECTR", "Draw filled rectangle reply" } }, { 236, { "PIXELR", "Draw pixel reply" } }, { 237, { "GBVAR", "Get byte variable array reply" } }, { 238, { "GWVAR", "Get word variable array reply" } }, { 239, { "SBVAR", "Set byte variable array reply" } }, { 240, { "ACK", "Acknowledgment" } }, { 241, { "NACK", "Negative acknowledgment" } }, { 242, { "SWVA", "Set word variable array" } }, { 243, { "SWVAR", "Set word variable array reply" } }, { 244, { "GCV", "Get color variable" } }, { 245, { "GCVR", "Get color variable reply" } }, { 246, { "SCV", "Set color variable" } }, { 247, { "SCVR", "Set color variable reply" } } })
cmds_with_high_bytes = { 160, 215, 231, 226, 227 }

L = logicview.len(cmds)
RX = 0
TX = 1
Ann = logicview.int_enum(logicview.add((function()
  local _lv_out = {}
  for _, _lv_v in _pairs(cmds) do
    c = _lv_v
    _lv_out[#_lv_out + 1] = logicview.idx(c, 0)
  end
  return _lv_out
end)(), { "BIT", "FIELD", "WARN" }))
cmd_annotation_classes = function()
  return logicview.copy((function()
  local _lv_out = {}
  for _, _lv_v in _pairs(cmds) do
    cmd = _lv_v
    _lv_out[#_lv_out + 1] = logicview.copy({ _string.lower(logicview.idx(cmd, 0)), logicview.idx(cmd, 1) })
  end
  return _lv_out
end)())
end
_decoder = {
  api_version = 3,
  id = "amulet_ascii",
  name = "Amulet ASCII",
  longname = "Amulet LCD ASCII",
  desc = "Amulet Technologies LCD controller ASCII protocol.",
  license = "gplv3+",
  inputs = { "uart" },
  outputs = {  },
  tags = { "Display" },
  channels = {  },
  optional_channels = {  },
  options = { logicview.dict({ id = "ms_chan", desc = "Master -> slave channel", default = "RX", values = { "RX", "TX" } }), logicview.dict({ id = "sm_chan", desc = "Slave -> master channel", default = "TX", values = { "RX", "TX" } }) },
  annotations = { { "page", "Jump to page" }, { "gbv", "Get byte variable" }, { "gwv", "Get word variable" }, { "gsv", "Get string variable" }, { "glv", "Get label variable" }, { "grpc", "Get RPC buffer" }, { "sbv", "Set byte variable" }, { "swv", "Set word variable" }, { "ssv", "Set string variable" }, { "rpc", "Invoke RPC" }, { "line", "Draw line" }, { "rect", "Draw rectangle" }, { "frect", "Draw filled rectangle" }, { "pixel", "Draw pixel" }, { "gbva", "Get byte variable array" }, { "gwva", "Get word variable array" }, { "sbva", "Set byte variable array" }, { "gbvr", "Get byte variable reply" }, { "gwvr", "Get word variable reply" }, { "gsvr", "Get string variable reply" }, { "glvr", "Get label variable reply" }, { "grpcr", "Get RPC buffer reply" }, { "sbvr", "Set byte variable reply" }, { "swvr", "Set word variable reply" }, { "ssvr", "Set string variable reply" }, { "rpcr", "Invoke RPC reply" }, { "liner", "Draw line reply" }, { "rectr", "Draw rectangle" }, { "frectr", "Draw filled rectangle reply" }, { "pixelr", "Draw pixel reply" }, { "gbvar", "Get byte variable array reply" }, { "gwvar", "Get word variable array reply" }, { "sbvar", "Set byte variable array reply" }, { "ack", "Acknowledgment" }, { "nack", "Negative acknowledgment" }, { "swva", "Set word variable array" }, { "swvar", "Set word variable array reply" }, { "gcv", "Get color variable" }, { "gcvr", "Get color variable reply" }, { "scv", "Set color variable" }, { "scvr", "Set color variable reply" }, { "bit", "Bit" }, { "field", "Field" }, { "warning", "Warning" } },
  annotation_rows = { { "bits", "Bits", { 41 } }, { "fields", "Fields", { 42 } }, { "commands", "Commands", { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40 } }, { "warnings", "Warnings", { 43 } } },
  binary = {  }
}
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  local get_handler
  self.state = nil
  self.cmdstate = nil
  get_handler = function(cmd)
    local s
    s = logicview.pymod("handle_%s", logicview.replace(_string.lower(logicview.idx(logicview.idx(cmds, cmd), 0)), "/", "_", nil))
    return (function() local _v = self[s]; if _v == nil then return nil end; return _v end)()
  end
  self.cmd_handlers = logicview.dict((function()
  local _lv_out = {}
  for _lv_k, _ in _pairs(cmds) do
    cmd = _lv_k
    _lv_out[#_lv_out + 1] = { cmd, get_handler(cmd) }
  end
  return _lv_out
end)())
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss, self.es, self.out_ann, data)
end
function _decoder.putf(self, data)
  self:put(self.ss_field, self.es_field, self.out_ann, data)
end
function _decoder.putc(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.cmd_ann_list(self)
  local x, s
  do
    local _lv_a0, _lv_a1 = logicview.idx(logicview.idx(cmds, self.state), 0), logicview.idx(logicview.idx(cmds, self.state), 1)
    x = _lv_a0
    s = _lv_a1
  end
  return { logicview.pymod("Command: %s (%s)", { s, x }), logicview.pymod("Command: %s", s), logicview.pymod("Cmd: %s", s), logicview.pymod("Cmd: %s", x), x }
end
function _decoder.emit_cmd_byte(self)
  self.ss_cmd = self.ss
  self:putx({ Ann.FIELD, self:cmd_ann_list() })
end
function _decoder.emit_addr_bytes(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.ss_field = self.ss
    self.addr = _string.char(pdata)
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("Addr h 0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.es_field = self.es
    self.addr = logicview.add(self.addr, _string.char(pdata))
    self.addr = logicview.tointeger(self.addr, 16)
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("Addr l 0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
  end
end
function _decoder.emit_cmd_end(self, data)
  self.es_cmd = self.es
  self:putc(data)
  self.state = nil
end
function _decoder.handle_read(self, data)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self:emit_cmd_byte()
    self.addr = 0
  elseif logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self:emit_addr_bytes(pdata)
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self:emit_addr_bytes(pdata)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_set_common(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    self.addr = 0
  end
  self:emit_addr_bytes(pdata)
end
function _decoder.emit_not_implemented(self, data)
  self.es_cmd = self.es
  self:putc({ Ann.WARN, { "Command not decoded", "Not decoded" } })
  self:emit_cmd_end(data)
end
function _decoder.handle_string(self, pdata, ann_class)
  self:handle_set_common(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.ss_field = self.ss
    self.value = ""
  end
  if logicview.truth(logicview.eq(pdata, 0)) then
    self.es_field = self.es
    self:putx({ Ann.BIT, { "NULL" } })
    self:putf({ Ann.FIELD, { logicview.pymod("Value: %s", self.value), logicview.pymod("Val: %s", self.value), logicview.pymod("%s", self.value) } })
    self:emit_cmd_end({ ann_class, self:cmd_ann_list() })
    return
  end
  if logicview.truth((self.cmdstate > 3)) then
    self.value = logicview.add(self.value, _string.char(pdata))
    self:putx({ Ann.BIT, { logicview.pymod("%c", pdata) } })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_page(self, pdata)
  local page
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    if logicview.truth(logicview.eq(pdata, 2)) then
      self.ss_field = self.ss_cmd
      self.es_field = self.es
      self:putf({ Ann.FIELD, self:cmd_ann_list() })
      self.checksum = logicview.add(160, 2)
    else
      self:putx({ Ann.WARN, { "Illegal second byte for page change", "Illegal byte" } })
      self.state = nil
    end
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.ss_field = self.ss
    self.checksum = logicview.add(self.checksum, pdata)
    logicview.setidx(self.page, 0, pdata)
  elseif logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.checksum = logicview.add(self.checksum, pdata)
    logicview.setidx(self.page, 1, pdata)
    self.es_field = self.es
    if logicview.truth((logicview.eq(logicview.idx(self.page, 0), logicview.idx(self.page, 1)) and logicview.eq(logicview.idx(self.page, 1), 255))) then
      self:putf(Ann.WARN, { "Soft reset", "Reset" })
    else
      page = logicview.add(_string.char(logicview.idx(self.page, 0)), _string.char(logicview.idx(self.page, 1)))
      self:putf(Ann.FIELD, { logicview.pymod("Page index: 0x%s", page), logicview.pymod("Page: 0x%s", page), logicview.pymod("0x%s", page) })
    end
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.checksum = logicview.add(self.checksum, pdata)
    if logicview.truth((not logicview.eq((self.checksum & 255), 0))) then
      self:putx({ Ann.WARN, { "Checksum error", "Error", "ERR" } })
    else
      self:putx({ Ann.FIELD, { "Checksum OK", "OK" } })
    end
    self:emit_cmd_end(Ann.PAGE)
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_gbv(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GBV, self:cmd_ann_list() })
end
function _decoder.handle_gwv(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GWV, self:cmd_ann_list() })
end
function _decoder.handle_gsv(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GSV, self:cmd_ann_list() })
end
function _decoder.handle_glv(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GLV, self:cmd_ann_list() })
end
function _decoder.handle_grpc(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.ss_field = self.ss
    self.flags = (logicview.tointeger(_string.char(pdata), 16) << 4)
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.flags = logicview.add(self.flags, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("RPC flag: 0x%02X", self.flags) } })
    self:emit_cmd_end({ Ann.GRPC, self:cmd_ann_list() })
  end
end
function _decoder.handle_gbva(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GBVA, self:cmd_ann_list() })
end
function _decoder.handle_gwva(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GWVA, self:cmd_ann_list() })
end
function _decoder.handle_gcv(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.GCV, self:cmd_ann_list() })
end
function _decoder.handle_sbv(self, pdata)
  self:handle_set_common(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.ss_field = self.ss
    self.value = _string.char(pdata)
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.value = logicview.add(self.value, _string.char(pdata))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%s", self.value), logicview.pymod("Val: 0x%s", self.value), logicview.pymod("0x%s", self.value) } })
    self:emit_cmd_end({ Ann.SBV, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_swv(self, pdata)
  local nibble
  self:handle_set_common(pdata)
  if logicview.truth((self.cmdstate > 3)) then
    nibble = (self.cmdstate - 4)
    if logicview.truth(logicview.eq(nibble, 0)) then
      self.ss_field = self.ss
      self.value = 0
    end
    self.value = logicview.add(self.value, (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble))))
    if logicview.truth(logicview.eq(nibble, 3)) then
      self.es_field = self.es
      self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%04x", self.value), logicview.pymod("Val: 0x%04x", self.value), logicview.pymod("0x%04x", self.value) } })
      self:emit_cmd_end({ Ann.SWV, self:cmd_ann_list() })
      return
    end
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_ssv(self, pdata)
  self:handle_string(pdata, Ann.SSV)
end
function _decoder.handle_sbva(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 2)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
  elseif logicview.truth(logicview.eq(stage, 2)) then
    if logicview.truth(logicview.eq(pdata, 0)) then
      self:emit_cmd_end({ Ann.SBVA, self:cmd_ann_list() })
      return
    end
    self.value = (logicview.tointeger(_string.char(pdata), 16) << 4)
  else
    self.value = logicview.add(self.value, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%02X", self.value), logicview.pymod("0x%02X", self.value) } })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_swva(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 4)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
    self.value = 0
  else
    self.value = logicview.add(self.value, (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble))))
    if logicview.truth(logicview.eq(nibble, 0)) then
      if logicview.truth(logicview.eq(pdata, 0)) then
        self:emit_cmd_end({ Ann.SWVA, self:cmd_ann_list() })
        return
      end
      self.ss_field = self.ss
    end
    if logicview.truth(logicview.eq(nibble, 3)) then
      self.es_field = self.es
      self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%04X", self.value), logicview.pymod("0x%04X", self.value) } })
      self.cmdstate = logicview.add(self.cmdstate, 1)
    end
  end
end
function _decoder.handle_scv(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 8)) then
    self:emit_not_implemented({ Ann.SCV, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_rpc(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.RPC, self:cmd_ann_list() })
end
function _decoder.decode_coords(self, pdata)
  local nibble, i
  if logicview.truth(logicview.eq(self.cmdstate, 1)) then
    logicview.setidx(self.coords, 0, 0)
    logicview.setidx(self.coords, 1, 0)
    logicview.setidx(self.coords, 2, 0)
    logicview.setidx(self.coords, 3, 0)
  end
  if logicview.truth((self.cmdstate < 18)) then
    nibble = logicview.pymod((self.cmdstate - 1), 4)
    i = ((self.cmdstate - 1) / 4)
    logicview.setidx(self.coords, i, logicview.add(logicview.idx(self.coords, i), (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble)))))
    if logicview.truth(logicview.eq(nibble, 0)) then
      self.ss_field = self.ss
    elseif logicview.truth(logicview.eq(nibble, 3)) then
      self.es_field = self.es
      self:putf({ Ann.FIELD, { logicview.pymod("Coordinate 0x%04X", logicview.idx(self.coords, i)) }, { logicview.pymod("0x%04X", logicview.idx(self.coords, i)) } })
    end
  end
end
function _decoder.handle_line(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.LINE, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Line pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_rect(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.RECT, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Line pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_frect(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.FRECT, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Fill pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_pixel(self, pdata)
  self.es_cmd = self.es
  self:putc({ Ann.WARN, { "Draw pixel documentation is missing.", "Undocumented" } })
  self.state = nil
end
function _decoder.handle_gbvr(self, pdata)
  self:emit_add_bytes(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.ss_field = self.ss
    self.value = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self:putx({ Ann.BIT, { logicview.pymod("High nibble 0x%s", pdata), logicview.pymod("0x%s", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.value = logicview.add(self.value, logicview.tointeger(_string.char(pdata), 16))
    self:putx({ Ann.BIT, { logicview.pymod("Low nibble 0x%s", pdata), logicview.pymod("0x%s", pdata) } })
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%02X", self.value), logicview.pymod("0x%02X", self.value) } })
    self:emit_cmd_end({ Ann.GBVR, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_gwvr(self, pdata)
  local nibble
  self:emit_add_bytes(pdata)
  if logicview.truth((self.cmdstate > 3)) then
    nibble = (self.cmdstate - 3)
    if logicview.truth(logicview.eq(nibble, 0)) then
      self.value = 0
      self.ss_field = self.ss
    end
    self.value = logicview.add(self.value, (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble))))
    self:putx({ Ann.BIT, { logicview.pymod("0x%s", pdata) } })
    if logicview.truth(logicview.eq(nibble, 3)) then
      self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%04x", self.value), logicview.pymod("0x%04X", self.value) } })
      self.es_cmd = self.ss
      self:emit_cmd_end({ Ann.GWVR, self:cmd_ann_list() })
    end
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_gsvr(self, pdata)
  self:handle_string(pdata, Ann.GSVR)
end
function _decoder.handle_glvr(self, pdata)
  self:handle_string(pdata, Ann.GLVR)
end
function _decoder.handle_grpcr(self, pdata)
  local nibble
  self:handle_addr(pdata)
  if logicview.truth((self.cmdstate > 3)) then
    nibble = logicview.pymod((self.cmdstate - 3), 2)
    if logicview.truth(logicview.eq(nibble, 0)) then
      if logicview.truth(logicview.eq(pdata, 0)) then
        self:emit_cmd_end({ Ann.GRPCR, self:cmd_ann_list() })
        return
      end
      self.value = (logicview.tointeger(_string.char(pdata), 16) << 4)
      self.ss_field = self.ss
      self:putx({ Ann.BIT, { logicview.pymod("0x%s", pdata) } })
    end
    if logicview.truth(logicview.eq(nibble, 2)) then
      self.value = logicview.add(self.value, logicview.tointeger(_string.char(pdata), 16))
      self.es_field = self.es
      self:putx({ Ann.BIT, { logicview.pymod("0x%s", pdata) } })
      self:putf({ Ann.FIELD, { logicview.pymod("0x%02X", self.value) } })
    end
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_sbvr(self, pdata)
  self:handle_set_common(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.ss_field = self.ss
    self.value = _string.char(pdata)
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.value = logicview.add(self.value, _string.char(pdata))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%s", self.value), logicview.pymod("Val: 0x%s", self.value), logicview.pymod("0x%s", self.value) } })
    self:emit_cmd_end({ Ann.SBVR, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_swvr(self, pdata)
  self:handle_set_common(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 4)) then
    self.ss_field = self.ss
    self.value = ((pdata - 48) << 4)
  elseif logicview.truth(logicview.eq(self.cmdstate, 5)) then
    self.value = logicview.add(self.value, (pdata - 48))
    self.value = (self.value << 8)
  elseif logicview.truth(logicview.eq(self.cmdstate, 6)) then
    self.value = logicview.add(self.value, ((pdata - 48) << 4))
  elseif logicview.truth(logicview.eq(self.cmdstate, 7)) then
    self.value = logicview.add(self.value, (pdata - 48))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value: 0x%04x", self.value), logicview.pymod("Val: 0x%04x", self.value), logicview.pymod("0x%04x", self.value) } })
    self:emit_cmd_end({ Ann.SWVR, self:cmd_ann_list() })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_ssvr(self, pdata)
  self:handle_string(pdata, Ann.SSVR)
end
function _decoder.handle_rpcr(self, pdata)
  self:handle_read(pdata)
  self:emit_cmd_end({ Ann.RPCR, self:cmd_ann_list() })
end
function _decoder.handle_liner(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.LINER, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Line pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_rectr(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.RECTR, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Line pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_frectr(self, pdata)
  decode_coords(pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 18)) then
    self.es_cmd = self.es
    self:putc({ Ann.FRECTR, self:cmd_ann_list() })
    self:putc({ Ann.WARN, { "Line pattern / Color not implemented" } })
    self.state = nil
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_pixelr(self, pdata)
  self.es_cmd = self.es
  self:putc({ Ann.WARN, { "Draw pixel documentation is missing.", "Undocumented" } })
  self.state = nil
end
function _decoder.handle_gbvar(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 2)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
  elseif logicview.truth(logicview.eq(stage, 2)) then
    if logicview.truth(logicview.eq(pdata, 0)) then
      self:emit_cmd_end({ Ann.GBVAR, self:cmd_ann_list() })
      return
    end
    self.value = (logicview.tointeger(_string.char(pdata), 16) << 4)
  else
    self.value = logicview.add(self.value, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%02X", self.value), logicview.pymod("0x%02X", self.value) } })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_gwvar(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 4)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
    self.value = 0
  else
    self.value = logicview.add(self.value, (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble))))
    if logicview.truth(logicview.eq(nibble, 0)) then
      if logicview.truth(logicview.eq(pdata, 0)) then
        self:emit_cmd_end({ Ann.GWVAR, self:cmd_ann_list() })
        return
      end
      self.ss_field = self.ss
    end
    if logicview.truth(logicview.eq(nibble, 3)) then
      self.es_field = self.es
      self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%04X", self.value), logicview.pymod("0x%04X", self.value) } })
      self.cmdstate = logicview.add(self.cmdstate, 1)
    end
  end
end
function _decoder.handle_sbvar(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 2)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
  elseif logicview.truth(logicview.eq(stage, 2)) then
    if logicview.truth(logicview.eq(pdata, 0)) then
      self:emit_cmd_end({ Ann.SBVAR, self:cmd_ann_list() })
      return
    end
    self.value = (logicview.tointeger(_string.char(pdata), 16) << 4)
  else
    self.value = logicview.add(self.value, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.es
    self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%02X", self.value), logicview.pymod("0x%02X", self.value) } })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_swvar(self, pdata)
  local nibble
  nibble = logicview.pymod((self.cmdstate - 3), 4)
  if logicview.truth(logicview.eq(self.cmdstate, 2)) then
    self.addr = (logicview.tointeger(_string.char(pdata), 16) << 4)
    self.ss_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address high nibble: %c", pdata), logicview.pymod("Addr high 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
  elseif logicview.truth(logicview.eq(self.cmdstate, 3)) then
    self.addr = logicview.add(self.addr, logicview.tointeger(_string.char(pdata), 16))
    self.es_field = self.ss
    self:putx({ Ann.BIT, { logicview.pymod("Address low nibble: %c", pdata), logicview.pymod("Addr low 0x%c", pdata), logicview.pymod("0x%c", pdata) } })
    self:putf({ Ann.FIELD, { logicview.pymod("Address: 0x%02X", self.addr), logicview.pymod("Addr: 0x%02X", self.addr), logicview.pymod("0x%02X", self.addr) } })
    self.value = 0
  else
    self.value = logicview.add(self.value, (logicview.tointeger(_string.char(pdata), 16) << (12 - logicview.mul(4, nibble))))
    if logicview.truth(logicview.eq(nibble, 0)) then
      if logicview.truth(logicview.eq(pdata, 0)) then
        self:emit_cmd_end({ Ann.SWVAR, self:cmd_ann_list() })
        return
      end
      self.ss_field = self.ss
    end
    if logicview.truth(logicview.eq(nibble, 3)) then
      self.es_field = self.es
      self:putf({ Ann.FIELD, { logicview.pymod("Value 0x%04X", self.value), logicview.pymod("0x%04X", self.value) } })
      self.cmdstate = logicview.add(self.cmdstate, 1)
    end
  end
end
function _decoder.handle_gcvr(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 8)) then
    self:emit_not_implemented({ Ann.SCV, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_scvr(self, pdata)
  if logicview.truth(logicview.eq(self.cmdstate, 8)) then
    self:emit_not_implemented({ Ann.SCV, self:cmd_ann_list() })
  end
  self.cmdstate = logicview.add(self.cmdstate, 1)
end
function _decoder.handle_ack(self, pdata)
  self:putx({ Ann.ACK, self:cmd_ann_list() })
  self.state = nil
end
function _decoder.handle_nack(self, pdata)
  self:putx({ Ann.NACK, self:cmd_ann_list() })
  self.state = nil
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, rxtx, pdata, abort_current
    do
      local _lv_seq = data
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      ptype = logicview.idx(_lv_seq, 0)
      rxtx = logicview.idx(_lv_seq, 1)
      pdata = logicview.idx(_lv_seq, 2)
    end
    do
      local _lv_a0, _lv_a1 = ss, es
      self.ss = _lv_a0
      self.es = _lv_a1
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_return = false
      local _lv_value = nil
      local _ok, _err = _pcall(function()
        abort_current = (function()
  local _v
  _v = ((208 <= logicview.idx(pdata, 0)) and (logicview.idx(pdata, 0) <= 247))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.truth(logicview.contains(cmds_with_high_bytes, self.state)))
  if not logicview.truth(_v) then return _v end
  _v = (not logicview.eq(self.state, nil))
  return _v
end)()
        if logicview.truth(abort_current) then
          self:putx({ Ann.WARN, { "Command aborted by invalid byte", "Abort" } })
          self.state = logicview.idx(pdata, 0)
          self:emit_cmd_byte()
          self.cmdstate = 1
        end
        if logicview.truth((self.state == nil)) then
          self.state = logicview.idx(pdata, 0)
          self:emit_cmd_byte()
          self.cmdstate = 1
        end
        logicview.idx(self.cmd_handlers, self.state)(logicview.idx(pdata, 0))
      end)
      if _lv_return then return _lv_value end
      if not _ok then
        if (_type(_err) == 'table' and _err._exc == "KeyError") then
          self:putx({ Ann.WARN, { logicview.pymod("Unknown command: 0x%02x", logicview.idx(pdata, 0)) } })
          self.state = nil
        else
          _error(_err, 0)
        end
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

return _decoder
