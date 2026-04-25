# Configuration Guide

A `_shinyelectron.yml` file keeps your build settings next to your app.
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
reads it automatically, so the function call stays short and the details
live in version control where the rest of the project already does.

![Overview of the \_shinyelectron.yml configuration file. A title bar at
the top reads \_shinyelectron.yml. Below it, eight labeled cards
arranged in two rows describe the main sections: app (display name and
version), build (language, runtime strategy, target platforms and
architectures), window (Electron window size), server (local Shiny
port), icon (app icon, one PNG fanned out per OS), nodejs (build
toolchain version and auto-install), r and python (runtime version for
bundled and auto-download strategies), and container (Docker or Podman
engine and image for the container strategy). A wider card underneath
describes apps, the optional multi-app suite, where each entry may
override the suite-level type or runtime_strategy so shinylive apps can
coexist with bundled or system apps in the same
build.](../reference/figures/config-overview.svg)

Every `_shinyelectron.yml` section at a glance: nine knobs that shape a
different part of the build, from app metadata and target platforms down
to the runtime and the optional multi-app launcher.

## Why use one

Compare a fully specified call:

``` r
export(
  appdir = "my-app",
  destdir = "output",
  app_name = "My Application",
  app_type = "r-shiny",
  runtime_strategy = "shinylive",
  platform = c("mac", "win"),
  arch = c("x64", "arm64"),
  icon = "icons/icon.png"
)
```

With the same build driven by config:

``` r
export(appdir = "my-app", destdir = "output")
```

A config file pulls double duty. It is a set of arguments to
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md),
but it is also a short document telling anyone who clones the repo how
the app is meant to be built.

## Getting a config file in place

The config file must be named `_shinyelectron.yml` and live at the root
of your app directory:

    my-shiny-app/
    ├── _shinyelectron.yml    # Configuration file
    ├── app.R                 # Your Shiny app
    └── ...

Generate a starter template with
[`init_config()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/init_config.md):

``` r
init_config("path/to/my-app")
```

    ✔ Created configuration file: path/to/my-app/_shinyelectron.yml
    ℹ Edit this file to customize your Electron app settings

The generated file carries the documented defaults you can edit in
place. For most projects, the only settings you need to write yourself
are the app name and whether to auto-install Node.js:

``` yaml
app:
  name: "My App"

nodejs:
  auto_install: true
```

Everything else is filled in by defaults described below.

## Complete reference

Every available option, annotated. Each section is covered in more
detail further down.

``` yaml
# shinyelectron configuration file
# Documentation: https://r-pkg.thecoatlessprofessor.com/shinyelectron/

app:
  name: "My Application"     # Application display name
  version: "1.0.0"           # Application version (used in package metadata)

build:
  type: "r-shiny"            # Application language (autodetected if omitted)
  runtime_strategy: "shinylive"  # shinylive, auto-download, bundled, system, container
  platforms:                 # Target platforms
    - mac
    - win
    - linux
  architectures:             # Target architectures
    - x64
    - arm64

r:
  version: null              # R version for bundled/auto-download (null = latest release)

python:
  version: null              # Python version for bundled/auto-download (null = "3.12.10")

window:
  width: 1200                # Default window width (pixels)
  height: 800                # Default window height (pixels)

server:
  port: 3838                 # Development server port

icon: "branding/icon.png"    # Single high-res source; electron-builder fans out to each platform

# Optional per-platform icon overrides (rarely needed):
# icons:
#   mac: "branding/icon.icns"
#   win: "branding/icon.ico"
#   linux: "branding/icon.png"

nodejs:
  version: null              # Node.js version (null = latest LTS)
  auto_install: false        # Auto-install Node.js if not found

container:                   # Used when runtime_strategy is "container"
  engine: "docker"           # "docker" or "podman"
  image: null                # Container image (null = auto-select)
  tag: "latest"
  pull_on_start: true        # Pull latest image on app start
  volumes: []                # Additional volume mounts
  env: []                    # Additional environment variables

# Multi-app suite (2+ apps packaged in one Electron shell)
# apps:
#   - id: "dashboard"
#     name: "Dashboard"
#     path: "./apps/dashboard"
#     type: "r-shiny"                   # Optional per-app override (default: build.type)
#     runtime_strategy: "shinylive"     # Optional per-app override (default: build.runtime_strategy)
#     description: "Main dashboard"
#     icon: "icons/dash.png"
#   - id: "admin"
#     name: "Admin Panel"
#     path: "./apps/admin"
```

> **How values get resolved**
>
> When
> [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
> runs, it merges three sources in priority order:
>
> 1.  **Function arguments** passed directly to
>     [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
> 2.  **Config file** values from `_shinyelectron.yml`
> 3.  **Built-in defaults**
>
> A function argument always wins. So
> `export(appdir = "app", destdir = "out", app_name = "Override")` uses
> `"Override"` even if the config file says something else, and
> everything else falls through to the config or the defaults.

## Section reference

### `app`

Application metadata.

| Key       | Type   | Default        | Description                                   |
|-----------|--------|----------------|-----------------------------------------------|
| `name`    | string | Directory name | Display name shown in window title and system |
| `version` | string | `"1.0.0"`      | Version number for the built application      |

### `build`

The build process and its targets.

| Key                | Type   | Default          | Description                                                                       |
|--------------------|--------|------------------|-----------------------------------------------------------------------------------|
| `type`             | string | autodetect       | Application language (see below). Autodetected from files in `appdir` if omitted. |
| `runtime_strategy` | string | `"shinylive"`    | How the app’s runtime reaches the user (see below)                                |
| `platforms`        | list   | Current platform | Target operating systems: `mac`, `win`, `linux`                                   |
| `architectures`    | list   | Current arch     | Target CPU architectures: `x64`, `arm64`                                          |

**Valid `type` values:** `r-shiny` (an `app.R` or `ui.R`/`server.R`
Shiny app) or `py-shiny` (an `app.py` Shiny for Python app).

**Valid `runtime_strategy` values:**

| Strategy        | Description                                                               |
|-----------------|---------------------------------------------------------------------------|
| `shinylive`     | Compiles to WebAssembly and runs in-browser via WebR or Pyodide (default) |
| `auto-download` | Downloads R or Python on first launch, caches for reuse                   |
| `bundled`       | Embeds a portable R or Python runtime inside the app at build time        |
| `system`        | Uses R or Python already installed on the end user’s machine              |
| `container`     | Runs the app inside a Docker or Podman container                          |

All five strategies work with both `r-shiny` and `py-shiny`. See the
[Runtime
Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
vignette for the full discussion.

> **Cross-platform caveats**
>
> macOS apps build only on macOS. The `bundled` strategy ships a
> platform-specific runtime binary, so exporting for Windows from macOS
> is not supported for bundled builds. `auto-download`, `system`, and
> `container` sidestep that constraint. See the Runtime Strategies
> vignette for the full story.

### `icon` and `icons`

A single top-level `icon` entry is the simplest and recommended shape.
Point it at a high-resolution PNG (1024×1024 or larger) and
electron-builder will generate the per-platform variants it needs
(`.icns` for macOS, `.ico` for Windows, and the PNG itself for Linux).

``` yaml
icon: "branding/icon.png"
```

If you genuinely need different artwork on different platforms (for
example, a monochrome Windows icon alongside a full-color macOS icon),
use the per-platform `icons` map as an override:

| Key     | Type   | Format  | Description                                 |
|---------|--------|---------|---------------------------------------------|
| `mac`   | string | `.icns` | macOS icon (typically 512×512 or larger)    |
| `win`   | string | `.ico`  | Windows icon (multi-resolution recommended) |
| `linux` | string | `.png`  | Linux icon (512×512 recommended)            |

Paths are relative to the app directory. When no icon is set at all, the
build uses the default Electron icon.

> **Creating icons**
>
> Start from one 1024×1024 PNG. That single file is enough for the
> default `icon:` path; electron-builder handles the conversions. If you
> need hand-tuned `.icns` or `.ico` artwork, convert with
> [iconutil](https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html)
> on macOS, [ImageMagick](https://imagemagick.org/), or any online
> converter.

### `window`

Electron window dimensions.

| Key      | Type    | Default | Description                           |
|----------|---------|---------|---------------------------------------|
| `width`  | integer | `1200`  | Window width in pixels (minimum 100)  |
| `height` | integer | `800`   | Window height in pixels (minimum 100) |

### `server`

Development server settings.

| Key    | Type    | Default | Description                                  |
|--------|---------|---------|----------------------------------------------|
| `port` | integer | `3838`  | Port for the local Shiny server (1 to 65535) |

### `nodejs`

Node.js installation behavior.

| Key            | Type    | Default | Description                                      |
|----------------|---------|---------|--------------------------------------------------|
| `version`      | string  | `null`  | Node.js version to install (`null` = latest LTS) |
| `auto_install` | boolean | `false` | Auto-install Node.js if not found                |

Auto-install is off by default. Set `auto_install: true` explicitly to
let
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
install Node.js for you when it is missing.

### `r`

Pins R for the `bundled` and `auto-download` runtime strategies. Ignored
otherwise.

| Key       | Type   | Default | Description                                                |
|-----------|--------|---------|------------------------------------------------------------|
| `version` | string | `null`  | R version (e.g. `"4.4.1"`); `null` uses the latest release |

### `python`

Pins Python for the `bundled` and `auto-download` runtime strategies.
Ignored otherwise.

| Key       | Type   | Default | Description                                                       |
|-----------|--------|---------|-------------------------------------------------------------------|
| `version` | string | `null`  | Python version (e.g. `"3.12.10"`); `null` resolves to `"3.12.10"` |

### `container`

Used when `runtime_strategy` is `"container"`. Ignored otherwise.

| Key             | Type    | Default    | Description                                                     |
|-----------------|---------|------------|-----------------------------------------------------------------|
| `engine`        | string  | `"docker"` | Container engine: `"docker"` or `"podman"`                      |
| `image`         | string  | `null`     | Container image name (`null` = auto-select based on `app.type`) |
| `tag`           | string  | `"latest"` | Image tag                                                       |
| `pull_on_start` | boolean | `true`     | Pull the latest image when the app starts                       |
| `volumes`       | list    | `[]`       | Additional volume mounts                                        |
| `env`           | list    | `[]`       | Additional environment variables                                |

**Example:**

``` yaml
container:
  engine: "docker"
  image: "rocker/shiny"
  tag: "4.4.1"
  pull_on_start: true
  volumes:
    - "/data:/app/data:ro"
  env:
    - "SHINY_LOG_LEVEL=DEBUG"
```

### `apps`

Defines a multi-app suite: two or more Shiny apps packaged in one
Electron shell with a launcher screen. At least two entries are
required. Any entry can override `build.type` or
`build.runtime_strategy`, which is how mixed-strategy suites work.

| Key                | Type   | Required | Description                                                   |
|--------------------|--------|----------|---------------------------------------------------------------|
| `id`               | string | yes      | Unique identifier (URL-safe)                                  |
| `name`             | string | yes      | Display name in the launcher                                  |
| `path`             | string | yes      | Relative path to the app directory                            |
| `type`             | string | no       | App type override (default: `build.type`)                     |
| `runtime_strategy` | string | no       | Runtime strategy override (default: `build.runtime_strategy`) |
| `description`      | string | no       | Short description shown in the launcher                       |
| `icon`             | string | no       | Per-app icon path                                             |

**Example:**

``` yaml
apps:
  - id: "dashboard"
    name: "Dashboard"
    path: "./apps/dashboard"
    description: "Sales analytics dashboard"
  - id: "admin"
    name: "Admin Panel"
    path: "./apps/admin"
    type: "py-shiny"
    description: "User management"
```

See the [Multi-App
Suites](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/multi-app-suites.md)
vignette for mixed-strategy examples and launcher customization.

## Common recipes

### Development setup

Fast iteration while you work:

``` yaml
app:
  name: "My App (Dev)"
  version: "0.0.1"

window:
  width: 1000
  height: 700

nodejs:
  auto_install: true
```

### Production multi-platform build

For distribution across platforms:

``` yaml
app:
  name: "Production App"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "shinylive"
  platforms:
    - mac
    - win
    - linux
  architectures:
    - x64
    - arm64

window:
  width: 1200
  height: 800

icon: "branding/icon.png"

nodejs:
  version: "22.11.0"
  auto_install: false
```

### Native R app with bundled runtime

Ship R inside the app:

``` yaml
app:
  name: "Analytics Tool"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "bundled"
  platforms:
    - mac
    - win

r:
  version: "4.4.1"

nodejs:
  auto_install: true
```

### Multi-app suite

Several apps behind one launcher:

``` yaml
app:
  name: "My App Suite"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "auto-download"

apps:
  - id: "dashboard"
    name: "Dashboard"
    path: "./apps/dashboard"
    description: "Sales analytics"
  - id: "admin"
    name: "Admin Panel"
    path: "./apps/admin"
    type: "py-shiny"
    description: "User management"

nodejs:
  auto_install: true
```

## What happens when a value is invalid

shinyelectron validates values on read and degrades gracefully rather
than aborting the build:

- Invalid `type` values warn and fall back to autodetect.
- Invalid `runtime_strategy` values warn and fall back to `shinylive`.
- Invalid platforms and architectures are dropped with a warning.
- Window dimensions under 100 pixels warn and use defaults.
- Invalid port numbers warn and use `3838`.

If the YAML itself fails to parse, shinyelectron warns and uses all
defaults. This is deliberate: a broken config file should never block
you from producing a build during development.

## Next steps

- **[Getting
  Started](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/getting-started.md)**:
  first-time user walkthrough.
- **[Runtime
  Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)**:
  deep dive on `build.runtime_strategy`.
- **[Node.js
  Management](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/nodejs-management.md)**:
  managing a local Node.js install.
- **[Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.md)**:
  diagnosing build issues.
