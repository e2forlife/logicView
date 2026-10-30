-- Adapted from DSView/libsigrokdecode adns5020/pd.py.
-- GPL-2.0-or-later; see the original decoder for its copyright notices.
-- Requires eight-bit MOSI words and an active-low SPI chip select.
local regs = {[0]='Product_ID', 'Revision_ID', 'Motion', 'Delta_X', 'Delta_Y',
  'SQUAL', 'Shutter_Upper', 'Shutter_Lower', 'Maximum_Pixel', 'Pixel_Sum',
  'Minimum_Pixel', 'Pixel_Grab', [0x0d]='Mouse_Control', [0x3a]='Chip_Reset',
  [0x3f]='Inv_Rev_ID', [0x63]='Motion_Burst'}
return {
  id = 'dsview_adns5020', name = 'ADNS-5020 (Lua)', stack_on = 'spi',
  channels = {}, classes = {'read', 'write', 'warning'},
  decode = function(first, last, bit, options, context)
    local rows, command, start = {}, nil, nil
    for _, packet in ipairs(context.packets) do
      if packet.start_sample >= first and packet.end_sample <= last then
        if packet.kind == 'CS-CHANGE' and packet.data.old == false and packet.data.new == true then
          if command then
            rows[#rows + 1] = {start_sample=start, end_sample=packet.end_sample, class='warning', text='Misplaced CS#!'}
            command = nil
          end
        elseif packet.kind == 'DATA' and type(packet.data.mosi) == 'number' then
          local value = packet.data.mosi
          if command == nil then command, start = value, packet.start_sample
          else
            local reg = command & 0x7f
            local name = regs[reg] or (reg > 0x63 and 'Unknown' or string.format('Reserved 0x%x', reg))
            rows[#rows + 1] = {start_sample=start, end_sample=packet.end_sample,
              class=(command & 0x80 ~= 0) and 'write' or 'read',
              text=string.format('%s: 0x%02X', name, value),
              fields={register=string.format('%02X',reg), value=string.format('%02X',value)}}
            command = nil
          end
        end
      end
    end
    return rows
  end,
}
