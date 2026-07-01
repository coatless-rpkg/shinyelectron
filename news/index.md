# Changelog

## shinyelectron 0.2.0

This release grows shinyelectron from an R shinylive exporter into a
general Shiny-to-desktop toolkit, adding Python apps, five runtime
strategies, and multi-app suites.

### Breaking changes

- `app_type` now takes only `"r-shiny"`, `"py-shiny"`, or `NULL`
  (autodetected), and shinylive is a `runtime_strategy` rather than an
  app type. The old `"r-shinylive"` and `"py-shinylive"` values still
  work with a deprecation warning and will be removed in a future
  release.

### New features

- Python Shiny apps are supported alongside R. `app_type` autodetects
  `"r-shiny"` or `"py-shiny"` from `appdir`, so
  `export(appdir, destdir)` works with no other arguments.
- `runtime_strategy` selects how an app runs, and all five strategies
  work with both languages: `shinylive` (the default; compiled to
  WebAssembly and run offline in the browser), `bundled` (embeds a
  portable R or Python runtime), `system` (uses an installed
  interpreter), `auto-download` (fetches the runtime on first launch),
  and `container` (runs in Docker or Podman).
- Multi-app suites bundle several apps into one Electron shell with a
  launcher. An `apps` array in `_shinyelectron.yml` lists them, and each
  app can set its own `runtime_strategy`.
- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  gain a `sign` argument for macOS signing and notarization and Windows
  Authenticode, driven by the usual `CSC_*` and `APPLE_*` environment
  variables.
- [`enable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/enable_auto_updates.md),
  [`disable_auto_updates()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/disable_auto_updates.md),
  and
  [`check_auto_update_status()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/check_auto_update_status.md)
  manage electron-updater configuration.
- `install_r()`, `install_python()`, and
  [`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)
  download and cache portable runtimes, and
  [`cache_dir()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_dir.md),
  [`cache_info()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_info.md),
  and
  [`cache_remove()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_remove.md)
  inspect and prune the cache.
- `dependencies.r.version`, `dependencies.python.version`, and
  `dependencies.electron.version` pin the versions a build uses; each
  accepts `null`, `"latest"`, or an exact version.
- App dependencies are detected automatically for native, bundled, and
  container builds, from
  [`library()`](https://rdrr.io/r/base/library.html) and
  [`require()`](https://rdrr.io/r/base/library.html) calls for R and
  `requirements.txt` or `pyproject.toml` for Python.
- A configurable lifecycle splash and preloader report startup progress,
  and a system tray and application menu are set through
  `_shinyelectron.yml`.
- [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  validates an app before building,
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  generates a config interactively,
  [`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
  prints the merged configuration, and
  [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)
  and
  [`example_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/example_app.md)
  browse the bundled demos.
- Apps can supply a Posit `_brand.yml` for theming.
- Prebuilt demo installers are published for every strategy and
  platform, listed in the new Download Prebuilt Demos article.

### Minor improvements and fixes

- [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  refuses to overwrite protected directories such as `~`, `/`, and
  [`R.home()`](https://rdrr.io/r/base/Rhome.html).
- [`convert_shiny_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_shiny_to_shinylive.md)
  removes its temporary copy on every exit path.
- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`export_multi_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export_multi_app.md)
  clean up partial output when a build fails, so a retry no longer needs
  `overwrite = TRUE`.
- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  no longer aborts or deletes a finished build when a `run_after` or
  `open_after` step fails; those steps now only warn.
- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  escapes app names so the generated YAML round-trips, and `build.type`
  may be omitted and autodetected.
- [`run_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_electron_app.md)
  reports the real exit code and stderr on failure and returns `NULL`
  when interrupted.
- [`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
  also checks the Python shinylive CLI and shiny package.
- Directory copying keeps consistent cross-platform semantics on
  Windows.
- Python subprocesses spawn without `LD_LIBRARY_PATH`, fixing a Linux
  `No module named shinylive` error.
- Portable runtimes extract with the system `tar` on macOS and Linux and
  bsdtar on Windows, handling archives R’s internal tar cannot read.
- Native apps bind to an OS-assigned free port to avoid collisions, and
  native startup failures surface in the lifecycle splash.
- The `system` strategy checks for R \>= 4.4.0 or Python \>= 3.9.0 and
  fails with an actionable message.
- Invalid configuration values warn and fall back to defaults instead of
  aborting later in the build.
- Configuration keys that were never read (`splash.width`,
  `splash.height`, `preloader.enabled`, `lifecycle.splash_min_duration`)
  are removed, and `menu.template` accepts only `"default"` and
  `"minimal"`.
- Downloaded runtimes are verified against upstream SHA-256 checksums
  before extraction.
- Vignettes cover getting started, configuration, runtime strategies,
  multi-app suites, code signing, containers, security, and
  auto-updates.

## shinyelectron 0.1.0

- Initial release with `r-shinylive` support.
- Export R Shiny apps as standalone Electron desktop applications via
  WebR.
- Cross-platform builds for macOS, Windows, and Linux.
- Node.js local installation and management.
- Configuration via `_shinyelectron.yml`.
- Automatic updates via `electron-updater`.
