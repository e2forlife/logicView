use std::time::Duration;

use logicview_capture::SessionConfig;
use logicview_proto::{decode_arm, ModeFlags};

use super::{Engine, StartMode};

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

    let rising = engine.search_edge(None, 0, 0, true).await.unwrap();
    assert_eq!(rising, Some(50));
    let falling = engine.search_edge(None, 0, 0, false).await.unwrap();
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
        reloaded.search_edge(None, 0, 0, true).await.unwrap(),
        rising
    );
    assert_eq!(
        reloaded.search_edge(None, 0, 50, true).await.unwrap(),
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
    assert!(!armed.mode.contains(ModeFlags::INSTANT));
    assert_eq!(armed.stages[0].mask, 1);
    assert_eq!(armed.stages[0].edge, 1);
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

#[tokio::test]
async fn usb_connect_is_refused() {
    let engine = Engine::new();
    let error = engine.connect("usb:2a0e:0034").await.unwrap_err();
    assert!(error.to_string().contains("demo"));
}
