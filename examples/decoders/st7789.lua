-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: gplv2+

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
local COMMAND_MAP, _get_annotation_index, Decoder
local _decoder

COMMAND_MAP = logicview.dict({ [0] = logicview.dict({ name = "NOP", desc = "Empty command" }), [1] = logicview.dict({ name = "SWRESET", desc = "Software Reset" }), [4] = logicview.dict({ name = "RDDID", desc = "Read Display ID" }), [9] = logicview.dict({ name = "RDDST", desc = "Read Display Status" }), [10] = logicview.dict({ name = "RDDPM", desc = "Read Display Power Mode" }), [11] = logicview.dict({ name = "RDDMADCTL", desc = "Read Display MADCTL" }), [12] = logicview.dict({ name = "RDDCOLMOD", desc = "Read Display Pixel Format" }), [13] = logicview.dict({ name = "RDDIM", desc = "Read Display Image Mode" }), [14] = logicview.dict({ name = "RDDSM", desc = "Read Display Signal Mode" }), [15] = logicview.dict({ name = "RDDSDR", desc = "Read Display Self-Diagnostic Result" }), [16] = logicview.dict({ name = "SLPIN", desc = "Sleep in" }), [17] = logicview.dict({ name = "SLPOUT", desc = "Sleep Out" }), [18] = logicview.dict({ name = "PTLON", desc = "Partial Display Mode On" }), [19] = logicview.dict({ name = "NORON", desc = "Normal Display Mode On" }), [32] = logicview.dict({ name = "INVOFF", desc = "Display Inversion Off" }), [33] = logicview.dict({ name = "INVON", desc = "Display Inversion On" }), [38] = logicview.dict({ name = "GAMSET", desc = "Gamma Set" }), [40] = logicview.dict({ name = "DISPOFF", desc = "Display Off" }), [41] = logicview.dict({ name = "DISPON", desc = "Display On" }), [42] = logicview.dict({ name = "CASET", desc = "Column Address Set" }), [43] = logicview.dict({ name = "RASET", desc = "Row Address Set" }), [44] = logicview.dict({ name = "RAMWR", desc = "Memory Write" }), [46] = logicview.dict({ name = "RAMRD", desc = "Memory Read" }), [48] = logicview.dict({ name = "PTLAR", desc = "Partial Area" }), [51] = logicview.dict({ name = "VSCRDEF", desc = "Vertical Scrolling Definition" }), [52] = logicview.dict({ name = "TEOFF", desc = "Tearing Effect Line OFF" }), [53] = logicview.dict({ name = "TEON", desc = "Tearing Effect Line On" }), [54] = logicview.dict({ name = "MADCTL", desc = "Memory Data Access Control" }), [55] = logicview.dict({ name = "VSCSAD", desc = "Vertical Scroll Start Address of RAM" }), [56] = logicview.dict({ name = "IDMOFF", desc = "Idle Mode Off" }), [57] = logicview.dict({ name = "IDMON", desc = "Idle mode on" }), [58] = logicview.dict({ name = "COLMOD", desc = "Interface Pixel Format" }), [60] = logicview.dict({ name = "WRMEMC", desc = "Write Memory Continue" }), [62] = logicview.dict({ name = "RDMEMC", desc = "Read Memory Continue" }), [68] = logicview.dict({ name = "STE", desc = "Set Tear Scanline" }), [69] = logicview.dict({ name = "GSCAN", desc = "Get Scanline" }), [81] = logicview.dict({ name = "WRDISBV", desc = "Write Display Brightness" }), [82] = logicview.dict({ name = "RDDISBV", desc = "Read Display Brightness Value" }), [83] = logicview.dict({ name = "WRCTRLD", desc = "Write CTRL Display" }), [84] = logicview.dict({ name = "RDCTRLD", desc = "Read CTRL Value Display" }), [85] = logicview.dict({ name = "WRCACE", desc = "Write Content Adaptive Brightness Control and Color Enhancement" }), [86] = logicview.dict({ name = "RDCABC", desc = "Read Content Adaptive Brightness Control" }), [94] = logicview.dict({ name = "WRCABCMB", desc = "Write CABC Minimum Brightness" }), [95] = logicview.dict({ name = "RDCABCMB", desc = "Read CABC Minimum Brightness" }), [104] = logicview.dict({ name = "RDABCSDR", desc = "Read Automatic Brightness Control Self-Diagnostic Result" }), [218] = logicview.dict({ name = "RDID1", desc = "Read ID1" }), [219] = logicview.dict({ name = "RDID2", desc = "Read ID2" }), [220] = logicview.dict({ name = "RDID3", desc = "Read ID3" }), [176] = logicview.dict({ name = "RAMCTRL", desc = "RAM Control" }), [177] = logicview.dict({ name = "RGBCTRL", desc = "RGB Interface Control" }), [178] = logicview.dict({ name = "PORCTRL", desc = "Porch Setting" }), [179] = logicview.dict({ name = "FRCTRL1", desc = "Frame Rate Control 1 (In partial mode/ idle colors)" }), [181] = logicview.dict({ name = "PARCTRL", desc = "Partial mode Control" }), [183] = logicview.dict({ name = "GCTRL", desc = "Gate Control" }), [184] = logicview.dict({ name = "GTADJ", desc = "Gate On Timing Adjustment" }), [186] = logicview.dict({ name = "DGMEN", desc = "Digital Gamma Enable" }), [187] = logicview.dict({ name = "VCOMS", desc = "VCOMS Setting" }), [192] = logicview.dict({ name = "LCMCTRL", desc = "LCM Control" }), [193] = logicview.dict({ name = "IDSET", desc = "ID Code Setting" }), [194] = logicview.dict({ name = "VDVVRHEN", desc = "VDV and VRH Command Enable" }), [195] = logicview.dict({ name = "VRHS", desc = "VRH Set" }), [196] = logicview.dict({ name = "VDVS", desc = "VDV Set" }), [197] = logicview.dict({ name = "VCMOFSET", desc = "VCOMS Offset Set" }), [198] = logicview.dict({ name = "FRCTRL2", desc = "Frame Rate Control in Normal Mode" }), [199] = logicview.dict({ name = "CABCCTRL", desc = "CABC Control" }), [200] = logicview.dict({ name = "REGSEL1", desc = "Register Value Selection 1" }), [202] = logicview.dict({ name = "REGSEL2", desc = "Register Value Selection 2" }), [204] = logicview.dict({ name = "PWMFRSEL", desc = "PWM Frequency Selection" }), [208] = logicview.dict({ name = "PWCTRL1", desc = "Power Control 1" }), [210] = logicview.dict({ name = "VAPVANEN", desc = "Enable VAP/VAN signal output" }), [223] = logicview.dict({ name = "CMD2EN", desc = "Command 2 Enable" }), [224] = logicview.dict({ name = "PVGAMCTRL", desc = "Positive Voltage Gamma Control" }), [225] = logicview.dict({ name = "NVGAMCTRL", desc = "Negative Voltage Gamma Control" }), [226] = logicview.dict({ name = "DGMLUTR", desc = "Digital Gamma Look-up Table for Red" }), [227] = logicview.dict({ name = "DGMLUTB", desc = "Digital Gamma Look-up Table for Blue" }), [228] = logicview.dict({ name = "GATECTRL", desc = "Gate Control" }), [231] = logicview.dict({ name = "SPI2EN", desc = "SPI2 Enable" }), [232] = logicview.dict({ name = "PWCTRL2", desc = "Power Control 2" }), [233] = logicview.dict({ name = "EQCTRL", desc = "Equalize time control" }), [236] = logicview.dict({ name = "PROMCTRL", desc = "Program Mode Control" }), [250] = logicview.dict({ name = "PROMEN", desc = "Program Mode Enable" }), [252] = logicview.dict({ name = "NVMSET", desc = "NVM Setting" }), [254] = logicview.dict({ name = "PROMACT", desc = "Program action" }) })
_get_annotation_index = function(annotations, name)
  local index, annotation
  for _lv_i, _lv_v in logicview.enumerate(annotations) do
    index = _lv_i
    annotation = _lv_v
    if logicview.truth(logicview.eq(logicview.idx(annotation, 0), name)) then
      return index
    end
    ::continue_1::
  end
  _error(RuntimeError(("Unknown annotation ") .. (_tostring(_tostring(name))) .. (": ") .. (_tostring(_tostring(annotations)))), 0)
end
_decoder = {
  api_version = 3,
  id = "st7789",
  name = "ST7789",
  longname = "Sitronix ST7789",
  desc = "Sitronix ST7789 TFT controller protocol.",
  license = "gplv2+",
  inputs = { "logic" },
  outputs = {  },
  tags = { "Display", "SPI" },
  channels = { logicview.dict({ id = "csx", name = "CSX", desc = "Chip selection signal" }), logicview.dict({ id = "dcx", name = "DCX", desc = "Clock signal" }), logicview.dict({ id = "sdo", name = "SDO", desc = "Serial output data" }), logicview.dict({ id = "wrx", name = "WRX", desc = "Command / data" }) },
  optional_channels = {  },
  options = {  },
  annotations = { { "bit", "Bit" }, { "command", "Command" }, { "data", "Data" }, { "cmd_data", "Command + Data" }, { "asserted", "Assertion" } },
  annotation_rows = { { "bits", "Bits", { 0 } }, { "bytes", "Bytes", { 1, 2 } }, { "cmd_data", "Command + Data", { 3 } }, { "asserted", "Assertion", { 4 } } },
  binary = {  }
}
function _decoder._get_channel_index(self, name)
  local index, channel
  for _lv_i, _lv_v in logicview.enumerate(self.channels) do
    index = _lv_i
    channel = _lv_v
    if logicview.truth(logicview.eq(logicview.idx(channel, "name"), name)) then
      return index
    end
    ::continue_2::
  end
  _error(RuntimeError("Implementation bug."), 0)
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder._get_cmd_str(self, cmd)
  if logicview.truth(logicview.contains(COMMAND_MAP, cmd)) then
    return logicview.add(logicview.idx(logicview.idx(COMMAND_MAP, cmd), "name"), logicview.pymod("(%02X)", cmd))
  else
    return logicview.pymod("Unknown(%02X)", cmd)
  end
end
function _decoder._get_cmd_data_str(self, cmd, data_list)
  local cmd_str, ret_str, v
  cmd_str = self:_get_cmd_str(cmd)
  if logicview.truth(data_list) then
    ret_str = (_tostring(cmd_str)) .. (": ")
    for _lv_item in logicview.iter(data_list) do
      v = _lv_item
      ret_str = logicview.add(ret_str, logicview.pymod(" %02X", v))
      ::continue_3::
    end
    return ret_str
  else
    return cmd_str
  end
end
function _decoder.decode(self)
  local last_cmd, last_cmd_data_sample_startnum, last_cmd_data_sample_endnum, last_cmd_data_list, csx_start_samplenum, bit, bit_count, byte, byte_sample_startnum, csx, dcx, sdo, wrx, bit_start_samplenum
  last_cmd = nil
  last_cmd_data_sample_startnum = nil
  last_cmd_data_sample_endnum = nil
  last_cmd_data_list = {  }
  while true do
    self:wait(logicview.dict({ [self:_get_channel_index("CSX")] = "f" }))
    csx_start_samplenum = self.samplenum
    bit = nil
    bit_count = 0
    byte = 0
    byte_sample_startnum = nil
    while true do
      do
        local _lv_seq = self:wait({ logicview.dict({ [self:_get_channel_index("CSX")] = "r" }), logicview.dict({ [self:_get_channel_index("DCX")] = "e" }) })
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        csx = logicview.idx(_lv_seq, 0)
        dcx = logicview.idx(_lv_seq, 1)
        sdo = logicview.idx(_lv_seq, 2)
        wrx = logicview.idx(_lv_seq, 3)
      end
      if logicview.truth(logicview.eq(csx, 1)) then
        self:put(csx_start_samplenum, self.samplenum, self.out_ann, { _get_annotation_index(self.annotations, "asserted"), { "Asserted" } })
        if logicview.truth((last_cmd ~= nil)) then
          self:put(last_cmd_data_sample_startnum, last_cmd_data_sample_endnum, self.out_ann, { _get_annotation_index(self.annotations, "cmd_data"), { self:_get_cmd_data_str(last_cmd, last_cmd_data_list) } })
          last_cmd = nil
          last_cmd_data_sample_startnum = nil
          last_cmd_data_sample_endnum = nil
          last_cmd_data_list = {  }
        end
        break
      end
      if logicview.truth((function()
  local _v
  _v = logicview.eq(dcx, 1)
  if not logicview.truth(_v) then return _v end
  _v = (bit == nil)
  return _v
end)()) then
        bit = sdo
        bit_start_samplenum = self.samplenum
        bit_count = logicview.add(bit_count, 1)
        byte = ((byte << 1) | bit)
        if logicview.truth((byte_sample_startnum == nil)) then
          byte_sample_startnum = self.samplenum
        end
      end
      if logicview.truth((function()
  local _v
  _v = logicview.eq(dcx, 0)
  if not logicview.truth(_v) then return _v end
  _v = (bit ~= nil)
  return _v
end)()) then
        self:put(bit_start_samplenum, self.samplenum, self.out_ann, { _get_annotation_index(self.annotations, "bit"), { _tostring(bit) } })
        bit = nil
        if logicview.truth(logicview.eq(bit_count, 8)) then
          if logicview.truth(wrx) then
            last_cmd_data_sample_endnum = self.samplenum
            _table.insert(last_cmd_data_list, byte)
            self:put(byte_sample_startnum, self.samplenum, self.out_ann, { _get_annotation_index(self.annotations, "data"), { logicview.pymod("Data(%02X)", byte) } })
          else
            self:put(byte_sample_startnum, self.samplenum, self.out_ann, { _get_annotation_index(self.annotations, "command"), { self:_get_cmd_str(byte) } })
            if logicview.truth((last_cmd ~= nil)) then
              self:put(last_cmd_data_sample_startnum, last_cmd_data_sample_endnum, self.out_ann, { _get_annotation_index(self.annotations, "cmd_data"), { self:_get_cmd_data_str(last_cmd, last_cmd_data_list) } })
              last_cmd_data_list = {  }
            end
            last_cmd = byte
            last_cmd_data_sample_startnum = byte_sample_startnum
            last_cmd_data_sample_endnum = self.samplenum
          end
          byte = 0
          bit_count = 0
          byte_sample_startnum = nil
        end
      end
      ::continue_5::
    end
    ::continue_4::
  end
end

return _decoder
