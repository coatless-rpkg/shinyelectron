# shinyelectron 0.2.0

## New app types

* Added Python Shiny support: `py-shinylive` (browser-based via Pyodide) and
  `py-shiny` (native with Python runtime). All four app types are now fully
  implemented.

## Runtime strategies

* Added four runtime strategies for native apps (`r-shiny`, `py-shiny`):
  **system**, **bundled**, **auto-download** (default), and **container**.
* Bundled strategy embeds a portable R or Python runtime inside the Electron
  app for zero-dependency distribution.
* Auto-download strategy downloads the runtime on first launch and caches it
  locally.
* Container strategy runs apps inside Docker or Podman for full environment
  isolation.

## Multi-app suites

* Bundle multiple Shiny apps into a single Electron shell with a launcher UI.
* Configure via `_shinyelectron.yml` with an `apps` array.
* Python suites read dependencies from a single suite-root `requirements.txt`.

## Lifecycle UI

* New lifecycle splash screen with progressive status updates during startup.
* Backend stderr is parsed and surfaced in the splash (package loading, font
  downloads, server status) so users see what's happening instead of a frozen
  screen.
* Port allocation uses OS-assigned ports via `findAvailablePort()` to prevent
  collisions when multiple apps run simultaneously.

## Code signing

* Added `sign` parameter to `export()` and `build_electron_app()`.
* Supports macOS code signing + notarization and Windows Authenticode via
  environment variables (`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`,
  `APPLE_APP_SPECIFIC_PASSWORD`).

## Developer tools

* `app_check()`: pre-flight validator that reports issues without aborting.
* `wizard()`: interactive configuration generator for `_shinyelectron.yml`.
* `available_examples()` and `example_app()`: browse and retrieve bundled demo
  apps.
* `sitrep_shinyelectron()` now checks Python shinylive CLI and shiny package
  availability.

## Windows compatibility

* Fixed `fs::dir_copy()` creating nested subdirectories on Windows by
  introducing `copy_dir_contents()` with consistent cross-platform semantics.
* Fixed GNU tar (from Git for Windows) misinterpreting drive letters as remote
  hosts by resolving to `%SystemRoot%\System32\tar.exe` (bsdtar) explicitly.
* Fixed Python download URL: `python-build-standalone` ships `.tar.gz` on all
  platforms, not `.zip` on Windows.
* Fixed bundled R package installation: packages are now installed into the
  portable R's own library with a scrubbed environment (`--vanilla`,
  `R_LIBS_USER=""`).
* Added post-copy entrypoint validation to catch file layout issues at build
  time instead of inside a running Electron app.

## Documentation

* New vignettes: Runtime Strategies, Multi-App Suites, Code Signing, Container
  Strategy, Security Considerations.
* Updated Getting Started, Configuration, and Troubleshooting vignettes for
  Python support, all runtime strategies, and Windows-specific guidance.

## Internal

* Extracted `run_command_safe()` helper for repeated `processx::run()` patterns.
* Extracted `killProcessTree()` to shared JS utils for process cleanup.
* Added app type group constants (`SHINYLIVE_TYPES`, `NATIVE_TYPES`,
  `R_TYPES`, `PY_TYPES`) to reduce stringly-typed code.
* Cached `available.packages()` during bundled R builds to avoid redundant
  CRAN network calls.
* Fixed event listener leak in multi-app mode (`removeAllListeners()` instead
  of `removeAllListeners('status')`).

# shinyelectron 0.1.0

* Initial release with `r-shinylive` support.
* Export R Shiny apps as standalone Electron desktop applications via WebR.
* Cross-platform builds for macOS, Windows, and Linux.
* Node.js local installation and management.
* Configuration via `_shinyelectron.yml`.
* Automatic updates via `electron-updater`.
