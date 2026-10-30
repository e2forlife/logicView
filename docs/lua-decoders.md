# Writing Lua decoders for LogicView

LogicView decoders turn captured digital samples or lower-level protocol events into annotations. This tutorial builds a small signal decoder, adds an option, and shows how to consume and emit events in a decoder stack. See the [README](../README.md#lua-decoders) for setup and the current list of examples.

## 1. Install and load a script

1. Choose a directory for your scripts. The repository's [`examples/decoders`](../examples/decoders) directory contains working examples.
2. Open **Preferences** using the gear in the upper right and set the Lua decoder script directory to that directory. Save Preferences.
3. Add your decoder from the Decode panel or menu, open its configuration, and map its signal roles to captured channels. Run a capture or use an existing capture to see its annotations.

LogicView discovers `.lua` files directly in the configured directory at startup and when Preferences are saved. Save Preferences again after adding or changing a script to refresh the catalog. A script returns a Lua table; its `id` must be unique, nonempty, and contain only ASCII letters, digits, underscores, or hyphens. Built-in decoder IDs take precedence. Give your script a distinct ID such as `tutorial_high_pulses`.

## 2. Decode a digital signal

Save this as `tutorial_high_pulses.lua` in the configured directory:

```lua
return {
  id = "tutorial_high_pulses",
  name = "Tutorial high pulses",
  channels = { "signal" },
  classes = { "pulse" },

  decode = function(first, last, bit, options, context)
    local rows = {}
    local pulse_start = nil

    local function emit(finish)
      rows[#rows + 1] = {
        start_sample = pulse_start,
        end_sample = finish,
        class = "pulse",
        text = "High",
        fields = { level = "1" },
      }
    end

    for sample = first, last - 1 do
      if bit("signal", sample) then
        if pulse_start == nil then pulse_start = sample end
      elseif pulse_start ~= nil then
        emit(sample)
        pulse_start = nil
      end
    end
    if pulse_start ~= nil then emit(last) end
    return rows
  end,
}
```

The `channels` entries are names used both for channel mapping and in `bit`. `classes` lists the annotation categories exposed by the decoder. The `decode` function receives an absolute, zero-based sample range `[first, last)`: the start is included and the end is excluded. `bit(name, sample)` returns a Boolean. A disconnected input reads low, so use `context.connected[name]` when the distinction matters.

An annotation contains `start_sample`, `end_sample`, `class`, and `text`. Its optional `fields` table maps strings to strings and can carry values for searching or a stacked decoder. Every annotation must satisfy `first <= start_sample < end_sample <= last`. For example, a pulse high at samples 2, 3, and 4 is represented by `start_sample = 2, end_sample = 5`. An invalid annotation causes the decode run to fail.

The example treats a high signal at the beginning or end of the selected region as a partial pulse. Choose and document the boundary behavior appropriate to your protocol. Each decode call starts fresh, so do not assume state survives a rerun or another selected region.

## 3. Add channel metadata and options

A script can declare optional channels and settings in its returned table:

```lua
channels = { "data", "enable" },
optional_channels = { "enable" },
options = {
  { id = "polarity", name = "Polarity", default = "high",
    values = { "high", "low" } },
  { id = "minimum_samples", name = "Minimum width in samples", default = "1" },
},
```

Add these fields to your decoder's table and use them from `decode`:

```lua
local active_high = options.polarity == "high"
local minimum = tonumber(options.minimum_samples) or 1
local enable_connected = context.connected.enable == true
```

Option defaults and values are strings. A `values` list produces a selection control; an option without one produces a text control. Convert numeric values with `tonumber` and validate their range in the script. LogicView passes defaults merged with the instance's configured options. `optional_channels` describes channel metadata; check `context.connected` yourself when a required signal is needed, because an unmapped signal otherwise reads low. When `optional_channels` is omitted, the current script runtime marks all listed channels optional.

`context.sample_rate_hz` is the capture rate in samples per second when available. Check it before converting sample counts to time:

```lua
local seconds = context.sample_rate_hz and width_samples / context.sample_rate_hz
```

For a working settings and timing example, see [`pwm.lua`](../examples/decoders/pwm.lua).

## 4. Consume a lower-level decoder

A stacked decoder declares the protocol ID it expects in `stack_on`. Add and configure the parent decoder first, then add the stacked decoder and select the parent instance in its settings. The current built-in SPI decoder exposes `DATA` packets containing numeric `data.mosi` and `data.miso` values when those lines are mapped. It also exposes `CS-CHANGE` packets with Boolean `old`, `new`, and `selected` values.

For example, this decoder displays each SPI MOSI word:

```lua
return {
  id = "tutorial_spi_words",
  name = "Tutorial SPI words",
  stack_on = "spi",
  channels = {},
  classes = { "word" },
  decode = function(first, last, bit, options, context)
    local rows = {}
    for _, packet in ipairs(context.packets) do
      local value = packet.data.mosi
      if packet.kind == "DATA" and type(value) == "number"
          and packet.start_sample >= first and packet.end_sample <= last then
        rows[#rows + 1] = {
          start_sample = packet.start_sample,
          end_sample = packet.end_sample,
          class = "word",
          text = string.format("0x%02X", value),
          fields = { value = string.format("%02X", value) },
        }
      end
    end
    return rows
  end,
}
```

The range check matters because a parent's region can differ from its child's. Decide whether to skip, clip, or reassemble events at a region boundary; never return an annotation outside the child's range. Test packet data types: missing SPI data lines are represented as null, not numeric zero.

`context.lower` also contains the parent's annotations, including their ranges, classes, text, and fields. Use packets for structured protocol data when the parent provides them. The existing [`rgb_led_spi.lua`](../examples/decoders/rgb_led_spi.lua) groups three MOSI words into a color, while [`adns5020.lua`](../examples/decoders/adns5020.lua) also handles chip-select changes.

## 5. Produce packets for another layer

Return a wrapper table when your decoder needs to produce packets in addition to annotations:

```lua
return {
  annotations = {
    { start_sample = first, end_sample = last,
      class = "message", text = "Message 42" },
  },
  packets = {
    { start_sample = first, end_sample = last, kind = "MESSAGE",
      data = { value = 42, valid = true, bytes = { 1, 2, 3 } } },
  },
}
```

This example assumes `first < last`. Packet ranges follow the same bounds as annotations, and `kind` must be a nonempty string. `data` is JSON-compatible and can contain nested objects, arrays, strings, numbers, and Booleans. A child whose `stack_on` names this decoder's ID reads the packets through `context.packets`. Document the packet kinds and their fields so child decoders can interpret them consistently.

## 6. Test and troubleshoot

- Test known input patterns, both polarities where applicable, disconnected optional inputs, incomplete frames, and transitions at the edges of the selected region. Check exact ranges as well as text and fields.
- For stacked decoders, test multiple parent instances, missing data lines, packet ordering, and a child region narrower than its parent's region.
- The Rust tests in [`script.rs`](../crates/logicview-decode/src/script.rs) demonstrate loading Lua modules and running synthetic sample and packet inputs. Run `cargo test -p logicview-decode` from the repository root.
- If a decoder is missing, check its ID, Lua syntax, script directory, and Preferences refresh. If it produces no rows, check channel bindings, parent selection, capture region, and the application logs. Script errors are logged and the failed run yields no annotations.
- The runtime limits Lua memory and instructions. It exposes a limited set of standard libraries; scripts should not depend on arbitrary file, process, or network access. Avoid unnecessary per-sample work and excessive output on large captures.

## Porting a DSView decoder

Read the source decoder's channels, defaults, input and output packet formats, timing assumptions, and annotations before translating its state machine. Keep attribution and license notices from the source. Map DSView sample positions to LogicView's absolute, exclusive-end ranges, and decide what happens when a frame starts before or ends after the selected region. Compare results against known captures or independently constructed protocol fixtures.

LogicView's Lua API is not a drop-in implementation of DSView's Python `sigrokdecode` API. In particular, the current interface does not provide DSView's `wait`, `put`, and `register` methods or all of its packet types. Built-in packet production currently covers SPI data and chip-select events; other built-in protocols do not yet supply equivalent typed streams. Some ports therefore need additional runtime or parent-decoder work before they can reproduce all DSView behavior.
