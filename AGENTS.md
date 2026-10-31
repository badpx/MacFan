# AGENTS.md

This file provides guidance to Code Agents when working with code in this repository.

## Project overview

MenuGauge (formerly MacFan) is a macOS menu-bar system monitor: CPU/GPU usage, CPU temperature, fan RPM, memory, disk, and network rates. Pure Swift (SwiftPM executable, no Xcode project — do not add one), AppKit + SwiftUI, no third-party dependencies, macOS 13+, Apple Silicon and Intel. Display name is MenuGauge, but bundle ID stays `com.badpx.macfan` (UserDefaults domain, SMAppService login item identity, and App Store records all depend on it).

Repo docs (README.md, docs/Release.md) are in Chinese; code comments are mostly English.

## Commands

```bash
bash Scripts/build.sh            # local ad-hoc universal MenuGauge.app → build/MenuGauge.app
bash Scripts/build.sh dmg        # Developer ID + notarized DMG (needs env credentials, see docs/Release.md)
bash Scripts/build.sh appstore   # sandboxed Mac App Store pkg (compiles with -DMAS)
swift test                       # all tests
swift test --filter StatusGaugeTests            # one test class
swift test --filter StatusGaugeTests/testName   # one test
swift run MenuGauge --smoke      # CLI smoke test: sample every provider and print readings
swift run MenuGauge --fandump    # dump raw SMC fan keys (debug, non-MAS builds only)
swift run MenuGauge --ui-snapshot build/ui-check -AppleLanguages '(zh-Hans)'
                                 # DEBUG-only: render popover/settings PNGs with fixed sample data
```

Version/build numbers are injected by build.sh (`MACFAN_VERSION`/`MACFAN_BUILD` or `--version`/`--build`), never hardcoded in `Resources/Info.plist`. `dmg` and `appstore` modes require explicit values.

## Architecture

Single-target SwiftPM executable under `Sources/MenuGauge/`, entry point `main.swift`. The app is a menu-bar-only agent (`LSUIElement`, `.accessory` activation policy); it temporarily becomes a regular app while the Settings window is open (for ⌘Tab/⌘W), then reverts.

**Sampling model** — One shared 2-second timer in `AppDelegate` drives everything. Each metric is a `MetricProvider` (`Metrics/MetricProvider.swift`) with a stable `id` and `func sample() -> MetricReading`. `MetricReading` carries two presentations: `menu` (full line for the popover) and `compact` (two-line menu-bar widget, nil = not shown). To add a metric: implement the protocol and add it to the provider catalog (`MetricCatalog.makeProviders`). The catalog takes `appStore:` — MAS builds exclude fan and SMC temperature providers.

**Menu bar rendering** — All menu-bar widgets are drawn by a single flat `NSView` subclass (`WidgetsView` in AppDelegate.swift) in one `draw(_:)`. This is deliberate: an earlier per-metric `NSTextField`/`NSStackView` hierarchy caused AppKit to continuously re-render status-item snapshots (~50% CPU). Keep it flat; clicks fall through to the status-bar button via nil hit-testing. Fixed-width `topWidthTemplate` strings (e.g. "100%") keep widget widths stable so the menu bar doesn't resize as digits change. When the menu bar overflows, `MenuBarOverflow.swift` drops widgets from the right and probes to restore them; the logo is removed last.

**System interfaces** (`Sources/MenuGauge/System/`):
- `SMC.swift` — IOKit AppleSMC client for CPU temperature (per-chip sensor key lists matching Tencent Lemon's `CmcTemperature.m`; only finite readings in 20–110 °C are averaged) and fan RPM (mean of all fans, 0 counts, missing reading = unavailable). Excluded from MAS builds via `#if !MAS`; build.sh verifies the MAS binary contains no `_IOServiceOpen`/SMC literals.
- `ThermalPressure.swift` — five-level thermal pressure from notifyd (`com.apple.system.thermalpressurelevel`), bound via `@_silgen_name` since notify.h isn't in the Swift module map. Works sandboxed; `ProcessInfo.thermalState` (four-state) is only a fallback and for accessibility wording.
- `MemoryPressure.swift` — memory text color follows `kern.memorystatus_vm_pressure_level` (pressure), not usage percentage.
- `SingleInstance.swift`, `LoginItem.swift` (SMAppService, macOS 13+).

**Two editions from one codebase** — The `-DMAS` compile flag (set by `build.sh appstore`) produces the App Store edition: no AppleSMC, no fan UI, thermal state instead of CPU temperature, sandboxed entitlements (`Resources/MacFan-MAS.entitlements`), and any persisted `fan` entry in `menuBarMetrics` is stripped at launch. MAS builds use separate scratch directories in build.sh so `-DMAS` objects never mix with the direct edition.

**UI** (`Sources/MenuGauge/UI/`) — `PopoverView.swift` (the dropdown panel, SwiftUI) and `SettingsView.swift` (settings window) receive samples published from AppDelegate's timer; the menu bar uses its own single-view drawing instead. `StatusGauge.swift` draws the menu-bar gauge (thermal pressure lights arc segments, CPU usage moves the needle). `PopoverPreview.swift` implements `--ui-snapshot` (DEBUG only, fixed sample data, never touches sensors or persisted settings).

**Localization** — No `.lproj` bundles (the .app is hand-assembled from a bare SwiftPM binary). All strings live in `L10n.swift` as enums; language follows the user's preferred-language list, defaulting to English, with zh-Hans matched first. Supported: en, zh-Hans, zh-Hant, ja, ko, hi, es, fr, bn, ru, pt.

## Conventions

- User selection of menu-bar metrics persists in `UserDefaults.standard` under `menuBarMetrics`; keep backward compatibility with older selections.
- **Check the ARM64 slice of every executable component.** macOS 28 drops general Rosetta 2 translation, so a universal main executable is not enough. When adding a login item, XPC service, helper, framework, dylib, or installer-invoked binary, run `lipo -info` (or `file`) on every Mach-O in the app/package and require an `arm64` slice; an x86_64-only nested component will fail on macOS 28 even if the main app is universal. Keep the existing universal build for macOS 13–26 Intel support, and add the same check to `Scripts/build.sh` or release verification whenever a new executable component appears.
- App icon: `Scripts/generate_icon.swift` and `Scripts/render_icon.py` are paired generators — changes to arcs/spacing/needle angle must be made in both. Packaging uses Xcode 26+ Icon Composer (`Resources/MenuGaugeFlat.icon`) for macOS 26 (glass highlights disabled); macOS 13–15 use the ICNS. Never just copy the ICNS as a substitute for full packaging.
- Release process, notarization credentials, and App Store upload: docs/Release.md (never hardcode signing identities; they come from env vars or flags).
