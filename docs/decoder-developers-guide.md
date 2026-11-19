# Decoder developers guide

This is the reference for writing a LogicView decoder in Lua. Use it to turn a component datasheet into a script: pin names, timing, registers, and packet formats. A shorter walkthrough is in the [Lua decoder tutorial](lua-decoders.md). Setup and the script directory are in the [README](../README.md#lua-decoders).

Implement the protocol from the published datasheet and from this interface. Do not copy, translate, or mechanically rewrite another application's decoder script or test vectors. [Contributing](../CONTRIBUTING.md) states the same clean-room rule. Build tests from timing diagrams and bit fields you derive yourself.

A decoder reads captured samples, or packets from a lower-level decoder, and emits annotations. An annotation is a labeled span of samples. A packet is a structured event that a decoder stacked on top of this one can read. Users add the decoder from the Decode panel, map its channel names to captured lines, and set its options.

## From a datasheet to a script

Work through the datasheet in this order.

1. **Pins.** Each wire the decoder samples becomes a channel id (`sck`, `sda`, `cs`). Required wires go in `channels`. Wires the part can leave disconnected go in `optional_channels`. The settings dialog maps `channels` only, and it labels each row with the channel id, so use ids a user will recognize from the pin table.
2. **Bus or bare wires.** If the part is a SPI, I2C, or UART device, do not resample the bus. Set `inputs` to that protocol (`"spi"`, `"i2c"`, or `"uart"`) and consume the parent decoder's packets. If the part has its own timing on one or more logic lines, set `inputs` to `{ "logic" }` and walk edges with `wait`.
3. **Timing diagram.** Each edge, level, and bit time becomes a `wait` condition. Convert times to sample counts with `self.sample_rate_hz` when the diagram is in seconds.
4. **Registers, commands, and status bits.** Each kind of event becomes an annotation class. Put the value a user will search for in the annotation text. On the callback host, also put it in string `fields`. On the session host, `put` does not attach fields; the visible text is what search sees, and a stacked child reads Python packets rather than fields.
5. **Variants.** Address pins, bit order, word size, resolution, and polarity become `options`. Give each one the datasheet's choices in `values` when the set is closed.
6. **A decoder above this one.** Set `outputs` to the protocol id a child will name in `inputs`. Emit one Python packet per event and document `kind` and the fields inside `data`.

Then pick a host, write the registration table, and test the ranges at the edges of the capture.

## Where scripts load

LogicView reads `.lua` files directly in the decoder script directories. It does not look in subdirectories. A blank preference uses [`examples/decoders`](../examples/decoders), found from the source tree, the working directory, or beside the executable. That folder holds the translated DSView ports kept with the source tree. LogicView also loads [`decoders`](../decoders) when present; that is the homebrew set shipped in the release. An explicit preference replaces `examples/decoders` and still adds `decoders/` when it exists. Files are loaded when the application starts and again when Preferences are saved.

The script returns one table. `id` is required, unique, and nonempty. It may contain only ASCII letters, digits, `_`, `-`, and `:`. `name` is the label in the decoder list and is required. Built-in ids `uart`, `i2c`, `spi`, and `eeprom24` take precedence over a script with the same id. A script that fails to load is omitted from the catalog; the error is printed to stderr. Save Preferences after adding or editing a file so the list refreshes.

Each decode pass loads the file again. Nothing you store on the decoder table survives the next pass or another selected region.

## Which host to use

Two hosts share the same registration table.

| `api_version` | Host | `decode` signature |
| --- | --- | --- |
| Omitted, `1`, or `2` | Callback | `decode(first, last, bit, options, context)` |
| `3` or higher | Session | Signal: `decode(self)`. Stacked: `decode(self, start_sample, end_sample, data)` |

Use the session host when the datasheet is an edge-timed state machine: you wait for a start condition, then clock edges, then a stop. Use the callback when you scan levels across the range, or when you only reshape packets from a parent and do not need `wait`.

`api_version` must be a non-negative integer. Any value of 3 or higher selects the session host.

## Registration table

The returned table is the catalog entry and the decoder instance. The session host writes `options`, `samplenum`, `matched`, `connected`, `sample_rate_hz`, `wait`, `put`, `register`, and `has_channel` onto that same table before calling your methods. Read option values from `self.options`. Do not treat `self.options` as the declaration list during `decode`.

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Stable protocol id. See the character rules above. |
| `name` | yes | Name shown in the decoder list. |
| `longname` | no | Longer name stored with the script. |
| `desc` | no | One-line description. The protocol search matches this text. |
| `license` | no | License notice stored with the script. |
| `inputs` | no | `"logic"` for sampled wires. Any other string is a parent protocol id. |
| `outputs` | no | Protocol ids this decoder produces. A child whose input names one of these can stack here. |
| `tags` | no | List of strings. The protocol search matches them, for example `"Sensor"`. |
| `channels` | no | Required inputs. A string id, or `{ id = "sck", name = "SCK", desc = "Serial clock" }`. `name` and `desc` default to the id. |
| `optional_channels` | no | Same shape as `channels`. |
| `stack_on` | no | Parent protocol id. When omitted, the first `inputs` entry other than `"logic"` is used. |
| `options` | no | List of `{ id, desc or name, default, values }`. |
| `annotations` or `classes` | no | Annotation classes. `annotations` wins when it is a table. |
| `annotation_rows` | no | Display groups. Accepted and not shown yet. |
| `binary` | no | Named byte streams. Accepted and not shown yet. |

`inputs` decides the parent. A signal decoder's only input is `"logic"`. A stacked decoder's input is the parent protocol, such as `"spi"`. If you list both, the first entry that is not `"logic"` becomes the parent and the session host calls the stacked `decode`. Set `stack_on` only when you need to override that.

For `api_version` 3 and higher, omitting `optional_channels` means there are none. For older scripts, omitting it marks every channel optional. The settings dialog still only offers rows for `channels`. A pin the user must be able to map belongs in `channels`. Check `connected` or `has_channel` before trusting an optional pin; an unmapped pin reads as disconnected, not as a default level you chose.

An option with `values` is a dropdown. Without `values` it is a text field. The dialog label is `name`, then `desc`, then `id`. Numbers and booleans in `default` and `values` are stored in the catalog as strings. What `decode` receives depends on the host and is described below.

Annotation classes:

- `"pulse"` uses that string as the id.
- `{ "pulse", "High interval" }` uses the first string as the id and the second as the description.
- `{ id = "pulse", desc = "High interval" }` is the same.
- `{ "7", "start", "Start condition" }` is the three-string form used by ported scripts: when the first string is all digits, the id is the second string and the description is the third.

The index of a class in this list is the number you pass to session `put`. The id is what the callback stores in `class` and what the table shows.

`annotation_rows` entries are `{ "id", "Label", { 0, 1 } }` or `{ id = "id", name = "Label", classes = { 0, 1 } }`. The numbers are indexes into the class list. `binary` entries use the same shapes as annotation classes.

## Callback host

```lua
decode = function(first, last, bit, options, context)
  -- return a list of annotations, or { annotations = {...}, packets = {...} }
end
```

`first` is included and `last` is excluded. Both are absolute sample indexes. `bit(name, sample)` returns a Boolean. A channel that is not connected reads low, including an index past the capture. Use `context.connected[name] == true` when low and disconnected must be different.

`options` is a string-to-string map of the declared defaults overwritten by the instance's settings. Convert numbers with `tonumber` and check the range yourself.

`context.sample_rate_hz` is the capture rate in samples per second, or nil when the session has none. `context.lower` is the parent instance's annotations (ranges, class, text, texts, fields). `context.packets` is the parent's packets.

Return a list:

```lua
{
  start_sample = first,
  end_sample = last,
  class = "pulse",
  text = "High",
  texts = { "High", "H" }, -- optional; the first entry is shown when text is empty
  fields = { level = "1" }, -- optional; every value must be a string
}
```

Or return a wrapper `{ annotations = { ... }, packets = { ... } }`. A packet is `{ start_sample, end_sample, kind, data }`. `kind` is a nonempty string. `data` is JSON-compatible: objects, arrays, strings, numbers, booleans, and null. Returning nil yields no rows.

Every annotation and packet must satisfy `first <= start_sample < end_sample <= last`. An invalid range, an empty `kind`, or missing text fails the pass and that pass produces no rows. A pulse that is high at samples 2, 3, and 4 is `start_sample = 2, end_sample = 5`.

`fields` is how the Decode panel's byte search finds values. A query such as `A0-10` matches rows whose `data` field, SPI `mosi` field, or address `raw` field is that hex byte, in order, skipping rows that have none of those fields. A normal text query matches the class, the annotation text, and `key=value` field text. Session `put` leaves `fields` empty, so a session decoder puts searchable text in the annotation string.

This callback marks runs of high samples. It is the same idea as the session example further down, written as a level scan:

```lua
decode = function(first, last, bit, options, context)
  local rows = {}
  local began = nil
  local function emit(finish)
    rows[#rows + 1] = {
      start_sample = began,
      end_sample = finish,
      class = "pulse",
      text = "High",
      fields = { level = "1" },
    }
  end
  for sample = first, last - 1 do
    if bit("data", sample) then
      if began == nil then began = sample end
    elseif began ~= nil then
      emit(sample)
      began = nil
    end
  end
  if began ~= nil then emit(last) end
  return rows
end
```

The loop treats a level that is still high at `last` as a pulse that ends on the region boundary. Decide and document the boundary behavior your protocol needs. Do not assume the next call continues this one.

## Session host

Set `api_version` to `3`. The global `logicview` table holds the output-type constants. Call methods with a colon or a dot; both pass the decoder table through.

Constants:

| Name | Value | Role |
| --- | --- | --- |
| `logicview.OUTPUT_ANN` | 0 | Annotation rows |
| `logicview.OUTPUT_PYTHON` | 1 | Packets for a stacked decoder |
| `logicview.OUTPUT_BINARY` | 2 | A byte stream |
| `logicview.OUTPUT_META` | 3 | A named measurement |
| `logicview.SRD_CONF_SAMPLERATE` | `"samplerate"` | Metadata key for the sample rate |

Call order on every pass:

1. `options`, `samplenum`, `matched`, and `connected` are set. `samplenum` starts at `start - 1`.
2. `__init__(self)`, if present.
3. `reset(self)`, if present. Clear protocol state here. Leave registered output ids alone if you register them in `start`.
4. `metadata(self, key, value)`, if the capture has a sample rate. `key` is `logicview.SRD_CONF_SAMPLERATE` and `value` is the rate in hertz. `self.sample_rate_hz` is the same number, or nil when there is no rate and `metadata` is not called.
5. `start(self)`. Register outputs here.
6. `decode`.

`reset` runs before `metadata`, so a reset that clears a saved sample rate is safe. `start` can read the rate.

```lua
local lv = logicview

start = function(self)
  self.out_ann = self:register(lv.OUTPUT_ANN)
  self.out_python = self:register(lv.OUTPUT_PYTHON)
  self.out_binary = self:register(lv.OUTPUT_BINARY)
  self.out_meta = self:register(lv.OUTPUT_META, "edges")
end
```

`register` returns the integer you pass back to `put`. The optional name is the metadata key. It is used for `OUTPUT_META` only; an empty name becomes `"meta"`. Register one Python output for the stack.

`self.options` keeps the Lua type of each default. A numeric default stays a number, and a value chosen in the dialog is parsed back into that type. A boolean default is true when the stored text is `1`, `true`, `yes`, or `on`, ignoring case. A string default stays a string. The callback host does not do this; there, every option is a string.

`self.connected[name] == true` when that channel is mapped. `self:has_channel(index)` reports the same thing for a zero-based pin index, required channels first, then optional channels. A string channel id is also accepted.

### put

```lua
self:put(start_sample, end_sample_inclusive, output_id, data)
```

The end is inclusive. A marker on one sample uses the same number twice. LogicView stores the span as the half-open range `[start_sample, end_sample_inclusive + 1)`. A range outside the decoded region, a negative start, or an end before the start fails the pass. The callback host's returned ranges stay exclusive; do not mix the two conventions in one mental model.

Annotation `data` is `{ class_index, { "Long text", "Short" } }`. `class_index` is zero-based into `annotations` (or `classes`). The first string is the text shown on the waveform and in the table. Further strings are kept in the order you wrote them. Put the longest label first. At least one string is required.

Python `data` is any JSON-compatible value. When it is a list whose first item is a string, that string is the packet `kind` and the whole list is the packet `data`. Otherwise the kind is `"python"`. Register one Python output.

Binary `data` is `{ format_index, bytes }`. `format_index` is zero-based into `binary`. `bytes` is a Lua string (raw bytes, so `string.char` is appropriate) or a list of integers from 0 to 255.

Metadata `data` is any JSON-compatible value. The name passed to `register` identifies it.

Binary payloads, metadata values, and annotation rows are produced and returned to the decode pass. The waveform stores annotations and passes Python packets up the stack. It does not yet show binary downloads, metadata readouts, or annotation-row layout.

A session `decode` may also return nil, or the same annotation and packet tables as the callback. Prefer `put` for session scripts. A return value that is not nil and not a valid result table fails the pass, including rows already passed to `put`.

### wait

`wait` blocks until a condition matches, then sets `self.samplenum` and `self.matched` and returns the pin levels. Pins are ordered as required channels, then optional channels that were not already required. The returned table is one-based. A connected pin is the number `1` or `0`. A disconnected pin is nil.

```lua
local pins = self:wait({ [0] = "r" })          -- rising edge on the first channel
local pins = self:wait({ data = "f" })         -- falling edge by channel id
local pins = self:wait({ [0] = "h", [1] = "f" }) -- both terms on the same sample
local pins = self:wait({ { [0] = "e" }, { skip = 100 } })
local pins = self:wait({ skip = 8 })
local pins = self:wait()                       -- the next sample
```

Terms inside one table are combined with and. A list of tables is combined with or. The scan returns the earliest sample at which any or-branch is fully true. `self.matched` is an integer bitmask: bit 0 is the first condition, bit 1 the second, and so on, for the first 63 conditions.

Pin conditions, case insensitive:

| Text | Also accepted | Matches |
| --- | --- | --- |
| `l` | `low`, or the number `0` | Pin is low |
| `h` | `high`, or the number `1` | Pin is high |
| `r` | `rising` | Previous sample low, this sample high |
| `f` | `falling` | Previous sample high, this sample low |
| `e` | `edge` | Level changed |
| `n` | `stable` | Level stayed the same |

`skip` counts samples forward from the previous `samplenum`. An empty condition, or `wait()` with no argument, skips one sample. A disconnected pin matches none of the level or edge letters. Check `has_channel` when that pin is optional; otherwise `wait` runs to the end of the region.

Before the first sample, `samplenum` is one less than the region start. At the beginning of a capture the previous level is the first sample, so that sample is not itself an edge. When the region starts later, the previous level is the sample just before the region.

`wait` raises when no later sample can match. Let that error leave `decode` so the loop stops. Annotations and packets already emitted are kept. Any other error is logged (`decoder failed`) and that pass yields no annotations.

A signal `decode` walks until the region ends:

```lua
decode = function(self)
  while true do
    self:wait({ [0] = "r" })
    local began = self.samplenum
    self:wait({ [0] = "f" })
    local last_high = self.samplenum - 1
    self:put(began, last_high, self.out_ann, { 0, { "High" } })
  end
end
```

The falling-edge sample is the first low sample, so the inclusive end of the high run is one sample earlier. A level that is still high when the region ends is not emitted, because the falling `wait` raises and the `put` has not run. Catching that error yourself is how you would emit a partial pulse; document it if you do.

## Stacking

A stacked session decoder does not call `wait`. Its `decode` receives the parent packets that overlap the region:

```lua
decode = function(self, start_sample, end_sample, data)
end
```

`start_sample` is inclusive and `end_sample` is exclusive. `data` is a list. Each item has `start_sample`, exclusive `end_sample`, `kind`, and `data`. A parent's region can be wider than the child's. Clip before `put`: the inclusive end you pass must lie inside `[start_sample, end_sample)`.

```lua
local first = math.max(packet.start_sample, start_sample)
local last = math.min(packet.end_sample, end_sample) - 1
if first <= last then
  self:put(first, last, self.out_ann, { 0, { "CMD" } })
end
```

The Decode panel stacks the new decoder on a parent whose id equals the child's parent protocol, or whose `outputs` contain that protocol. The user can change the parent in the decoder's settings when more than one instance matches. Add and configure the parent first.

Built-in SPI emits packets. Built-in UART, I2C, and EEPROM do not. A datasheet decoder that needs I2C or UART bytes stacks on a script parent whose `outputs` include `i2c` or `uart`. The translated `1:i2c` and `1:uart` scripts do. Built-in SPI is enough for a SPI device.

Built-in SPI packet kinds:

- `DATA`. `data.mosi` and `data.miso` are numbers when those lines are mapped. A missing line is JSON null, which arrives as a null userdata, not as nil and not as numeric zero. Test `type(packet.data.mosi) == "number"` before arithmetic.
- `CS-CHANGE`. `data.old`, `data.new`, and `data.selected` are booleans. `selected` follows the chip-select polarity configured on the SPI decoder.

Those objects are the packet `data`. They are not wrapped in a list.

A script that emits Python output is different. `put(..., { "EDGE", count })` stores `kind == "EDGE"` and `data` equal to the whole list `{ "EDGE", count }`. A child reads `packet.kind` and then the rest of `packet.data`. Document that layout next to the decoder.

The callback host sees the same packets on `context.packets`, plus the parent's annotations on `context.lower`. Use packets when the parent provides them.

## What the application shows

The protocol list matches `name`, `id`, `longname`, `desc`, and `tags`. The settings dialog shows channel ids from `channels`, a dropdown or text field for each option, and a parent picker when `stack_on` is set. The waveform and the decode table show each annotation's first text, over the stored half-open sample range. The table search matches class, text, and callback `fields`, including a dash-separated hex pattern such as `A0-10` against `data`, `mosi`, or address `raw` fields.

Annotation rows, binary streams, and metadata are kept on the decode pass and are not drawn. Python packets are not drawn either; they exist so the next decoder can read them.

## Runtime and testing

The Lua state has the base library plus `table`, `string`, `math`, and `coroutine`. It does not provide `io`, `os`, `package`, or `debug`. A script cannot read files, start processes, or use the network. Memory is limited to 64 MiB. An instruction hook stops a script after about 100 million instructions. Avoid per-sample work that allocates on every sample of a long capture, and avoid emitting an annotation for every sample when a span will do.

`logicview` also contains helpers used by translated scripts (`dict`, `truth`, `idx`, and others). New decoders should use ordinary Lua.

Check these cases against the datasheet:

- Both polarities and every option value, including the default.
- An optional pin left unmapped.
- A frame that starts before the region or is still open at the end.
- A stacked child whose region is narrower than its parent's, and a parent packet with a null data line.
- Exact `start_sample` and `end_sample`, not only the label text.

The Rust tests in [`script.rs`](../crates/logicview-decode/src/script.rs) load Lua modules and run them on synthetic samples and packets. From the repository root:

```sh
cargo test -p logicview-decode
```

A failed script is logged and that pass contributes no annotations. If the decoder is missing from the list, check the id, the syntax, the script directory, and that Preferences were saved.

## Examples

Both examples are original skeletons. Replace the class names and the conditions with the ones from the datasheet you are implementing.

### One wire, session host

Marks each high interval on a single line. The falling edge ends the interval. A pulse still high at the end of the region is dropped with the `wait`.

```lua
local lv = logicview

return {
  api_version = 3,
  id = "guide_high_pulse",
  name = "Guide high pulse",
  longname = "High intervals on one line",
  desc = "Marks samples where one line stays high.",
  license = "gplv3+",
  inputs = { "logic" },
  outputs = { "guide_high_pulse" },
  tags = { "Debug/trace" },
  channels = { { id = "data", name = "Data", desc = "Sampled line" } },
  optional_channels = {},
  annotations = { { "pulse", "High interval" } },

  start = function(self)
    self.out_ann = self:register(lv.OUTPUT_ANN)
  end,

  reset = function(self)
    self.count = 0
  end,

  metadata = function(self, key, value)
    if key == lv.SRD_CONF_SAMPLERATE then self.samplerate = value end
  end,

  decode = function(self)
    while true do
      self:wait({ data = "r" })
      local began = self.samplenum
      self:wait({ data = "f" })
      local last_high = self.samplenum - 1
      self.count = self.count + 1
      local text = string.format("High %d", self.count)
      if self.samplerate and last_high >= began then
        local seconds = (last_high - began + 1) / self.samplerate
        text = string.format("High %.3f us", seconds * 1e6)
      end
      self:put(began, last_high, self.out_ann, { 0, { text } })
    end
  end,
}
```

### SPI command byte, stacked on the built-in SPI decoder

Treats each MOSI byte as a command. It clips the packet to the child region before `put`. A missing MOSI line is skipped.

```lua
local lv = logicview

return {
  api_version = 3,
  id = "guide_spi_command",
  name = "Guide SPI command",
  desc = "Shows each SPI MOSI byte as a command.",
  license = "gplv3+",
  inputs = { "spi" },
  outputs = { "guide_spi_command" },
  channels = {},
  optional_channels = {},
  annotations = { { "command", "Command byte" } },

  start = function(self)
    self.out_ann = self:register(lv.OUTPUT_ANN)
    self.out_python = self:register(lv.OUTPUT_PYTHON)
  end,

  decode = function(self, start_sample, end_sample, packets)
    for _, packet in ipairs(packets) do
      local value = type(packet.data) == "table" and packet.data.mosi or nil
      if packet.kind == "DATA" and type(value) == "number" then
        local first = math.max(packet.start_sample, start_sample)
        local last = math.min(packet.end_sample, end_sample) - 1
        if first <= last then
          local text = string.format("CMD 0x%02X", value)
          self:put(first, last, self.out_ann, { 0, { text } })
          self:put(first, last, self.out_python, { "COMMAND", value })
        end
      end
    end
  end,
}
```

A child of this decoder sees `kind == "COMMAND"` and `data == { "COMMAND", value }`. Add the built-in SPI decoder, map its clock and MOSI, then add this decoder and select that SPI instance as the parent.
