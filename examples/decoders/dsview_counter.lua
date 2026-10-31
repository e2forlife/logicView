-- Adapted from DSView/libsigrokdecode counter/pd.py.
-- Copyright (C) 2018 Stefan Bruens. GPL-2.0-or-later.
return {
  id = 'dsview_counter', name = 'Edge counter (Lua)',
  channels = {'data', 'reset'}, optional_channels = {'reset'}, classes = {'edge_count', 'word_count', 'word_reset'},
  options = {
    {id='data_edge', name='Edges to count', default='any', values={'any', 'rising', 'falling'}},
    {id='divider', name='Word width', default='0'},
    {id='reset_edge', name='Reset edge', default='falling', values={'falling', 'rising'}},
    {id='edge_off', name='Initial edge count', default='0'},
    {id='word_off', name='Initial word count', default='0'},
    {id='dead_cycles', name='Edges ignored after reset', default='0'},
    {id='start_with_reset', name='Start with reset', default='no', values={'no', 'yes'}},
  },
  decode = function(first, last, bit, options)
    local rows = {}
    if first >= last then return rows end
    local data_edge = options.data_edge or 'any'
    local reset_edge = options.reset_edge or 'falling'
    local divider = math.max(0, math.floor(tonumber(options.divider) or 0))
    local edge_off = math.floor(tonumber(options.edge_off) or 0)
    local word_off = math.floor(tonumber(options.word_off) or 0)
    local dead_cycles = math.max(0, math.floor(tonumber(options.dead_cycles) or 0))
    local dead = options.start_with_reset == 'yes' and dead_cycles or 0
    local count, words, edge_start, word_start = edge_off, word_off, first, first
    local prev_data, prev_reset = bit('data', first), bit('reset', first)
    local function matches(old, new, edge)
      return old ~= new and (edge == 'any' or (edge == 'rising' and new) or (edge == 'falling' and not new))
    end
    local function emit(start, finish, class, value)
      if start < finish then
        rows[#rows + 1] = {start_sample = start, end_sample = finish, class = class, text = tostring(value)}
      end
    end
    for sample = first + 1, last - 1 do
      local data, reset = bit('data', sample), bit('reset', sample)
      if matches(prev_reset, reset, reset_edge) then
        count, words, edge_start, word_start, dead = edge_off, word_off, sample, sample, dead_cycles
        -- DSView emits a zero-width reset marker; LogicView requires a range.
        emit(sample, sample + 1, 'word_reset', 'Reset')
      elseif matches(prev_data, data, data_edge) then
        if dead > 0 then
          dead, edge_start, word_start = dead - 1, sample, sample
        else
          count = count + 1
          emit(edge_start, sample, 'edge_count', count)
          edge_start = sample
          if divider > 0 and (count - edge_off) % divider == 0 then
            words = words + 1
            emit(word_start, sample, 'word_count', words)
            word_start = sample
          end
        end
      end
      prev_data, prev_reset = data, reset
    end
    return rows
  end,
}
