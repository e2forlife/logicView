# Writing Lua decoders for LogicView

LogicView decoders turn captured digital samples or lower-level protocol events into annotations. This tutorial builds a small signal decoder, adds an option, and shows how to consume and emit events in a decoder stack. See the [README](../README.md#lua-decoders) for setup and the current list of examples.

## 1. Install and load a script

1. Choose a directory for your scripts. A blank preference uses the repository's [`examples/decoders`](../examples/decoders) directory, which contains the translated DSView decoders and the shorter tutorials.
2. Open **Preferences** using the gear in the upper right to point the Lua decoder script directory somewhere else. Save Preferences.
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

For a working settings and timing example, see [`dsview_pwm.lua`](../examples/decoders/dsview_pwm.lua).

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

`context.lower` also contains the parent's annotations, including their ranges, classes, text, and fields. Use packets for structured protocol data when the parent provides them. The existing [`dsview_rgb_led_spi.lua`](../examples/decoders/dsview_rgb_led_spi.lua) groups three MOSI words into a color, while [`dsview_adns5020.lua`](../examples/decoders/dsview_adns5020.lua) also handles chip-select changes.

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

## 7. Use the session API

Set `api_version` to `3` when a decoder should follow the same shape as a [sigrok protocol decoder](https://sigrok.org/wiki/Protocol_decoder_API). The global `logicview` table provides the output-type and metadata constants. Call methods with a colon (`self:wait()`), or with a dot (`self.wait()`); both pass the arguments through.

[`session_edges.lua`](../examples/decoders/session_edges.lua) is a complete example. A session script declares the same kind of registration metadata sigrok uses:

| Field | Role |
| --- | --- |
| `api_version` | `3` selects this host. Omitted, `1`, and `2` keep the functional `decode(first, last, bit, options, context)` callback. |
| `id`, `name`, `longname`, `desc`, `license` | Identity and the license notice stored with the script. |
| `inputs`, `outputs`, `tags` | `logic` means samples. Any other input is the parent protocol id and sets the stack parent when `stack_on` is omitted. |
| `channels`, `optional_channels` | A list of ids, or tables `{ id, name, desc }`. For version 3, omitted optional channels mean there are none. |
| `options` | `{ id, desc, default, values }`. `name` is accepted as well. Numbers and booleans are stored as strings. |
| `annotations` | `{ { "id", "Description" }, ... }`. The index in this list is the class passed to `put`. `classes` still accepts a list of ids. |
| `annotation_rows` | `{ { "id", "Label", { 0, 1 } }, ... }`. The numbers are annotation-class indexes. |
| `binary` | `{ { "id", "Description" }, ... }` for byte streams. |

The host calls `metadata`, then `start`, then `reset`, then `decode`. `metadata(self, key, value)` is called with `logicview.SRD_CONF_SAMPLERATE` when the capture has a sample rate. `start` is where the script calls `register`. `reset` clears protocol state and should leave registered output ids in place.

```lua
local lv = logicview

start = function(self)
  self.out_ann = self:register(lv.OUTPUT_ANN)
  self.out_python = self:register(lv.OUTPUT_PYTHON)
  self.out_binary = self:register(lv.OUTPUT_BINARY)
  self.out_meta = self:register(lv.OUTPUT_META, "bitrate")
end
```

`register` returns the id passed back to `put`. The four output types match sigrok:

- `OUTPUT_ANN` data is `{ class_index, { "Longest text", "Short" } }`. The first string is shown today. Further strings are kept, longest first, for a later zoom-dependent label.
- `OUTPUT_PYTHON` data is any JSON-compatible value. A list whose first item is a string becomes the packet kind, and the whole value is delivered to a stacked decoder. Register one Python output for the stack.
- `OUTPUT_BINARY` data is `{ format_index, bytes }`. `bytes` is a Lua string or a list of numbers from 0 to 255.
- `OUTPUT_META` data is a JSON-compatible value. The name passed to `register` identifies it.

`put(start_sample, end_sample, output_id, data)` uses sigrok's inclusive end. A marker on one sample uses the same number for both ends. LogicView stores that marker as the half-open range `[start_sample, end_sample + 1)`. The functional callback's returned ranges stay exclusive.

`wait` blocks until a condition matches, then sets `self.samplenum` and `self.matched` and returns the pin levels. Pins are ordered as required channels, then optional channels, one-based. A connected pin is `1` or `0`. A disconnected optional pin is `nil`.

```lua
local pins = self:wait({ [0] = "r" })       -- rising edge on the first channel
local pins = self:wait({ data = "f" })      -- falling edge by channel id
local pins = self:wait({ [0] = "h", [1] = "f" })
local pins = self:wait({ { [0] = "e" }, { skip = 100 } })
local pins = self:wait({ skip = 8 })
local pins = self:wait()                    -- the next sample
```

Terms inside one table are combined with and. A list of tables is combined with or. `self.matched` is an integer bitmask: bit 0 is set when the first condition matched, bit 1 when the second matched, and so on. `self:has_channel(index)` reports whether that zero-based channel, required channels first, is connected. The pin letters are `l`, `h`, `r`, `f`, `e`, and `n` (stable, the opposite of an edge); `0` and `1` mean low and high. `skip` counts samples forward from the previous position.

Before the first sample, `samplenum` is one less than the region start. At the beginning of a capture the previous level is the first sample, so that sample is not itself an edge. When the region starts later, the previous level is the sample just before the region. `wait` raises the end of the capture when no later sample can match; let that propagate out of `decode` so the `while true` loop stops. Output emitted before that point is kept.

A stacked session decoder implements `decode(self, start_sample, end_sample, data)` instead of calling `wait`. `start_sample` is inclusive and `end_sample` is exclusive, which is the range sigrok walks with `start_sample` through `end_sample - 1`. `data` is a list of the parent's Python outputs that overlap the region. Each item has `start_sample`, exclusive `end_sample`, `kind`, and `data`.

The host also sets `self.options`, `self.connected`, and `self.sample_rate_hz` when a rate is known.

## 8. Expose new application features here

The session host is the place to grow the decoder API. When LogicView adds a capture or interface feature a script could use, expose it on this host instead of inventing a parallel callback. Likely additions are a user-chosen initial pin level, a saved binary download, a metadata readout, annotation rows in the waveform, and streamed sample chunks. Each one should arrive as a `metadata` key, an output type, or a field on the decoder instance, next to the constants in the `logicview` table.

Binary payloads and metadata values are produced and returned to the decode pass today. The waveform stores annotation rows and passes Python packets up the stack; it does not yet show binary downloads, metadata readouts, or annotation-row layout.

## Porting a DSView decoder

Read the source decoder's channels, defaults, input and output packet formats, timing assumptions, and annotations before translating its state machine. Keep attribution and license notices from the source. A Python `decode(self)` loop that calls `self.wait()` and `self.put()` maps onto the session methods above. Translate `sigrokdecode.OUTPUT_ANN` and the other constants to `logicview.OUTPUT_ANN` and its siblings, and translate `SRD_CONF_SAMPLERATE` to `logicview.SRD_CONF_SAMPLERATE`.

`put` keeps sigrok's inclusive end. Annotation ranges returned from the functional callback, and the `end_sample` on a stacked `data` item, use LogicView's exclusive end. Decide what happens when a frame starts before or ends after the selected region. Compare results against known captures or independently constructed protocol fixtures.

The host is Lua and covers the same jobs as DSView's Python `sigrokdecode` module. A `.py` decoder still has to be translated. Built-in packet production currently covers SPI data and chip-select events. UART, I2C, and the other built-in decoders still need Python output before a stacked port can consume their bytes.
