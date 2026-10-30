//! Discovery and execution of user-provided Lua decoder modules.
use std::{collections::BTreeMap, path::PathBuf, sync::atomic::{AtomicBool, Ordering}};
use mlua::{Lua, LuaOptions, LuaSerdeExt, StdLib, Table, Value};
use super::{Annotation, DecodeError, DecodeOutput, DecodeRequest, DecoderSchema};

fn directory() -> Option<PathBuf> {
    let dir = logicview_config::load().scripts_dir;
    if dir.is_empty() { None } else { Some(PathBuf::from(dir)) }
}
fn files() -> Vec<PathBuf> {
    let mut paths: Vec<_> = directory().and_then(|p| std::fs::read_dir(p).ok()).into_iter().flatten()
        .filter_map(Result::ok).map(|entry| entry.path())
        .filter(|p| p.extension().is_some_and(|ext| ext == "lua")).collect();
    paths.sort(); paths
}
fn lua() -> Result<Lua, DecodeError> {
    let lua = Lua::new_with(StdLib::TABLE | StdLib::STRING | StdLib::MATH, LuaOptions::default())
        .map_err(|e| DecodeError::Message(e.to_string()))?;
    lua.set_memory_limit(64 * 1024 * 1024).map_err(|e| DecodeError::Message(e.to_string()))?;
    let ticks = std::sync::atomic::AtomicUsize::new(0);
    lua.set_hook(mlua::HookTriggers::new().every_nth_instruction(10_000), move |_, _| {
        if ticks.fetch_add(1, Ordering::Relaxed) >= 10_000 {
            Err(mlua::Error::RuntimeError("decoder instruction limit exceeded".into()))
        } else { Ok(mlua::VmState::Continue) }
    }).map_err(|e| DecodeError::Message(e.to_string()))?;
    Ok(lua)
}
fn module(lua: &Lua, path: &PathBuf) -> Result<Table, DecodeError> {
    let source = std::fs::read_to_string(path).map_err(|e| DecodeError::Message(e.to_string()))?;
    lua.load(source.trim_start_matches('\u{feff}')).set_name(path.to_string_lossy()).eval().map_err(|e| DecodeError::Message(e.to_string()))
}
fn metadata(lua: &Lua, module: &Table) -> Result<DecoderSchema, DecodeError> {
    let schema = DecoderSchema {
        id: module.get("id").map_err(|e| DecodeError::Message(e.to_string()))?,
        name: module.get("name").map_err(|e| DecodeError::Message(e.to_string()))?,
        channels: module.get::<Option<Vec<String>>>("channels").map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default(),
        optional_channels: Vec::new(),
        stack_on: module.get("stack_on").map_err(|e| DecodeError::Message(e.to_string()))?,
        classes: module.get::<Option<Vec<String>>>("classes").map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default(),
        options: lua.from_value::<Option<Vec<super::DecoderOption>>>(module.get::<Value>("options").map_err(|e| DecodeError::Message(e.to_string()))?)
            .map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default(),
    };
    if schema.id.is_empty() || !schema.id.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') || schema.name.is_empty() {
        return Err(DecodeError::Message("invalid scripted decoder metadata".into()));
    }
    let optional_channels = module.get::<Option<Vec<String>>>("optional_channels")
        .map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_else(|| schema.channels.clone());
    Ok(DecoderSchema { optional_channels, ..schema })
}
pub fn catalog() -> Vec<DecoderSchema> {
    files().into_iter().filter_map(|path| {
        let result = (|| { let lua = lua()?; let m = module(&lua, &path)?; metadata(&lua, &m) })();
        match result { Ok(value) => Some(value), Err(err) => { eprintln!("decoder {}: {err}", path.display()); None } }
    }).collect()
}
pub fn run_script(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    run_paths(request, cancel, files())
}
fn run_paths(request: &DecodeRequest<'_>, cancel: &AtomicBool, paths: Vec<PathBuf>) -> Result<DecodeOutput, DecodeError> {
    if cancel.load(Ordering::Relaxed) { return Ok(DecodeOutput { annotations: vec![], packets: vec![], cancelled: true }); }
    for path in paths {
        let lua = lua()?;
        let m = match module(&lua, &path) { Ok(m) => m, Err(_) => continue };
        let schema = match metadata(&lua, &m) { Ok(m) => m, Err(_) => continue };
        if schema.id != request.protocol { continue; }
        let decode: mlua::Function = m.get("decode").map_err(|e| DecodeError::Message(e.to_string()))?;
        let mut options: BTreeMap<String, String> = schema.options.iter().map(|option| (option.id.clone(), option.default.clone())).collect();
        options.extend(request.options.iter().cloned());
        let start = request.region.start.min(request.sample_len);
        let end = request.region.end.min(request.sample_len);
        let result = lua.scope(|scope| {
            let bit = scope.create_function(|_, (name, index): (String, u64)| {
                if index >= request.sample_len { return Ok(false); }
                Ok(request.channels.iter().find(|(n, _)| *n == name).is_some_and(|(_, bytes)| logicview_analysis::bit_at(bytes, index)))
            })?;
            let context = lua.create_table()?;
            context.set("sample_rate_hz", request.sample_rate_hz)?;
            let connected = lua.create_table()?;
            for (name, _) in request.channels { connected.set(*name, true)?; }
            context.set("connected", connected)?;
            context.set("lower", lua.to_value(request.lower)?)?;
            context.set("packets", lua.to_value(request.lower_packets)?)?;
            decode.call::<Value>((start, end, bit, lua.to_value(&options)?, context))
        }).map_err(|e| DecodeError::Message(e.to_string()))?;
        #[derive(serde::Deserialize)]
        struct Row { start_sample: u64, end_sample: u64, class: String, text: String, #[serde(default)] fields: BTreeMap<String, String> }
        let table = match result { Value::Table(table) => table, _ => return Err(DecodeError::Message("script must return a table".into())) };
        let wrapped = table.contains_key("annotations").map_err(|e| DecodeError::Message(e.to_string()))?
            || table.contains_key("packets").map_err(|e| DecodeError::Message(e.to_string()))?;
        let (rows, packets): (Vec<Row>, Vec<super::ProtocolPacket>) = if wrapped {
            let rows = lua.from_value::<Option<Vec<Row>>>(table.get("annotations").map_err(|e| DecodeError::Message(e.to_string()))?)
                .map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default();
            let packets = lua.from_value::<Option<Vec<super::ProtocolPacket>>>(table.get("packets").map_err(|e| DecodeError::Message(e.to_string()))?)
                .map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default();
            (rows, packets)
        } else {
            (lua.from_value(Value::Table(table)).map_err(|e| DecodeError::Message(e.to_string()))?, Vec::new())
        };
        let mut annotations = Vec::new();
        for row in rows {
            if row.start_sample < start || row.end_sample > end || row.start_sample >= row.end_sample {
                return Err(DecodeError::Message("script returned an invalid annotation range".into()));
            }
            annotations.push(Annotation::new(row.start_sample, row.end_sample, row.class, row.text, row.fields));
        }
        for packet in &packets {
            if packet.start_sample < start || packet.end_sample > end || packet.start_sample >= packet.end_sample || packet.kind.is_empty() {
                return Err(DecodeError::Message("script returned an invalid packet".into()));
            }
        }
        return Ok(DecodeOutput { annotations, packets, cancelled: false });
    }
    Err(DecodeError::UnknownProtocol(request.protocol.into()))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn metadata_accepts_a_decoder_function() {
        let lua = lua().unwrap();
        let module: Table = lua.load(r#"return { id='test', name='Test', channels={'signal'}, classes={'data'}, decode=function() return {} end }"#).eval().unwrap();
        let schema = metadata(&lua, &module).unwrap();
        assert_eq!(schema.id, "test");
        assert_eq!(schema.channels, ["signal"]);
    }
    #[test]
    fn script_decodes_channel_samples_into_annotations() {
        let path = std::env::temp_dir().join(format!("logicview-script-test-{}.lua", std::process::id()));
        std::fs::write(&path, r#"return { id='test', name='Test', channels={'signal'}, classes={'data'},
            decode=function(start, finish, bit, options)
                if bit('signal', start) then return {{start_sample=start, end_sample=finish, class='data', text='high', fields={value='1'}}} end
                return {}
            end }"#).unwrap();
        let bytes = [0xff];
        let channels = [("signal", bytes.as_slice())];
        let req = DecodeRequest { protocol: "test", channels: &channels, options: &[], region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![path.clone()]).unwrap();
        std::fs::remove_file(path).unwrap();
        assert_eq!(result.annotations.len(), 1);
        assert_eq!(result.annotations[0].text, "high");
        assert_eq!(result.annotations[0].end_sample, 8);
    }

    #[test]
    fn example_module_is_loadable() {
        let lua = lua().unwrap();
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders/high_pulses.lua");
        let module = module(&lua, &path).unwrap();
        assert_eq!(metadata(&lua, &module).unwrap().id, "high_pulses");
    }

    #[test]
    fn dsview_examples_decode_samples() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders");
        let one = [0xff];
        let zero = [0x00];
        let segments = [("a", &zero[..]), ("b", &one[..]), ("c", &one[..]),
            ("d", &zero[..]), ("e", &zero[..]), ("f", &zero[..]), ("g", &zero[..])];
        let req = DecodeRequest { protocol: "dsview_seven_segment", channels: &segments,
            options: &[], region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("seven_segment.lua")]).unwrap();
        assert_eq!(result.annotations.len(), 1);
        assert_eq!(result.annotations[0].text, "1");
        assert_eq!(result.annotations[0].end_sample, 8);

        let steps = [0b0010_1010];
        let direction = [0b0000_0110];
        let channels = [("step", &steps[..]), ("dir", &direction[..])];
        let req = DecodeRequest { protocol: "dsview_stepper_motor", channels: &channels,
            options: &[], region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("stepper_motor.lua")]).unwrap();
        assert_eq!(result.annotations.iter().map(|a| a.text.as_str()).collect::<Vec<_>>(), ["1 steps", "0 steps"]);
    }

    #[test]
    fn dsview_counter_and_pwm_decode_edges() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders");
        let data = [0b0110_0110];
        let channels = [("data", &data[..])];
        let req = DecodeRequest { protocol: "dsview_pwm", channels: &channels,
            options: &[], region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("pwm.lua")]).unwrap();
        assert_eq!(result.annotations.iter().map(|a| a.text.as_str()).collect::<Vec<_>>(), ["50.000000%", "4 samples"]);
        let options = [("divider".into(), "2".into())];
        let req = DecodeRequest { protocol: "dsview_counter", channels: &channels,
            options: &options, region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("counter.lua")]).unwrap();
        assert_eq!(result.annotations.iter().map(|a| a.text.as_str()).collect::<Vec<_>>(), ["1", "2", "1", "3", "4", "2"]);
    }

    #[test]
    fn script_context_exposes_stacked_events_and_capture_metadata() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders");
        let mut fields = BTreeMap::new();
        fields.insert("miso".into(), "7F".into());
        let lower = [Annotation::new(1, 5, "word", "", fields)];
        let req = DecodeRequest { protocol: "dsview_nes_gamepad", channels: &[], options: &[],
            region: 0..8, sample_len: 8, sample_rate_hz: Some(1_000_000), lower: &lower, lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("nes_gamepad.lua")]).unwrap();
        assert_eq!(result.annotations[0].text, "A");
        assert_eq!(result.annotations[0].start_sample, 1);

        let rgb: Vec<_> = [0x12, 0x34, 0xab].iter().enumerate().map(|(i, byte)| {
            super::super::ProtocolPacket { start_sample: i as u64, end_sample: i as u64 + 1,
                kind: "DATA".into(), data: serde_json::json!({"mosi": byte}) }
        }).collect();
        let req = DecodeRequest { protocol: "dsview_rgb_led_spi", channels: &[], options: &[],
            region: 0..8, sample_len: 8, sample_rate_hz: Some(1_000_000), lower: &[], lower_packets: &rgb };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("rgb_led_spi.lua")]).unwrap();
        assert_eq!(result.annotations[0].text, "#1234ab");

        let packet = |start, value| super::super::ProtocolPacket { start_sample: start, end_sample: start + 1,
            kind: "DATA".into(), data: serde_json::json!({"mosi": value}) };
        let packets = [packet(1, 0x83), packet(2, 0x52)];
        let req = DecodeRequest { protocol: "dsview_adns5020", channels: &[], options: &[],
            region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &packets };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("adns5020.lua")]).unwrap();
        assert_eq!(result.annotations[0].text, "Delta_X: 0x52");
        assert_eq!(result.annotations[0].class, "write");

        let data = [0b0110_0110];
        let channels = [("data", &data[..])];
        let req = DecodeRequest { protocol: "dsview_pwm", channels: &channels, options: &[],
            region: 0..8, sample_len: 8, sample_rate_hz: Some(1_000_000), lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![dir.join("pwm.lua")]).unwrap();
        assert_eq!(result.annotations[1].text, "4e-06 s");
    }

    #[test]
    fn script_packets_preserve_nested_values_for_stacked_scripts() {
        let dir = std::env::temp_dir().join(format!("logicview-packets-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let parent = dir.join("parent.lua");
        let child = dir.join("child.lua");
        std::fs::write(&parent, r#"return { id='parent', name='Parent', decode=function()
            return { annotations={}, packets={{start_sample=1, end_sample=3, kind='FRAME',
                data={value=42, valid=true, bits={1,0,1}}}} }
            end }"#).unwrap();
        std::fs::write(&child, r#"return { id='child', name='Child', stack_on='parent', decode=function(s,e,bit,options,context)
            local p=context.packets[1]
            return {{start_sample=p.start_sample, end_sample=p.end_sample, class='data',
                text=string.format('%d:%s:%d', p.data.value, tostring(p.data.valid), p.data.bits[2])}}
            end }"#).unwrap();
        let request = DecodeRequest { protocol: "parent", channels: &[], options: &[], region: 0..4,
            sample_len: 4, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&request, &AtomicBool::new(false), vec![parent.clone()]).unwrap();
        let request = DecodeRequest { protocol: "child", lower_packets: &result.packets, ..request };
        let result = run_paths(&request, &AtomicBool::new(false), vec![child.clone()]).unwrap();
        assert_eq!(result.annotations[0].text, "42:true:0");
        std::fs::remove_file(parent).unwrap();
        std::fs::remove_file(child).unwrap();
        std::fs::remove_dir(dir).unwrap();
    }

    #[test]
    fn example_metadata_and_connected_inputs_support_options() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders/seven_segment.lua");
        let lua = lua().unwrap();
        let schema = metadata(&lua, &module(&lua, &path).unwrap()).unwrap();
        assert_eq!(schema.optional_channels, ["dp"]);
        assert_eq!(schema.options[0].default, "common-cathode");
        let high = [0xff];
        let low = [0x00];
        let channels = [("a", &high[..]), ("b", &low[..]), ("c", &low[..]),
            ("d", &high[..]), ("e", &high[..]), ("f", &high[..]), ("g", &high[..])];
        let options = [("polarity".into(), "common-anode".into())];
        let req = DecodeRequest { protocol: "dsview_seven_segment", channels: &channels, options: &options,
            region: 0..8, sample_len: 8, sample_rate_hz: None, lower: &[], lower_packets: &[] };
        let result = run_paths(&req, &AtomicBool::new(false), vec![path]).unwrap();
        assert_eq!(result.annotations[0].text, "1");
    }

}
