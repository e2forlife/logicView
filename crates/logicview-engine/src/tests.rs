//! Exercises the shared engine as a client would use it, using deterministic demo captures.
//!
//! These tests cover session state, protocol analysis, channel selection, persistence,
//! and the distinction between listed hardware and hardware that can be opened.

use std::time::Duration;

use logicview_capture::{CaptureError, DepthMode, RunPolicy, SessionConfig, TriggerStep};
use logicview_proto::{decode_arm, ModeFlags};

use super::{
    hardware_before_demo, install_usb_catalog, local_enable, BoundDevice, DeviceInfo, Engine,
    EngineError, StartMode,
};

/// Checks that native persistence preserves captured logic, analog values, and subsequent edge
/// searches.
#[tokio::test]
async fn five_second_demo_edge_survives_save_and_load() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 5_000,
                realtime: false,
                trigger_enabled: false,
                trigger_percent: 10.0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let status = engine
        .wait_until_settled("ses-1", Duration::from_secs(30))
        .await
        .unwrap();
    assert_eq!(status.phase, "stopped");
    assert_eq!(status.sample_count, 5_000_000);

    let rising = engine.search_edge(None, 0, 0, true, true).await.unwrap();
    assert_eq!(rising, Some(50));
    let falling = engine.search_edge(None, 0, 0, false, true).await.unwrap();
    assert_eq!(falling, Some(100));
    let analog = engine.analog_at(None, 250).await.unwrap();
    assert!(analog.is_some());

    let dir = std::env::temp_dir().join(format!("lvcap-five-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    engine.save_lvcap(None, &dir).await.unwrap();

    let reloaded = Engine::new();
    let loaded = reloaded.load_lvcap(None, &dir).await.unwrap();
    assert_eq!(loaded.sample_count, 5_000_000);
    assert_eq!(loaded.sample_rate_hz, 1_000_000);
    assert_eq!(
        reloaded.search_edge(None, 0, 0, true, true).await.unwrap(),
        rising
    );
    assert_eq!(
        reloaded.search_edge(None, 0, 50, true, true).await.unwrap(),
        Some(150)
    );
    assert_eq!(reloaded.analog_at(None, 250).await.unwrap(), analog);
    let _ = std::fs::remove_dir_all(&dir);
}

/// Checks that instant capture bypasses configured triggers while normal capture arms them.
#[tokio::test]
async fn instant_clears_the_trigger_enable_bit() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                realtime: false,
                trigger_enabled: true,
                trigger_percent: 20.0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Instant).await.unwrap();
    engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    let instant = decode_arm(&engine.arm_record(None).await.unwrap()).unwrap();
    assert!(instant.mode.contains(ModeFlags::INSTANT));
    assert!(!instant.mode.contains(ModeFlags::TRIGGER_ENABLE));

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                realtime: false,
                trigger_enabled: true,
                trigger_percent: 20.0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    let armed = decode_arm(&engine.arm_record(None).await.unwrap()).unwrap();
    assert!(armed.mode.contains(ModeFlags::TRIGGER_ENABLE));
    assert!(armed.mode.contains(ModeFlags::SERIAL_TRIGGER));
    assert!(!armed.mode.contains(ModeFlags::INSTANT));
    assert_eq!(armed.stage_count, 2);
    assert_eq!(armed.stages[0].mask, 1);
    assert_eq!(armed.stages[0].value, 0);
    assert_eq!(armed.stages[0].edge, 0);
    assert_eq!(armed.stages[1].mask, 1);
    assert_eq!(armed.stages[1].value, 1);
    assert_eq!(armed.stages[1].edge, 1);
    assert!(armed.trigger_position >= 64);
}

/// Exercises pattern navigation, saved measurements, cursor spans, and DSL export together.
#[tokio::test]
async fn pattern_cursors_and_dsl_round_trip_on_the_demo() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    let edge = engine
        .search_pattern(None, 0, 0, &[Some(true), Some(false)], true)
        .await
        .unwrap();
    assert_eq!(edge, Some(99));
    engine.set_cursor(None, 0, Some(50)).await.unwrap();
    engine.set_cursor(None, 1, Some(150)).await.unwrap();
    let span = engine.cursor_span(None, 0).await.unwrap();
    assert_eq!(span.samples, 100);
    let saved = engine.save_measurement(None, 0, 75).await.unwrap();
    assert_eq!(saved.pulse_width_samples, 50);
    assert_eq!(engine.measurements(None).await.unwrap().len(), 1);
    let dsl = engine.export_dsl(None).await.unwrap();
    assert_eq!(&dsl[..2], b"PK");
    let channel = logicview_store::read_dsl_channel(&dsl, 0).unwrap();
    assert!(!channel.is_empty());
}

/// Checks that physical instruments are presented ahead of demo sources.
#[test]
fn plugged_in_pods_are_listed_before_demo_devices() {
    let ordered = hardware_before_demo(vec![
        DeviceInfo {
            id: "demo".into(),
            name: "Demo".into(),
            kind: "demo".into(),
            connected: true,
            super_speed: false,
        },
        DeviceInfo {
            id: "usb:2a0e:0020".into(),
            name: "DSLogic Plus".into(),
            kind: "usb".into(),
            connected: true,
            super_speed: false,
        },
        DeviceInfo {
            id: "demo:spi".into(),
            name: "Demo SPI".into(),
            kind: "demo".into(),
            connected: true,
            super_speed: false,
        },
    ]);
    assert_eq!(
        ordered
            .iter()
            .map(|device| device.id.as_str())
            .collect::<Vec<_>>(),
        vec!["usb:2a0e:0020", "demo", "demo:spi"]
    );
}

/// Checks that an untested product remains discoverable in profiles but cannot be opened.
#[tokio::test]
async fn usb_connect_is_refused() {
    let engine = Engine::new();
    let error = engine.connect("usb:2a0e:0034").await.unwrap_err();
    let text = error.to_string();
    assert!(
        text.contains("not opened") && text.contains("hardware test"),
        "{text}"
    );
    let profiles = engine.list_profiles().await;
    assert!(profiles
        .iter()
        .any(|profile| { profile.product_id == 0x0020 && profile.hardware_tested }));
    assert!(profiles
        .iter()
        .any(|profile| profile.product_id == 0x002C && profile.hardware_tested));
    assert!(profiles
        .iter()
        .any(|profile| profile.product_id == 0x0034 && !profile.hardware_tested));
}

/// Exercises channel origins, measurements, stacked protocol decoding, and annotation searches.
#[tokio::test]
async fn two_demo_pods_stack_decode_and_measure_the_clock() {
    use std::collections::BTreeMap;

    let engine = Engine::new();
    engine.attach_device(None, "demo:spi").await.unwrap();
    let status = engine.status(None).await.unwrap();
    assert_eq!(status.channels.len(), 8);
    assert_eq!(status.channels[0].device_id, "demo");
    assert_eq!(status.channels[0].name, "CLK");
    assert_eq!(status.channels[2].name, "SDA");
    assert_eq!(status.channels[3].name, "SCL");
    assert_eq!(status.channels[4].device_id, "demo:spi");
    assert_eq!(status.channels[4].name, "SCK");
    assert_eq!(status.devices.len(), 2);

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();

    let pulse = engine.measure(None, 0, 75).await.unwrap();
    assert_eq!(pulse.pulse_width_samples, 50);
    assert_eq!(pulse.period_samples, Some(100));
    assert_eq!(pulse.frequency_hz, Some(10_000.0));
    assert_eq!(pulse.duty, Some(0.5));
    let saved = engine.save_measurement(None, 0, 75).await.unwrap();
    assert_eq!(saved.frequency_hz, Some(10_000.0));
    assert_eq!(saved.duty, Some(0.5));

    let mut i2c_channels = BTreeMap::new();
    i2c_channels.insert("scl".into(), "demo/SCL".into());
    i2c_channels.insert("sda".into(), "demo/SDA".into());
    let i2c = engine
        .add_decoder(None, "i2c", &i2c_channels, &BTreeMap::new(), None, None)
        .await
        .unwrap();
    let lua_i2c = engine
        .add_decoder(None, "1:i2c", &i2c_channels, &BTreeMap::new(), None, None)
        .await
        .unwrap();
    let eeprom = engine
        .add_decoder(
            None,
            "eeprom24",
            &BTreeMap::new(),
            &BTreeMap::new(),
            None,
            Some(&i2c.id),
        )
        .await
        .unwrap();
    assert_eq!(eeprom.stack_on.as_deref(), Some(i2c.id.as_str()));

    let mut spi_channels = BTreeMap::new();
    spi_channels.insert("sck".into(), "demo:spi/SCK".into());
    spi_channels.insert("mosi".into(), "demo:spi/MOSI".into());
    spi_channels.insert("miso".into(), "demo:spi/MISO".into());
    spi_channels.insert("cs".into(), "demo:spi/CS".into());
    engine
        .add_decoder(None, "spi", &spi_channels, &BTreeMap::new(), None, None)
        .await
        .unwrap();

    let lua_channels = BTreeMap::from([
        ("clk".into(), "demo:spi/SCK".into()),
        ("mosi".into(), "demo:spi/MOSI".into()),
        ("miso".into(), "demo:spi/MISO".into()),
        ("cs".into(), "demo:spi/CS".into()),
    ]);
    let lua_spi = engine
        .add_decoder(None, "1:spi", &lua_channels, &BTreeMap::new(), None, None)
        .await
        .unwrap();
    assert_eq!(lua_spi.channels.len(), 4);
    let updated = engine
        .update_decoder(None, &lua_spi.id, &lua_channels, &BTreeMap::new(), None)
        .await
        .unwrap();
    assert_eq!(updated.channels.len(), 4);

    let rows = engine
        .read_annotations(None, None, None, None, None, 0, 5_000)
        .await
        .unwrap();
    let page = engine.read_annotations(None, Some(&lua_i2c.id), None, None, None, 1, 3).await.unwrap();
    let expected: Vec<_> = rows.iter().filter(|row| row.decoder == lua_i2c.id).skip(1).take(3).collect();
    assert_eq!(page.iter().map(|row| (&row.class, row.start_sample, &row.text)).collect::<Vec<_>>(),
        expected.iter().map(|row| (&row.class, row.start_sample, &row.text)).collect::<Vec<_>>());
    let numeric_i2c = rows
        .iter()
        .find(|row| row.decoder == lua_i2c.id && row.fields.contains_key("value"))
        .expect("Lua I2C emits a numeric annotation");
    assert!(!numeric_i2c.text.contains("{$}"));
    assert!(numeric_i2c.text.contains(&numeric_i2c.fields["value"]));
    assert!(
        rows.iter().any(|row| row.decoder == lua_spi.id),
        "Lua SPI should emit annotations"
    );
    assert!(rows.iter().any(|row| {
        row.protocol == "i2c"
            && row.class == "address"
            && row.fields.get("address").map(String::as_str) == Some("50")
            && row.fields.get("read").map(String::as_str) == Some("false")
    }));
    assert!(rows.iter().any(|row| {
        row.protocol == "i2c"
            && row.class == "data"
            && row.fields.get("data").map(String::as_str) == Some("5A")
    }));
    assert!(rows
        .iter()
        .any(|row| row.protocol == "eeprom24" && row.text == "Write 0x10 = 0x5A"));
    assert!(rows
        .iter()
        .any(|row| row.protocol == "eeprom24" && row.text == "Read 0x10 = 0x5A"));
    assert!(rows.iter().any(|row| {
        row.protocol == "spi"
            && row.class == "word"
            && row.fields.get("mosi").map(String::as_str) == Some("A5")
            && row.fields.get("miso").map(String::as_str) == Some("3C")
    }));

    let found = engine.search_annotations(None, "A0-10-5A").await.unwrap();
    assert!(found.len() >= 3);
    let csv = engine
        .export_annotations(None, "csv", Some("Read 0x10"))
        .await
        .unwrap();
    assert!(csv.contains("Read 0x10 = 0x5A"));
    let text = engine
        .export_annotations(None, "text", Some("MOSI 0xA5"))
        .await
        .unwrap();
    assert!(text.contains("MOSI 0xA5 MISO 0x3C"));
}

/// Checks ordered trigger encoding and observed demo positions, including invalid sequence depth.
#[tokio::test]
async fn sequential_trigger_arms_on_channel_1_and_fires_on_channel_3() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                realtime: false,
                trigger_enabled: true,
                trigger_steps: vec![
                    TriggerStep {
                        channel: 1,
                        rising: true,
                    },
                    TriggerStep {
                        channel: 3,
                        rising: true,
                    },
                ],
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let status = engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    assert_eq!(status.trigger_sample, Some(40));
    assert!(status.warnings.is_empty(), "{:?}", status.warnings);
    let armed = decode_arm(&engine.arm_record(None).await.unwrap()).unwrap();
    assert_eq!(armed.stage_count, 2);
    assert!(armed.mode.contains(ModeFlags::TRIGGER_ENABLE));
    assert_eq!(armed.stages[0].mask, 1 << 1);
    assert_eq!(armed.stages[0].value, 1 << 1);
    assert_eq!(armed.stages[0].edge, 1 << 1);
    assert_eq!(armed.stages[0].count, 1);
    assert_eq!(armed.stages[1].mask, 1 << 3);
    assert_eq!(armed.stages[1].value, 1 << 3);
    assert_eq!(armed.stages[1].edge, 1 << 3);
    assert_eq!(armed.stages[1].count, 1);
    assert!(armed.upper.is_none());

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                realtime: false,
                trigger_enabled: true,
                trigger_steps: vec![
                    TriggerStep {
                        channel: 3,
                        rising: true,
                    },
                    TriggerStep {
                        channel: 1,
                        rising: true,
                    },
                ],
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let reversed = engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    assert_eq!(reversed.trigger_sample, Some(50));

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                realtime: false,
                trigger_enabled: true,
                trigger_steps: vec![
                    TriggerStep {
                        channel: 0,
                        rising: true,
                    },
                    TriggerStep {
                        channel: 0,
                        rising: false,
                    },
                ],
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let clock = engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    assert_eq!(clock.trigger_sample, Some(100));

    let refused = engine
        .configure(
            None,
            SessionConfig {
                trigger_steps: (0..17)
                    .map(|channel| TriggerStep {
                        channel,
                        rising: true,
                    })
                    .collect(),
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap_err();
    assert!(refused.to_string().contains("16"));
}

/// Checks that the enable mask controls stored streams while the complete probe catalog remains
/// available.
#[tokio::test]
async fn a_cleared_channel_is_left_out_of_the_demo_capture() {
    let engine = Engine::new();
    let before = engine.status(None).await.unwrap();
    assert_eq!(before.probes.len(), 4);
    assert_eq!(before.probes[1].name, "UART");
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 1,
                realtime: false,
                channel_enable: 0b1101,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let status = engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    let names: Vec<_> = status
        .channels
        .iter()
        .map(|channel| channel.name.as_str())
        .collect();
    assert_eq!(names, ["CLK", "SDA", "SCL"]);
    assert_eq!(status.probes[1].name, "UART");
    assert_eq!(status.channel_enable, 0b1101);
    assert_eq!(
        engine.search_edge(None, 0, 0, true, true).await.unwrap(),
        Some(50)
    );
}

/// Checks discovery ordering for the wider hardware profile.
#[tokio::test]
#[ignore = "needs the plugged-in high-speed DSLogic U3Pro32"]
async fn plugged_in_u3pro32_is_listed_before_demo_devices() {
    let engine = Engine::new();
    let devices = engine.list_devices().await;
    assert_eq!(
        devices.first().map(|device| device.id.as_str()),
        Some("usb:2a0e:002c")
    );
    assert!(devices.iter().any(|device| device.kind == "demo"));
    let info = engine.connect("usb:2a0e:002c").await.expect("connect");
    assert!(info.name.contains("U3Pro32"), "{}", info.name);
    let status = engine.status(None).await.unwrap();
    assert_eq!(status.channels.len(), 32);
    assert_eq!(status.channels[0].name, "D0");
    assert_eq!(status.channels[31].name, "D31");
    assert_eq!(status.devices[0].id, "usb:2a0e:002c");
}

/// Checks that configuration applies channel-count-dependent sampling ceilings.
#[tokio::test]
async fn sample_rate_drops_when_more_channels_are_enabled() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 400_000_000,
                duration_ms: 1,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(
        engine.status(None).await.unwrap().sample_rate_hz,
        400_000_000
    );
    engine.attach_device(None, "demo:spi").await.unwrap();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 400_000_000,
                duration_ms: 1,
                channel_enable: 0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let eight = engine.status(None).await.unwrap();
    assert_eq!(eight.probes.len(), 8);
    assert_eq!(eight.sample_rate_hz, 200_000_000);
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 400_000_000,
                duration_ms: 1,
                channel_enable: 0b0000_1111,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(
        engine.status(None).await.unwrap().sample_rate_hz,
        400_000_000
    );
    let profiles = engine.list_profiles().await;
    let plus = profiles
        .iter()
        .find(|profile| profile.product_id == 0x0020)
        .unwrap();
    let wide = profiles
        .iter()
        .find(|profile| profile.product_id == 0x002c)
        .unwrap();
    assert_eq!(plus.buffer_rates[0].max_hz, 400_000_000);
    assert_eq!(wide.buffer_rates.last().unwrap().max_channels, 32);
    assert_eq!(wide.stream_rates.last().unwrap().max_hz, 10_000_000);
    assert_eq!(wide.super_stream_rates.last().unwrap().max_hz, 50_000_000);
    assert_eq!(wide.super_stream_rates[0].max_hz, 1_000_000_000);
}

/// Checks that native and DSL imports restore an inactive session and its captured data.
#[tokio::test]
async fn imported_capture_bytes_replace_the_open_session() {
    let engine = Engine::new();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 1,
                realtime: false,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let original = engine
        .wait_until_settled("ses-1", Duration::from_secs(5))
        .await
        .unwrap();
    assert!(original.sample_count > 0);
    let edge = engine.search_edge(None, 0, 0, true, true).await.unwrap();
    let zip = engine.export_zip(None).await.unwrap();
    let dsl = engine.export_dsl(None).await.unwrap();

    let loaded_engine = Engine::new();
    let mut channels = std::collections::BTreeMap::new();
    channels.insert("scl".to_string(), "SCL".to_string());
    channels.insert("sda".to_string(), "SDA".to_string());
    loaded_engine
        .add_decoder(
            None,
            "i2c",
            &channels,
            &std::collections::BTreeMap::new(),
            None,
            None,
        )
        .await
        .unwrap();
    assert_eq!(loaded_engine.list_decoders(None).await.unwrap().len(), 1);
    let loaded = loaded_engine
        .import_capture(None, "capture.lvcap", &zip)
        .await
        .unwrap();
    assert_eq!(loaded.sample_count, original.sample_count);
    assert_eq!(loaded.sample_rate_hz, original.sample_rate_hz);
    assert_eq!(loaded.channels[0].name, "CLK");
    assert_eq!(loaded.devices[0].id, "file");
    assert!(loaded_engine.list_decoders(None).await.unwrap().is_empty());
    assert_eq!(
        loaded_engine
            .search_edge(None, 0, 0, true, true)
            .await
            .unwrap(),
        edge
    );

    let from_dsl = Engine::new();
    let loaded = from_dsl
        .import_capture(None, "capture.dsl", &dsl)
        .await
        .unwrap();
    assert_eq!(loaded.sample_count, original.sample_count);
    assert_eq!(loaded.channels[0].name, "CLK");
    assert_eq!(
        from_dsl.search_edge(None, 0, 0, true, true).await.unwrap(),
        edge
    );
}

/// Exercises the complete buffered capture pipeline on a connected Plus.
#[tokio::test]
#[ignore = "needs a connected DSLogic Plus"]
async fn plus_ten_ms_capture_pipeline() {
    let engine = Engine::new();
    engine.connect("usb:2a0e:0020").await.unwrap();
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 100_000_000,
                duration_ms: 10,
                channel_enable: 0x0f,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let started = std::time::Instant::now();
    engine.start(None, StartMode::Normal).await.unwrap();
    let status = engine
        .wait_until_settled("ses-1", Duration::from_secs(15))
        .await
        .unwrap();
    eprintln!(
        "engine capture: {:?}, {} samples, phase {}, error {:?}",
        started.elapsed(),
        status.sample_count,
        status.phase,
        status.error
    );
    assert_eq!(status.phase, "stopped");
    assert_eq!(status.sample_count, 1_000_000);
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 100_000_000,
                duration_ms: 50,
                channel_enable: 0x0f,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let long = engine
        .wait_until_settled("ses-1", Duration::from_secs(15))
        .await
        .unwrap();
    assert_eq!(long.phase, "stopped", "{:?}", long.error);
    assert_eq!(long.sample_count, 5_000_000);
}

/// Plus occupies the low 16 mask bits and the U3Pro32 the next 32 when the Plus is first.
#[test]
fn combined_mask_splits_plus_then_u3() {
    let mask = 1u64 | (1u64 << 16);
    assert_eq!(local_enable(0, 0, 16), 0xffff);
    assert_eq!(local_enable(0, 16, 32), u32::MAX);
    assert_eq!(local_enable(mask, 0, 16), 1);
    assert_eq!(local_enable(mask, 16, 32), 1);
    assert_eq!(local_enable(1, 16, 32), 0);
}

fn bound_usb(id: &str, name: &str) -> BoundDevice {
    BoundDevice {
        id: id.into(),
        name: name.into(),
        kind: "usb".into(),
        super_speed: false,
    }
}

/// Two USB pods share one catalog. Stream, trigger, loop, and a repeated product id are refused
/// before any device is opened.
#[tokio::test]
async fn combined_usb_catalog_rates_and_refusals() {
    let engine = Engine::new();
    {
        let mut state = engine.shared.state.lock().await;
        let slot = state
            .slots
            .iter_mut()
            .find(|slot| slot.id == "ses-1")
            .unwrap();
        install_usb_catalog(
            slot,
            &[
                bound_usb("usb:2a0e:0020", "DSLogic Plus"),
                bound_usb("usb:2a0e:002c", "DSLogic U3Pro32"),
            ],
        )
        .unwrap();
    }
    let status = engine.status(None).await.unwrap();
    assert_eq!(status.probes.len(), 48);
    assert_eq!(status.probes[0].name, "Plus D0");
    assert_eq!(status.probes[0].device_id, "usb:2a0e:0020");
    assert_eq!(status.probes[15].name, "Plus D15");
    assert_eq!(status.probes[16].name, "U3 D0");
    assert_eq!(status.probes[16].device_id, "usb:2a0e:002c");
    assert_eq!(status.probes[47].name, "U3 D31");
    assert_eq!(status.devices.len(), 2);

    let same = engine
        .attach_device(None, "usb:2a0e:0020")
        .await
        .unwrap_err();
    assert!(same.to_string().contains("same product"), "{same}");

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 400_000_000,
                duration_ms: 10,
                channel_enable: 0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(
        engine.status(None).await.unwrap().sample_rate_hz,
        100_000_000
    );

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000_000,
                duration_ms: 10,
                channel_enable: 1u64 | (1u64 << 16),
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    assert_eq!(
        engine.status(None).await.unwrap().sample_rate_hz,
        400_000_000
    );

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                depth: DepthMode::Stream,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let stream = engine.start(None, StartMode::Normal).await.unwrap_err();
    assert!(stream.to_string().contains("single buffer"), "{stream}");

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                trigger_enabled: true,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let trigger = engine.start(None, StartMode::Normal).await.unwrap_err();
    assert!(
        trigger.to_string().contains("hardware trigger"),
        "{trigger}"
    );

    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                run: RunPolicy::Loop,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let looping = engine.start(None, StartMode::Normal).await.unwrap_err();
    assert!(looping.to_string().contains("single buffer"), "{looping}");
}

/// Buffer-captures every probe on the connected Plus and U3Pro32 in one session.
#[tokio::test]
#[ignore = "needs the connected DSLogic Plus and DSLogic U3Pro32"]
async fn plus_and_u3_ten_ms_combined_buffer() {
    let _pods = logicview_hal::acquire_test_pod_lock();
    let engine = Engine::new();
    engine.connect("usb:2a0e:0020").await.unwrap();
    engine.attach_device(None, "usb:2a0e:002c").await.unwrap();
    let attached = engine.status(None).await.unwrap();
    assert_eq!(attached.probes.len(), 48);
    assert!(attached
        .devices
        .iter()
        .any(|device| device.id == "usb:2a0e:0020"));
    assert!(attached
        .devices
        .iter()
        .any(|device| device.id == "usb:2a0e:002c"));
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 10,
                channel_enable: 0,
                trigger_enabled: false,
                depth: DepthMode::Buffer,
                run: RunPolicy::Single,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    engine.start(None, StartMode::Normal).await.unwrap();
    let status = engine
        .wait_until_settled("ses-1", Duration::from_secs(30))
        .await
        .unwrap();
    assert_eq!(status.phase, "stopped", "{:?}", status.error);
    assert!(status.error.is_none());
    assert!(
        status.sample_count > 0,
        "sample_count {}",
        status.sample_count
    );
    assert_eq!(status.channels.len(), 48);
    assert_eq!(status.channels[0].device_id, "usb:2a0e:0020");
    assert_eq!(status.channels[16].device_id, "usb:2a0e:002c");
    let plus = engine.tile(None, 0, 0.0, 8, 64.0).await.unwrap();
    let u3 = engine.tile(None, 16, 0.0, 8, 64.0).await.unwrap();
    assert!(
        plus.iter().any(|column| column.valid),
        "Plus channel had no samples"
    );
    assert!(
        u3.iter().any(|column| column.valid),
        "U3 channel had no samples"
    );
    eprintln!(
        "combined buffer: {} samples, plus {}, u3 {}",
        status.sample_count, status.channels[0].name, status.channels[16].name
    );
}

/// Demo and stream stay at the host sample cap. A buffered pod can use its memory,
/// split across the channels enabled on that pod.
#[tokio::test]
async fn buffer_length_stops_at_the_pod_memory_share() {
    let engine = Engine::new();
    let demo = engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 20_000,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap_err();
    match demo {
        EngineError::Capture(CaptureError::TooLarge { ceiling, .. }) => {
            assert_eq!(ceiling, logicview_capture::MAX_SAMPLES);
        }
        other => panic!("demo buffer should stop at the host cap, got {other}"),
    }

    {
        let mut state = engine.shared.state.lock().await;
        let slot = state
            .slots
            .iter_mut()
            .find(|slot| slot.id == "ses-1")
            .unwrap();
        install_usb_catalog(slot, &[bound_usb("usb:2a0e:0020", "DSLogic Plus")]).unwrap();
    }
    engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 20_000,
                channel_enable: 1,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap();
    let wide = engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 20_000,
                channel_enable: 0,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap_err();
    match wide {
        EngineError::Capture(CaptureError::TooLarge { ceiling, .. }) => {
            assert_eq!(ceiling, logicview_hal::MEMORY_BITS / 16);
        }
        other => panic!("16 channels should split the pod memory, got {other}"),
    }

    {
        let mut state = engine.shared.state.lock().await;
        let slot = state
            .slots
            .iter_mut()
            .find(|slot| slot.id == "ses-1")
            .unwrap();
        install_usb_catalog(
            slot,
            &[
                bound_usb("usb:2a0e:0020", "DSLogic Plus"),
                bound_usb("usb:2a0e:002c", "DSLogic U3Pro32"),
            ],
        )
        .unwrap();
    }
    let stacked = engine
        .configure(
            None,
            SessionConfig {
                sample_rate_hz: 1_000_000,
                duration_ms: 9_000,
                channel_enable: 0,
                depth: DepthMode::Buffer,
                run: RunPolicy::Single,
                trigger_enabled: false,
                ..SessionConfig::default()
            },
        )
        .await
        .unwrap_err();
    match stacked {
        EngineError::Capture(CaptureError::TooLarge { ceiling, .. }) => {
            assert_eq!(ceiling, logicview_hal::MEMORY_BITS / 32);
        }
        other => panic!("two pods should use the smaller memory share, got {other}"),
    }
}

/// Checks that a capture tab name is trimmed, stored, and refused when blank or unknown.
#[tokio::test]
async fn rename_session_trims_and_rejects_blank() {
    let engine = Engine::new();
    let renamed = engine.rename_session("ses-1", "  Logic  ").await.unwrap();
    assert_eq!(renamed.name, "Logic");
    assert!(renamed.active);
    let (sessions, _) = engine.list_sessions().await;
    assert_eq!(sessions[0].name, "Logic");
    assert!(engine.rename_session("ses-1", "   ").await.is_err());
    match engine.rename_session("missing", "Name").await {
        Err(EngineError::UnknownSession(id)) => assert_eq!(id, "missing"),
        other => panic!("unknown session should fail, got {other:?}"),
    }
    let (sessions, _) = engine.list_sessions().await;
    assert_eq!(sessions[0].name, "Logic");
}

/// Closing sessions preserves the selected capture and replaces the final session.
#[tokio::test]
async fn close_session_preserves_workspace_selection() {
    let engine = Engine::new();
    engine.create_session(None).await.unwrap();
    engine.create_session(None).await.unwrap();
    assert_eq!(engine.close_session("ses-1").await.unwrap(), "ses-3");
    assert_eq!(engine.close_session("ses-3").await.unwrap(), "ses-2");
    assert!(engine.close_session("ses-3").await.is_err());
    let replacement = engine.close_session("ses-2").await.unwrap();
    assert_eq!(replacement, "ses-4");
    let (sessions, active) = engine.list_sessions().await;
    assert_eq!(sessions.len(), 1);
    assert_eq!(active, replacement);
}

/// New sessions inherit the active pod catalog without inheriting captured data.
#[tokio::test]
async fn new_session_inherits_active_pods() {
    let engine = Engine::new();
    engine.connect("demo:spi").await.unwrap();
    engine.attach_device(None, "demo").await.unwrap();
    let created = engine.create_session(None).await.unwrap();
    let status = engine.status(Some(&created.id)).await.unwrap();
    assert_eq!(status.devices.iter().map(|device| device.id.as_str()).collect::<Vec<_>>(), vec!["demo:spi", "demo"]);
    assert_eq!(status.sample_count, 0);
    {
        let mut state = engine.shared.state.lock().await;
        let active = state.active;
        install_usb_catalog(&mut state.slots[active], &[bound_usb("usb:2a0e:0020", "DSLogic Plus"), bound_usb("usb:2a0e:002c", "DSLogic U3Pro32")]).unwrap();
    }
    let created = engine.create_session(None).await.unwrap();
    let status = engine.status(Some(&created.id)).await.unwrap();
    assert_eq!(status.devices.iter().map(|device| device.id.as_str()).collect::<Vec<_>>(), vec!["usb:2a0e:0020", "usb:2a0e:002c"]);
    assert_eq!(status.probes.len(), 48);
    assert_eq!(status.sample_count, 0);
}

#[tokio::test]
async fn new_session_from_file_uses_previous_pods() {
    let engine = Engine::new();
    engine.connect("demo:spi").await.unwrap();
    {
        let mut state = engine.shared.state.lock().await;
        let slot = &mut state.slots[0];
        slot.capture_devices_before_file = slot.devices.clone();
        slot.devices = vec![BoundDevice { id: "file".into(), name: "File".into(), kind: "file".into(), super_speed: false }];
    }
    let created = engine.create_session(None).await.unwrap();
    let status = engine.status(Some(&created.id)).await.unwrap();
    assert_eq!(status.devices[0].id, "demo:spi");
}

#[test]
fn usb_trigger_wait_has_no_deadline_but_instant_and_untriggered_are_bounded() {
    let mut config = SessionConfig::default();
    config.trigger_enabled = true;
    assert_eq!(crate::usb_header_wait(&config, StartMode::Normal, 1_000_000), None);
    assert!(crate::usb_header_wait(&config, StartMode::Instant, 1_000_000).is_some());
    config.trigger_enabled = false;
    assert!(crate::usb_header_wait(&config, StartMode::Normal, 1_000_000).is_some());
    config.depth = DepthMode::Stream;
    config.trigger_enabled = true;
    assert_eq!(crate::usb_header_wait(&config, StartMode::Normal, 1_000_000), None);
}
