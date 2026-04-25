# Getting Started with shinyelectron

Ship a Shiny app as a desktop application. R or Python, macOS, Windows,
or Linux. Your users double-click an `.app`, `.exe`, or AppImage. No
server, no browser tab, no deployment.

![Flow diagram showing three steps: Shiny App containing app.R or app.py
passes through shinyelectron (convert and package via electron-builder)
to produce a Desktop App distributed as .app, .exe, or
AppImage.](../reference/figures/pipeline-overview.svg)

The shinyelectron export pipeline: a Shiny app (R or Python) is
converted and packaged into a standalone desktop application.

## Install the package

shinyelectron is not on CRAN yet. Install it from GitHub with pak.

``` r
install.packages("pak")
pak::pak("coatless-rpkg/shinyelectron")
```

## Run a pre-flight check

Diagnose before you build. It saves hours later.

``` r
library(shinyelectron)
sitrep_shinyelectron()
```

[`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md)
verifies Node.js (\>= 22.0.0), npm, required R packages, Python, and
platform build tools. If Node.js is missing, install it locally without
admin rights.

``` r
install_nodejs()
```

## Build a demo end to end

Ship a bundled example before touching your own app. It confirms the
toolchain works.

``` r
# List available demos
available_examples()

# Export the R single-app demo to your Desktop
export(
  appdir = example_app("r-single"),
  destdir = "~/Desktop/my-first-app",
  run_after = TRUE
)
```

One call converts the demo to shinylive, wraps it in Electron, builds a
distributable, and launches it. Roughly a minute on a small app.

## Export your Shiny app

### Shinylive: runs in the browser

The default runtime strategy compiles your app to WebAssembly. R uses
WebR. Python uses Pyodide. Either way, the app runs in the browser, and
the browser runs inside Electron. The user installs nothing.

Use this strategy whenever your dependencies allow it. shinyelectron
detects the app language from the files in `appdir`, so you usually only
need to point at the directory.

``` r
# R (language autodetected from app.R, shinylive is the default strategy)
export(
  appdir = "path/to/my-app",       # directory containing app.R
  destdir = "my-electron-app",
  app_name = "My App"
)

# Python (language autodetected from app.py)
export(
  appdir = "path/to/my-py-app",    # directory containing app.py
  destdir = "my-py-electron-app",
  app_name = "My App"
)
```

### Native: runs a real R or Python process

Some packages do not compile to WebAssembly. For those, spawn a real R
or Python process behind the Electron window by picking a non-shinylive
`runtime_strategy`.

``` r
# R Shiny with auto-download (downloads R on first launch)
export(
  appdir = "path/to/my-app",
  destdir = "my-native-app",
  runtime_strategy = "auto-download"
)

# Python Shiny with a bundled runtime (ships Python inside the app)
export(
  appdir = "path/to/my-py-app",
  destdir = "my-bundled-py-app",
  runtime_strategy = "bundled"
)
```

![Architecture diagram comparing three modes. Shinylive: Electron window
contains a Chromium browser running WebR or Pyodide with the app
compiled to WebAssembly. Native: Electron window loads localhost, a
child R or Python process runs the Shiny server, runtime sourced from
bundled, auto-download, or system install. Container: Electron window
loads localhost, a Docker or Podman container runs the app with full
isolation and all system
dependencies.](../reference/figures/app-types.svg)

Three execution modes: Shinylive runs entirely in-browser, Native spawns
a real R or Python process, and Container runs inside Docker or Podman.

## Choose an app type and runtime strategy

Two dials drive every shinyelectron build: the app language (`app_type`)
and how the runtime reaches the user (`runtime_strategy`). shinyelectron
autodetects `app_type` from the files in `appdir`, so you usually set
only the strategy.

| App Type   | Entry File | Best For          |
|------------|------------|-------------------|
| `r-shiny`  | `app.R`    | R Shiny apps      |
| `py-shiny` | `app.py`   | Python Shiny apps |

`runtime_strategy` decides how your code actually runs. All five
strategies work with both `r-shiny` and `py-shiny`.

| Strategy        | Behavior                                     | App Size        | First Launch         | Best For                                                |
|-----------------|----------------------------------------------|-----------------|----------------------|---------------------------------------------------------|
| `shinylive`     | Compiles app to WebAssembly, runs in-browser | Medium          | Instant, offline     | Simple apps whose deps run in WebR or Pyodide (default) |
| `auto-download` | Downloads R/Python on first launch           | Small           | Needs internet       | Public distribution, smaller download                   |
| `bundled`       | Ships R/Python inside the app                | Large (~200MB+) | Instant, offline     | Public distribution, offline first run                  |
| `system`        | Uses R/Python already installed              | Smallest        | Requires pre-install | Internal tools for users who already have R or Python   |
| `container`     | Runs inside Docker/Podman                    | Small           | Needs Docker         | Complex system dependencies, reproducibility            |

See [Runtime
Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
for when to pick each.

## What export produces

[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
writes two siblings into `destdir`: the prepared app and the Electron
project that wraps it. The app is then copied into
`electron-app/src/app/`, which is the path Electron actually loads at
runtime.

    my-electron-app/
    ├── shinylive-app/          # shinylive strategy: WebAssembly bundle
    │   (or shiny-app/)         # other strategies: app source plus a manifest
    └── electron-app/
        ├── src/app/            # Copy of the sibling above (what Electron loads)
        ├── main.js             # Electron entry point
        ├── renderer.html
        ├── package.json
        ├── node_modules/
        └── dist/               # Ready-to-distribute binaries
            ├── mac-arm64/
            │   └── My App.app
            ├── win-x64/
            │   └── My App Setup.exe
            └── linux-x64/
                └── My App.AppImage

Ship `dist/`. The rest is build scaffolding, though the sibling app
directory is useful when you want to inspect exactly what Electron is
serving.

## Build for several platforms in one call

Pass vectors to `platform` and `arch` to produce several targets in one
call.

``` r
export(
  appdir = "my-app",
  destdir = "my-electron-app",
  platform = c("mac", "win", "linux"),
  arch = c("x64", "arm64"),
  overwrite = TRUE
)
```

Not every combination is portable. Two rules to keep in mind:

- **macOS apps build only on macOS.** Apple’s signing and `.app`
  packaging run through native tools. Windows and Linux will
  cross-compile from macOS, but each platform’s own native build is more
  reliable.
- **The `bundled` runtime strategy needs a matching host.** A bundled
  app embeds a platform-specific R or Python binary at build time, so
  exporting for Windows requires building on Windows, and the same for
  macOS and Linux. `auto-download`, `system`, and `container` sidestep
  this: the runtime is fetched, found, or isolated at launch instead of
  at build, so any host can target any platform.

In practice, if you want a single workstation to emit installers for
every OS, reach for auto-download or container. If you want bundled
everywhere, hand the job to CI (see the [GitHub
Actions](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/github-actions.md)
article).

## Give the app a custom icon

Point `icon` at a single file. Each platform wants its own format:
`.icns` for macOS, `.ico` for Windows, `.png` for Linux.

``` r
export(
  appdir = "my-app",
  destdir = "my-electron-app",
  icon = "icon.icns"
)
```

## Capture build settings in a config file

Once your build options are settled, move them out of the function call
and into `_shinyelectron.yml` alongside your app.

``` r
init_config("my-app")
```

``` yaml
app:
  name: "My Dashboard"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "bundled"
  platforms: [mac, win]
```

[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
picks it up automatically.

``` r
export(appdir = "my-app", destdir = "output")
```

See the [Configuration
Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)
for every option.

## Where to go next

- [Configuration
  Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md):
  every `_shinyelectron.yml` option
- [Runtime
  Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md):
  bundled, system, auto-download, container
- [Multi-App
  Suites](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/multi-app-suites.md):
  bundle several apps in one shell
- [Code
  Signing](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md):
  sign for macOS GateKeeper and Windows SmartScreen
- [Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.md):
  common issues and fixes

## Function cheat sheet

| Function                                                                                                           | Purpose                                 |
|--------------------------------------------------------------------------------------------------------------------|-----------------------------------------|
| [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)                             | Convert and build Shiny app to Electron |
| [`app_check()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/app_check.md)                       | Pre-flight validation without building  |
| [`wizard()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/wizard.md)                             | Interactive config generator            |
| [`sitrep_shinyelectron()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/sitrep_shinyelectron.md) | Full system diagnostics                 |
| [`install_nodejs()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/install_nodejs.md)             | Install Node.js locally                 |
| [`available_examples()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/available_examples.md)     | List bundled demo apps                  |
| [`example_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/example_app.md)                   | Get path to a demo app                  |
| [`run_electron_app()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/run_electron_app.md)         | Launch a built Electron app             |
| [`cache_clear()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/cache_clear.md)                   | Clear cached runtimes and assets        |
