# Changelog

## shinyelectron 0.2.0

This release expands shinyelectron from an R shinylive exporter into a
general Shiny-to-desktop toolkit: R and Python apps, five runtime
strategies, multi-app suites, and a rewritten Electron shell.

### App types and autodetection

- Python Shiny is now supported alongside R Shiny. `app_type` takes
  `"r-shiny"` or `"py-shiny"`, with `NULL` (default) meaning autodetect
  from the files in `appdir`.
  [`detect_app_type()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/detect_app_type.md)
  resolves `app.R`, `ui.R` + `server.R`, or `app.py`; directories
  carrying both R and Python entrypoints, or only one of `server.R` /
  `ui.R`, abort with guidance.
- `export(appdir, destdir)` with no other arguments now works for the
  common case.
- Python subprocesses (shinylive conversion and Python or shinylive
  validation) are spawned without `LD_LIBRARY_PATH`. On Linux, R
  prepends its own library directory to that variable, so an inherited
  value made a spawned Python load a system `libpython`, recompute
  `sys.prefix`, and drop its `site-packages`, surfacing as
  `No module named shinylive` even when it was installed.

### Runtime strategies

- Five strategies, all legal with both languages: **shinylive** (the
  default, compiles to WebAssembly and runs in-browser, fully offline),
  **bundled**, **system**, **auto-download**, and **container**.
- Bundled embeds a portable R or Python runtime inside the Electron app
  for zero-dependency distribution.
- Auto-download fetches the runtime on first launch and caches it
  locally.
- System runs against an interpreter already installed on the end user’s
  machine. Native backends probe it first and fail with an actionable
  message when R is older than 4.4.0 or Python older than 3.9.0.
- Container runs apps inside Docker or Podman for full environment
  isolation (see Container strategy below).
- Downloaded runtimes are verified against an upstream-published SHA-256
  checksum before extraction: Node.js against `SHASUMS256.txt`, portable
  R against its per-asset `.sha256` sidecar, and portable Python against
  python-build-standalone’s `SHA256SUMS`. A missing checksum warns and
  continues. The `auto-download` runtime manifest also carries the hash,
  so the first-launch download is verified on the end user’s machine.
- Bundled and auto-download builds resolve an R version that actually
  has a portable build (the newest r-hub release can outpace
  portable-r), read a pinned version from `dependencies.r.version` /
  `dependencies.python.version`, and abort when combined with more than
  one platform or architecture, since they embed a single platform’s
  runtime.
- The older `app_type = "r-shinylive"` and `"py-shinylive"` values are
  still accepted with a deprecation warning of class
  `shinyelectron_deprecated_app_type`; they translate to the canonical
  language plus `runtime_strategy = "shinylive"`. Pairing a legacy type
  with a non-shinylive strategy is an error. The shim will be removed in
  a future release.

### Runtime versions and installers

- `dependencies.r.version`, `dependencies.python.version`, and
  `dependencies.electron.version` each accept `null` (the maintained
  pin), `"latest"` (fetch the newest published version), or an exact
  version string. Resolution follows a config, then latest, then pin
  precedence and drives native, container, and `package.json` builds.
  Maintained pins ship in `SHINYELECTRON_DEFAULTS$runtime_versions`.
- New exported installers `install_r()`, `install_python()`, and
  [`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
  download and cache portable R, Python (python-build-standalone), and
  Node.js for the bundled and auto-download strategies.
  `install_python(version = NULL)` resolves the maintained pin and
  derives the correct release tag automatically.
- Runtime cache management:
  [`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md)
  reports the cache location,
  [`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md)
  lists cached R, Python, and Node.js runtimes with version, platform,
  arch, and disk usage,
  [`cache_remove()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_remove.md)
  deletes a specific version (platform and arch are required for
  Node.js, and only that build is removed), and
  [`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)
  gains `nodejs` and `python` targets.
- Generated Electron apps now build on Electron 41 (up from Electron
  38), with electron-builder, electron-updater, and express bumped to
  current releases. The `electron` version is read from config; the
  previous Node version knob was removed.
- Portable archives extract atomically into a staging directory swapped
  into place only on success, so a failed or forced reinstall never
  destroys a working install. Extraction uses the system `tar` on macOS
  and Linux (R’s internal tar aborts on PAX records with embedded nuls,
  such as Apple code signing metadata) and Windows’ bundled bsdtar
  (`%SystemRoot%\System32\tar.exe`) for the PAX and long-name records in
  python-build-standalone archives, which also ship as `.tar.gz` on
  every platform (not `.zip` on Windows).
- Bundled R packages install into a sibling `runtime/library` directory
  alongside the portable R, not into the portable R’s own library. This
  avoids macOS hardened-runtime segfaults that occurred when installing
  unsigned CRAN binaries directly into the bundled R tree.

### Dependency detection and installation

- App dependencies are detected automatically for native, bundled, and
  container builds: R packages from
  [`library()`](https://rdrr.io/r/base/library.html) /
  [`require()`](https://rdrr.io/r/base/library.html) calls (minus base
  packages) and Python packages from `requirements.txt` or
  `pyproject.toml`, merged with any declared in config. Requirement
  parsing handles VCS and bare-URL entries, PEP 508 `name @ url` specs,
  and multi-entry lines.
- Container builds resolve the required Linux system libraries from the
  Posit Package Manager system-requirements API and install them before
  the R packages, with a `dependencies.system_packages` config key as an
  escape hatch.
- [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
  no longer forces `type = "binary"` on Linux, where the package type is
  source.

### Container strategy

- Runs native Shiny apps inside a Docker or Podman container, with
  engine autodetection, image selection, and bundled Dockerfiles for R,
  Python, and combined apps.
- Container host resolution is engine-aware: Podman’s machine socket (or
  its default connection) is resolved and `CONTAINER_HOST` set
  accordingly, with an engine-specific not-running message, so Podman is
  now functional.
- The host port is assigned by the engine (`-p 127.0.0.1::<port>`, read
  back with `docker port`) instead of pre-picked, avoiding collisions
  between concurrent apps and keeping the container off the LAN.
- Shutdown is asynchronous, so the closing screen renders immediately
  while the container stops and is removed in the background.
- Images are pinned and tagged by the resolved runtime version. The R
  image moved to `rocker/r-ver` with an `R_VERSION` build arg and
  installs Shiny’s transitive R dependencies explicitly because r2u’s
  `r-cran-shiny` can lag on bleeding-edge R. Cold builds pass
  `DEBIAN_FRONTEND=noninteractive` and `--force-confold` so a mid-build
  `r-base-core` upgrade does not stall on a conffile prompt.

### Multi-app suites

- Bundle multiple Shiny apps into a single Electron shell with a
  launcher UI.
- Configure via `_shinyelectron.yml` with an `apps` array; each app
  entry may carry its own `runtime_strategy`, so a suite can mix (for
  example) one shinylive app with a bundled R app. Mixing follows one
  rule: each language uses a single native strategy (`system`,
  `bundled`, or `auto-download`) across the suite, enforced at export. A
  single-entry `apps` block is rejected with a clear error.
- Bundled and auto-download suites embed the runtime correctly: a
  bundled suite installs the union of its bundled apps’ packages into
  one shared runtime, and an auto-download suite writes a per-app
  runtime manifest that the backends locate relative to the running app.
  Shinylive suites share a single WebAssembly runtime across all apps
  instead of duplicating it, served from one origin so app-to-app
  navigation keeps one root-scoped service worker.
- Python suites read dependencies from a single suite-root
  `requirements.txt`.

### Config file

- `build.type` may be omitted; autodetection runs at build time.
- `build.runtime_strategy: "shinylive"` is accepted alongside the other
  four strategies.
- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  writes a template that leaves `build.type` commented out and lists all
  five strategies, and
  [`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
  pretty-prints the effective merged configuration.
- An app may supply a Posit `_brand.yml` for visual theming; its assets
  are copied into the generated project, with a graceful fallback to
  default branding on parse errors.
- Config validation is stricter and more forgiving in the right places:
  invalid `runtime_strategy`, `container.engine`, and out-of-range
  version or `system_packages` values warn and fall back to defaults
  rather than aborting a build later, while genuine validation errors
  surface with their specific message instead of a generic parse
  warning. Multi-element `window.width`, `window.height`, and
  `server.port` values warn by field name and fall back.
- Deep config merge no longer discards user-set lists and scalars
  (repos, index URLs, package lists); it recurses only into fully named
  lists.
- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  escapes app names containing quotes or backslashes so the generated
  YAML round-trips.

### Removed config keys

- `splash.width`, `splash.height`, `preloader.enabled`, and
  `lifecycle.splash_min_duration` were validated but never read and have
  been removed from the schema.
- `menu.template` accepts only `"default"` and `"minimal"`; the
  previously listed `"custom"` value is no longer accepted.

### Desktop UI and lifecycle

- The rewritten Electron shell adds a configurable system tray, a
  default or minimal application menu, and splash and preloader screens,
  all set through `_shinyelectron.yml`.
- New lifecycle splash screen with progressive status updates during
  startup. Backend stderr is parsed and surfaced (package loading, font
  downloads, server status) so users see progress instead of a frozen
  screen, and native R and Python startup failures now appear in the
  lifecycle UI instead of only the logs.
- Splash and preloader gain working knobs: `splash.enabled` toggles the
  splash state, `splash.duration` sets a minimum display time before
  transitioning, `splash.background` and `preloader.background` override
  the lifecycle window background, and `preloader.style` picks the
  loading indicator (`spinner`, `bar`, or `dots`).
- Native servers bind to an OS-assigned free port via
  `findAvailablePort()` to prevent collisions when multiple apps run.
- Window and tray icons use the icon’s real file extension, and a
  restored window is clamped to a currently connected display instead of
  opening off-screen on a since-disconnected monitor.
- Backends no longer wipe the main process’s status subscribers on
  start; they remove only their own one-shot handlers, so the lifecycle
  UI keeps updating. In a suite, install and runtime prompts are routed
  to the active sub-app, a retry restarts the app the user selected, and
  the tray tooltip and status item track the running sub-app.

### Code signing

- Added `sign` parameter to
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md).
- Supports macOS code signing plus notarization and Windows Authenticode
  via environment variables (`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_ID`,
  `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`).
- Signing is resolved before the multi-app branch, so suites honor
  `sign: true`, and disabled builds set
  `CSC_IDENTITY_AUTO_DISCOVERY=false` rather than nulling the macOS
  identity. The `icon` and per-platform icon keys are honored for single
  and multi-app builds.

### Auto-updates

- New management API:
  [`enable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/enable_auto_updates.md),
  [`disable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/disable_auto_updates.md),
  and
  [`check_auto_update_status()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/check_auto_update_status.md)
  configure electron-updater in `_shinyelectron.yml` and report the
  current update status. Only the GitHub provider is wired into the
  build today; `s3` and `generic` are rejected with a message saying
  they are planned.
- Update-enabled builds now parse and load correctly: R booleans render
  as lowercase JavaScript `true` / `false` in the generated `main.js`,
  and the electron-log import no longer clashes with the app logger.

### Developer tools

- [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md):
  pre-flight validator that inspects app structure, config, runtime
  availability, and dependencies and reports issues without aborting,
  honoring `app_type`, `runtime_strategy`, `platform`, and `sign`
  overrides, and reporting config parse errors as warnings.
- [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md):
  interactive configuration generator for `_shinyelectron.yml`. It asks
  for language and runtime strategy separately, re-prompts on
  non-numeric window or port input, validates platform tokens, offers
  only the GitHub update provider, and validates that the file it writes
  round-trips.
- [`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md):
  diagnostics across system, dependencies, build tools, and project
  state, including the Python shinylive CLI and shiny package.
- [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)
  and
  [`example_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/example_app.md):
  browse and retrieve bundled demo apps (R single, Python single, and
  suites);
  [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)
  reports a `type` column.
- Backend diagnostic logging is gated behind `SHINYELECTRON_DEBUG`;
  warnings and errors still print unconditionally.

### Bug fixes

These correct behavior that shipped in 0.1.0.

- Directory copying created a nested subdirectory of the destination on
  Windows. [`fs::dir_copy()`](https://fs.r-lib.org/reference/copy.html)
  was replaced with
  [`copy_dir_contents()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/copy_dir_contents.md),
  which has consistent cross-platform semantics.
- A failed Electron run reported a generic “Failed to run” message that
  hid the exit code and stderr, because the exit-code check ran inside
  its own error handler. The check now runs outside the handler so the
  real diagnostics surface, and a Ctrl+C interruption returns `NULL`
  cleanly.
- A failed
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  left its partially populated output directory behind, so a retry
  needed `overwrite = TRUE`. Both
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`export_multi_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export_multi_app.md)
  now remove output they created on error.
- A failing `run_after` or `open_after` step (a non-zero Electron exit
  or a [`browseURL()`](https://rdrr.io/r/utils/browseURL.html) failure)
  aborted
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and could delete the finished build. Those steps now run after the
  build and only warn, preserving the output.
- [`convert_shiny_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_shiny_to_shinylive.md)
  removed its temporary app copy only on success, leaking it whenever
  [`shinylive::export()`](https://posit-dev.github.io/r-shinylive/reference/export.html)
  errored. Cleanup now runs on every exit path.
- [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  unlinked its output directory unconditionally when overwriting, so an
  overwrite of `~`, `/`, or
  [`R.home()`](https://rdrr.io/r/base/Rhome.html) was possible. A
  protected-directory guard,
  [`assert_safe_to_overwrite()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/assert_safe_to_overwrite.md),
  now runs first.

### Demos

- Prebuilt desktop installers of the bundled demo apps are published for
  every runtime strategy on macOS, Windows, and Linux. The new Download
  Prebuilt Demos article detects the visitor’s platform, shows its
  installers first, and collapses the rest, while remaining usable
  without JavaScript.

### Documentation

- New vignettes cover getting started, configuration, runtime
  strategies, multi-app suites, code signing, container strategy,
  security, auto-updates, Node.js management, customizations, GitHub
  Actions, and troubleshooting (0.1.0 shipped none).
- The Advanced Features vignette was renamed to Customizations and
  rewritten around the splash, tray, and menu options.
- The GitHub Actions vignette reads its env-vars block live from
  `inst/templates/github-actions-build.yml`, so the documented values
  stay in sync with the shipped template, and its runner matrix was
  reconciled with the four CI runners the template ships.
- Configuration and security vignettes gain reference tables for
  logging, lifecycle, installer, and dependency options, plus custom
  runtime-version guidance, runtime-download SHA-256 integrity, and
  Content-Security-Policy scope. Version pins are documented under
  `dependencies:` (top-level keys are ignored), and `auto_install` is
  marked planned.
- Runtime-strategy docs were corrected for multi-platform builds (one
  export per target), the `~/.shinyelectron/runtimes/` cache path, the
  bundled runtime landing in `runtime/`, and R bundling being
  unsupported on Linux while Python bundling works.
- Auto-update, code-signing, and container docs were realigned with the
  shipped behavior (GitHub-only updates with S3 and generic planned, the
  update manifests to upload with a release, Linux GPG signing as a
  reserved no-op, and the container engine being baked into config).
- Roxygen and man pages moved from `\code{}` to markdown backticks, and
  README and vignette drift was corrected.

### Internal

- DESCRIPTION now depends on R (\>= 4.4.0), moves `shinylive` from
  Imports to Suggests, adds `yaml` to Imports, imports the base `stats`,
  `tools`, and `utils` packages, adds `quarto`, `renv`, and `withr` to
  Suggests with `VignetteBuilder: quarto`, and raises version floors on
  current dependencies. `pak` was dropped once system requirements moved
  to the Posit Package Manager HTTP API.
- Extracted
  [`run_command_safe()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_command_safe.md)
  for repeated
  [`processx::run()`](http://processx.r-lib.org/reference/run.md)
  patterns and `killProcessTree()` into the shared JS utilities for
  process cleanup, and cached
  [`available.packages()`](https://rdrr.io/r/utils/available.packages.html)
  during bundled R builds to avoid redundant CRAN calls.
- Native builds confirm a Shiny entrypoint survived the file copy and
  abort at build time rather than failing inside a running Electron app.
- Build success is judged by the presence of platform artifacts in
  `dist/`, and generated build scripts pass `--publish never`, so a
  non-zero electron-builder exit no longer prints a misleading failure
  when the installer was written. The generated `package.json` emits the
  `AGPL-3.0-or-later` license id.
- Portable and Node.js installs abort (rather than warn and return a
  broken path) when the extracted executable is missing, verify the
  target platform and arch rather than the build host, stage a Node.js
  reinstall so a mid-extraction failure leaves the prior install intact,
  and give a clear error for an unsupported platform or architecture
  instead of a malformed download URL.
- Electron file logging honors `log_level = "debug"`, and dependency
  checks no longer require `jsonlite` in a bare system R.
- `sitrep` helpers persist detected issues across their error handlers
  and align their R and npm version thresholds and required-package list
  with DESCRIPTION.

## shinyelectron 0.1.0

- Initial release with `r-shinylive` support.
- Export R Shiny apps as standalone Electron desktop applications via
  WebR.
- Cross-platform builds for macOS, Windows, and Linux.
- Node.js local installation and management.
- Configuration via `_shinyelectron.yml`.
- Automatic updates via `electron-updater`.
