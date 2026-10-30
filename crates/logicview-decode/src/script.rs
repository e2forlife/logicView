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
fn metadata(_lua: &Lua, module: &Table) -> Result<DecoderSchema, DecodeError> {
    let schema = DecoderSchema {
        id: module.get("id").map_err(|e| DecodeError::Message(e.to_string()))?,
        name: module.get("name").map_err(|e| DecodeError::Message(e.to_string()))?,
        channels: module.get::<Option<Vec<String>>>("channels").map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default(),
        optional_channels: Vec::new(),
        stack_on: module.get("stack_on").map_err(|e| DecodeError::Message(e.to_string()))?,
        classes: module.get::<Option<Vec<String>>>("classes").map_err(|e| DecodeError::Message(e.to_string()))?.unwrap_or_default(),
    };
    if schema.id.is_empty() || !schema.id.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') || schema.name.is_empty() || schema.stack_on.is_some() {
        return Err(DecodeError::Message("invalid scripted decoder metadata".into()));
    }
    Ok(DecoderSchema { optional_channels: schema.channels.clone(), ..schema })
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
    if cancel.load(Ordering::Relaxed) { return Ok(DecodeOutput { annotations: vec![], cancelled: true }); }
    for path in paths {
        let lua = lua()?;
        let m = match module(&lua, &path) { Ok(m) => m, Err(_) => continue };
        let schema = match metadata(&lua, &m) { Ok(m) => m, Err(_) => continue };
        if schema.id != request.protocol { continue; }
        let decode: mlua::Function = m.get("decode").map_err(|e| DecodeError::Message(e.to_string()))?;
        let options: BTreeMap<String, String> = request.options.iter().cloned().collect();
        let start = request.region.start.min(request.sample_len);
        let end = request.region.end.min(request.sample_len);
        let result = lua.scope(|scope| {
            let bit = scope.create_function(|_, (name, index): (String, u64)| {
                if index >= request.sample_len { return Ok(false); }
                Ok(request.channels.iter().find(|(n, _)| *n == name).is_some_and(|(_, bytes)| logicview_analysis::bit_at(bytes, index)))
            })?;
            decode.call::<Value>((start, end, bit, lua.to_value(&options)?))
        }).map_err(|e| DecodeError::Message(e.to_string()))?;
        #[derive(serde::Deserialize)]
        struct Row { start_sample: u64, end_sample: u64, class: String, text: String, #[serde(default)] fields: BTreeMap<String, String> }
        let rows: Vec<Row> = lua.from_value(result).map_err(|e| DecodeError::Message(e.to_string()))?;
        let mut annotations = Vec::new();
        for row in rows {
            if row.start_sample < start || row.end_sample > end || row.start_sample >= row.end_sample {
                return Err(DecodeError::Message("script returned an invalid annotation range".into()));
            }
            annotations.push(Annotation::new(row.start_sample, row.end_sample, row.class, row.text, row.fields));
        }
        return Ok(DecodeOutput { annotations, cancelled: false });
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
        let req = DecodeRequest { protocol: "test", channels: &channels, options: &[], region: 0..8, sample_len: 8, lower: &[] };
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

}
