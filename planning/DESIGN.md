---
version: alpha
name: Tilt-a-Wort
description: Solarpunk instrument for listening to Tilt hydrometers — brass, silver, water-blue, soil-black; chamfers not blobs; dark default.
colors:
  primary: "#D6A84F"
  secondary: "#C4C8C2"
  tertiary: "#5A9BB8"
  neutral: "#0B0D0C"
  on-primary: "#0B0D0C"
  on-tertiary: "#0B0D0C"
  surface: "#161A16"
  ink: "#F4F1E6"
  muted: "#8B9388"
  light-neutral: "#F3EFE4"
  light-surface: "#E8E2D4"
  light-ink: "#121510"
  light-primary: "#6B5010"
  light-on-primary: "#F3EFE4"
  light-secondary: "#4A4E48"
  light-tertiary: "#1E4A62"
  light-on-tertiary: "#F3EFE4"
  light-muted: "#5A5E58"
typography:
  h1:
    fontFamily: Oxanium
    fontSize: 2.75rem
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "-0.02em"
    fontFeature: "tnum"
  h2:
    fontFamily: Sora
    fontSize: 1.25rem
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  body-md:
    fontFamily: Sora
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: Sora
    fontSize: 0.8125rem
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: Sora
    fontSize: 0.75rem
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.04em"
  readout-temp:
    fontFamily: Oxanium
    fontSize: 1.75rem
    fontWeight: 600
    lineHeight: 1.1
    fontFeature: "tnum"
rounded:
  sm: 0px
  md: 0px
  lg: 0px
  full: 0px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  chamfer-sm: 8px
  chamfer-md: 12px
  chamfer-lg: 20px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.sm}"
    padding: 12px
  button-primary-hover:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.neutral}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
    padding: 12px
  button-ghost:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: 12px
  tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 16px
  tile-stale:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.md}"
    padding: 16px
  banner-radio-off:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.on-tertiary}"
    rounded: "{rounded.sm}"
    padding: 16px
  status-live:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.sm}"
    padding: 8px
  status-stale:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
    padding: 8px
  readout:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.primary}"
    typography: "{typography.h1}"
  chart:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.md}"
    padding: 16px
  button-primary-light:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    rounded: "{rounded.sm}"
    padding: 12px
  tile-light:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-ink}"
    rounded: "{rounded.md}"
    padding: 16px
  tile-stale-light:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-secondary}"
    rounded: "{rounded.md}"
    padding: 16px
  caption:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.muted}"
    typography: "{typography.body-sm}"
  caption-light:
    backgroundColor: "{colors.light-neutral}"
    textColor: "{colors.light-muted}"
    typography: "{typography.body-sm}"
  page-light:
    backgroundColor: "{colors.light-neutral}"
    textColor: "{colors.light-ink}"
  banner-radio-off-light:
    backgroundColor: "{colors.light-tertiary}"
    textColor: "{colors.light-on-tertiary}"
    rounded: "{rounded.sm}"
    padding: 16px
  status-live-light:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    rounded: "{rounded.sm}"
    padding: 8px
---

## Overview

Tilt-a-Wort is a **Monitor** surface: you watch hydrometers that only broadcast. It is living tech — sun-brass, leaf-silver, water-blue, soil-black — not a neon HUD and not a cottage brew-blog. Dark is the product. Light is a greenhouse-day option, same bones.

Home is a list of instrument tiles. Tap one Tilt, get that Tilt’s full UI. Desktop is a wider window of the same app, not a second chrome.

This file is the visual + IA spec for Roller. Tokens are **not** MediaBender champagne/putty (`#C8B496`), not Inter, not Tilt 2’s phone cards. Protocol honesty lives in `README.md`. V1 feature cut lives in `planning/v1-scope.md`. Patrick’s look/IA/platform calls (10-24-2026) live in `decisions.md` and are not relitigated here.

## Colors

Four named metals, two modes. No fifth “success green.” No danger red for radio-off (that is dusk, not an error toast).

**Dark (default)**

- **Neutral (`{colors.neutral}`):** soil-black ground. Warm, not OLED cyber.
- **Surface (`{colors.surface}`):** lifted plot / tile. Still dark.
- **Ink (`{colors.ink}`):** warm paper for body on dark.
- **Primary (`{colors.primary}`):** sun-brass. Live status, hero SG, primary actions. Hairline catch-light on chamfers.
- **On-primary (`{colors.on-primary}`):** soil-black on brass fills.
- **Secondary (`{colors.secondary}`):** leaf-silver. Stale, chrome edges, secondary labels.
- **Muted (`{colors.muted}`):** quiet meta (last-seen caption) on dark.
- **Tertiary (`{colors.tertiary}`):** water-blue. Radio Off banner, Empty listening, temp series on the chart.
- **On-tertiary (`{colors.on-tertiary}`):** soil-black on water-blue fills.

**Light (optional pair)**

- **Light-neutral (`{colors.light-neutral}`):** sun-bleached paper, not SaaS white.
- **Light-surface (`{colors.light-surface}`):** tile / plot on paper.
- **Light-ink (`{colors.light-ink}`):** soil ink.
- **Light-primary (`{colors.light-primary}`):** darker brass so body-size type and buttons pass WCAG AA on paper. Do not put dark-mode `#D6A84F` as small text on paper (fails).
- **Light-secondary (`{colors.light-secondary}`):** ink-silver.
- **Light-tertiary (`{colors.light-tertiary}`):** deep water for banners and temp.
- **Light-muted (`{colors.light-muted}`):** captions on paper.

**Status mapping (both modes)**

| State | Color job |
|---|---|
| Live | brass inlay |
| Stale | silver going matte |
| Empty (scanning, none heard) | water-blue, quiet |
| Radio Off | water-blue banner, first-class — not a dead home |

Factory Tilt colors (Red…Pink) are **identity swatches**, not theme tokens. Do not recolor the app chrome to match the float.

## Typography

Two families, chosen — not Inter, not MediaBender’s 13px UI mono.

- **Oxanium** — live numbers and chart ticks. Angular, matches chamfers, `tnum` always. Hero SG is `h1`. Temp is `readout-temp`.
- **Sora** — everything else (titles, body, labels). Sentence case. Do not shout `LIVE` in tracked caps.

SG digits: Standard Tilt three decimals (`1.016`); Pro four (`1.0160`). Units (`SG` / `°P`, `°F` / `°C`) sit in Sora `label` beside the number, not inside the Oxanium string.

Minimum body 16px on phone. Chart axis labels may be `body-sm`. Hit labels ≥ 44px.

## Layout

4px baseline. `md` (16px) inside a tile or section. `lg` (24px) between Home tiles and between Device sections. `xl` (40px) only for the empty-home listening block.

**Phone-width is the constraint** (~360px content). Home = one column of tiles. Device = one column scroll. App Settings = one column.

**Wide window:** same screens. Tiles may wrap two-across above ~720px; anatomy does not change. Device chart grows horizontally; do not add a desktop-only sidebar, master-detail split, or inspector.

Safe areas: notch / home indicator / desktop window chrome. Custom chrome, not stock iOS grouped settings lists and not a Windows settings clone.

## Elevation & Depth

No drop shadows. No glass blur. Depth = facet + hairline.

- Tile sits on soil; silver 1px edge follows the chamfer.
- Live brass catches a little more edge light than Stale.
- Chart plot is the same surface as a tile, not a floating card.
- Light mode: same rules on paper; edge is light-secondary at 1px, still no shadow.

## Shapes

**Chamfer, not radius.** `rounded.*` is `0px` so nobody “helpfully” squircles it.

Clip tiles, banners, primary buttons, status chips, and the chart plot with **cut corners**: `{spacing.chamfer-sm}` on chips/buttons, `{spacing.chamfer-md}` on tiles, `{spacing.chamfer-lg}` only if a hero empty-state panel needs it. Cut **top-right and bottom-left** (solar-panel facet). Do not round, do not blob, do not squircle, do not pill-badge the status.

Factory color mark: small faceted rectangle, not a circle and not an emoji.

## Components

- `button-primary` — one high-emphasis action per screen (Start log, Add cal point, Open Bluetooth settings). Brass fill, soil text.
- `button-secondary` — End log, Delete, Log once. Surface fill, silver text, silver chamfer edge (edge in CSS, not a token property).
- `button-ghost` — Back, gear. No fill competition with primary.
- `tile` / `tile-stale` — Home instrument. Stale does not shrink or hide; it mattes.
- `banner-radio-off` — persistent on Home (and Settings) while the radio is off. Not a toast. Not a modal that covers remembered tiles.
- `status-live` / `status-stale` — faceted chip. Word is “Live” or “Stale”. Never “Connected”.
- `readout` — Device hero SG. Brass on soil (dark) / dark brass on paper (light, via `button-primary-light` pairing — readout color follows mode: dark uses `{colors.primary}` on `{colors.neutral}`; light uses `{colors.light-primary}` on `{colors.light-neutral}`).
- `chart` — first-class plot surface. Not a sparkline on the tile.
- `caption` / `caption-light` — last-seen, uncal, RSSI. Muted on soil / paper.
- `page-light` — light-mode ground. Dark ground is `{colors.neutral}`.
- `tile-stale-light` — Stale tile on paper.
- `*-light` siblings — same components when Appearance = Light.

Light-mode primary button uses `button-primary-light`. Do not invert by swapping hex blindly.

## Do's and Don'ts

- **Do** treat Tilts as one-way beacons. Status is Live / Stale / Empty. Radio Off is a banner, not a greyed-out corpse of Home.
- **Do** keep calibrated SG + temp as the numbers people glance. Uncalibrated belongs on Device, not the tile.
- **Do** label names, units, cal, and logs as **ours on this device**. Copy never says the float accepted a write. Water shortcut: “Tilt-a-Wort cal → 1.000”, never “tare”.
- **Do** clip chamfers; keep edges silver/brass hairlines.
- **Don't** restyle MediaBender gold, Inter, uppercase mono chrome, or Lucide icon salad.
- **Don't** glassmorphism, squircles, blobs, neon cyan, scanlines, or cottage watercolor hops.
- **Don't** put RSSI, uncalibrated, app version, Pro/Standard, or packet time on the Home tile.
- **Don't** hide a tile at 120 s. Stale keeps last SG/temp.
- **Don't** invent SG/temp on Empty. Em dash, not a leftover needle.
- **Don't** ship Sheets, Pico, Pi, ABV, Brix, proof, pairing glyphs, or battery % in V1.
- **Don't** give desktop a different IA.

## Information architecture

Three screens. Same product on Android, iPhone, Linux, Windows, Mac.

```
Home
 ├─ App status (Scanning · Heard N | Empty | Radio Off banner)
 ├─ Tile list (one per remembered or heard color UUID)
 └─ Gear → App Settings
      ├─ Appearance: Dark (default) / Light
      ├─ About: app version
      └─ Radio Off pointer (same copy as Home banner)

Device  (push from a tile; Back to Home)
 ├─ Header
 ├─ Live numbers
 ├─ Freshness
 ├─ Chart
 ├─ Logging
 ├─ Calibration (ours)
 ├─ Name & units (ours)
 └─ Logs list
```

No tab bar. No cloud pane. No Pico accordion. Sheets / Brewfather / ABV are not screens.

**App Settings** is where dark/light lives — an app setting, not a second product and not a per-Tilt switch.

**Remembered Tilts** (F13/F50): Home lists colors we have heard before, even if currently Stale. Radio Off does not wipe the list.

**Keying:** color UUID. One tile per color. No “connected session.” Same-color two-Pinks is out of V1.

### Home

Surface: Monitor.

Top: product name “Tilt-a-Wort” + gear (App Settings). Under that, persistent **app status** — not a toast:

| Radio | Scan | Copy |
|---|---|---|
| Off | — | Banner: “Bluetooth is off. This app only listens.” Primary: **Open Bluetooth settings** (OS settings; we do not flip the radio). Remembered tiles stay, all Stale. |
| On | running | “Scanning · heard N” where N = currently Live tiles. |
| On | running, N=0, no remembered | Empty home (see below). |
| On | running, N=0, remembered exist | “Scanning · none live” + Stale tiles. |

**Empty home** (radio on, nothing remembered, nothing heard): one listening block, not a marketing hero. Copy: “No Tilts heard. They broadcast about every 5 seconds. This app only listens.” No fake SG.

**Tile list:** Live first (most recently heard at top), then Stale. Tap → Device for that color.

### App Settings

Appearance: two faceted choices, Dark selected by default. Switching mode restyles every screen; it does not duplicate IA.

About: version string lives here only (F06) — never on a reading row.

### Device

That Tilt’s full UI. V1 sections only, in this order, one scroll:

1. **Header** — ghost Back; factory color facet + color word (Pink); beer name (ours; “Untitled” if unset); Live/Stale chip.
2. **Live numbers** — calibrated SG (hero Oxanium); calibrated temp beside or directly under it. Caption: uncalibrated SG + temp, labeled “Uncalibrated”. Quiet “Pro” / “Tilt” decode mark here if we know it — not on the tile.
3. **Freshness** — last-seen relative (“12 s ago”); last-packet local datetime; RSSI as dBm from this device’s scan, or “—” if missing. Never invent a previous dBm. Never show TX-power as battery.
4. **Chart** — first-class. Two stacked plots, shared X (time): SG on top (brass line), temp below (water-blue line). History is every decoded packet in the current local log (or the in-memory listen if no log is open). No area-gradient fill. No analog fake gauges. Empty chart: “No samples yet” — do not draw a flat 1.000.
5. **Logging** — per-color toggle (off = no file). **Start log** / **End log**. **Log once** + comment (dry hop, crash). Start with beer name Untitled → prompt for a name first (ours). End stops the file; do not auto-wipe the beer name.
6. **Calibration (ours)** — list of uncal → actual gravity (and temp) pairs. Add, delete, fill uncal from current reading. Shortcut: current uncal SG → 1.000 in **our** table, labeled “Tilt-a-Wort cal → 1.000”. Confirm copy: “Does not tare the float.” Live display interpolates sorted points.
7. **Name & units (ours)** — beer name field; °F / °C; SG / °P. Display-side only. No live-row unit carousel. No Brix / ABV / proof.
8. **Logs list** — local CSVs for this color. Delete. Reveal in the OS file UI (Files / Finder / Explorer / file manager — not an email composer).

Sheets, Pico, cloud URLs, Help/Buy: not present.

## Tile anatomy

One tile = one Tilt. Pertinent only.

```
┌──────────────────────────────┐  ← chamfer TR + BL
│ [facet Pink]  Pink           │  identity (factory color)
│ SAISON IN THE GREENHOUSE     │  beer name if we have one; omit the line if Untitled
│                              │
│  1.0160          72.4 °F     │  calibrated SG (primary) + temp
│  Live                        │  status chip (or Stale)
└──────────────────────────────┘
```

- **Always:** factory color mark + word, calibrated SG, calibrated temp, Live or Stale.
- **If set:** beer name (our string). If Untitled, skip the name line — do not print “Untitled” on Home.
- **Stale:** last SG/temp remain; chip reads Stale; silver type. Tile stays.
- **Radio Off:** same Stale treatment plus the page banner.

**Not on the tile:** RSSI, last-seen seconds, last-packet timestamp, uncalibrated pair, Pro/Standard, app version, log-running glyph, cloud, battery, analog bars, sparkline.

Minimum height: enough for 44px tap. Wide window: tile stretches or sits two-across; do not add extra fields just because there is room.

## Flows

Copy is spec. Do not substitute “Connected”.

### 1. Open app → hear / empty / radio off

1. Restore remembered colors, names, units, cal, logging (F50).
2. If radio off → Home with **Radio Off** banner + remembered tiles as Stale. Primary opens OS Bluetooth settings. Do not scan. Do not invent readings.
3. If radio on → start continuous empty-filter scan (process lifetime, including backgrounded/minimized). Status: Scanning.
4. Packet decoded → that color’s tile becomes Live, numbers update (~1 s UI refresh). Heard N increments.
5. No packets and no memory → Empty home. Stay scanning. Never fill SG/temp.

### 2. Tap tile → Device

1. Tap tile → push Device for that color UUID.
2. Header + live numbers + freshness + chart + our knobs, as above.
3. Back → Home. Scan does not stop.
4. Deep link none in V1.

### 3. Start / stop log

1. On Device → Logging. If beer name Untitled, Start asks for a name (required to start). Cancel leaves logging off.
2. Start: open a named local CSV (`Timestamp,Timepoint,SG,Temp,Color,Beer,Comment`). Chart follows this file. Toggle on.
3. Packets append (~5 s). Log once writes one row with comment, even between intervals.
4. End: stop writing. File remains in Logs list. Beer name stays. Chart remains viewable for that closed log until a new Start.
5. Reveal: OS file UI. No email.

### 4. Add a cal point

1. Device → Calibration. Add.
2. Uncal field: empty, or **Fill from current** (uses live uncal if Live; if Stale, fill last uncal and say it is last-seen, not live).
3. Actual: what we want that uncal to read. Optional temp pair if we collect one.
4. Save into **our** table. Copy: “Stored on this device. Not written to the Tilt.”
5. Water shortcut: confirm “Tilt-a-Wort cal → 1.000. Does not tare the float.” Maps current uncal SG to 1.000 in our table.
6. Live numbers immediately use interpolated cal. Uncal caption still shows raw.

### 5. Stale while looking at a Device

1. Last packet age ≥ **15 s** (about three missed ads) → chip Live → Stale. Numbers freeze on last calibrated values. Chart does not add points. Last-seen counts up. RSSI holds last dBm until a new packet (do not dash it just because Stale; dash only if the scan event never had RSSI).
2. New packet → Live, numbers move, chart resumes.
3. Radio turns off mid-view → Stale + the same Radio Off banner pinned above the Device header (or a slim in-page echo). Back to Home still shows the banner.
4. Do not pop a “disconnected” modal. Do not pop the user home. Do not hide the tile.

**Live vs Stale threshold:** 15 s default. Empty is “this color has never been heard this session and has no remembered last values” — if remembered last values exist, it is Stale, not Empty.

## Cross-platform

Same IA on Android, iPhone, Linux, Windows, Mac.

| | Phone | Desktop / large window |
|---|---|---|
| Home | one-column tiles | same tiles, may wrap two-across ≥720px |
| Device | one-column scroll | same sections; chart wider |
| Settings | pushed screen | pushed screen, not a preferences window with extra panes |
| Radio Off | banner + OS Bluetooth settings | banner + OS Bluetooth settings |
| Reveal CSV | OS Files / share sheet to Files | Finder / Explorer / file manager |
| Scan permission | OS prompt is a banner-class event, same as Radio Off — not a fourth screen | Windows: PoweredOn; no Store capability theater |

Custom chrome on all five. Do not ship stock iOS Settings appearance, Material lists, or WinUI settings as the product.

Phone-width is the tight constraint; if it fails at 360px it fails. Desktop does not unlock Pico, Sheets, or a different nav.

V1-scope still talks “this Windows PC” as the original desk target. This DESIGN.md follows the later 10-24-2026 call: five platforms, one IA. Do not relitigate. Toolkit choice is Foreman’s later card.

## Steering for Chaser

Draw from this without waiting on Pattern. Raster mockups are your card; this is art direction only.

- Solarpunk = **living tech**: brass that could have been grown, leaf-silver edges, water-blue dusk, soil-black ground. Sun on metal, not RGB on acrylic.
- Not neon-cyber: no magenta, no scanlines, no FPS-HUD brackets, no glow soup.
- Not cottagecore: no kraft collage, no watercolor hops, no serif farmhouse, no cute bottle illustrator sticker.
- Chamfers: cut TR+BL like a solar facet. Hairline metal edge. Zero squircles, zero blobs, zero glassmorphism.
- Home is a **rack of instruments**, not an icon-grid of apps. One tile = one hydrometer.
- Factory color = small faceted metal chip (real Red/Pink enamel), not a round candy dot and not a beer emoji.
- Live = brass catching light on a 5 s breath. Stale = the same facet gone matte silver. Empty/Off = dusk blue, not a red X.
- Chart: two honest polylines on a faceted plot (brass SG, water temp). No gradient-area candy, no fake analog needle.
- Light mode is **sun on a greenhouse wall** (warm paper), the same chamfers — not a simple invert of dark.
- Empty home: a quiet listening still — antenna among leaves, patient. Not a disconnected-plug illustration.
- Radio Off is a first-class dusk banner over the still-visible rack, not a blocking modal and not a dead screen.
- Stay off MediaBender: no champagne putty gold, no Inter, no uppercase mono labels, no generic Lucide stroke salad.
- Motion is light on a chamfer when a packet lands. `prefers-reduced-motion`: static brass, no breath.

## Builder notes (Roller)

- Screens to implement from this file: **Home**, **Device**, **App Settings**.
- Status vocabulary: Live / Stale / Empty / Radio Off. Never Connected / Paired / GATT.
- Persist by color UUID on this device: name, units, cal table, logging, last values, last-seen.
- Scan: empty filter, no Coded PHY, no GATT. Keep scanning while the process runs.
- CSV columns: `Timestamp,Timepoint,SG,Temp,Color,Beer,Comment`.
- Decode Standard vs Pro per `README.md`. Display Pro precision on Device numbers.
- Appearance token switch: dark components vs `*-light` components. Default dark.
)
