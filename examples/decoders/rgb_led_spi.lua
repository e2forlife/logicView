-- Adapted from DSView/libsigrokdecode rgb_led_spi/pd.py.
-- Copyright (C) 2014 Matt Ranostay. GPL-2.0-or-later.
-- Stack on an SPI decoder configured for eight-bit MOSI words.
return {
  id = 'dsview_rgb_led_spi', name = 'RGB LED SPI (Lua)',
  stack_on = 'spi', channels = {}, classes = {'rgb'},
  decode = function(first, last, bit, options, context)
    local rows, bytes, start = {}, {}, nil
    for _, event in ipairs(context.packets) do
      local value = event.kind == 'DATA' and event.data.mosi
      if type(value) ~= 'number' then value = nil end
      if value and event.start_sample >= first and event.end_sample <= last then
        if #bytes == 0 then start = event.start_sample end
        bytes[#bytes + 1] = value
        if #bytes == 3 then
          rows[#rows + 1] = {start_sample = start, end_sample = event.end_sample,
            class = 'rgb', text = string.format('#%02x%02x%02x', bytes[1], bytes[2], bytes[3])}
          bytes = {}
        end
      end
    end
    return rows
  end,
}
