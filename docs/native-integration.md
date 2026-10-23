# Native Integration

AIR cannot see other applications' windows by itself. The app therefore starts small native Windows executables through `NativeProcess` (this needs the `extendedDesktop` profile) and listens for browser extensions on a local TCP socket.

The helpers ship in `static/utils/`. They are binaries only; their source code is not in this repository. Only the Windows build includes them (`ASSETS_WIN` in `build.properties`).

## Helper executables

The 64-bit variant is chosen when `Capabilities.supports64BitProcesses` is true.

### `MotivateClockActivity.exe` / `MotivateClockActivity64.exe`

Used by `services/ActiveProcessService.as`.

- A long-running process that writes a line to **stdout** (in **windows-1251**) every time the foreground window changes:
  ```
  <type>$<path-or-url>$<label>$<title-or-browserPath>\n
  ```
  - `type` is `app` or `site` (`ProcessTypeEnum`).
  - For `app`, the path is cut after the extension (`.exe`). If the label is `-` or the path is a `.jar`, the label is derived from the file name.
  - For `site`, the URL is reduced to its domain. An empty URL becomes `tab:blank`.
- Partial chunks are buffered until a newline arrives. Repeated reports of the same path are ignored.
- If a file named `debugactivity.txt` exists in the app directory, the helper is started with `/debuglog`.
- **If the helper exits, the app performs an emergency exit** (`ApplicationManager.exit(true)`).

### `MotivateClockProcesses.exe` / `MotivateClockProcesses64.exe`

Used by `services/RunningProcessService.as`.

- Runs on demand: when the process picker opens or the user clicks refresh. Its working directory is the storage directory.
- When it exits, the app reads `processes.dat` (windows-1251). Records end with `$\r\n` and fields are separated by tabs: `path \t ? \t description`.
- The list is cleaned up as follows:
  1. Arguments are stripped from paths, and paths are lower-cased.
  2. Duplicates are dropped.
  3. System and background processes on a hard-coded ignore list are dropped (`svchost.exe`, `dwm.exe`, `conhost.exe`, the helpers themselves, …).
  4. Missing names are derived from the file name.
  5. The list is sorted by name.
- `firefox`, `opera`, `iexplore` and `chrome` are typed as `browser`.
- Debug flag file: `debugprocesses.txt`.

### `MotivateClockBrowsers.exe`

Used by `services/BrowsersService.as`.

- Runs once at startup and writes the installed browsers to stdout (UTF-16 "unicode"). Each line is `x|<Browser name>|<"path to exe">`.
- `BrowserListParseCommand` keeps only executables that exist, removes duplicates by file name, and stores the result in `Model.browserList`.
- The list is used to open the extension store **in that specific browser** (`InstallExtensionCommand`).

## Browser extension protocol

Used by `services/BrowserExtensionService.as`.

- The app listens with an AIR `ServerSocket` on **`127.0.0.1:1257`**.
- Extensions (Chrome Web Store id `binhgmklnnecdadhiodcjcnhpbnknomg`, Firefox add-on `motivate-clock-extension`, Opera add-on `motivate-clock-extension`) connect and send UTF-8 JSON:
  ```json
  {"url": "https://example.com/page", "title": "Page title"}
  ```
- Data is buffered until the accumulated text ends with `}`. Only the last `\n`-separated line is used.
- The URL is reduced to a domain by `URIUtil.getDomainFromURI` and becomes a `site` process. The `browserPath` is the browser the activity helper reported last.
- **Merge logic** in `ServiceController`:
  - When the activity helper reports a browser executable, the app starts a 650 ms timer.
  - If extension data arrives first, the site is tracked.
  - If the timer fires first, the browser application itself is tracked.

### Extension store links

The links are in `resources/links.xml`, per language: `CHROME_EXTENSION`, `FIREFOX_EXTENSION` and `OPERA_EXTENSION`. Yandex Browser and the Opera launcher use the Opera store link.

## macOS

The macOS package (`ASSETS_MAC`) does **not** include `utils/`. On macOS:

- The activity, process and browser services cannot start; their `NativeProcess.start` calls fail silently inside `try/catch`.
- Automatic per-application tracking and the process picker are therefore not available.
- The browser-extension socket still works, along with manual mode, the tray/dock icon and the rest of the UI.
