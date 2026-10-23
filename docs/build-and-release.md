# Build & Release

## Prerequisites

- **Apache Flex SDK merged with the Harman AIR SDK.** The descriptor namespace is `http://ns.adobe.com/air/application/50.0`. Ant needs `flexTasks.jar`, `mxmlc`, `adt.jar` and `adl` from it.
- **JDK** to run Ant and ADT.
- **Apache Ant**.
- Windows installers: **Inno Setup 6** (`ISCC.exe`).
- macOS installers: **[create-dmg](https://github.com/andreyvit/create-dmg)** on `PATH`.

## Configuration: `build.properties`

| Property | Meaning |
|---|---|
| `FLEX_HOME` | SDK path (default `./sdk`, which is git-ignored) |
| `SRC_DIR`, `MAIN_CLASS`, `VENDOR_DIR`, `STATIC_DIR`, `TEMPLATES_DIR`, `RESOURCES_DIR` | Source layout |
| `APP_NAME` / `APP_NAME_LABEL` | `motivateclock` / `Motivate Clock` |
| `APP_VERSION` / `APP_VERSION_LABEL` | `1.6.4` / `1.6.4 Beta 1`. Both are written into the descriptor and update.xml |
| `DIST_DIR` / `DEBUG_DIR` | Output folders `./dist` and `./debug` |
| `ASSETS_WIN` / `ASSETS_MAC` | Static assets bundled per OS. The Mac list omits `utils` |
| `UPDATE_URL` | `https://motivateclock.org/download`. Base for `update.xml` and the installer download |
| `WIN_INSTALLER_DIR` | Inno Setup install directory |
| `KEYSTORE` / `STOREPASS` | PKCS#12 certificate for AIR packaging and Authenticode (default: dev cert, password `dev`) |
| `SIGN_TOOL`, `TIMESTAMP_SERVER`, `PUBLISHER_NAME`, `PUBLISHER_URL` | Windows `signtool` options |

## Ant targets

Both public targets pick the OS automatically through the `isMac` / `isWindows` conditions.

### `start`: debug run

1. `serve.debug.dir` cleans `debug/`, copies all of `static/` into it, and generates `debug/motivateclock-app.xml` and `resources/config.xml`.
2. `compile` runs `mxmlc` in debug mode (`air-config.xml`, plus `src/` and the vendor SWCs) and writes `debug/motivateclock.swf`.
3. It launches `adl debug/motivateclock-app.xml`.

### `package`: release installer

1. Cleans `dist/`.
2. Generates the app descriptor (into `dist/temp`), `resources/config.xml` and `dist/update.xml`.
3. Compiles a release `motivateclock.swf`.
4. `adt -package -target bundle` creates a captive-runtime bundle that includes the per-OS assets.
5. Builds the installer:
   - **Windows:** fills in `templates/installer.iss` and runs `ISCC`, which produces `dist/motivateclock.exe`. The installer supports English, Russian and Ukrainian, an optional desktop icon, and a Program Files install. It is then signed with `signtool`.
   - **macOS:** `create-dmg` with `resources/images/dmg-background.png` produces `dist/motivateclock.dmg`. `sign.dmg` is an empty placeholder.
6. Deletes `dist/temp`.

## Releasing a new version

1. Bump `APP_VERSION` (and `APP_VERSION_LABEL`) in `build.properties`.
2. If the UI skin changed, re-publish `xfl/motivate_clock` to `static/ui.swf` from Adobe Animate.
3. Run `ant package` on each target OS, using a production certificate instead of `certs/dev_cert.p12`. The AIR app id `MotivateClock` and the certificate must stay consistent for updates to work.
4. Upload `motivateclock.exe` (and `.dmg`) and `update.xml` to `UPDATE_URL`.
5. Installed clients find `update.xml` on startup or on the next day change, and offer the download.
6. Tag the commit (the existing tags follow `v.1.6.x`).

## Localisation workflow

- UI strings live in `static/text.xml` under `<LANGUAGE ID="ru|ua|en">`, with entries like `<TEXT ID="KEY"><![CDATA[…]]></TEXT>`.
- To add a string:
  1. Add the key to `enum/TextKeyEnum.as`.
  2. Add the text in all three languages.
- A missing key renders as the key itself.
- Plural forms are comma-separated lists (for example `DAY`, `HOUR`, `MINUTE`), resolved by `TimeUtils.getDeclensionNumberName`.
- Per-language links are in `resources/links.xml`. Installer descriptions are in `resources/description/`.
- To add a language:
  1. Add a `<LANGUAGE>` block.
  2. Add a links block.
  3. Extend the first-launch detection in `LanguagesManager`, which currently recognises only `ru` and `ua`.
