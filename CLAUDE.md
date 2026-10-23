# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

Motivate Clock is a desktop time-tracking app written in **ActionScript 3** on **Adobe AIR** (Harman AIR SDK, `extendedDesktop` profile). It tracks the foreground app or website and counts the time as work, rest or pause for each user project. Detailed docs are in `docs/`. Start with `docs/README.md`, then:

- `docs/architecture.md`: MVC + commands, startup sequence, tracking pipeline, events
- `docs/project-structure.md`: folder and package map
- `docs/data-storage.md`: SQLite schema and storage files
- `docs/native-integration.md`: Windows helper executables and the browser-extension socket (`127.0.0.1:1257`)
- `docs/build-and-release.md`: Ant targets, packaging, localisation
- `docs/known-issues.md`: known gaps and tech debt

Update the relevant doc whenever behaviour, structure or the build changes.

## Build & run

Builds use Apache Ant with a Flex SDK merged with the AIR SDK. Set `FLEX_HOME` in `build.properties` (the default `./sdk` is git-ignored).

- `ant start`: compile in debug mode into `debug/` and launch with `adl`
- `ant package`: build the release installer into `dist/` (Inno Setup on Windows, create-dmg on macOS)

There are no automated tests or linter. To verify a change, compile it with `ant start`. Automatic app tracking only works on Windows, because the native helpers in `static/utils/` are `.exe` files.

## Code layout & conventions

- Source root: `src/org/motivateclock/`. Entry point: `Main.as`. It creates `Model`, `View` and `Controller`.
- **Model**: `Model.as` is a service locator for the sub-models in `model/`. State changes are announced with `ModelEvent`s.
- **View** (`view/`): reads the model and reports user intents as `ViewEvent`s on the stage. Visual symbols come from the embedded `static/ui.swf`, built from `xfl/motivate_clock/` in Adobe Animate. Their linkage names are listed in `resource/ResourceLib.as`.
- **Controllers** (`controller/`): one concern each. **Commands** (`controller/command/`) implement `ICommand.execute()`.
- **Services** (`services/`): implement `IService` and wrap `NativeProcess` or `ServerSocket`.
- Constants go in `enum/`. Custom events go in `events/`. Interfaces go in `interfaces/`.
- **Style:**
  - 4-space indentation, with braces on their own line (Allman style).
  - Private members are prefixed with `_`.
  - Event handlers are named `<source>_<event>Handler` or `<event>Handler`.
  - Singletons expose `getInstance()`.
  - Match the surrounding code.
- **UI strings:**
  - Never hard-code user-visible text.
  - Add a key to `enum/TextKeyEnum.as` and its text for **all three languages** (`ru`, `ua`, `en`) in `static/text.xml`.
  - Per-language URLs live in `resources/links.xml`.
- **Generated files:** `resources/config.xml` is generated from `templates/config.xml`. Do not edit it by hand.
- **Database:** use parameter binding for new SQL in `model/statistic/DataBase.as`. All DB access is asynchronous and event-driven (`DBEvent`).
- **Version:** bump `APP_VERSION` and `APP_VERSION_LABEL` in `build.properties` only.

## Commits

Follow **[Conventional Commits](https://www.conventionalcommits.org/)**:

```
<type>(<optional scope>): <short imperative summary>

<optional body>

<optional footer, e.g. "Closes #23" or "BREAKING CHANGE: ...">
```

- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- **Scope:** optional, for the affected area, e.g. `feat(statistics): …`, `fix(tracking): …`, `build(installer): …`, `docs: …`.
- **Summary:** lower-case and imperative, with no trailing period, kept to 72 characters or fewer.
- **Issues:** reference GitHub issues in the footer (`Closes #N`).
- **Branches:** use `feature/<issue>-<slug>` or `fix/<issue>-<slug>` off `master`.
