-- Nuvoton NAU7802 24-bit bridge ADC (datasheet Rev 2.6).
-- Stacks on an I2C parent that emits START / ADDRESS / DATA / STOP packets.
-- Slave address is fixed at 0x2A (unshifted write 0x54, read 0x55).

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
  [0] = "4.5V",
  [1] = "4.2V",
  [2] = "3.9V",
  [3] = "3.6V",
  [4] = "3.3V",
  [5] = "3.0V",
  [6] = "2.7V",
  [7] = "2.4V",
}

local PGA = {
  [0] = "x1",
  [1] = "x2",
  [2] = "x4",
  [3] = "x8",
  [4] = "x16",
  [5] = "x32",
  [6] = "x64",
  [7] = "x128",
}

local CRS = {
  [0] = "10SPS",
  [1] = "20SPS",
  [2] = "40SPS",
  [3] = "80SPS",
  [7] = "320SPS",
}

local CALMOD = {
  [0] = "offset internal",
  [1] = "reserved",
  [2] = "offset system",
  [3] = "gain system",
}

local MASTER_BIAS = {
  [0] = "100%",
  [1] = "90%",
  [2] = "80%",
  [3] = "73%",
  [4] = "67%",
  [5] = "62%",
  [6] = "58%",
  [7] = "54%",
}

local ADC_CURR = {
  [0] = "100%",
  [1] = "75%",
  [2] = "50%",
  [3] = "25%",
}

local PGA_CURR = {
  [0] = "100%",
  [1] = "95%",
  [2] = "86%",
  [3] = "70%",
}

local function bit_on(value, bit)
  return (value & (1 << bit)) ~= 0
end

local function reg_name(reg)
  return REG_NAMES[reg] or string.format("REG0x%02X", reg)
end

local function packet_byte(packet)
  local data = packet.data
  if type(data) ~= "table" then
    return nil
  end
  local value = data[2]
  if type(value) == "number" then
    return value & 0xFF
  end
  return nil
end

local function is_slave(addr)
  if addr == SLAVE then
    return true
  end
  if (addr >> 1) == SLAVE then
    return true
  end
  return false
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
  local rate = CRS[(value >> 4) & 7] or "reserved"
  return string.format(
    "CTRL2 CHS=%s CRS=%s CAL_ERR=%d CALS=%d CALMOD=%s",
    bit_on(value, 7) and "Ch2" or "Ch1",
    rate,
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
  local label = otp_sel and "OTP[31:24]" or "ADC_CTRL"
  return string.format(
    "%s FRD_EN=%d REG_CHPS=%d ADC_VCM=%d REG_CHP=%d",
    label,
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
  local name = reg_name(reg)
  local hex = string.format("0x%02X", value)
  if reg == 0x00 then
    return describe_pu_ctrl(value)
  elseif reg == 0x01 then
    return describe_ctrl1(value)
  elseif reg == 0x02 then
    return describe_ctrl2(value)
  elseif reg == 0x11 then
    return describe_i2c_ctrl(value)
  elseif reg == 0x15 then
    return describe_adc_ctrl(value, (not write) and otp_sel)
  elseif reg == 0x1B then
    return describe_pga_ctrl(value)
  elseif reg == 0x1C then
    return describe_pwr_ctrl(value)
  elseif reg == 0x1F then
    return string.format("REV_ID 0x%X", value & 0x0F)
  elseif reg >= 0x12 and reg <= 0x14 then
    return string.format("%s %s", name, hex)
  elseif reg >= 0x16 and reg <= 0x17 then
    return string.format("%s %s", name, hex)
  else
    return string.format("%s %s", name, hex)
  end
end

local function clip(first, last, ss, es)
  local start = math.max(ss, first)
  local finish = math.min(es, last)
  if start < finish then
    return start, finish
  end
  return nil, nil
end

local function emit_row(rows, first, last, ss, es, class, text, fields)
  local start, finish = clip(first, last, ss, es)
  if start == nil then
    return
  end
  rows[#rows + 1] = {
    start_sample = start,
    end_sample = finish,
    class = class,
    text = text,
    fields = fields or {},
  }
end

local function emit_register(packets, first, last, ss, es, reg, name, value, write)
  local start, finish = clip(first, last, ss, es)
  if start == nil then
    return
  end
  packets[#packets + 1] = {
    start_sample = start,
    end_sample = finish,
    kind = "REGISTER",
    data = {
      reg = reg,
      name = name,
      value = value,
      write = write,
    },
  }
end

local function emit_adc(packets, first, last, ss, es, raw, code)
  local start, finish = clip(first, last, ss, es)
  if start == nil then
    return
  end
  packets[#packets + 1] = {
    start_sample = start,
    end_sample = finish,
    kind = "ADC",
    data = {
      raw = raw,
      code = code,
    },
  }
end

return {
  id = "nau7802",
  name = "NAU7802",
  longname = "Nuvoton NAU7802",
  desc = "Nuvoton NAU7802 24-bit bridge ADC over I2C.",
  license = "gplv3+",
  inputs = { "i2c" },
  outputs = { "nau7802" },
  tags = { "IC", "Sensor" },
  stack_on = "i2c",
  channels = {},
  classes = { "write", "read", "sample", "warning" },

  decode = function(first, last, bit, options, context)
    local rows = {}
    local out_packets = {}
    local state = "idle"
    local pointer = nil
    local write = false
    local matched = false
    local saw_pointer = false
    local data_bytes = {}
    local data_ss = nil
    local data_es = nil
    local last_i2c = {
      [0x11] = 0,
      [0x15] = 0,
      [0x1B] = 0,
    }
    local group = nil

    local function reset_txn()
      state = "idle"
      write = false
      matched = false
      saw_pointer = false
      data_bytes = {}
      data_ss = nil
      data_es = nil
      group = nil
    end

    local function next_pointer()
      if pointer == nil then
        return
      end
      pointer = (pointer + 1) & 0x7F
    end

    local function finish_group()
      if group == nil then
        return
      end
      if #group.bytes < group.need then
        group = nil
        return
      end
      local raw = 0
      for i = 1, #group.bytes do
        raw = (raw << 8) | group.bytes[i]
      end
      local text
      if group.kind == "offset" then
        text = string.format(
          "%s offset %+d (0x%06X)",
          group.label,
          offset_sign_mag(raw),
          raw
        )
      elseif group.kind == "gain" then
        text = string.format(
          "%s gain %.6f (0x%08X)",
          group.label,
          raw / (1 << 23),
          raw
        )
      elseif group.kind == "adc" then
        local code = signed24(raw)
        text = string.format("ADC %+d (0x%06X)", code, raw)
        emit_adc(out_packets, first, last, group.ss, group.es, raw, code)
        emit_row(rows, first, last, group.ss, group.es, "sample", text, {
          raw = string.format("%06X", raw),
          code = tostring(code),
        })
        group = nil
        return
      else
        group = nil
        return
      end
      emit_row(rows, first, last, group.ss, group.es, group.write and "write" or "read", text, {
        reg = string.format("%02X", group.base),
        value = string.format("%0" .. (group.need * 2) .. "X", raw),
      })
      group = nil
    end

    local function start_group(kind, label, base, need, ss, es, is_write)
      finish_group()
      group = {
        kind = kind,
        label = label,
        base = base,
        need = need,
        bytes = {},
        ss = ss,
        es = es,
        write = is_write,
      }
    end

    local function push_group_byte(reg, value, ss, es, is_write)
      if group ~= nil
          and group.write == is_write
          and #group.bytes < group.need
          and reg == ((group.base + #group.bytes) & 0x7F) then
        group.bytes[#group.bytes + 1] = value
        group.es = es
        if #group.bytes == group.need then
          finish_group()
        end
        return true
      end
      return false
    end

    local function handle_data(reg, value, ss, es, is_write)
      local name = reg_name(reg)
      if is_write then
        if reg == 0x11 or reg == 0x15 or reg == 0x1B then
          last_i2c[reg] = value
        end
      end

      local grouped = false
      if reg >= 0x03 and reg <= 0x05 then
        if reg == 0x03 then
          start_group("offset", "CH1", 0x03, 3, ss, es, is_write)
        end
        grouped = push_group_byte(reg, value, ss, es, is_write)
      elseif reg >= 0x0A and reg <= 0x0C then
        if reg == 0x0A then
          start_group("offset", "CH2", 0x0A, 3, ss, es, is_write)
        end
        grouped = push_group_byte(reg, value, ss, es, is_write)
      elseif reg >= 0x06 and reg <= 0x09 then
        if reg == 0x06 then
          start_group("gain", "CH1", 0x06, 4, ss, es, is_write)
        end
        grouped = push_group_byte(reg, value, ss, es, is_write)
      elseif reg >= 0x0D and reg <= 0x10 then
        if reg == 0x0D then
          start_group("gain", "CH2", 0x0D, 4, ss, es, is_write)
        end
        grouped = push_group_byte(reg, value, ss, es, is_write)
      elseif (not is_write) and reg >= 0x12 and reg <= 0x14 then
        if reg == 0x12 then
          start_group("adc", "ADC", 0x12, 3, ss, es, false)
        end
        grouped = push_group_byte(reg, value, ss, es, false)
      end

      if not grouped then
        finish_group()
        local otp_sel = bit_on(last_i2c[0x1B] or 0, 7)
        local text = describe_byte(reg, value, is_write, otp_sel)
        emit_row(rows, first, last, ss, es, is_write and "write" or "read", text, {
          reg = string.format("%02X", reg),
          value = string.format("%02X", value),
          data = string.format("%02X", value),
        })
      end

      emit_register(out_packets, first, last, ss, es, reg, name, value, is_write)
    end

    local function flush_stream_read()
      if #data_bytes == 3
          and (not saw_pointer)
          and bit_on(last_i2c[0x11] or 0, 6)
          and bit_on(last_i2c[0x15] or 0, 7) then
        local raw = (data_bytes[1] << 16) | (data_bytes[2] << 8) | data_bytes[3]
        local code = signed24(raw)
        local text = string.format("ADC stream %+d (0x%06X)", code, raw)
        emit_adc(out_packets, first, last, data_ss, data_es, raw, code)
        emit_row(rows, first, last, data_ss, data_es, "sample", text, {
          raw = string.format("%06X", raw),
          code = tostring(code),
        })
        data_bytes = {}
        return true
      end
      return false
    end

    local packets = context and context.packets or {}
    for _, packet in ipairs(packets) do
      local kind = packet.kind
      local ss = packet.start_sample
      local es = packet.end_sample
      if kind == "BITS" then
        goto continue
      end
      if kind == "START" or kind == "START REPEAT" then
        if kind == "START" then
          finish_group()
          reset_txn()
        else
          finish_group()
          data_bytes = {}
          data_ss = nil
          data_es = nil
        end
        state = "address"
      elseif kind == "STOP" then
        if not write then
          flush_stream_read()
        end
        finish_group()
        reset_txn()
      elseif kind == "NACK" then
        if state == "ack_address" then
          finish_group()
          reset_txn()
        elseif state == "data" and (not write) then
          if not flush_stream_read() then
            -- ordinary end of a read burst
          end
          finish_group()
          state = "idle"
        end
      elseif kind == "ACK" then
        if state == "ack_address" then
          if write then
            state = saw_pointer and "data" or "pointer"
          else
            state = "data"
          end
        end
      elseif kind == "ADDRESS WRITE" or kind == "ADDRESS READ" then
        local addr = packet_byte(packet)
        if addr == nil or (not is_slave(addr)) then
          matched = false
          state = "idle"
        else
          matched = true
          write = (kind == "ADDRESS WRITE")
          state = "ack_address"
          if write and kind == "ADDRESS WRITE" then
            saw_pointer = false
          end
        end
      elseif matched and (kind == "DATA WRITE" or kind == "DATA READ") then
        local value = packet_byte(packet)
        if value == nil then
          goto continue
        end
        if state == "pointer" and kind == "DATA WRITE" then
          pointer = value & 0x7F
          saw_pointer = true
          emit_row(rows, first, last, ss, es, "write",
            string.format("pointer %s (0x%02X)", reg_name(pointer), pointer), {
              reg = string.format("%02X", pointer),
              data = string.format("%02X", pointer),
            })
          state = "data"
        elseif state == "data" then
          if pointer == nil and kind == "DATA READ" then
            if data_ss == nil then
              data_ss = ss
            end
            data_es = es
            data_bytes[#data_bytes + 1] = value
          elseif pointer ~= nil then
            local reg = pointer
            handle_data(reg, value, ss, es, kind == "DATA WRITE")
            next_pointer()
          end
        end
      end
      ::continue::
    end

    finish_group()
    return {
      annotations = rows,
      packets = out_packets,
    }
  end,
}
