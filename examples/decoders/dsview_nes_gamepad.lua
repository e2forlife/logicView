-- Adapted from DSView/libsigrokdecode nes_gamepad/pd.py.
-- Copyright (C) 2019 Stephan Thiele. GPL-2.0-or-later.
-- Stack on an SPI decoder configured for eight-bit MSB-first MISO words.
return {
  id = 'dsview_nes_gamepad', name = 'NES gamepad (Lua)',
  stack_on = 'spi', channels = {}, classes = {'button', 'no-press', 'not-connected'},
  decode = function(first, last, bit, options, context)
    local rows = {}
    local buttons = {'A', 'B', 'Select', 'Start', 'North', 'South', 'West', 'East'}
    for _, event in ipairs(context.lower) do
      local value = event.class == 'word' and event.fields.miso and tonumber(event.fields.miso, 16)
      local start = math.max(first, event.start_sample)
      local finish = math.min(last, event.end_sample)
      if value and start < finish then
        local class, message
        if value == 0xff then class, message = 'no-press', 'No button is pressed'
        elseif value == 0 then class, message = 'not-connected', 'Gamepad is not connected'
        else
          local pressed = {}
          for i, name in ipairs(buttons) do
            if (value & (1 << (8 - i))) == 0 then pressed[#pressed + 1] = name end
          end
          class, message = 'button', table.concat(pressed, ' + ')
        end
        rows[#rows + 1] = {start_sample = start, end_sample = finish, class = class, text = message}
      end
    end
    return rows
  end,
}
