# Project Structure

```
motivate-clock-desktop/
├── build.xml               Ant build: start (debug run) and package (installer) targets
├── build.properties        Paths, app name/version, signing and update URL settings
├── README.md / LICENSE     Project readme, MIT license
├── .github/FUNDING.yml     GitHub sponsorship config
├── certs/dev_cert.p12      Development code-signing certificate (password "dev")
├── tools/signtool.exe      Windows Authenticode signing tool
├── misc/logo-wide.png      Readme logo
├── src/                    ActionScript 3 source code (see below)
├── vendor/                 Precompiled third-party SWC libraries
├── static/                 Files copied next to the app at runtime (bundled assets)
├── resources/              Files embedded into the SWF or used by installers
├── templates/              Templates with placeholders filled in by Ant
├── xfl/motivate_clock/     Adobe Animate (XFL) source of the UI skin -> static/ui.swf
└── docs/                   This documentation
```

Ignored by git: `/dist` (installers), `/debug` (debug run folder), `/sdk` (local Flex/AIR SDK), `/resources/config.xml` (generated), `.idea`, `*.iml`.

## `vendor/`: libraries

| SWC | Purpose |
|---|---|
| `purePDF.swc` | PDF generation for the statistics export |
| `tweener.swc` | Tweening (panel slides, hue colour shift via `ColorShortcuts`) |
| `as3_jpeg_wrapper.swc` | JPEG encoding (used by PurePDF images) |
| `analytics_flash.swc` | Google Analytics for Flash (`GATracker`) |
| `servicemonitor.swc` | AIR network service monitor |

## `static/`: runtime assets

| Path | Purpose |
|---|---|
| `ui.swf` | Compiled UI library: movie clips with `gfx_*` linkage names and the Myriad Pro font. It is embedded via `ResourceCommon.UI` |
| `text.xml` | All localised strings (ru, ua, en), loaded from the app directory at runtime |
| `assets/tray_icon_*.png` | Tray icons per mode |
| `icons/16х16.png … 128х128.png` | Application icons. The `х` in the file names is **Cyrillic** |
| `sounds/alert_work.mp3`, `alert_rest.mp3` | Reminder sounds |
| `utils/*.exe` | Native Windows helpers (activity, processes, browsers). Windows build only |

## `resources/`

| Path | Purpose |
|---|---|
| `config.xml` | Generated from `templates/config.xml` by Ant. Holds the update descriptor URL. Embedded |
| `links.xml` | Per-language external links: home page, extension stores, rating, bug report. Embedded |
| `developers.xml` | Developer names and links shown in About. Embedded |
| `images/*.png` | Toast, browser-button, slider and swap-button bitmaps (embedded via `ResourceImage`). Also `icon.ico` (installer) and `dmg-background.png` |
| `fonts/` | Myriad Pro and Tahoma font files (design and PDF use) |
| `description/description.{en,ru,uk}.txt` | Text shown by the Windows installer before installation |

## `templates/`

| File | Placeholders | Output |
|---|---|---|
| `motivateclock-app.xml` | `VERSION`, `VER_LABEL` | AIR application descriptor |
| `config.xml` | `UPDATE_DESCRIPTOR` | `resources/config.xml` |
| `update.xml` | `VERSION`, `VER_LABEL`, `DOWNLOAD_URL` | `dist/update.xml`, uploaded to the update server |
| `installer.iss` | `VERSION`, `APP_DIR`, `BUNDLE_DIR` | Inno Setup script for `motivateclock.exe` |

## `src/org/motivateclock/`: source packages

About 140 classes and about 19k lines in total.

### Root

| Class | Role |
|---|---|
| `Main` | Document class. Creates `Model`, `View`, `Controller` |
| `Model` | Root model and service locator. Holds the sub-models, the current mode (`currentType`), the init state and the pending/sync flags |
| `View` | Builds the main window UI after the skin loads. Wires the tray, windows, context menu, resize and drag |
| `Controller` | Runs startup. Initialises the controllers after projects load. Handles idle/present and auto work/rest switching |

### `controller/`

| Class | Responsibility |
|---|---|
| `ClockController` | Adds every clock tick to the current project's work/rest/idle time |
| `ProcessController` | Sets the current process, adds tick time to it, saves it on switch or exit, adds/removes project processes from the UI |
| `ProjectController` | Re-syncs project time on project change. Updates auto/manual mode on process add/remove |
| `ServiceController` | Starts the native services and the extension socket. Merges browser + extension data into the current process |
| `StatisticsController` | Loads statistics for the selected project/category. Keeps the live current process. Handles reset and PDF export/cancel |
| `TimeSyncController` | Waits 2 s after the process list changes, then saves and re-syncs. Pauses the clock while pending |
| `ToastController` | Activity reminder logic (tick handler currently disabled) |
| `KeyController` | `Alt+C` colour cycling on every window |
| `AnalyticsController` | Install / daily run / error analytics events |

### `controller/command/`: `ICommand` implementations

| Command | Purpose |
|---|---|
| `StartupCommand` | Disables autoExit, hooks the error log, detects first launch, loads the UI, restores the window position |
| `InitializeUICommand` | `Loader.loadBytes` of the embedded `ui.swf` into the current ApplicationDomain. Registers the font |
| `ProjectSyncCommand` | Recomputes a project's work time (marked processes) and rest time (total minus work) from the DB |
| `SaveProcessCommand` | Writes the current process time for today into the DB, then clears the in-memory counter |
| `TempSaveProcessCommand` / `LoadTempProcessCommand` | Emergency persistence to `temp.dat` and its recovery |
| `BrowserListParseCommand` | Parses installed-browser output into `BrowserVO`s |
| `InstallExtensionCommand` | Launches the browser with the extension store URL (or opens it in the default browser) |
| `UpdateHelpTextCommand` | Chooses the contextual help text in the projects panel |

### `model/`

| Class | Responsibility |
|---|---|
| `ApplicationManager` | Window lifecycle: minimise/tray/restore, always-on-top, window position, 2 s autosave, orderly and emergency exit |
| `ClockModel` | 1 Hz timer that emits `CLOCK_TICK` with the real elapsed seconds |
| `ProjectsModel` (singleton) | Project list, current project, create/remove/reset/rename, load/save via `DataBase` |
| `Project` | Name, id, dates, work/rest/idle time, `isAuto`, `isCurrent`, dirty flag, owns a `ProcessModel` |
| `ProcessModel` | The project's marked processes (work list) plus the current process. Serialises to `type$name$path\t…` |
| `Process` | Tracked app/site: type, name, path, time, `isMarked`. Its id is the path without non-word characters |
| `StatisticsModel` | Statistics list for the view, sorted by time, with a live current process |
| `ToastManager` | Toast scheduling, sounds, toast content |
| `NotificationModel` | Generic notification dispatcher |
| `LanguagesManager` | Loads `text.xml`, chooses the language, `getText(id)`, `getLink(id)` |
| `SkinManager` | Applies the hue tone to registered display objects |
| `ErrorLog` (singleton) | Catches uncaught errors, writes `errors.log`, re-dispatches them for analytics |
| `GoogleAnalytics` | `IAnalytics` wrapper over `GATracker` |
| `settings/Settings`, `SettingsManager` | AMF-serialised user settings |
| `statistic/DataBase` (singleton) | Async SQLite access (see [data-storage.md](data-storage.md)) |
| `statistic/StatisticExporter`, `PDF`, `StatDay` | PDF export pipeline |
| `update/UpdaterController`, `UpdaterModel` | Update-descriptor polling and version comparison |
| `icons/IconManager`, `Icon` | App/site icon resolution and caching |
| `vo/ProcessVO`, `vo/BrowserVO` | Value objects from services |

### `services/`: `IService` implementations

| Class | Source |
|---|---|
| `ActiveProcessService` | `utils/MotivateClockActivity[64].exe`: streams foreground window changes |
| `BrowserExtensionService` | TCP `ServerSocket` on `127.0.0.1:1257`: active tab URL/title from extensions |
| `BrowsersService` | `utils/MotivateClockBrowsers.exe`: list of installed browsers |
| `RunningProcessService` (singleton) | `utils/MotivateClockProcesses[64].exe` → `processes.dat`: running apps for the process picker |

### `view/`

| Path | Contents |
|---|---|
| `ClockView`, `clock/*` | Flip clock, status line, mode toggle buttons |
| `ProjectsView`, `projects/*` | Projects panel, list, item renderer, creator, label editor, icon slider, help |
| `projects/setting/*` | Process picker (apps), internet sites editor, browser-extension install buttons |
| `StatisticView`, `statistic/*` | Statistics panel, menu, list, item renderer, pie chart |
| `setting/*` | Settings and About content, checkbox with slider/combo, slider |
| `windows/*` | `AbstractWindow` (NativeWindow base), `ProcessesWindow`, `SettingWindow`, `WindowBackground` |
| `toast/*` | `ToastWindow`, `Toast` |
| `alert/*` | Modal `ConfirmAlert` |
| `components/*` | Scroll, GridScroll, ComboBox, HSelector, Hint, TextArea, SmartContainer |
| `content/*` | Tabbed content toggle used by the windows |
| `SystemTray`, `NotificationView`, `AbstractListView` | Tray icon and menu, notifications, list base |

### Other packages

| Package | Contents |
|---|---|
| `enum/` | String/int constants: modes (`TypeEnum`), process types, browsers, files, text keys, links, states, setting keys, etc. |
| `events/` | Custom events: `ModelEvent`, `ViewEvent`, `McEvent`, `DBEvent`, `StatisticViewEvent`, `ProjectEvent`, `NotificationEvent`, `StorageEvent`, `DateWatcherEvent`, `ErrorEvent`, `ActionCounterEvent` |
| `interfaces/` | `IProcess`, `IProject`, `IProcessModel`, `IStatisticsModel`, `IService`, `ICommand`, `IAnalytics`, `IToast`, `ISkinManager`, `IContent`, `IDisposable`, `IIconViewer`, `INotification*` |
| `resource/` | `ResourceCommon` (embedded ui.swf and XMLs), `ResourceImage` (embedded PNGs), `ResourceLib` (skin linkage names) |
| `utils/` | `DateWatcher` (day-change events, `date.dat`), `AccurateTimer`, `Storage` (async file I/O), `TimeUtils`, `URIUtil`, `RegularUtils`, `TextFieldUtil`, `DisplayObjectUtils`, `ActionCounterUtil` |

## `xfl/motivate_clock/`

The Adobe Animate project (uncompressed XFL) that contains the visual skin: backgrounds, buttons, flip digits, list renderers and the embedded font. Publishing it produces `static/ui.swf`. Code finds symbols by the linkage names listed in `resource/ResourceLib.as` (for example `gfx_clock_view`, `gfx_statistic_view`).
