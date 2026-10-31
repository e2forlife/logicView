-- Translated from DSView libsigrokdecode for the LogicView session API.
-- License: mit
-- Copyright (C) 2017 Karl Palsson <karlp@etactica.com>
-- Copyright (C) 2022 DreamSourceLab <support@dreamsourcelab.com>

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
local Decoder, OrderedDict, regs
local _decoder

collections = { namedtuple = function(_n, fields) if _type(fields) == 'string' then fields = logicview.split(fields, ' ') end return logicview.namedtuple(fields) end, OrderedDict = function(t) return logicview.dict(t or {}) end, deque = function() return {} end }
OrderedDict = collections.OrderedDict
regs = OrderedDict({ { 1, { "AWATTHR", "Watt-Hour Accumulation Register for Phase A. Active power is accumulated over time in this read-only register. The AWATTHR register can hold a maximum of 0.52 seconds of active energy information with full-scale analog inputs before it overflows (see the Active Energy Calculation section). Bit 0 and Bit 1 of the COMPMODE register determine how the active energy is processed from the six analog inputs.", "R", 16, "S", 0 } }, { 2, { "BWATTHR", "Watt-Hour Accumulation Register for Phase B.", "R", 16, "S", 0 } }, { 3, { "CWATTHR", "Watt-Hour Accumulation Register for Phase C.", "R", 16, "S", 0 } }, { 4, { "AVARHR", "VAR-Hour Accumulation Register for Phase A. Reactive power is accumulated over time in this read-only register. The AVARHR register can hold a maximum of 0.52 seconds of reactive energy information with full-scale analog inputs before it overflows (see the Reactive Energy Calculation section). Bit 0 and Bit 1 of the COMPMODE register determine how the reactive energy is processed from the six analog inputs.", "R", 16, "S", 0 } }, { 5, { "BVARHR", "VAR-Hour Accumulation Register for Phase B.", "R", 16, "S", 0 } }, { 6, { "CVARHR", "VAR-Hour Accumulation Register for Phase C.", "R", 16, "S", 0 } }, { 7, { "AVAHR", "VA-Hour Accumulation Register for Phase A. Apparent power is accumulated over time in this read-only register. The AVAHR register can hold a maximum of 1.15 seconds of apparent energy information with full-scale analog inputs before it overflows (see the Apparent Energy Calculation section). Bit 0 and Bit 1 of the COMPMODE register determine how the apparent energy is processed from the six analog inputs.", "R", 16, "S", 0 } }, { 8, { "BVAHR", "VA-Hour Accumulation Register for Phase B.", "R", 16, "S", 0 } }, { 9, { "CVAHR", "VA-Hour Accumulation Register for Phase C.", "R", 16, "S", 0 } }, { 10, { "AIRMS", "Phase A Current Channel RMS Register. The register contains the rms component of the Phase A input of the current channel. The source is selected by data bits in the mode register.", "R", 24, "S", 0 } }, { 11, { "BIRMS", "Phase B Current Channel RMS Register.", "R", 24, "S", 0 } }, { 12, { "CIRMS", "Phase C Current Channel RMS Register.", "R", 24, "S", 0 } }, { 13, { "AVRMS", "Phase A Voltage Channel RMS Register.", "R", 24, "S", 0 } }, { 14, { "BVRMS", "Phase B Voltage Channel RMS Register.", "R", 24, "S", 0 } }, { 15, { "CVRMS", "Phase C Voltage Channel RMS Register.", "R", 24, "S", 0 } }, { 16, { "FREQ", "Frequency of the Line Input Estimated by the Zero-Crossing Processing. It can also display the period of the line input. Bit 7 of the LCYCMODE register determines if the reading is frequency or period. Default is frequency. Data Bit 0 and Bit 1 of the MMODE register determine the voltage channel used for the frequency or period calculation.", "R", 12, "U", 0 } }, { 17, { "TEMP", "Temperature Register. This register contains the result of the latest temperature conversion. Refer to the Temperature Measurement section for details on how to interpret the content of this register.", "R", 8, "S", 0 } }, { 18, { "WFORM", "Waveform Register. This register contains the digitized waveform of one of the six analog inputs or the digitized power waveform. The source is selected by Data Bit 0 to Bit 4 in the WAVMODE register.", "R", 24, "S", 0 } }, { 19, { "OPMODE", "Operational Mode Register. This register defines the general configuration of the ADE7758 (see Table 18).", "R/W", 8, "U", 4 } }, { 20, { "MMODE", "Measurement Mode Register. This register defines the channel used for period and peak detection measurements (see Table 19).", "R/W", 8, "U", 252 } }, { 21, { "WAVMODE", "Waveform Mode Register. This register defines the channel and sampling frequency used in the waveform sampling mode (see Table 20).", "R/W", 8, "U", 0 } }, { 22, { "COMPMODE", "Computation Mode Register. This register configures the formula applied for the energy and line active energy measurements (see Table 22).", "R/W", 8, "U", 28 } }, { 23, { "LCYCMODE", "Line Cycle Mode Register. This register configures the line cycle accumulation mode for WATT-HR", "R/W", 8, "U", 120 } }, { 24, { "Mask", "IRQ Mask Register. It determines if an interrupt event generates an active-low output at the IRQ pin (see the Interrupts section).", "R/W", 24, "U", 0 } }, { 25, { "Status", "IRQ Status Register. This register contains information regarding the source of the ADE7758 interrupts (see the Interrupts section).", "R", 24, "U", 0 } }, { 26, { "RSTATUS", "IRQ Reset Status Register. Same as the STATUS register, except that its contents are reset to 0 (all flags cleared) after a read operation.", "R", 24, "U", 0 } }, { 27, { "ZXTOUT", "Zero-Cross Timeout Register. If no zero crossing is detected within the time period specified by this register", "R/W", 16, "U", 65535 } }, { 28, { "LINECYC", "Line Cycle Register. The content of this register sets the number of half-line cycles that the active", "R/W", 16, "U", 65535 } }, { 29, { "SAGCYC", "SAG Line Cycle Register. This register specifies the number of consecutive half-line cycles where voltage channel input may fall below a threshold level. This register is common to the three line voltage SAG detection. The detection threshold is specified by the SAGLVL register (see the Line Voltage SAG Detection section).", "R/W", 8, "U", 255 } }, { 30, { "SAGLVL", "SAG Voltage Level. This register specifies the detection threshold for the SAG event. This register is common to all three phases’ line voltage SAG detections. See the description of the SAGCYC register for details.", "R/W", 8, "U", 0 } }, { 31, { "VPINTLVL", "Voltage Peak Level Interrupt Threshold Register. This register sets the level of the voltage peak detection. Bit 5 to Bit 7 of the MMODE register determine which phases are to be monitored. If the selected voltage phase exceeds this level", "R/W", 8, "U", 255 } }, { 32, { "IPINTLVL", "Current Peak Level Interrupt Threshold Register. This register sets the level of the current peak detection. Bit 5 to Bit 7 of the MMODE register determine which phases are to be monitored. If the selected current phase exceeds this level", "R/W", 8, "U", 255 } }, { 33, { "VPEAK", "Voltage Peak Register. This register contains the value of the peak voltage waveform that has occurred within a fixed number of half-line cycles. The number of half-line cycles is set by the LINECYC register.", "R", 8, "U", 0 } }, { 34, { "IPEAK", "Current Peak Register. This register holds the value of the peak current waveform that has occurred within a fixed number of half-line cycles. The number of half-line cycles is set by the LINECYC register.", "R", 8, "U", 0 } }, { 35, { "Gain", "PGA Gain Register. This register is used to adjust the gain selection for the PGA in the current and voltage channels (see the Analog Inputs section).", "R/W", 8, "U", 0 } }, { 36, { "AVRMSGAIN", "Phase A VRMS Gain Register. The range of the voltage rms calculation can be adjusted by writing to this register. It has an adjustment range of ±50% with a resolution of 0.0244%/LSB.", "R/W", 12, "S", 0 } }, { 37, { "BVRMSGAIN", "Phase B VRMS Gain Register.", "R/W", 12, "S", 0 } }, { 38, { "CVRMSGAIN", "Phase C VRMS Gain Register.", "R/W", 12, "S", 0 } }, { 39, { "AIGAIN", "Phase A Current Gain Register. This register is not recommended to be used and it should be kept at 0", "R/W", 12, "S", 0 } }, { 40, { "BIGAIN", "Phase B Current Gain Register. This register is not recommended to be used and it should be kept at 0", "R/W", 12, "S", 0 } }, { 41, { "CIGAIN", "Phase C Current Gain Register. This register is not recommended to be used and it should be kept at 0", "R/W", 12, "S", 0 } }, { 42, { "AWG", "Phase A Watt Gain Register. The range of the watt calculation can be adjusted by writing to this register. It has an adjustment range of ±50% with a resolution of 0.0244%/LSB.", "R/W", 12, "S", 0 } }, { 43, { "BWG", "Phase B Watt Gain Register.", "R/W", 12, "S", 0 } }, { 44, { "CWG", "Phase C Watt Gain Register.", "R/W", 12, "S", 0 } }, { 45, { "AVARG", "Phase A VAR Gain Register. The range of the VAR calculation can be adjusted by writing to this register. It has an adjustment range of ±50% with a resolution of 0.0244%/LSB.", "R/W", 12, "S", 0 } }, { 46, { "BVARG", "Phase B VAR Gain Register.", "R/W", 12, "S", 0 } }, { 47, { "CVARG", "Phase C VAR Gain Register.", "R/W", 12, "S", 0 } }, { 48, { "AVAG", "Phase A VA Gain Register. The range of the VA calculation can be adjusted by writing to this register. It has an adjustment range of ±50% with a resolution of 0.0244%/LSB.", "R/W", 12, "S", 0 } }, { 49, { "BVAG", "Phase B VA Gain Register.", "R/W", 12, "S", 0 } }, { 50, { "CVAG", "Phase C VA Gain Register.", "R/W", 12, "S", 0 } }, { 51, { "AVRMSOS", "Phase A Voltage RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 52, { "BVRMSOS", "Phase B Voltage RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 53, { "CVRMSOS", "Phase C Voltage RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 54, { "AIRMSOS", "Phase A Current RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 55, { "BIRMSOS", "Phase B Current RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 56, { "CIRMSOS", "Phase C Current RMS Offset Correction Register.", "R/W", 12, "S", 0 } }, { 57, { "AWATTOS", "Phase A Watt Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 58, { "BWATTOS", "Phase B Watt Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 59, { "CWATTOS", "Phase C Watt Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 60, { "AVAROS", "Phase A VAR Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 61, { "BVAROS", "Phase B VAR Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 62, { "CVAROS", "Phase C VAR Offset Calibration Register.", "R/W", 12, "S", 0 } }, { 63, { "APHCAL", "Phase A Phase Calibration Register. The phase relationship between the current and voltage channel can be adjusted by writing to this signed 7-bit register (see the Phase Compensation section).", "R/W", 7, "S", 0 } }, { 64, { "BPHCAL", "Phase B Phase Calibration Register.", "R/W", 7, "S", 0 } }, { 65, { "CPHCAL", "Phase C Phase Calibration Register.", "R/W", 7, "S", 0 } }, { 66, { "WDIV", "Active Energy Register Divider.", "R/W", 8, "U", 0 } }, { 67, { "VARDIV", "Reactive Energy Register Divider.", "R/W", 8, "U", 0 } }, { 68, { "VADIV", "Apparent Energy Register Divider.", "R/W", 8, "U", 0 } }, { 69, { "APCFNUM", "Active Power CF Scaling Numerator Register. The content of this register is used in the numerator of the APCF output scaling calculation. Bits [15:13] indicate reverse polarity active power measurement for Phase A", "R/W", 16, "U", 0 } }, { 70, { "APCFDEN", "Active Power CF Scaling Denominator Register. The content of this register is used in the denominator of the APCF output scaling.", "R/W", 12, "U", 63 } }, { 71, { "VARCFNUM", "Reactive Power CF Scaling Numerator Register. The content of this register is used in the numerator of the VARCF output scaling. Bits [15:13] indicate reverse polarity reactive power measurement for Phase A", "R/W", 16, "U", 0 } }, { 72, { "VARCFDEN", "Reactive Power CF Scaling Denominator Register. The content of this register is used in the denominator of the VARCF output scaling.", "R/W", 12, "U", 63 } }, { 126, { "CHKSUM", "Checksum Register. The content of this register represents the sum of all the ones in the last register read from the SPI port.", "R", 8, "U", nil } }, { 127, { "Version", "Version of the Die.", "R", 8, "U", nil } } })

_decoder = {
  api_version = 3,
  id = "ade77xx",
  name = "ADE77xx",
  longname = "Analog Devices ADE77xx",
  desc = "Poly phase multifunction energy metering IC protocol.",
  license = "mit",
  inputs = { "spi" },
  outputs = {  },
  tags = { "Analog/digital", "IC", "Sensor" },
  channels = {  },
  optional_channels = {  },
  options = {  },
  annotations = { { "read", "Register read commands" }, { "write", "Register write commands" }, { "warning", "Warnings" } },
  annotation_rows = { { "read", "Read", { 0 } }, { "write", "Write", { 1 } }, { "warnings", "Warnings", { 2 } } },
  binary = {  }
}
function _decoder.reset_data(self)
  self.expected = 0
  do
    local _lv_a0, _lv_a1 = {  }, {  }
    self.mosi_bytes = _lv_a0
    self.miso_bytes = _lv_a1
  end
end
function _decoder.__init__(self)
  self:reset()
end
function _decoder.reset(self)
  do
    local _lv_a0, _lv_a1 = 0, 0
    self.ss_cmd = _lv_a0
    self.es_cmd = _lv_a1
  end
  self:reset_data()
end
function _decoder.start(self)
  self.out_ann = self:register(logicview.OUTPUT_ANN)
end
function _decoder.putx(self, data)
  self:put(self.ss_cmd, self.es_cmd, self.out_ann, data)
end
function _decoder.put_warn(self, pos, msg)
  self:put(logicview.idx(pos, 0), logicview.idx(pos, 1), self.out_ann, { 2, { msg } })
end
function _decoder.decode(self, start_sample, end_sample, packets)
  local function _lv_packet(self, ss, es, data)
    local ptype, cs_old, cs_new, write, reg, rblob, idx, mosi, miso, valo, vali
    ptype = logicview.idx(data, 0)
    if logicview.truth(logicview.eq(ptype, "CS-CHANGE")) then
      do
        local _lv_seq = logicview.slice(data, 1, nil, nil)
        if _type(_lv_seq) == 'function' then
          local _lv_built = {}
          for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
          _lv_seq = _lv_built
        end
        cs_old = logicview.idx(_lv_seq, 0)
        cs_new = logicview.idx(_lv_seq, 1)
      end
      if logicview.truth((function()
  local _v
  _v = (cs_old ~= nil)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_old, 0)
  if not logicview.truth(_v) then return _v end
  _v = logicview.eq(cs_new, 1)
  return _v
end)()) then
        if logicview.truth((function()
  local _v
  _v = (logicview.len(self.mosi_bytes) > 0)
  if not logicview.truth(_v) then return _v end
  _v = (logicview.len(logicview.slice(self.mosi_bytes, 1, nil, nil)) < self.expected)
  return _v
end)()) then
          self.es_cmd = es
          do
            local _lv_a0, _lv_a1 = (self.cmd & 128), (self.cmd & 127)
            write = _lv_a0
            reg = _lv_a1
          end
          rblob = logicview.dget(regs, reg, nil)
          idx = (function() if logicview.truth(write) then return 1 else return 0 end end)()
          self:putx({ idx, { logicview.pymod("%s: %s", { logicview.idx(rblob, 0), "SHORT" }) } })
          self:put_warn({ self.ss_cmd, es }, "Short transfer!")
        end
        self:reset_data()
      end
      return
    end
    if logicview.truth((not logicview.eq(ptype, "DATA"))) then
      return
    end
    do
      local _lv_seq = logicview.slice(data, 1, nil, nil)
      if _type(_lv_seq) == 'function' then
        local _lv_built = {}
        for _lv_v in _lv_seq do _lv_built[#_lv_built + 1] = _lv_v end
        _lv_seq = _lv_built
      end
      mosi = logicview.idx(_lv_seq, 0)
      miso = logicview.idx(_lv_seq, 1)
    end
    if logicview.truth(logicview.eq(logicview.len(self.mosi_bytes), 0)) then
      self.ss_cmd = ss
    end
    _table.insert(self.mosi_bytes, mosi)
    _table.insert(self.miso_bytes, miso)
    if logicview.truth((logicview.len(self.mosi_bytes) < 2)) then
      return
    end
    self.cmd = logicview.idx(self.mosi_bytes, 0)
    do
      local _lv_a0, _lv_a1 = (self.cmd & 128), (self.cmd & 127)
      write = _lv_a0
      reg = _lv_a1
    end
    rblob = logicview.dget(regs, reg, nil)
    if logicview.truth((not logicview.truth(rblob))) then
      self:put_warn({ self.ss_cmd, es }, "Unknown register!")
      return
    end
    self.expected = math.ceil((logicview.idx(rblob, 3) / 8))
    if logicview.truth((not logicview.eq(logicview.len(logicview.slice(self.mosi_bytes, 1, nil, nil)), self.expected))) then
      return
    end
    do
      local _lv_a0, _lv_a1 = nil, nil
      valo = _lv_a0
      vali = _lv_a1
    end
    self.es_cmd = es
    if logicview.truth(logicview.eq(self.expected, 3)) then
      valo = (((logicview.idx(self.mosi_bytes, 1) << 16) | (logicview.idx(self.mosi_bytes, 2) << 8)) | logicview.idx(self.mosi_bytes, 3))
      vali = (((logicview.idx(self.miso_bytes, 1) << 16) | (logicview.idx(self.miso_bytes, 2) << 8)) | logicview.idx(self.miso_bytes, 3))
    elseif logicview.truth(logicview.eq(self.expected, 2)) then
      valo = ((logicview.idx(self.mosi_bytes, 1) << 8) | logicview.idx(self.mosi_bytes, 2))
      vali = ((logicview.idx(self.miso_bytes, 1) << 8) | logicview.idx(self.miso_bytes, 2))
    elseif logicview.truth(logicview.eq(self.expected, 1)) then
      valo = logicview.idx(self.mosi_bytes, 1)
      vali = logicview.idx(self.miso_bytes, 1)
    end
    if logicview.truth(write) then
      self:putx({ 1, { logicview.pymod("%s: {$}", logicview.idx(rblob, 0)), logicview.pymod("@%02X", valo) } })
    else
      self:putx({ 0, { logicview.pymod("%s: {$}", logicview.idx(rblob, 0)), logicview.pymod("@%02X", valo) } })
    end
    self:reset_data()
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
