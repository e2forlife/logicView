//! Vendor control pipe and FPGA bring-up for a tested logic pod.

use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};

use nusb::transfer::{Buffer, Bulk, ControlIn, ControlOut, ControlType, In, Out, Recipient};
use nusb::{MaybeFuture, Speed};

use crate::profile::{
    BITSTREAM_NAME, HDL_VERSION, PLUS_PID, U3PRO32_PID, U3_BITSTREAM_NAME, U3_HDL_VERSION,
    U3_HS_SAMPLE_LEADER, VENDOR_ID,
};
use crate::HalError;

const REQ_WRITE: u8 = 0xB0;
const REQ_READ_SETUP: u8 = 0xB1;
const REQ_READ: u8 = 0xB2;
const EP_OUT: u8 = 0x02;

const DEST_VERSION: u8 = 0;
const DEST_STATUS: u8 = 2;
const DEST_PROG: u8 = 3;
const DEST_LED: u8 = 5;
const DEST_INTRDY: u8 = 6;
const DEST_WORDWIDE: u8 = 7;
const DEST_BULK: u8 = 10;
const DEST_REG_WRITE: u8 = 14;
const DEST_REG_READ: u8 = 15;

const BIT_PROG: u8 = 1 << 2;
const BIT_INIT: u8 = 1 << 5;
const BIT_DONE: u8 = 1 << 6;
const BIT_GPIF: u8 = 1 << 7;
const BIT_SYS_CLR: u8 = 1 << 3;
const BIT_OVERFLOW: u8 = 1 << 4;
const BIT_GREEN: u8 = 1 << 0;
const BIT_RED: u8 = 1 << 1;
const BIT_INTRDY: u8 = 1 << 7;
const BIT_WORDWIDE: u8 = 1;

const HDL_ADDR: u16 = 0x04;
const VTH_ADDR: u16 = 0x78;
const CTR0_ADDR: u16 = 0x70;
const ADCC_ADDR: u16 = 0x48;
const FORCE_RDY: u8 = 1 << 1;
const FORCE_STOP: u8 = 1 << 2;

/// Owns the claimed USB interface and model information for one prepared logic analyzer.
pub struct Pod {
    interface: nusb::Interface,
    pub firmware_major: u8,
    pub firmware_minor: u8,
    product_id: u16,
    speed: Option<Speed>,
}

/// Discovery information for a connected instrument, including models that cannot be opened.
pub struct ListedPod {
    pub id: String,
    pub name: String,
    pub product_id: u16,
    /// The bus enumerated this pod at SuperSpeed or SuperSpeedPlus.
    pub super_speed: bool,
}

/// A plugged-in high-speed Plus is vendor `0x2A0E` product `0x0020`.
/// Speed is not part of that identity: some hosts omit it until the device is open.
pub fn matches_plus(vendor_id: u16, product_id: u16) -> bool {
    vendor_id == VENDOR_ID && product_id == PLUS_PID
}

/// Product ids this build will open and arm.
pub fn supported_product(product_id: u16) -> bool {
    product_id == PLUS_PID || product_id == U3PRO32_PID
}

/// Every DreamSourceLab device on the bus, whether or not this build can open it.
pub fn list_pods() -> Result<Vec<ListedPod>, HalError> {
    let devices = nusb::list_devices()
        .wait()
        .map_err(|err| HalError::Usb(err.to_string()))?;
    let mut found = Vec::new();
    for dev in devices {
        if let Some(pod) = describe_listed(
            dev.vendor_id(),
            dev.product_id(),
            dev.speed(),
            dev.product_string(),
        ) {
            found.push(pod);
        }
    }
    Ok(found)
}

/// Plus pods only. Prefer [`list_pods`] when the caller wants the whole scan.
pub fn list_plus() -> Result<Vec<ListedPod>, HalError> {
    let mut pods = list_pods()?;
    pods.retain(|pod| matches_plus(VENDOR_ID, pod.product_id));
    Ok(pods)
}

/// Builds the device-drawer identity from USB discovery data without opening the instrument.
pub(crate) fn describe_listed(
    vendor_id: u16,
    product_id: u16,
    speed: Option<Speed>,
    product_string: Option<&str>,
) -> Option<ListedPod> {
    if vendor_id != VENDOR_ID {
        return None;
    }
    let profile_name = crate::logic_profile(product_id)
        .map(|profile| profile.name)
        .unwrap_or("DreamSourceLab");
    let _ = product_string;
    let name = profile_name.to_string();
    Some(ListedPod {
        id: format!("usb:{vendor_id:04x}:{product_id:04x}"),
        name,
        product_id,
        super_speed: matches!(speed, Some(Speed::Super | Speed::SuperPlus)),
    })
}

/// The bulk-write length covers the first record. A 32-channel capture then
/// sends the second record as its own transfer.
fn split_arm_image(image: &[u8]) -> (&[u8], Option<&[u8]>) {
    const SYNC: [u8; 4] = u32::to_le_bytes(logicview_proto::OPEN_SYNC);
    if image.len() > 8 {
        if let Some(pos) = image[4..].windows(4).position(|window| window == SYNC) {
            let at = pos + 4;
            return (&image[..at], Some(&image[at..]));
        }
    }
    (image, None)
}

impl Pod {
    /// Opens the first supported pod and prepares its firmware and sampling hardware.
    pub fn open() -> Result<Self, HalError> {
        Self::open_product(None)
    }

    /// Open one tested product. `None` opens the first tested pod on the bus.
    pub fn open_product(product_id: Option<u16>) -> Result<Self, HalError> {
        if let Some(pid) = product_id {
            if !supported_product(pid) {
                return Err(HalError::Message(format!(
                    "product {pid:#06x} is not opened"
                )));
            }
        }
        let info = nusb::list_devices()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?
            .find(|dev| {
                dev.vendor_id() == VENDOR_ID
                    && supported_product(dev.product_id())
                    && product_id.is_none_or(|pid| dev.product_id() == pid)
            })
            .ok_or(HalError::NotFound)?;
        let product_id = info.product_id();
        let device = info
            .open()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let speed = device.speed();
        let interface = device
            .claim_interface(0)
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let mut pod = Self {
            interface,
            firmware_major: 0,
            firmware_minor: 0,
            product_id,
            speed,
        };
        let version = pod.read(DEST_VERSION, 0, 2)?;
        if version.len() < 2 {
            return Err(HalError::Usb("firmware version read was short".into()));
        }
        pod.firmware_major = version[0];
        pod.firmware_minor = version[1];
        if pod.firmware_major < 2 {
            return Err(HalError::FirmwareTooOld {
                major: pod.firmware_major,
                minor: pod.firmware_minor,
            });
        }
        pod.ensure_fpga()?;
        pod.init_sample_clock()?;
        let _ = pod.clear_control();
        Ok(pod)
    }

    /// Identifies the opened hardware profile used to select capture behavior.
    pub fn product_id(&self) -> u16 {
        self.product_id
    }

    /// Returns the negotiated USB speed used to choose transfer and sampling limits.
    pub fn speed(&self) -> Option<Speed> {
        self.speed
    }

    /// High-speed U3 uploads insert one 512-byte bulk packet between the
    /// header and the samples. The packet is structural: skipping it by
    /// looking for zeros would drop a real all-low capture.
    pub fn sample_leader(&self) -> u64 {
        if self.product_id == U3PRO32_PID && self.speed == Some(Speed::High) {
            U3_HS_SAMPLE_LEADER
        } else {
            0
        }
    }

    /// Reads the device state used to coordinate FPGA setup and capture transfers.
    pub fn status(&self) -> Result<u8, HalError> {
        let bytes = self.read(DEST_STATUS, 0, 1)?;
        bytes
            .first()
            .copied()
            .ok_or_else(|| HalError::Usb("status read was empty".into()))
    }

    /// Reports whether the device recorded a capture overflow.
    pub fn overflow(&self) -> Result<bool, HalError> {
        Ok(self.status()? & BIT_OVERFLOW != 0)
    }

    /// Programs the logic input threshold using a code selected by the hardware profile.
    pub fn set_threshold(&self, code: u8) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, VTH_ADDR, &[code])
    }

    /// One byte from the I2C register window. The buffer can be stale past the
    /// byte this command writes, so the caller asks for a single byte.
    pub fn read_register(&self, offset: u16) -> Result<u8, HalError> {
        let bytes = self.read(DEST_REG_READ, offset, 1)?;
        bytes
            .first()
            .copied()
            .ok_or_else(|| HalError::Usb("register read was empty".into()))
    }

    /// Asks an unfinished acquisition to become ready for sample upload.
    pub(crate) fn force_ready(&self) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, CTR0_ADDR, &[FORCE_RDY])
    }

    /// Clear the force-ready and force-stop bits before an arm.
    pub(crate) fn clear_control(&self) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, CTR0_ADDR, &[0])
    }

    /// Asks the device to abandon the current acquisition.
    pub(crate) fn force_stop(&self) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, CTR0_ADDR, &[FORCE_STOP])
    }

    /// Uploads the prepared arm records and waits for the device transfer handshake.
    pub(crate) fn arm_image(&self, image: &[u8]) -> Result<(), HalError> {
        if !self.link_is_super() {
            self.write(DEST_WORDWIDE, &[BIT_WORDWIDE])?;
        }
        let (primary, extra) = split_arm_image(image);
        let words = (primary.len() / 2) as u32;
        let len = words.to_le_bytes();
        self.write(DEST_BULK, &len[..3])?;
        let start = Instant::now();
        loop {
            if self.status()? & BIT_SYS_CLR != 0 {
                break;
            }
            if start.elapsed() > Duration::from_millis(500) {
                return Err(HalError::Message(
                    "the pod did not clear before the arm image".into(),
                ));
            }
        }
        self.bulk_out(primary)?;
        if let Some(extra) = extra {
            self.bulk_out(extra)?;
        }
        self.write(DEST_INTRDY, &[BIT_INTRDY])?;
        self.wait_status(BIT_GPIF, Duration::from_millis(500))?;
        self.write(DEST_INTRDY, &[!BIT_INTRDY])?;
        Ok(())
    }

    /// Starts acquisition after the arm image and input transfer queue are ready.
    pub(crate) fn start(&self) -> Result<(), HalError> {
        self.write(8, &[])
    }

    /// Stops device acquisition as part of capture completion or cleanup.
    pub(crate) fn stop(&self) -> Result<(), HalError> {
        self.write(9, &[])
    }

    /// Borrows the claimed USB interface for the capture transfer loop.
    pub(crate) fn interface(&self) -> &nusb::Interface {
        &self.interface
    }

    /// Bulk IN max packet. High speed is 512. Super speed is 1024. A read
    /// shorter than this packet is rejected by the host stack.
    pub(crate) fn bulk_in_packet(&self) -> usize {
        const FALLBACK: usize = 512;
        for descriptor in self.interface.descriptors() {
            for endpoint in descriptor.endpoints() {
                if endpoint.address() == 0x86 {
                    let size = endpoint.max_packet_size();
                    if size >= FALLBACK {
                        return size;
                    }
                }
            }
        }
        FALLBACK
    }

    /// Reset the bulk pipes. A timed-out capture can leave an endpoint halted,
    /// and later reads then sit until the host gives up.
    pub(crate) fn clear_pipes(&self) -> Result<(), HalError> {
        let mut incoming = self
            .interface
            .endpoint::<Bulk, In>(0x86)
            .map_err(|err| HalError::Usb(err.to_string()))?;
        incoming
            .clear_halt()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let mut outgoing = self
            .interface
            .endpoint::<Bulk, Out>(EP_OUT)
            .map_err(|err| HalError::Usb(err.to_string()))?;
        outgoing
            .clear_halt()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        Ok(())
    }

    /// Program the FPGA from the bitstream on disk even when DONE is already set.
    pub fn reload_fpga(&self) -> Result<(), HalError> {
        let _ = self.force_ready();
        let _ = self.stop();
        self.load_bitstream()?;
        let status = self.status()?;
        if status & BIT_DONE == 0 {
            return Err(HalError::Message(format!(
                "FPGA DONE stayed clear after configuration ({status:#04x})"
            )));
        }
        self.accept_hdl()?;
        self.init_sample_clock()
    }

    /// Accepts an already configured FPGA or loads the required external bitstream.
    fn ensure_fpga(&self) -> Result<(), HalError> {
        if self.status()? & BIT_DONE != 0 {
            return self.accept_hdl();
        }
        self.load_bitstream()
    }

    /// Reads the hardware-specific FPGA image from an external location and configures the pod.
    fn load_bitstream(&self) -> Result<(), HalError> {
        let path = bitstream_path(self.bitstream_name())?;
        let image = std::fs::read(&path).map_err(|err| {
            HalError::Message(format!("could not read {}: {err}", path.display()))
        })?;
        self.configure_fpga(&image)
    }

    /// Selects the external FPGA image required by the opened device model.
    fn bitstream_name(&self) -> &'static str {
        if self.product_id == U3PRO32_PID {
            U3_BITSTREAM_NAME
        } else {
            BITSTREAM_NAME
        }
    }

    /// Selects the FPGA interface version expected by this hardware backend.
    fn hdl_expected(&self) -> u8 {
        if self.product_id == U3PRO32_PID {
            U3_HDL_VERSION
        } else {
            HDL_VERSION
        }
    }

    /// Checks the configured FPGA interface, allowing the measured post-capture state of the wider
    /// pod.
    fn accept_hdl(&self) -> Result<(), HalError> {
        let found = match self.read(DEST_REG_READ, 0, (HDL_ADDR as u8) + 1) {
            Ok(window) => window.get(HDL_ADDR as usize).copied().unwrap_or(0),
            Err(_) if self.product_id == U3PRO32_PID => return Ok(()),
            Err(err) => return Err(err),
        };
        let expected = self.hdl_expected();
        let ok = if self.product_id == U3PRO32_PID {
            // 0x0E after configuration, 0 after a capture. DONE is the load bit.
            found == 0 || found == expected
        } else {
            found == expected
        };
        if ok {
            Ok(())
        } else {
            Err(HalError::HdlMismatch { found, expected })
        }
    }

    /// Performs the model-specific programming handshake and uploads the user-supplied FPGA image.
    fn configure_fpga(&self, image: &[u8]) -> Result<(), HalError> {
        if self.product_id == U3PRO32_PID {
            // The GPIF stays word-wide across PROG unless this is cleared
            // first, and the bitstream then never sets DONE.
            self.write(DEST_WORDWIDE, &[0])?;
            self.write(DEST_PROG, &[!BIT_PROG])?;
            self.write(DEST_LED, &[0x00])?;
        } else {
            self.write(DEST_PROG, &[!BIT_PROG])?;
            self.write(DEST_LED, &[!BIT_GREEN & !BIT_RED])?;
        }
        thread::sleep(Duration::from_millis(20));
        self.write(DEST_PROG, &[BIT_PROG])?;
        self.wait_status(BIT_INIT, Duration::from_millis(800))?;
        self.write(DEST_INTRDY, &[!BIT_INTRDY])?;
        let len = (image.len() as u32).to_le_bytes();
        self.write(DEST_BULK, &len[..3])?;
        self.bulk_out(image)?;
        self.write(DEST_INTRDY, &[BIT_INTRDY])?;
        self.wait_status(BIT_GPIF, Duration::from_secs(3))?;
        self.write(DEST_INTRDY, &[!BIT_INTRDY])?;
        self.wait_status(BIT_DONE, Duration::from_secs(5))?;
        self.write(DEST_LED, &[BIT_GREEN])?;
        self.write(DEST_WORDWIDE, &[BIT_WORDWIDE])?;
        Ok(())
    }

    /// Waits for a device handshake state with a bounded timeout.
    fn wait_status(&self, bit: u8, limit: Duration) -> Result<(), HalError> {
        let start = Instant::now();
        loop {
            if self.status()? & bit != 0 {
                return Ok(());
            }
            if start.elapsed() > limit {
                return Err(HalError::Message(format!(
                    "timed out waiting for status bit {bit:#04x}"
                )));
            }
            thread::sleep(Duration::from_millis(20));
        }
    }

    /// Reports whether the opened pod has a USB link that supports the wider streaming limits.
    pub fn link_is_super(&self) -> bool {
        matches!(self.speed, Some(Speed::Super | Speed::SuperPlus))
    }

    /// Program the 500 MHz sample clock on a U3Pro32. The Plus has no synthesizer
    /// on this path. The last group waits 10 ms so the clock can lock.
    fn init_sample_clock(&self) -> Result<(), HalError> {
        if self.product_id != U3PRO32_PID {
            return Ok(());
        }
        self.write_reg(ADCC_ADDR + 2, 0x01)?;
        for byte in [0x01, 0x61, 0x00, 0x30] {
            self.write_reg(ADCC_ADDR, byte)?;
        }
        for byte in [0x01, 0x40, 0xF1, 0x46] {
            self.write_reg(ADCC_ADDR, byte)?;
        }
        thread::sleep(Duration::from_millis(10));
        for byte in [0x01, 0x62, 0x3D, 0x40] {
            self.write_reg(ADCC_ADDR, byte)?;
        }
        Ok(())
    }

    /// Programs one device register through the vendor control interface.
    fn write_reg(&self, addr: u16, value: u8) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, addr, &[value])
    }

    /// Transfers a complete arm record or FPGA image, rejecting incomplete USB writes.
    fn bulk_out(&self, data: &[u8]) -> Result<(), HalError> {
        let mut ep = self
            .interface
            .endpoint::<Bulk, Out>(EP_OUT)
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let done = ep.transfer_blocking(Buffer::from(data.to_vec()), Duration::from_secs(3));
        if done.status.is_err() || done.actual_len != data.len() {
            return Err(HalError::Usb(format!(
                "bulk OUT {:?} transferred {} of {} bytes",
                done.status,
                done.actual_len,
                data.len()
            )));
        }
        Ok(())
    }

    /// Sends a vendor control command with no register offset.
    fn write(&self, dest: u8, payload: &[u8]) -> Result<(), HalError> {
        self.write_at(dest, 0, payload)
    }

    /// Sends a bounded vendor control payload to the selected destination and offset.
    fn write_at(&self, dest: u8, offset: u16, payload: &[u8]) -> Result<(), HalError> {
        if payload.len() > 60 {
            return Err(HalError::Message(
                "control write is longer than 60 bytes".into(),
            ));
        }
        let mut body = vec![dest, offset as u8, (offset >> 8) as u8, payload.len() as u8];
        body.extend_from_slice(payload);
        self.interface
            .control_out(
                ControlOut {
                    control_type: ControlType::Vendor,
                    recipient: Recipient::Device,
                    request: REQ_WRITE,
                    value: 0,
                    index: 0,
                    data: &body,
                },
                Duration::from_secs(3),
            )
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))
    }

    /// Requests a vendor control read and collects the device's response after its setup delay.
    fn read(&self, dest: u8, offset: u16, size: u8) -> Result<Vec<u8>, HalError> {
        let header = [dest, offset as u8, (offset >> 8) as u8, size];
        self.interface
            .control_out(
                ControlOut {
                    control_type: ControlType::Vendor,
                    recipient: Recipient::Device,
                    request: REQ_READ_SETUP,
                    value: 0,
                    index: 0,
                    data: &header,
                },
                Duration::from_secs(3),
            )
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        thread::sleep(Duration::from_millis(10));
        self.interface
            .control_in(
                ControlIn {
                    control_type: ControlType::Vendor,
                    recipient: Recipient::Device,
                    request: REQ_READ,
                    value: 0,
                    index: 0,
                    length: u16::from(size),
                },
                Duration::from_secs(3),
            )
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))
    }
}

/// Locates a user-supplied FPGA image and reports all searched locations on failure.
fn bitstream_path(file_name: &str) -> Result<PathBuf, HalError> {
    let mut tried = Vec::new();
    if let Ok(dir) = std::env::var("LOGICVIEW_FIRMWARE_DIR") {
        let path = PathBuf::from(dir).join(file_name);
        if path.is_file() {
            return Ok(path);
        }
        tried.push(path);
    }
    for dir in candidate_dirs() {
        let path = dir.join(file_name);
        if path.is_file() {
            return Ok(path);
        }
        tried.push(path);
    }
    let tried = tried
        .iter()
        .map(|path| path.display().to_string())
        .collect::<Vec<_>>()
        .join("; ");
    Err(HalError::FirmwareMissing {
        file: file_name.to_string(),
        tried,
    })
}

/// Lists conventional external locations that may contain the required FPGA image.
fn candidate_dirs() -> Vec<PathBuf> {
    let mut dirs = dsview_res_dirs(
        std::env::var("ProgramFiles").ok().as_deref(),
        std::env::var("ProgramFiles(x86)").ok().as_deref(),
    );
    if let Ok(local) = std::env::var("LOCALAPPDATA") {
        dirs.push(Path::new(&local).join("Temp").join("lv-fw"));
    }
    dirs
}

/// DreamSourceLab installs keep bitstreams in `res`. Nothing from that folder
/// is copied into this repo; open reads the file in place.
fn dsview_res_dirs(program_files: Option<&str>, program_files_x86: Option<&str>) -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    for root in [program_files, program_files_x86].into_iter().flatten() {
        if root.is_empty() {
            continue;
        }
        let path = Path::new(root).join("DSView").join("res");
        if !dirs.contains(&path) {
            dirs.push(path);
        }
    }
    dirs
}

#[cfg(test)]
mod tests {
    //! Checks device identification and external bitstream discovery without claiming hardware.

    use super::{describe_listed, dsview_res_dirs, matches_plus, supported_product};
    use nusb::Speed;

    /// Checks that device identity and the openable-model allowlist remain distinct from discovery.
    #[test]
    fn plus_identity_is_the_tested_high_speed_pod() {
        assert!(matches_plus(0x2A0E, 0x0020));
        assert!(!matches_plus(0x2A0E, 0x0034));
        assert!(!matches_plus(0x1234, 0x0020));
        assert!(supported_product(0x0020));
        assert!(supported_product(0x002C));
        assert!(!supported_product(0x0034));
    }

    /// Checks that discovery exposes meaningful model and connection information.
    #[test]
    fn scan_names_the_plugged_in_plus_and_a_u3pro32() {
        let plus = describe_listed(
            0x2A0E,
            0x0020,
            Some(Speed::High),
            Some("USB-based DSL Instrument v2"),
        )
        .unwrap();
        assert_eq!(plus.id, "usb:2a0e:0020");
        assert_eq!(plus.product_id, 0x0020);
        assert_eq!(plus.name, "DSLogic Plus");

        let wide = describe_listed(0x2A0E, 0x002C, Some(Speed::Super), None).unwrap();
        assert_eq!(wide.id, "usb:2a0e:002c");
        assert_eq!(wide.name, "DSLogic U3Pro32");
        assert!(wide.super_speed);
        assert!(!plus.super_speed);
        assert!(describe_listed(0x1234, 0x0020, None, None).is_none());
    }

    /// Checks the external installation paths used to locate user-supplied bitstreams.
    #[test]
    fn firmware_search_includes_a_dsview_install() {
        let dirs = dsview_res_dirs(Some(r"C:\Program Files"), Some(r"C:\Program Files (x86)"));
        assert_eq!(dirs.len(), 2);
        assert_eq!(dirs[0].file_name().unwrap(), "res");
        assert_eq!(dirs[0].parent().unwrap().file_name().unwrap(), "DSView");
        assert!(dirs[1].parent().unwrap().ends_with("DSView"));
        assert!(dsview_res_dirs(Some(""), None).is_empty());
    }
}
