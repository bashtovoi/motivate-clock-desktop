# Architecture

## Overview

The app uses a hand-rolled **MVC** design with **commands** and AS3 events. No framework is involved.

```
            ┌──────────────────────── Main (document class) ────────────────────────┐
            │                                                                        │
       new Model()                     new View(model, stage)          new Controller(model, stage)
            │                                  │                                │
  sub-models & singletons             listens to Model events,          StartupCommand → feature controllers
  (ProjectsModel, DataBase,           dispatches ViewEvents on           listen to Model + View events,
   ClockModel, Settings, …)           the stage                          mutate the Model, run Commands
```

- **Model** (`Model.as`) is the root model and a service locator. It exposes the sub-models and dispatches `ModelEvent`s such as `TYPE_CHANGE`, `INITIALIZE_STATE_CHANGE`, `NEW_PROCESS_READY` and `APP_PENDING_CHANGE`.
- **View** (`View.as` and `view/*`) reads the model directly and listens for its events. User actions go out as `ViewEvent`s on the stage. Sub-windows re-dispatch their events to the main stage.
- **Controllers** (`controller/*`) each handle one concern. They are created after projects load and hold no state that matters elsewhere.
- **Commands** (`controller/command/*`) are single-use operations implementing `ICommand.execute()`.
- **Services** (`services/*`) wrap the native helper processes and the socket. They push data through callbacks set by `initializeHandlers()`.
- **Singletons**: `ProjectsModel`, `DataBase`, `ErrorLog`, `UpdaterModel`, `IconManager`, `RunningProcessService`, `SystemTray`, `DateWatcher`, `ProcessesWindow`, `SettingWindow`, `ConfirmAlert`, `Hint`. They are enforced with a private flag or a private class.

## Startup sequence

1. **`Main`** sets the stage scale/align and creates `Model`, `View` and `Controller`.
2. **`Model()`** loads settings (`settings_16.dat`) and languages (`text.xml`), then creates the clock, the projects model, toasts, the updater, the DB singleton and the application manager.
3. **`StartupCommand`**:
   1. Initialises Tweener's `ColorShortcuts` and sets `autoExit = false`.
   2. Hooks `ErrorLog` to uncaught errors.
   3. Sets `isFirstLaunch` if `statistic.db` does not exist yet.
   4. Runs `InitializeUICommand`: `loadBytes(ui.swf)` into the current domain, then registers the Myriad Pro font. This sets `initializeState = INITIALIZE_UI_COMPLETE`.
   5. Restores the saved window position.
4. **`View`** reacts to `INITIALIZE_UI_COMPLETE`. It builds the clock, toggle, statistics and projects panels, the alert, toasts, the process and settings windows, and the tray. It starts `DateWatcher`, minimises to the tray (after an OS login or if the window was minimised last time) or restores the window, and shows the first-launch toast.
5. **`Controller`** reacts to `INITIALIZE_UI_COMPLETE` with `projectModel.load()`. This opens SQLite, creates the tables and reads the projects. If there are none, it creates the manual-mode project and the first project. This sets `INITIALIZE_PROJECTS_COMPLETE`.
6. **`Controller`** then creates `KeyController` and the feature controllers: Analytics, Project, Process, Service, Clock, Updater, Statistics, TimeSync and Toast.
7. When the DB is ready, `LoadTempProcessCommand` merges any `temp.dat` left by an emergency exit.

## Time-tracking pipeline

```
MotivateClockActivity.exe ──stdout──► ActiveProcessService ─┐
                                                           ├─► ServiceController ──► Model.updateCurrentProcess(process)
Browser extension ──TCP :1257 JSON──► BrowserExtensionService ┘     (browser? wait 650 ms for tab URL)
                                                                         │
                                                         ModelEvent.NEW_PROCESS_READY
                                                                         ▼
                                    ProcessController: SaveProcessCommand(previous) → processModel.setCurrentProcess(new)
                                                                         │  (marks isMarked if path is in project list)
                                                         ModelEvent.PROCESS_CHANGE
                                                                         ▼
                                    Controller: auto project? currentType = isMarked ? WORK : REST
```

On every **`CLOCK_TICK`** (about 1 s):

- `ClockController` adds the elapsed seconds to `project.workTime`, `restTime` or `idleTime`, depending on `currentType`.
- `ProcessController` adds the elapsed seconds to the current process unless the mode is Pause.
- `StatisticsController` updates the live row of the open statistics list.

### Persisting process time

- `SaveProcessCommand` calls `DataBase.syncProcess(projectId, today, path, name, time)`. That is an upsert: it adds to the existing row for (project, date, path, name) or inserts a new one. The in-memory counter then resets to 0.
- It runs on every process switch, before PDF export, during a time re-sync and on exit.

### Keeping project totals consistent

- `ProjectSyncCommand` recomputes the totals from the DB for auto projects:
  - `workTime` is the sum of time over the project's marked paths.
  - `restTime` is total time minus `workTime`.
- It runs on project change, before statistics are viewed for another project, before export, and 2 s after the process list is edited (`TimeSyncController`).
- During this the model is `isPending`, and the clock stops so time is not double-counted.

### Idle handling (`Controller`)

- On `USER_IDLE`: `currentType` becomes `settings.idleTarget`. If the target is Rest, a synthetic `Desktop` process becomes current.
- On `USER_PRESENT`: `currentType` goes back to `previousType`.

### Saving and exit (`ApplicationManager`)

- Every 2 s, `projectModel.save()` writes the dirty projects (`UPDATE projects …`).
- On exit:
  1. Dispatches `APPLICATION_EXITING`. `ProcessController` saves the current process, or writes `temp.dat` if this is an emergency.
  2. Stops the timers and saves settings and icons.
  3. Hides the tray.
  4. Saves the projects and exits on `PROJECT_SAVE_COMPLETE`.
- An emergency exit happens when the activity helper process exits unexpectedly.

## Statistics flow

1. `StatisticView` dispatches `StatisticViewEvent.STATISTIC_SELECT` with (projectId, category).
2. `StatisticsController` sets the model's current project and category, then calls `DataBase.getStatistics(...)`. For the Work and Rest categories the query is filtered with `appPath IN / NOT IN` the project's marked paths.
3. On `DB_STATISTICS_LOAD_COMPLETE`, each process gets a type and an `isMarked` flag, and the list is set on `StatisticsModel` (sorted by time).
4. If the selected project is the current one, the live current process is added or updated and bubbles up the list as its time grows.

## Event catalogue (main ones)

| Event | Dispatcher | Meaning |
|---|---|---|
| `ModelEvent.INITIALIZE_STATE_CHANGE` | Model | UI loaded / projects loaded |
| `ModelEvent.TYPE_CHANGE` | Model | Work/Rest/Pause changed |
| `ModelEvent.NEW_PROCESS_READY` | Model | Services reported a new foreground process |
| `ModelEvent.CLOCK_TICK` | ClockModel | Elapsed seconds (`timeRange`) |
| `ModelEvent.PROJECT_CHANGE` | ProjectsModel | Current project switched |
| `ModelEvent.PROCESS_CHANGE / PROCESS_ADD / PROCESS_REMOVE` | ProcessModel | Current process / work list changed |
| `ModelEvent.PROJECT_TIME_CHANGE`, `PROJECT_MODE_CHANGE` | Project | Time or auto/manual mode changed |
| `ModelEvent.APP_PENDING_CHANGE` | Model | Long operation running; clock paused |
| `ModelEvent.PROJECT_SYNC_COMPLETE`, `PROCESS_SYNC_STATE_CHANGE` | Model | Sync finished |
| `ModelEvent.APPLICATION_EXITING` | ApplicationManager | Shutdown (with `isEmergency`) |
| `ModelEvent.UPDATE_AVAILABLE` | UpdaterModel | Newer version found |
| `ModelEvent.SETTING_CHANGE` | SettingsManager | Setting set via `setProperty` |
| `McEvent.DB_LOADED`, `PROJECTS_OBTAINED`, `LOAD_COMPLETE`, `LANGUAGE_CHANGED`, `PDF_SAVED`… | various | Lifecycle events |
| `DBEvent.*` | DataBase | Async query results |
| `ViewEvent.*` | View | User intents: process add/remove, export, reset, install extension, etc. |
| `DateWatcherEvent.CHANGE` | DateWatcher | Calendar day changed (checked hourly). Triggers the update check and the daily analytics event |

## Theming

- `SkinManager` keeps a list of registered display containers and tweens their `_hue` (Tweener `ColorShortcuts`) to `settings.colorTone`.
- The tone changes from the Settings slider or with `Alt+C`.
