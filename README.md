

<!-- README.md is generated from README.qmd. Please edit that file -->

# shinyelectron

<!-- badges: start -->

[![R-CMD-check](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml)
![Prototype](https://img.shields.io/badge/Status-Prototype-orange.png)
![Experimental](https://img.shields.io/badge/Status-Experimental-blue.png)
<!-- badges: end -->

Turn any Shiny app — R or Python — into a standalone desktop application
that runs on macOS, Windows, and Linux. No web server, no browser tab,
no deployment infrastructure. Just an `.app`, `.exe`, or AppImage your
users double-click to open.

![](man/figures/pipeline-overview.svg)

> [!IMPORTANT]
>
> This package is currently in the prototype/experimental stage. It is
> not yet on CRAN and may have rough edges. **Not recommended for
> production applications at this time.**

## Install

``` r
# install.packages("pak")
pak::pak("coatless-rpkg/shinyelectron")
```

## Quick start

``` r
library(shinyelectron)

# Check your system
sitrep_shinyelectron()

# Try a bundled demo
export(
  appdir  = example_app("r-single"),
  destdir = "~/Desktop/my-first-app",
  run_after = TRUE
)
```

That’s the whole workflow: one call converts your app, wraps it in
Electron, builds a distributable, and launches it. Takes about a minute
for a small app.

## What you can export

| App Type | Runs In | User Needs | Best For |
|----|----|----|----|
| `r-shinylive` | Browser (WebR) | Nothing | Simple R apps |
| `py-shinylive` | Browser (Pyodide) | Nothing | Simple Python apps |
| `r-shiny` | R process | R (or bundled) | Full R package support |
| `py-shiny` | Python process | Python (or bundled) | Full Python package support |

Native types (`r-shiny` / `py-shiny`) support four **runtime
strategies** for delivering R or Python to the end user: `auto-download`
(default), `bundled`, `system`, or `container`. See the [Runtime
Strategies
guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.html)
for the decision matrix.

## Prerequisites

- **R** (\>= 4.4.0)
- **Node.js** (\>= 22.0.0) — install locally with `install_nodejs()`
- **npm** (\>= 11.5.0) — included with Node.js

Platform build tools:

| Platform | Requirement                   |
|----------|-------------------------------|
| macOS    | Xcode Command Line Tools      |
| Windows  | Visual Studio Build Tools     |
| Linux    | `build-essential` (gcc, make) |

## Learn more

- [Getting
  Started](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/getting-started.html)
  — step-by-step tutorial
- [Configuration
  Guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/configuration.html)
  — `_shinyelectron.yml` reference
- [Runtime
  Strategies](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.html)
  — bundled vs system vs auto-download vs container
- [Multi-App
  Suites](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/multi-app-suites.html)
  — bundle multiple apps in one shell
- [Code
  Signing](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/code-signing.html)
  — macOS GateKeeper and Windows SmartScreen
- [Troubleshooting](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/troubleshooting.html)
  — common issues and fixes

## Acknowledgements

This project builds on several prior efforts to package Shiny apps as
desktop applications:

- [electricShine](https://chasemc.github.io/electricShine/) — automated
  Windows builds via `electrify()`.
- [Photon](https://github.com/COVAIL/photon) — RStudio add-in that
  bundles Shiny apps with portable R.
- [RInno](https://github.com/ficonsulting/RInno) — standalone R app
  builder for Windows.
- [DesktopDeployR](https://github.com/wleepang/DesktopDeployR) —
  self-contained R deployment framework.
- [Electron ShinyApp
  Deployment](https://www.youtube.com/watch?v=ARrbbviGvjc) — @ksasso’s
  2018 UseR! talk.
- [Developer
  tutorials](https://github.com/lawalter/r-shiny-electron-app) from
  @lawalter and @dirkschumacher.
- [Zarathu Corporation
  templates](https://github.com/zarathucorp/shiny-electron-template-m1)
  for macOS ARM and Windows.

## License

AGPL (\>= 3)
