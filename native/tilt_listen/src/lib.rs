//! Listen-only BLE advertisement library.
//! Empty ScanFilter. Manufacturer 0x004C only. No connect, no GATT, no Coded PHY.
//!
//! C ABI: `tilt_listen_start` / `tilt_listen_stop`. JSON lines match the CLI sidecar.

use btleplug::api::{Central, CentralEvent, CentralState, Manager as _, Peripheral as _, ScanFilter};
use btleplug::platform::Manager;
use futures::StreamExt;
use std::collections::HashMap;
use std::ffi::{c_char, c_void, CString};
use std::io::{self, Write};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread::{self, JoinHandle};
use std::time::Duration;
use tokio::sync::watch;

const APPLE: u16 = 0x004C;
const LINE_CAP: usize = 256;

type ListenCb = extern "C" fn(*const c_char, *mut c_void);

#[derive(Clone, Copy)]
struct UserPtr(*mut c_void);
unsafe impl Send for UserPtr {}

struct LineKeep {
    slots: Vec<CString>,
    next: usize,
}

impl LineKeep {
    fn intern(&mut self, c: CString) -> *const c_char {
        let ptr = c.as_ptr();
        if self.slots.len() < LINE_CAP {
            self.slots.push(c);
        } else {
            self.slots[self.next] = c;
            self.next = (self.next + 1) % LINE_CAP;
        }
        ptr
    }
}

fn line_keep() -> &'static Mutex<LineKeep> {
    static KEEP: OnceLock<Mutex<LineKeep>> = OnceLock::new();
    KEEP.get_or_init(|| Mutex::new(LineKeep { slots: Vec::new(), next: 0 }))
}

struct Session {
    stop: watch::Sender<bool>,
    join: Option<JoinHandle<()>>,
}

static SESSION: Mutex<Option<Session>> = Mutex::new(None);

#[derive(Clone)]
struct Emitter {
    inner: Arc<dyn Fn(serde_json::Value) + Send + Sync>,
}

impl Emitter {
    fn stdout() -> Self {
        Self {
            inner: Arc::new(|value| {
                let mut out = io::stdout();
                writeln!(out, "{value}").ok();
                out.flush().ok();
            }),
        }
    }

    fn callback(cb: ListenCb, user: UserPtr) -> Self {
        let user_bits = user.0 as usize;
        Self {
            inner: Arc::new(move |value| {
                let Ok(c) = CString::new(value.to_string()) else { return };
                let ptr = {
                    let mut keep = line_keep().lock().unwrap_or_else(|e| e.into_inner());
                    keep.intern(c)
                };
                cb(ptr, user_bits as *mut c_void);
            }),
        }
    }

    fn emit(&self, value: serde_json::Value) {
        (self.inner)(value);
    }
}

pub fn parse_seconds(args: &[String]) -> Option<u64> {
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--seconds" {
            return args.get(i + 1).and_then(|s| s.parse().ok());
        }
        i += 1;
    }
    None
}

/// CLI entry: same JSON on stdout, stderr logs, error if no adapter.
pub async fn run_listen_stdout(seconds: Option<u64>) -> Result<(), Box<dyn std::error::Error>> {
    let (_tx, rx) = watch::channel(false);
    run_scan(Emitter::stdout(), seconds, rx, true).await.map_err(Into::into)
}

async fn run_scan(
    emit: Emitter,
    seconds: Option<u64>,
    mut stop: watch::Receiver<bool>,
    verbose: bool,
) -> Result<(), String> {
    let manager = Manager::new().await.map_err(|e| e.to_string())?;
    let adapters = manager.adapters().await.map_err(|e| e.to_string())?;
    let adapter = adapters.into_iter().next().ok_or_else(|| "no BLE adapter".to_string())?;
    let state = adapter.adapter_state().await.map_err(|e| e.to_string())?;
    let on = matches!(state, CentralState::PoweredOn);
    let state_s = match &state {
        CentralState::PoweredOn => "PoweredOn",
        CentralState::PoweredOff => "PoweredOff",
        other => {
            if verbose {
                eprintln!("adapter-up: {other:?}");
            }
            "Unknown"
        }
    };
    if verbose {
        eprintln!("adapter-up: WinRT state={state_s}");
    }
    emit.emit(serde_json::json!({"type":"adapter","state":state_s}));
    if !on {
        if verbose {
            eprintln!("radio Off — turn Bluetooth on in Windows Settings");
        }
        return Ok(());
    }

    // Subscribe before start_scan so WinRT ads are not dropped.
    let mut events = adapter.events().await.map_err(|e| e.to_string())?;
    adapter
        .start_scan(ScanFilter::default())
        .await
        .map_err(|e| e.to_string())?;
    if verbose {
        eprintln!(
            "scanning {} (empty ScanFilter, 0x004C only, no Coded PHY, no GATT)",
            seconds
                .map(|s| format!("{s}s"))
                .unwrap_or_else(|| "until stop".into())
        );
    }

    let mut rssi: HashMap<String, i16> = HashMap::new();
    let mut stats = Stats::default();
    let deadline = seconds.map(|s| tokio::time::Instant::now() + Duration::from_secs(s));
    let mut ticker = tokio::time::interval(Duration::from_secs(1));

    loop {
        if *stop.borrow() {
            break;
        }
        let timed_out = deadline
            .map(|d| tokio::time::Instant::now() >= d)
            .unwrap_or(false);
        if timed_out {
            break;
        }
        tokio::select! {
            maybe = events.next() => {
                match maybe {
                    Some(ev) => handle(&adapter, ev, &mut rssi, &mut stats, &emit).await,
                    None => break,
                }
            }
            _ = ticker.tick() => {
                poll_properties(&adapter, &mut rssi, &mut stats, &emit).await;
            }
            _ = stop.changed() => {
                if *stop.borrow() {
                    break;
                }
            }
        }
    }

    let _ = adapter.stop_scan().await;
    if verbose {
        eprintln!(
            "scan done; manufacturer ads (any company)={}; apple 0x004C events={}; peripherals polled={}",
            stats.mfg_any, stats.apple, stats.polls
        );
    }
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
    emit: &Emitter,
) {
    match ev {
        CentralEvent::StateUpdate(CentralState::PoweredOff) => {
            emit.emit(serde_json::json!({"type":"adapter","state":"PoweredOff"}));
        }
        CentralEvent::StateUpdate(CentralState::PoweredOn) => {
            emit.emit(serde_json::json!({"type":"adapter","state":"PoweredOn"}));
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
                emit.emit(ad_value(payload, r, &addr));
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
                emit.emit(ad_value(payload, r, &addr));
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
    emit: &Emitter,
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
            emit.emit(ad_value(payload, r, &props.address.to_string()));
        }
    }
}

fn ad_value(payload: &[u8], rssi: Option<i16>, address: &str) -> serde_json::Value {
    serde_json::json!({
        "type": "ad",
        "companyId": APPLE,
        "payload": payload,
        "rssi": rssi,
        "address": address,
    })
}

fn take_join() -> Option<JoinHandle<()>> {
    let mut g = SESSION.lock().unwrap_or_else(|e| e.into_inner());
    if let Some(s) = g.as_mut() {
        let _ = s.stop.send(true);
        s.join.take()
    } else {
        None
    }
}

/// Start empty-filter listen. `cb` receives one UTF-8 JSON line per adapter/ad event.
/// The pointer is valid until 256 later lines (Dart `NativeCallable.listener` must copy immediately).
#[no_mangle]
pub extern "C" fn tilt_listen_start(
    cb: Option<ListenCb>,
    user: *mut c_void,
) -> i32 {
    let Some(cb) = cb else { return -1 };
    tilt_listen_stop();
    let (stop_tx, stop_rx) = watch::channel(false);
    let user = UserPtr(user);
    let spawn = thread::Builder::new().name("tilt_listen".into()).spawn(move || {
        let rt = match tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
        {
            Ok(rt) => rt,
            Err(_) => {
                Emitter::callback(cb, user)
                    .emit(serde_json::json!({"type":"adapter","state":"PoweredOff"}));
                return;
            }
        };
        let emit = Emitter::callback(cb, user);
        rt.block_on(async move {
            if let Err(_) = run_scan(emit.clone(), None, stop_rx, false).await {
                emit.emit(serde_json::json!({"type":"adapter","state":"PoweredOff"}));
            }
        });
    });
    match spawn {
        Ok(join) => {
            let mut g = SESSION.lock().unwrap_or_else(|e| e.into_inner());
            *g = Some(Session {
                stop: stop_tx,
                join: Some(join),
            });
            0
        }
        Err(_) => -2,
    }
}

#[no_mangle]
pub extern "C" fn tilt_listen_stop() {
    if let Some(join) = take_join() {
        let _ = join.join();
    }
    let mut g = SESSION.lock().unwrap_or_else(|e| e.into_inner());
    *g = None;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ad_json_is_type_ad_company_apple() {
        let v = ad_value(&[2, 21], Some(-90), "AA:BB");
        assert_eq!(v["type"], "ad");
        assert_eq!(v["companyId"], APPLE);
        assert_eq!(v["rssi"], -90);
        assert_eq!(v["address"], "AA:BB");
    }

    #[test]
    fn parse_seconds_reads_flag() {
        let args = ["--seconds".into(), "30".into()];
        assert_eq!(parse_seconds(&args), Some(30));
        assert_eq!(parse_seconds(&[]), None);
    }

    #[test]
    fn start_null_callback_is_minus_one() {
        assert_eq!(tilt_listen_start(None, std::ptr::null_mut()), -1);
    }
}
