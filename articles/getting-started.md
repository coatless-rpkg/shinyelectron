# Getting Started with shinyelectron

Turn any Shiny app — R or Python — into a standalone desktop application
that runs on macOS, Windows, and Linux. No web server, no browser tab,
no deployment infrastructure. Just an `.app`, `.exe`, or AppImage your
users double-click to open.

![Flow diagram showing three steps: Shiny App containing app.R or app.py
passes through shinyelectron (convert and package via electron-builder)
to produce a Desktop App distributed as .app, .exe, or
AppImage.](../reference/figures/pipeline-overview.svg)

The shinyelectron export pipeline: a Shiny app (R or Python) is
converted and packaged into a standalone desktop application.

## Install

``` r
install.packages("pak")
pak::pak("coatless-rpkg/shinyelectron")
```

## Check your system

``` r
library(shinyelectron)
sitrep_shinyelectron()
```

This checks Node.js (\>= 22.0.0), npm, R packages, Python availability,
and platform build tools. If Node.js is missing, install it locally — no
admin rights needed:

``` r
install_nodejs()
```

## Try a demo

The fastest way to see shinyelectron in action is with a bundled demo:

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

This converts the demo to shinylive format, wraps it in Electron, builds
a distributable, and opens the app. The whole process takes about a
minute.

## Export your own app

### Shinylive (browser-based)

The default path converts your Shiny app to run entirely inside the
browser via WebR (R) or Pyodide (Python). WebR compiles R to WebAssembly
so it runs directly in the browser. Pyodide does the same for Python.
The end user needs nothing installed — everything is self-contained.

- [R](#tabset-1-1)
- [Python](#tabset-1-2)

&nbsp;

- ``` r
  export(
    appdir = "path/to/my-app",       # directory containing app.R
    destdir = "my-electron-app",
    app_name = "My App"
  )
  ```

``` r
export(
  appdir = "path/to/my-py-app",    # directory containing app.py
  destdir = "my-py-electron-app",
  app_name = "My App",
  app_type = "py-shinylive"
)
```

### Native (runtime-based)

Some R and Python packages don’t work in WebAssembly. For full
compatibility, use the native path — your app runs in a real R or Python
process instead of in the browser.

``` r
# R Shiny with auto-download (default: downloads R on first launch)
export(
  appdir = "path/to/my-app",
  destdir = "my-native-app",
  app_type = "r-shiny"
)

# Python Shiny with bundled runtime (ships Python inside the app)
export(
  appdir = "path/to/my-py-app",
  destdir = "my-bundled-py-app",
  app_type = "py-shiny",
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

## Choosing an app type

The key distinction: shinylive apps run entirely in the browser (no
server needed), while native apps talk to a real R or Python process
behind the scenes.

| App Type       | Entry File | Runs In           | User Needs          | Best For                    |
|----------------|------------|-------------------|---------------------|-----------------------------|
| `r-shinylive`  | `app.R`    | Browser (WebR)    | Nothing             | Simple R apps               |
| `py-shinylive` | `app.py`   | Browser (Pyodide) | Nothing             | Simple Python apps          |
| `r-shiny`      | `app.R`    | R process         | R (or bundled)      | Full R package support      |
| `py-shiny`     | `app.py`   | Python process    | Python (or bundled) | Full Python package support |

For native app types, the `runtime_strategy` controls how the runtime
reaches the end user:

| Strategy        | How it Works                         | App Size        | First Launch         |
|-----------------|--------------------------------------|-----------------|----------------------|
| `auto-download` | Downloads R/Python on first launch   | Small           | Needs internet       |
| `bundled`       | Ships R/Python inside the app        | Large (~200MB+) | Instant, offline     |
| `system`        | Uses R/Python already on the machine | Smallest        | Requires pre-install |
| `container`     | Runs inside Docker/Podman            | Small           | Needs Docker         |

See [Runtime
Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
for a deep dive on each.

## What you get

After export, your destination directory looks like this:

    my-electron-app/
    ├── shinylive-app/          # Converted app (shinylive types only)
    └── electron-app/
        ├── src/app/            # Your application files
        ├── main.js             # Electron shell
        ├── package.json
        ├── node_modules/
        └── dist/               # Ready-to-distribute binaries
            ├── mac-arm64/
            │   └── My App.app
            ├── win-x64/
            │   └── My App Setup.exe
            └─��� linux-x64/
                └── My App.AppImage

## Build for multiple platforms

``` r
export(
  appdir = "my-app",
  destdir = "my-electron-app",
  platform = c("mac", "win", "linux"),
  arch = c("x64", "arm64"),
  overwrite = TRUE
)
```

> **Note**
>
> macOS apps can only be built on macOS. Windows and Linux apps can be
> cross-compiled from macOS, but native builds are more reliable.

## Add a custom icon

``` r
export(
  appdir = "my-app",
  destdir = "my-electron-app",
  icon = "icon.icns"   # .icns (macOS), .ico (Windows), .png (Linux)
)
```

## Use a configuration file

For repeated builds, create a `_shinyelectron.yml` in your app directory
instead of passing parameters every time:

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

Then export reads the config automatically:

``` r
export(appdir = "my-app", destdir = "output")
```

See the [Configuration
Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)
for all available options.

## Next steps

- [Configuration
  Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.md)
  — all `_shinyelectron.yml` options
- [Runtime
  Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
  — bundled vs system vs auto-download vs container
- [Multi-App
  Suites](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/multi-app-suites.md)
  — bundle multiple apps in one shell
- [Code
  Signing](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.md)
  — sign your app for macOS GateKeeper and Windows SmartScreen
- [Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.md)
  — common issues and fixes

## Quick reference

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
