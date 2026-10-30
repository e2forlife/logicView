-- Example: mark each high interval on one input.
return {
  id = "high_pulses",
  name = "High pulses (Lua)",
  channels = { "signal" },
  classes = { "data" },
  decode = function(start_sample, end_sample, bit, options)
    local rows = {}
    local start = nil
    for sample = start_sample, end_sample - 1 do
      if bit("signal", sample) then
        if start == nil then start = sample end
      elseif start ~= nil then
        rows[#rows + 1] = { start_sample = start, end_sample = sample,
          class = "data", text = "High", fields = { level = "1" } }
        start = nil
      end
    end
    if start ~= nil then
      rows[#rows + 1] = { start_sample = start, end_sample = end_sample,
        class = "data", text = "High", fields = { level = "1" } }
    end
    return rows
  end,
}
