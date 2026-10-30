-- Adapted from DSView/libsigrokdecode stepper_motor/pd.py.
-- Copyright (C) 2015 Petteri Aimonen. GPL-2.0-or-later.
-- Position starts at zero at the beginning of the requested region.
return {
  id = 'dsview_stepper_motor', name = 'Stepper motor (Lua)',
  channels = {'step', 'dir'}, classes = {'position', 'speed'},
  options = {
    {id='unit', name='Unit', default='steps', values={'steps', 'mm'}},
    {id='steps_per_mm', name='Steps per mm', default='100'},
  },
  decode = function(start_sample, end_sample, bit, options, context)
    local rows, position, previous = {}, 0, nil
    local scale = options.unit == 'mm' and (tonumber(options.steps_per_mm) or 100) or 1
    if scale <= 0 then return rows end
    local unit = options.unit == 'mm' and 'mm' or 'steps'
    local function format(value) return unit == 'mm' and string.format('%.2f', value) or string.format('%.0f', value) end
    if start_sample >= end_sample then return rows end
    local old_step = bit('step', start_sample)
    for sample = start_sample + 1, end_sample - 1 do
      local step = bit('step', sample)
      if step and not old_step then
        if previous then
          if context.sample_rate_hz and context.sample_rate_hz > 0 then
            rows[#rows + 1] = {start_sample = previous, end_sample = sample,
              class = 'speed', text = format(context.sample_rate_hz / (sample - previous) / scale) .. ' ' .. unit .. '/s'}
          end
          rows[#rows + 1] = {start_sample = previous, end_sample = sample,
            class = 'position', text = format(position / scale) .. ' ' .. unit,
            fields = {steps = tostring(position)}}
        end
        position = position + (bit('dir', sample) and 1 or -1)
        previous = sample
      end
      old_step = step
    end
    return rows
  end,
}
