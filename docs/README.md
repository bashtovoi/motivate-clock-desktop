# Motivate Clock Desktop: Documentation

Motivate Clock is a free desktop time-tracking assistant. It watches which application or website is in the foreground, matches it against the user's **projects**, and counts every second as **work**, **rest** or **pause** (idle). The app is written in **ActionScript 3** and runs on **Adobe AIR** (Harman AIR SDK, descriptor namespace `50.0`). It ships in English, Russian and Ukrainian.

Current version: **1.6.4** (see `build.properties`).

## Contents

| Document | What it covers |
|---|---|
| [features.md](features.md) | Every user-facing feature: clock modes, projects, statistics, PDF export, notifications, tray, settings, hotkeys |
| [project-structure.md](project-structure.md) | Repository layout and what each folder and package contains |
| [architecture.md](architecture.md) | MVC + command design, startup sequence, the time-tracking pipeline, the event catalogue |
| [data-storage.md](data-storage.md) | SQLite schema, settings file, and every other file the app writes |
| [native-integration.md](native-integration.md) | Native Windows helper executables and the browser-extension socket protocol |
| [build-and-release.md](build-and-release.md) | Prerequisites, Ant targets, packaging (Inno Setup / DMG), signing, auto-update |
| [known-issues.md](known-issues.md) | Limitations, dead code and technical debt found during analysis |

## Quick facts

- **Language / runtime:** ActionScript 3 on Adobe AIR, `extendedDesktop` profile (required for `NativeProcess` and `ServerSocket`).
- **Entry point:** `src/org/motivateclock/Main.as`
- **UI assets:** `static/ui.swf`, compiled from the Adobe Animate project in `xfl/motivate_clock/`. It is embedded in the main SWF and loaded at runtime.
- **Persistence:** local SQLite database `statistic.db` in the AIR application storage directory.
- **Activity detection:** Windows helper executables in `static/utils/` plus browser extensions (Chrome, Firefox, Opera/Yandex) that report the active tab over `127.0.0.1:1257`.
- **Third-party libraries (`vendor/`):** PurePDF, Tweener, as3_jpeg_wrapper, Google Analytics for Flash, ServiceMonitor.
- **Build:** Apache Ant (`build.xml`) with the Flex SDK `mxmlc` task and AIR `adt`/`adl`.
- **License:** MIT.
