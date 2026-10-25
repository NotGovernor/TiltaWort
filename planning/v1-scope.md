# Tilt-a-Wort V1 scope

Date: 10-24-2026. Planning only. No app code. No DESIGN.md. No BLE writes.

Inventory: `planning/tilt-app-features.md` (Prospector `t_9ae27368`, Tilt 2 Android 1.1.17, **65** F-rows). Protocol memory: `README.md`.

**Recommended default:** ship the **V1 cut** as written. Do not add Sheets / Brewfather / Pico / GATT to V1.

V1 is **this Windows PC** (Patrick’s desk, Pink Tilt Pro in-room). Not an Android clone. Not Tilt Pi. If a Tilt 2 feature only makes sense on a phone left in the brewery, it is Exclude or an on-PC Improve.

Hard excludes (already decided — not relitigated): GATT / pairing / firmware / software device-tare; battery % from TX-power; claiming a setting was written to the float.

Verdicts: exactly one of **Include** / **Exclude** / **Improve** per F-row. Improve names the smallest on-PC substitute.

Counts: **Include 13 · Improve 22 · Exclude 30** (65/65).

---

## 1. Live readings

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F01 | Live Tilt card | **Include** | Core job: live beer name, color, calibrated SG + temp for each heard Tilt. Desktop chrome is later DESIGN.md, not this cut. |
| F02 | Uncalibrated vs calibrated readout | **Include** | Calibrated numbers are primary; uncalibrated stays visible so app-side cal is honest. |
| F03 | Analog SG / temp bars | **Improve** | Phone bars are live-only fake gauges, not history. **V1:** time-series SG and temp charts from local history (the actual beat vs Tilt 2). |
| F04 | Last-seen seconds | **Include** | Honest last-seen. This desktop radio is weak (`README.md`: −94 to −103 dBm in-room); do not fake a live needle. |
| F05 | RSSI line | **Improve** | **V1:** dBm from this PC’s scan event only. No Pico “source” tag. Never treat TX-power as battery %. Missing RSSI → “—” with last-seen, do not invent a previous dBm. |
| F06 | Packet timestamp + app version | **Improve** | **V1:** last-packet local datetime on the live row. App version in window/About chrome, not on every reading. |
| F07 | Scanning toast | **Improve** | Toast is phone chrome. **V1:** persistent status: Bluetooth Off / Scanning / Heard N / Empty. Empty is honest; never invent SG/temp (`README.md`). |
| F08 | Hide card after 2 minutes | **Improve** | Hiding is a phone-range trick and fights long listens. **V1:** keep the Tilt visible as **stale** (last values + last-seen). Do not drop it at 120 s. |
| F09 | Landscape two-up | **Exclude** | Phone orientation. Window layout is DESIGN.md later. |
| F10 | Standard vs HD (Pro) decode | **Include** | Protocol. Patrick’s Pink is Pro (`minor` scaled). Same heuristic as README / Tilt 2 (`minor > 5000`). |
| F11 | Eight factory colors | **Include** | Protocol UUID table (Red…Pink). Display name derived from UUID; color is factory. |

## 2. Multi-Tilt

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F12 | Simultaneous color cards | **Include** | One live row per color UUID. Key by color, not by a fake “connected” session. |
| F13 | Remember found colors | **Include** | Persist name / units / cal / logging by color so a rescan does not wipe our knobs. |
| F14 | Same-color Tilts (Pico MAC) | **Exclude** | Pico-only identity. Phone ranging cannot tell two Pinks apart; V1 will not invent GATT identity. One Pink Pro is the desk target. |

## 3. Names

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F15 | Beer name | **Include** | Per-color local name, default Untitled, shown on the live row. Labeled as Tilt-a-Wort’s name, not the float’s. |
| F16 | Cloud beer ID | **Exclude** | Baron Brew Sheets suffix. Not load-bearing on this PC. |

## 4. Units

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F17 | Card UNITS cycle | **Improve** | Tap-cycle is phone chrome. **V1:** units live in settings (F18), not a live-row carousel. |
| F18 | Settings unit radios | **Improve** | **V1:** °F/°C and SG/°P only, display-side, labeled as ours. Drop °Bx, %ABV, %ABV*, proof — not needed to beat the phone at this desk. |

## 5. Calibration (app-side)

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F19 | CAL prompt | **Include** | App-side paired uncal/actual gravity (and temp) points. Copy: our table, not written to the Tilt. |
| F20 | Multi-point interpolation | **Include** | Live display interpolates sorted points. Smallest honest cal. |
| F21 | Settings cal lists | **Include** | List / delete pairs; fill uncal from current reading; add a pair. |
| F22 | “Tare in water” button | **Improve** | Tilt 2 maps current uncal SG → 1.000 in **phone** cal (not firmware tare). **V1:** same shortcut in our table, labeled “Tilt-a-Wort cal → 1.000”, never “tare the device”. Hardware purple-LED tare stays out of band (`README.md`). |

## 6. Local logging

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F23 | Device logging toggle | **Include** | Per-color local logging on/off. Off = no file. On with no file = ready to start. |
| F24 | CSV + JSON on phone | **Improve** | **V1:** CSV on this PC, columns `Timestamp,Timepoint,SG,Temp,Color,Beer,Comment`. No twin JSON. Chart history is the same local store, not Cordova `dataDirectory`. |
| F25 | Auto-append on interval | **Improve** | Phone default 15 min is cloud/battery, and the app must stay foreground. **V1:** every decoded packet (~5 s) into local history for charts; CSV follows that (or a denser-than-15-min setting). No cloud POST. |
| F26 | Start New Log | **Improve** | **V1:** start a named **local** log. Prompt for beer name if Untitled. Do not auto-enable cloud. |
| F27 | Log once + comment | **Improve** | **V1:** one local history/CSV row with a comment (dry hop, crash). No cloud POST. |
| F28 | End log | **Improve** | **V1:** stop writing the current file. No “End of log” POST. Do not auto-wipe the beer name (user can clear it). |
| F63 | Device file list | **Improve** | **V1:** list local logs; delete; reveal in Explorer. No email-on-tap. |

## 7. Cloud / 3rd-party

Not load-bearing for “better than the phone app on this PC.” Local history/charts replace remote Sheets cards.

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F29 | Default Google Sheets (Baron Brew) | **Exclude** | Phone/Pico HTTP. Hydrometer never talks to Google. |
| F30 | Custom cloud URL 1 | **Exclude** | Generic webhook (Brewfather et al. are POSTs, not clients). |
| F31 | Custom cloud URL 2 | **Exclude** | Same. |
| F32 | Email for sheet share | **Exclude** | Sheets sharing. |
| F33 | Cloud interval stepper | **Exclude** | How often the phone/Pico posts, not radio rate. |
| F34 | Cloud status on card | **Exclude** | Sheet link chrome. |
| F35 | Remote Google Sheets cards | **Exclude** | Polls Sheets when out of BLE range — the phone-left-in-brewery workaround. V1 history is on this PC. |
| F36 | Cloud log history | **Exclude** | List of sheet URLs. |
| F37 | New-log retry / logId | **Exclude** | Sheets duplicate-avoidance. |

## 8. Permissions

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F38 | Bluetooth scan permission | **Improve** | Not Android `BLUETOOTH_SCAN`. **V1:** detect Windows Bluetooth **PoweredOn**. Unpackaged Win32: radio On, no Store capability, no admin (`README.md`). |
| F39 | Bluetooth advertise permission | **Exclude** | Pico Wi‑Fi provisioning only. Not needed to hear a Tilt. |
| F40 | Fine location permission | **Exclude** | Android BLE. |
| F41 | When-in-use location (plugin) | **Exclude** | iOS/Android plugin. |
| F42 | Cleartext HTTP | **Exclude** | Pico `http://{ip}`. |

## 9. Background / range

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F43 | Foreground ranging only (Android 8+) | **Improve** | Tilt 2 **stops scan on pause** — the reason a phone must sit in the brewery. **V1:** keep scanning while this process is running, including minimized. No Windows service in V1. |
| F44 | KeepRunning preference | **Exclude** | Cordova flag; does not implement a foreground service. |
| F45 | Scan cadence | **Improve** | Do not clone AltBeacon 1500/500. **V1:** continuous empty-filter scan, no Coded PHY, UI refresh ~1 s (`README.md`). |
| F46 | Bluetooth toggle helper | **Improve** | Do not flip the radio from the app. **V1:** if Off, say so and point at Windows Settings. |
| F47 | In-range vs out-of-range | **Improve** | **V1:** Live / Stale / Empty. RSSI as dBm, not feet. Do not hide at 120 s (see F08). Empty scan is a real result. |

## 10. Settings / chrome

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F48 | Left Settings panel | **Improve** | **V1:** settings for name, units, cal, logging only. No email, no three cloud URLs, no Pico accordion. |
| F49 | Right Files panel | **Improve** | **V1:** local log list only. No cloud logs, no Pico CSVs. |
| F50 | Restore on launch | **Include** | Reload found colors’ name / cal / units / logging from local PC storage. |
| F51 | Help / Buy Tilt | **Exclude** | Marketing links. Not load-bearing. |
| F52 | Splash / status bar | **Exclude** | Cordova chrome. |

## 11. Sharing

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F53 | Email current CSV | **Improve** | **V1:** reveal/export the CSV in Explorer. No email composer. |
| F64 | Open Google Sheet | **Exclude** | Sheets. |
| F65 | Email Pico CSV | **Exclude** | Pico. |

## 12. Tilt Pico

All phone ↔ Pico (iBeacon advertise + LAN HTTP). None of it writes the float. V1 is this PC as the logger, not a Pico/Pi bridge.

| ID | Name | Verdict | Why / V1 instead |
|---|---|---|---|
| F54 | Pico discovery | **Exclude** | Pico iBeacon region. |
| F55 | Pico Wi‑Fi setup | **Exclude** | Phone advertises SSID/password. Not GATT to a Tilt, still not V1. |
| F56 | Use Pico as scanner | **Exclude** | LAN JSON of beacons. |
| F57 | Pico cloud sync | **Exclude** | Pico then POSTs cloud. |
| F58 | Pico local logging | **Exclude** | Pico filesystem. |
| F59 | Rename Pico | **Exclude** | Phone label for a Pico. |
| F60 | Pico file list / remove log | **Exclude** | Pico HTTP. |
| F61 | Reset Pico Wi‑Fi | **Exclude** | Pico HTTP. |
| F62 | Remove Pico config / tilts | **Exclude** | Pico HTTP. |

---

## Non-features (inventory appendix — do not add)

Already out: GATT / connect / pairing; battery %; firmware tare; “connected” Tilt; Tilt Pi dashboard; settings written to the float; Google OAuth; firmware update; dead `copySettings`; Framework7 sample pages.

Tilt 2 has **no in-app chart**. V1’s chart is F03 Improve, not a new cloud dependency.

---

## V1 cut

Smallest desktop app that beats Tilt 2 **at this desk**.

### Surfaces (IA, not visual tokens)

1. **Status** — Bluetooth Off / Scanning / Heard N / Empty. Point at Windows Settings when Off. Never invent a reading.
2. **Live** — one row per color UUID: our beer name, factory color, Standard vs Pro, calibrated SG + temp (primary), uncalibrated, last-seen, RSSI dBm, last-packet local time, Live vs Stale. Stale keeps last values; does not hide.
3. **Chart** — SG and temp vs time for the current (or selected) local log, from every decoded packet.
4. **Settings (ours)** — beer name; °F/°C; SG/°P; cal point list (add / delete / fill from current uncal); water shortcut = current uncal SG → 1.000 in **our** table. Copy never says the float accepted a write.
5. **Logs** — per-color logging toggle; Start / End; Log once + comment; list; delete; reveal CSV in Explorer.

Persist name / units / cal / logging / found colors on this PC, keyed by color UUID. Restore on launch.

Scan: empty filter, no Coded PHY, no GATT, no pairing. Decode per `README.md` (standard vs Pro). Eight factory UUIDs. Keep scanning while the process runs (including minimized). Radio Off is a first-class state.

### In V1 (Include + Improve)

F01, F02, F03, F04, F05, F06, F07, F08, F10, F11, F12, F13, F15, F17, F18, F19, F20, F21, F22, F23, F24, F25, F26, F27, F28, F38, F43, F45, F46, F47, F48, F49, F50, F53, F63.

### Out of V1 (Exclude)

F09, F14, F16, F29–F37, F39–F42, F44, F51, F52, F54–F62, F64, F65.

### Explicitly not V1

Cloud / Brewfather / Sheets / Pico / Pi. Phone-left-in-brewery logging. Advertise, location permissions, email composer, splash, Help/Buy. Same-color MAC identity. ABV / Brix / proof. A Windows service.

---

## Coverage

Walked every F-row in `tilt-app-features.md` (F01–F65; IDs are not contiguous after F28). 13 Include + 22 Improve + 30 Exclude = 65.
