//! Native `.lvcap` captures.
//!
//! A capture is either a directory or a zip file the tool owns:
//! `manifest.json`, `logic/<channel>.bin` (LSB-first bits), and `analog/0.f32`.
//! This is not a `.dsl` container. The text header for that format lives in
//! `logicview-proto` until the zip container is implemented.

use std::fs::{self, File};
use std::io::{Cursor, Read, Write};
use std::path::Path;

use serde::{Deserialize, Serialize};
use thiserror::Error;
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

pub const MANIFEST_VERSION: u32 = 1;

#[derive(Debug, Error)]
pub enum StoreError {
    #[error("{0}")]
    Io(#[from] std::io::Error),
    #[error("{0}")]
    Json(#[from] serde_json::Error),
    #[error("{0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("unsupported capture version {0}")]
    Version(u32),
    #[error("manifest is missing logic channel {0}")]
    MissingChannel(u32),
    #[error("analog samples are not a whole number of f32 values")]
    BadAnalog,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Manifest {
    pub version: u32,
    pub software: String,
    pub device: String,
    pub mode: String,
    pub sample_rate_hz: u64,
    pub sample_count: u64,
    pub duration_secs: f64,
    pub threshold_volts: f64,
    pub trigger: TriggerManifest,
    pub channels: Vec<ChannelManifest>,
    pub analog_channels: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct TriggerManifest {
    pub enabled: bool,
    pub position_samples: Option<u64>,
    pub instant: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ChannelManifest {
    pub index: u32,
    pub name: String,
    pub color: String,
}

#[derive(Clone, Debug)]
pub struct ArchiveData {
    pub manifest: Manifest,
    pub logic: Vec<Vec<u8>>,
    pub analog: Vec<f32>,
}

pub fn write_directory(path: &Path, data: &ArchiveData) -> Result<(), StoreError> {
    fs::create_dir_all(path)?;
    fs::create_dir_all(path.join("logic"))?;
    fs::write(
        path.join("manifest.json"),
        serde_json::to_vec_pretty(&data.manifest)?,
    )?;
    for (index, bytes) in data.logic.iter().enumerate() {
        fs::write(path.join("logic").join(format!("{index}.bin")), bytes)?;
    }
    if !data.analog.is_empty() {
        fs::create_dir_all(path.join("analog"))?;
        fs::write(path.join("analog/0.f32"), f32_bytes(&data.analog))?;
    }
    Ok(())
}

pub fn read_directory(path: &Path) -> Result<ArchiveData, StoreError> {
    let manifest: Manifest = serde_json::from_slice(&fs::read(path.join("manifest.json"))?)?;
    check_version(&manifest)?;
    let mut logic = Vec::with_capacity(manifest.channels.len());
    for channel in &manifest.channels {
        let file = path.join("logic").join(format!("{}.bin", channel.index));
        if !file.exists() {
            return Err(StoreError::MissingChannel(channel.index));
        }
        logic.push(fs::read(file)?);
    }
    let analog_path = path.join("analog/0.f32");
    let analog = if analog_path.exists() {
        decode_f32(&fs::read(analog_path)?)?
    } else {
        Vec::new()
    };
    Ok(ArchiveData {
        manifest,
        logic,
        analog,
    })
}

pub fn write_zip(path: &Path, data: &ArchiveData) -> Result<(), StoreError> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)?;
        }
    }
    let file = File::create(path)?;
    let mut writer = write_zip_to(file, data)?;
    writer.flush()?;
    Ok(())
}

pub fn write_zip_bytes(data: &ArchiveData) -> Result<Vec<u8>, StoreError> {
    let cursor = write_zip_to(Cursor::new(Vec::new()), data)?;
    Ok(cursor.into_inner())
}

pub fn read_zip(path: &Path) -> Result<ArchiveData, StoreError> {
    let file = File::open(path)?;
    read_zip_reader(file)
}

pub fn read_zip_bytes(bytes: &[u8]) -> Result<ArchiveData, StoreError> {
    read_zip_reader(Cursor::new(bytes.to_vec()))
}

pub fn read_any(path: &Path) -> Result<ArchiveData, StoreError> {
    if path.is_dir() {
        read_directory(path)
    } else {
        read_zip(path)
    }
}

fn write_zip_to<W: Write + std::io::Seek>(writer: W, data: &ArchiveData) -> Result<W, StoreError> {
    let mut zip = ZipWriter::new(writer);
    let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
    zip.start_file("manifest.json", opts)?;
    zip.write_all(&serde_json::to_vec_pretty(&data.manifest)?)?;
    for (index, bytes) in data.logic.iter().enumerate() {
        zip.start_file(format!("logic/{index}.bin"), opts)?;
        zip.write_all(bytes)?;
    }
    if !data.analog.is_empty() {
        zip.start_file("analog/0.f32", opts)?;
        zip.write_all(&f32_bytes(&data.analog))?;
    }
    Ok(zip.finish()?)
}

fn read_zip_reader<R: Read + std::io::Seek>(reader: R) -> Result<ArchiveData, StoreError> {
    let mut archive = ZipArchive::new(reader)?;
    let manifest: Manifest = {
        let mut file = archive.by_name("manifest.json")?;
        let mut text = String::new();
        file.read_to_string(&mut text)?;
        serde_json::from_str(&text)?
    };
    check_version(&manifest)?;
    let mut logic = Vec::with_capacity(manifest.channels.len());
    for channel in &manifest.channels {
        let name = format!("logic/{}.bin", channel.index);
        let mut file = archive
            .by_name(&name)
            .map_err(|_| StoreError::MissingChannel(channel.index))?;
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        logic.push(bytes);
    }
    let analog = match archive.by_name("analog/0.f32") {
        Ok(mut file) => {
            let mut bytes = Vec::new();
            file.read_to_end(&mut bytes)?;
            decode_f32(&bytes)?
        }
        Err(_) => Vec::new(),
    };
    Ok(ArchiveData {
        manifest,
        logic,
        analog,
    })
}

fn check_version(manifest: &Manifest) -> Result<(), StoreError> {
    if manifest.version != MANIFEST_VERSION {
        Err(StoreError::Version(manifest.version))
    } else {
        Ok(())
    }
}

/// Pieces of a version-3 `.dsl` zip: header text, session JSON, and one
/// bit-packed block per logic channel.
pub struct DslParts {
    pub header: String,
    pub session_json: String,
    pub channels: Vec<Vec<u8>>,
}

pub fn write_dsl_bytes(parts: &DslParts) -> Result<Vec<u8>, StoreError> {
    let cursor = Cursor::new(Vec::new());
    let mut zip = ZipWriter::new(cursor);
    let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
    zip.start_file("header", opts)?;
    zip.write_all(parts.header.as_bytes())?;
    zip.start_file("decoders", opts)?;
    zip.write_all(br#"{"version":2,"decoders":[]}"#)?;
    zip.start_file("session", opts)?;
    zip.write_all(parts.session_json.as_bytes())?;
    for (index, bytes) in parts.channels.iter().enumerate() {
        zip.start_file(format!("L-{index}/0"), opts)?;
        zip.write_all(bytes)?;
    }
    let cursor = zip.finish()?;
    Ok(cursor.into_inner())
}

pub fn read_dsl_channel(bytes: &[u8], channel: usize) -> Result<Vec<u8>, StoreError> {
    let mut archive = ZipArchive::new(Cursor::new(bytes.to_vec()))?;
    let mut file = archive
        .by_name(&format!("L-{channel}/0"))
        .map_err(|_| StoreError::MissingChannel(channel as u32))?;
    let mut out = Vec::new();
    file.read_to_end(&mut out)?;
    Ok(out)
}

fn f32_bytes(samples: &[f32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(samples.len() * 4);
    for sample in samples {
        out.extend_from_slice(&sample.to_le_bytes());
    }
    out
}

fn decode_f32(bytes: &[u8]) -> Result<Vec<f32>, StoreError> {
    let (chunks, rest) = bytes.as_chunks::<4>();
    if !rest.is_empty() {
        return Err(StoreError::BadAnalog);
    }
    Ok(chunks
        .iter()
        .map(|chunk| f32::from_le_bytes(*chunk))
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> ArchiveData {
        ArchiveData {
            manifest: Manifest {
                version: 1,
                software: "logicview 0.1.0".into(),
                device: "demo".into(),
                mode: "logic".into(),
                sample_rate_hz: 1_000_000,
                sample_count: 64,
                duration_secs: 0.000064,
                threshold_volts: 1.6,
                trigger: TriggerManifest {
                    enabled: false,
                    position_samples: None,
                    instant: false,
                },
                channels: vec![ChannelManifest {
                    index: 0,
                    name: "CLK".into(),
                    color: "#e2b340".into(),
                }],
                analog_channels: 1,
            },
            logic: vec![vec![0x0F, 0xF0, 0x00, 0xFF, 0x01, 0x02, 0x03, 0x04]],
            analog: vec![0.0, 0.5, -0.25, 1.0],
        }
    }

    #[test]
    fn directory_and_zip_round_trip() {
        let dir = std::env::temp_dir().join(format!("lvcap-dir-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        let data = sample();
        write_directory(&dir, &data).unwrap();
        let loaded = read_directory(&dir).unwrap();
        assert_eq!(loaded.manifest, data.manifest);
        assert_eq!(loaded.logic, data.logic);
        assert_eq!(loaded.analog, data.analog);
        let _ = fs::remove_dir_all(&dir);

        let bytes = write_zip_bytes(&data).unwrap();
        assert_eq!(&bytes[..2], b"PK");
        let from_zip = read_zip_bytes(&bytes).unwrap();
        assert_eq!(from_zip.manifest.sample_count, 64);
        assert_eq!(from_zip.logic, data.logic);
        assert_eq!(from_zip.analog, data.analog);
    }

    #[test]
    fn dsl_zip_keeps_the_header_and_channel_block() {
        let bytes = write_dsl_bytes(&DslParts {
            header: "[header]\nversion=3\n".into(),
            session_json: "{\"depth\":\"buffer\"}".into(),
            channels: vec![vec![0xAA, 0x55]],
        })
        .unwrap();
        assert_eq!(&bytes[..2], b"PK");
        let mut archive = ZipArchive::new(Cursor::new(bytes.clone())).unwrap();
        let mut header = String::new();
        archive
            .by_name("header")
            .unwrap()
            .read_to_string(&mut header)
            .unwrap();
        assert!(header.contains("version=3"));
        assert_eq!(read_dsl_channel(&bytes, 0).unwrap(), vec![0xAA, 0x55]);
    }
}
