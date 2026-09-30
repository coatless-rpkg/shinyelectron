# Changelog

## shinyelectron (development version)

### Breaking changes

- shinyelectron now requires R 4.5.0 or newer, since it verifies
  downloaded runtimes with
  [`tools::sha256sum()`](https://rdrr.io/r/tools/sha256sum.html), which
  was added in R 4.5.0. The README and
  [`sitrep_electron_system()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_electron_system.md)
  now report this minimum. Apps built with the `system` strategy still
  accept R 4.4.0 or newer on the end user’s machine.

- Installer and artifact file names change. They now come from the slug
  and always include the architecture, as in `my-app-1.0.0-arm64.dmg`,
  `my-app-Setup-1.0.0-x64.exe`, and `my-app-1.0.0-x86_64.AppImage`, so
  building several architectures into one `dist/` no longer overwrites
  installers. Update release scripts that look for the old names.

- The installed app now carries the display name instead of the slug:
  the macOS app bundle and App menu, the Windows Start Menu shortcut and
  Apps & Features entry, and the installer window.
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  now also takes the display name from `app.name` in
  `_shinyelectron.yml` when no `app_name` is given, as documented,
  instead of from the directory name. The slug, which is the app’s
  identity, keeps coming from `app.slug`, then the `app_name` argument,
  then the directory name, so installed copies keep updating. The
  Windows executable keeps the slug as well, and updates reuse the
  existing install folder, so pinned shortcuts and existing installs
  carry over. On macOS, reinstalling from the disk image leaves the old
  `<slug>.app` in Applications to delete by hand.

- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  now builds for `build.platforms` and `build.architectures` in
  `_shinyelectron.yml` when its `platform` and `arch` arguments are not
  given, for single apps and multi-app suites alike. Each argument
  overrides only its own list. Before, the lists had no effect: the
  build, the choice of icon, and the signing and Windows installer
  checks all used the current machine. Check the lists in your
  configuration files. Earlier versions of
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  suggested `mac` and wrote it to `build.platforms`, so a file written
  with them on Windows or Linux may list `platforms: mac`; change or
  remove `platforms` there.
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  now leaves `platforms` out unless you name some, so each build targets
  the machine it runs on. If you copied the Getting Started or
  Configuration Guide example that paired `runtime_strategy: "bundled"`
  with `platforms: [mac, win]`, remove `platforms`, since a `bundled` or
  `auto-download` build stops when the targets name more than one
  platform or architecture. A list with no valid value means the current
  platform or architecture, and a value listed twice is built once.

- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  now checks the targets before converting anything. It stops when a
  target is `mac` and the build machine is not a Mac: macOS apps build
  only on macOS, and such an export used to report success without
  making an installer. A `bundled` or `auto-download` build for more
  than one target now stops before any files are copied, and an invalid
  `platform` or `arch` argument stops the export even with
  `build = FALSE`.
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  reports these problems too, and
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  asks for a single platform when you choose the `bundled` or
  `auto-download` strategy.

### New features

- New `lifecycle.startup_timeout` sets how long, in milliseconds, an app
  waits for its R, Python, or container server to start (default 180000,
  three minutes). R and Python apps used to give up after 60 seconds and
  container apps after 120. This timeout and
  `lifecycle.shutdown_timeout` must be whole numbers from 1000 to
  2147483647; any other value warns and falls back to the default.
  Before, a `shutdown_timeout` such as `"10s"` built an app that could
  not launch.

- `installer.allow_to_change_installation_directory: true` adds a page
  to the Windows setup wizard where users choose the installation
  folder. It requires `installer.one_click: false`; otherwise reading
  the configuration fails with an error.

- `installer.per_machine: true` installs the Windows app for all users.
  Every install and update then needs administrator rights.

- Bundled R builds now leave out files that a running app does not use:
  the test suites (`tests/`, `testme/`, `tinytest/`) of every embedded
  package, and the portable R’s own regression tests, PDF and HTML
  manuals, and news and FAQ files. Package examples, demos, NEWS files,
  and headers are kept, as are R’s license notices. Pruning is on by
  default; set `dependencies.r.prune: false` in `_shinyelectron.yml` to
  ship the runtime unchanged. A quoted `"true"` or `"false"` is read
  with a warning, and any other value stops the build before anything is
  downloaded.

- `dependencies.r.local_packages` installs R packages that are not on a
  repository, such as in-house packages, into the R library of a
  `bundled` build. List package source folders or `.tar.gz` source
  tarballs relative to the app directory. Each package is built and
  installed with the bundled R after its dependencies, and the build
  stops unless it loads.

- New `app.description`, `app.author`, `app.homepage`, and
  `app.copyright` settings describe the app. They fill the generated
  `package.json` and the installer metadata, and Help \> About shows
  them, with buttons to visit the homepage or email the author.
  `app.author` takes an npm-style `"Name <email> (url)"` string or a map
  with `name`, `email`, and `url`, and `app.homepage` must be an
  `http://` or `https://` URL. On macOS, the App menu’s About panel
  shows the same name, version, copyright, description, and author.
  Straight double quotes in the app name, author, and copyright become
  typographic quotes in the installer metadata, and a `$` in the app
  name, description, author, or copyright, which the Windows installer
  cannot hold, stops a Windows build.

- With auto-updates enabled, Help \> About offers Check for Updates on
  Windows and Linux. It reports that the app is up to date, offers to
  download a newer version, or explains why the check failed.

- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  shows the app’s slug next to its display name and says when `app.slug`
  could choose another.
  [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  and
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  write the slug into the new configuration, and
  [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  warns when a configuration it replaces gave a different slug.

### Minor improvements and fixes

- shinyelectron now imports rlang. cli builds `cli_abort()` and
  `cli_warn()` on rlang but only suggests it. Without rlang installed,
  errors from `cli_abort()` showed “there is no package called ‘rlang’”
  instead of their own message, and warnings from `cli_warn()` became
  that same error, stopping operations meant to continue, such as a
  Node.js install whose checksum list could not be downloaded.

- The situation reports
  ([`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
  and friends) no longer report Node.js, npm or Python as missing when
  the withr package is not installed. withr is only a suggested
  dependency, and the probe used to fail without it.

- The Security Considerations guide gains a “Secrets and per-user
  credentials” section. It covers which environment variables and
  `.Renviron` files reach an app’s R, Python, or container process, and
  how to give each user their own token without bundling it.

- Keys in `_shinyelectron.yml` that shinyelectron does not recognize,
  such as a misspelled `widht` or a key placed in the wrong section, now
  trigger a warning of class `shinyelectron_unknown_config_key` that
  names each one by its dotted path (for example `window.widht`). They
  were previously ignored without notice.

- The top-level `logging` section documented in the Configuration Guide
  now takes effect; its `log_dir` and `log_level` were previously
  ignored. If you copied the guide’s earlier example, drop its
  `log_dir: "/var/log/my-app"` line: `log_dir` should be an absolute
  path that the app’s user can write to, and without it logs go to the
  app’s `userData/logs` folder. `app.log_dir` and `app.log_level` still
  work. When both set a key to different values, `logging` wins with a
  warning of class `shinyelectron_logging_conflict`.
  [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  now suggests the `logging` form.

- [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md)
  no longer suggests `nodejs.auto_install`, which has no effect yet.

- App names and other settings that contain quotes or backslashes no
  longer break the generated app. Settings placed in JavaScript strings
  in `main.js` or in the splash and preloader page are now escaped, so a
  name like “Children’s Dashboard” or a Windows `log_dir` such as
  `C:\Users\me\logs` works, and the About and quit dialogs and the tray
  tooltip show `&` instead of `&amp;`.

- App names and descriptions in a multi-app suite that contain `<!--`
  followed by `<script>` no longer break the launcher page.

- Help \> Documentation opens help URLs with query strings correctly
  instead of turning `&` into `&amp;`.

- Help \> Documentation appears only when `menu.help_url` is set,
  instead of in every app with a link that opened nothing.

- R and Python apps whose UI takes several seconds to render no longer
  fail to start. The startup check used to request the app’s page, which
  ran the UI code on every attempt; it now requests a path the app does
  not serve, so the UI is rendered once, when the window loads it.

- When an app does not start in time, only its own R or Python process
  or container is stopped, and the error screen stays up with its Retry
  and Quit buttons. For a container, the error names the container and
  its details show the container’s logs. Going back to the launcher
  while an app is still starting no longer leaves that start running,
  where it could later stop the next app’s process or container or
  replace the window with the abandoned app, and switching between
  container apps no longer shows the previous container’s shutdown
  messages.

- An R or Python app killed by a signal while starting (a segfault, or
  the system running out of memory), or one that exits before its server
  answers, now shows the error at once instead of after the startup
  timeout.

- Restarting to install a downloaded update now stops the app’s R or
  Python process (or its container) and waits for it to exit before the
  installer runs. If the update cannot be installed, a dialog asks you
  to restart the app. Pressing Esc in the Update Ready dialog now means
  Later.

- Signed builds no longer fail when `_shinyelectron.yml` sets
  `signing.win.certificate_file`. The certificate settings were written
  where electron-builder 26 no longer accepts them, so its configuration
  check stopped the build for every platform, macOS and Linux included.
  They now go under `win.signtoolOptions`, where electron-builder 26
  reads them. The certificate password still comes from
  `CSC_KEY_PASSWORD` and is never written to `package.json`.

- The Windows credential checks in
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  now follow electron-builder’s lookup order: the certificate from
  `signing.win.certificate_file`, then `WIN_CSC_LINK`, then `CSC_LINK`,
  and the password from `WIN_CSC_KEY_PASSWORD`, then `CSC_KEY_PASSWORD`.
  Setting only the `WIN_CSC_*` variables no longer draws a misleading
  warning, and a `WIN_CSC_*` variable that is set but empty now warns,
  because electron-builder stops there instead of falling back to
  `CSC_*`.

- A signed build now passes `signing.mac.team_id` to electron-builder as
  `APPLE_TEAM_ID`, the only place electron-builder reads the
  notarization team ID. Before, when the team ID was set only in
  `_shinyelectron.yml`, builds that notarize with an Apple ID failed
  with “APPLE_TEAM_ID env var needs to be set”. A team ID already set in
  `APPLE_TEAM_ID` still wins.

- `export(sign = TRUE)` and `app_check(sign = TRUE)` now check the
  signing credentials even when `signing.sign` is off in
  `_shinyelectron.yml`. The macOS checks also follow electron-builder:
  an App Store Connect API key (`APPLE_API_KEY`, `APPLE_API_KEY_ID`,
  `APPLE_API_ISSUER`) or `APPLE_KEYCHAIN_PROFILE` counts as notarization
  credentials, a missing team ID is reported only when notarizing with
  an Apple ID, and each warning says whether notarization will fail or
  be skipped.

- Bundled R builds now install packages with the portable R’s own
  startup files. The install no longer runs a project `.Rprofile` or
  `.Renviron` from the working directory, such as renv’s autoloader, and
  ignores `R_ENVIRON` and `R_PROFILE` set for the calling R. A site
  profile chosen that way skipped the portable R’s macOS library fix-up,
  so installed binary packages could crash when loaded. `~/.Renviron`
  and `~/.Rprofile` still apply.

- Python dependencies are now read in full from `pyproject.toml`. In a
  `dependencies` list that spanned several lines, a `]` inside an entry,
  such as the extras in `"uvicorn[standard]>=0.30"`, or in a comment
  ended the list, so the packages after it were not installed.
  Single-quoted entries are now read, commented-out entries are skipped,
  and only the `dependencies` of the `[project]` table are used, so
  development tools listed in other tables, such as Hatch’s
  `[tool.hatch.envs.*]` environments, are no longer installed with the
  app. A `pyproject.toml` with no packages in that list now draws a
  warning.

- Python packages listed with the version in parentheses, as in
  `"shiny (>=1.0)"`, are now read as `shiny` from `pyproject.toml` and
  `requirements.txt`. Poetry 2 writes `pyproject.toml` entries this way.
  They were read as `shiny (`, which pip rejects, so none of the app’s
  Python packages were installed.

- `installer.one_click`,
  `installer.allow_to_change_installation_directory`, and
  `installer.per_machine` are checked when the configuration is read. A
  quoted `"true"` or `"false"` (or `"yes"` or `"no"`) is read as the
  matching value with a warning; any other value that is not `true` or
  `false` stops the build with an error that names the key.

- `installer.license_file` no longer fails every build with
  electron-builder’s “unknown property ‘license’” error. The file is
  resolved relative to the app directory, copied into the build, and
  shown as the Windows installer’s license page. A UTF-8 text license
  gets a byte order mark in the copy so the installer shows characters
  such as the copyright sign correctly.

- [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  now fails on configuration errors that stop
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  instead of listing them as warnings, and it checks that
  `installer.license_file` exists.

- Paths in `_shinyelectron.yml` are now resolved against the app
  directory (the suite root for a multi-app suite) as documented, not
  the working directory, so
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  finds them from anywhere. This covers `icon`, `icons`, `splash.image`,
  `tray.icon`, `signing.win.certificate_file`, and the `path` and `icon`
  of each `apps` entry; launcher icons are now copied into the build so
  the launcher can show them. `~` and absolute paths work. The `icon`
  argument of
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  stays relative to the working directory.

- A configured splash image, tray icon, or launcher icon that does not
  exist now gives a warning naming the key and the path checked, instead
  of being skipped silently, and the build uses the default. A missing
  configured app icon stops
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
  as a missing `icon` argument does, and a missing
  `signing.win.certificate_file` warns when a Windows build is signed.
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  checks these files the same way and reports a missing icon as an
  error.

- The system tray icon is no longer blank when `tray.icon` is not set
  and the app icon is not a PNG. The tray looked for an `icon.png` that
  only a PNG app icon provides; it now loads the app icon itself, such
  as an `.ico` file on Windows. Where Electron cannot read the file (an
  `.icns` file, or an `.ico` file on macOS or Linux), or when no icon is
  set, the tray shows a built-in icon of a window outline instead.
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  warns about a tray icon that a target platform cannot read, with a
  warning of class `shinyelectron_tray_icon_unsupported` that suggests
  setting `tray.icon` to a PNG.

- With `updates.auto_download` on, the update notification now says the
  new version is downloading, instead of asking the user to click to
  download.

- An `app_name` with no ASCII letters or digits, such as one written
  only in Chinese characters, no longer stops
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  late in the build; the slug comes from the directory name instead.
  When no slug can be derived, or `app.slug` is invalid,
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  now stops before converting the app, and
  [`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
  no longer fails on a non-ASCII `app.name`.

- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md),
  [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md),
  and
  [`show_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/show_config.md)
  now name the app after its folder when the app directory is a relative
  path such as `"."` or `".."`. The app was named `"."` or `".."`, and
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  and
  [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  stopped because they could not derive an app slug. When `appdir` is
  the path of a symbolic link,
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md),
  [`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md),
  and
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  now take the slug from the link’s name, as
  [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  does, instead of from the folder it points to.
  [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)
  also uses the link’s name in its report, and
  [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  offers it as the default app name.

## shinyelectron 0.2.1

CRAN release: 2026-08-07

- Examples for functions that install a runtime, launch an app, or clear
  the cache now run only in interactive sessions.

- The Download Prebuilt Demos guide moved from a bundled vignette to the
  package website, and outdated external documentation links were
  refreshed.

- [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)
  now requires the `appdir` argument instead of defaulting to the
  working directory.

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
- [`install_r_portable()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_r_portable.md),
  [`install_python_standalone()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_python_standalone.md),
  and
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
- The Electron shell streams the renderer console (webR, Pyodide, and
  Shiny output) into the app log, so browser-side messages and errors
  appear alongside the main-process logs.
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
- [`app_dependencies()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_dependencies.md)
  reports the R or Python packages a Shiny app or multi-app suite uses,
  which helps install an app’s dependencies before a shinylive build.
- Apps can supply a Posit `_brand.yml` for theming.
- Prebuilt demo installers are published for every strategy and
  platform, listed in the new Download Prebuilt Demos article.

### Minor improvements and fixes

- The `runtime_strategy` argument overrides a suite’s
  `build.runtime_strategy` for apps that set no per-app strategy, so a
  suite built as `shinylive` really is shinylive rather than falling
  back to the config default.
- A `_brand.yml` that names palette colors (for example `primary: plum`)
  resolves those references before theming the shell.
- Error screens allow selecting and copying the message and log details.
- Building with the shinylive strategy checks that the app’s R packages
  are installed and names any that are missing, since
  [`shinylive::export()`](https://posit-dev.github.io/r-shinylive/reference/export.html)
  compiles the WebAssembly bundle from installed packages.
- [`build_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/build_electron_app.md)
  refuses to overwrite protected directories such as `~`, `/`, and
  [`R.home()`](https://rdrr.io/r/base/Rhome.html).
- [`convert_shiny_to_shinylive()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/convert_shiny_to_shinylive.md)
  removes its temporary copy on every exit path.
- [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
  cleans up partial output when a build fails, so a retry no longer
  needs `overwrite = TRUE`, for single apps and multi-app suites alike.
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
