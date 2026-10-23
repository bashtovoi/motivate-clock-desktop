# Known Issues & Technical Debt

These observations come from a static read of the code at v1.6.4. They are not verified bug reports.

## Functional gaps

- **The statistics date-range selector does nothing.**
  - `StatisticView.initializeDateRangeSelector()` renders day / week / month / project.
  - However, `updateStatistics()` always sends `range = ""`, and `DataBase.getStatistics()` ignores its `range` parameter.
  - `DataBase.getStatisticsByDate()` exists, but its result handler is empty.
- **The activity reminder in `ToastController` is disabled.** The `updateActivityTime(...)` call in `clock_tickHandler` is commented out. Work and rest reminders still come from the `ToastManager` show timer.
- **macOS has no automatic tracking.** The native helpers are Windows-only `.exe` files and are left out of the Mac bundle. See [native-integration.md](native-integration.md).
- **`update.xml` uses the `.exe` URL for the `<dmg>` entry too.** `create.update.descriptor` sets `DOWNLOAD_URL` to `${APP_NAME}.exe`.
- **DMG signing is not implemented.** The `sign.dmg` macro is empty.

## Robustness

- **SQL is built by string concatenation.**
  - `DataBase.convertList2QueryList()` joins process paths directly into `IN ('…')`.
  - A path or domain that contains `'` breaks the query.
  - Parameter binding would fix this.
- **Errors are swallowed in many places.**
  - Many `try { … } catch (e:Error) {}` blocks and empty `SQLErrorEvent` handlers hide failures.
  - Uncaught errors are suppressed by `ErrorLog` (`preventDefault`).
- **The `isAuto` column is never written.** `addProject` and `updateProject` do not store it. It is recomputed from the process list at runtime anyway.
- **Process ids can collide.** Different paths that differ only in non-word characters produce the same id (path with `\W` removed).
- **There is no DB index** on `statistic(projectId, usedDate, appPath)`. `syncProcess` runs a SELECT before each write, which slows down as the history grows.
- **Dates are stored from `Date.toDateString()`**, parsed back with `new Date(string)`, and grouped with `STRFTIME`. This relies on AIR's SQLite date conversion.

## External services

- **Google Analytics uses Universal Analytics** (`UA-8935548-3`, `analytics_flash.swc`). Universal Analytics stopped processing data in 2023–2024, so events are most likely no longer collected.
- **Site favicons** come from `google.com/s2/favicons`, which needs network access.
- **Links in `links.xml`** point to the Chrome Web Store support and review pages for "Report error" and "Rate".

## Repository hygiene

- `certs/dev_cert.p12` and its password (`dev`) are committed. This is fine for development only; release builds must override `KEYSTORE` and `STOREPASS`.
- `tools/signtool.exe` and the helper `.exe` files are committed binaries. The helpers' source code is not in the repository.
- The `static/icons/` file names use the Cyrillic letter `х` (for example `16х16.png`), and the descriptor references them the same way. Renaming either side breaks the app icon.
- **Dead code:**
  - `NotificationModel` / `NotificationView` are mostly unused.
  - `Settings.idleState` and `appHeight` have empty setters.
  - `TRAY_ICON_DISABLE` refers to an asset that does not exist.
- There are no automated tests.
