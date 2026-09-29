# shinyelectron (development version)

## Breaking changes

* `export()` now takes the app name from `app.name` in `_shinyelectron.yml`
  when no `app_name` is given, as documented, instead of from the directory
  name. The name also gives the app's slug, which is its identity: the
  package name, the user data folder, the installer file names, and the
  default app ID that Windows installers and macOS use to recognize an
  installed copy. When `app.name` gives an app without `app.slug` a
  different slug than its directory, `export()` warns and shows the
  `app: slug:` line that keeps updating existing installs. `init_config()`
  and `wizard()` now write an explicit `slug:`, and `init_config()` warns
  when a config it replaces gave a different slug.

* Installer and artifact file names change. They now come from the slug and
  always include the architecture, as in `my-app-1.0.0-arm64.dmg`,
  `my-app-Setup-1.0.0-x64.exe`, and `my-app-1.0.0-x86_64.AppImage`, so
  building several architectures into one `dist/` no longer overwrites
  installers. Update release scripts that look for the old names.

* The installed app now carries the display name (`app.name`) instead of the
  slug: the macOS app bundle and App menu, the Windows Start Menu shortcut
  and Apps & Features entry, and the installer window. The Windows
  executable and install folder keep the slug, so pinned shortcuts and
  existing installs carry over. On macOS, reinstalling from the disk image
  leaves the old `<slug>.app` in Applications to delete by hand.

## New features

* New `app.description`, `app.author`, `app.homepage`, and `app.copyright`
  settings describe the app. They fill the generated `package.json` and the
  installer metadata, and Help > About shows them, with buttons to visit the
  homepage or email the author. `app.author` takes an npm-style
  `"Name <email> (url)"` string or a map with `name`, `email`, and `url`,
  and `app.homepage` must be an `http://` or `https://` URL. On macOS, the
  App menu's About panel shows the same name, version, copyright,
  description, and author. Straight double quotes in the app name, author, and copyright become
  typographic quotes in the installer metadata, and a `$` in the app name,
  description, author, or copyright, which the Windows installer cannot
  hold, stops a Windows build.

* With auto-updates enabled, Help > About offers Check for Updates on
  Windows and Linux. It reports that the app is up to date, offers to
  download a newer version, or explains why the check failed.

## Minor improvements and fixes

* App names and other settings that contain quotes or backslashes no longer
  break the generated app. Settings placed in JavaScript strings in `main.js`
  or in the splash and preloader page are now escaped, so a name like
  "Children's Dashboard" or a Windows `log_dir` such as `C:\Users\me\logs`
  works, and the About and quit dialogs and the tray tooltip show `&` instead
  of `&amp;`.

* App names and descriptions in a multi-app suite that contain `<!--`
  followed by `<script>` no longer break the launcher page.

* Help > Documentation opens help URLs with query strings correctly instead
  of turning `&` into `&amp;`.

* Help > Documentation appears only when `menu.help_url` is set, instead of
  in every app with a link that opened nothing.

* With `updates.auto_download` on, the update notification now says the new
  version is downloading, instead of asking the user to click to download.

* An app name with no ASCII letters or digits, such as one written only in
  Chinese characters, no longer stops `export()` late in the build or breaks
  `show_config()`; the slug comes from the directory name instead.

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
