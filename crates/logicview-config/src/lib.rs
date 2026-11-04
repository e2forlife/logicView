//! Persistent application preferences shared by the UI, hardware, and decoder engine.
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Preferences {
    pub firmware_dir: String,
    pub scripts_dir: String,
    pub theme: String,
    pub edge_snap: bool,
    pub mcp_enabled: bool,
    pub mcp_port: u16,
    /// Last folder used by Export Capture.
    pub export_dir: String,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            firmware_dir: String::new(),
            scripts_dir: String::new(),
            theme: "system".into(),
            edge_snap: true,
            mcp_enabled: false,
            mcp_port: 8765,
            export_dir: String::new(),
        }
    }
}
pub fn path() -> PathBuf {
    if let Some(path) = std::env::var_os("LOGICVIEW_CONFIG_FILE") {
        return path.into();
    }
    preferences_base_dir()
        .join("LogicView")
        .join("preferences.json")
}

/// Resolves the platform config directory that contains the LogicView folder.
fn preferences_base_dir() -> PathBuf {
    #[cfg(windows)]
    {
        std::env::var_os("APPDATA")
            .map(PathBuf::from)
            .unwrap_or_else(std::env::temp_dir)
    }
    #[cfg(not(windows))]
    {
        unix_preferences_base(
            std::env::var_os("XDG_CONFIG_HOME"),
            std::env::var_os("HOME"),
        )
    }
}

/// XDG config home, then `~/.config`, then the process temp directory.
#[cfg(not(windows))]
fn unix_preferences_base(
    xdg_config_home: Option<std::ffi::OsString>,
    home: Option<std::ffi::OsString>,
) -> PathBuf {
    xdg_config_home
        .map(PathBuf::from)
        .or_else(|| home.map(|path| PathBuf::from(path).join(".config")))
        .unwrap_or_else(std::env::temp_dir)
}
pub fn load() -> Preferences {
    load_from(&path())
}

/// Directory used when the decoder-script preference is blank.
///
/// The source-tree `examples/decoders` directory is preferred, then the same
/// relative path from the working directory and from the executable.
pub fn default_scripts_dir() -> PathBuf {
    let compiled = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../examples/decoders");
    let mut candidates = vec![compiled.clone(), PathBuf::from("examples/decoders")];
    if let Ok(current) = std::env::current_dir() {
        candidates.push(current.join("examples/decoders"));
    }
    if let Ok(exe) = std::env::current_exe() {
        let mut dir = exe.parent().map(|path| path.to_path_buf());
        for _ in 0..6 {
            let Some(path) = dir else { break };
            candidates.push(path.join("examples/decoders"));
            dir = path.parent().map(|parent| parent.to_path_buf());
        }
    }
    for candidate in candidates {
        if candidate.is_dir() {
            let resolved = candidate.canonicalize().unwrap_or(candidate);
            return friendly_path(resolved);
        }
    }
    friendly_path(compiled)
}

/// The saved script directory, or [`default_scripts_dir`] when it is blank.
pub fn effective_scripts_dir(prefs: &Preferences) -> String {
    if prefs.scripts_dir.is_empty() {
        default_scripts_dir().display().to_string()
    } else {
        prefs.scripts_dir.clone()
    }
}

fn friendly_path(path: PathBuf) -> PathBuf {
    let text = path.to_string_lossy();
    text.strip_prefix(r"\\?\")
        .map(PathBuf::from)
        .unwrap_or(path)
}
fn load_from(path: &std::path::Path) -> Preferences {
    std::fs::read(path)
        .ok()
        .and_then(|data| serde_json::from_slice(&data).ok())
        .unwrap_or_default()
}
pub fn save(prefs: &Preferences) -> Result<(), String> {
    save_to(&path(), prefs)
}
fn save_to(path: &std::path::Path, prefs: &Preferences) -> Result<(), String> {
    if prefs.mcp_port == 0 {
        return Err("MCP port must be between 1 and 65535".into());
    }
    if !["light", "dark", "system"].contains(&prefs.theme.as_str()) {
        return Err("Invalid theme".into());
    }
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    }
    let bytes = serde_json::to_vec_pretty(prefs).map_err(|e| e.to_string())?;
    std::fs::write(path, bytes).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn preferences_round_trip_and_invalid_theme_is_rejected() {
        let file = std::env::temp_dir().join(format!(
            "logicview-preferences-test-{}.json",
            std::process::id()
        ));
        let prefs = Preferences {
            firmware_dir: "firmware".into(),
            scripts_dir: "scripts".into(),
            theme: "light".into(),
            edge_snap: false,
            mcp_enabled: true,
            mcp_port: 9135,
            export_dir: "exports".into(),
        };
        save_to(&file, &prefs).unwrap();
        let loaded = load_from(&file);
        assert_eq!(loaded.firmware_dir, "firmware");
        assert_eq!(loaded.scripts_dir, "scripts");
        assert_eq!(loaded.theme, "light");
        assert!(!loaded.edge_snap);
        assert!(serde_json::from_str::<Preferences>("{}").unwrap().edge_snap);
        assert!(loaded.mcp_enabled);
        assert_eq!(loaded.mcp_port, 9135);
        assert_eq!(loaded.export_dir, "exports");
        assert!(Preferences::default().export_dir.is_empty());
        assert!(!Preferences::default().mcp_enabled);
        assert!(default_scripts_dir().ends_with("examples/decoders"));
        assert!(effective_scripts_dir(&Preferences::default()).contains("examples"));
        assert!(save_to(
            &file,
            &Preferences {
                theme: "bad".into(),
                ..prefs
            }
        )
        .is_err());
        assert_eq!(load_from(&file).theme, "light");
        std::fs::remove_file(file).unwrap();
    }

    #[cfg(not(windows))]
    #[test]
    fn unix_preferences_prefer_xdg_then_home_config() {
        let xdg = unix_preferences_base(Some("/tmp/xdg-config".into()), Some("/home/dev".into()));
        assert_eq!(xdg, PathBuf::from("/tmp/xdg-config"));
        let home = unix_preferences_base(None, Some("/home/dev".into()));
        assert_eq!(home, PathBuf::from("/home/dev/.config"));
        let fallback = unix_preferences_base(None, None);
        assert_eq!(fallback, std::env::temp_dir());
    }
}
