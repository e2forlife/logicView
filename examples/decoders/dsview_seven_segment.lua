-- Adapted from DSView/libsigrokdecode seven_segment/pd.py.
-- Copyright (C) 2019 Benedikt Otto. GPL-2.0-or-later.
-- Default DSView polarity: common cathode (active high).
local digits = {
  [0x00] = ' ', [0x3f] = '0', [0x06] = '1', [0x5b] = '2',
  [0x4f] = '3', [0x66] = '4', [0x6d] = '5', [0x7d] = '6',
  [0x07] = '7', [0x7f] = '8', [0x6f] = '9', [0x77] = 'A',
  [0x7c] = 'B', [0x39] = 'C', [0x5e] = 'D', [0x79] = 'E', [0x71] = 'F',
}
local pins = {'a', 'b', 'c', 'd', 'e', 'f', 'g'}
return {
  id = 'dsview_seven_segment', name = '7-segment display (Lua)',
  channels = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'dp'},
  optional_channels = {'dp'}, classes = {'decoded-digit'},
  options = {{id='polarity', name='Polarity', default='common-cathode', values={'common-cathode', 'common-anode'}}},
  decode = function(start_sample, end_sample, bit, options, context)
    local rows = {}
    if start_sample >= end_sample then return rows end
    local invert = options.polarity == 'common-anode'
    local function read(sample)
      local value = 0
      for i, pin in ipairs(pins) do
        if bit(pin, sample) ~= invert then value = value | (1 << (i - 1)) end
      end
      local dp = bit('dp', sample)
      if not context.connected.dp then dp = false elseif invert then dp = not dp end
      return value, dp
    end
    local value, dp = read(start_sample)
    local first = start_sample
    local function emit(last)
      local digit = digits[value]
      if digit then
        rows[#rows + 1] = {start_sample = first, end_sample = last,
          class = 'decoded-digit', text = digit .. (dp and '.' or '')}
      end
    end
    for sample = start_sample + 1, end_sample - 1 do
      local next_value, next_dp = read(sample)
      if next_value ~= value or next_dp ~= dp then
        emit(sample)
        first, value, dp = sample, next_value, next_dp
      end
    end
    emit(end_sample)
    return rows
  end,
}
