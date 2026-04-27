

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

shinyelectron supports two app types, autodetected from the contents of
your `appdir`:

- `r-shiny`: detected from `app.R` or `ui.R` + `server.R`
- `py-shiny`: detected from `app.py`

Both types work with five **runtime strategies** for delivering the app
to the end user:

| Strategy | What Ships | First Launch | User Needs | Best For |
|----|----|----|----|----|
| `shinylive` | Electron + WASM bundle | Instant, offline | Nothing | Simple apps; deps that run in WebR or Pyodide (default) |
| `bundled` | Electron + R/Python runtime | Instant, offline | Nothing | Offline distribution; predictable runtime |
| `auto-download` | Electron + downloader | Needs internet | Nothing | Public distribution; smaller download |
| `system` | Electron only | Finds R/Python on PATH | R or Python pre-installed | Internal tools for users who already have R or Python |
| `container` | Electron + container config | Needs Docker | Docker or Podman | Complex system deps; reproducibility |

`shinylive` is the default when `runtime_strategy` is not set. See the
[Runtime Strategies
guide](https://r-pkg.thecoatlessprofessor.com/shinyelectron/articles/runtime-strategies.html)
for the full decision matrix.

> [!NOTE]
>
> **Linux note for `r-shiny`:** the `bundled` and `auto-download`
> strategies rely on the [portable-r](https://github.com/portable-r)
> project, which currently publishes builds for macOS and Windows only.
> On Linux, use `shinylive`, `system` (the user has R installed), or
> `container` (Docker or Podman). Python apps work with all strategies
> on Linux via
> [python-build-standalone](https://github.com/astral-sh/python-build-standalone).

## Prerequisites

These are required on the **build machine** (where you run `export()`).
What end users need depends on the runtime strategy: nothing for
`shinylive`, `bundled`, or `auto-download`; R or Python pre-installed
for `system`; Docker or Podman for `container`.

- **R** (\>= 4.4.0)
- **Node.js** (\>= 22.0.0) — run `install_nodejs()` to install locally
  without admin rights
- **npm** (\>= 11.5.0) — included with Node.js

Platform build tools:

| Platform | Requirement                   |
|----------|-------------------------------|
| macOS    | Xcode Command Line Tools      |
| Windows  | Visual Studio Build Tools     |
| Linux    | `build-essential` (gcc, make) |

> [!TIP]
>
> Run `sitrep_shinyelectron()` to verify your system is ready before
> your first export. It checks everything above and tells you what’s
> missing.

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

Turning Shiny apps into desktop apps is a problem many people have
attacked over the years. shinyelectron stands on the shoulders of prior
packaging attempts, community tutorials, and the broader WebR / Pyodide
/ Electron ecosystems. The list below credits the specific projects
whose approaches directly informed this one; we’re grateful to the much
larger community of contributors experimenting in this space.

### Prior packaging attempts

- [electricShine](https://chasemc.github.io/electricShine/) — R package
  that streamlines distributable Shiny Electron apps via its
  `electrify()` function; automates Windows builds.
- [Photon](https://github.com/COVAIL/photon) — RStudio add-in that
  leverages Electron to build standalone Shiny apps for macOS and
  Windows by cloning an R-specific
  [`electron-quick-start`](https://github.com/COVAIL/electron-quick-start)
  repository and including portable R versions.
- [RInno](https://github.com/ficonsulting/RInno) — standalone R
  application builder with Electron on Windows.
- [DesktopDeployR](https://github.com/wleepang/DesktopDeployR) —
  alternative framework for deploying self-contained R-based
  applications with a portable R environment and private package
  library.

### Talks, tutorials, and templates

- **UseR! 2018** — [Shiny meets
  Electron](https://www.youtube.com/watch?v=ARrbbviGvjc) by @ksasso
  demonstrating how to convert Shiny apps into standalone desktop apps.
- **Developer tutorials** — step-by-step guides from
  [@lawalter](https://github.com/lawalter/r-shiny-electron-app) and
  [@dirkschumacher](https://github.com/dirkschumacher/r-shiny-electron)
  on practical integration.
- **Zarathu Corporation templates** — cross-platform deployment
  templates for [macOS
  ARM](https://github.com/zarathucorp/shiny-electron-template-m1) and
  [Windows](https://github.com/zarathucorp/shiny-electron-template-windows),
  summarized in this [R-bloggers
  post](https://www.r-bloggers.com/2023/03/creating-standalone-apps-from-shiny-with-electron-2023-macos-m1/).

### Upstream projects

- [Electron](https://electronjs.org/docs/latest/tutorial/application-distribution)
  — the desktop framework.
- [electron-builder](https://www.electron.build/) — the packaging
  pipeline that produces platform installers.
- [shinylive](https://github.com/posit-dev/r-shinylive) (Posit) and
  [WebR](https://docs.r-wasm.org/webr/) — R in WebAssembly, enabling
  browser-only Shiny apps.
- [py-shinylive](https://github.com/posit-dev/py-shinylive) and
  [Pyodide](https://pyodide.org/) — the Python equivalents.
- [portable-r](https://github.com/portable-r) — standalone R binaries
  used by the `bundled` and `auto-download` strategies.
- [python-build-standalone](https://github.com/astral-sh/python-build-standalone)
  — standalone Python builds used by the Python strategies.

## License

AGPL (\>= 3)

## References

- [`electricShine` (R
  package)](https://chasemc.github.io/electricShine/)
- [`RInno` (R package)](https://github.com/ficonsulting/RInno)
- [`Photon` (RStudio Add-in)](https://github.com/COVAIL/photon)
- [`COVAIL`
  electron-quick-start](https://github.com/COVAIL/electron-quick-start)
- [`DesktopDeployR`
  (framework)](https://github.com/wleepang/DesktopDeployR)
- [Electron ShinyApp Deployment —
  @ksasso](https://github.com/ksasso/Electron_ShinyApp_Deployment)
- [How to Make an R Shiny Electron App —
  @lawalter](https://github.com/lawalter/r-shiny-electron-app)
- [R Shiny and Electron —
  @dirkschumacher](https://github.com/dirkschumacher/r-shiny-electron)
- [Creating Standalone Shiny Apps with Electron on macOS
  M1](https://github.com/zarathucorp/shiny-electron-template-m1)
- [Creating Standalone Shiny Apps with Electron on Windows —
  @jhk0530](https://github.com/zarathucorp/shiny-electron-template-windows)
- [Creating Standalone Apps from Shiny with Electron (R-bloggers) —
  @jhk0530](https://www.r-bloggers.com/2023/03/creating-standalone-apps-from-shiny-with-electron-2023-macos-m1/)
- [Shiny meets Electron (UseR! 2018
  talk)](https://www.youtube.com/watch?v=ARrbbviGvjc) ([slides and
  code](https://github.com/ksasso/useR_electron_meet_shiny/))
- [Electron
  documentation](https://electronjs.org/docs/latest/tutorial/application-distribution)
- [electron-builder documentation](https://www.electron.build/)
- [shinylive (R)](https://github.com/posit-dev/r-shinylive)
- [py-shinylive (Python)](https://github.com/posit-dev/py-shinylive)
- [WebR](https://docs.r-wasm.org/webr/)
- [Pyodide](https://pyodide.org/)
- [portable-r (macOS / Windows builds)](https://github.com/portable-r)
- [python-build-standalone](https://github.com/astral-sh/python-build-standalone)
