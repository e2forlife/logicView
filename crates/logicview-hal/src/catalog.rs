//! Logic-pod profiles used to name a device and to know how many channels it
//! would contribute to a stacked waveform.
//!
//! The high-speed DSLogic Plus (`0x0020`) and the high-speed DSLogic U3Pro32
//! (`0x002C`) have been captured on hardware. Every other product id is listed
//! so a session can show what a stack would look like. LogicView refuses to
//! open those ids.

use serde::Deserialize;
use std::sync::OnceLock;

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
pub struct LogicProfile {
    pub vendor_id: u16,
    pub product_id: u16,
    pub name: String,
    pub channels: u8,
    pub hardware_tested: bool,
    pub firmware: String,
    pub note: String,
}
#[derive(Deserialize)]
struct Profiles {
    devices: Vec<LogicProfile>,
}

/// Loads external profiles once at startup, with bundled defaults as a fallback.
pub fn logic_profiles() -> &'static [LogicProfile] {
    static PROFILES: OnceLock<Vec<LogicProfile>> = OnceLock::new();
    PROFILES.get_or_init(|| {
        let explicit = std::env::var_os("LOGICVIEW_PROFILES").map(std::path::PathBuf::from);
        let candidates = explicit
            .into_iter()
            .chain([std::path::PathBuf::from("profiles.toml")])
            .chain(
                std::env::current_exe()
                    .ok()
                    .and_then(|p| p.parent().map(|p| p.join("profiles.toml"))),
            );
        for path in candidates {
            if let Ok(contents) = std::fs::read_to_string(&path) {
                match toml::from_str::<Profiles>(&contents) {
                    Ok(profiles) if !profiles.devices.is_empty() => return profiles.devices,
                    Ok(_) => eprintln!("{} contains no device profiles", path.display()),
                    Err(err) => eprintln!("Invalid profiles {}: {err}", path.display()),
                }
            }
        }
        toml::from_str::<Profiles>(include_str!("../../../profiles.toml"))
            .expect("bundled profiles are valid")
            .devices
    })
}

pub fn logic_profile(product_id: u16) -> Option<&'static LogicProfile> {
    logic_profiles()
        .iter()
        .find(|profile| profile.product_id == product_id)
}

#[cfg(test)]
mod tests {
    //! Checks which descriptive profiles are marked as verified hardware.

    use super::*;

    /// Checks that only hardware-verified model profiles advertise tested capture support.
    #[test]
    fn tested_profiles_are_the_plus_and_the_u3pro32() {
        let tested: Vec<_> = logic_profiles()
            .iter()
            .filter(|profile| profile.hardware_tested)
            .map(|profile| profile.product_id)
            .collect();
        assert_eq!(tested, vec![0x0020, 0x002C]);
        let wide = logic_profile(0x002C).unwrap();
        assert_eq!(wide.channels, 32);
        assert!(wide.hardware_tested);
        assert!(wide.note.contains("Super-speed"));
        assert!(logic_profile(0x0021).unwrap().note.contains("Not tested"));
        assert!(!logic_profile(0x0034).unwrap().hardware_tested);
    }
}
