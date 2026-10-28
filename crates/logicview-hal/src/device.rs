//! Vendor control pipe and FPGA bring-up for the Plus pod.

use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};

use nusb::transfer::{Bulk, Buffer, ControlIn, ControlOut, ControlType, Out, Recipient};
use nusb::MaybeFuture;

use crate::profile::{BITSTREAM_NAME, HDL_VERSION, PLUS_PID, VENDOR_ID};
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

pub struct Pod {
    interface: nusb::Interface,
    pub firmware_major: u8,
    pub firmware_minor: u8,
}

pub struct ListedPod {
    pub id: String,
    pub name: String,
    pub product_id: u16,
}

pub fn list_plus() -> Result<Vec<ListedPod>, HalError> {
    let devices = nusb::list_devices()
        .wait()
        .map_err(|err| HalError::Usb(err.to_string()))?;
    let mut found = Vec::new();
    for dev in devices {
        if dev.vendor_id() == VENDOR_ID && dev.product_id() == PLUS_PID && dev.speed() == Some(nusb::Speed::High)
        {
            let product = dev.product_string().unwrap_or("DSLogic Plus");
            found.push(ListedPod {
                id: crate::DEVICE_ID.to_string(),
                name: format!("{product} ({:04x}:{:04x})", dev.vendor_id(), dev.product_id()),
                product_id: dev.product_id(),
            });
        }
    }
    Ok(found)
}

impl Pod {
    pub fn open() -> Result<Self, HalError> {
        let info = nusb::list_devices()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?
            .find(|dev| {
                dev.vendor_id() == VENDOR_ID
                    && dev.product_id() == PLUS_PID
                    && dev.speed() == Some(nusb::Speed::High)
            })
            .ok_or(HalError::NotFound)?;
        let device = info
            .open()
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let interface = device
            .claim_interface(0)
            .wait()
            .map_err(|err| HalError::Usb(err.to_string()))?;
        let mut pod = Self {
            interface,
            firmware_major: 0,
            firmware_minor: 0,
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
        Ok(pod)
    }

    pub fn status(&self) -> Result<u8, HalError> {
        let bytes = self.read(DEST_STATUS, 0, 1)?;
        bytes
            .first()
            .copied()
            .ok_or_else(|| HalError::Usb("status read was empty".into()))
    }

    pub fn overflow(&self) -> Result<bool, HalError> {
        Ok(self.status()? & BIT_OVERFLOW != 0)
    }

    pub fn set_threshold(&self, code: u8) -> Result<(), HalError> {
        self.write_at(DEST_REG_WRITE, VTH_ADDR, &[code])
    }

    pub(crate) fn arm_image(&self, image: &[u8]) -> Result<(), HalError> {
        self.write(DEST_WORDWIDE, &[BIT_WORDWIDE])?;
        let words = (image.len() / 2) as u32;
        let len = words.to_le_bytes();
        self.write(DEST_BULK, &len[..3])?;
        let start = Instant::now();
        loop {
            if self.status()? & BIT_SYS_CLR != 0 {
                break;
            }
            if start.elapsed() > Duration::from_millis(500) {
                return Err(HalError::Message("the pod did not clear before the arm image".into()));
            }
        }
        self.bulk_out(image)?;
        self.write(DEST_INTRDY, &[BIT_INTRDY])?;
        self.wait_status(BIT_GPIF, Duration::from_millis(500))?;
        self.write(DEST_INTRDY, &[!BIT_INTRDY])?;
        Ok(())
    }

    pub(crate) fn start(&self) -> Result<(), HalError> {
        self.write(8, &[])
    }

    pub(crate) fn stop(&self) -> Result<(), HalError> {
        self.write(9, &[])
    }

    pub(crate) fn interface(&self) -> &nusb::Interface {
        &self.interface
    }

    fn ensure_fpga(&self) -> Result<(), HalError> {
        let status = self.status()?;
        if status & BIT_DONE != 0 {
            let window = self.read(DEST_REG_READ, 0, (HDL_ADDR as u8) + 1)?;
            let found = window.get(HDL_ADDR as usize).copied().unwrap_or(0);
            if found != HDL_VERSION {
                return Err(HalError::HdlMismatch {
                    found,
                    expected: HDL_VERSION,
                });
            }
            return Ok(());
        }
        let path = bitstream_path()?;
        let image = std::fs::read(&path).map_err(|err| {
            HalError::Message(format!("could not read {}: {err}", path.display()))
        })?;
        self.configure_fpga(&image)
    }

    fn configure_fpga(&self, image: &[u8]) -> Result<(), HalError> {
        self.write(DEST_PROG, &[!BIT_PROG])?;
        self.write(DEST_LED, &[!BIT_GREEN & !BIT_RED])?;
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
        self.wait_status(BIT_DONE, Duration::from_secs(3))?;
        self.write(DEST_LED, &[BIT_GREEN])?;
        self.write(DEST_WORDWIDE, &[BIT_WORDWIDE])?;
        Ok(())
    }

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

    fn write(&self, dest: u8, payload: &[u8]) -> Result<(), HalError> {
        self.write_at(dest, 0, payload)
    }

    fn write_at(&self, dest: u8, offset: u16, payload: &[u8]) -> Result<(), HalError> {
        if payload.len() > 60 {
            return Err(HalError::Message("control write is longer than 60 bytes".into()));
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

fn bitstream_path() -> Result<PathBuf, HalError> {
    let mut tried = Vec::new();
    if let Ok(dir) = std::env::var("LOGICVIEW_FIRMWARE_DIR") {
        let path = PathBuf::from(dir).join(BITSTREAM_NAME);
        if path.is_file() {
            return Ok(path);
        }
        tried.push(path);
    }
    for dir in candidate_dirs() {
        let path = dir.join(BITSTREAM_NAME);
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
        file: BITSTREAM_NAME.to_string(),
        tried,
    })
}

fn candidate_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Ok(local) = std::env::var("LOCALAPPDATA") {
        dirs.push(Path::new(&local).join("Temp").join("lv-fw"));
    }
    dirs
}
