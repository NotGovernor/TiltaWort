# Tilt-a-Wort

Desktop app for Tilt hydrometers. Goal: do a better job than the first-party Tilt phone app.

This file is the protocol memory for a clean-slate rebuild (10-24-2026). The first POC was deleted on purpose. Do not reconnect GATT. Do not treat the float as a writable device.

## How a Tilt actually works

A Tilt (original, Pro, Pro Mini) is a **one-way BLE iBeacon**. It floats in the fermenter and **broadcasts** specific gravity and temperature about every **5 seconds**. It has **no Wi-Fi, no cellular, no pairing, and no settings you can change over Bluetooth**.

The official Tilt 2 / Tilt 3 app only **listens** to those beacons (`cordova-plugin-ibeacon`). Names, °F/°C, Plato vs SG, calibration points, log interval, and cloud URLs live in **phone storage** (`NativeStorage` / `localStorage`), keyed by color. Cloud logging is the **phone or Tilt Pi/Pico** POSTing Google Sheets / Brewfather — the hydrometer never joins a network.

If Tilt-a-Wort wants those knobs, store them **locally on this PC**, keyed by color UUID, and apply them on display. Never claim the float accepted a write.

### Sleep / wake (hardware, not BLE)

- Stand vertical or lay on its side → sleep (blue LED).
- Float in roughly 0.990–1.200 SG → wake (green/red LED related to battery).
- After a battery change: purple LED means **device-level tare** — float in still room-temp water so firmware aims broadcast SG at 1.000. That is physical, not an app command. Do not offer it as a BLE feature.

### Color is the UUID (factory)

Same eight UUIDs for Tilt, Tilt Pro, and Tilt Pro Mini. Color is not a separate field.

| Color  | UUID                                   |
|--------|----------------------------------------|
| Red    | `A495BB10-C5B1-4B44-B512-1370F02D74DE` |
| Green  | `A495BB20-C5B1-4B44-B512-1370F02D74DE` |
| Black  | `A495BB30-C5B1-4B44-B512-1370F02D74DE` |
| Purple | `A495BB40-C5B1-4B44-B512-1370F02D74DE` |
| Orange | `A495BB50-C5B1-4B44-B512-1370F02D74DE` |
| Blue   | `A495BB60-C5B1-4B44-B512-1370F02D74DE` |
| Yellow | `A495BB70-C5B1-4B44-B512-1370F02D74DE` |
| Pink   | `A495BB80-C5B1-4B44-B512-1370F02D74DE` |

Do **not** copy `baronbrew/tilt-scan` JS — it maps Yellow’s UUID to Pink and omits Yellow.

## Advertisement layout (this is the protocol)

Apple iBeacon inside BLE Manufacturer Specific Data. Company id **`0x004C`**.

WinRT / typical host APIs give a map keyed by `0x004C`. The value usually **omits** `4C 00` and starts at `02 15`:

```
02 15
[16-byte UUID]
major u16 big-endian
minor u16 big-endian
tx     i8  (iBeacon measured power — do not show as battery %)
```

RSSI is **not** in that blob; it comes from the scan event.

### Decode

1. Ignore ads with no manufacturer key `0x004C`.
2. Strip optional `4C 00` prefix. Require `02 15` then ≥21 more bytes.
3. UUID = next 16 bytes. Unknown UUID → not a Tilt, drop.
4. `major` / `minor` = big-endian u16.
5. **Standard Tilt:** `temp_f = major` (1 °F steps), `sg = minor / 1000` (0.001 SG).
6. **Tilt Pro / Pro Mini:** vendor resolution is 0.1 °F and 0.0001 SG. Community heuristic (use it): if `minor > 5000` then `temp_f = major / 10`, `sg = minor / 10000`. Same UUID table. Standard minors sit ~990–1200; Pro minors ~9900–11200.
7. `°C = (°F − 32) × 5/9`.
8. Do **not** filter the scanner by these UUIDs as GATT **service** UUIDs — they are iBeacon proximity UUIDs. An empty scan filter is correct.
9. Do **not** enable Bluetooth Coded PHY on Windows (drops 1M ads on Intel radios).

### Test vector (documented live dump — Red, standard Tilt)

Company `0x004C`, payload:

```
02 15 A4 95 BB 10 C5 B1 4B 44 B5 12 13 70 F0 2D 74 DE 00 44 03 F8 C5
```

Expect: Red, 68.0 °F / 20.0 °C, SG 1.016, not Pro.

Trap: some blog tables swap major/minor. Trust kvurd’s dump, not those tables.

Battery millivolts are **not** in the iBeacon body. Official battery check is an LED blink.

## Live proof on this PC (10-24-2026)

Workstation: Windows, `Intel(R) Wireless Bluetooth(R)`. Radio can be PnP-OK but **software Off** — turn Bluetooth on in Settings (WinRT `PoweredOn`) before scanning.

Patrick’s Pink **Tilt Pro** (cup of water, in this room):

| Field | Value |
|-------|--------|
| Color | Pink |
| Kind  | Pro (`minor` scaled) |
| UUID  | `A495BB80-C5B1-4B44-B512-1370F02D74DE` |
| BLE address seen | `EC:95:FA:E0:74:DE` (random) |
| In water | SG **1.0000–1.0003**, temp **~72–74 °F** |
| RSSI in-room | about **−94 to −103 dBm** (weak; fermenter across the house was **zero Tilts** even for 5 minutes) |

Read path works. **Connect path does not:** Windows `Device not found` while scanning and after stopping the scan. No GATT services, no write. Official app source has zero GATT. Do not retry connect as a product feature — it can stall the 5 s beacon.

Range: this desktop is a poor radio for a Tilt in another room. Plan the UI for missed packets and long listens, not a 2-second snapshot.

## Windows notes for the next app

- Unpackaged Win32/console can watch advertisements. No Store `bluetooth` capability required.
- 64-bit process. Radio must be On. PC does **not** need to be discoverable. No admin. No pairing.
- First POC crate that worked here: **btleplug 0.13.5**, empty `ScanFilter`, no Coded PHY. Not a mandate if a better host API is chosen — the **layout above** is the mandate.
- Listen both for manufacturer-data events **and** device properties; Windows sometimes delivers the payload on only one path.
- Empty scan is an honest result. Never invent SG/temp.

## Product implications (better than the first-party app)

The first-party app is a phone beacon ranger plus a local settings database plus optional cloud POST. Beating it means, at least:

- Reliable Windows scan (radio-off detected, long listen, multi-Tilt).
- History, charts, and logging **on this machine** without leaving a phone in the brewery.
- App-side names / units / calibration **clearly labeled as ours**, not “written to the Tilt.”
- Honest range: RSSI and last-seen, not a fake live needle when ads stop.

Do **not:** GATT, pairing, firmware, device tare from software, or claiming battery % from the TX-power byte.

## Sources

- https://kvurd.com/blog/tilt-hydrometer-ibeacon-data-format
- https://tilthydrometer.com/pages/faqs
- https://tilthydrometer.com/pages/guide
- https://tilthydrometer.com/products/tilt-pro-wireless-hydrometer-and-thermometer
- https://github.com/baronbrew/Tilt-Hydrometer-Framework7 (official Tilt 3 Cordova app)
- https://github.com/baronbrew/TiltScan-Bleak
- https://github.com/baronbrew/TiltPico
- https://learn.microsoft.com/en-us/windows/apps/develop/devices-sensors/ble-beacon

Foundry spike reports (detail, not required to build): `M:\AIHome\Foundry Team\jobs\t_4378e813\foundry-lab.md`, `jobs\t_bbdd227d\foundry-lab.md`.
