//! Persistent application preferences shared by the UI, hardware, and decoder engine.
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Preferences {
    pub firmware_dir: String,
    pub scripts_dir: String,
    pub theme: String,
    pub mcp_enabled: bool,
    pub mcp_port: u16,
}
impl Default for Preferences {
    fn default() -> Self { Self { firmware_dir: String::new(), scripts_dir: String::new(), theme: "system".into(), mcp_enabled: false, mcp_port: 8765 } }
}
pub fn path() -> PathBuf {
    if let Some(path) = std::env::var_os("LOGICVIEW_CONFIG_FILE") { return path.into(); }
    let base = std::env::var_os("APPDATA").or_else(|| std::env::var_os("XDG_CONFIG_HOME"))
        .map(PathBuf::from).or_else(|| std::env::var_os("HOME").map(|p| PathBuf::from(p).join(".config")))
        .unwrap_or_else(std::env::temp_dir);
    base.join("LogicView").join("preferences.json")
}
pub fn load() -> Preferences { load_from(&path()) }
fn load_from(path: &std::path::Path) -> Preferences {
    std::fs::read(path).ok().and_then(|data| serde_json::from_slice(&data).ok()).unwrap_or_default()
}
pub fn save(prefs: &Preferences) -> Result<(), String> { save_to(&path(), prefs) }
fn save_to(path: &std::path::Path, prefs: &Preferences) -> Result<(), String> {
    if prefs.mcp_port == 0 { return Err("MCP port must be between 1 and 65535".into()); }
    if !["light", "dark", "system"].contains(&prefs.theme.as_str()) { return Err("Invalid theme".into()); }
    if let Some(dir) = path.parent() { std::fs::create_dir_all(dir).map_err(|e| e.to_string())?; }
    let bytes = serde_json::to_vec_pretty(prefs).map_err(|e| e.to_string())?;
    std::fs::write(path, bytes).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn preferences_round_trip_and_invalid_theme_is_rejected() {
        let file = std::env::temp_dir().join(format!("logicview-preferences-test-{}.json", std::process::id()));
        let prefs = Preferences { firmware_dir: "firmware".into(), scripts_dir: "scripts".into(), theme: "light".into(), mcp_enabled: true, mcp_port: 9135 };
        save_to(&file, &prefs).unwrap();
        let loaded = load_from(&file);
        assert_eq!(loaded.firmware_dir, "firmware");
        assert_eq!(loaded.scripts_dir, "scripts");
        assert_eq!(loaded.theme, "light");
        assert!(loaded.mcp_enabled);
        assert_eq!(loaded.mcp_port, 9135);
        assert!(!Preferences::default().mcp_enabled);
        assert!(save_to(&file, &Preferences { theme: "bad".into(), ..prefs }).is_err());
        assert_eq!(load_from(&file).theme, "light");
        std::fs::remove_file(file).unwrap();
    }
}
