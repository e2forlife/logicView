-- Nuvoton NAU7802 24-bit bridge ADC (datasheet Rev 2.6).
-- Standalone: samples SCL/SDA directly and interprets the chip's I2C register
-- protocol. Slave address is fixed at 0x2A (write 0x54, read 0x55).

local lv = logicview
local SLAVE = 0x2A

local REG_NAMES = {
  [0x00] = "PU_CTRL",
  [0x01] = "CTRL1",
  [0x02] = "CTRL2",
  [0x03] = "OCAL1_B2",
  [0x04] = "OCAL1_B1",
  [0x05] = "OCAL1_B0",
  [0x06] = "GCAL1_B3",
  [0x07] = "GCAL1_B2",
  [0x08] = "GCAL1_B1",
  [0x09] = "GCAL1_B0",
  [0x0A] = "OCAL2_B2",
  [0x0B] = "OCAL2_B1",
  [0x0C] = "OCAL2_B0",
  [0x0D] = "GCAL2_B3",
  [0x0E] = "GCAL2_B2",
  [0x0F] = "GCAL2_B1",
  [0x10] = "GCAL2_B0",
  [0x11] = "I2C_CTRL",
  [0x12] = "ADCO_B2",
  [0x13] = "ADCO_B1",
  [0x14] = "ADCO_B0",
  [0x15] = "ADC_CTRL",
  [0x16] = "OTP_B1",
  [0x17] = "OTP_B0",
  [0x18] = "RESERVED_18",
  [0x19] = "RESERVED_19",
  [0x1A] = "RESERVED_1A",
  [0x1B] = "PGA_CTRL",
  [0x1C] = "PWR_CTRL",
  [0x1D] = "RESERVED_1D",
  [0x1E] = "RESERVED_1E",
  [0x1F] = "REV_ID",
}

local VLDO = {
  [0] = "4.5V", [1] = "4.2V", [2] = "3.9V", [3] = "3.6V",
  [4] = "3.3V", [5] = "3.0V", [6] = "2.7V", [7] = "2.4V",
}
local PGA = {
  [0] = "x1", [1] = "x2", [2] = "x4", [3] = "x8",
  [4] = "x16", [5] = "x32", [6] = "x64", [7] = "x128",
}
local CRS = {
  [0] = "10SPS", [1] = "20SPS", [2] = "40SPS", [3] = "80SPS", [7] = "320SPS",
}
local CALMOD = {
  [0] = "offset internal", [1] = "reserved",
  [2] = "offset system", [3] = "gain system",
}
local MASTER_BIAS = {
  [0] = "100%", [1] = "90%", [2] = "80%", [3] = "73%",
  [4] = "67%", [5] = "62%", [6] = "58%", [7] = "54%",
}
local ADC_CURR = { [0] = "100%", [1] = "75%", [2] = "50%", [3] = "25%" }
local PGA_CURR = { [0] = "100%", [1] = "95%", [2] = "86%", [3] = "70%" }

local ANN_WRITE = 0
local ANN_READ = 1
local ANN_SAMPLE = 2
local ANN_WARN = 3
local ANN_BUS = 4

local function bit_on(value, bit)
  return (value & (1 << bit)) ~= 0
end

local function reg_name(reg)
  return REG_NAMES[reg] or string.format("REG0x%02X", reg)
end

local function signed24(raw)
  if (raw & 0x800000) ~= 0 then
    return raw - 0x1000000
  end
  return raw
end

local function offset_sign_mag(raw)
  local mag = raw & 0x7FFFFF
  if (raw & 0x800000) ~= 0 then
    return -mag
  end
  return mag
end

local function describe_pu_ctrl(value)
  return string.format(
    "PU_CTRL AVDDS=%s OSCS=%s CR=%d CS=%d PUR=%d PUA=%d PUD=%d RR=%d",
    bit_on(value, 7) and "LDO" or "pin",
    bit_on(value, 6) and "xtal" or "RC",
    bit_on(value, 5) and 1 or 0,
    bit_on(value, 4) and 1 or 0,
    bit_on(value, 3) and 1 or 0,
    bit_on(value, 2) and 1 or 0,
    bit_on(value, 1) and 1 or 0,
    bit_on(value, 0) and 1 or 0
  )
end

local function describe_ctrl1(value)
  return string.format(
    "CTRL1 DRDYP=%s DRDY_SEL=%s VLDO=%s PGA=%s",
    bit_on(value, 7) and "low" or "high",
    bit_on(value, 6) and "clock" or "ready",
    VLDO[(value >> 3) & 7] or "?",
    PGA[value & 7] or "?"
  )
end

local function describe_ctrl2(value)
  return string.format(
    "CTRL2 CHS=%s CRS=%s CAL_ERR=%d CALS=%d CALMOD=%s",
    bit_on(value, 7) and "Ch2" or "Ch1",
    CRS[(value >> 4) & 7] or "reserved",
    bit_on(value, 3) and 1 or 0,
    bit_on(value, 2) and 1 or 0,
    CALMOD[value & 3] or "?"
  )
end

local function describe_i2c_ctrl(value)
  return string.format(
    "I2C_CTRL CRSD=%d FRD=%d SPE=%d WPD=%d SI=%d BOPGA=%d TS=%d BGPCP=%d",
    bit_on(value, 7) and 1 or 0,
    bit_on(value, 6) and 1 or 0,
    bit_on(value, 5) and 1 or 0,
    bit_on(value, 4) and 1 or 0,
    bit_on(value, 3) and 1 or 0,
    bit_on(value, 2) and 1 or 0,
    bit_on(value, 1) and 1 or 0,
    bit_on(value, 0) and 1 or 0
  )
end

local function describe_adc_ctrl(value, otp_sel)
  return string.format(
    "%s FRD_EN=%d REG_CHPS=%d ADC_VCM=%d REG_CHP=%d",
    otp_sel and "OTP[31:24]" or "ADC_CTRL",
    bit_on(value, 7) and 1 or 0,
    (value >> 4) & 3,
    (value >> 2) & 3,
    value & 3
  )
end

local function describe_pga_ctrl(value)
  return string.format(
    "PGA_CTRL RD_OTP_SEL=%d LDOMODE=%d PGA_BUFF=%d PGA_BP=%d PGAINV=%d PGACHPDIS=%d",
    bit_on(value, 7) and 1 or 0,
    bit_on(value, 6) and 1 or 0,
    bit_on(value, 5) and 1 or 0,
    bit_on(value, 4) and 1 or 0,
    bit_on(value, 3) and 1 or 0,
    bit_on(value, 0) and 1 or 0
  )
end

local function describe_pwr_ctrl(value)
  return string.format(
    "PWR_CTRL PGA_CAP_EN=%d MASTER_BIAS=%s ADC_CURR=%s PGA_CURR=%s",
    bit_on(value, 7) and 1 or 0,
    MASTER_BIAS[(value >> 4) & 7] or "?",
    ADC_CURR[(value >> 2) & 3] or "?",
    PGA_CURR[value & 3] or "?"
  )
end

local function describe_byte(reg, value, write, otp_sel)
  if reg == 0x00 then return describe_pu_ctrl(value) end
  if reg == 0x01 then return describe_ctrl1(value) end
  if reg == 0x02 then return describe_ctrl2(value) end
  if reg == 0x11 then return describe_i2c_ctrl(value) end
  if reg == 0x15 then return describe_adc_ctrl(value, (not write) and otp_sel) end
  if reg == 0x1B then return describe_pga_ctrl(value) end
  if reg == 0x1C then return describe_pwr_ctrl(value) end
  if reg == 0x1F then return string.format("REV_ID 0x%X", value & 0x0F) end
  return string.format("%s 0x%02X", reg_name(reg), value)
end

return {
  api_version = 3,
  id = "nau7802",
  name = "NAU7802",
  longname = "Nuvoton NAU7802",
  desc = "Nuvoton NAU7802 24-bit bridge ADC over SCL/SDA.",
  license = "gplv3+",
  inputs = { "logic" },
  outputs = { "nau7802" },
  tags = { "IC", "Sensor" },
  channels = {
    { id = "scl", name = "SCL", desc = "Serial clock" },
    { id = "sda", name = "SDA", desc = "Serial data" },
  },
  optional_channels = {},
  annotations = {
    { "write", "Register write" },
    { "read", "Register read" },
    { "sample", "ADC sample" },
    { "warning", "Warning" },
    { "bus", "I2C bus event" },
  },
  annotation_rows = {
    { "bus", "Bus", { 4 } },
    { "regs", "Registers", { 0, 1, 2, 3 } },
  },
  lanes = {
    {
      id = "nau7802",
      name = "NAU7802",
      channel = "sda",
      channels = { "sda", "scl" },
      classes = { "write", "read", "sample", "warning", "bus" },
    },
  },

  start = function(self)
    self.out_ann = self:register(lv.OUTPUT_ANN)
    self.out_python = self:register(lv.OUTPUT_PYTHON)
  end,

  reset = function(self)
    self.pointer = nil
    self.seen = { [0x11] = 0, [0x15] = 0, [0x1B] = 0 }
    self.group = nil
    self.stream = {}
    self.stream_ss = nil
    self.stream_es = nil
    self.saw_pointer = false
    self.writing = false
  end,

  putx = function(self, ss, es, class_index, text)
    if ss == nil or es == nil or ss > es then
      return
    end
    self:put(ss, es, self.out_ann, { class_index, { text } })
  end,

  finish_group = function(self)
    local group = self.group
    if group == nil then
      return
    end
    if #group.bytes < group.need then
      self.group = nil
      return
    end
    local raw = 0
    for i = 1, #group.bytes do
      raw = (raw << 8) | group.bytes[i]
    end
    if group.kind == "adc" then
      local code = signed24(raw)
      local text = string.format("ADC %+d (0x%06X)", code, raw)
      self:putx(group.ss, group.es, ANN_SAMPLE, text)
      self:put(group.ss, group.es, self.out_python, { "ADC", raw, code })
    elseif group.kind == "offset" then
      self:putx(
        group.ss,
        group.es,
        group.write and ANN_WRITE or ANN_READ,
        string.format("%s offset %+d (0x%06X)", group.label, offset_sign_mag(raw), raw)
      )
    elseif group.kind == "gain" then
      self:putx(
        group.ss,
        group.es,
        group.write and ANN_WRITE or ANN_READ,
        string.format("%s gain %.6f (0x%08X)", group.label, raw / (1 << 23), raw)
      )
    end
    self.group = nil
  end,

  start_group = function(self, kind, label, base, need, ss, es, write)
    self:finish_group()
    self.group = {
      kind = kind,
      label = label,
      base = base,
      need = need,
      bytes = {},
      ss = ss,
      es = es,
      write = write,
    }
  end,

  push_group_byte = function(self, reg, value, ss, es, write)
    local group = self.group
    if group == nil
        or group.write ~= write
        or #group.bytes >= group.need
        or reg ~= ((group.base + #group.bytes) & 0x7F) then
      return false
    end
    group.bytes[#group.bytes + 1] = value
    group.es = es
    if #group.bytes == group.need then
      self:finish_group()
    end
    return true
  end,

  handle_data = function(self, reg, value, ss, es, write)
    local name = reg_name(reg)
    if write and (reg == 0x11 or reg == 0x15 or reg == 0x1B) then
      self.seen[reg] = value
    end

    local grouped = false
    if reg >= 0x03 and reg <= 0x05 then
      if reg == 0x03 then
        self:start_group("offset", "CH1", 0x03, 3, ss, es, write)
      end
      grouped = self:push_group_byte(reg, value, ss, es, write)
    elseif reg >= 0x0A and reg <= 0x0C then
      if reg == 0x0A then
        self:start_group("offset", "CH2", 0x0A, 3, ss, es, write)
      end
      grouped = self:push_group_byte(reg, value, ss, es, write)
    elseif reg >= 0x06 and reg <= 0x09 then
      if reg == 0x06 then
        self:start_group("gain", "CH1", 0x06, 4, ss, es, write)
      end
      grouped = self:push_group_byte(reg, value, ss, es, write)
    elseif reg >= 0x0D and reg <= 0x10 then
      if reg == 0x0D then
        self:start_group("gain", "CH2", 0x0D, 4, ss, es, write)
      end
      grouped = self:push_group_byte(reg, value, ss, es, write)
    elseif (not write) and reg >= 0x12 and reg <= 0x14 then
      if reg == 0x12 then
        self:start_group("adc", "ADC", 0x12, 3, ss, es, false)
      end
      grouped = self:push_group_byte(reg, value, ss, es, false)
    end

    if not grouped then
      self:finish_group()
      local otp_sel = bit_on(self.seen[0x1B] or 0, 7)
      local text = describe_byte(reg, value, write, otp_sel)
      self:putx(ss, es, write and ANN_WRITE or ANN_READ, text)
    end
    self:put(ss, es, self.out_python, { "REGISTER", reg, name, value, write })
  end,

  flush_stream = function(self)
    if #self.stream == 3
        and (not self.saw_pointer)
        and bit_on(self.seen[0x11] or 0, 6)
        and bit_on(self.seen[0x15] or 0, 7) then
      local raw = (self.stream[1] << 16) | (self.stream[2] << 8) | self.stream[3]
      local code = signed24(raw)
      self:putx(
        self.stream_ss,
        self.stream_es,
        ANN_SAMPLE,
        string.format("ADC stream %+d (0x%06X)", code, raw)
      )
      self:put(self.stream_ss, self.stream_es, self.out_python, { "ADC", raw, code })
      self.stream = {}
      return true
    end
    return false
  end,

  wait_start = function(self)
    -- START: SDA falls while SCL is high.
    self:wait({ scl = "h", sda = "f" })
    return self.samplenum
  end,

  -- Returns "byte", value, ss, es, ack  or  "start", sample  or  "stop", sample
  read_byte = function(self)
    local value = 0
    local ss = nil
    local es = nil
    for bit = 7, 0, -1 do
      local pins = self:wait({
        { scl = "r" },
        { scl = "h", sda = "f" },
        { scl = "h", sda = "r" },
      })
      local matched = self.matched or 0
      if (matched & 2) ~= 0 then
        return "start", self.samplenum
      end
      if (matched & 4) ~= 0 then
        return "stop", self.samplenum
      end
      local sda = pins[2]
      if sda == nil then
        sda = 0
      end
      if ss == nil then
        ss = self.samplenum
      end
      es = self.samplenum
      if sda ~= 0 then
        value = value | (1 << bit)
      end
    end
    local pins = self:wait({
      { scl = "r" },
      { scl = "h", sda = "f" },
      { scl = "h", sda = "r" },
    })
    local matched = self.matched or 0
    if (matched & 2) ~= 0 then
      return "start", self.samplenum
    end
    if (matched & 4) ~= 0 then
      return "stop", self.samplenum
    end
    local ack = (pins[2] or 1) == 0
    es = self.samplenum
    return "byte", value, ss, es, ack
  end,

  handle_address = function(self, value, ss, es, ack)
    local addr7 = value >> 1
    local reading = (value & 1) ~= 0
    if addr7 ~= SLAVE then
      self:putx(ss, es, ANN_WARN, string.format("ignored 0x%02X", addr7))
      return false
    end
    if not ack then
      self:putx(ss, es, ANN_WARN, "NACK address")
      return false
    end
    self.writing = not reading
    self:putx(
      ss,
      es,
      ANN_BUS,
      reading and string.format("ADDR 0x%02X R", addr7) or string.format("ADDR 0x%02X W", addr7)
    )
    if self.writing then
      self.saw_pointer = false
      self.stream = {}
      self.stream_ss = nil
      self.stream_es = nil
    end
    return true
  end,

  handle_payload = function(self, value, ss, es)
    if self.writing then
      if not self.saw_pointer then
        self.pointer = value & 0x7F
        self.saw_pointer = true
        self:putx(
          ss,
          es,
          ANN_WRITE,
          string.format("pointer %s (0x%02X)", reg_name(self.pointer), self.pointer)
        )
        return
      end
      local reg = self.pointer
      self:handle_data(reg, value, ss, es, true)
      self.pointer = (self.pointer + 1) & 0x7F
      return
    end

    if self.pointer == nil then
      if self.stream_ss == nil then
        self.stream_ss = ss
      end
      self.stream_es = es
      self.stream[#self.stream + 1] = value
      return
    end

    local reg = self.pointer
    self:handle_data(reg, value, ss, es, false)
    self.pointer = (self.pointer + 1) & 0x7F
  end,

  decode = function(self)
    while true do
      local start_sample = self:wait_start()
      self:putx(start_sample, start_sample, ANN_BUS, "START")
      self:finish_group()
      self.writing = false
      self.saw_pointer = false
      self.stream = {}
      self.stream_ss = nil
      self.stream_es = nil
      local matched = false
      local first = true

      while true do
        local kind, a, b, c, d = self:read_byte()
        if kind == "start" then
          self:putx(a, a, ANN_BUS, "Sr")
          self:finish_group()
          matched = false
          first = true
          self.writing = false
        elseif kind == "stop" then
          if not self.writing then
            self:flush_stream()
          end
          self:finish_group()
          self:putx(a, a, ANN_BUS, "STOP")
          break
        else
          local value, ss, es, ack = a, b, c, d
          if first then
            matched = self:handle_address(value, ss, es, ack)
            first = false
            if not matched then
              -- Skip the rest of this transfer until STOP/Sr.
            elseif not ack then
              break
            end
          elseif matched then
            self:handle_payload(value, ss, es)
            if not ack and not self.writing then
              self:flush_stream()
              self:finish_group()
            end
          end
        end
      end
    end
  end,
}
