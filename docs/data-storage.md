# Data & Storage

All user data lives in the AIR **application storage directory** (`File.applicationStorageDirectory`). Its location:

- Windows: `%APPDATA%\MotivateClock\Local Store\`
- macOS: `~/Library/Application Support/MotivateClock/Local Store/`

## Files

| File | Written by | Format | Contents |
|---|---|---|---|
| `statistic.db` | `DataBase` | SQLite (async connection) | Projects and per-day usage statistics. Its absence means first launch |
| `settings_16.dat` | `SettingsManager` | AMF3 object (`registerClassAlias("SettingsAlias", Settings)`) | User settings. The `_16` suffix versions the format |
| `icons.xml` | `IconManager` | XML `<ICONS><ICON PROCESS="path" ICON="icon_N.png"/></ICONS>` | Process-path to cached-icon index |
| `ico/icon_N.png` | `IconManager` | PNG | Extracted application icons |
| `temp.dat` | `TempSaveProcessCommand` | Text line `projectId\tdate\tname\tpath\ttime` | Unsaved process time after an emergency exit. Merged into the DB and deleted on the next start |
| `date.dat` | `DateWatcher` | AMF `Date` | Last seen calendar day, used for day-change detection |
| `processes.dat` | `MotivateClockProcesses.exe` | Text, windows-1251, records separated by `$\r\n`, fields by `\t` | Running applications for the process picker |
| `errors.log` | `ErrorLog` | Appended UTF blocks | Uncaught errors with date, version and stack |

## SQLite schema

Both tables are created in `DataBase.openHandler` with `CREATE TABLE IF NOT EXISTS`. There are no indexes and no migrations.

```sql
CREATE TABLE statistic(
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    projectId TEXT,      -- Project.id (ms timestamp string, or "0" for manual mode)
    usedDate  DATE,      -- calendar day (from Date.toDateString())
    appPath   TEXT,      -- lower-cased exe path, domain, or "desktop"
    appName   TEXT,      -- display label
    time      INTEGER    -- seconds
);

CREATE TABLE projects(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    projectId    TEXT,
    name         TEXT,
    creationDate DATE,
    isCurrent    INTEGER,
    workTime     INTEGER,  -- seconds
    restTime     INTEGER,  -- seconds
    isAuto       INTEGER,  -- only read on load; inserts and updates do not write it
    applications TEXT      -- serialised work list: "type$name$path\t" repeated
);
```

### Key queries (`model/statistic/DataBase.as`)

| Method | What it does |
|---|---|
| `getProjects()` | `SELECT … FROM projects`, mapped to `Project` via `itemClass` |
| `addProject` / `updateProject` / `removeProject` | CRUD on `projects` by `projectId` |
| `syncProcess(project, date, path, name, time)` | Selects the row for (project, date, path, name). Adds `time` to it if found, otherwise inserts a new row |
| `getProjectTime(id)` | `total(time)` for the project |
| `getProcessesTime(id, list)` | `total(time)` where `appPath IN (list)`: the project's work time |
| `getStatistics(id, category, range, list)` | Rows grouped by `appPath` with `total(time)`. Optional `IN` / `NOT IN` filter for Work/Rest |
| `getStatisticsByDay(id)` | Rows grouped by `(usedDate, appName)` with `STRFTIME('%Y-%m-%d')`, for the PDF |
| `getStatisticsByDate(start, end, id)` | Date-range aggregate. Currently unused, and its result handler is empty |
| `resetProjectStatistic(id)` | `DELETE FROM statistic WHERE projectId = @id` |

## Identifiers

- **Project id:** `new Date().getTime().toString()` at creation. The manual-mode project always has id `"0"`.
- **Process id:** the process path with all non-word characters removed (`/\W/g`). It is used as a map key for "is this path marked".
- **Process path:**
  - Applications: the lower-cased executable path. Arguments are stripped after the extension.
  - Sites: the domain only.
  - Idle-as-rest: the special value `desktop`.
- A path without a `\` (other than `desktop`) is classified as a site in statistics.

## Settings fields (`model/settings/Settings.as`)

`restState`, `workState`, `restTime` (min), `workTime` (min), `soundEnabled`, `language`, `alwaysInFront`, `closeToTray`, `mainWindowState {x, y, display}`, `idleTarget`, `exportRestStat`, `workingHours`, `colorTone`, `version`, `versionNumber`.

These are derived properties rather than stored ones:

- `autorun` maps to `NativeApplication.startAtLogin`.
- `idleTime` maps to `NativeApplication.idleThreshold / 60`.
- `idleState` and `appHeight` are effectively constant (their setters are empty).
