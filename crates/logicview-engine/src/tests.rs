use std::time::Duration;

use logicview_capture::{SessionConfig, TriggerStep};
use logicview_proto::{decode_arm, ModeFlags};

use super::{hardware_before_demo, DeviceInfo, Engine, StartMode};

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

#[test]
fn plugged_in_pods_are_listed_before_demo_devices() {
    let ordered = hardware_before_demo(vec![
        DeviceInfo {
            id: "demo".into(),
            name: "Demo".into(),
            kind: "demo".into(),
            connected: true,
        },
        DeviceInfo {
            id: "usb:2a0e:0020".into(),
            name: "DSLogic Plus".into(),
            kind: "usb".into(),
            connected: true,
        },
        DeviceInfo {
            id: "demo:spi".into(),
            name: "Demo SPI".into(),
            kind: "demo".into(),
            connected: true,
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
        .any(|profile| profile.product_id == 0x0034 && !profile.hardware_tested));
}

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

    let rows = engine
        .read_annotations(None, None, None, None, None, 0, 5_000)
        .await
        .unwrap();
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
    assert_eq!(engine.status(None).await.unwrap().sample_rate_hz, 400_000_000);
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
    assert_eq!(engine.status(None).await.unwrap().sample_rate_hz, 400_000_000);
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
    assert_eq!(wide.stream_rates.last().unwrap().max_hz, 50_000_000);
}
