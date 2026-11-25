# Tilt-a-Wort decisions

Patrick's calls. Do not relitigate. Newest at the top.

- 11-24-2026 — **Updates.** GitHub Releases, user taps Update before download. No cert. No Play Store. iOS has none.
- 11-24-2026 — **Windows listen.** In-process cdylib (no `tilt_listen.exe` child); Android and iOS are listen-only; Linux/macOS use the cdylib only if the library is present, else stub.
- 11-24-2026 — **Home header.** No Tilt-a-Wort wordmark/text at the top of Home. Gear stays. Icon kit C unchanged.
- 11-24-2026 — **Android data.** Prefs + CSV live under app support (`path_provider`), not `%APPDATA%` fallback `.`. Windows stays `%APPDATA%\Tilt-a-Wort`.
- 10-25-2026 — **Brand mix.** Icon/logo = kit **C**. Home wordmark kit B was this day's call; the 11-24 header decision supersedes it (no Home wordmark).
- 10-25-2026 — **Look is pass 1, in the running app.** Patrick: current Flutter UI looks almost nothing like `jobs/t_463f3b3f/`. Visual refine until Assay matches those stills. IA/BLE unchanged.
- 10-25-2026 — **V1 Windows shipped (Assay).** HEAD `7e7062b`. Live Pink Pro in the Flutter window, Home cal + light tiles, Device chart/CSV. `flutter test` +48. Radio Windows-only; other OS stub. No GitHub.
- 10-24-2026 — **V1 stack: Flutter.** Windows radio first. Android/iOS/Linux/macOS stub until a later slice. No GitHub until Patrick says. Branch `master`. No LICENSE.
- 10-24-2026 — **Look locked: pass 1.** Patrick: favorites by far are `jobs/t_463f3b3f/` (chamfered plates). Pass 2 timid, pass 3 rejected. Do not restyle off that set. Canonical copies: `planning/mockups/`.
- 10-24-2026 — **Look, restart.** Pass 3 rejected (“look like ass”). Do not iterate those files. Last set Patrick approved was pass 1 (`jobs/t_463f3b3f/`). Visuals start over. IA unchanged.
- 10-24-2026 — **Look, pass 3.** REJECTED. HUD/brass-instrument overshoot. Do not use as source.
- 10-24-2026 — **Look.** Sleek, futuristic, solarpunk. Dark mode default, light mode optional. Palette: gold, silver, blue, black. Angles and chamfers, not soft blobs.
- 10-24-2026 — **Home.** Simple list of tiles, one per Tilt. Pertinent info: status, current gravity, current temp. Tap a tile → that device's full UI.
- 10-24-2026 — **Cross-platform.** Android, iPhone, Linux, Windows, Mac. Same product IA on all five, not a Windows-only CLI and not five different apps.
- 10-24-2026 — **V1 feature cut.** Live SG/temp, honest last-seen (Live / Stale / Empty — Tilts do not pair), local charts + CSV, local names/units/cal labeled as ours. No Sheets, Brewfather, Pico, Pi, GATT, pairing, firmware, software device-tare, battery % from TX-power. See `planning/v1-scope.md`.
