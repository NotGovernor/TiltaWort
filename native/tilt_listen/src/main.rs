//! Listen-only BLE advertisement sidecar.
//! Empty ScanFilter. Manufacturer 0x004C only. No connect, no GATT, no Coded PHY.

use btleplug::api::{Central, CentralEvent, CentralState, Manager as _, Peripheral as _, ScanFilter};
use btleplug::platform::Manager;
use futures::StreamExt;
use std::collections::HashMap;
use std::io::{self, Write};
use std::time::Duration;

const APPLE: u16 = 0x004C;

fn emit(value: serde_json::Value) {
    let mut out = io::stdout();
    writeln!(out, "{value}").ok();
    out.flush().ok();
}

fn parse_seconds(args: &[String]) -> Option<u64> {
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--seconds" {
            return args.get(i + 1).and_then(|s| s.parse().ok());
        }
        i += 1;
    }
    None
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let seconds = parse_seconds(&args);

    let manager = Manager::new().await?;
    let adapters = manager.adapters().await?;
    let adapter = adapters.into_iter().next().ok_or("no BLE adapter")?;
    let state = adapter.adapter_state().await?;
    let on = matches!(state, CentralState::PoweredOn);
    let state_s = match &state {
        CentralState::PoweredOn => "PoweredOn",
        CentralState::PoweredOff => "PoweredOff",
        other => {
            eprintln!("adapter-up: {other:?}");
            "Unknown"
        }
    };
    eprintln!("adapter-up: WinRT state={state_s}");
    emit(serde_json::json!({"type":"adapter","state":state_s}));
    if !on {
        eprintln!("radio Off — turn Bluetooth on in Windows Settings");
        return Ok(());
    }

    // Subscribe before start_scan so WinRT ads are not dropped.
    let mut events = adapter.events().await?;
    adapter.start_scan(ScanFilter::default()).await?;
    eprintln!(
        "scanning {} (empty ScanFilter, 0x004C only, no Coded PHY, no GATT)",
        seconds.map(|s| format!("{s}s")).unwrap_or_else(|| "until stop".into())
    );

    let mut rssi: HashMap<String, i16> = HashMap::new();
    let mut stats = Stats::default();
    let deadline = seconds.map(|s| tokio::time::Instant::now() + Duration::from_secs(s));
    let mut ticker = tokio::time::interval(Duration::from_secs(1));

    loop {
        let timed_out = deadline
            .map(|d| tokio::time::Instant::now() >= d)
            .unwrap_or(false);
        if timed_out {
            break;
        }
        tokio::select! {
            maybe = events.next() => {
                match maybe {
                    Some(ev) => handle(&adapter, ev, &mut rssi, &mut stats).await,
                    None => break,
                }
            }
            _ = ticker.tick() => {
                poll_properties(&adapter, &mut rssi, &mut stats).await;
            }
        }
    }

    let _ = adapter.stop_scan().await;
    eprintln!(
        "scan done; manufacturer ads (any company)={}; apple 0x004C events={}; peripherals polled={}",
        stats.mfg_any, stats.apple, stats.polls
    );
    Ok(())
}

#[derive(Default)]
struct Stats {
    mfg_any: u64,
    apple: u64,
    polls: u64,
}

async fn handle(
    adapter: &btleplug::platform::Adapter,
    ev: CentralEvent,
    rssi: &mut HashMap<String, i16>,
    stats: &mut Stats,
) {
    match ev {
        CentralEvent::StateUpdate(CentralState::PoweredOff) => {
            emit(serde_json::json!({"type":"adapter","state":"PoweredOff"}));
        }
        CentralEvent::StateUpdate(CentralState::PoweredOn) => {
            emit(serde_json::json!({"type":"adapter","state":"PoweredOn"}));
        }
        CentralEvent::RssiUpdate { id, rssi: r } => {
            rssi.insert(id.to_string(), r);
        }
        CentralEvent::ManufacturerDataAdvertisement { id, manufacturer_data } => {
            stats.mfg_any += 1;
            if let Some(payload) = manufacturer_data.get(&APPLE) {
                stats.apple += 1;
                let mut addr = id.to_string();
                let mut r = rssi.get(&addr).copied();
                if let Ok(p) = adapter.peripheral(&id).await {
                    if let Ok(Some(props)) = p.properties().await {
                        addr = props.address.to_string();
                        if let Some(rr) = props.rssi {
                            r = Some(rr);
                            rssi.insert(id.to_string(), rr);
                        }
                    }
                }
                emit_ad(payload, r, &addr);
            }
        }
        CentralEvent::DeviceUpdated(id) | CentralEvent::DeviceDiscovered(id) => {
            let Ok(p) = adapter.peripheral(&id).await else { return };
            let Ok(Some(props)) = p.properties().await else { return };
            if let Some(r) = props.rssi {
                rssi.insert(id.to_string(), r);
            }
            if !props.manufacturer_data.is_empty() {
                stats.mfg_any += 1;
            }
            if let Some(payload) = props.manufacturer_data.get(&APPLE) {
                stats.apple += 1;
                let r = props.rssi.or_else(|| rssi.get(&id.to_string()).copied());
                let addr = props.address.to_string();
                emit_ad(payload, r, &addr);
            }
        }
        // Never connect. Ignore DeviceConnected if the OS emits it.
        _ => {}
    }
}

async fn poll_properties(
    adapter: &btleplug::platform::Adapter,
    rssi: &mut HashMap<String, i16>,
    stats: &mut Stats,
) {
    stats.polls += 1;
    let Ok(peripherals) = adapter.peripherals().await else { return };
    for p in peripherals {
        let Ok(Some(props)) = p.properties().await else { continue };
        if let Some(r) = props.rssi {
            rssi.insert(p.id().to_string(), r);
        }
        if let Some(payload) = props.manufacturer_data.get(&APPLE) {
            stats.apple += 1;
            let r = props.rssi.or_else(|| rssi.get(&p.id().to_string()).copied());
            emit_ad(payload, r, &props.address.to_string());
        }
    }
}

fn emit_ad(payload: &[u8], rssi: Option<i16>, address: &str) {
    emit(serde_json::json!({
        "type": "ad",
        "companyId": APPLE,
        "payload": payload,
        "rssi": rssi,
        "address": address,
    }));
}
