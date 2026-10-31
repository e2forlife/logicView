//! Session host for Lua decoders.
//!
//! Scripts that set `api_version` to 3 or higher register outputs and then `wait`
//! for edges or a sample count, matching the job of libsigrokdecode's protocol
//! decoder API. The functional `decode(start, end, bit, options, context)` form
//! remains for scripts that do not opt in.
//!
//! When the application gains a capture or interface feature a decoder could use,
//! expose it through this host — a `metadata` key, an output type, or a field on
//! the decoder instance — instead of adding a second script interface. Initial pin
//! levels chosen by the user, binary downloads, metadata readouts, annotation-row
//! layout, and streaming input chunks are the current candidates.

use std::sync::atomic::{AtomicBool, Ordering};

use mlua::{Lua, LuaSerdeExt, Table, Value};

use super::{
    Annotation, AnnotationClass, AnnotationRowGroup, BinaryFormat, BinaryPayload, ChannelDesc,
    DecodeError, DecodeOutput, DecodeRequest, DecoderOption, DecoderSchema, MetaItem, ProtocolPacket,
};

const OUTPUT_ANN: i64 = 0;
const OUTPUT_PYTHON: i64 = 1;
const OUTPUT_BINARY: i64 = 2;
const OUTPUT_META: i64 = 3;
const END_OF_STREAM: &str = "\u{1}logicview-end-of-stream";
const CANCELLED: &str = "\u{1}logicview-cancelled";

/// Installs the `logicview` constants a script can read while it is loading.
pub fn install(lua: &Lua) -> Result<(), DecodeError> {
    let host = lua.create_table().map_err(lua_err)?;
    host.set("OUTPUT_ANN", OUTPUT_ANN).map_err(lua_err)?;
    host.set("OUTPUT_PYTHON", OUTPUT_PYTHON).map_err(lua_err)?;
    host.set("OUTPUT_BINARY", OUTPUT_BINARY).map_err(lua_err)?;
    host.set("OUTPUT_META", OUTPUT_META).map_err(lua_err)?;
    host.set("SRD_CONF_SAMPLERATE", "samplerate").map_err(lua_err)?;
    lua.globals().set("logicview", host).map_err(lua_err)?;
    super::lua_helpers::install(lua)?;
    Ok(())
}

/// Reads decoder registration metadata, including the sigrok-style fields.
pub fn read_schema(module: &Table) -> Result<DecoderSchema, DecodeError> {
    let api_version = match module.get::<Value>("api_version").map_err(lua_err)? {
        Value::Nil => 1,
        Value::Integer(value) if value >= 0 => u32::try_from(value).map_err(|_| DecodeError::Message("api_version is too large".into()))?,
        Value::Number(value) if value >= 0.0 && value.fract() == 0.0 => value as u32,
        _ => return Err(DecodeError::Message("api_version must be a non-negative integer".into())),
    };
    let id: String = module.get("id").map_err(lua_err)?;
    let name: String = module.get("name").map_err(lua_err)?;
    if id.is_empty() || !id.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == ':') || name.is_empty() {
        return Err(DecodeError::Message("invalid scripted decoder metadata".into()));
    }
    let channel_details = parse_channels(module.get("channels").map_err(lua_err)?)?;
    let optional_value: Value = module.get("optional_channels").map_err(lua_err)?;
    let optional_channel_details = if matches!(optional_value, Value::Nil) {
        if api_version >= 3 { Vec::new() } else { channel_details.clone() }
    } else {
        parse_channels(optional_value)?
    };
    let annotation_classes = parse_classes(module)?;
    let mut inputs = string_list(module.get("inputs").map_err(lua_err)?)?;
    let mut stack_on: Option<String> = module.get("stack_on").map_err(lua_err)?;
    if stack_on.is_none() {
        stack_on = inputs.iter().find(|input| *input != "logic").cloned();
    }
    if inputs.is_empty() {
        inputs.push(stack_on.clone().unwrap_or_else(|| {
            if api_version >= 3 { "logic".into() } else { String::new() }
        }));
        if inputs.first().is_some_and(String::is_empty) { inputs.clear(); }
    }
    Ok(DecoderSchema {
        id,
        name,
        channels: channel_details.iter().map(|channel| channel.id.clone()).collect(),
        optional_channels: optional_channel_details.iter().map(|channel| channel.id.clone()).collect(),
        stack_on,
        classes: annotation_classes.iter().map(|class| class.id.clone()).collect(),
        options: parse_options(module.get("options").map_err(lua_err)?)?,
        api_version,
        longname: optional_text(module, "longname")?,
        desc: optional_text(module, "desc")?,
        license: optional_text(module, "license")?,
        inputs,
        outputs: string_list(module.get("outputs").map_err(lua_err)?)?,
        tags: string_list(module.get("tags").map_err(lua_err)?)?,
        channel_details,
        optional_channel_details,
        annotation_classes,
        annotation_rows: parse_rows(module.get("annotation_rows").map_err(lua_err)?)?,
        binary: parse_binary(module.get("binary").map_err(lua_err)?)?,
    })
}

/// Runs one api_version >= 3 script over the requested region.
pub fn run_session(
    lua: &Lua,
    module: &Table,
    schema: &DecoderSchema,
    request: &DecodeRequest<'_>,
    cancel: &AtomicBool,
) -> Result<DecodeOutput, DecodeError> {
    if cancel.load(Ordering::Relaxed) {
        return Ok(DecodeOutput::new(Vec::new(), Vec::new(), true));
    }
    let mut start = request.region.start.min(request.sample_len);
    let end = request.region.end.min(request.sample_len);
    if start > end { start = end; }
    let session = std::cell::RefCell::new(Session::new(schema, request, start, end));
    let instance_ptr = module.to_pointer();
    let decoded = lua.scope(|scope| -> Result<Value, mlua::Error> {
        let wait = scope.create_function(|lua, args: mlua::MultiValue| {
            let spec = method_args(args, instance_ptr).into_iter().next();
            let hit = session.borrow_mut().wait(spec.as_ref(), cancel)?;
            let pins = lua.create_table()?;
            for (index, pin) in hit.pins.iter().enumerate() {
                if let Some(level) = pin { pins.set(index + 1, if *level { 1 } else { 0 })?; }
            }
            let mut mask = 0i64;
            for (index, hit) in hit.matched.iter().enumerate() {
                if *hit && index < 63 { mask |= 1 << index; }
            }
            module.set("samplenum", hit.samplenum)?;
            module.set("matched", mask)?;
            Ok(pins)
        })?;
        let put = scope.create_function(|lua, args: mlua::MultiValue| {
            let args = method_args(args, instance_ptr);
            if args.len() < 4 { return Err(runtime("put expects start, end, output id, and data")); }
            session.borrow_mut().put(&args[0], &args[1], &args[2], args[3].clone(), lua)?;
            Ok(())
        })?;
        let register = scope.create_function(|_, args: mlua::MultiValue| {
            let args = method_args(args, instance_ptr);
            let kind = args.first().and_then(as_i64).ok_or_else(|| runtime("register expects an output type"))?;
            let name = args.get(1).and_then(lua_text);
            Ok(session.borrow_mut().register(kind, name)?)
        })?;
        module.set("wait", wait)?;
        module.set("put", put)?;
        module.set("register", register)?;
        let pin_names = {
            let mut names = schema.channels.clone();
            for name in &schema.optional_channels {
                if !names.contains(name) { names.push(name.clone()); }
            }
            names
        };
        let has_channel = scope.create_function(move |_, args: mlua::MultiValue| {
            let args = method_args(args, instance_ptr);
            let connected: Table = module.get("connected")?;
            let Some(arg) = args.first() else { return Ok(false) };
            let name = if let Some(index) = as_i64(arg) {
                if index < 0 { return Ok(false); }
                pin_names.get(usize::try_from(index).unwrap_or(usize::MAX)).cloned()
            } else {
                lua_text(arg)
            };
            let Some(name) = name else { return Ok(false) };
            Ok(matches!(connected.get::<Value>(name)?, Value::Boolean(true)))
        })?;
        module.set("has_channel", has_channel)?;
        let defaults = option_defaults(module)?;
        module.set("options", option_table(lua, &defaults, schema, request)?)?;
        module.set("samplenum", start as i64 - 1)?;
        module.set("matched", 0)?;
        let connected = lua.create_table()?;
        for (name, _) in request.channels { connected.set(*name, true)?; }
        module.set("connected", connected)?;
        // reset and __init__ run before metadata. Many DSView decoders clear
        // samplerate inside reset, and start() both registers outputs and may
        // read the sample rate, so the rate has to be applied between them.
        call_if_present(module, "__init__", (module.clone(),))?;
        call_if_present(module, "reset", (module.clone(),))?;
        if let Some(rate) = request.sample_rate_hz {
            module.set("sample_rate_hz", rate)?;
            call_if_present(module, "metadata", (module.clone(), "samplerate", rate))?;
        } else {
            module.set("sample_rate_hz", Value::Nil)?;
        }
        call_if_present(module, "start", (module.clone(),))?;
        let decode: mlua::Function = match module.get("decode")? {
            Value::Function(function) => function,
            _ => return Err(runtime("decode must be a function")),
        };
        if schema.stack_on.is_some() {
            let data = lua.create_table()?;
            let mut slot = 1;
            for packet in request.lower_packets.iter().filter(|packet| packet.end_sample > start && packet.start_sample < end) {
                let item = lua.create_table()?;
                item.set("start_sample", packet.start_sample)?;
                item.set("end_sample", packet.end_sample)?;
                item.set("kind", packet.kind.clone())?;
                item.set("data", lua.to_value(&packet.data)?)?;
                data.set(slot, item)?;
                slot += 1;
            }
            decode.call((module.clone(), start, end, data))
        } else {
            decode.call((module.clone(),))
        }
    });
    let mut state = session.into_inner();
    match decoded {
        Ok(value) => {
            let extra = super::script::output_from_value(lua, value, start, end)?;
            state.annotations.extend(extra.annotations);
            state.packets.extend(extra.packets);
            Ok(state.finish(false))
        }
        Err(err) if is_marker(&err, END_OF_STREAM) => Ok(state.finish(false)),
        Err(err) if is_marker(&err, CANCELLED) || cancel.load(Ordering::Relaxed) => Ok(state.finish(true)),
        Err(err) => Err(DecodeError::Message(err.to_string())),
    }
}

struct Session<'a> {
    schema: &'a DecoderSchema,
    request: &'a DecodeRequest<'a>,
    pins: Vec<String>,
    samplenum: i64,
    prev: Vec<Option<bool>>,
    outputs: Vec<OutKind>,
    annotations: Vec<Annotation>,
    packets: Vec<ProtocolPacket>,
    binary: Vec<BinaryPayload>,
    meta: Vec<MetaItem>,
    start: u64,
    end: u64,
}

enum OutKind { Ann, Python, Binary, Meta(String) }
struct WaitHit { samplenum: i64, matched: Vec<bool>, pins: Vec<Option<bool>> }
struct Cond { terms: Vec<Term> }
enum Term { Pin { index: usize, expect: Expect }, Skip(u64) }
#[derive(Clone, Copy)]
enum Expect { Low, High, Rise, Fall, Either, Stable }

impl<'a> Session<'a> {
    fn new(schema: &'a DecoderSchema, request: &'a DecodeRequest<'a>, start: u64, end: u64) -> Self {
        let mut pins = schema.channels.clone();
        for name in &schema.optional_channels {
            if !pins.contains(name) { pins.push(name.clone()); }
        }
        let prev = if start > 0 {
            sample_pins(request, &pins, start - 1)
        } else if start < end {
            sample_pins(request, &pins, start)
        } else {
            vec![None; pins.len()]
        };
        Self {
            schema, request, pins, samplenum: start as i64 - 1, prev, outputs: Vec::new(),
            annotations: Vec::new(), packets: Vec::new(), binary: Vec::new(), meta: Vec::new(), start, end,
        }
    }

    fn finish(self, cancelled: bool) -> DecodeOutput {
        DecodeOutput { annotations: self.annotations, packets: self.packets, binary: self.binary, meta: self.meta, cancelled }
    }

    fn register(&mut self, kind: i64, name: Option<String>) -> Result<i64, mlua::Error> {
        let slot = match kind {
            OUTPUT_ANN => OutKind::Ann,
            OUTPUT_PYTHON => OutKind::Python,
            OUTPUT_BINARY => OutKind::Binary,
            OUTPUT_META => OutKind::Meta(name.filter(|value| !value.is_empty()).unwrap_or_else(|| "meta".into())),
            _ => return Err(runtime("unknown output type")),
        };
        self.outputs.push(slot);
        Ok(self.outputs.len() as i64 - 1)
    }

    fn put(&mut self, start: &Value, end_inclusive: &Value, output_id: &Value, data: Value, lua: &Lua) -> Result<(), mlua::Error> {
        let start = as_i64(start).ok_or_else(|| runtime("put start sample must be an integer"))?;
        let end_inclusive = as_i64(end_inclusive).ok_or_else(|| runtime("put end sample must be an integer"))?;
        let output_id = as_i64(output_id).ok_or_else(|| runtime("put output id must be an integer"))?;
        let (start_sample, end_sample) = self.span(start, end_inclusive)?;
        let kind = self.outputs.get(usize::try_from(output_id).map_err(|_| runtime("unknown output id"))?)
            .ok_or_else(|| runtime("unknown output id"))?;
        match kind {
            OutKind::Ann => {
                let table = data.as_table().ok_or_else(|| runtime("annotation data must be {class, texts}"))?;
                let class_index = as_i64(&table.get(1)?).ok_or_else(|| runtime("annotation class must be an index"))?;
                let class_index = usize::try_from(class_index).map_err(|_| runtime("annotation class is out of range"))?;
                if !self.schema.classes.is_empty() && class_index >= self.schema.classes.len() {
                    return Err(runtime("annotation class is out of range"));
                }
                let texts = text_list(table.get(2)?)?;
                if texts.is_empty() { return Err(runtime("annotation text is empty")); }
                let class = self.schema.classes.get(class_index).cloned().unwrap_or_else(|| class_index.to_string());
                let mut annotation = Annotation::new(start_sample, end_sample, class, texts[0].clone(), std::collections::BTreeMap::new());
                if texts.len() > 1 { annotation.texts = texts; }
                self.annotations.push(annotation);
            }
            OutKind::Python => {
                let value: serde_json::Value = lua.from_value(data)?;
                let kind = value.as_array().and_then(|items| items.first()).and_then(|item| item.as_str()).unwrap_or("python").to_string();
                self.packets.push(ProtocolPacket { start_sample, end_sample, kind, data: value });
            }
            OutKind::Binary => {
                let table = data.as_table().ok_or_else(|| runtime("binary data must be {format, bytes}"))?;
                let format_index = usize::try_from(as_i64(&table.get(1)?).ok_or_else(|| runtime("binary format must be an index"))?)
                    .map_err(|_| runtime("binary format is out of range"))?;
                let format = self.schema.binary.get(format_index).ok_or_else(|| runtime("binary format is out of range"))?;
                self.binary.push(BinaryPayload { start_sample, end_sample, format: format.id.clone(), bytes: byte_string(table.get(2)?)? });
            }
            OutKind::Meta(key) => {
                let value = lua.from_value(data)?;
                self.meta.push(MetaItem { start_sample, end_sample, key: key.clone(), value });
            }
        }
        Ok(())
    }

    fn wait(&mut self, spec: Option<&Value>, cancel: &AtomicBool) -> Result<WaitHit, mlua::Error> {
        if cancel.load(Ordering::Relaxed) { return Err(runtime(CANCELLED)); }
        let conditions = parse_conditions(spec, &self.pins)?;
        let origin = self.samplenum;
        let region_end = self.end as i64;
        if conditions.iter().all(|condition| matches!(condition.terms.as_slice(), [Term::Skip(_)])) {
            let mut target: Option<i64> = None;
            for condition in &conditions {
                let Term::Skip(skip) = condition.terms[0] else { continue };
                let at = checked_skip(origin, skip)?;
                target = Some(target.map_or(at, |best| best.min(at)));
            }
            let target = target.unwrap_or(origin.saturating_add(1));
            if target >= region_end || (target < self.start as i64 && target != origin) {
                return Err(runtime(END_OF_STREAM));
            }
            let pins = if target < self.start as i64 { self.prev.clone() } else { sample_pins(self.request, &self.pins, target as u64) };
            let matched = conditions.iter().map(|condition| {
                matches!(condition.terms.first(), Some(Term::Skip(skip)) if checked_skip(origin, *skip).ok() == Some(target))
            }).collect();
            if target >= self.start as i64 { self.prev = pins.clone(); self.samplenum = target; }
            return Ok(WaitHit { samplenum: self.samplenum, matched, pins });
        }
        let mut sample = origin.saturating_add(1).max(self.start as i64);
        let mut previous = if sample > 0 { sample_pins(self.request, &self.pins, (sample - 1) as u64) } else { self.prev.clone() };
        let mut checked = 0u64;
        while sample < region_end {
            if checked % 65_536 == 0 && cancel.load(Ordering::Relaxed) { return Err(runtime(CANCELLED)); }
            checked += 1;
            let pins = sample_pins(self.request, &self.pins, sample as u64);
            let matched: Vec<bool> = conditions.iter().map(|condition| {
                condition.terms.iter().all(|term| term_matches(term, sample, origin, &previous, &pins))
            }).collect();
            if matched.iter().any(|hit| *hit) {
                self.samplenum = sample;
                self.prev = pins.clone();
                return Ok(WaitHit { samplenum: sample, matched, pins });
            }
            previous = pins;
            sample += 1;
        }
        Err(runtime(END_OF_STREAM))
    }

    fn span(&self, start: i64, end_inclusive: i64) -> Result<(u64, u64), mlua::Error> {
        if start < 0 || end_inclusive < start { return Err(runtime("put range is invalid")); }
        let start = start as u64;
        let end = (end_inclusive as u64).checked_add(1).ok_or_else(|| runtime("put range is invalid"))?;
        if start < self.start || end > self.end { return Err(runtime("put range is outside the decoded region")); }
        Ok((start, end))
    }
}

fn sample_pins(request: &DecodeRequest<'_>, names: &[String], sample: u64) -> Vec<Option<bool>> {
    names.iter().map(|name| {
        request.channels.iter().find(|(channel, _)| *channel == name)
            .map(|(_, bytes)| logicview_analysis::bit_at(bytes, sample))
    }).collect()
}

fn term_matches(term: &Term, sample: i64, origin: i64, previous: &[Option<bool>], pins: &[Option<bool>]) -> bool {
    match term {
        Term::Skip(skip) => checked_skip(origin, *skip).ok() == Some(sample),
        Term::Pin { index, expect } => {
            let current = pins.get(*index).copied().flatten();
            let prior = previous.get(*index).copied().flatten();
            match expect {
                Expect::Low => current == Some(false),
                Expect::High => current == Some(true),
                Expect::Rise => prior == Some(false) && current == Some(true),
                Expect::Fall => prior == Some(true) && current == Some(false),
                Expect::Either => matches!((prior, current), (Some(before), Some(after)) if before != after),
                Expect::Stable => matches!((prior, current), (Some(before), Some(after)) if before == after),
            }
        }
    }
}

fn checked_skip(origin: i64, skip: u64) -> Result<i64, mlua::Error> {
    let skip = i64::try_from(skip).map_err(|_| runtime("skip is too large"))?;
    origin.checked_add(skip).ok_or_else(|| runtime("skip is too large"))
}

fn parse_conditions(spec: Option<&Value>, pins: &[String]) -> Result<Vec<Cond>, mlua::Error> {
    let Some(value) = spec.filter(|value| !matches!(value, Value::Nil)) else {
        return Ok(vec![Cond { terms: vec![Term::Skip(1)] }]);
    };
    let Value::Table(table) = value else { return Err(runtime("wait condition must be a table")); };
    if or_list(table)? {
        let mut conditions = Vec::new();
        for item in table.clone().sequence_values::<Table>() {
            conditions.push(parse_condition(&item?, pins)?);
        }
        if conditions.is_empty() { conditions.push(Cond { terms: vec![Term::Skip(1)] }); }
        return Ok(conditions);
    }
    Ok(vec![parse_condition(table, pins)?])
}

fn or_list(table: &Table) -> Result<bool, mlua::Error> {
    let mut entries = 0i64;
    let mut list = true;
    table.for_each(|key: Value, value: Value| {
        entries += 1;
        if !(matches!(key, Value::Integer(index) if index >= 1) && matches!(value, Value::Table(_))) { list = false; }
        Ok(())
    })?;
    Ok(list && entries > 0 && table.len()? == entries)
}

fn parse_condition(table: &Table, pins: &[String]) -> Result<Cond, mlua::Error> {
    let mut terms = Vec::new();
    table.for_each(|key: Value, value: Value| {
        match key {
            Value::String(text) if text.to_str()? == "skip" => terms.push(Term::Skip(non_negative(&value)?)),
            Value::String(text) => {
                let name = text.to_str()?.to_string();
                let index = pins.iter().position(|pin| pin == &name).ok_or_else(|| runtime(format!("unknown channel {name}")))?;
                terms.push(Term::Pin { index, expect: expect(&value)? });
            }
            Value::Integer(index) if index >= 0 => {
                let index = usize::try_from(index).map_err(|_| runtime("channel index is out of range"))?;
                if index >= pins.len() { return Err(runtime("channel index is out of range")); }
                terms.push(Term::Pin { index, expect: expect(&value)? });
            }
            _ => return Err(runtime("invalid wait condition")),
        }
        Ok(())
    })?;
    if terms.is_empty() { terms.push(Term::Skip(1)); }
    Ok(Cond { terms })
}

fn expect(value: &Value) -> Result<Expect, mlua::Error> {
    match value {
        Value::Integer(0) => Ok(Expect::Low),
        Value::Integer(1) => Ok(Expect::High),
        Value::String(text) => match text.to_str()?.to_ascii_lowercase().as_str() {
            "l" | "low" => Ok(Expect::Low),
            "h" | "high" => Ok(Expect::High),
            "r" | "rising" => Ok(Expect::Rise),
            "f" | "falling" => Ok(Expect::Fall),
            "e" | "edge" => Ok(Expect::Either),
            "n" | "stable" => Ok(Expect::Stable),
            _ => Err(runtime("pin condition must be l, h, r, f, e, or n")),
        },
        _ => Err(runtime("pin condition must be l, h, r, f, e, or n")),
    }
}

fn non_negative(value: &Value) -> Result<u64, mlua::Error> {
    let number = as_i64(value).ok_or_else(|| runtime("skip must be an integer"))?;
    u64::try_from(number).map_err(|_| runtime("skip must be zero or positive"))
}

fn method_args(args: mlua::MultiValue, instance: *const std::ffi::c_void) -> Vec<Value> {
    let mut args: Vec<Value> = args.into_iter().collect();
    if let Some(Value::Table(table)) = args.first() {
        if table.to_pointer() == instance { args.remove(0); }
    }
    args
}

fn option_defaults(module: &Table) -> Result<std::collections::BTreeMap<String, Value>, mlua::Error> {
    let mut defaults = std::collections::BTreeMap::new();
    if let Value::Table(table) = module.get("options")? {
        for item in table.sequence_values::<Table>() {
            let item = item?;
            let Some(id) = lua_text(&item.get("id")?) else { continue };
            if id.is_empty() { continue; }
            defaults.insert(id, item.get("default")?);
        }
    }
    Ok(defaults)
}

fn option_table(lua: &Lua, defaults: &std::collections::BTreeMap<String, Value>, _schema: &DecoderSchema, request: &DecodeRequest<'_>) -> Result<Table, mlua::Error> {
    let mut chosen = std::collections::BTreeMap::new();
    for (key, value) in defaults { chosen.insert(key.clone(), value.clone()); }
    for (key, text) in request.options {
        let default = chosen.get(key).cloned().unwrap_or(Value::Nil);
        chosen.insert(key.clone(), coerce_option(lua, &default, text)?);
    }
    let table = lua.create_table()?;
    for (key, value) in chosen { table.set(key, value)?; }
    Ok(table)
}

fn coerce_option(lua: &Lua, default: &Value, text: &str) -> Result<Value, mlua::Error> {
    match default {
        Value::Integer(_) => {
            if let Ok(value) = text.parse::<i64>() { return Ok(Value::Integer(value)); }
            if let Ok(value) = text.parse::<f64>() { return Ok(Value::Number(value)); }
            Ok(Value::String(lua.create_string(text)?))
        }
        Value::Number(_) => {
            if let Ok(value) = text.parse::<f64>() { Ok(Value::Number(value)) } else { Ok(Value::String(lua.create_string(text)?)) }
        }
        Value::Boolean(_) => Ok(Value::Boolean(matches!(text.to_ascii_lowercase().as_str(), "1" | "true" | "yes" | "on"))),
        _ => Ok(Value::String(lua.create_string(text)?)),
    }
}

fn call_if_present<A: mlua::IntoLuaMulti>(module: &Table, name: &str, args: A) -> Result<(), mlua::Error> {
    match module.get(name)? {
        Value::Nil => Ok(()),
        Value::Function(function) => { function.call::<()>(args)?; Ok(()) },
        _ => Err(runtime(format!("{name} must be a function"))),
    }
}

fn text_list(value: Value) -> Result<Vec<String>, mlua::Error> {
    match value {
        Value::String(text) => Ok(vec![text.to_str()?.to_string()]),
        Value::Table(table) => {
            let mut texts = Vec::new();
            for item in table.sequence_values::<Value>() {
                texts.push(lua_text(&item?).ok_or_else(|| runtime("annotation text must be a string"))?);
            }
            Ok(texts)
        }
        _ => Err(runtime("annotation text must be a list of strings")),
    }
}

fn byte_string(value: Value) -> Result<Vec<u8>, mlua::Error> {
    match value {
        Value::String(text) => Ok(text.as_bytes().to_vec()),
        Value::Table(table) => {
            let mut bytes = Vec::new();
            for item in table.sequence_values::<Value>() {
                let byte = as_i64(&item?).ok_or_else(|| runtime("binary byte must be an integer"))?;
                bytes.push(u8::try_from(byte).map_err(|_| runtime("binary byte must be 0 to 255"))?);
            }
            Ok(bytes)
        }
        _ => Err(runtime("binary payload must be a string or a list of bytes")),
    }
}

fn parse_channels(value: Value) -> Result<Vec<ChannelDesc>, DecodeError> {
    let Value::Table(table) = value else {
        return if matches!(value, Value::Nil) { Ok(Vec::new()) } else { Err(DecodeError::Message("channels must be a list".into())) };
    };
    let mut channels = Vec::new();
    for item in table.sequence_values::<Value>() {
        let item = item.map_err(lua_err)?;
        let channel = match item {
            Value::String(text) => {
                let id = text.to_str().map_err(lua_err)?.to_string();
                ChannelDesc { id: id.clone(), name: id, desc: String::new() }
            }
            Value::Table(table) => {
                let id = lua_text(&table.get(1).map_err(lua_err)?).or_else(|| optional_text(&table, "id").ok().filter(|value| !value.is_empty()))
                    .ok_or_else(|| DecodeError::Message("channel id is required".into()))?;
                let name = optional_text(&table, "name").unwrap_or_default();
                let desc = optional_text(&table, "desc").unwrap_or_default();
                let name = if name.is_empty() { id.clone() } else { name };
                ChannelDesc { id, name, desc }
            }
            _ => return Err(DecodeError::Message("channel must be a name or {id, name, desc}".into())),
        };
        if channel.id.is_empty() { return Err(DecodeError::Message("channel id is required".into())); }
        channels.push(channel);
    }
    Ok(channels)
}

fn parse_classes(module: &Table) -> Result<Vec<AnnotationClass>, DecodeError> {
    let annotations: Value = module.get("annotations").map_err(lua_err)?;
    let classes: Value = module.get("classes").map_err(lua_err)?;
    let source = if matches!(annotations, Value::Table(_)) { annotations } else { classes };
    let Value::Table(table) = source else { return Ok(Vec::new()); };
    let mut parsed = Vec::new();
    for item in table.sequence_values::<Value>() {
        parsed.push(parse_class(item.map_err(lua_err)?)?);
    }
    Ok(parsed)
}

fn dsview_annotation(table: &Table) -> Result<Option<(String, String)>, DecodeError> {
    if table.len().map_err(lua_err)? != 3 { return Ok(None); }
    let Some(first) = lua_text(&table.get(1).map_err(lua_err)?) else { return Ok(None) };
    let Some(second) = lua_text(&table.get(2).map_err(lua_err)?) else { return Ok(None) };
    let Some(third) = lua_text(&table.get(3).map_err(lua_err)?) else { return Ok(None) };
    if !first.is_empty() && first.chars().all(|c| c.is_ascii_digit()) {
        return Ok(Some((second, third)));
    }
    Ok(None)
}

fn parse_class(value: Value) -> Result<AnnotationClass, DecodeError> {
    match value {
        Value::String(text) => Ok(AnnotationClass { id: text.to_str().map_err(lua_err)?.to_string(), desc: String::new() }),
        Value::Table(table) => {
            if table.get::<Value>("id").map_err(lua_err)?.is_nil() {
                if let Some((id, desc)) = dsview_annotation(&table)? { return Ok(AnnotationClass { id, desc }); }
            }
            let id = match table.get::<Value>("id").map_err(lua_err)? {
                Value::Nil => lua_text(&table.get(1).map_err(lua_err)?),
                value => lua_text(&value),
            }.ok_or_else(|| DecodeError::Message("annotation class id is required".into()))?;
            let desc = match table.get::<Value>("desc").map_err(lua_err)? {
                Value::Nil => table.get::<Value>(2).ok().and_then(|value| lua_text(&value)).unwrap_or_default(),
                value => lua_text(&value).unwrap_or_default(),
            };
            Ok(AnnotationClass { id, desc })
        }
        _ => Err(DecodeError::Message("annotation class must be a name or {id, description}".into())),
    }
}

fn parse_rows(value: Value) -> Result<Vec<AnnotationRowGroup>, DecodeError> {
    let Value::Table(table) = value else { return Ok(Vec::new()); };
    let mut rows = Vec::new();
    for item in table.sequence_values::<Table>() {
        let item = item.map_err(lua_err)?;
        let id = match item.get::<Value>("id").map_err(lua_err)? {
            Value::Nil => lua_text(&item.get(1).map_err(lua_err)?),
            value => lua_text(&value),
        }.ok_or_else(|| DecodeError::Message("annotation row id is required".into()))?;
        let name = match item.get::<Value>("name").map_err(lua_err)? {
            Value::Nil => lua_text(&item.get(2).map_err(lua_err)?).unwrap_or_else(|| id.clone()),
            value => lua_text(&value).unwrap_or_else(|| id.clone()),
        };
        let classes = match item.get::<Value>("classes").map_err(lua_err)? {
            Value::Nil => item.get(3).map_err(lua_err)?,
            value => value,
        };
        rows.push(AnnotationRowGroup { id, name, classes: index_list(classes)? });
    }
    Ok(rows)
}

fn parse_binary(value: Value) -> Result<Vec<BinaryFormat>, DecodeError> {
    let Value::Table(table) = value else { return Ok(Vec::new()); };
    let mut formats = Vec::new();
    for item in table.sequence_values::<Value>() {
        let class = parse_class(item.map_err(lua_err)?)?;
        formats.push(BinaryFormat { id: class.id, desc: class.desc });
    }
    Ok(formats)
}

fn parse_options(value: Value) -> Result<Vec<DecoderOption>, DecodeError> {
    let Value::Table(table) = value else { return Ok(Vec::new()); };
    let mut options = Vec::new();
    for item in table.sequence_values::<Table>() {
        let item = item.map_err(lua_err)?;
        let id = lua_text(&item.get::<Value>("id").map_err(lua_err)?).ok_or_else(|| DecodeError::Message("option id is required".into()))?;
        let desc = optional_text(&item, "desc")?;
        let name = optional_text(&item, "name")?;
        let name = if name.is_empty() { if desc.is_empty() { id.clone() } else { desc.clone() } } else { name };
        let desc = if desc.is_empty() { name.clone() } else { desc };
        options.push(DecoderOption {
            id,
            name,
            desc,
            default: optional_text(&item, "default")?,
            values: string_list(item.get("values").map_err(lua_err)?)?,
        });
    }
    Ok(options)
}

fn index_list(value: Value) -> Result<Vec<u32>, DecodeError> {
    let Value::Table(table) = value else { return Ok(Vec::new()); };
    let mut indexes = Vec::new();
    for item in table.sequence_values::<Value>() {
        let number = as_i64(&item.map_err(lua_err)?).ok_or_else(|| DecodeError::Message("annotation row class must be an index".into()))?;
        indexes.push(u32::try_from(number).map_err(|_| DecodeError::Message("annotation row class is out of range".into()))?);
    }
    Ok(indexes)
}

fn string_list(value: Value) -> Result<Vec<String>, DecodeError> {
    let Value::Table(table) = value else { return Ok(Vec::new()); };
    let mut values = Vec::new();
    for item in table.sequence_values::<Value>() {
        values.push(lua_text(&item.map_err(lua_err)?).ok_or_else(|| DecodeError::Message("expected a string".into()))?);
    }
    Ok(values)
}

fn optional_text(table: &Table, key: &str) -> Result<String, DecodeError> {
    Ok(lua_text(&table.get(key).map_err(lua_err)?).unwrap_or_default())
}

fn lua_text(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => text.to_str().ok().map(|text| text.to_string()),
        Value::Integer(number) => Some(number.to_string()),
        Value::Number(number) if number.fract() == 0.0 && number.is_finite() => Some((*number as i64).to_string()),
        Value::Number(number) if number.is_finite() => Some(number.to_string()),
        Value::Boolean(value) => Some(if *value { "true" } else { "false" }.into()),
        _ => None,
    }
}

fn as_i64(value: &Value) -> Option<i64> {
    match value {
        Value::Integer(number) => Some(*number),
        Value::Number(number) if number.fract() == 0.0 && number.is_finite() => Some(*number as i64),
        _ => None,
    }
}

fn runtime(message: impl Into<String>) -> mlua::Error {
    mlua::Error::RuntimeError(message.into())
}

fn lua_err(err: mlua::Error) -> DecodeError {
    DecodeError::Message(err.to_string())
}

fn is_marker(err: &mlua::Error, marker: &str) -> bool {
    err.to_string().contains(marker)
}
