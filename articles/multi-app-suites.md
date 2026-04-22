# Multi-App Suites

shinyelectron can bundle multiple Shiny apps – R or Python – into a
single Electron application. Users see a launcher page where they pick
which app to open, and can switch between apps at any time via the
**Apps** menu.

## Directory structure

A multi-app suite is a directory that contains a `_shinyelectron.yml`
config file and an `apps/` folder with one sub-directory per app. Each
sub-directory holds a standard Shiny app (`app.R` for R, `app.py` for
Python).

### R suite

The bundled demo at `inst/demos/demo-r-app-suite/` looks like this:

    demo-r-app-suite/
    ├── _shinyelectron.yml
    └── apps/
        ├── dashboard/
        │   └── app.R
        ├── data-explorer/
        │   └── app.R
        └── about/
            └── app.R

### Python suite

The bundled demo at `inst/demos/demo-py-app-suite/` follows the same
layout with one addition – a `requirements.txt` at the suite root:

    demo-py-app-suite/
    ├── _shinyelectron.yml
    ├── requirements.txt
    └── apps/
        ├── dashboard/
        │   └── app.py
        ├── data-explorer/
        │   └── app.py
        └── about/
            └── app.py

## Configuration

Multi-app mode is activated by including an `apps` array in
`_shinyelectron.yml`. Each entry needs three required fields (`id`,
`name`, `path`) and accepts optional `description`, `type`, and `icon`
fields.

### R suite config

``` yaml
# _shinyelectron.yml
app:
  name: "R Shiny Demo Suite"
  version: "1.0.0"

build:
  type: "r-shiny"
  runtime_strategy: "system"

window:
  width: 1100
  height: 750

apps:
  - id: dashboard
    name: "Dashboard"
    description: "Real-time analytics with live-updating stats and charts"
    path: "./apps/dashboard"

  - id: data-explorer
    name: "Data Explorer"
    description: "Browse and analyze built-in R datasets"
    path: "./apps/data-explorer"

  - id: about
    name: "About"
    description: "System information and runtime details"
    path: "./apps/about"
```

### Python suite config

The Python config is nearly identical – only `build.type` changes:

``` yaml
# _shinyelectron.yml
app:
  name: "Python Shiny Demo Suite"
  version: "1.0.0"

build:
  type: "py-shiny"
  runtime_strategy: "system"

window:
  width: 1100
  height: 750

apps:
  - id: dashboard
    name: "Dashboard"
    description: "Analytics overview with live-updating stats and charts"
    path: "./apps/dashboard"

  - id: data-explorer
    name: "Data Explorer"
    description: "Browse and analyze built-in datasets"
    path: "./apps/data-explorer"

  - id: about
    name: "About"
    description: "System information and runtime details"
    path: "./apps/about"
```

### App entry fields

| Field         | Required | Description                                                  |
|---------------|----------|--------------------------------------------------------------|
| `id`          | Yes      | Unique identifier (used in file paths and the apps manifest) |
| `name`        | Yes      | Display name shown on the launcher card                      |
| `path`        | Yes      | Relative path from the suite root to the app directory       |
| `description` | No       | Short text shown below the name on the launcher card         |
| `type`        | No       | Override the default `build.type` for this specific app      |
| `icon`        | No       | Path to an icon image displayed on the launcher card         |

The default `build.type` from the config applies to every app that does
not specify its own `type`. This means a single suite can mix app types
if needed (e.g., some apps as `r-shinylive`, others as `r-shiny`),
though in practice most suites use a single type throughout.

## Dependency detection

R and Python suites handle dependencies differently.

### R suites: per-app code scanning

For R apps, shinyelectron scans each app directory individually using
[`renv::dependencies()`](https://rstudio.github.io/renv/reference/dependencies.html).
This detects [`library()`](https://rdrr.io/r/base/library.html),
[`require()`](https://rdrr.io/r/base/library.html), and
`package::function()` calls in the app’s source files. Each app gets its
own `dependencies.json` manifest, so only the packages that app actually
uses are recorded.

### Python suites: suite-root requirements.txt

For Python apps, dependencies are read from a single `requirements.txt`
(or `pyproject.toml`) at the **suite root** – not from individual app
directories. All apps in the suite share one virtual environment with
the same set of packages installed.

For example, the demo Python suite uses this `requirements.txt`:

    shiny
    numpy
    matplotlib

This file covers the dependencies for all three apps in the suite.

## Exporting a multi-app suite

The standard
[`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
function handles multi-app suites automatically. When it reads the
config and finds an `apps` array with two or more entries, it switches
to multi-app mode internally.

``` r
library(shinyelectron)

# Export the bundled R demo suite
r_suite <- example_app("suite")
export(appdir = r_suite, destdir = "output-r-suite")

# Export a Python suite from your own project
export(appdir = "path/to/my-py-suite", destdir = "output-py-suite")
```

You do not need to pass `app_type` or `runtime_strategy` – the config
file drives everything. The `build.type` and `build.runtime_strategy`
fields in `_shinyelectron.yml` determine how the suite is built.

All four [runtime
strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.md)
(system, bundled, auto-download, container) work with multi-app suites,
just as they do with single apps.

## Launcher UI and app switching

When the Electron app starts, users see a **launcher page** instead of
loading an app immediately. The launcher displays a card for each app in
the suite, showing the name, description, type badge, and an icon
(either a custom image or a generated initial).

Clicking a card starts the backend for that app and navigates to it.
While using any app, the **Apps** menu in the menu bar provides a “Back
to Launcher” option that stops the current backend and returns to the
launcher page.

### How the runtime works

All apps in a suite share a single runtime process (one R or Python
instance). When the user switches from one app to another:

1.  The current backend process is stopped.
2.  The launcher page is shown.
3.  The user selects the next app.
4.  A new backend process starts for the selected app.

This means only one app runs at a time, keeping resource usage low.
There is no need to install multiple runtimes or manage parallel
processes.

## Creating your own suite

To create a multi-app suite from scratch:

1.  Create a directory with an `apps/` sub-folder.
2.  Add each Shiny app as its own sub-directory under `apps/`.
3.  Write a `_shinyelectron.yml` with the `apps` array listing every
    app.
4.  For Python suites, place a `requirements.txt` at the suite root.
5.  Run
    [`export()`](https://r-pkg.thecoatlessprofessor.com/shinyelectron/reference/export.md)
    pointing at the suite directory.

``` r
# Minimal example: create suite structure, then export
export(appdir = "my-suite", destdir = "my-suite-output")
```

The config file is the single source of truth. As long as the `apps`
array has at least two entries and each entry points to a valid Shiny
app directory, shinyelectron will build the multi-app Electron
application with the launcher UI and app-switching support.
