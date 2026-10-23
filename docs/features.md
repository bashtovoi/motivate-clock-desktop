# Features

## 1. The clock and the three modes

The main window is a transparent, chromeless "clock" with flip-style digits (`view/ClockView.as`, `view/clock/FlipperView.as`). It shows the time accumulated for the **current project** in the current mode.

| Mode | `TypeEnum` | Meaning |
|---|---|---|
| Work | `work` | Time spent in applications/sites the project marks as work |
| Rest | `rest` | Time spent in anything else |
| Pause | `idle` | Tracking is paused. Time goes into the project's `idleTime` and is not attributed to processes |

- The clock ticks once per second (`model/ClockModel.as`). Each tick measures the real elapsed time with `getTimer()`. A gap longer than the system idle threshold (for example after sleep or hibernation) is discarded.
- The toggle panel (`view/clock/ClockToggleView.as`) has Work / Rest / Pause buttons plus Settings and Exit.
- The status line (`view/clock/ClockStatusView.as`) shows "You are working" / "You are resting", or a "Start time tracking" prompt.
- When the work/rest time is longer than the configured **working hours**, it is displayed as days (see Settings).

## 2. Projects

A project groups the applications and websites that count as **work** for one task. Code: `model/Project.as`, `model/ProjectsModel.as`, `view/ProjectsView.as`, `view/projects/*`.

- **Manual mode project.** It has the fixed id `"0"` (`ProjectsModel.MANUAL_MODE`), always exists and is pinned to the top of the list. Here the user switches Work/Rest/Pause by hand.
- **Auto mode.** A project with at least one marked process is *auto* (`Project.updateProjectMode()`). The mode follows the foreground process: if the process is in the project's list the mode is Work, otherwise Rest.
- **First launch.** The app creates the manual-mode project and a "first project". New projects are seeded with the site `motivateclock.org`.
- **Project operations:**
  - Create (also `Ctrl+N`).
  - Rename inline (`LabelEditorView`).
  - Delete (with confirmation). This also deletes the project's statistics.
  - Duplicate: creates "Copy <name>" with the same process list.
  - Reset statistics.
  - Open options: edit the process list.
- **Process editor window** (`view/windows/ProcessesWindow.as`):
  - **Applications tab** (`ProcessSettingView`): lists running applications from the native process helper. The user ticks the ones that count as work. A refresh button re-scans.
  - **Internet tab** (`InternetSettingView`): add work domains by typing a URL or dragging a link from a browser. Domains are normalised with `URIUtil.getDomainFromURI`.
  - Browser-extension install buttons for Chrome, Firefox, Opera and Yandex (`BrowserInstallView`). Each button opens the extension store page in the detected browser (`InstallExtensionCommand`).
- **Contextual help.** A help line in the projects panel (`UpdateHelpTextCommand`) suggests the next step: "create a project", "mark applications", "install the browser extension", or "a new version is available".
- Switching the current project is possible from the projects panel or from the tray **Projects** submenu.

## 3. Activity tracking

- The foreground application is reported by the native helper `MotivateClockActivity(64).exe` (see [native-integration.md](native-integration.md)).
- If the foreground app is a known browser (`BrowserEnum`: Chrome, Firefox, Opera, Opera launcher, Yandex), the app waits **650 ms** for the browser extension to report the active tab's URL. If the extension reports, the **domain** is tracked. Otherwise the browser application itself is tracked.
- Each process accumulates seconds while the mode is not Pause. When the foreground process changes, the previous process's time is written to the database for **today's date** (`SaveProcessCommand`).
- **Idle detection.** Uses AIR `USER_IDLE` / `USER_PRESENT` with `idleThreshold` set from the settings slider (1–120 min).
  - On idle the mode switches to the configured target, **Pause** or **Rest**. If the target is Rest, a synthetic `Desktop` process is tracked.
  - When the user returns, the previous mode is restored.
- Work/Rest totals of auto projects are recomputed from the database whenever the project's process list changes, so re-marking an app re-classifies its past time (`ProjectSyncCommand`, `TimeSyncController`).

## 4. Statistics

Code: `view/StatisticView.as`, `view/statistic/*`, `controller/StatisticsController.as`.

- A slide-out panel (`Ctrl+S`) has a project selector and category filters **All / Work / Rest**.
- Applications and sites are listed with icons and are sorted by time. The current process is updated live and moves up the list as its time grows.
- A pie chart (`DrawPieChart`, `StatisticChartView`) shows the work vs rest share.
- Items can be swapped between work and rest directly from the list. This adds the process to the project or removes it.
- **Reset** clears all statistics of the selected project (with confirmation).
- A date-range selector (day / week / month / project) is rendered but not connected yet. See [known-issues.md](known-issues.md).

### Icons

- **Application icons** are extracted from the executable (`File.icon`). They are cached as PNG files in `ico/` and indexed in `icons.xml` (`model/icons/IconManager.as`).
- **Site icons** are fetched from `https://www.google.com/s2/favicons?domain=<domain>`.

## 5. PDF export

Code: `model/statistic/StatisticExporter.as`, `model/statistic/PDF.as` (PurePDF).

1. The export first flushes the current process and re-syncs project time.
2. It loads per-day statistics (`DataBase.getStatisticsByDay`).
3. It builds a PDF with these parts:
   - Header: creation date and working hours.
   - Total work / rest time and a coloured status bar for work, rest and idle.
   - Year / month / day anchors for navigation.
   - Each day with its work and rest totals and the applications in each group. Rest applications are omitted if **Export statistics of rest** is turned off.
   - Footer and page events.
4. The user chooses the save location (`browseForSave`). The export can be cancelled, and the clock pauses while it runs (`isPending`).

## 6. Notifications (toasts)

Code: `model/ToastManager.as`, `view/toast/*`.

A small toast window appears in the corner. Each toast closes after 15 s by default; clicking a toast restores the main window.

| Toast | Trigger |
|---|---|
| First launch / project | On every startup. Shows the current project name |
| Work reminder | Every *N* minutes of continuous Work, if enabled. Plays `sounds/alert_work.mp3` if sound is on |
| Rest reminder | Every *N* minutes of continuous Rest, if enabled. Plays `sounds/alert_rest.mp3` |
| Update available | 60 s after a newer version is detected. Stays for 60 s and links to the download |

## 7. System tray

Code: `view/SystemTray.as`.

- The tray icon changes with the mode: `assets/tray_icon_work.png`, `tray_icon_rest.png` or `tray_icon_idle.png`.
- The tooltip shows the current project and mode.
- The tray menu has these items:
  - Open
  - Work / Rest / Pause (enabled only in manual mode)
  - Projects submenu
  - Always on top
  - Rate
  - Report error
  - Visit website
  - Exit
- `Esc` minimises to the tray. If a secondary window is open, `Esc` closes it first.
- After an OS login (autorun), the app starts minimised to the tray.

## 8. Main-window context menu

Right-clicking the main window shows:

- Minimize
- Always on top
- About
- Visit website
- Report error
- Rate
- Exit

## 9. Settings

`view/setting/SettingContent.as`, persisted in `model/settings/Settings.as`.

| Setting | Default | Notes |
|---|---|---|
| Run at OS startup | on | `NativeApplication.startAtLogin` |
| Language | system (ru/ua), else en | ru / ua / en |
| Idle detection + target + delay | Pause, AIR default | Target: Pause or Rest; delay slider 1–120 min |
| Working hours | 24 h | Hours per "day" used when formatting long durations (1–24) |
| Sound | off | Toast sounds |
| Work reminder | off, 50 min | Slider up to 120 min |
| Rest reminder | off, 30 min | Slider up to 120 min |
| Export statistics of rest | on | Include rest apps in the PDF |
| Application colour | 0 | Hue shift of the whole UI (`SkinManager`, Tweener `_hue`) |
| Always on top | on | Applied to all windows |
| Window position | — | Saved on move. The window is reset to the screen centre if it falls outside the screens |

The **About** tab (`InfoContent`) shows the current version, update status, a website link, the developers (from `resources/developers.xml`) and the hotkey list.

## 10. Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Ctrl+P` | Open / close the projects panel |
| `Ctrl+N` | New project |
| `Ctrl+S` | Open / close statistics |
| `Ctrl+O` | Open / close settings |
| `Esc` | Close sub-windows, or minimise to the tray |
| `Alt+C` | Cycle the application colour tone in 30° steps (`KeyController`) |

## 11. Auto-update check

- On startup and on every date change, the app POSTs to the update URL in `resources/config.xml`, for example `https://motivateclock.org/download/update.xml`.
- It compares `versionNumber` and `versionLabel` with the app descriptor.
- If a newer version exists, it shows the update toast and help text with a download link.
- The update is a manual download; it is not installed silently.

## 12. Analytics and error logging

- **Google Analytics** (`GATracker`, account `UA-8935548-3`). Events:
  - `install`: on first launch.
  - `run`: once per day.
  - `error`: on uncaught errors, with the OS, version, message and stack trace.
- **Error log.** Uncaught errors are swallowed and appended to `errors.log` in the storage directory (`model/ErrorLog.as`).

## 13. Crash safety

- Projects that changed are saved every **2 seconds** (`ApplicationManager` save timer).
- On a normal exit:
  1. The current process is flushed to the database.
  2. Settings and the icon index are saved.
  3. Projects are saved, then the app exits.
- On an **emergency exit** (the activity helper process died), the current process's time goes to `temp.dat`. It is merged into the database on the next launch (`TempSaveProcessCommand` / `LoadTempProcessCommand`).
