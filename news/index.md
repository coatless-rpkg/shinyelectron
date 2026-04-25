# Changelog

## shinyelectron 0.2.0

### App types and autodetection

- Python Shiny is now supported alongside R Shiny. `app_type` takes
  `"r-shiny"` or `"py-shiny"`, with `NULL` (default) meaning autodetect
  from the files in `appdir`.
  [`detect_app_type()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/detect_app_type.md)
  resolves `app.R`, `ui.R` + `server.R`, or `app.py`; ambiguous layouts
  abort with a pointer to the multi-app-suites workflow.
- `export(appdir, destdir)` with no other arguments now works for the
  common case.

### Runtime strategies

- Five strategies, all legal with both languages: **shinylive** (the
  default, compiles to WebAssembly and runs in-browser), **bundled**,
  **system**, **auto-download**, and **container**.
- Bundled embeds a portable R or Python runtime inside the Electron app
  for zero-dependency distribution.
- Auto-download fetches the runtime on first launch and caches it
  locally.
- Container runs apps inside Docker or Podman for full environment
  isolation.
- The older `app_type = "r-shinylive"` and `"py-shinylive"` values are
  still accepted with a deprecation warning of class
  `shinyelectron_deprecated_app_type`; they translate to the canonical
  language plus `runtime_strategy = "shinylive"`. Pairing a legacy type
  with a non-shinylive strategy is an error. The shim will be removed in
  a future release.

### Multi-app suites

- Bundle multiple Shiny apps into a single Electron shell with a
  launcher UI.
- Configure via `_shinyelectron.yml` with an `apps` array; each app
  entry may carry its own `runtime_strategy`, so a suite can mix (for
  example) one shinylive app with a bundled R app.
- Python suites read dependencies from a single suite-root
  `requirements.txt`.

### Config file

- `build.type` may be omitted; autodetection runs at build time.
- `build.runtime_strategy: "shinylive"` is accepted alongside the other
  four strategies.
- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  writes a template that leaves `build.type` commented out and lists all
  five strategies.

### Lifecycle UI

- New lifecycle splash screen with progressive status updates during
  startup.
- Backend stderr is parsed and surfaced in the splash (package loading,
  font downloads, server status) so users see what’s happening instead
  of a frozen screen.
- Port allocation uses OS-assigned ports via `findAvailablePort()` to
  prevent collisions when multiple apps run simultaneously.
- Splash and preloader gain working knobs in `_shinyelectron.yml`:
  `splash.enabled` toggles the splash state, `splash.duration` sets a
  minimum display time before transitioning, `splash.background` and
  `preloader.background` override the lifecycle window background, and
  `preloader.style` picks the loading indicator (`spinner`, `bar`, or
  `dots`).

### Bug fixes

- `auto_download` and `auto_install` were rendered as R-style `TRUE` /
  `FALSE` in the generated `main.js`, which is invalid JavaScript.
  Booleans now render through mustache sections so the auto-updater
  wiring is valid.

### Code signing

- Added `sign` parameter to
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).
- Supports macOS code signing + notarization and Windows Authenticode
  via environment variables (`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`,
  `APPLE_APP_SPECIFIC_PASSWORD`).

### Developer tools

- [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md):
  pre-flight validator that reports issues without aborting.
- [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md):
  interactive configuration generator for `_shinyelectron.yml`.
- [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)
  and
  [`example_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/example_app.md):
  browse and retrieve bundled demo apps.
- [`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
  now checks Python shinylive CLI and shiny package availability.

### Windows compatibility

- Fixed [`fs::dir_copy()`](https://fs.r-lib.org/reference/copy.html)
  creating nested subdirectories on Windows by introducing
  [`copy_dir_contents()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_dir_contents.md)
  with consistent cross-platform semantics.
- Fixed GNU tar (from Git for Windows) misinterpreting drive letters as
  remote hosts by resolving to `%SystemRoot%\System32\tar.exe` (bsdtar)
  explicitly.
- Fixed Python download URL: `python-build-standalone` ships `.tar.gz`
  on all platforms, not `.zip` on Windows.
- Fixed bundled R package installation: packages are now installed into
  the portable R’s own library with a scrubbed environment (`--vanilla`,
  `R_LIBS_USER=""`).
- Added post-copy entrypoint validation to catch file layout issues at
  build time instead of inside a running Electron app.

### Documentation

- New vignettes: Runtime Strategies, Multi-App Suites, Code Signing,
  Container Strategy, Security Considerations.
- Renamed the Advanced Features vignette to Customizations and rewrote
  it around the splash, tray, and menu options with annotated diagrams.
- Updated Getting Started, Configuration, and Troubleshooting vignettes
  for Python support, all runtime strategies, and Windows-specific
  guidance.
- The GitHub Actions vignette now reads its env-vars block live from
  `inst/templates/github-actions-build.yml`, so the documented values
  stay in sync with the shipped template.

### Internal

- Extracted
  [`run_command_safe()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_command_safe.md)
  helper for repeated
  [`processx::run()`](http://processx.r-lib.org/reference/run.md)
  patterns.
- Extracted `killProcessTree()` to shared JS utils for process cleanup.
- Cached
  [`available.packages()`](https://rdrr.io/r/utils/available.packages.html)
  during bundled R builds to avoid redundant CRAN network calls.
- Fixed event listener leak in multi-app mode (`removeAllListeners()`
  instead of `removeAllListeners('status')`).

## shinyelectron 0.1.0

- Initial release with `r-shinylive` support.
- Export R Shiny apps as standalone Electron desktop applications via
  WebR.
- Cross-platform builds for macOS, Windows, and Linux.
- Node.js local installation and management.
- Configuration via `_shinyelectron.yml`.
- Automatic updates via `electron-updater`.
