//! Listen-only BLE advertisement sidecar CLI.
//! Empty ScanFilter. Manufacturer 0x004C only. No connect, no GATT, no Coded PHY.

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let seconds = tilt_listen::parse_seconds(&args);
    tilt_listen::run_listen_stdout(seconds).await
}
