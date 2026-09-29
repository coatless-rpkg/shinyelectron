# shinyelectron (development version)

* R and Python apps whose UI takes several seconds to render no longer fail to
  start. The startup check used to request the app's page, which ran the UI
  code on every attempt; it now requests a path the app does not serve, so the
  UI is rendered once, when the window loads it.

* When an R or Python app does not start in time, only that app's process is
  stopped and the error screen stays up with its details and a Retry button.
  Going back to the launcher while an R or Python app is still starting no
  longer leaves that start running, where it could later stop the next app's
  process or replace the window with the abandoned app.

* Restarting to install a downloaded update now stops the app's R or Python
  process (or its container) and waits for it to exit before the installer
  runs. If the update cannot be installed, a dialog asks you to restart the
  app. Pressing Esc in the Update Ready dialog now means Later.

* New `lifecycle.startup_timeout` sets how long, in milliseconds, an app waits
  for its R, Python, or container server to start (default 180000, three
  minutes). R and Python apps used to give up after 60 seconds and container
  apps after 120. This timeout and `lifecycle.shutdown_timeout` must be whole
  numbers of at least 1000; any other value warns and falls back to the
  default. Before, a `shutdown_timeout` such as `"10s"` built an app that could
  not launch.

# shinyelectron 0.2.1

* Examples for functions that install a runtime, launch an app, or clear the
  cache now run only in interactive sessions.

* The Download Prebuilt Demos guide moved from a bundled vignette to the
  package website, and outdated external documentation links were refreshed.

* `wizard()` now requires the `appdir` argument instead of defaulting to the
  working directory.

# shinyelectron 0.2.0

This release grows shinyelectron from an R shinylive exporter into a general
Shiny-to-desktop toolkit, adding Python apps, five runtime strategies, and
multi-app suites.

## Breaking changes

* `app_type` now takes only `"r-shiny"`, `"py-shiny"`, or `NULL` (autodetected),
  and shinylive is a `runtime_strategy` rather than an app type. The old
  `"r-shinylive"` and `"py-shinylive"` values still work with a deprecation
  warning and will be removed in a future release.

## New features

* Python Shiny apps are supported alongside R. `app_type` autodetects
  `"r-shiny"` or `"py-shiny"` from `appdir`, so `export(appdir, destdir)` works
  with no other arguments.
* `runtime_strategy` selects how an app runs, and all five strategies work with
  both languages: `shinylive` (the default; compiled to WebAssembly and run
  offline in the browser), `bundled` (embeds a portable R or Python runtime),
  `system` (uses an installed interpreter), `auto-download` (fetches the runtime
  on first launch), and `container` (runs in Docker or Podman).
* Multi-app suites bundle several apps into one Electron shell with a launcher.
  An `apps` array in `_shinyelectron.yml` lists them, and each app can set its
  own `runtime_strategy`.
* `export()` and `build_electron_app()` gain a `sign` argument for macOS signing
  and notarization and Windows Authenticode, driven by the usual `CSC_*` and
  `APPLE_*` environment variables.
* `enable_auto_updates()`, `disable_auto_updates()`, and
  `check_auto_update_status()` manage electron-updater configuration.
* `install_r_portable()`, `install_python_standalone()`, and `install_nodejs()`
  download and cache portable runtimes, and `cache_dir()`, `cache_info()`, and
  `cache_remove()` inspect and prune the cache.
* `dependencies.r.version`, `dependencies.python.version`, and
  `dependencies.electron.version` pin the versions a build uses; each accepts
  `null`, `"latest"`, or an exact version.
* App dependencies are detected automatically for native, bundled, and container
  builds, from `library()` and `require()` calls for R and `requirements.txt` or
  `pyproject.toml` for Python.
* A configurable lifecycle splash and preloader report startup progress, and a
  system tray and application menu are set through `_shinyelectron.yml`.
* The Electron shell streams the renderer console (webR, Pyodide, and Shiny
  output) into the app log, so browser-side messages and errors appear alongside
  the main-process logs.
* `app_check()` validates an app before building, `wizard()` generates a config
  interactively, `show_config()` prints the merged configuration, and
  `available_examples()` and `example_app()` browse the bundled demos.
* `app_dependencies()` reports the R or Python packages a Shiny app or multi-app
  suite uses, which helps install an app's dependencies before a shinylive build.
* Apps can supply a Posit `_brand.yml` for theming.
* Prebuilt demo installers are published for every strategy and platform, listed
  in the new Download Prebuilt Demos article.

## Minor improvements and fixes

* The `runtime_strategy` argument overrides a suite's `build.runtime_strategy`
  for apps that set no per-app strategy, so a suite built as `shinylive` really
  is shinylive rather than falling back to the config default.
* A `_brand.yml` that names palette colors (for example `primary: plum`) resolves
  those references before theming the shell.
* Error screens allow selecting and copying the message and log details.
* Building with the shinylive strategy checks that the app's R packages are
  installed and names any that are missing, since `shinylive::export()` compiles
  the WebAssembly bundle from installed packages.
* `build_electron_app()` refuses to overwrite protected directories such as `~`,
  `/`, and `R.home()`.
* `convert_shiny_to_shinylive()` removes its temporary copy on every exit path.
* `export()` cleans up partial output when a build fails, so a retry no longer
  needs `overwrite = TRUE`, for single apps and multi-app suites alike.
* `export()` no longer aborts or deletes a finished build when a `run_after` or
  `open_after` step fails; those steps now only warn.
* `init_config()` escapes app names so the generated YAML round-trips, and
  `build.type` may be omitted and autodetected.
* `run_electron_app()` reports the real exit code and stderr on failure and
  returns `NULL` when interrupted.
* `sitrep_shinyelectron()` also checks the Python shinylive CLI and shiny
  package.
* Directory copying keeps consistent cross-platform semantics on Windows.
* Python subprocesses spawn without `LD_LIBRARY_PATH`, fixing a Linux
  `No module named shinylive` error.
* Portable runtimes extract with the system `tar` on macOS and Linux and bsdtar
  on Windows, handling archives R's internal tar cannot read.
* Native apps bind to an OS-assigned free port to avoid collisions, and native
  startup failures surface in the lifecycle splash.
* The `system` strategy checks for R >= 4.4.0 or Python >= 3.9.0 and fails with
  an actionable message.
* Invalid configuration values warn and fall back to defaults instead of
  aborting later in the build.
* Configuration keys that were never read (`splash.width`, `splash.height`,
  `preloader.enabled`, `lifecycle.splash_min_duration`) are removed, and
  `menu.template` accepts only `"default"` and `"minimal"`.
* Downloaded runtimes are verified against upstream SHA-256 checksums before
  extraction.
* Vignettes cover getting started, configuration, runtime strategies, multi-app
  suites, code signing, containers, security, and auto-updates.

# shinyelectron 0.1.0

* Initial release with `r-shinylive` support.
* Export R Shiny apps as standalone Electron desktop applications via WebR.
* Cross-platform builds for macOS, Windows, and Linux.
* Node.js local installation and management.
* Configuration via `_shinyelectron.yml`.
* Automatic updates via `electron-updater`.
