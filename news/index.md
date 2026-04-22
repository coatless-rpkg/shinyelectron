# Changelog

## shinyelectron 0.2.0

### New app types

- Added Python Shiny support: `py-shinylive` (browser-based via Pyodide)
  and `py-shiny` (native with Python runtime). All four app types are
  now fully implemented.

### Runtime strategies

- Added four runtime strategies for native apps (`r-shiny`, `py-shiny`):
  **system**, **bundled**, **auto-download** (default), and
  **container**.
- Bundled strategy embeds a portable R or Python runtime inside the
  Electron app for zero-dependency distribution.
- Auto-download strategy downloads the runtime on first launch and
  caches it locally.
- Container strategy runs apps inside Docker or Podman for full
  environment isolation.

### Multi-app suites

- Bundle multiple Shiny apps into a single Electron shell with a
  launcher UI.
- Configure via `_shinyelectron.yml` with an `apps` array.
- Python suites read dependencies from a single suite-root
  `requirements.txt`.

### Lifecycle UI

- New lifecycle splash screen with progressive status updates during
  startup.
- Backend stderr is parsed and surfaced in the splash (package loading,
  font downloads, server status) so users see what’s happening instead
  of a frozen screen.
- Port allocation uses OS-assigned ports via `findAvailablePort()` to
  prevent collisions when multiple apps run simultaneously.

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
- Updated Getting Started, Configuration, and Troubleshooting vignettes
  for Python support, all runtime strategies, and Windows-specific
  guidance.

### Internal

- Extracted
  [`run_command_safe()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_command_safe.md)
  helper for repeated
  [`processx::run()`](http://processx.r-lib.org/reference/run.md)
  patterns.
- Extracted `killProcessTree()` to shared JS utils for process cleanup.
- Added app type group constants (`SHINYLIVE_TYPES`, `NATIVE_TYPES`,
  `R_TYPES`, `PY_TYPES`) to reduce stringly-typed code.
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
