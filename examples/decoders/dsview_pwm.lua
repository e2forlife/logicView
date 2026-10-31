-- Adapted from DSView/libsigrokdecode pwm/pd.py.
-- Copyright (C) 2014 Torsten Duwe and Sebastien Bourdelin. GPL-2.0-or-later.
-- Capture sample rate is unavailable to Lua, so period is in samples.
return {
  id = 'dsview_pwm', name = 'PWM duty cycle (Lua)',
  channels = {'data'}, classes = {'duty-cycle', 'period'},
  options = {{id='polarity', name='Polarity', default='active-high', values={'active-high', 'active-low'}}},
  decode = function(first, last, bit, options, context)
    local rows = {}
    if first >= last then return rows end
    local active = options.polarity ~= 'active-low'
    local prev, start, middle = bit('data', first), nil, nil
    for sample = first + 1, last - 1 do
      local value = bit('data', sample)
      if value ~= prev then
        if value == active then
          if start and middle then
            local period = sample - start
            local ratio = (middle - start) / period
            rows[#rows + 1] = {start_sample = start, end_sample = sample,
              class = 'duty-cycle', text = string.format('%.6f%%', 100 * ratio)}
            rows[#rows + 1] = {start_sample = start, end_sample = sample,
              class = 'period', text = context.sample_rate_hz and string.format('%.9g s', period / context.sample_rate_hz) or (tostring(period) .. ' samples')}
          end
          start, middle = sample, nil
        elseif start then
          middle = sample
        end
      end
      prev = value
    end
    return rows
  end,
}
