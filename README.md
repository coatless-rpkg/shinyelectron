

<!-- README.md is generated from README.qmd. Please edit that file -->

> [!IMPORTANT]
>
> This package is currently in the prototype/experimental stage. It is
> not yet available on CRAN and may have bugs or limitations.

# shinyelectron

<!-- badges: start -->

[![R-CMD-check](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/coatless-rpkg/shinyelectron/actions/workflows/R-CMD-check.yaml)
![Prototype](https://img.shields.io/badge/Status-Prototype-orange.png)
![Experimental](https://img.shields.io/badge/Status-Experimental-blue.png)
<!-- badges: end -->

## Export Shiny Applications as Desktop Applications using Electron

This R package allows you to convert Shiny web applications into
standalone desktop applications for using Electron. This means your
users can run your Shiny apps without having R installed on their
machines.

## Installation

You can install the development version of shinyelectron from
[GitHub](https://github.com/) with:

``` r
# From CRAN (not available yet)
# install.packages("shinyelectron")

# From GitHub
# install.packages("remotes")
remotes::install_github("coatless-rpkg/shinyelectron")
```

## Prerequisites

> [!IMPORTANT]
>
> We are currently working on making the installation process as smooth
> as possible. Please bear with us as we work through identifying the
> necessary dependencies for each platform.

- R (\>= 4.4.0)
- Node.js (\>= 22.0.0)
- npm (\>= 11.5.0)

For building platform-specific installers:

- Windows: Windows 11+ and Visual Studio Build Tools
- macOS: macOS 10.13+ and Xcode CLI
- Linux: Appropriate development tools for your distribution

## Usage

### Quickstart

The `export()` function allows you to convert a Shiny application into a
standalone Electron application.

``` r
library(shinyelectron)

# Export a Shiny application to an Electron application
shinyelectron::export(
  appdir = "path/to/your/shinyapp",
  destdir = "path/to/export/destination"
)
```

For example, to convert the “Hello World” Shiny app from the `{shiny}`
package into a standalone Electron app:

``` r
# Copy "Hello World" from `{shiny}`
system.file("examples", "01_hello", package="shiny") |>
    fs::dir_copy("myapp", overwrite = TRUE)

shinyelectron::export("myapp", "hello-world-app")
```

### Advanced Options

You can customize the export process using the following options:

``` r
shinyelectron::export(
  appdir = "path/to/your/shinyapp",
  destdir = "path/to/export/destination",
  app_name = "My Amazing App",
  platform = c("win", "mac"),  # Build for Windows and Mac only
  include_r = TRUE,    # Bundle minimal R environment
  r_version = "4.4.3", # Bundle R 4.4.3
  overwrite = TRUE,    # Overwrite existing files in destdir
  verbose = TRUE,      # Display detailed progress information 
  open_after = TRUE    # Open the generated project after export
)
```

## How It Works

1.  The package creates an Electron application structure in the
    destination directory
2.  It copies your Shiny application files into this structure
3.  It configures the Electron app to start an R process and run your
    Shiny app
4.  It optionally bundles a minimal R environment
5.  It builds platform-specific installers using electron-builder

## Acknowledgements

This project builds upon several notable efforts to integrate R Shiny
applications with the Electron framework.

### Prior packaging attempts:

- [**electricShine**](https://chasemc.github.io/electricShine/): A
  package that streamlines the creation of distributable Shiny Electron
  apps through its `electrify` function, which automates building and
  packaging processes for Windows.
- [**Photon**](https://github.com/COVAIL/photon): An RStudio add-in that
  leverages Electron to build standalone Shiny apps for macOS and
  Windows by cloning an R specific [`electron-quick-start`
  repository](https://github.com/COVAIL/electron-quick-start) and
  including portable R versions.
- [**RInno**](https://github.com/ficonsulting/RInno): Creates standalone
  R applications with Electron on Windows.
- [**DesktopDeployR**](https://github.com/wleepang/DesktopDeployR): An
  alternative framework for deploying self-contained R-based
  applications that provides a portable R environment and private
  package library.

### Talks, Tutorials, and Templates:

- **User! 2018 Talk**: A presentation by @ksasso at the 2018 UseR!
  conference that demonstrates how to convert Shiny apps into standalone
  desktop applications using Electron.
  [ksassouser2018talk](https://www.youtube.com/watch?v=ARrbbviGvjc)
- **Developer Tutorials**: Valuable step-by-step guides from
  contributors like @lawalter and @dirkschumacher that demonstrate
  practical integration techniques and
  solutions.[shiny-electron-walter-tutorial](https://github.com/dirkschumacher/r-shiny-electron)
- **Zarathu Corporation Templates**: Specialized templates for [macOS
  ARM
  (M1/M2/..)](https://github.com/zarathucorp/shiny-electron-template-m1)
  and
  [Windows](https://github.com/zarathucorp/shiny-electron-template-windows)
  platforms that have significantly contributed to cross-platform
  deployment solutions described in [R-Bloggers: Creating Standalone
  Apps from Shiny with
  Electron](https://www.r-bloggers.com/2023/03/creating-standalone-apps-from-shiny-with-electron-2023-macos-m1/)
  post.

## License

AGPL (\>= 3)

## References

- [`electricShine` (R
  Package)](https://chasemc.github.io/electricShine/)
- [`RInno` (R package)](https://github.com/ficonsulting/RInno)
- [`Photon` (RStudio Addin)](https://github.com/COVAIL/photon)
- [`COVAIL` Electron Quick Start
  (GitHub)](https://github.com/COVAIL/electron-quick-start)
- [`DesktopDeployR`
  (GitHub)](https://github.com/wleepang/DesktopDeployR)
- [Electron ShinyApp Deployment UseR! 2018 (GitHub,
  @ksasso)](https://github.com/ksasso/Electron_ShinyApp_Deployment)
- [How to Make an R Shiny Electron App (GitHub,
  @lawalter)](https://github.com/lawalter/r-shiny-electron-app)
- [R shiny and electron (GitHub,
  @dirkschumacher)](https://github.com/dirkschumacher/r-shiny-electron)
- [Creating Standalone Apps from Shiny with Electron in macOS 2023
  (GitHub, macOS ARM
  (M1/M2/…))](https://github.com/zarathucorp/shiny-electron-template-m1)
- [Creating Standalone Apps from Shiny with Electron in Windows 2023
  (GitHub,
  @jhk0530)](https://github.com/zarathucorp/shiny-electron-template-windows)
- [Creating Standalone Apps from Shiny with Electron 2023 (R-bloggers,
  @jhk0530)](https://www.r-bloggers.com/2023/03/creating-standalone-apps-from-shiny-with-electron-2023-macos-m1/)
- [Shiny meets Electron: Turn your Shiny app into a standalone desktop
  app in no time @ UseR!
  2018](https://www.youtube.com/watch?v=ARrbbviGvjc) ([Presentation
  Source](https://github.com/ksasso/useR_electron_meet_shiny/))
- [Electron
  Documentation](https://electronjs.org/docs/latest/tutorial/application-distribution)
