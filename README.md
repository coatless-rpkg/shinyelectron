# shinyelectron

<!-- badges: start -->
[![R-CMD-check](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Export [Shiny](https://shiny.posit.co/) applications as standalone desktop applications using [Electron](https://www.electronjs.org/). Supports R and Python Shiny apps with multiple runtime strategies.

## Installation

```r
# install.packages("remotes")
remotes::install_github("coatless-rpkg/shinyelectron")
```

## Quick Start

```r
library(shinyelectron)

# Validate your app before building
app_check("path/to/my/app")

# Export as a desktop app (shinylive — runs entirely in browser, no runtime needed)
export(
  appdir = "path/to/my/app",
  destdir = "output"
)

# Or use native R with system runtime
export(
  appdir = "path/to/my/app",
  destdir = "output",
  app_type = "r-shiny",
  runtime_strategy = "system"
)
```

## App Types

| Type | Description | Runtime needed? |
|------|-------------|-----------------|
| `r-shinylive` | R Shiny via WebR in browser | No |
| `py-shinylive` | Python Shiny via Pyodide in browser | No |
| `r-shiny` | Native R Shiny | Yes (R) |
| `py-shiny` | Native Python Shiny | Yes (Python) |

## Runtime Strategies (Native Apps)

| Strategy | Description | Best for |
|----------|-------------|----------|
| `auto-download` | Downloads R/Python on first launch | Default, zero-config |
| `system` | Uses R/Python on user's machine | Dev/testing |
| `bundled` | Embeds portable R/Python in the app | Self-contained distribution |
| `container` | Runs in Docker/Podman | Reproducible environments |

## Configuration

Use the interactive wizard or create a config file manually:

```r
# Interactive wizard
wizard("path/to/my/app")

# Or create a template config file
init_config("path/to/my/app")

# View effective configuration
show_config("path/to/my/app")
```

### `_shinyelectron.yml` example

```yaml
app:
  name: "My Dashboard"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "auto-download"
  platforms:
    - mac
    - win

window:
  width: 1200
  height: 800
```

## Multi-App Bundling

Bundle multiple Shiny apps into one desktop application with a launcher:

```yaml
# _shinyelectron.yml
app:
  name: "My App Suite"
build:
  type: "r-shiny"
  runtime_strategy: "system"
apps:
  - id: dashboard
    name: "Dashboard"
    path: "./apps/dashboard"
  - id: explorer
    name: "Data Explorer"
    path: "./apps/explorer"
```

## Key Functions

| Function | Purpose |
|----------|---------|
| `export()` | Convert and build Shiny app to Electron |
| `available_examples()` | Show bundled example apps |
| `example_app()` | Get path to a bundled example app |
| `app_check()` | Pre-flight validation without building |
| `wizard()` | Interactive configuration generator |
| `show_config()` | Display merged effective configuration |
| `init_config()` | Create template `_shinyelectron.yml` |
| `sitrep_shinyelectron()` | Full system diagnostics |
| `install_nodejs()` | Install Node.js locally (no admin needed) |
| `enable_auto_updates()` | Configure auto-update via GitHub Releases |
| `run_electron_app()` | Launch a built Electron app for testing |
| `cache_clear()` | Clear cached Node.js/R/Python/npm assets |

## Demos

```r
# List bundled examples
available_examples()

# Get an example app and export with any app_type + strategy
path <- example_app("r")
export(path, "my-output", app_type = "r-shiny", runtime_strategy = "system")

path <- example_app("python")
export(path, "py-output", app_type = "py-shiny", runtime_strategy = "system")
```

## System Requirements

- R >= 4.4.0
- Node.js >= 18.0.0 (auto-installable via `install_nodejs()`)
- Platform build tools:
  - macOS: Xcode Command Line Tools (`xcode-select --install`)
  - Windows: Visual Studio Build Tools
  - Linux: build-essential

## License

AGPL (>= 3)
