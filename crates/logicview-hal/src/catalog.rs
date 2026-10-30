//! Logic-pod profiles used to name a device and to know how many channels it
//! would contribute to a stacked waveform.
//!
//! The high-speed DSLogic Plus (`0x0020`) and the high-speed DSLogic U3Pro32
//! (`0x002C`) have been captured on hardware. Every other product id is listed
//! so a session can show what a stack would look like. LogicView refuses to
//! open those ids.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LogicProfile {
    pub product_id: u16,
    pub name: &'static str,
    pub channels: u8,
    pub hardware_tested: bool,
    pub note: &'static str,
}

const UNTESTED: &str =
    "Channel count only. Not tested on hardware; this product id cannot be opened.";

const PROFILES: &[LogicProfile] = &[
    LogicProfile {
        product_id: 0x0001,
        name: "DSLogic",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0003,
        name: "DSLogic Pro",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0020,
        name: "DSLogic Plus",
        channels: 16,
        hardware_tested: true,
        note: "High-speed buffer and stream were checked on one Plus. Arming two USB pods at once is not verified.",
    },
    LogicProfile {
        product_id: 0x0021,
        name: "DSLogic Basic",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0029,
        name: "DSLogic U2Basic",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x002A,
        name: "DSLogic U3Pro16",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x002C,
        name: "DSLogic U3Pro32",
        channels: 32,
        hardware_tested: true,
        note: "High-speed and Super-speed buffer and stream were checked on one U3Pro32.",
    },
    LogicProfile {
        product_id: 0x002D,
        name: "DSLogic U2Pro16",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0030,
        name: "DSLogic Plus (Pango)",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0031,
        name: "DSLogic U2Basic (Pango)",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0034,
        name: "DSLogic Plus (Pango v2)",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
    LogicProfile {
        product_id: 0x0035,
        name: "DSLogic U2Basic (Pango v2)",
        channels: 16,
        hardware_tested: false,
        note: UNTESTED,
    },
];

/// Lists known model identities, distinguishing tested hardware from descriptive entries.
pub fn logic_profiles() -> &'static [LogicProfile] {
    PROFILES
}

/// Looks up a model profile without implying that the device can be opened.
pub fn logic_profile(product_id: u16) -> Option<&'static LogicProfile> {
    PROFILES
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
