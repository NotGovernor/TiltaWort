# Tilt 2 Android — user-facing feature inventory

Date: 10-24-2026. Spike only. No app code shipped. Zero APK / decompile.

**Vendor clone (do not commit):** `M:\Git Repos\TiltaWort\planning\vendor\Tilt-Hydrometer-Framework7`  
**Branch (primary):** `Tilt-2-Android`  
**HEAD SHA:** `382a6e3b8cd0b7b6904b9acefa6a9094e405137b`  
**App identity:** Play Store `com.baronbrew.tilthydrometerf7`, `config.xml` name **Tilt 2**, version **1.1.17** (`config.xml:2–3`, `www/js/app.js:36`).  
**Ignored:** `planning/vendor/` is in TiltaWort `.gitignore`. Baron Brew files were not `git add`ed.

This list is from **cloned source**, not marketing. Play Store / tilthydrometer.com are corroboration only (URLs at the bottom).

## How the official app is built

Cordova + Framework7. Real UI is one screen: `www/index.html` (home cards + left Settings panel + right Files panel). Logic is `www/js/app.js` (4219 lines). Routes in `www/js/routes.js` still include leftover Framework7 samples (`/about/`, `/form/`, page-loaders) — those pages are lorem / widget demos, **not** Tilt features.

Radio path: `cordova-plugin-ibeacon` (`com.unarin.cordova.beacon`) **ranges** eight Tilt UUIDs plus one Tilt Pico UUID. Settings live in **phone** `localStorage` + `NativeStorage`, keyed by color (and color+MAC when a Pico is the scanner). Cloud is the **phone or Tilt Pico** HTTP POSTing Google Sheets / custom webhooks. The hydrometer never joins a network.

Plugins (`package.json`): file, nativestorage, statusbar, inappbrowser, advanced-http, ibeacon, android-permissions, email-composer.

---

## 1. Live readings

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F01 | Live Tilt card | One card per in-range hydrometer: beer name, color, calibrated SG + temp, UNITS / CAL / LOG. | `www/index.html:117–138` template `#displaytemplate`; filled by `updateBeacons` `www/js/app.js:856–1173` | Phone-only display of last ranged iBeacon. Hydrometer: ads only. | Bluetooth + Location; Tilt floating |
| F02 | Uncalibrated vs calibrated readout | Card shows calibrated gravity/temp as the big numbers; uncalibrated values sit on the analog bars. | `index.html:129–135`; `app.js:860–899`, `1158–1165` | Phone applies cal points to last `uncalSG` / `uncalTemp` | F01; cal points F19 |
| F03 | Analog SG / temp bars | Fake gauges: SG bar maps 0.980–1.150, temp bar 0–185 °F. Not a history chart. | `index.html:129–135`; `app.js:1169–1170` | Phone-only CSS width | F01 |
| F04 | Last-seen seconds | `#numberSecondsAgo` = seconds since last ranged packet. | `index.html:136`; `app.js:1121`, `1166` | Phone timestamp vs last beacon | F01 |
| F05 | RSSI line | Shows dBm plus whether the packet came from this phone or a Tilt Pico. iOS RSSI `0` reuses previous. | `index.html:136`; `app.js:406–416`, `1167` | Phone scan event (not in iBeacon body) | F01; Pico path F54 |
| F06 | Packet timestamp + app version | Local datetime of last packet, plus `v1.1.17`. | `index.html:137`; `app.js:381–382`, `1168` | Phone | F01 |
| F07 | Scanning toast | Bottom toast: “Scanning for nearby TILT hydrometers. Ensure Bluetooth and Location Services are enabled and TILT is floating.” Closes when a Tilt is found. | `app.js:290`, `374`, `2527` | Phone UI | Bluetooth + Location |
| F08 | Hide card after 2 minutes | If no packet for **120 s**, hide the card and drop the color from `inrangebeacons`. | `app.js:1142–1153` | Phone | F01 |
| F09 | Landscape two-up | On ±90° orientation, cards max-width 45%, navbar hidden. | `app.js:264–284` | Phone UI | F01 |
| F10 | Standard vs HD (Pro) decode | `minor > 5000` (or FW codes 1005/1006/1007 with major 999) → HD: temp = major/10, SG = minor/10000, color tagged `•HD`. Else temp = major, SG = minor/1000. | `app.js:643–739` | Decode of iBeacon major/minor. Not written back. | F01 |
| F11 | Eight factory colors | UUID nibble maps RED…PINK (`A495BB10`…`A495BB80`). Same table as Tilt-a-Wort README. | `app.js:141–149`, `649–681` | Radio UUID is factory; display name is derived | F01 |

## 2. Multi-Tilt

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F12 | Simultaneous color cards | Every ranged color gets its own card and settings accordion. `beacons{}` keyed by color. | `app.js:154–155`, `741–744`, `922–929` | Phone | F01 |
| F13 | Remember found colors | `foundbeacons` list persists so settings/cal/units survive a rescan. | `app.js:106–113`, `851`, `903–925` | `NativeStorage` + `localStorage` `foundbeacons` | Phone storage |
| F14 | Same-color Tilts (Pico MAC) | Phone-only ranging cannot tell two Pinks apart. Pico scan appends `_mac` to the color key and can hide the phone’s duplicate. | `app.js:683–715`; settings copy `index.html:313–314` | Pico HTTP JSON of beacons (MAC); phone storage | Tilt Pico + F56 |

## 3. Names

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F15 | Beer name | Per-color name, default `Untitled`. Set/clear in Settings. Shown on the card. | `index.html:399–411`; `app.js:1463–1556`, `1158` | Phone `beerName-{color}` NativeStorage/localStorage | Phone |
| F16 | Cloud beer ID | After a successful Baron Brew Sheets “new log”, beer name becomes `Name,<id>` so later posts append to the same sheet. | `app.js:2872–2876`, `2900` | Phone; id assigned by Apps Script HTTP response | F29, network |

## 4. Units

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F17 | Card UNITS cycle | Tap UNITS: °F+SG → °C+SG → °C+°P → °F+°P → repeat. | `index.html:123`; `app.js:315–354`, `1009–1014` | Phone `displayTempunits-` / `displayFermunits-` | F01 |
| F18 | Settings unit radios | Gravity: SG, °P, °Bx, %ABV, %ABV* (temp-compensated), °UP/°OP (over/under proof). Temp: °F / °C. | `index.html:561–616`; `app.js:357–368`, `1216–1236`, `3034–3058` | Phone only. Formulas are display-side. | F01 |

%ABV / proof use a density lookup table in `convertSGtoABV` / `convertSGtoOPUP`. They are **display conversions**, not something the float computes.

## 5. Calibration (app-side)

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F19 | CAL prompt | Tap CAL: enter actual gravity (0.500–2.000). Cancel → enter actual temperature. Stores a paired uncal/actual point. | `index.html:124`; `app.js:1026–1110` | Phone `uncalSGpoints-` / `actualSGpoints-` / temp equivalents | F01 in range |
| F20 | Multi-point interpolation | Live display interpolates between sorted cal points (`getCalFerm` / `getCalTemp`). | `app.js:1239–1278` | Phone | F19 |
| F21 | Settings cal lists | Lists SG and temp points; checkbox deletes a pair. “Get uncalibrated” fills current reading; “Set calibration” adds a pair. | `index.html:618–670`; `app.js:1176–1452` | Phone NativeStorage | F19 |
| F22 | “Tare in water” button | Button id `addSG-{color}-1.000` maps **current uncalibrated SG → 1.000** in the phone cal table. Comment in source: “handle quick cal / tare in water”. **Not** firmware tare. | `index.html:641`; `app.js:1356–1362` | Phone cal points | F01 in water |

## 6. Local logging

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F23 | Device logging toggle | Per-color switch. Off = no CSV. On with no file = “Ready to Start New Log”. | `index.html:436–447`; `app.js:1625–1653` | Phone `deviceLoggingEnabled-` | Phone filesystem |
| F24 | CSV + JSON on phone | Writes `Timestamp,Timepoint,SG,Temp,Color,Beer,Comment` to `cordova.file.dataDirectory`. Matching `.json`. Filename `{beer} ({color} TILT) {date}.csv`. | `app.js:2122–2188`, `2325–2484` | Phone filesystem (not hydrometer) | F23; Tilt in range |
| F25 | Auto-append on interval | When a packet arrives and `cloudInterval` minutes have passed, `logToDevice` + `postToCloudURLs`. Default 15 min. | `app.js:383–391` | Phone timer | F01, F23/F29, app in foreground |
| F26 | Start New Log | Card LOG / settings “Start New Log”. If both cloud and device toggles are off, it turns both on and returns. Else starts CSV and/or cloud sheet (prompts for beer name if Untitled). | `index.html:125`, `678`; `app.js:1112–1115`, `1975–2076` | Phone + HTTP | F23 and/or F29 |
| F27 | Log once + comment | Settings “Log Once”: prompt for comment, one CSV row + one cloud POST. | `index.html:679`; `app.js:2078–2087` | Phone + HTTP | F23/F29 |
| F28 | End log | Clears beer name, local filenames, cloud URL link after a 5 s undo toast. Posts “End of log”. | `index.html:680`; `app.js:2089–2120` | Phone | F26 |
| F63 | Device file list | Right panel lists CSVs. Tap emails the file. Swipe deletes CSV+JSON from disk and stops active log if that file was current. | `index.html:81–89`, `171–185`; `app.js:767–847`, `2247–2277` | Phone filesystem + NativeStorage `listOfCSVFiles` | F24 |

## 7. Cloud / 3rd-party

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F29 | Default Google Sheets (Baron Brew) | Toggle “Log to Google Sheets”. POST `Timepoint, SG, Temp, Color, Beer, Comment` to Apps Script in `app.data.defaultCloudURL`. New log can wrap email/units in JSON Comment + `logId`. Response sets sheet URL + beer id. | `index.html:449–473`; `app.js:34`, `1658–1722`, `2716–3032` | Phone HTTP POST. Hydrometer never talks to Google. | Network; email optional F32 |
| F30 | Custom cloud URL 1 | Second webhook (Play Store names Brewfather, brewstat.us, monitor.beer, Grainfather — the app is a generic POST). | `index.html:475–499`; `app.js:1735–1792` | Phone `cloudurls-` slot 1 | Network |
| F31 | Custom cloud URL 2 | Third webhook, same POST body. | `index.html:501–525`; `app.js:1814–1871` | Phone `cloudurls-` slot 2 | Network |
| F32 | Email for sheet share | Saved per color. Sent to Baron Brew script so the sheet is shared. Invalid email → log still starts without it. | `index.html:413–434`; `app.js:1910–1954`, `2034–2052` | Phone `emailAddress-`; not a Google account login | F29 |
| F33 | Cloud interval stepper | 15–60 minutes, step 15. Minimum toast at 15. This is **how often the phone/Pico posts**, not Tilt radio rate (still ~5 s). | `index.html:527–545`; `app.js:1891–1908` | Phone `cloudInterval-` | F25 |
| F34 | Cloud status on card | After a sheet exists, card shows a cloud icon + minutes since last cloud log, linking to `docLongURL`. | `app.js:934–940`, `1159`, `2902–2912` | Phone; opens URL via InAppBrowser/`_system` | F29 |
| F35 | Remote Google Sheets cards | If a color has a saved sheet but is **not** in BLE range, poll Sheets API `Report!A1:G2` every 60 s and draw a “via Google Sheets” card. Hidden after 7 days stale. Manual remove. | `index.html:140–166`; `app.js:101–102`, `157–160`, `785–809`, `4081–4184` | HTTP GET Sheets API. Key in gitignored `www/js/secrets.js` (example only in tree). Missing key → no cloud cards, scan still runs. | Network + API key; not BLE |
| F36 | Cloud log history | Right-panel list of `{url, beername, color, started}`. Swipe drops the row from the list; **does not delete the Google Sheet**. | `index.html:90–96`, `187–216`; `app.js:2190–2243`, `811–819` | Phone `listOfCloudLogs` | F29 |
| F37 | New-log retry / logId | New Sheets log waits ~25 s, retries once with the same `logId` so the script can return the existing sheet instead of a duplicate. | `app.js:2679–2711`, `2956–2987` | Phone HTTP | F29 |

Play Store copy names brewfather.app, brewstat.us, monitor.log, Grainfather.com as custom endpoints. The Android source has **no** Brewfather-specific client — those are F30/F31 POSTs.

## 8. Permissions

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F38 | Bluetooth scan permission | Android runtime `BLUETOOTH_SCAN`. | `config.xml:43`; `app.js:132–134`, `183–196` | Phone OS | Android 12+ |
| F39 | Bluetooth advertise permission | Android runtime `BLUETOOTH_ADVERTISE` — needed to **broadcast iBeacons to a Tilt Pico** (WiFi SSID/password), not to talk to a Tilt. | `config.xml:44`; `app.js:133`, `198–211`, `3061–3114` | Phone peripheral advertise | F55 |
| F40 | Fine location permission | Android `ACCESS_FINE_LOCATION` (BLE scan on Android). Coarse check exists but is commented out at startup. | `config.xml:42`; `app.js:135`, `213–241` | Phone OS | Android BLE |
| F41 | When-in-use location (plugin) | `locationManager.requestWhenInUseAuthorization()` — iOS-oriented; still called on Android. **Not** Always / background location. | `app.js:756–758`; iOS usage strings `config.xml:81–86` | Phone OS | Plugin |
| F42 | Cleartext HTTP | Android `usesCleartextTraffic=true` so Pico `http://{ip}/…` works. | `config.xml:50–52` | LAN HTTP to Pico | F54 |

No `BLUETOOTH_CONNECT`. No foreground-service permission. No Google account OAuth in the app (Sheets sharing is the Apps Script + email).

## 9. Background / range

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F43 | Foreground ranging only (Android 8+) | `onPause` **stops** ranging and the 1 s UI timer. `onResume` starts them again. Comment: “Android 8+ doesn't allow scanning to continue in background”. | `app.js:2520–2540` | Phone | App in foreground |
| F44 | KeepRunning preference | Cordova `KeepRunning=true`. Does **not** implement a foreground service; F43 still stops the scan. | `config.xml:22` | Phone | — |
| F45 | Scan cadence | AltBeacon foreground scan 1500 ms, 500 ms between. UI refresh 1 s. | `config.xml:55–56`; `app.js:761–763` | Phone BLE ranger | F38–F40 |
| F46 | Bluetooth toggle helper | `toggleBluetooth` disable/enable via locationManager (skipped on Android 4 and iOS). `watchBluetooth` every 30 s is a stub (toggle call commented out). | `app.js:245–261`, `130–131`, `2542–2547` | Phone radio on/off | Android |
| F47 | In-range vs out-of-range | Toast + 120 s hide (F07/F08). RSSI shown, not converted to feet. Vendor FAQ claims ~25 ft — corroboration only. | `app.js:1142–1153` | Phone | BLE range |

Continuous logging without sitting next to the fermenter is **Tilt Pico** (F54–F61), not background phone scan.

## 10. Settings / chrome

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F48 | Left Settings panel | Per-found-color accordion: name, email, device log, three cloud URLs, interval, units, cal, log buttons. | `index.html:32–78`, `388–691`; filled `app.js:928–929` | Phone | F13 |
| F49 | Right Files panel | Device CSVs, cloud log list, Pico CSVs. | `index.html:80–114` | Phone | F63, F36, F60 |
| F50 | Restore on launch | `deviceready` reloads found colors’ logging, cal, units, Pico list, cloud log list, sheet URLs from NativeStorage. | `app.js:105–114`, `2549–2676` | Phone NativeStorage | Phone |
| F51 | Help / Buy Tilt | `https://tilt.help` and `https://tilthydrometer.com`. Pico info popover. | `index.html:47–61`, `97–113` | External browser | Network |
| F52 | Splash / status bar | Cordova splash then black status bar; orientation restyle. | `config.xml:57–65`; `app.js:100`, `125–128`, `264–284` | Phone | — |

`copySettings(fromColor, toColor)` (`app.js:3543–3545`) only copies beer name in memory and is **never called** from the UI — not a feature.

## 11. Sharing

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F53 | Email current CSV | Card “share” / file-list tap opens the system composer with the CSV attached and last reading in the body. | `app.js:2487–2518`; `index.html:126` deviceStatus | Phone email plugin + filesystem | F24; email app |
| F64 | Open Google Sheet | Cloud icon / cloud-log row opens `docLongURL` with `target="_system"`. | `app.js:939`, `2902`; `index.html:202` | HTTP / browser | F29 |
| F65 | Email Pico CSV | Downloads `http://{pico}/log.csv` to the phone then emails it. | `index.html:343`; `app.js:3345–3350`, `4186–4198` | Pico HTTP + phone email | Tilt Pico, same Wi‑Fi |

## 12. Tilt Pico (bridge — not the hydrometer)

All of this is **phone ↔ Pico** (iBeacon advertise + LAN HTTP). None of it writes the Tilt float.

| # | Name | What it does | Where | Storage / radio | Depends on |
|---|---|---|---|---|---|
| F54 | Pico discovery | Extra region UUID `A495BC02-…`. Major/minor packed as LAN IP (`uint16ToIp`). RSSI / major/minor 999/999 = waiting for Wi‑Fi; 999/998 NTP fail; 999/997 Wi‑Fi fail. | `app.js:150`, `486–634`, `3182–3197` | Pico iBeacon ads; phone ranges | BLE; Pico powered |
| F55 | Pico Wi‑Fi setup | FAB “CONNECT TILT PICO”: name, SSID, password. Password AES-CBC encrypted in JS, then **phone advertises iBeacons** (`a495bc00-` SSID, `a495bc01-` password) for ~5 s each. Not GATT to a Tilt. | `index.html:64–67`; `app.js:3061–3246`, `3840–3913` | Phone advertise + Pico receive | BLE advertise perm; within ~5 ft of Pico |
| F56 | Use Pico as scanner | Per-Pico toggle: phone stops using its own ads for those colors and `GET http://{ip}` for Pico’s beacon JSON (MAC identity). | `index.html:293–317`; `app.js:1568–1620`, `165–166`, `434–468` | Pico HTTP; phone `macToggleEnabled-` | Pico on same LAN |
| F57 | Pico cloud sync | Card “TILT PICO” bolt: pick a Pico, `GET /sync?beername&color&mac&cal&cloudurls&cloudinterval&timezoneoffsetsec&logLocally=…`. Bolt color gray/yellow/green/red. | `app.js:418–422`, `945–987`, `3312–3541`, `3677+` | Pico HTTP; Pico then POSTs cloud | Pico + F29/F30 |
| F58 | Pico local logging | Optional `logLocally=true` on the Pico; list of colors; download/view `log.csv`. | `index.html:319–361`; `app.js:3398–3447` | Pico filesystem via HTTP | Pico |
| F59 | Rename Pico | Prompt; stored on phone (`tiltPicos` NativeStorage), not on the hydrometer. | `index.html:366`; `app.js:4200–4212` | Phone | F54 |
| F60 | Pico file list / remove log | Files panel Pico CSVs; `GET /remove_log_file`. | `index.html:216–226`; `app.js:4215–4218` | Pico HTTP | Pico |
| F61 | Reset Pico Wi‑Fi | `GET http://{ip}/reset?` then drop from phone list. Fallback: press R on the hardware. | `index.html:367`; `app.js:3247–3281` | Pico HTTP | Pico on LAN |
| F62 | Remove Pico config / tilts | `remove_config_file`, add/remove colors from Pico logging list. Merge Picos by MAC if DHCP changes IP. | `app.js:3381–3391`, `3595–3637`, `3931–4079` | Pico HTTP + phone `tiltPicos` | Pico |

Pico HTTP paths seen: `/`, `/info`, `/lastlogged`, `/sync?…`, `/reset?`, `/remove_config_file`, `/remove_log_file`, `/log.csv`.

---

## Non-features the UI might imply

Do **not** recommend these for Tilt-a-Wort. Source has no implementation (except as noted).

| Implied by UI / marketing | Reality in Tilt 2 Android source |
|---|---|
| GATT write / connect / pairing | **None.** Zero `gatt`, `writeCharacteristic`, `BleakClient`, or `BLUETOOTH_CONNECT`. Scan is `startRangingBeaconsInRegion` only (`app.js:288–312`). Phone `startAdvertising` is **only** Pico Wi‑Fi provisioning (F55). |
| Battery % | **None.** No battery field. RSSI and iBeacon measured-power are not shown as %. LED blink is hardware (FAQ). |
| Device tare from the app | **F22 is phone cal → 1.000**, not firmware tare. Vendor hardware tare is physical (purple LED, water) — out of band. |
| Pairing / “connected” Tilt | No pairing UX. “In range” = last packet < 120 s. |
| In-app fermentation chart / history graph | **None.** Analog bars are live only. Charts live in Google Sheets (cloud) or a 3rd-party webhook. Play Store reviews complain about this; FAQ says charting is cloud Sheets. |
| Background always-on phone logging | **F43 stops scan on pause** (Android 8+). FAQ: phone plugged in, app **foreground**, near fermenter — or use Pico/Pi. |
| Tilt Pi dashboard | **Not in this app.** Pico only. Tilt Pi is a separate Raspberry Pi image on tilthydrometer.com. |
| Settings written to the float | All knobs are NativeStorage/localStorage or Pico HTTP. |
| Google account sign-in | No OAuth. Email string + Baron Brew script, or a user-hosted Apps Script URL (F29/F30). |
| Firmware update | None. |
| `copySettings` | Dead stub (`app.js:3543`). |
| Framework7 sample pages | `/about/`, `/form/`, page-loaders — not product. |

---

## Corroboration (not the inventory)

- Play Store Tilt 2 (`com.baronbrew.tilthydrometerf7`): cloud Sheets + custom endpoints (Brewfather, brewstat.us, monitor.log, Grainfather), local CSV email, calibrate, °F/°C and SG/Plato, **phone must stay in range for continuous logging**. https://play.google.com/store/apps/details?id=com.baronbrew.tilthydrometerf7
- Get the App: Tilt 2 Android / Tilt 3 iOS / Tilt Pico; Sheets option 1 vs own Apps Script vs 3rd-party. https://tilthydrometer.com/pages/app
- FAQ: continuous Sheets needs phone always on, app **foreground**, near fermenter; Tilt broadcasts every **5 s**; range ~25 ft; Bluetooth + location permissions. https://tilthydrometer.com/pages/faqs

---

## Appendix — Tilt 3 / `master` deltas

Fetched locally as `master` `7fbecf0e83fdc043e0419494c607f0e25ce50893` (“Bump iOS version to 1.1.18”, 08-27-2026). **Not** the Android Play Store app.

| | `Tilt-2-Android` (this inventory) | `master` (Tilt 3 iOS) |
|---|---|---|
| Ships as | Tilt 2, Play Store | Tilt 3, App Store |
| Bundle | `com.baronbrew.tilthydrometerf7` | `com.tilthydrometer.tilt3` |
| Version | 1.1.17 | 1.1.18 |
| `www/` | Shared product UI | Same cards/settings/Pico/cloud; Android-only permission/scan-pause and new-log retry comments differ |
| User-facing extras on master | — | **None material.** Cloud POST timeout copy is 30 s vs Android’s 25/20 + logId retry. Platform chrome (iOS icons, usage strings) only. |
| User-facing extras on Android branch | Pico “Now supports Tilt Pico…” in `config.xml` description; Android 8+ pause/resume scan; `BLUETOOTH_SCAN` / `ADVERTISE` / fine location; cleartext Pico HTTP | iOS Bluetooth Always + When-In-Use strings |

Vendor README (`Tilt-Hydrometer-Framework7/README.md`): develop `www/` on one branch and cherry-pick; platform `config.xml` stays per branch.

**Feature count (Tilt 2 Android): 65 user-facing rows (F01–F65).** Non-features listed separately, not counted. IDs are not contiguous after F28 (F63 is the device file list; F64–F65 are share actions) so Pattern should walk **every table row**, not `range(1,66)`.

Pattern’s child card should walk **every F-row** as include / exclude / improve. Hard excludes already decided: GATT, pairing, firmware, software device-tare, battery % from TX-power, claiming a setting was written to the float.
